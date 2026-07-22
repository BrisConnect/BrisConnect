import 'package:brisconnect/services/crowd_report_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FixedConnectivity implements Connectivity {
  final List<ConnectivityResult> _results;

  _FixedConnectivity({List<ConnectivityResult> results = const [ConnectivityResult.wifi]})
      : _results = results;

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => _results;

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      Stream<List<ConnectivityResult>>.empty();
}

void main() {
  group('CrowdReportService', () {
    late FakeFirebaseFirestore fakeFirestore;
    late CrowdReportService service;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      SharedPreferences.setMockInitialValues({});
      service = CrowdReportService(
        firestore: fakeFirestore,
        connectivity: _FixedConnectivity(),
        useFirebaseAuth: false,
      );
    });

    test('submitReport stores report with timestamp and weight', () async {
      await service.submitReport('event_1', CrowdLevel.moderate);

      final snapshot = await fakeFirestore.collection('crowd_reports').get();
      expect(snapshot.docs.length, 1);

      final data = snapshot.docs.first.data();
      expect(data['eventId'], 'event_1');
      expect(data['level'], 'Moderate');
      expect(data['weight'], 2);
      expect(data['timestamp'], isA<Timestamp>());
    });

    test('canSubmitReport returns true when no prior report exists', () async {
      final canSubmit = await service.canSubmitReport('event_1');
      expect(canSubmit, true);
    });

    test('canSubmitReport returns false within cooldown for anonymous user', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        'crowd_report_event_1_last',
        DateTime.now().millisecondsSinceEpoch,
      );

      final anonymousService = CrowdReportService(
        firestore: fakeFirestore,
        connectivity: _FixedConnectivity(),
        prefs: prefs,
        useFirebaseAuth: false,
      );

      final canSubmit = await anonymousService.canSubmitReport('event_1');
      expect(canSubmit, false);
    });

    test('canSubmitReport returns true after cooldown for anonymous user', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        'crowd_report_event_1_last',
        DateTime.now().subtract(const Duration(minutes: 31)).millisecondsSinceEpoch,
      );

      final anonymousService = CrowdReportService(
        firestore: fakeFirestore,
        connectivity: _FixedConnectivity(),
        prefs: prefs,
        useFirebaseAuth: false,
      );

      final canSubmit = await anonymousService.canSubmitReport('event_1');
      expect(canSubmit, true);
    });

    test('watchCrowdStatus calculates weighted average from reports', () async {
      final now = DateTime.now();
      await fakeFirestore.collection('crowd_reports').add({
        'eventId': 'event_1',
        'userId': 'u1',
        'level': 'Low',
        'weight': 1,
        'timestamp': Timestamp.fromDate(now),
      });
      await fakeFirestore.collection('crowd_reports').add({
        'eventId': 'event_1',
        'userId': 'u2',
        'level': 'High',
        'weight': 3,
        'timestamp': Timestamp.fromDate(now.subtract(const Duration(minutes: 5))),
      });

      final status = await service.watchCrowdStatus('event_1').first;
      expect(status, isNotNull);
      expect(status!.reportCount, 2);
      expect(status.level, CrowdLevel.moderate);
    });

    test('watchCrowdStatus ignores reports older than 2 hours', () async {
      await fakeFirestore.collection('crowd_reports').add({
        'eventId': 'event_1',
        'userId': 'u1',
        'level': 'High',
        'weight': 3,
        'timestamp': Timestamp.fromDate(
          DateTime.now().subtract(const Duration(hours: 3)),
        ),
      });

      final status = await service.watchCrowdStatus('event_1').first;
      expect(status, isNull);
    });

    test('submitReport throws when offline', () async {
      final offlineService = CrowdReportService(
        firestore: fakeFirestore,
        connectivity: _FixedConnectivity(results: const [ConnectivityResult.none]),
      );

      expect(
        () => offlineService.submitReport('event_1', CrowdLevel.low),
        throwsException,
      );
    });
  });
}
