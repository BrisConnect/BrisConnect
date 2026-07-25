import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'package:brisconnect/services/best_time_to_post_service.dart';

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

  /// Initializes FCM: sets the background handler, requests iOS notification
  /// permissions, configures foreground presentation options, and begins
  /// listening for token refreshes and incoming messages.
  Future<void> initialize() async {
    try {
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
      final token = await _messaging.getToken();
      await _storeToken(token);
    } catch (e) {
      debugPrint('[FCM] getToken failed: $e');
    }
  }

  /// Writes [token] to Firestore under `local_users/{userId}/fcmTokens`
  /// with a createdAt timestamp and platform metadata. The parent document
  /// uses the signed-in email when available (consistent with local/visitor
  /// user collections) and falls back to the Firebase Auth UID.
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

    try {
      await _firestore
          .collection('local_users')
          .doc(userId)
          .collection('fcmTokens')
          .doc(token)
          .set({
        'token': token,
        'platform': Platform.operatingSystem,
        'createdAt': FieldValue.serverTimestamp(),
        'lastSeenAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('[FCM] token stored for $userId');
    } catch (e) {
      debugPrint('[FCM] token storage failed: $e');
    }
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
        ),
      );
    }

    // Keep the snackbar non-blocking and accessible.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Semantics(
          liveRegion: true,
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
        duration: const Duration(seconds: 8),
        behavior: SnackBarBehavior.floating,
        action: action ??
            SnackBarAction(
              label: 'Dismiss',
              onPressed: () {},
            ),
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
      default:
        break;
    }
  }

  /// Navigates to the appropriate screen when a push notification is tapped
  /// while the app is backgrounded or terminated.
  void _handleNotificationOpen(RemoteMessage message) {
    final screen = message.data['screen'];
    if (screen == null || screen.isEmpty) return;

    final navigator = navigatorKey.currentState;
    if (navigator == null) return;

    switch (screen) {
      case 'promotion_detail':
        final promotionId = message.data['promotionId'];
        if (promotionId != null && promotionId.isNotEmpty) {
          navigator.pushNamed('/promotion/detail', arguments: promotionId);
        }
        break;
      default:
        debugPrint('[FCM] unhandled notification screen: $screen');
    }
  }
}

/// Global navigator key used by [FcmService] to show foreground notifications.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
