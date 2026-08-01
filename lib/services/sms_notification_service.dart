import 'package:flutter/foundation.dart';

/// Notification/SMS service.
///
/// NOTE: Twilio has been removed. Firebase Phone Auth is used for
/// verification codes only. Welcome/notification SMS are no longer sent.
/// All methods below are intentionally stubbed and log clearly that no SMS
/// was dispatched, so it is obvious during testing that this channel is
/// disabled.
class SmsNotificationService {
  SmsNotificationService({String senderName = 'BrisConnect+'}) {
    // senderName is kept for API compatibility but no longer used
    // because Twilio has been removed.
    debugPrint(
      '[SmsNotificationService] INITIALISED — SMS is DISABLED. '
      'No text messages will be sent (Twilio removed). senderName=$senderName',
    );
  }

  /// Always false — SMS is not configured in this project.
  bool get isSmsEnabled => false;

  /// Deprecated: admin broadcast SMS is no longer supported. Returns 0.
  Future<int> queueAdminBroadcastSms({
    required String audience,
    required String message,
    bool approvedLocalsOnly = false,
  }) async {
    debugPrint(
      '[SmsNotificationService] NOT SENT — admin broadcast SMS is disabled. '
      'audience=$audience',
    );
    return 0;
  }

  /// Deprecated: direct local SMS is no longer supported. Returns 0.
  Future<int> queueSingleLocalSms({
    required String email,
    required String message,
  }) async {
    debugPrint(
      '[SmsNotificationService] NOT SENT — direct local SMS is disabled. '
      'email=$email',
    );
    return 0;
  }

  /// Deprecated: registration welcome SMS is no longer supported.
  Future<void> queueLocalAccountRegistrationReceivedSms({
    required String recipientPhone,
    required String businessName,
  }) async {
    debugPrint(
      '[SmsNotificationService] NOT SENT — local registration welcome SMS is disabled. '
      'phone=$recipientPhone, business=$businessName',
    );
  }

  /// Deprecated: registration welcome SMS is no longer supported.
  Future<void> queueVisitorRegistrationReceivedSms({
    required String recipientPhone,
    required String visitorName,
  }) async {
    debugPrint(
      '[SmsNotificationService] NOT SENT — visitor registration welcome SMS is disabled. '
      'phone=$recipientPhone, visitor=$visitorName',
    );
  }

  /// Deprecated: account review SMS is no longer supported.
  Future<void> queueLocalAccountReviewSms({
    required String recipientPhone,
    required String businessName,
    required bool approved,
  }) async {
    debugPrint(
      '[SmsNotificationService] NOT SENT — local account review SMS is disabled. '
      'phone=$recipientPhone, business=$businessName, approved=$approved',
    );
  }

  /// Deprecated: event review SMS is no longer supported.
  Future<void> queueLocalEventReviewSms({
    required String recipientPhone,
    required String eventTitle,
    required String reviewStatus,
  }) async {
    debugPrint(
      '[SmsNotificationService] NOT SENT — local event review SMS is disabled. '
      'phone=$recipientPhone, event=$eventTitle, status=$reviewStatus',
    );
  }

  /// Saved-event reminder SMS is no longer supported.
  Future<bool> queueVisitorSavedEventSms({
    required String visitorEmail,
    required String eventId,
  }) async {
    debugPrint(
      '[SmsNotificationService] NOT SENT — visitor saved-event SMS is disabled. '
      'email=$visitorEmail, eventId=$eventId',
    );
    return false;
  }

  /// Saved-event reminder SMS is no longer supported.
  Future<bool> queueLocalSavedEventSms({
    required String localEmail,
    required String eventId,
  }) async {
    debugPrint(
      '[SmsNotificationService] NOT SENT — local saved-event SMS is disabled. '
      'email=$localEmail, eventId=$eventId',
    );
    return false;
  }
}
