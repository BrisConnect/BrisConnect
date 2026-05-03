import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:brisconnect/services/location_utilities.dart';

class OlympicEventEmailService {
  OlympicEventEmailService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const double _brisbaneLatitude = -27.4698;
  static const double _brisbaneLongitude = 153.0251;
  static const double _brisbaneRadiusKm = 80.0;

  static const List<String> _brisbaneLocationKeywords = [
    'brisbane',
    'south bank',
    'kangaroo point',
    'woolloongabba',
    'fortitude valley',
    'new farm',
    'newstead',
    'west end',
    'toowong',
    'milton',
    'spring hill',
    'kelvin grove',
    'st lucia',
    'indooroopilly',
    'nundah',
    'chermside',
    'carindale',
  ];

  Future<void> queueUpcomingOlympicEventEmail({
    required String recipientEmail,
  }) async {
    final upcoming = await _loadUpcomingOlympicBrisbaneEvents();
    if (upcoming.isEmpty) {
      return;
    }

    await _queueEmailForRecipient(
      recipientEmail: recipientEmail,
      events: upcoming,
    );
  }

  Future<int> queueUpcomingOlympicEventEmailsForOptedInVisitors() async {
    final upcoming = await _loadUpcomingOlympicBrisbaneEvents();
    if (upcoming.isEmpty) {
      return 0;
    }

    final visitors = await _firestore
        .collection('visitor_users')
        .where('emailNotificationsEnabled', isEqualTo: true)
        .get();

    var queuedCount = 0;
    for (final doc in visitors.docs) {
      final data = doc.data();
      final rawEmail = (data['email'] as String?) ?? doc.id;
      final email = rawEmail.trim().toLowerCase();
      if (email.isEmpty || !email.contains('@')) {
        continue;
      }

      final queued = await _queueEmailForRecipient(
        recipientEmail: email,
        events: upcoming,
      );
      if (queued) {
        queuedCount++;
      }
    }
    return queuedCount;
  }

  Future<List<Map<String, dynamic>>> _loadUpcomingOlympicBrisbaneEvents() async {
    final now = DateTime.now();
    final snapshot = await _firestore
        .collection('events')
        .where('reviewStatus', isEqualTo: 'approved')
        .get();

    return snapshot.docs
        .map((doc) => doc.data())
        .where((data) {
          final title = (data['title'] as String? ?? '').toLowerCase();
          final description =
              (data['description'] as String? ?? '').toLowerCase();
          final searchable = '$title $description';
          final maybeOlympic = searchable.contains('olympic') ||
              searchable.contains('brisbane 2032') ||
              searchable.contains('games');
          if (!maybeOlympic) return false;

          if (!_isBrisbaneArea(data)) {
            return false;
          }

          final dateText = (data['date'] as String? ?? '').trim();
          if (dateText.isEmpty) return true;
          final parsed = _tryParseEventDate(dateText);
          if (parsed == null) {
            return false;
          }
          return parsed.isAfter(now.subtract(const Duration(days: 1)));
        })
        .take(5)
        .toList(growable: false);
  }

  Future<bool> _queueEmailForRecipient({
    required String recipientEmail,
    required List<Map<String, dynamic>> events,
  }) async {
    final normalizedRecipient = recipientEmail.trim().toLowerCase();
    if (normalizedRecipient.isEmpty) {
      return false;
    }

    final digest = _buildDigest(events);
    final existing = await _firestore
        .collection('mail')
        .where('to', isEqualTo: normalizedRecipient)
        .where('meta.type', isEqualTo: 'visitor_olympic_events')
        .where('meta.eventDigest', isEqualTo: digest)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      return false;
    }

    final itemsHtml = events.map((event) {
      final title = event['title'] ?? 'Upcoming Event';
      final date = event['date'] ?? 'Date TBA';
      final time = event['time'] ?? 'Time TBA';
      final venue = event['location'] ?? event['venue'] ?? 'Venue TBA';
      return '<li><strong>$title</strong><br>$date at $time<br>$venue</li>';
    }).join();

    final ts = DateTime.now().millisecondsSinceEpoch;
    final emailSlug = normalizedRecipient
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    await _firestore.collection('mail').doc(
      'olympic-events-$emailSlug-$ts',
    ).set({
      'to': normalizedRecipient,
      'message': {
        'subject': 'Upcoming Brisbane Olympic events',
        'html': '<p>Here are upcoming Brisbane Olympic-related events:</p><ul>$itemsHtml</ul>',
      },
      'meta': {
        'type': 'visitor_olympic_events',
        'eventDigest': digest,
      },
      'createdAt': FieldValue.serverTimestamp(),
    });

    return true;
  }

  String _buildDigest(List<Map<String, dynamic>> events) {
    final canonical = events
        .map((event) {
          final title = (event['title'] as String? ?? '').trim().toLowerCase();
          final date = (event['date'] as String? ?? '').trim().toLowerCase();
          final time = (event['time'] as String? ?? '').trim().toLowerCase();
          final venue = ((event['location'] ?? event['venue']) as String? ?? '')
              .trim()
              .toLowerCase();
          return '$title|$date|$time|$venue';
        })
        .toList(growable: false)
      ..sort();
    return sha1.convert(utf8.encode(canonical.join('||'))).toString();
  }

  bool _isBrisbaneArea(Map<String, dynamic> event) {
    final lat = _toDouble(event['latitude']);
    final lon = _toDouble(event['longitude']);
    if (lat != null && lon != null) {
      final distance = LocationUtilities.calculateDistance(
        lat1: _brisbaneLatitude,
        lon1: _brisbaneLongitude,
        lat2: lat,
        lon2: lon,
      );
      if (distance <= _brisbaneRadiusKm) {
        return true;
      }
    }

    final searchable = [
      event['location'],
      event['venue'],
      event['address'],
      event['suburb'],
      event['description'],
      event['title'],
    ].whereType<String>().join(' ').toLowerCase();

    return _brisbaneLocationKeywords.any(searchable.contains);
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

  DateTime? _tryParseEventDate(String raw) {
    final normalized = raw.trim();
    if (normalized.isEmpty) {
      return null;
    }

    final iso = DateTime.tryParse(normalized);
    if (iso != null) {
      return DateTime(iso.year, iso.month, iso.day);
    }

    final match = RegExp(r'^(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})$')
        .firstMatch(normalized);
    if (match == null) {
      return null;
    }

    final day = int.tryParse(match.group(1)!);
    final month = int.tryParse(match.group(2)!);
    var year = int.tryParse(match.group(3)!);
    if (day == null || month == null || year == null) {
      return null;
    }
    if (year < 100) {
      year += 2000;
    }

    try {
      return DateTime(year, month, day);
    } catch (_) {
      return null;
    }
  }
}