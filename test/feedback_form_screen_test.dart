import 'dart:typed_data';

import 'package:brisconnect/screens/feedback_form_screen.dart';
import 'package:brisconnect/services/app_feedback_service.dart';
import 'package:brisconnect/services/firebase_media_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

class _NoOpStorageDriver implements MediaStorageDriver {
  @override
  Future<String> uploadBytes({
    required String path,
    required Uint8List bytes,
    required String contentType,
  }) async => 'https://example.com/fake.jpg';

  @override
  Future<void> delete(String path) async {}
}

late FakeFirebaseFirestore _fakeFirestore;
late AppFeedbackService _fakeService;

Widget _buildApp({
  String reporterRole = 'visitor',
  String reporterName = 'Jane Doe',
  String reporterEmail = 'jane@example.com',
}) {
  _fakeFirestore = FakeFirebaseFirestore();
  _fakeService = AppFeedbackService(firestore: _fakeFirestore);
  return MaterialApp(
    home: FeedbackFormScreen(
      reporterRole: reporterRole,
      reporterName: reporterName,
      reporterEmail: reporterEmail,
      feedbackService: _fakeService,
      mediaService: FirebaseMediaService(driver: _NoOpStorageDriver()),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('FeedbackFormScreen', () {
    testWidgets('displays subject and details fields', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      expect(find.text('Subject'), findsOneWidget);
      expect(find.text('Feedback details'), findsOneWidget);
    });

    testWidgets('displays category dropdown with all five options',
        (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      expect(find.text('Category'), findsOneWidget);

      // Open the category dropdown.
      await tester.tap(find.text('Bug'));
      await tester.pumpAndSettle();

      expect(find.text('Bug'), findsWidgets);
      expect(find.text('Misleading Information'), findsWidgets);
      expect(find.text('Usability'), findsWidgets);
      expect(find.text('Performance'), findsWidgets);
      expect(find.text('Other'), findsWidgets);
    });

    testWidgets('displays severity dropdown with all four options',
        (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      expect(find.text('Severity'), findsOneWidget);

      // Open the severity dropdown.
      await tester.tap(find.text('Medium'));
      await tester.pumpAndSettle();

      expect(find.text('Low'), findsWidgets);
      expect(find.text('Medium'), findsWidgets);
      expect(find.text('High'), findsWidgets);
      expect(find.text('Critical'), findsWidgets);
    });

    testWidgets('validates subject with fewer than five characters',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildApp());
      await tester.pump();

      // Enter a short subject and valid details.
      await tester.enterText(find.byType(TextFormField).at(0), 'Hi');
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'This is a detailed description of the issue for the team.',
      );

      // Scroll to the submit button and tap it.
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -500));
      await tester.pump();

      await tester.tap(find.text('Submit Feedback'));
      await tester.pump();

      expect(
        find.text('Subject should be at least 5 characters.'),
        findsOneWidget,
      );
    });

    testWidgets('submits feedback with pending_triage status and timestamp',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildApp());
      await tester.pump();

      // Fill in subject.
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'Button does not respond',
      );

      // Fill in details.
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'The submit button stops working after the first tap fails.',
      );

      // Scroll down to ensure the submit button is visible.
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -500));
      await tester.pump();

      await tester.tap(find.text('Submit Feedback'));
      await tester.pumpAndSettle();

      // Verify Firestore received the document.
      final snap = await _fakeFirestore.collection('app_feedback').get();
      expect(snap.docs.length, 1);

      final data = snap.docs.first.data();
      expect(data['status'], 'pending_triage');
      expect(data['createdAt'], isNotNull);
      expect(data['updatedAt'], isNotNull);
    });

    testWidgets('captures reporter name, email, and role automatically',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildApp(
        reporterRole: 'visitor',
        reporterName: 'Jane Doe',
        reporterEmail: 'jane@example.com',
      ));
      await tester.pump();

      // The form shows the reporter context.
      expect(find.textContaining('jane@example.com'), findsOneWidget);
      expect(find.textContaining('visitor'), findsOneWidget);

      // Fill valid subject and details, then submit.
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'Search feature is broken',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'Searching for events returns empty results even with keywords.',
      );

      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -500));
      await tester.pump();

      await tester.tap(find.text('Submit Feedback'));
      await tester.pumpAndSettle();

      final snap = await _fakeFirestore.collection('app_feedback').get();
      expect(snap.docs.length, 1);

      final data = snap.docs.first.data();
      expect(data['reporterRole'], 'visitor');
      expect(data['reporterName'], 'Jane Doe');
      expect(data['reporterEmail'], 'jane@example.com');
    });

    testWidgets('validates empty details field', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildApp());
      await tester.pump();

      // Enter a valid subject but leave details empty.
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'Missing map location',
      );

      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -500));
      await tester.pump();

      await tester.tap(find.text('Submit Feedback'));
      await tester.pump();

      expect(find.text('Please provide details.'), findsOneWidget);
    });

    testWidgets('shows submit button and screenshot attach option',
        (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      expect(find.text('Submit Feedback'), findsOneWidget);
      expect(find.byIcon(Icons.send_rounded), findsOneWidget);

      // Scroll to screenshot section.
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -400));
      await tester.pump();

      expect(find.text('Attach Screenshot'), findsOneWidget);
      expect(find.byIcon(Icons.image_rounded), findsOneWidget);
    });
  });
}
