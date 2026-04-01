import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

class AdminDashboardService {
  AdminDashboardService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<int> totalEventsCount() {
    return _countStream(_firestore.collection('events'));
  }

  Stream<int> pendingEventsCount() {
    return _countStream(
      _firestore
          .collection('events')
          .where('reviewStatus', isEqualTo: 'pending'),
    );
  }

  Stream<int> totalLocalUsersCount() {
    return _countStream(_firestore.collection('local_users'));
  }

  Stream<int> totalUsersCount() {
    return _sumThreeStreams(
      totalLocalUsersCount(),
      totalVisitorsCount(),
      totalAdminsCount(),
    );
  }

  Stream<int> pendingLocalUsersCount() {
    return _countStream(
      _firestore
          .collection('local_users')
          .where('approvalStatus', isEqualTo: 'pending'),
    );
  }

  Stream<int> totalVisitorsCount() {
    return _countStream(_firestore.collection('visitor_users'));
  }

  Stream<int> totalAdminsCount() {
    return _countStream(_firestore.collection('admins'));
  }

  Stream<int> pendingEventReportsCount() {
    return _countStream(
      _firestore
          .collection('event_reports')
          .where('status', isEqualTo: 'pending'),
    );
  }

  Stream<int> _countStream(Query<Map<String, dynamic>> query) {
    return query.snapshots().map((snapshot) => snapshot.size).distinct();
  }

  Stream<int> _sumThreeStreams(
    Stream<int> a,
    Stream<int> b,
    Stream<int> c,
  ) {
    late StreamController<int> controller;
    StreamSubscription<int>? subA;
    StreamSubscription<int>? subB;
    StreamSubscription<int>? subC;

    int? valueA;
    int? valueB;
    int? valueC;

    void emitIfReady() {
      if (valueA == null || valueB == null || valueC == null) {
        return;
      }
      controller.add(valueA! + valueB! + valueC!);
    }

    controller = StreamController<int>(
      onListen: () {
        subA = a.listen(
          (value) {
            valueA = value;
            emitIfReady();
          },
          onError: controller.addError,
        );

        subB = b.listen(
          (value) {
            valueB = value;
            emitIfReady();
          },
          onError: controller.addError,
        );

        subC = c.listen(
          (value) {
            valueC = value;
            emitIfReady();
          },
          onError: controller.addError,
        );
      },
      onCancel: () async {
        await subA?.cancel();
        await subB?.cancel();
        await subC?.cancel();
      },
    );

    return controller.stream.distinct();
  }
}
