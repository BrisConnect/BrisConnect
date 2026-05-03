import 'dart:math' as math;

/// Utility class for location-based distance calculations and filtering.
class LocationUtilities {
  /// Default location (Brisbane CBD) used when location services are unavailable.
  static const double defaultLatitude = -27.4698;
  static const double defaultLongitude = 153.0251;

  /// Calculates the great-circle distance between two geographic points
  /// using the Haversine formula.
  ///
  /// Returns distance in kilometers.
  ///
  /// Parameters:
  /// - lat1, lon1: Starting point (user's location)
  /// - lat2, lon2: Ending point (attraction/event location)
  static double calculateDistance({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    const double earthRadiusKm = 6371.0;

    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);

    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadiusKm * c;
  }

  /// Converts degrees to radians
  static double _toRadians(double degrees) {
    return degrees * (math.pi / 180.0);
  }

  /// Checks if a location is within the specified radius from user location
  static bool isWithinRadius({
    required double userLat,
    required double userLon,
    required double targetLat,
    required double targetLon,
    required int radiusKm,
  }) {
    final double distance = calculateDistance(
      lat1: userLat,
      lon1: userLon,
      lat2: targetLat,
      lon2: targetLon,
    );
    return distance <= radiusKm;
  }

  /// Filters a list of items by distance from user location
  ///
  /// Generic type T should have getters for latitude and longitude
  static List<T> filterByRadius<T>({
    required List<T> items,
    required double userLat,
    required double userLon,
    required int radiusKm,
    required double Function(T) getLatitude,
    required double Function(T) getLongitude,
  }) {
    return items.where((item) {
      return isWithinRadius(
        userLat: userLat,
        userLon: userLon,
        targetLat: getLatitude(item),
        targetLon: getLongitude(item),
        radiusKm: radiusKm,
      );
    }).toList(growable: false);
  }

  /// Validates latitude is within valid range
  static bool isValidLatitude(double lat) {
    return lat >= -90.0 && lat <= 90.0;
  }

  /// Validates longitude is within valid range
  static bool isValidLongitude(double lon) {
    return lon >= -180.0 && lon <= 180.0;
  }

  /// Validates both latitude and longitude
  static bool isValidCoordinate(double lat, double lon) {
    return isValidLatitude(lat) && isValidLongitude(lon);
  }

  /// Gets the default Brisbane CBD location
  static (double, double) getDefaultLocation() {
    return (defaultLatitude, defaultLongitude);
  }
}
