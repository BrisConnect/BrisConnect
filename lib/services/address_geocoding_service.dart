import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:brisconnect/services/google_places_autocomplete_service.dart';

/// Service for geocoding addresses to coordinates and validating addresses
class AddressGeocodingService {
  final GooglePlacesAutocompleteService _placesService =
      GooglePlacesAutocompleteService();

  /// Geocode an address string to coordinates using Google Places API.
  /// Returns a LatLng if successful, or null if the address is invalid.
  /// Falls back to suburb-level estimation when the Places backend is unavailable.
  Future<LatLng?> geocodeAddress(String address) async {
    try {
      // Try to get precise coordinates via Google Places Details first.
      final placeId = await _placesService.fetchPlaceId(address);
      if (placeId != null) {
        final details = await _placesService.fetchPlaceDetails(placeId);
        if (details != null) {
          return LatLng(details.lat, details.lng);
        }
      }

      // Fall back to the autocomplete suggestions list and rough suburb estimation.
      final predictions = await _placesService.fetchBrisbaneAddressSuggestions(address);
      if (predictions.isEmpty) {
        return null;
      }
      return _estimateCoordinatesFromAddress(address);
    } catch (e) {
      return null;
    }
  }

  /// Estimate coordinates from address based on patterns
  /// This is a simplified approach for Brisbane-specific businesses
  LatLng? _estimateCoordinatesFromAddress(String address) {
    // Default to Brisbane CBD if unable to extract specific coordinates
    // In production, integrate with Google Places Details API for precise coords
    final lowerAddress = address.toLowerCase();
    
    // Known Brisbane suburbs and their approximate coordinates
    final suburbCoords = {
      'south bank': LatLng(-27.4849, 153.0282),
      'brisbane cbd': LatLng(-27.4698, 153.0251),
      'fortitude valley': LatLng(-27.4537, 153.0402),
      'west end': LatLng(-27.4947, 153.0085),
      'paddington': LatLng(-27.4663, 153.0085),
      'kangaroo point': LatLng(-27.4818, 153.0489),
      'new farm': LatLng(-27.4580, 153.0686),
      'ascot': LatLng(-27.4293, 153.1073),
      'woolowin': LatLng(-27.4102, 153.1072),
      'stone corner': LatLng(-27.4205, 153.0970),
      'red hill': LatLng(-27.5072, 153.0111),
      'sherwood': LatLng(-27.5286, 153.0217),
      'mount gravatt': LatLng(-27.5456, 153.0794),
      'mansfield': LatLng(-27.5584, 153.1256),
      'sunnybank': LatLng(-27.5528, 152.9994),
      'salisbury': LatLng(-27.7070, 153.0391),
      'springfield': LatLng(-27.6410, 152.8881),
      'durham': LatLng(-27.6652, 153.0869),
      'chermside': LatLng(-27.3898, 153.0744),
      'boondall': LatLng(-27.3633, 153.0921),
      'clayfield': LatLng(-27.3928, 153.1058),
      'zillmere': LatLng(-27.3712, 153.1282),
      'city': LatLng(-27.4698, 153.0251),
      'CBD': LatLng(-27.4698, 153.0251),
    };

    // Check for suburb matches
    for (final entry in suburbCoords.entries) {
      if (lowerAddress.contains(entry.key)) {
        // Add some noise to the coordinates for variation
        final latNoise = (address.hashCode % 100) / 10000 - 0.005;
        final lngNoise = (address.hashCode % 100) / 10000 - 0.005;
        return LatLng(
          entry.value.latitude + latNoise,
          entry.value.longitude + lngNoise,
        );
      }
    }

    // Default to Brisbane CBD if no suburb match
    return LatLng(-27.4698, 153.0251);
  }

  /// Validate an address by attempting to geocode it
  /// Returns true if the address can be geocoded to valid coordinates
  Future<bool> isValidAddress(String address) async {
    if (address.trim().isEmpty) {
      return false;
    }

    // Check if address contains Brisbane or known Brisbane suburbs
    final lowerAddress = address.toLowerCase();
    if (!lowerAddress.contains('brisbane') && 
        !lowerAddress.contains('qld') &&
        !lowerAddress.contains('queensland')) {
      // Check against known suburbs
      final hasSuburb = <String>[
        'south bank', 'fortitude valley', 'west end', 'paddington',
        'kangaroo point', 'new farm', 'ascot', 'woolowin', 'stone corner',
        'red hill', 'sherwood', 'mount gravatt', 'mansfield', 'sunnybank',
        'salisbury', 'springfield', 'durham', 'chermside', 'boondall',
        'clayfield', 'zillmere', 'CBD', 'city',
      ].any((suburb) => lowerAddress.contains(suburb.toLowerCase()));
      
      if (!hasSuburb) {
        return false;
      }
    }

    final latLng = await geocodeAddress(address);
    return latLng != null && isWithinBrisbane(latLng.latitude, latLng.longitude);
  }

  /// Get formatted address from predictions
  Future<String?> getFormattedAddress(String address) async {
    try {
      final predictions = await _placesService.fetchBrisbaneAddressSuggestions(address);

      if (predictions.isEmpty) {
        return null;
      }

      return predictions.first;
    } catch (e) {
      return null;
    }
  }

  /// Check if coordinates are within Brisbane area
  /// Brisbane bounds: approximately -27.4 to -27.7 latitude, 153.0 to 153.3 longitude
  static bool isWithinBrisbane(double latitude, double longitude) {
    return latitude >= -27.8 && 
           latitude <= -27.2 && 
           longitude >= 152.8 && 
           longitude <= 153.4;
  }
}
