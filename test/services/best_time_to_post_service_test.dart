import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brisconnect/models/audience_interaction.dart';
import 'package:brisconnect/services/audience_analytics_service.dart';
import 'package:brisconnect/services/best_time_to_post_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BestTimeToPostService', () {
    late FakeFirebaseFirestore fakeFirestore;
    late BestTimeToPostService service;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      service = BestTimeToPostService(firestore: fakeFirestore);
    });

    Future<DocumentReference> addBusiness({
      required String id,
      required String ownerId,
    }) async {
      return fakeFirestore.collection('businesses').doc(id)
        ..set({
          'ownerId': ownerId,
          'businessName': 'Test Business $id',
          'category': 'Restaurant',
          'description': 'A test business',
          'address': 'Brisbane',
          'contactNumber': '0000000000',
        });
    }

    Future<DocumentReference> addInteraction({
      required String businessId,
      required String ownerId,
      required String visitorId,
      required DateTime timestamp,
    }) async {
      return fakeFirestore.collection('audience_interactions').add({
        'businessId': businessId,
        'ownerId': ownerId,
        'visitorHash': AudienceAnalyticsService.anonymiseVisitorId(visitorId),
        'type': AudienceInteractionType.view.name,
        'timestamp': Timestamp.fromDate(timestamp),
      });
    }

    test('returns insufficient when owner has no businesses', () async {
      final result = await service.getRecommendations('owner_no_business');
      expect(result.hasEnoughData, isFalse);
    });

    test('returns insufficient with fewer than 14 days of history', () async {
      await addBusiness(id: 'b1', ownerId: 'owner@test.com');
      final now = DateTime.now();
      for (var i = 0; i < 5; i++) {
        await addInteraction(
          businessId: 'b1',
          ownerId: 'owner@test.com',
          visitorId: 'v$i',
          timestamp: now.subtract(Duration(days: i, hours: i)),
        );
      }

      final result = await service.getRecommendations('owner@test.com');
      expect(result.hasEnoughData, isFalse);
      expect(
        result.insufficientDataReason,
        contains('14 days'),
      );
    });

    test('returns recommendations when strong engagement pattern exists',
        () async {
      await addBusiness(id: 'b1', ownerId: 'owner@test.com');
      final base = DateTime.now().subtract(const Duration(days: 20));

      // Strong Friday 18:00 spike.
      for (var week = 0; week < 3; week++) {
        for (var i = 0; i < 10; i++) {
          await addInteraction(
            businessId: 'b1',
            ownerId: 'owner@test.com',
            visitorId: 'v_${week}_$i',
            timestamp: base.add(Duration(days: week * 7 + 4, hours: 18)),
          );
        }
      }

      // Low scattered noise on other days.
      for (var day = 0; day < 20; day++) {
        if (day % 7 == 4) continue;
        await addInteraction(
          businessId: 'b1',
          ownerId: 'owner@test.com',
          visitorId: 'noise_$day',
          timestamp: base.add(Duration(days: day, hours: day % 24)),
        );
      }

      final result = await service.getRecommendations('owner@test.com');
      expect(result.hasEnoughData, isTrue);
      expect(result.recommendations, isNotEmpty);
      // The injected spike is at hour 18 local time. Because `toLocal()` may
      // shift the hour for the test environment, assert the peak hour is within
      // a reasonable band around 18.
      expect(
        (result.recommendations.first.startHour - 18).abs(),
        lessThanOrEqualTo(2),
      );
      expect(result.recommendations.first.explanation, isNotEmpty);
    });

    test('warningForSchedule returns null inside recommended window', () async {
      final rec = PostRecommendation(
        dayOfWeek: DateTime.friday,
        startHour: 18,
        endHour: 20,
        engagementScore: 1.0,
        interactionCount: 30,
        explanation: 'test',
      );

      final warning = service.warningForSchedule(
        DateTime(2026, 7, 24, 19, 0), // Friday 7pm
        [rec],
      );
      expect(warning, isNull);
    });

    test('warningForSchedule returns soft warning outside recommended window',
        () async {
      final rec = PostRecommendation(
        dayOfWeek: DateTime.friday,
        startHour: 18,
        endHour: 20,
        engagementScore: 1.0,
        interactionCount: 30,
        explanation: 'test',
      );

      final warning = service.warningForSchedule(
        DateTime(2026, 7, 24, 10, 0), // Friday 10am
        [rec],
      );
      expect(warning, isNotNull);
      expect(warning, contains('less visibility'));
    });

    test('warningForSchedule returns null when no recommendations', () {
      final warning = service.warningForSchedule(
        DateTime.now(),
        const [],
      );
      expect(warning, isNull);
    });

    test('recommendations spread across different days when possible',
        () async {
      await addBusiness(id: 'b1', ownerId: 'owner@test.com');
      final base = DateTime.now().subtract(const Duration(days: 50));

      // Spread interactions across multiple weeks so history spans >=14 days.
      // Friday 18:00 spike.
      for (var week = 0; week < 3; week++) {
        for (var i = 0; i < 10; i++) {
          await addInteraction(
            businessId: 'b1',
            ownerId: 'owner@test.com',
            visitorId: 'fri_${week}_$i',
            timestamp: base.add(Duration(days: week * 7 + 4, hours: 18)),
          );
        }
      }
      // Saturday 12:00 spike.
      for (var week = 0; week < 3; week++) {
        for (var i = 0; i < 8; i++) {
          await addInteraction(
            businessId: 'b1',
            ownerId: 'owner@test.com',
            visitorId: 'sat_${week}_$i',
            timestamp: base.add(Duration(days: week * 7 + 5, hours: 12)),
          );
        }
      }
      // Sunday 20:00 spike.
      for (var week = 0; week < 3; week++) {
        for (var i = 0; i < 6; i++) {
          await addInteraction(
            businessId: 'b1',
            ownerId: 'owner@test.com',
            visitorId: 'sun_${week}_$i',
            timestamp: base.add(Duration(days: week * 7 + 6, hours: 20)),
          );
        }
      }

      // Scattered low-level noise on other day/hour cells so variance is
      // significant enough to pass the pattern threshold.
      for (var day = 0; day < 50; day++) {
        if (day % 7 >= 4) continue; // skip Friday-Sunday peaks
        await addInteraction(
          businessId: 'b1',
          ownerId: 'owner@test.com',
          visitorId: 'noise_$day',
          timestamp: base.add(Duration(days: day, hours: day % 24)),
        );
      }

      final result = await service.getRecommendations('owner@test.com');
      expect(result.hasEnoughData, isTrue);
      expect(result.recommendations.length, greaterThanOrEqualTo(2));

      // Ensure each recommendation points to a distinct day/hour pair,
      // tolerating local-time hour shifts.
      final pairs = result.recommendations
          .map((r) => '${r.dayOfWeek}:${r.startHour}')
          .toSet();
      expect(pairs.length, result.recommendations.length);

      // Verify at least one recommendation reflects one of the injected peaks.
      final matchesPeak = result.recommendations.any(
        (r) => [12, 18, 20].any((h) => (r.startHour - h).abs() <= 1),
      );
      expect(matchesPeak, isTrue);
    });
  });
}
