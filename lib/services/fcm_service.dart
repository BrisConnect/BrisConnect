import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

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
    } catch (e) {
      debugPrint('[FCM] initialization failed: $e');
    }
  }

  /// Disposes foreground and token refresh listeners.
  void dispose() {
    unawaited(_foregroundSub?.cancel());
    unawaited(_tokenRefreshSub?.cancel());
    _foregroundSub = null;
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
  /// while the app is in the foreground.
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('[FCM] foreground message: ${message.notification?.title}');

    final notification = message.notification;
    if (notification == null) return;

    final context = navigatorKey.currentContext;
    if (context == null) return;

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
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Dismiss',
          onPressed: () {},
        ),
      ),
    );
  }
}

/// Global navigator key used by [FcmService] to show foreground notifications.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
