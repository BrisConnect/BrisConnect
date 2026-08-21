import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Service for managing language translations via Cloud Functions
class TranslationService {
  static final TranslationService _instance = TranslationService._internal();

  factory TranslationService() {
    return _instance;
  }

  TranslationService._internal();

  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'australia-southeast1');

  /// Trigger bulk translation of all language ARB files
  /// Requires admin role to execute
  Future<Map<String, dynamic>> bulkTranslateLanguages() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User must be authenticated to translate languages');
      }

      debugPrint('Triggering bulk translation for all languages...');

      final result = await _functions.httpsCallable('bulkTranslateLanguages').call();

      debugPrint('Translation result: $result');
      return Map<String, dynamic>.from(result.data as Map);
    } on FirebaseFunctionsException catch (e) {
      debugPrint('Cloud Functions error: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Error triggering translation: $e');
      rethrow;
    }
  }

  /// Get translation status for a specific language
  Future<Map<String, dynamic>> getTranslationStatus(String languageCode) async {
    try {
      debugPrint('Getting translation status for language: $languageCode');

      final result = await _functions
          .httpsCallable('getTranslationStatus')
          .call({'languageCode': languageCode});

      return Map<String, dynamic>.from(result.data as Map);
    } on FirebaseFunctionsException catch (e) {
      debugPrint('Cloud Functions error: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Error getting translation status: $e');
      rethrow;
    }
  }

  /// Manually translate specific strings for a language
  /// Useful for fixing specific translations
  Future<Map<String, dynamic>> translateStrings(
    String languageCode,
    Map<String, String> strings,
  ) async {
    try {
      debugPrint(
        'Translating ${strings.length} strings for language: $languageCode',
      );

      final result = await _functions.httpsCallable('translateStrings').call({
        'languageCode': languageCode,
        'strings': strings,
      });

      return Map<String, dynamic>.from(result.data as Map);
    } on FirebaseFunctionsException catch (e) {
      debugPrint('Cloud Functions error: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Error translating strings: $e');
      rethrow;
    }
  }

  /// Check if user has permission to trigger translations
  Future<bool> canTranslate() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return false;

      // User must have admin role (implement according to your security model)
      // For now, just check if user is authenticated
      return true;
    } catch (e) {
      debugPrint('Error checking translation permission: $e');
      return false;
    }
  }
}
