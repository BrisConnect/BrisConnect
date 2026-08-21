import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:brisconnect/config/app_config.dart';
import 'package:brisconnect/services/best_time_to_post_service.dart';
import 'package:brisconnect/services/session_persistence_service.dart';

/// Top-level handler for background/terminated FCM messages.
/// Must be a top-level or static function.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM] background message: ${message.messageId}');
}

/// Service responsible for Firebase Cloud Messaging token lifecycle,
/// permission handling, and foreground message presentation on iOS/Android.
class FcmService {
  FcmService._({
    FirebaseMessaging? messaging,
    FirebaseFirestore? firestore,
  })  : _messagingOverride = messaging,
        _firestoreOverride = firestore;

  /// Production singleton. Lazily constructed so test harnesses can inject
  /// mocks before first use.
  static FcmService? _instance;

  static FcmService get instance {
    _instance ??= FcmService._();
    return _instance!;
  }

  @visibleForTesting
  static set instance(FcmService value) {
    _instance = value;
  }

  @visibleForTesting
  static void resetInstance() {
    _instance = null;
  }

  final FirebaseMessaging? _messagingOverride;
  final FirebaseFirestore? _firestoreOverride;

  FirebaseMessaging get _messaging =>
      _messagingOverride ?? FirebaseMessaging.instance;
  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;

  String? _cachedToken;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _openedAppSub;
  StreamSubscription<String>? _tokenRefreshSub;

  /// Last known token. May be null before [initialize] completes.
  String? get token => _cachedToken;

  /// Refreshes and stores the current FCM token manually. Call this after a
  /// user signs in so the token is associated with the newly authenticated
  /// account.
  Future<void> refreshToken() async {
    await _refreshAndStoreToken();
  }

  /// Migrates [token] out of the opposite collection so a device token is
  /// never present in both `visitor_users` and `local_users` for the same
  /// email. This keeps Cloud Functions from sending pushes to the wrong
  /// role collection.
  Future<void> _removeTokenFromOppositeCollection(
    String userId,
    String token,
    String targetCollection,
  ) async {
    try {
      final opposite = targetCollection == 'visitor_users'
          ? 'local_users'
          : 'visitor_users';
      final doc = await _firestore
          .collection(opposite)
          .doc(userId)
          .collection('fcmTokens')
          .doc(token)
          .get();
      if (doc.exists) {
        await doc.reference.delete();
        debugPrint('[FCM] removed stale token from $opposite/$userId');
      }
    } catch (e) {
      debugPrint('[FCM] failed to clean up opposite collection token: $e');
    }
  }

  /// Initializes FCM: sets the background handler, requests notification
  /// permissions, configures foreground presentation options, and begins
  /// listening for token refreshes and incoming messages.
  ///
  /// On mobile: requests native notification permissions.
  /// On web: tokens are registered and foreground listeners configured; the web
  /// service worker handles background notifications. Browser permission must be
  /// granted separately by the user (Chrome/Edge/Firefox notification settings).
  Future<void> initialize() async {
    try {
      if (!kIsWeb) {
        FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

        final settings = await _messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: false,
          announcement: false,
          carPlay: false,
          criticalAlert: false,
        );
        debugPrint('[FCM] authorization status: ${settings.authorizationStatus}');

        await _messaging.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      } else {
        // On web: attempt to request permission using the web API.
        // This may prompt the browser's native permission dialog on first access.
        try {
          final permission = await _messaging.requestPermission(
            alert: true,
            badge: true,
            sound: true,
            provisional: true,
          );
          debugPrint('[FCM] web notification permission status: ${permission.authorizationStatus}');
        } catch (e) {
          // On web, permission request is optional and may fail gracefully.
          // Users can enable notifications through browser settings.
          debugPrint('[FCM] web permission request skipped: $e');
        }
      }

      await _refreshAndStoreToken();

      _tokenRefreshSub = _messaging.onTokenRefresh.listen(
        _storeToken,
        onError: (Object e) => debugPrint('[FCM] token refresh error: $e'),
      );

      _foregroundSub = FirebaseMessaging.onMessage.listen(
        _handleForegroundMessage,
        onError: (Object e) => debugPrint('[FCM] foreground message error: $e'),
      );

      _openedAppSub = FirebaseMessaging.onMessageOpenedApp.listen(
        _handleNotificationOpen,
        onError: (Object e) => debugPrint('[FCM] opened-app error: $e'),
      );

      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationOpen(initialMessage);
      }
    } catch (e) {
      debugPrint('[FCM] initialization failed: $e');
    }
  }

  /// Disposes foreground, opened-app, and token refresh listeners.
  void dispose() {
    unawaited(_foregroundSub?.cancel());
    unawaited(_openedAppSub?.cancel());
    unawaited(_tokenRefreshSub?.cancel());
    _foregroundSub = null;
    _openedAppSub = null;
    _tokenRefreshSub = null;
  }

  /// Requests the current FCM token and stores it under the signed-in
  /// [local_users] document.
  Future<void> _refreshAndStoreToken() async {
    try {
      final token = await _messaging.getToken(
        vapidKey: kIsWeb ? AppConfig.firebaseWebVapidKey : null,
      );
      await _storeToken(token);
    } catch (e) {
      debugPrint('[FCM] getToken failed: $e');
    }
  }

  /// Writes [token] to Firestore under the correct user collection
  /// (`visitor_users` or `local_users`) based on the signed-in user's active
  /// role. The parent document uses the signed-in email when available and
  /// falls back to the Firebase Auth UID.
  Future<void> _storeToken(String? token) async {
    if (token == null || token.isEmpty) return;

    final user = fb_auth.FirebaseAuth.instance.currentUser;
    final userId = user?.email?.trim().toLowerCase().isNotEmpty == true
        ? user!.email!.trim().toLowerCase()
        : user?.uid;
    if (userId == null || userId.isEmpty) {
      debugPrint('[FCM] no signed-in user; skipping token storage');
      return;
    }

    _cachedToken = token;

    final collection = await _resolveTokenCollection(userId);

    try {
      await _firestore
          .collection(collection)
          .doc(userId)
          .collection('fcmTokens')
          .doc(token)
          .set({
        'token': token,
        'platform': kIsWeb ? 'web' : Platform.operatingSystem,
        'createdAt': FieldValue.serverTimestamp(),
        'lastSeenAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('[FCM] token stored for $userId in $collection');

      // Ensure the same device token is not also stored under the other
      // role collection, which would let the wrong Cloud Function deliver
      // stale pushes.
      await _removeTokenFromOppositeCollection(userId, token, collection);
    } catch (e) {
      debugPrint('[FCM] token storage failed: $e');
    }
  }

  /// Resolves whether the user is a visitor or local business owner so FCM
  /// tokens are written to the matching collection used by Cloud Functions.
  ///
  /// The active role (persisted from the last successful sign-in) is used
  /// first so users with both a local and visitor profile store tokens in
  /// the collection for the portal they are currently using. Falls back to
  /// checking which Firestore profile exists, and defaults to `local_users`
  /// when no profile is found.
  Future<String> _resolveTokenCollection(String userId) async {
    try {
      final lastRole = await SessionPersistenceService.getLastRole();
      if (lastRole == 'visitor') return 'visitor_users';
      if (lastRole == 'local') return 'local_users';

      final visitorDoc = await _firestore
          .collection('visitor_users')
          .doc(userId)
          .get(const GetOptions(source: Source.serverAndCache));
      if (visitorDoc.exists) return 'visitor_users';

      final localDoc = await _firestore
          .collection('local_users')
          .doc(userId)
          .get(const GetOptions(source: Source.serverAndCache));
      if (localDoc.exists) return 'local_users';
    } catch (e) {
      debugPrint('[FCM] collection resolution failed, defaulting: $e');
    }
    return 'local_users';
  }

  /// Presents a lightweight heads-up notification when a message arrives
  /// while the app is in the foreground. Action buttons from the FCM data
  /// payload are surfaced as snackbar actions (e.g. "Extend offer").
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('[FCM] foreground message: ${message.notification?.title}');

    final notification = message.notification;
    if (notification == null) return;

    final context = navigatorKey.currentContext;
    if (context == null) return;

    final actions = _parseNotificationActions(message.data['actions']);
    final promotionId = message.data['promotionId'];

    SnackBarAction? action;
    if (actions.isNotEmpty) {
      final first = actions.first;
      action = SnackBarAction(
        label: first['title'] ?? 'Open',
        onPressed: () => _onNotificationAction(
          context,
          action: first['action'] ?? '',
          promotionId: promotionId,
          message: message,
        ),
      );
    } else if (_notificationScreen(message.data) case final screen when screen.isNotEmpty) {
      action = SnackBarAction(
        label: 'Open',
        onPressed: () => _navigateForMessage(message),
      );
    }

    final messenger = ScaffoldMessenger.of(context);

    // Keep the snackbar non-blocking and accessible.
    messenger.showSnackBar(
      SnackBar(
        content: Semantics(
          liveRegion: true,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (notification.title?.isNotEmpty == true)
                      Text(
                        notification.title!,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    if (notification.body?.isNotEmpty == true)
                      Text(notification.body!),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                color: Colors.white,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Dismiss',
                onPressed: messenger.hideCurrentSnackBar,
              ),
            ],
          ),
        ),
        duration: const Duration(seconds: 8),
        behavior: SnackBarBehavior.floating,
        action: action,
      ),
    );
  }

  /// Parses a JSON array of action objects from the FCM data payload.
  List<Map<String, String>> _parseNotificationActions(dynamic raw) {
    if (raw == null || raw is! String || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map((a) => <String, String>{
                'action': (a['action'] as String? ?? ''),
                'title': (a['title'] as String? ?? ''),
              })
          .where((a) => a['action']!.isNotEmpty && a['title']!.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('[FCM] failed to parse notification actions: $e');
      return [];
    }
  }

  /// Handles a notification action button press.
  Future<void> _onNotificationAction(
    BuildContext context, {
    required String action,
    String? promotionId,
    RemoteMessage? message,
  }) async {
    switch (action) {
      case 'extend':
        if (promotionId == null || promotionId.isEmpty) return;
        final ok = await BestTimeToPostService().extendPromotion(
          promotionId: promotionId,
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                ok ? 'Offer extended by 7 days.' : 'Could not extend offer.',
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        break;
      case 'open':
        if (message != null) _navigateForMessage(message);
        break;
      default:
        break;
    }
  }

  /// Returns the deep-link screen from a notification data payload, or an
  /// empty string if none is present.
  String _notificationScreen(Map<String, dynamic> data) {
    final screen = data['screen'];
    if (screen is String && screen.isNotEmpty) return screen;
    return '';
  }

  /// Extracts the most relevant item id from a notification data payload.
  String? _notificationArgument(Map<String, dynamic> data) {
    for (final key in const [
      'promotionId',
      'businessId',
      'eventId',
      'reportId',
      'reviewId',
      'relatedItemId',
    ]) {
      final value = data[key];
      if (value is String && value.isNotEmpty) return value;
    }
    return null;
  }

  /// Navigates to the appropriate screen when a push notification is tapped
  /// while the app is foregrounded, backgrounded, or terminated.
  void _navigateForMessage(RemoteMessage message) {
    final screen = _notificationScreen(message.data);
    if (screen.isEmpty) return;

    final navigator = navigatorKey.currentState;
    if (navigator == null) return;

    // Legacy owner notification screens that pre-date route-path deep links.
    final legacyRoutes = <String, String>{
      'business_dashboard': '/local/portal',
      'business_detail': '/business/view',
      'reviews': '/admin/reports',
      'promotion_detail': '/promotion/detail',
    };

    final routeName = legacyRoutes[screen] ?? screen;
    final argument = _notificationArgument(message.data);

    // Owner dashboard routes carry related item IDs as a map.
    final Map<String, dynamic> routeArgs = <String, dynamic>{
      if (argument != null) 'relatedItemId': argument,
      for (final key in const [
        'businessId',
        'promotionId',
        'reviewId',
        'reportId',
        'notificationId',
        'relatedItemType',
      ])
        if (message.data[key] is String && (message.data[key] as String).isNotEmpty)
          key: message.data[key],
    };

    // '/business/view' and '/promotion/detail' require a plain String id;
    // every other route expects the Map (or ignores arguments entirely).
    // Passing a Map where a String is expected throws inside onGenerateRoute
    // and silently aborts the navigation, leaving the user on the same screen.
    final Object? arguments;
    switch (routeName) {
      case '/business/view':
        arguments = (message.data['businessId'] as String?) ?? argument ?? '';
        break;
      case '/promotion/detail':
        arguments = (message.data['promotionId'] as String?) ?? argument ?? '';
        break;
      default:
        arguments = routeArgs.isNotEmpty ? routeArgs : argument;
    }

    navigator.pushNamed(routeName, arguments: arguments).catchError((error) {
      debugPrint('[FCM] navigation error for route $routeName: $error');
      return null;
    });
  }

  /// Navigates to the appropriate screen when a push notification is tapped
  /// while the app is backgrounded or terminated.
  void _handleNotificationOpen(RemoteMessage message) {
    _navigateForMessage(message);
  }
}

/// Global navigator key used by [FcmService] to show foreground notifications.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
