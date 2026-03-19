import 'package:brisconnect/models/discover_event.dart';
import 'package:brisconnect/models/food_place.dart';
import 'package:brisconnect/models/historical_sight.dart';

class DiscoverDataService {
  // Brisbane City Council events/open data integration placeholder.
  // Example source for future integration:
  // https://www.data.brisbane.qld.gov.au/
  Future<List<Event>> fetchCouncilEvents() async {
    return _mockCouncilEvents
        .map((item) => Event.fromJson(item))
        .toList(growable: false);
  }

  // Historical sights can be seeded from Brisbane heritage trails.
  Future<List<HistoricalSight>> fetchHistoricalSights() async {
    return _mockHistoricalSights
        .map((item) => HistoricalSight.fromJson(item))
        .toList(growable: false);
  }

  // Google Places API integration placeholder for future live food data.
  // Example endpoint style:
  // https://maps.googleapis.com/maps/api/place/nearbysearch/json
  // TODO: Inject API key securely via build config/env vars.
  Future<List<FoodPlace>> fetchFoodPlaces() async {
    return _mockFoodPlaces
        .map((item) => FoodPlace.fromJson(item))
        .toList(growable: false);
  }
}

const List<Map<String, dynamic>> _mockCouncilEvents = [
  {
    'id': 'bcc_1',
    'title': 'Brisbane Twilight Music in the Park',
    'date': 'Fri, 21 Mar 2026',
    'time': '6:30pm',
    'venue': 'Roma Street Parkland Stage',
    'suburb': 'Brisbane City',
    'imageUrl':
        'https://images.unsplash.com/photo-1459749411175-04bf5292ceea?auto=format&fit=crop&w=1200&q=80',
    'description':
        'Free live performances featuring local artists and community ensembles in a family-friendly setting.',
    'categories': ['Events', 'Culture', 'Family', 'Free', 'Outdoor'],
  },
  {
    'id': 'bcc_2',
    'title': 'South Bank Cultural Night Market',
    'date': 'Sat, 29 Mar 2026',
    'time': '5:00pm',
    'venue': 'Little Stanley Street',
    'suburb': 'South Brisbane',
    'imageUrl':
        'https://images.unsplash.com/photo-1472653431158-6364773b2a56?auto=format&fit=crop&w=1200&q=80',
    'description':
        'Explore artisan stalls, multicultural performances, and food experiences celebrating Brisbane communities.',
    'categories': ['Events', 'Culture', 'Food', 'Outdoor'],
  },
  {
    'id': 'bcc_3',
    'title': 'Brisbane Family River Festival',
    'date': 'Sun, 6 Apr 2026',
    'time': '10:00am',
    'venue': 'River Quay Green',
    'suburb': 'South Brisbane',
    'imageUrl':
        'https://images.unsplash.com/photo-1492684223066-81342ee5ff30?auto=format&fit=crop&w=1200&q=80',
    'description':
        'A day of performances, workshops, and riverfront activities inspired by Brisbane\'s upcoming Olympic spirit.',
    'categories': ['Events', 'Family', 'Outdoor'],
  },
];

const List<Map<String, dynamic>> _mockHistoricalSights = [
  {
    'id': 'heritage_1',
    'name': 'Brisbane City Hall',
    'location': 'King George Square, Brisbane City',
    'imageUrl':
        'https://images.unsplash.com/photo-1477512076069-d5746aa5b6f8?auto=format&fit=crop&w=1200&q=80',
    'description':
        'An iconic heritage landmark known for its sandstone facade, grand auditorium, and civic history.',
    'categories': ['Historical Sights', 'Heritage', 'Culture'],
  },
  {
    'id': 'heritage_2',
    'name': 'Old Windmill Tower',
    'location': 'Wickham Park, Spring Hill',
    'imageUrl':
        'https://images.unsplash.com/photo-1562774053-701939374585?auto=format&fit=crop&w=1200&q=80',
    'description':
        'One of Queensland\'s oldest convict-era structures, reflecting early colonial Brisbane history.',
    'categories': ['Historical Sights', 'Heritage'],
  },
  {
    'id': 'heritage_3',
    'name': 'Commissariat Store',
    'location': 'William Street, Brisbane City',
    'imageUrl':
        'https://images.unsplash.com/photo-1505693416388-ac5ce068fe85?auto=format&fit=crop&w=1200&q=80',
    'description':
        'A significant convict-built building now preserving stories from early European settlement.',
    'categories': ['Historical Sights', 'Heritage', 'Culture'],
  },
  {
    'id': 'heritage_4',
    'name': 'Story Bridge',
    'location': 'Kangaroo Point / Fortitude Valley',
    'imageUrl':
        'https://images.unsplash.com/photo-1517090504586-fde19ea6066f?auto=format&fit=crop&w=1200&q=80',
    'description':
        'A historic steel cantilever bridge and one of Brisbane\'s most recognisable architectural landmarks.',
    'categories': ['Historical Sights', 'Heritage', 'Outdoor'],
  },
  {
    'id': 'heritage_5',
    'name': 'Spring Hill Heritage Precinct',
    'location': 'Spring Hill',
    'imageUrl':
        'https://images.unsplash.com/photo-1511818966892-d7d671e672a2?auto=format&fit=crop&w=1200&q=80',
    'description':
        'A precinct of historic homes, churches, and streetscapes that reflect Brisbane\'s urban heritage.',
    'categories': ['Historical Sights', 'Heritage'],
  },
];

const List<Map<String, dynamic>> _mockFoodPlaces = [
  {
    'id': 'food_1',
    'name': 'Riverfront Kitchen',
    'cuisine': 'Modern Australian',
    'rating': 4.6,
    'suburb': 'South Brisbane',
    'imageUrl':
        'https://images.unsplash.com/photo-1552566626-52f8b828add9?auto=format&fit=crop&w=1200&q=80',
    'snippet':
        'Popular for local produce, seasonal menus, and relaxed views across the Brisbane River.',
    'mapQuery': 'Riverfront Kitchen South Brisbane',
    'categories': ['Food', 'Culture', 'Outdoor'],
  },
  {
    'id': 'food_2',
    'name': 'Laneway Espresso Bar',
    'cuisine': 'Cafe / Specialty Coffee',
    'rating': 4.5,
    'suburb': 'Fortitude Valley',
    'imageUrl':
        'https://images.unsplash.com/photo-1509042239860-f550ce710b93?auto=format&fit=crop&w=1200&q=80',
    'snippet':
        'A local favourite for brunch, specialty brews, and a distinctly Brisbane laneway vibe.',
    'mapQuery': 'Laneway Espresso Bar Fortitude Valley',
    'categories': ['Food', 'Family'],
  },
  {
    'id': 'food_3',
    'name': 'Market Street Dumpling House',
    'cuisine': 'Asian Fusion',
    'rating': 4.4,
    'suburb': 'Sunnybank',
    'imageUrl':
        'https://images.unsplash.com/photo-1473093295043-cdd812d0e601?auto=format&fit=crop&w=1200&q=80',
    'snippet':
        'Known for authentic flavours, handmade dumplings, and a lively community dining atmosphere.',
    'mapQuery': 'Market Street Dumpling House Sunnybank',
    'categories': ['Food', 'Culture'],
  },
];
