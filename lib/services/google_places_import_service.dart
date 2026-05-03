import 'package:cloud_functions/cloud_functions.dart';

class GooglePlacesImportSummary {
  const GooglePlacesImportSummary({
    required this.radiusKm,
    required this.attractionCount,
    required this.eventCount,
    required this.writeCount,
  });

  final num radiusKm;
  final int attractionCount;
  final int eventCount;
  final int writeCount;

  factory GooglePlacesImportSummary.fromMap(Map<String, dynamic> map) {
    final rawRadius = map['radiusKm'];
    final rawAttractions = map['attractionCount'];
    final rawEvents = map['eventCount'];
    final rawWrites = map['writeCount'];

    return GooglePlacesImportSummary(
      radiusKm: rawRadius is num ? rawRadius : 30,
      attractionCount: rawAttractions is num ? rawAttractions.toInt() : 0,
      eventCount: rawEvents is num ? rawEvents.toInt() : 0,
      writeCount: rawWrites is num ? rawWrites.toInt() : 0,
    );
  }
}

class DiscoverItemsConversionSummary {
  const DiscoverItemsConversionSummary({
    required this.discoveredAttractions,
    required this.discoveredEvents,
    required this.itemCount,
    required this.writeCount,
  });

  final int discoveredAttractions;
  final int discoveredEvents;
  final int itemCount;
  final int writeCount;

  factory DiscoverItemsConversionSummary.fromMap(Map<String, dynamic> map) {
    final rawAttractions = map['discoveredAttractions'];
    final rawEvents = map['discoveredEvents'];
    final rawItems = map['itemCount'];
    final rawWrites = map['writeCount'];

    return DiscoverItemsConversionSummary(
      discoveredAttractions:
          rawAttractions is num ? rawAttractions.toInt() : 0,
      discoveredEvents: rawEvents is num ? rawEvents.toInt() : 0,
      itemCount: rawItems is num ? rawItems.toInt() : 0,
      writeCount: rawWrites is num ? rawWrites.toInt() : 0,
    );
  }
}

class GooglePlacesImportService {
  GooglePlacesImportService({FirebaseFunctions? functions})
      : _functions = functions ??
            FirebaseFunctions.instanceFor(region: 'australia-southeast1');

  final FirebaseFunctions _functions;

  Future<GooglePlacesImportSummary> importWithinBrisbaneRadius() async {
    final callable = _functions.httpsCallable('importGooglePlacesCatalog');
    final response = await callable.call<Map<String, dynamic>>();

    final data = response.data;

    return GooglePlacesImportSummary.fromMap(data);
  }

  Future<DiscoverItemsConversionSummary> convertImportedToDiscoverItems() async {
    final callable =
        _functions.httpsCallable('convertGooglePlacesToDiscoverItems');
    final response = await callable.call<Map<String, dynamic>>();

    final data = response.data;

    return DiscoverItemsConversionSummary.fromMap(data);
  }
}

