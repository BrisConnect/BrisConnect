import 'package:cloud_firestore/cloud_firestore.dart';

class EventDocumentIdService {
  const EventDocumentIdService._();

  static String slugify(String value) {
    final normalized = value.trim().toLowerCase();
    final replaced = normalized.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    return replaced.replaceAll(RegExp(r'^-+|-+$'), '');
  }

  static String buildLocalSubmissionId({
    required String title,
    required String date,
    required String email,
    DateTime? createdAt,
  }) {
    final timestamp = createdAt ?? DateTime.now();
    final stamp = '${timestamp.year}'
        '${timestamp.month.toString().padLeft(2, '0')}'
        '${timestamp.day.toString().padLeft(2, '0')}'
        '-'
        '${timestamp.hour.toString().padLeft(2, '0')}'
        '${timestamp.minute.toString().padLeft(2, '0')}'
        '${timestamp.second.toString().padLeft(2, '0')}';
    return [
      'local',
      slugify(title),
      slugify(date),
      slugify(email),
      'submitted-$stamp',
    ].where((part) => part.isNotEmpty).join('_');
  }

  static String buildLocalSubmissionIdFromMap(Map<String, dynamic> data) {
    final createdAtRaw = data['createdAt'];
    DateTime? createdAt;
    if (createdAtRaw is Timestamp) {
      createdAt = createdAtRaw.toDate();
    }

    return buildLocalSubmissionId(
      title: '${data['title'] ?? 'event'}',
      date: '${data['date'] ?? 'date'}',
      email: '${data['createdByLocalEmail'] ?? 'local'}',
      createdAt: createdAt,
    );
  }
}