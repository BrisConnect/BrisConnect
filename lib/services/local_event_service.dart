import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:brisconnect/models/event_item.dart';
import 'package:brisconnect/services/firebase_media_service.dart';

class LocalEventService {
  LocalEventService(
      {FirebaseFirestore? firestore, FirebaseMediaService? mediaService})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _mediaService = mediaService;

  final FirebaseFirestore _firestore;
  FirebaseMediaService? _mediaService;

  FirebaseMediaService get _effectiveMediaService =>
      _mediaService ??= FirebaseMediaService();

  Stream<List<EventItem>> watchSubmittedEvents(String localEmail) {
    final normalizedEmail = localEmail.trim().toLowerCase();
    if (normalizedEmail.isEmpty) {
      return Stream<List<EventItem>>.value(const <EventItem>[]);
    }

    return _firestore
        .collection('events')
        .where('createdByLocalEmail', isEqualTo: normalizedEmail)
        .snapshots()
        .map((snapshot) {
      final events = <EventItem>[];
      for (final doc in snapshot.docs) {
        try {
          events.add(_eventFromDoc(doc));
        } catch (error) {
          debugPrint(
            '[LocalEventService] Skipping invalid event ${doc.id}: $error',
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

  Future<bool> updateSubmittedEvent({
    required String eventId,
    required String localEmail,
    required String title,
    required String date,
    required String category,
    required String location,
    required String description,
    String? imageUrl,
    String? imageStoragePath,
    String? audioUrl,
    String? audioStoragePath,
    String? aiNarration,
  }) async {
    final normalizedRequester = localEmail.trim().toLowerCase();
    final eventRef = _firestore.collection('events').doc(eventId);

    return _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(eventRef);
      if (!snapshot.exists) {
        return false;
      }

      final data = snapshot.data() ?? const <String, dynamic>{};
      final normalizedOwner =
          ((data['createdByLocalEmail'] as String?) ?? '').trim().toLowerCase();
      if (normalizedOwner.isEmpty || normalizedOwner != normalizedRequester) {
        return false;
      }

      final time = ((data['time'] as String?) ?? _extractTime(data)).trim();
      final normalizedTitle = title.trim();
      final normalizedDate = date.trim();
      final normalizedCategory = category.trim();
      final normalizedLocation = location.trim();
      final normalizedDescription = description.trim();

      transaction.update(eventRef, {
        'title': normalizedTitle,
        'date': normalizedDate,
        'category': normalizedCategory,
        'location': normalizedLocation,
        'description': normalizedDescription,
        'imageUrl': imageUrl?.trim(),
        'imageStoragePath': imageStoragePath?.trim(),
        'audioUrl': audioUrl?.trim(),
        'audioStoragePath': audioStoragePath?.trim(),
        if (aiNarration != null) 'aiNarration': aiNarration.trim(),
        'reviewStatus': 'pending',
        'dateTime': _composeDateTime(normalizedDate, time),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return true;
    });
  }

  Future<bool> deleteSubmittedEvent({
    required String eventId,
    required String localEmail,
  }) async {
    final normalizedRequester = localEmail.trim().toLowerCase();
    final eventRef = _firestore.collection('events').doc(eventId);
    String? imageStoragePath;

    final deleted = await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(eventRef);
      if (!snapshot.exists) {
        return false;
      }

      final data = snapshot.data() ?? const <String, dynamic>{};
      final normalizedOwner =
          ((data['createdByLocalEmail'] as String?) ?? '').trim().toLowerCase();
      if (normalizedOwner.isEmpty || normalizedOwner != normalizedRequester) {
        return false;
      }

      imageStoragePath = (data['imageStoragePath'] as String?)?.trim();

      transaction.delete(eventRef);
      return true;
    });

    if (deleted && imageStoragePath != null && imageStoragePath!.isNotEmpty) {
      await _effectiveMediaService.deleteMedia(imageStoragePath);
    }

    return deleted;
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
      category: ((data['category'] as String?) ?? 'General').trim(),
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
    final parts = dateTime.split('•');
    return parts.first.trim();
  }

  String _extractTime(Map<String, dynamic> data) {
    final dateTime = ((data['dateTime'] as String?) ?? '').trim();
    if (!dateTime.contains('•')) {
      return '';
    }
    final parts = dateTime.split('•');
    if (parts.length < 2) {
      return '';
    }
    return parts.sublist(1).join('•').trim();
  }

  String _composeDateTime(String date, String time) {
    if (time.isEmpty) {
      return date;
    }
    return '$date • $time';
  }
}
