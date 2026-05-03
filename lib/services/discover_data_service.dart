import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:brisconnect/models/discover_event.dart';
import 'package:brisconnect/models/food_place.dart';
import 'package:brisconnect/models/historical_sight.dart';
import 'package:brisconnect/models/stadium_venue.dart';
import 'package:brisconnect/services/location_utilities.dart';

enum DiscoverSeedResult { seeded, alreadySeeded, permissionDenied, failed }

class DiscoverDataService {
  DiscoverDataService({
    FirebaseFirestore? firestore,
    bool enableSeedDefaults = true,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _enableSeedDefaults = enableSeedDefaults;

  final FirebaseFirestore _firestore;
  final bool _enableSeedDefaults;

  Future<DiscoverSeedResult> ensureSeeded() async {
    if (!_enableSeedDefaults) {
      return DiscoverSeedResult.alreadySeeded;
    }
    try {
      final seedDoc =
          _firestore.collection('seed_metadata').doc('discover_catalog_v10');
      final seedSnapshot = await seedDoc.get();
      if (seedSnapshot.exists) {
        return DiscoverSeedResult.alreadySeeded;
      }

      final batch = _firestore.batch();

      for (final item in _discoverSeedItems) {
        batch.set(
          _firestore.collection('discover_items').doc(item['id'] as String),
          item,
          SetOptions(merge: true),
        );
      }

      for (final item in _approvedAttractionSeedItems) {
        batch.set(
          _firestore.collection('attractions').doc(item['id'] as String),
          item,
          SetOptions(merge: true),
        );
      }

      for (final item in _eventSeedItems) {
        batch.set(
          _firestore.collection('events').doc(item['id'] as String),
          item,
          SetOptions(merge: true),
        );
      }

      batch.set(
        seedDoc,
        {
          'version': 1,
          'seededAt': FieldValue.serverTimestamp(),
          'discoverItemCount': _discoverSeedItems.length,
          'attractionCount': _approvedAttractionSeedItems.length,
          'eventCount': _eventSeedItems.length,
        },
        SetOptions(merge: true),
      );

      await batch.commit();
      debugPrint(
          '[DiscoverDataService] Seeded discovery catalog into Firestore.');
      return DiscoverSeedResult.seeded;
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        debugPrint('[DiscoverDataService] Seed denied by Firestore rules.');
        return DiscoverSeedResult.permissionDenied;
      }
      debugPrint('[DiscoverDataService] Seed skipped: $error');
      return DiscoverSeedResult.failed;
    } catch (error) {
      debugPrint('[DiscoverDataService] Seed skipped: $error');
      return DiscoverSeedResult.failed;
    }
  }

  Stream<List<Map<String, dynamic>>> watchApprovedDiscoverItems() {
    return _firestore
        .collection('discover_items')
        .where('approvalStatus', isEqualTo: 'approved')
        .snapshots()
        .map((snapshot) {
      final items = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          ...data,
          'id': (data['id'] as String?)?.trim().isNotEmpty == true
              ? data['id']
              : doc.id,
        };
      }).toList(growable: false);

      items.sort((a, b) {
        final aSection = (_sectionSortKey(a['section'] as String? ?? ''));
        final bSection = (_sectionSortKey(b['section'] as String? ?? ''));
        if (aSection != bSection) {
          return aSection.compareTo(bSection);
        }

        final aTitle = (a['title'] as String? ?? '').toLowerCase();
        final bTitle = (b['title'] as String? ?? '').toLowerCase();
        return aTitle.compareTo(bTitle);
      });

      return _deduplicateItems(items);
    });
  }

  /// Removes duplicate discover items that represent the same physical
  /// venue.  Duplicates arise when the same Google Place appears in both
  /// the attractions and events collections and also when seed data
  /// overlaps with Google-imported data.
  ///
  /// Dedup key priority: `sourcePlaceId` (if present) → normalised title.
  /// When two items share a key the one with a non-empty [imageUrl] or
  /// the one from a non-import source wins.
  static List<Map<String, dynamic>> _deduplicateItems(
    List<Map<String, dynamic>> items,
  ) {
    final seen = <String, Map<String, dynamic>>{};

    for (final item in items) {
      final sourcePlaceId =
          (item['sourcePlaceId'] as String? ?? '').trim();
      final title = (item['title'] as String? ?? '').trim().toLowerCase();
      if (title.isEmpty) continue;

      // Normalise title: strip trailing "(Venue)" / "(Place)" tags added
      // by the Google Places import function.
      final normTitle = title
          .replaceAll(RegExp(r'\s*\(venue\)\s*$', caseSensitive: false), '')
          .replaceAll(RegExp(r'\s*\(place\)\s*$', caseSensitive: false), '')
          .trim();

      final key =
          sourcePlaceId.isNotEmpty ? 'pid:$sourcePlaceId' : 'title:$normTitle';

      final existing = seen[key];
      if (existing == null) {
        seen[key] = item;
        continue;
      }

      // Prefer the item that is NOT a Google Places import (seed / manual
      // entries are typically more curated).
      final existingIsImport =
          (existing['sourceProvider'] as String? ?? '') == 'google_places';
      final currentIsImport =
          (item['sourceProvider'] as String? ?? '') == 'google_places';

      if (existingIsImport && !currentIsImport) {
        seen[key] = item;
        continue;
      }

      if (!existingIsImport && currentIsImport) {
        continue;
      }

      // Both are imports (or neither): prefer the one with a non-empty
      // imageUrl.
      final existingHasImage =
          (existing['imageUrl'] as String? ?? '').trim().isNotEmpty;
      final currentHasImage =
          (item['imageUrl'] as String? ?? '').trim().isNotEmpty;
      if (!existingHasImage && currentHasImage) {
        seen[key] = item;
      }
    }

    final deduped = seen.values.toList(growable: false);
    return deduped;
  }

  Future<List<Event>> fetchCouncilEvents() async {
    final items = await _fetchSection('events');
    return items
        .map(
          (item) => Event.fromJson({
            'id': item['id'],
            'title': item['title'],
            'date': item['date'],
            'time': item['time'],
            'venue': item['venue'],
            'suburb': item['suburb'],
            'imageUrl': item['imageUrl'],
            'description': item['description'],
            'categories': item['categories'],
            'aiAudio': item['aiAudio'] ?? '',
          }),
        )
        .toList(growable: false);
  }

  Future<List<HistoricalSight>> fetchHistoricalSights() async {
    final items = await _fetchSection('historical');
    return items
        .map(
          (item) => HistoricalSight.fromJson({
            'id': item['id'],
            'name': item['title'],
            'location': item['location'],
            'imageUrl': item['imageUrl'],
            'description': item['description'],
            'categories': item['categories'],
          }),
        )
        .toList(growable: false);
  }

  Future<List<FoodPlace>> fetchFoodPlaces() async {
    final items = await _fetchSection('food');
    return items
        .map(
          (item) => FoodPlace.fromJson({
            'id': item['id'],
            'name': item['title'],
            'cuisine': item['cuisine'],
            'rating': item['rating'],
            'suburb': item['suburb'],
            'imageUrl': item['imageUrl'],
            'snippet': item['description'],
            'mapQuery': item['mapQuery'],
            'categories': item['categories'],
            'aiAudio': item['aiAudio'] ?? '',
          }),
        )
        .toList(growable: false);
  }

  Future<List<StadiumVenue>> fetchStadiumVenues() async {
    final items = await _fetchSection('stadiums');
    return items
        .map(
          (item) => StadiumVenue.fromJson({
            'id': item['id'],
            'name': item['title'],
            'badge': item['badge'],
            'dateTime': item['dateTime'],
            'price': item['price'],
            'location': item['location'],
            'imageUrl': item['imageUrl'],
            'description': item['description'],
            'mapQuery': item['mapQuery'],
            'webLink': item['webLink'],
            'categories': item['categories'],
            'aiAudio': item['aiAudio'] ?? '',
          }),
        )
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> _fetchSection(String section) async {
    final snapshot = await _firestore
        .collection('discover_items')
        .where('approvalStatus', isEqualTo: 'approved')
        .where('section', isEqualTo: section)
        .get();

    final items = snapshot.docs
        .map((doc) => {...doc.data(), 'id': doc.id})
        .toList(growable: false);

    items.sort((a, b) {
      final aTitle = (a['title'] as String? ?? '').toLowerCase();
      final bTitle = (b['title'] as String? ?? '').toLowerCase();
      return aTitle.compareTo(bTitle);
    });

    return items;
  }

  List<Map<String, dynamic>> filterByRadius({
    required List<Map<String, dynamic>> items,
    required double? userLatitude,
    required double? userLongitude,
    required int radiusKm,
  }) {
    if (userLatitude == null || userLongitude == null) {
      return items;
    }

    return items.where((item) {
      final latitude = _toDouble(item['latitude']);
      final longitude = _toDouble(item['longitude']);
      if (latitude == null || longitude == null) {
        return true;
      }

      final distanceKm = LocationUtilities.calculateDistance(
        lat1: userLatitude,
        lon1: userLongitude,
        lat2: latitude,
        lon2: longitude,
      );
      return distanceKm <= radiusKm;
    }).toList(growable: false);
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

  static int _sectionSortKey(String section) {
    switch (section) {
      case 'events':
        return 0;
      case 'historical':
        return 1;
      case 'food':
        return 2;
      case 'stadiums':
        return 3;
      default:
        return 99;
    }
  }
}

const List<Map<String, dynamic>> _discoverSeedItems = [
  {
    'id': 'discover_event_bands_in_parks',
    'section': 'events',
    'title': 'Bands in Parks',
    'badge': 'Cultural Event',
    'date': 'Check schedule',
    'time': 'Weekend sessions',
    'dateTime': 'Check official schedule',
    'venue': 'New Farm Park Rotunda',
    'suburb': 'New Farm',
    'location': 'New Farm Park Rotunda, New Farm',
    'price': 'Free',
    'imageUrl':
        'https://images.unsplash.com/photo-1533174072545-7a4b6ad7a6c3?auto=format&fit=crop&w=1400&q=80',
    'description':
        'A recurring Brisbane City Council community music program featuring local bands in park settings across Brisbane.',
    'culturalBackground':
        "Brisbane's Bands in Parks program has a rich history dating back to the early 20th century, reflecting the city's tradition of community gathering in public green spaces. Queensland's subtropical climate has long shaped a culture of outdoor performance, where live music in parkland settings strengthens local community ties and celebrates the city's diverse musical traditions.",
    'audioUrl': '',
    'aiAudio':
        'Welcome to Bands in Parks ΓÇö one of Brisbane\'s most cherished free weekend traditions. '
        'Head to New Farm Park Rotunda on the weekend and you will find local musicians filling the air with live performance under the trees. '
        'This program has been part of Brisbane\'s community spirit for over a century, connecting residents and visitors in one of the city\'s most beautiful green spaces. '
        'No ticket needed ΓÇö just find a spot on the grass and enjoy the sounds of Brisbane.',
    'categories': ['Events', 'Culture', 'Family', 'Free', 'Outdoor'],
    'webLink':
        'https://www.brisbane.qld.gov.au/things-to-see-and-do/council-venues-and-precincts/parks/bands-in-parks',
    'mapQuery': 'New Farm Park Rotunda Brisbane',
    'latitude': -27.4679,
    'longitude': 153.0454,
    'approvalStatus': 'approved',
    'source': 'Brisbane City Council',
  },
  {
    'id': 'discover_event_clock_tower_tours',
    'section': 'events',
    'title': 'Clock Tower Tours at Brisbane City Hall',
    'badge': 'Cultural Event',
    'date': 'Check schedule',
    'time': 'Daily tours',
    'dateTime': 'Check official schedule',
    'venue': 'Brisbane City Hall',
    'suburb': 'Brisbane City',
    'location': 'Brisbane City Hall, King George Square',
    'price': 'Free',
    'imageUrl':
      'https://images.unsplash.com/photo-1568992687947-868a62a9f521?auto=format&fit=crop&w=1400&q=80',
    'description':
        'A central-city heritage experience with guided access to the historic clock tower and city views when tours are available.',
    'culturalBackground':
        "Brisbane City Hall, completed in 1930, embodies the civic aspirations of early Queensland. Designed in Italian Renaissance style, the building served as a symbol of local governance and community pride. The clock tower's clockface was one of the largest in Australia at the time, and guided tours continue to connect Brisbanites and visitors with their shared civic heritage.",
    'audioUrl': '',
    'aiAudio':
        'Welcome to Brisbane City Hall ΓÇö a grand sandstone landmark at the heart of King George Square. '
        'Completed in 1930 in Italian Renaissance style, this civic building has watched the city transform across nearly a century of history. '
        'Free guided tours take you up into the historic clock tower, offering sweeping views across the CBD. '
        'At the time of its opening, the clock face was one of the largest in Australia. '
        'It is a piece of Brisbane history well worth your time.',
    'categories': ['Events', 'Culture', 'Heritage', 'Free'],
    'webLink': 'https://www.museumofbrisbane.com.au/',
    'mapQuery': 'Brisbane City Hall King George Square',
    'latitude': -27.4689,
    'longitude': 153.0235,
    'approvalStatus': 'approved',
    'source': 'Brisbane City Council / Museum of Brisbane',
  },
  {
    'id': 'discover_event_riverstage_program',
    'section': 'events',
    'title': 'Riverstage Live Program',
    'badge': 'Cultural Event',
    'date': 'Seasonal program',
    'time': 'Evening sessions',
    'dateTime': 'Seasonal program',
    'venue': 'Riverstage',
    'suburb': 'Brisbane City',
    'location': 'Riverstage, City Botanic Gardens',
    'price': 'Paid / Free mix',
    'imageUrl':
        'https://images.unsplash.com/photo-1429962714451-bb934ecdc4ec?auto=format&fit=crop&w=1400&q=80',
    'description':
        'A major outdoor performance venue used for concerts and civic cultural programming in the City Botanic Gardens precinct.',
    'culturalBackground':
        "The City Botanic Gardens, where Riverstage is situated, hold deep cultural significance for both the Indigenous Yuggera and Turrbal peoples and for Brisbane's settler history. Theatrical and musical performances in this riverside precinct celebrate Brisbane's transition from colonial outpost to cosmopolitan host city, with the Brisbane River itself serving as a central thread of the region's cultural identity.",
    'audioUrl': '',
    'aiAudio':
        'Welcome to Riverstage ΓÇö Brisbane\'s most beloved outdoor performance venue, nestled inside the City Botanic Gardens along the river. '
        'This is where the city gathers for concerts, live events, and cultural celebrations with the Brisbane River as a backdrop. '
        'The gardens here carry deep significance for the Yuggera and Turrbal peoples, and this venue marks Brisbane\'s evolution from a quiet river settlement into a cultural capital. '
        'Check the event program to catch what\'s on during your visit.',
    'categories': ['Events', 'Culture', 'Outdoor'],
    'webLink':
        'https://www.brisbane.qld.gov.au/things-to-see-and-do/council-venues-and-precincts/venues/riverstage',
    'mapQuery': 'Riverstage Brisbane',
    'latitude': -27.4752,
    'longitude': 153.0307,
    'approvalStatus': 'approved',
    'source': 'Brisbane City Council',
  },
  {
    'id': 'discover_historical_city_hall',
    'section': 'historical',
    'title': 'Brisbane City Hall',
    'badge': 'Historical',
    'dateTime': 'Open daily',
    'price': 'Free',
    'location': 'King George Square, Brisbane City',
    'imageUrl': 'https://images.unsplash.com/photo-1568992687947-868a62a9f521?auto=format&fit=crop&w=1400&q=80',
    'description':
        'A landmark civic building known for its sandstone exterior, heritage interiors, and role in Brisbane public life.',
    'categories': ['Historical Sights', 'Heritage', 'Culture'],
    'webLink':
        'https://www.brisbane.qld.gov.au/things-to-see-and-do/council-venues-and-precincts/venues/brisbane-city-hall',
    'mapQuery': 'Brisbane City Hall King George Square',
    'latitude': -27.4689,
    'longitude': 153.0235,
    'approvalStatus': 'approved',
    'source': 'Brisbane City Council',
    'aiAudio':
        'Welcome to Brisbane City Hall ΓÇö the sandstone centrepiece of King George Square. '
        'Completed in 1930, this Italian Renaissance building reflects the civic pride and ambition of early Queensland. '
        'It is free to enter and open daily, with the Museum of Brisbane and the famous clock tower tours available inside. '
        'Standing here, you are at the symbolic and geographic heart of Brisbane\'s public life.',
  },
  {
    'id': 'discover_historical_old_windmill',
    'section': 'historical',
    'title': 'Old Windmill Tower',
    'badge': 'Historical',
    'dateTime': 'Open grounds',
    'price': 'Free',
    'location': 'Wickham Park, Spring Hill',
    'imageUrl': 'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?auto=format&fit=crop&w=1400&q=80',
    'description':
        'A convict-era tower in Spring Hill that remains one of the oldest surviving built structures in Queensland.',
    'categories': ['Historical Sights', 'Heritage'],
    'webLink':
        'https://www.brisbane.qld.gov.au/things-to-see-and-do/outdoor-activities/parks/old-windmill-observatory-and-wickham-park',
    'mapQuery': 'Old Windmill Tower Spring Hill',
    'latitude': -27.4632,
    'longitude': 153.0351,
    'approvalStatus': 'approved',
    'source': 'Brisbane City Council',
    'aiAudio':
        'Welcome to the Old Windmill Tower in Spring Hill ΓÇö one of the oldest surviving structures in Queensland. '
        'Built using convict labour in the 1820s, the tower was originally designed to grind grain, though the windmill mechanism never worked reliably. '
        'Over the decades it became a signal tower, then a fire lookout, and eventually a television broadcast point. '
        'Today it stands as a quiet heritage marker in Wickham Park, free to visit and easy to reach from the city.',
  },
  {
    'id': 'discover_historical_story_bridge',
    'section': 'historical',
    'title': 'Story Bridge',
    'badge': 'Historical',
    'dateTime': 'Always accessible',
    'price': 'Free',
    'location': 'Kangaroo Point / Fortitude Valley',
    'imageUrl': 'https://images.unsplash.com/photo-1449824913935-59a10b8d2000?auto=format&fit=crop&w=1400&q=80',
    'description':
        'A heritage-listed steel cantilever bridge that has become one of BrisbaneΓÇÖs most recognisable city structures.',
    'categories': ['Historical Sights', 'Heritage', 'Outdoor'],
    'webLink':
        'https://www.brisbane.qld.gov.au/traffic-and-transport/bridges-tunnels-and-ferries/bridges/story-bridge',
    'mapQuery': 'Story Bridge Brisbane',
    'latitude': -27.4614,
    'longitude': 153.0348,
    'approvalStatus': 'approved',
    'source': 'Brisbane City Council',
    'aiAudio':
        'Welcome to the Story Bridge ΓÇö Brisbane\'s most iconic steel landmark, spanning the river between Kangaroo Point and Fortitude Valley. '
        'Completed in 1940, it was among the last major infrastructure projects funded through Depression-era public works investment in Australia. '
        'Now heritage-listed and home to bridge climbing experiences, it forms the centrepiece of one of the most photographed views in Queensland. '
        'Whether you see it from the riverside or walk across it, this bridge is as central to Brisbane\'s identity as the river it crosses.',
  },
  {
    'id': 'discover_food_howard_smith_wharves',
    'section': 'food',
    'title': 'Howard Smith Wharves Dining Precinct',
    'badge': 'Food',
    'cuisine': 'Dining precinct',
    'rating': 0.0,
    'suburb': 'Brisbane City',
    'dateTime': 'Open daily',
    'price': 'Paid',
    'location': 'Howard Smith Wharves, Brisbane River',
    'imageUrl': 'https://images.unsplash.com/photo-1414235077428-338989a2e8c0?auto=format&fit=crop&w=1400&q=80',
    'description':
        'A riverfront hospitality precinct with varied dining options, bridge views, and easy pedestrian access from the CBD.',
    'categories': ['Food', 'Culture', 'Outdoor'],
    'webLink': 'https://maps.google.com/?q=Howard+Smith+Wharves+Brisbane',
    'mapQuery': 'Howard Smith Wharves Brisbane',
    'latitude': -27.4614,
    'longitude': 153.0348,
    'approvalStatus': 'approved',
    'source': 'Google Maps',
    'aiAudio':
        'Welcome to Howard Smith Wharves ΓÇö a riverside dining precinct sitting directly beneath the Story Bridge along the Brisbane River. '
        'Once the city\'s industrial freight wharf, this heritage stretch has been transformed into one of Brisbane\'s most visited destinations for food, drink, and waterfront atmosphere. '
        'From rooftop bars with bridge views to riverfront restaurants and casual outdoor terraces, the combination of heritage architecture and the river setting makes this one of the most memorable dining experiences the city has to offer.',
  },
  {
    'id': 'discover_food_eat_street',
    'section': 'food',
    'title': 'Eat Street Northshore',
    'badge': 'Food',
    'cuisine': 'Street food market',
    'rating': 0.0,
    'suburb': 'Hamilton',
    'dateTime': 'Evening trading',
    'price': 'Paid',
    'location': 'Northshore, Hamilton',
    'imageUrl': 'https://images.unsplash.com/photo-1539136788836-5699e78bfc75?auto=format&fit=crop&w=1400&q=80',
    'description':
        'A destination food market known for international street food, night-time atmosphere, and riverfront views.',
    'categories': ['Food', 'Family', 'Culture'],
    'webLink': 'https://maps.google.com/?q=Eat+Street+Northshore+Hamilton',
    'mapQuery': 'Eat Street Northshore Hamilton',
    'latitude': -27.4385,
    'longitude': 153.0691,
    'approvalStatus': 'approved',
    'source': 'Google Maps',
    'aiAudio':
        'Welcome to Eat Street Northshore in Hamilton ΓÇö Brisbane\'s famous shipping container food market. '
        'More than 180 vendors are packed into converted containers along the riverfront, serving food from around the world, from wood-fired pizza to Asian street food to Belgian waffles. '
        'The Friday and Saturday night atmosphere is electric, with fairy lights, live music, and river breezes making this one of Brisbane\'s most unique food experiences. '
        'Check the trading schedule before you go, as it operates on select nights.',
  },
  {
    'id': 'discover_food_sunnybank_market_square',
    'section': 'food',
    'title': 'Sunnybank Market Square Dining',
    'badge': 'Food',
    'cuisine': 'Asian dining precinct',
    'rating': 0.0,
    'suburb': 'Sunnybank',
    'dateTime': 'Open daily',
    'price': 'Paid',
    'location': 'Market Square, Sunnybank',
    'imageUrl': 'https://images.unsplash.com/photo-1563245372-f21724e3856d?auto=format&fit=crop&w=1400&q=80',
    'description':
        'A well-known southside food precinct with dense restaurant choices and late-night dining activity.',
    'categories': ['Food', 'Culture'],
    'webLink': 'https://maps.google.com/?q=Market+Square+Sunnybank',
    'mapQuery': 'Market Square Sunnybank',
    'latitude': -27.5739,
    'longitude': 153.0582,
    'approvalStatus': 'approved',
    'source': 'Google Maps',
    'aiAudio':
        'Welcome to Sunnybank Market Square ΓÇö the beating heart of Brisbane\'s Asian food scene. '
        'Sunnybank has long been home to one of the most vibrant Chinese, Vietnamese, and pan-Asian communities in Queensland. '
        'The Market Square precinct and surrounding streets are packed with dozens of restaurants, hot pot spots, bubble tea shops, and night market stalls. '
        'If you want an authentic taste of Brisbane\'s multicultural food culture, this is the place to be, especially on weekend evenings.',
  },
  {
    'id': 'discover_stadium_suncorp',
    'section': 'stadiums',
    'title': 'Suncorp Stadium',
    'badge': 'Stadium',
    'dateTime': 'Match and event schedule',
    'price': 'Paid',
    'location': 'Milton',
    'imageUrl': 'https://images.unsplash.com/photo-1540747913346-19e32dc3e97e?auto=format&fit=crop&w=1400&q=80',
    'description':
        'A major rectangular stadium in Milton used for football, rugby league, rugby union, and large-scale live events.',
    'categories': ['Stadiums', 'Events'],
    'webLink': 'https://maps.google.com/?q=Suncorp+Stadium+Milton',
    'mapQuery': 'Suncorp Stadium Milton',
    'latitude': -27.4648,
    'longitude': 152.9975,
    'approvalStatus': 'approved',
    'source': 'Google Maps',
    'aiAudio':
        'Welcome to Suncorp Stadium in Milton ΓÇö one of Australia\'s most celebrated major venues. '
        'With a capacity of over 52,000, this is where you come for State of Origin, Brisbane Broncos NRL matches, Queensland Reds rugby, and some of the biggest concerts to visit Brisbane. '
        'The atmosphere on a full-house night here is genuinely electric. '
        'Train connections from Roma Street make it easy to reach without a car. '
        'Check the event calendar and book early ΓÇö the popular events here sell out fast.',
  },
  {
    'id': 'discover_stadium_gabba',
    'section': 'stadiums',
    'title': 'The Gabba',
    'badge': 'Stadium',
    'dateTime': 'Match and event schedule',
    'price': 'Paid',
    'location': 'Woolloongabba',
    'imageUrl': 'https://images.unsplash.com/photo-1531415074968-036ba1b575da?auto=format&fit=crop&w=1400&q=80',
    'description':
        'BrisbaneΓÇÖs long-established cricket and AFL venue, anchored in the Woolloongabba sporting precinct.',
    'categories': ['Stadiums', 'Events'],
    'webLink': 'https://maps.google.com/?q=The+Gabba+Woolloongabba',
    'mapQuery': 'The Gabba Woolloongabba',
    'latitude': -27.4858,
    'longitude': 153.0381,
    'approvalStatus': 'approved',
    'source': 'Google Maps',
    'aiAudio':
        'Welcome to The Gabba in Woolloongabba ΓÇö Brisbane\'s legendary cricket and AFL ground. '
        'The venue has hosted Test cricket since 1931, and with the 2032 Brisbane Olympics approaching, the entire precinct is being redeveloped into a world-class athletics and stadium complex. '
        'It is the home ground of the AFL\'s Brisbane Lions, and a venue with a proud reputation for intense sporting occasions. '
        'A short bus or train ride from the city centre, The Gabba sits at the heart of Brisbane\'s south side sporting identity.',
  },
  {
    'id': 'discover_stadium_ballymore',
    'section': 'stadiums',
    'title': 'Ballymore Stadium',
    'badge': 'Stadium',
    'dateTime': 'Event schedule',
    'price': 'Paid / Free mix',
    'location': 'Herston',
    'imageUrl': 'https://images.unsplash.com/photo-1487466365202-1afdb86c764e?auto=format&fit=crop&w=1400&q=80',
    'description':
        'A well-known rugby venue in Herston that remains part of BrisbaneΓÇÖs broader major-events and training network.',
    'categories': ['Stadiums', 'Events'],
    'webLink': 'https://maps.google.com/?q=Ballymore+Stadium+Herston',
    'mapQuery': 'Ballymore Stadium Herston',
    'latitude': -27.4448,
    'longitude': 153.0156,
    'approvalStatus': 'approved',
    'source': 'Google Maps',
    'aiAudio':
        'Welcome to Ballymore Stadium in Herston ΓÇö the traditional home of Queensland rugby union. '
        'While Suncorp Stadium hosts the big test matches, Ballymore carries the history. '
        'The Queensland Reds built their identity here, Australian Wallabies have trained on these grounds for decades, and the close-up atmosphere of the smaller stands gives this venue a distinctive community rugby feel. '
        'Keep an eye on the Super Rugby and club fixture schedules for upcoming matches.',
  },
];

const List<Map<String, dynamic>> _approvedAttractionSeedItems = [
  {
    'id': 'attraction_city_hall',
    'name': 'Brisbane City Hall',
    'description':
        'A landmark civic building known for its sandstone exterior, heritage interiors, and role in Brisbane public life.',
    'location': 'King George Square, Brisbane City',
    'latitude': -27.4689,
    'longitude': 153.0235,
    'category': 'Historical',
    'approvalStatus': 'approved',
    'imageUrl':
        'https://images.unsplash.com/photo-1568992687947-868a62a9f521?auto=format&fit=crop&w=1400&q=80',
    'webLink':
        'https://www.brisbane.qld.gov.au/things-to-see-and-do/council-venues-and-precincts/venues/brisbane-city-hall',
  },
  {
    'id': 'attraction_story_bridge',
    'name': 'Story Bridge',
    'description':
        'A heritage-listed steel cantilever bridge that has become one of BrisbaneΓÇÖs most recognisable city structures.',
    'location': 'Story Bridge, Brisbane',
    'latitude': -27.4632,
    'longitude': 153.0351,
    'category': 'Historical',
    'approvalStatus': 'approved',
    'imageUrl':
        'https://images.unsplash.com/photo-1566734904496-9309bb1798ae?auto=format&fit=crop&w=1400&q=80',
    'webLink':
        'https://www.brisbane.qld.gov.au/traffic-and-transport/bridges-tunnels-and-ferries/bridges/story-bridge',
  },
  {
    'id': 'attraction_hsw_food',
    'name': 'Howard Smith Wharves Dining Precinct',
    'description':
        'A riverfront hospitality precinct with varied dining options, bridge views, and easy pedestrian access from the CBD.',
    'location': 'Howard Smith Wharves, Brisbane City',
    'latitude': -27.4614,
    'longitude': 153.0348,
    'category': 'Food',
    'approvalStatus': 'approved',
    'imageUrl':
        'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?auto=format&fit=crop&w=1400&q=80',
    'webLink': 'https://maps.google.com/?q=Howard+Smith+Wharves+Brisbane',
  },
  {
    'id': 'attraction_eat_street',
    'name': 'Eat Street Northshore',
    'description':
        'A destination food market known for international street food, night-time atmosphere, and riverfront views.',
    'location': 'Northshore, Hamilton',
    'latitude': -27.4385,
    'longitude': 153.0691,
    'category': 'Food',
    'approvalStatus': 'approved',
    'imageUrl':
        'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?auto=format&fit=crop&w=1400&q=80',
    'webLink': 'https://maps.google.com/?q=Eat+Street+Northshore+Hamilton',
  },
  {
    'id': 'attraction_suncorp',
    'name': 'Suncorp Stadium',
    'description':
        'A major rectangular stadium in Milton used for football, rugby league, rugby union, and large-scale live events.',
    'location': 'Milton',
    'latitude': -27.4648,
    'longitude': 152.9975,
    'category': 'Stadium',
    'approvalStatus': 'approved',
    'imageUrl':
        'https://images.unsplash.com/photo-1577223625816-7546f13df25d?auto=format&fit=crop&w=1400&q=80',
    'webLink': 'https://maps.google.com/?q=Suncorp+Stadium+Milton',
  },
  {
    'id': 'attraction_gabba',
    'name': 'The Gabba',
    'description':
        'BrisbaneΓÇÖs long-established cricket and AFL venue, anchored in the Woolloongabba sporting precinct.',
    'location': 'Woolloongabba',
    'latitude': -27.4858,
    'longitude': 153.0381,
    'category': 'Stadium',
    'approvalStatus': 'approved',
    'imageUrl':
        'https://images.unsplash.com/photo-1540747913346-19e32dc3e97e?auto=format&fit=crop&w=1400&q=80',
    'webLink': 'https://maps.google.com/?q=The+Gabba+Woolloongabba',
  },
];

const List<Map<String, dynamic>> _eventSeedItems = [
  {
    'id': 'seed_event_bands_in_parks',
    'title': 'Bands in Parks',
    'description':
        'A recurring Brisbane City Council community music program featuring local bands in park settings across Brisbane.',
    'dateTime': 'Check official schedule',
    'location': 'New Farm Park Rotunda, New Farm',
    'price': 'Free',
    'imageUrl': 'https://images.unsplash.com/photo-1533174072545-7a4b6ad7a6c3?auto=format&fit=crop&w=1400&q=80',
    'badge': 'Cultural Event',
    'webLink':
        'https://www.brisbane.qld.gov.au/things-to-see-and-do/council-venues-and-precincts/parks/bands-in-parks',
    'latitude': -27.4679,
    'longitude': 153.0454,
    'reviewStatus': 'approved',
  },
  {
    'id': 'seed_event_clock_tower_tours',
    'title': 'Clock Tower Tours at Brisbane City Hall',
    'description':
        'A central-city heritage experience with guided access to the historic clock tower and city views when tours are available.',
    'dateTime': 'Check official schedule',
    'location': 'Brisbane City Hall, King George Square',
    'price': 'Free',
    'imageUrl': 'https://images.unsplash.com/photo-1568992687947-868a62a9f521?auto=format&fit=crop&w=1400&q=80',
    'badge': 'Cultural Event',
    'webLink': 'https://www.museumofbrisbane.com.au/',
    'latitude': -27.4689,
    'longitude': 153.0235,
    'reviewStatus': 'approved',
  },
  {
    'id': 'seed_event_riverstage_program',
    'title': 'Riverstage Live Program',
    'description':
        'A major outdoor performance venue used for concerts and civic cultural programming in the City Botanic Gardens precinct.',
    'dateTime': 'Seasonal program',
    'location': 'Riverstage, City Botanic Gardens',
    'price': 'Paid / Free mix',
    'imageUrl': 'https://images.unsplash.com/photo-1429962714451-bb934ecdc4ec?auto=format&fit=crop&w=1400&q=80',
    'badge': 'Cultural Event',
    'webLink':
        'https://www.brisbane.qld.gov.au/things-to-see-and-do/council-venues-and-precincts/venues/riverstage',
    'latitude': -27.4752,
    'longitude': 153.0307,
    'reviewStatus': 'approved',
  },
];
