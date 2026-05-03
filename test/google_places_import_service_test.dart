import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brisconnect/services/google_places_import_service.dart';

// ---------------------------------------------------------------------------
// Fake callable / response used to simulate Cloud Functions responses.
// ---------------------------------------------------------------------------

class _FakeHttpsCallableResult<T> implements HttpsCallableResult<T> {
  _FakeHttpsCallableResult(this.data);

  @override
  final T data;
}

class _FakeHttpsCallable implements HttpsCallable {
  _FakeHttpsCallable(this._response);

  final Map<String, dynamic> _response;

  @override
  Future<HttpsCallableResult<T>> call<T>([dynamic data]) async {
    return _FakeHttpsCallableResult<T>(_response as T);
  }

  @override
  int get timeout => 540;
  @override
  set timeout(int value) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeFirebaseFunctions implements FirebaseFunctions {
  _FakeFirebaseFunctions({
    Map<String, dynamic>? importResponse,
    Map<String, dynamic>? convertResponse,
    bool throwOnImport = false,
    bool throwOnConvert = false,
    String? importError,
    String? convertError,
  })  : _importResponse = importResponse ?? {},
        _convertResponse = convertResponse ?? {},
        _throwOnImport = throwOnImport,
        _throwOnConvert = throwOnConvert,
        _importError = importError,
        _convertError = convertError;

  final Map<String, dynamic> _importResponse;
  final Map<String, dynamic> _convertResponse;
  final bool _throwOnImport;
  final bool _throwOnConvert;
  final String? _importError;
  final String? _convertError;

  String? lastCalledFunction;

  @override
  HttpsCallable httpsCallable(String name, {HttpsCallableOptions? options}) {
    lastCalledFunction = name;
    if (name == 'importGooglePlacesCatalog') {
      if (_throwOnImport) {
        return _ThrowingCallable(
          _importError ?? 'Import failed',
        );
      }
      return _FakeHttpsCallable(_importResponse);
    }
    if (name == 'convertGooglePlacesToDiscoverItems') {
      if (_throwOnConvert) {
        return _ThrowingCallable(
          _convertError ?? 'Convert failed',
        );
      }
      return _FakeHttpsCallable(_convertResponse);
    }
    return _FakeHttpsCallable({});
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ThrowingCallable implements HttpsCallable {
  _ThrowingCallable(this._message);
  final String _message;

  @override
  Future<HttpsCallableResult<T>> call<T>([dynamic data]) async {
    throw FirebaseFunctionsException(
      code: 'internal',
      message: _message,
    );
  }

  @override
  int get timeout => 540;
  @override
  set timeout(int value) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Minimal FirebaseFunctionsException for testing error paths.
class FirebaseFunctionsException implements Exception {
  FirebaseFunctionsException({required this.code, required this.message});
  final String code;
  final String message;

  @override
  String toString() => 'FirebaseFunctionsException($code): $message';
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // ==========================================================================
  // GooglePlacesImportSummary.fromMap
  // ==========================================================================
  group('GooglePlacesImportSummary.fromMap', () {
    test('parses valid numeric fields from Cloud Function response', () {
      final summary = GooglePlacesImportSummary.fromMap({
        'radiusKm': 30,
        'attractionCount': 12,
        'eventCount': 5,
        'writeCount': 17,
      });

      expect(summary.radiusKm, 30);
      expect(summary.attractionCount, 12);
      expect(summary.eventCount, 5);
      expect(summary.writeCount, 17);
    });

    test('handles double values returned from Cloud Function', () {
      final summary = GooglePlacesImportSummary.fromMap({
        'radiusKm': 30.0,
        'attractionCount': 8.0,
        'eventCount': 3.0,
        'writeCount': 11.0,
      });

      expect(summary.radiusKm, 30.0);
      expect(summary.attractionCount, 8);
      expect(summary.eventCount, 3);
      expect(summary.writeCount, 11);
    });

    test('defaults to safe values when fields are missing', () {
      final summary = GooglePlacesImportSummary.fromMap({});

      expect(summary.radiusKm, 30);
      expect(summary.attractionCount, 0);
      expect(summary.eventCount, 0);
      expect(summary.writeCount, 0);
    });

    test('defaults to safe values when fields are non-numeric', () {
      final summary = GooglePlacesImportSummary.fromMap({
        'radiusKm': 'thirty',
        'attractionCount': null,
        'eventCount': true,
        'writeCount': 'abc',
      });

      expect(summary.radiusKm, 30);
      expect(summary.attractionCount, 0);
      expect(summary.eventCount, 0);
      expect(summary.writeCount, 0);
    });

    test('handles zero counts for empty import', () {
      final summary = GooglePlacesImportSummary.fromMap({
        'radiusKm': 30,
        'attractionCount': 0,
        'eventCount': 0,
        'writeCount': 0,
      });

      expect(summary.attractionCount, 0);
      expect(summary.eventCount, 0);
      expect(summary.writeCount, 0);
    });

    test('handles large import counts', () {
      final summary = GooglePlacesImportSummary.fromMap({
        'radiusKm': 30,
        'attractionCount': 500,
        'eventCount': 300,
        'writeCount': 800,
      });

      expect(summary.attractionCount, 500);
      expect(summary.eventCount, 300);
      expect(summary.writeCount, 800);
    });
  });

  // ==========================================================================
  // DiscoverItemsConversionSummary.fromMap
  // ==========================================================================
  group('DiscoverItemsConversionSummary.fromMap', () {
    test('parses valid conversion response', () {
      final summary = DiscoverItemsConversionSummary.fromMap({
        'discoveredAttractions': 10,
        'discoveredEvents': 4,
        'itemCount': 14,
        'writeCount': 14,
      });

      expect(summary.discoveredAttractions, 10);
      expect(summary.discoveredEvents, 4);
      expect(summary.itemCount, 14);
      expect(summary.writeCount, 14);
    });

    test('defaults to zero when fields are missing', () {
      final summary = DiscoverItemsConversionSummary.fromMap({});

      expect(summary.discoveredAttractions, 0);
      expect(summary.discoveredEvents, 0);
      expect(summary.itemCount, 0);
      expect(summary.writeCount, 0);
    });

    test('defaults to zero when fields are non-numeric', () {
      final summary = DiscoverItemsConversionSummary.fromMap({
        'discoveredAttractions': 'ten',
        'discoveredEvents': null,
        'itemCount': false,
        'writeCount': [],
      });

      expect(summary.discoveredAttractions, 0);
      expect(summary.discoveredEvents, 0);
      expect(summary.itemCount, 0);
      expect(summary.writeCount, 0);
    });

    test('handles double values from Cloud Function', () {
      final summary = DiscoverItemsConversionSummary.fromMap({
        'discoveredAttractions': 7.0,
        'discoveredEvents': 3.0,
        'itemCount': 10.0,
        'writeCount': 10.0,
      });

      expect(summary.discoveredAttractions, 7);
      expect(summary.discoveredEvents, 3);
      expect(summary.itemCount, 10);
      expect(summary.writeCount, 10);
    });

    test('itemCount matches sum of attractions and events', () {
      final summary = DiscoverItemsConversionSummary.fromMap({
        'discoveredAttractions': 6,
        'discoveredEvents': 4,
        'itemCount': 10,
        'writeCount': 10,
      });

      expect(
        summary.itemCount,
        summary.discoveredAttractions + summary.discoveredEvents,
      );
    });
  });

  // ==========================================================================
  // GooglePlacesImportService — import within Brisbane radius
  // ==========================================================================
  group('GooglePlacesImportService.importWithinBrisbaneRadius', () {
    test('calls importGooglePlacesCatalog Cloud Function', () async {
      final fakeFunctions = _FakeFirebaseFunctions(
        importResponse: {
          'radiusKm': 30,
          'attractionCount': 15,
          'eventCount': 8,
          'writeCount': 23,
        },
      );

      final service = GooglePlacesImportService(functions: fakeFunctions);
      await service.importWithinBrisbaneRadius();

      expect(fakeFunctions.lastCalledFunction, 'importGooglePlacesCatalog');
    });

    test('returns parsed summary with attraction and event counts', () async {
      final fakeFunctions = _FakeFirebaseFunctions(
        importResponse: {
          'radiusKm': 30,
          'attractionCount': 15,
          'eventCount': 8,
          'writeCount': 23,
        },
      );

      final service = GooglePlacesImportService(functions: fakeFunctions);
      final summary = await service.importWithinBrisbaneRadius();

      expect(summary.radiusKm, 30);
      expect(summary.attractionCount, 15);
      expect(summary.eventCount, 8);
      expect(summary.writeCount, 23);
    });

    test('returns summary showing 30km Brisbane radius', () async {
      final fakeFunctions = _FakeFirebaseFunctions(
        importResponse: {
          'radiusKm': 30,
          'attractionCount': 0,
          'eventCount': 0,
          'writeCount': 0,
        },
      );

      final service = GooglePlacesImportService(functions: fakeFunctions);
      final summary = await service.importWithinBrisbaneRadius();

      expect(summary.radiusKm, 30);
    });

    test('handles empty import with zero counts', () async {
      final fakeFunctions = _FakeFirebaseFunctions(
        importResponse: {
          'radiusKm': 30,
          'attractionCount': 0,
          'eventCount': 0,
          'writeCount': 0,
        },
      );

      final service = GooglePlacesImportService(functions: fakeFunctions);
      final summary = await service.importWithinBrisbaneRadius();

      expect(summary.attractionCount, 0);
      expect(summary.eventCount, 0);
      expect(summary.writeCount, 0);
    });

    test('propagates Cloud Function errors', () async {
      final fakeFunctions = _FakeFirebaseFunctions(
        throwOnImport: true,
        importError: 'Google Places API quota exceeded',
      );

      final service = GooglePlacesImportService(functions: fakeFunctions);

      expect(
        () => service.importWithinBrisbaneRadius(),
        throwsA(isA<FirebaseFunctionsException>()),
      );
    });

    test('write count equals attraction count plus event count', () async {
      final fakeFunctions = _FakeFirebaseFunctions(
        importResponse: {
          'radiusKm': 30,
          'attractionCount': 20,
          'eventCount': 10,
          'writeCount': 30,
        },
      );

      final service = GooglePlacesImportService(functions: fakeFunctions);
      final summary = await service.importWithinBrisbaneRadius();

      expect(summary.writeCount, summary.attractionCount + summary.eventCount);
    });
  });

  // ==========================================================================
  // GooglePlacesImportService — convert imported to discover items
  // ==========================================================================
  group('GooglePlacesImportService.convertImportedToDiscoverItems', () {
    test('calls convertGooglePlacesToDiscoverItems Cloud Function', () async {
      final fakeFunctions = _FakeFirebaseFunctions(
        convertResponse: {
          'discoveredAttractions': 10,
          'discoveredEvents': 5,
          'itemCount': 15,
          'writeCount': 15,
        },
      );

      final service = GooglePlacesImportService(functions: fakeFunctions);
      await service.convertImportedToDiscoverItems();

      expect(
        fakeFunctions.lastCalledFunction,
        'convertGooglePlacesToDiscoverItems',
      );
    });

    test('returns parsed conversion summary', () async {
      final fakeFunctions = _FakeFirebaseFunctions(
        convertResponse: {
          'discoveredAttractions': 10,
          'discoveredEvents': 5,
          'itemCount': 15,
          'writeCount': 15,
        },
      );

      final service = GooglePlacesImportService(functions: fakeFunctions);
      final summary = await service.convertImportedToDiscoverItems();

      expect(summary.discoveredAttractions, 10);
      expect(summary.discoveredEvents, 5);
      expect(summary.itemCount, 15);
      expect(summary.writeCount, 15);
    });

    test('handles conversion with zero results', () async {
      final fakeFunctions = _FakeFirebaseFunctions(
        convertResponse: {
          'discoveredAttractions': 0,
          'discoveredEvents': 0,
          'itemCount': 0,
          'writeCount': 0,
        },
      );

      final service = GooglePlacesImportService(functions: fakeFunctions);
      final summary = await service.convertImportedToDiscoverItems();

      expect(summary.itemCount, 0);
      expect(summary.writeCount, 0);
    });

    test('propagates Cloud Function errors', () async {
      final fakeFunctions = _FakeFirebaseFunctions(
        throwOnConvert: true,
        convertError: 'Value for argument "data" is not a valid Firestore document',
      );

      final service = GooglePlacesImportService(functions: fakeFunctions);

      expect(
        () => service.convertImportedToDiscoverItems(),
        throwsA(isA<FirebaseFunctionsException>()),
      );
    });

    test('handles attractions-only conversion with no events', () async {
      final fakeFunctions = _FakeFirebaseFunctions(
        convertResponse: {
          'discoveredAttractions': 12,
          'discoveredEvents': 0,
          'itemCount': 12,
          'writeCount': 12,
        },
      );

      final service = GooglePlacesImportService(functions: fakeFunctions);
      final summary = await service.convertImportedToDiscoverItems();

      expect(summary.discoveredAttractions, 12);
      expect(summary.discoveredEvents, 0);
      expect(summary.itemCount, 12);
    });

    test('handles events-only conversion with no attractions', () async {
      final fakeFunctions = _FakeFirebaseFunctions(
        convertResponse: {
          'discoveredAttractions': 0,
          'discoveredEvents': 8,
          'itemCount': 8,
          'writeCount': 8,
        },
      );

      final service = GooglePlacesImportService(functions: fakeFunctions);
      final summary = await service.convertImportedToDiscoverItems();

      expect(summary.discoveredAttractions, 0);
      expect(summary.discoveredEvents, 8);
      expect(summary.itemCount, 8);
    });
  });

  // ==========================================================================
  // Duplicate import handling (idempotent upsert)
  // ==========================================================================
  group('Duplicate import handling', () {
    test('consecutive imports return latest counts without error', () async {
      final fakeFunctions = _FakeFirebaseFunctions(
        importResponse: {
          'radiusKm': 30,
          'attractionCount': 15,
          'eventCount': 8,
          'writeCount': 23,
        },
      );

      final service = GooglePlacesImportService(functions: fakeFunctions);

      final first = await service.importWithinBrisbaneRadius();
      final second = await service.importWithinBrisbaneRadius();

      // Both calls succeed — server handles upsert via doc ID
      expect(first.writeCount, 23);
      expect(second.writeCount, 23);
    });

    test('consecutive conversions return latest counts without error', () async {
      final fakeFunctions = _FakeFirebaseFunctions(
        convertResponse: {
          'discoveredAttractions': 10,
          'discoveredEvents': 5,
          'itemCount': 15,
          'writeCount': 15,
        },
      );

      final service = GooglePlacesImportService(functions: fakeFunctions);

      final first = await service.convertImportedToDiscoverItems();
      final second = await service.convertImportedToDiscoverItems();

      expect(first.itemCount, 15);
      expect(second.itemCount, 15);
    });
  });

  // ==========================================================================
  // Service constructor
  // ==========================================================================
  group('GooglePlacesImportService constructor', () {
    test('accepts injected FirebaseFunctions instance', () {
      final fakeFunctions = _FakeFirebaseFunctions();
      final service = GooglePlacesImportService(functions: fakeFunctions);
      expect(service, isNotNull);
    });
  });
}
