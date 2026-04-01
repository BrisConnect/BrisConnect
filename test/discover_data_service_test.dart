import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brisconnect/services/discover_data_service.dart';

void main() {
  group('DiscoverDataService', () {
    test('ensureSeeded writes discover items, attractions, and events',
        () async {
      final firestore = FakeFirebaseFirestore();
      final service = DiscoverDataService(firestore: firestore);

      await service.ensureSeeded();

      final discoverSnapshot = await firestore.collection('discover_items').get();
      final attractionsSnapshot = await firestore.collection('attractions').get();
      final eventsSnapshot = await firestore.collection('events').get();
      final seedSnapshot =
          await firestore.collection('seed_metadata').doc('discover_catalog_v1').get();

      expect(discoverSnapshot.docs, isNotEmpty);
      expect(attractionsSnapshot.docs, isNotEmpty);
      expect(eventsSnapshot.docs, isNotEmpty);
      expect(seedSnapshot.exists, isTrue);
    });

    test('fetch helpers return seeded events, sights, food, and stadiums',
        () async {
      final firestore = FakeFirebaseFirestore();
      final service = DiscoverDataService(firestore: firestore);

      await service.ensureSeeded();

      final events = await service.fetchCouncilEvents();
      final sights = await service.fetchHistoricalSights();
      final food = await service.fetchFoodPlaces();
      final stadiums = await service.fetchStadiumVenues();

      expect(events, isNotEmpty);
      expect(sights, isNotEmpty);
      expect(food, isNotEmpty);
      expect(stadiums, isNotEmpty);

      expect(events.first.categories, contains('Events'));
      expect(sights.first.categories, contains('Historical Sights'));
      expect(food.first.categories, contains('Food'));
      expect(stadiums.first.categories, contains('Stadiums'));
    });

    test('watchApprovedDiscoverItems returns only approved content', () async {
      final firestore = FakeFirebaseFirestore();
      final service =
          DiscoverDataService(firestore: firestore, enableSeedDefaults: false);

      await firestore.collection('discover_items').doc('approved_item').set({
        'title': 'Approved Brisbane Pick',
        'section': 'events',
        'approvalStatus': 'approved',
      });

      await firestore.collection('discover_items').doc('pending_item').set({
        'title': 'Pending Brisbane Pick',
        'section': 'food',
        'approvalStatus': 'pending',
      });

      final items = await service.watchApprovedDiscoverItems().first;

      expect(items.length, 1);
      expect(items.first['id'], 'approved_item');
      expect(items.first['title'], 'Approved Brisbane Pick');
    });
  });
}