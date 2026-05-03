import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationRecord {
  final String id;
  final String eventId;
  final String userEmail;
  final String userType; // 'visitor' or 'local'
  final String eventTitle;
  final String eventDateTime;
  final String eventLocation;
  final String scheduleType; // 'event_time' | 'fallback' | 'unknown'
  final DateTime createdAt;
  final bool isRead;

  const NotificationRecord({
    required this.id,
    required this.eventId,
    required this.userEmail,
    required this.userType,
    required this.eventTitle,
    required this.eventDateTime,
    required this.eventLocation,
    this.scheduleType = 'unknown',
    required this.createdAt,
    this.isRead = false,
  });

  factory NotificationRecord.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final createdAtRaw = data['createdAt'];
    DateTime createdAt;
    if (createdAtRaw is Timestamp) {
      createdAt = createdAtRaw.toDate();
    } else {
      createdAt = DateTime.now();
    }

    return NotificationRecord(
      id: doc.id,
      eventId: '${data['eventId'] ?? ''}'.trim(),
      userEmail: '${data['userEmail'] ?? ''}'.trim(),
      userType: '${data['userType'] ?? 'visitor'}'.trim(),
      eventTitle: '${data['eventTitle'] ?? 'Event'}'.trim(),
      eventDateTime: '${data['eventDateTime'] ?? 'Date TBA'}'.trim(),
      eventLocation: '${data['eventLocation'] ?? 'Location TBA'}'.trim(),
      scheduleType: '${data['scheduleType'] ?? 'unknown'}'.trim(),
      createdAt: createdAt,
      isRead: data['isRead'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'eventId': eventId,
      'userEmail': userEmail,
      'userType': userType,
      'eventTitle': eventTitle,
      'eventDateTime': eventDateTime,
      'eventLocation': eventLocation,
      'scheduleType': scheduleType,
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': isRead,
    };
  }

  NotificationRecord copyWith({bool? isRead, String? scheduleType}) {
    return NotificationRecord(
      id: id,
      eventId: eventId,
      userEmail: userEmail,
      userType: userType,
      eventTitle: eventTitle,
      eventDateTime: eventDateTime,
      eventLocation: eventLocation,
      scheduleType: scheduleType ?? this.scheduleType,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
    );
  }
}
