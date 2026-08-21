import 'package:flutter/foundation.dart';

class AppConfig {
  static const String firebaseFunctionsRegion = 'australia-southeast1';
  static const int firestoreEmulatorPort = 8080;

  /// Google Gemini API key — get a free key at https://aistudio.google.com/
  static const String geminiApiKey = 'AIzaSyDh0PHiARbQM8WCeGHtppQEcIKOfyPGMhU';

  /// Google Places / Maps API key
  /// Required for precise address geocoding in AddressGeocodingService.
  static const String googlePlacesApiKey = 'AIzaSyCgEZo0LJD6ksf9Vfe8owyGm22xYygW8ps';

  /// Firebase Cloud Messaging Web Push certificate public key.
  /// Required for push notifications on Flutter Web. Set this to the
  /// VAPID key from Firebase project settings to enable web tokens.
  static const String firebaseWebVapidKey =
      'BE5f8kiVkdDKD59AT4o66qOtHZ7rPqHiD9cKYcUfLKblqdeyy_Q-M_UzSRliN2tpNougeFnaDN1-qj5Bg9nQRkA';

  static String get firestoreEmulatorHost {
    return defaultTargetPlatform == TargetPlatform.android ? '10.0.2.2' : 'localhost';
  }
}