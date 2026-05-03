import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:brisconnect/models/event_item.dart';
import 'package:brisconnect/services/event_document_id_service.dart';
import 'package:brisconnect/services/local_email_notification_service.dart';
import 'package:brisconnect/services/sms_notification_service.dart';

import 'package:brisconnect/utils/narration_builder.dart';

class AdminEventService {
  AdminEventService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<int> migrateLegacyLocalSubmissionIds() async {
    try {
      final snapshot = await _firestore
          .collection('events')
          .where('source', isEqualTo: 'local_submission')
          .get();

      var migratedCount = 0;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final targetId = EventDocumentIdService.buildLocalSubmissionIdFromMap(data);
        if (targetId.isEmpty || targetId == doc.id) {
          continue;
        }

        final batch = _firestore.batch();
        batch.set(
          _firestore.collection('events').doc(targetId),
          {
            ...data,
            'id': targetId,
          },
          SetOptions(merge: true),
        );
        batch.delete(doc.reference);
        await batch.commit();
        migratedCount++;
      }

      if (migratedCount > 0) {
        debugPrint('[AdminEventService] Migrated $migratedCount legacy local event IDs.');
      }
      return migratedCount;
    } catch (error) {
      debugPrint('[AdminEventService] migrateLegacyLocalSubmissionIds failed: $error');
      return 0;
    }
  }

  Stream<List<EventItem>> watchAllEvents() {
    return _firestore.collection('events').snapshots().map((snapshot) {
      final events = <EventItem>[];
      for (final doc in snapshot.docs) {
        try {
          events.add(_eventFromDoc(doc));
        } catch (error) {
          debugPrint(
            '[AdminEventService] Skipping invalid event ${doc.id}: $error',
          );
        }
      }

      events.sort((left, right) {
        final statusOrder = _statusSortWeight(left.reviewStatus)
            .compareTo(_statusSortWeight(right.reviewStatus));
        if (statusOrder != 0) {
          return statusOrder;
        }
        return left.title.toLowerCase().compareTo(right.title.toLowerCase());
      });
      return events;
    });
  }

  Future<void> updateEvent({
    required String eventId,
    required String title,
    required String date,
    String? category,
    EventReviewStatus? reviewStatus,
    required String location,
    required String description,
    String? imageUrl,
    String? imageStoragePath,
    String? videoUrl,
    String? videoStoragePath,
    String? audioUrl,
    String? audioStoragePath,
    String? aiNarration,
  }) async {
    final eventRef = _firestore.collection('events').doc(eventId);
    EventReviewStatus? previousReviewStatus;
    String? createdByLocalEmail;

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(eventRef);
      if (!snapshot.exists) {
        throw StateError('Event no longer exists.');
      }

      final data = snapshot.data() ?? const <String, dynamic>{};
      previousReviewStatus = _parseStatus(
        (data['reviewStatus'] as String?) ??
            (data['status'] as String?) ??
            (data['badge'] as String?),
      );
      createdByLocalEmail = ((data['createdByLocalEmail'] as String?) ??
              (data['createdBy'] as String?))
          ?.trim();
      final time = ((data['time'] as String?) ?? _extractTime(data)).trim();
      final normalizedTitle = title.trim();
      final normalizedDate = date.trim();
      final normalizedLocation = location.trim();
      final normalizedDescription = description.trim();

      transaction.update(eventRef, {
        'title': normalizedTitle,
        'date': normalizedDate,
        if (category != null) 'category': category.trim(),
        'location': normalizedLocation,
        'description': normalizedDescription,
        if (reviewStatus != null) ...{
          'reviewStatus': _statusToValue(reviewStatus),
          'status': _statusToValue(reviewStatus),
          'badge': _statusBadgeValue(reviewStatus),
          'isApproved': reviewStatus == EventReviewStatus.approved,
        },
        'imageUrl': imageUrl,
        'imageStoragePath': imageStoragePath,
        'videoUrl': videoUrl,
        'videoStoragePath': videoStoragePath,
        'audioUrl': audioUrl,
        'audioStoragePath': audioStoragePath,
        if (aiNarration != null) 'aiNarration': aiNarration.trim(),
        'dateTime': _composeDateTime(normalizedDate, time),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    // Sync approved events to discover_items so visitors can see them.
    if (reviewStatus == EventReviewStatus.approved) {
      final eventSnapshot = await eventRef.get();
      final eventData = eventSnapshot.data() ?? const <String, dynamic>{};
      final narration = aiNarration ??
          (eventData['aiNarration'] as String? ?? '') .trim();
      final generatedNarration = narration.isNotEmpty
          ? narration
          : buildEventNarration(
              title: title.trim(),
              dateTime: eventData['dateTime'] as String? ?? '',
              location: location.trim(),
              description: description.trim(),
            );

      await _firestore.collection('discover_items').doc(eventId).set({
        'id': eventId,
        'title': title.trim(),
        'date': date.trim(),
        'dateTime': eventData['dateTime'] as String? ?? '',
        'category': category?.trim() ?? eventData['category'] as String? ?? '',
        'location': location.trim(),
        'description': description.trim(),
        'section': 'events',
        'approvalStatus': 'approved',
        'imageUrl': imageUrl ?? eventData['imageUrl'],
        'imageStoragePath': imageStoragePath ?? eventData['imageStoragePath'],
        'videoUrl': videoUrl ?? eventData['videoUrl'],
        'videoStoragePath': videoStoragePath ?? eventData['videoStoragePath'],
        'audioUrl': audioUrl ?? eventData['audioUrl'],
        'audioStoragePath': audioStoragePath ?? eventData['audioStoragePath'],
        'aiNarration': generatedNarration,
        'source': eventData['source'] as String? ?? 'local_submission',
        'createdByLocalEmail': createdByLocalEmail,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    if (reviewStatus != null &&
        previousReviewStatus != null &&
        previousReviewStatus != reviewStatus &&
        (createdByLocalEmail?.isNotEmpty ?? false)) {
      await _queueLocalReviewSms(
        localEmail: createdByLocalEmail!,
        eventTitle: title.trim(),
        reviewStatus: _statusToValue(reviewStatus),
      );
      await _queueLocalReviewEmail(
        localEmail: createdByLocalEmail!,
        eventTitle: title.trim(),
        approved: reviewStatus == EventReviewStatus.approved,
      );
    }
  }

  Future<void> deleteEvent(String eventId) async {
    final eventRef = _firestore.collection('events').doc(eventId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(eventRef);
      if (!snapshot.exists) {
        throw StateError('Event no longer exists.');
      }
      transaction.delete(eventRef);
    });
  }

  EventItem _eventFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final rawDate = ((data['date'] as String?) ?? '').trim();
    final rawTime = ((data['time'] as String?) ?? _extractTime(data)).trim();
    final reviewStatus = _parseStatus(
      (data['reviewStatus'] as String?) ??
          (data['status'] as String?) ??
          (data['badge'] as String?),
    );

    return EventItem(
      id: doc.id,
      title: ((data['title'] as String?) ?? 'Untitled Event').trim(),
      date: rawDate.isNotEmpty ? rawDate : _extractDate(data),
      time: rawTime.isNotEmpty ? rawTime : 'Time TBA',
      location: ((data['location'] as String?) ?? 'Location TBA').trim(),
      description: ((data['description'] as String?) ?? '').trim(),
      reviewStatus: reviewStatus,
      createdByLocalEmail: ((data['createdByLocalEmail'] as String?) ??
              (data['createdBy'] as String?))
          ?.trim(),
      imageAsset: (data['imageUrl'] as String?)?.trim(),
      imageStoragePath: (data['imageStoragePath'] as String?)?.trim(),
      audioUrl: (data['audioUrl'] as String?)?.trim(),
      audioStoragePath: (data['audioStoragePath'] as String?)?.trim(),
      videoUrl: (data['videoUrl'] as String?)?.trim(),
      videoStoragePath: (data['videoStoragePath'] as String?)?.trim(),
      category: ((data['category'] as String?) ?? 'General').trim(),
      latitude: _toDouble(data['latitude']),
      longitude: _toDouble(data['longitude']),
    );
  }

  EventReviewStatus _parseStatus(String? rawStatus) {
    final normalized = (rawStatus ?? '').trim().toLowerCase();
    if (normalized.contains('pending')) {
      return EventReviewStatus.pending;
    }
    if (normalized.contains('reject')) {
      return EventReviewStatus.rejected;
    }
    return EventReviewStatus.approved;
  }

  int _statusSortWeight(EventReviewStatus status) {
    switch (status) {
      case EventReviewStatus.pending:
        return 0;
      case EventReviewStatus.approved:
        return 1;
      case EventReviewStatus.rejected:
        return 2;
    }
  }

  double? _toDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }

  String _extractDate(Map<String, dynamic> data) {
    final dateTime = ((data['dateTime'] as String?) ?? '').trim();
    if (dateTime.isEmpty) {
      return 'Date TBA';
    }
    final parts = dateTime.split('ΓÇó');
    return parts.first.trim();
  }

  String _extractTime(Map<String, dynamic> data) {
    final dateTime = ((data['dateTime'] as String?) ?? '').trim();
    if (!dateTime.contains('ΓÇó')) {
      return '';
    }
    final parts = dateTime.split('ΓÇó');
    if (parts.length < 2) {
      return '';
    }
    return parts.sublist(1).join('ΓÇó').trim();
  }

  String _composeDateTime(String date, String time) {
    if (time.isEmpty) {
      return date;
    }
    return '$date ΓÇó $time';
  }

  String _statusToValue(EventReviewStatus status) {
    switch (status) {
      case EventReviewStatus.pending:
        return 'pending';
      case EventReviewStatus.approved:
        return 'approved';
      case EventReviewStatus.rejected:
        return 'rejected';
    }
  }

  String _statusBadgeValue(EventReviewStatus status) {
    switch (status) {
      case EventReviewStatus.pending:
        return 'PENDING';
      case EventReviewStatus.approved:
        return 'APPROVED';
      case EventReviewStatus.rejected:
        return 'REJECTED';
    }
  }

  Future<void> _queueLocalReviewSms({
    required String localEmail,
    required String eventTitle,
    required String reviewStatus,
  }) async {
    final localDoc = await _firestore
        .collection('local_users')
        .doc(localEmail.toLowerCase())
        .get();
    final localData = localDoc.data() ?? const <String, dynamic>{};
    final phone = ((localData['phone'] as String?) ??
            (localData['phoneNumber'] as String?) ??
            (localData['mobile'] as String?) ??
            '')
        .trim();
    if (phone.isEmpty) {
      return;
    }

    await SmsNotificationService().queueLocalEventReviewSms(
      recipientPhone: phone,
      eventTitle: eventTitle,
      reviewStatus: reviewStatus,
    );
  }

  Future<void> _queueLocalReviewEmail({
    required String localEmail,
    required String eventTitle,
    required bool approved,
  }) async {
    final normalizedEmail = localEmail.trim().toLowerCase();
    if (normalizedEmail.isEmpty) {
      return;
    }

    await LocalEmailNotificationService(firestore: _firestore)
        .queueEventReviewEmail(
      recipientEmail: normalizedEmail,
      eventTitle: eventTitle,
      approved: approved,
    );
  }
}
