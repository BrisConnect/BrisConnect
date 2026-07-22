import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:brisconnect/config/app_config.dart';

class GooglePlacesAutocompleteService {
  GooglePlacesAutocompleteService({FirebaseFunctions? functions})
      : _functions = functions ??
            FirebaseFunctions.instanceFor(region: AppConfig.firebaseFunctionsRegion);

  final FirebaseFunctions _functions;
  String _sessionToken = _newSessionToken();

  static const List<String> _brisbaneFallbackSuggestions = [
    'Brisbane City QLD',
    'South Brisbane QLD',
    'West End QLD',
    'Fortitude Valley QLD',
    'New Farm QLD',
    'Kangaroo Point QLD',
    'Paddington QLD',
    'Milton QLD',
    'Spring Hill QLD',
    'Toowong QLD',
    'Indooroopilly QLD',
    'St Lucia QLD',
    'Taringa QLD',
    'Auchenflower QLD',
    'Ashgrove QLD',
    'Red Hill QLD',
    'Herston QLD',
    'Kelvin Grove QLD',
    'Woolloongabba QLD',
    'Greenslopes QLD',
    'Coorparoo QLD',
    'Camp Hill QLD',
    'Carina QLD',
    'Carindale QLD',
    'Morningside QLD',
    'Bulimba QLD',
    'Hawthorne QLD',
    'Balmoral QLD',
    'Nundah QLD',
    'Chermside QLD',
    'Aspley QLD',
    'Albion QLD',
    'Windsor QLD',
    'Lutwyche QLD',
    'Annerley QLD',
    'Yeronga QLD',
    'Fairfield QLD',
    'Sherwood QLD',
    'Oxley QLD',
    'Corinda QLD',
  ];

  static String _newSessionToken() {
    final micros = DateTime.now().microsecondsSinceEpoch;
    return 'brisconnect-$micros';
  }

  void resetSession() {
    _sessionToken = _newSessionToken();
  }

  List<String> _fallbackSuggestions(String query, {int limit = 8}) {
    final lower = query.trim().toLowerCase();
    if (lower.length < 2) return const [];

    final startsWith = <String>[];
    final contains = <String>[];

    for (final item in _brisbaneFallbackSuggestions) {
      final itemLower = item.toLowerCase();
      if (itemLower.startsWith(lower)) {
        startsWith.add(item);
      } else if (itemLower.contains(lower)) {
        contains.add(item);
      }
    }

    final merged = <String>[...startsWith, ...contains];
    if (merged.length <= limit) return merged;
    return merged.take(limit).toList(growable: false);
  }

  Future<List<String>> fetchBrisbaneAddressSuggestions(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return const [];
    final fallback = _fallbackSuggestions(trimmed);

    try {
      final callable = _functions.httpsCallable('autocompleteBrisbaneAddress');
      final response = await callable.call<Map<String, dynamic>>({
        'query': trimmed,
        'sessionToken': _sessionToken,
        'limit': 8,
      }).timeout(const Duration(seconds: 10));

      final data = response.data;
      final rawList = data['suggestions'];
      if (rawList is! List) {
        debugPrint('[PlacesAutocomplete] query="$trimmed" invalid payload');
        return fallback;
      }

      final suggestions = rawList
          .map((item) => item is String ? item.trim() : '')
          .where((item) => item.isNotEmpty)
          .toList(growable: false);

      debugPrint(
        '[PlacesAutocomplete] query="$trimmed" suggestions=${suggestions.length}',
      );
      if (suggestions.isEmpty) {
        return fallback;
      }
      return suggestions;
    } catch (error) {
      debugPrint('[PlacesAutocomplete] query="$trimmed" error=$error');
      return fallback;
    }
  }
}
