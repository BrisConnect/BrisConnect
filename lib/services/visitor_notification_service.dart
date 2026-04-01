import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:brisconnect/services/notification_repository.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class VisitorNotificationService {
  static final VisitorNotificationService _instance =
      VisitorNotificationService._internal();

  late FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin;
  bool _isInitialized = false;
  static bool _timezoneInitialized = false;

  VisitorNotificationService._internal();

  factory VisitorNotificationService() {
    return _instance;
  }

  Future<void> initialize() async {
    if (_isInitialized) return;

    _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _flutterLocalNotificationsPlugin.initialize(initSettings);

    final androidImplementation =
        _flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidImplementation?.requestNotificationsPermission();

    _initializeTimezone();
    _isInitialized = true;
  }

  void _initializeTimezone() {
    if (_timezoneInitialized) return;
    tz_data.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Australia/Brisbane'));
    } catch (_) {
      // Fallback to the timezone package default local location.
    }
    _timezoneInitialized = true;
  }

  Future<void> showEventReminderNotification({
    required String eventTitle,
    required String eventDate,
    required String eventLocation,
    required int notificationId,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    const androidDetails = AndroidNotificationDetails(
      'event_reminders',
      'Event Reminders',
      channelDescription:
          'Notifications for events you are interested in.',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _flutterLocalNotificationsPlugin.show(
      notificationId,
      'Event Reminder: $eventTitle',
      'Coming up on $eventDate at $eventLocation',
      notificationDetails,
    );
  }

  DateTime? _parseEventStart(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;

    final slashTime = RegExp(
      r'^(\d{1,2})\/(\d{1,2})\/(\d{4})\s*[•\-]\s*(\d{1,2}):(\d{2})$',
    ).firstMatch(text);
    if (slashTime != null) {
      return DateTime(
        int.parse(slashTime.group(3)!),
        int.parse(slashTime.group(2)!),
        int.parse(slashTime.group(1)!),
        int.parse(slashTime.group(4)!),
        int.parse(slashTime.group(5)!),
      );
    }

    final slashDate = RegExp(r'^(\d{1,2})\/(\d{1,2})\/(\d{4})$').firstMatch(text);
    if (slashDate != null) {
      return DateTime(
        int.parse(slashDate.group(3)!),
        int.parse(slashDate.group(2)!),
        int.parse(slashDate.group(1)!),
        9,
      );
    }

    final wordDate = RegExp(r'^(\d{1,2})\s+([A-Za-z]{3})\s+(\d{4})$').firstMatch(text);
    if (wordDate != null) {
      const months = {
        'jan': 1,
        'feb': 2,
        'mar': 3,
        'apr': 4,
        'may': 5,
        'jun': 6,
        'jul': 7,
        'aug': 8,
        'sep': 9,
        'oct': 10,
        'nov': 11,
        'dec': 12,
      };
      final month = months[wordDate.group(2)!.toLowerCase()];
      if (month != null) {
        return DateTime(
          int.parse(wordDate.group(3)!),
          month,
          int.parse(wordDate.group(1)!),
          9,
        );
      }
    }

    return null;
  }

  DateTime _resolveReminderTime(String eventDateText) {
    final eventStart = _parseEventStart(eventDateText);
    if (eventStart == null) {
      // Fallback for demo data that does not contain parseable date/time.
      return DateTime.now().add(const Duration(seconds: 12));
    }

    final reminderAt = eventStart.subtract(const Duration(hours: 24));
    final now = DateTime.now();
    if (reminderAt.isAfter(now)) {
      return reminderAt;
    }

    // If 24h lead time has already passed, schedule a near-term fallback.
    return now.add(const Duration(seconds: 10));
  }

  /// Schedule a local notification based on event date/time.
  /// Default target is 24h before event start, with safe fallback for demo data.
  Future<void> scheduleEventReminder({
    required String eventTitle,
    required String eventDate,
    required String eventLocation,
    required int notificationId,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    const androidDetails = AndroidNotificationDetails(
      'event_reminders',
      'Event Reminders',
      channelDescription: 'Notifications for events you are interested in.',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final reminderAt = _resolveReminderTime(eventDate);
    final tzReminderAt = tz.TZDateTime.from(reminderAt, tz.local);

    await _flutterLocalNotificationsPlugin.cancel(notificationId);
    await _flutterLocalNotificationsPlugin.zonedSchedule(
      notificationId,
      'Event Reminder: $eventTitle',
      'Coming up on $eventDate at $eventLocation',
      tzReminderAt,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Schedule notification when an event is added to interested list.
  /// Also writes a persistent record to Firestore.
  Future<void> scheduleNotificationForInterestedEvent({
    required String eventTitle,
    required String eventDatetime,
    required String eventLocation,
    required String eventId,
    required String userEmail,
    String userType = 'visitor',
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    // Use event ID as base for notification ID
    final notificationId = eventId.hashCode & 0x7fffffff;
    final scheduleType =
        _parseEventStart(eventDatetime) == null ? 'fallback' : 'event_time';

    // Persist notification record to Firestore
    final repo = NotificationRepository();
    final didSave = await repo.saveNotification(
      userEmail: userEmail,
      userType: userType,
      eventTitle: eventTitle,
      eventDateTime: eventDatetime,
      eventLocation: eventLocation,
      scheduleType: scheduleType,
    );
    if (!didSave) {
      debugPrint(
        '[VisitorNotificationService] Firestore notification save did not complete for $userEmail',
      );
    }

    await scheduleEventReminder(
      eventTitle: eventTitle,
      eventDate: eventDatetime,
      eventLocation: eventLocation,
      notificationId: notificationId,
    );
  }

  Future<void> cancelNotificationForInterestedEvent({
    required String eventTitle,
    required String eventDatetime,
    required String eventId,
    required String userEmail,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    final notificationId = eventId.hashCode & 0x7fffffff;
    await cancelNotification(notificationId);

    final repo = NotificationRepository();
    await repo.deleteNotificationForEvent(
      userEmail: userEmail,
      eventTitle: eventTitle,
      eventDateTime: eventDatetime,
    );
  }

  Future<void> cancelNotification(int notificationId) async {
    if (!_isInitialized) {
      await initialize();
    }
    await _flutterLocalNotificationsPlugin.cancel(notificationId);
  }

  Future<void> cancelAllNotifications() async {
    if (!_isInitialized) {
      await initialize();
    }
    await _flutterLocalNotificationsPlugin.cancelAll();
  }
}
