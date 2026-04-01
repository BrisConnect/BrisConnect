import 'package:brisconnect/auth/local_auth.dart';
import 'package:brisconnect/auth/visitor_auth.dart';
import 'package:brisconnect/widgets/logo_app_bar_title.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _DestinationScreen extends StatelessWidget {
  final String label;

  const _DestinationScreen(this.label);

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text(label)));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    VisitorAuth.debugSetCurrentVisitorForTesting(null);
    LocalAuth.debugSetCurrentLocalForTesting(null);
  });

  testWidgets('Logo tap routes Visitor to visitor home immediately',
      (tester) async {
    VisitorAuth.debugSetCurrentVisitorForTesting(
      const VisitorUser(
        name: 'Visitor',
        email: 'visitor@brisconnect.com',
        password: 'Password1!',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            title: LogoAppBarTitle(
              'Any Page',
              visitorHomeBuilder: (_) => const _DestinationScreen('Visitor Home'),
            ),
          ),
          body: const SizedBox.shrink(),
        ),
      ),
    );

    await tester.tap(find.byType(InkWell).first);
    await tester.pumpAndSettle();

    expect(find.text('Visitor Home'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Logo tap routes Local to local home immediately',
      (tester) async {
    LocalAuth.debugSetCurrentLocalForTesting(
      const LocalUser(
        name: 'Local',
        email: 'local@brisconnect.com',
        password: 'Password1!',
        phone: '0400000000',
        suburb: 'Brisbane',
        approvalStatus: AccountApprovalStatus.approved,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            title: LogoAppBarTitle(
              'Any Page',
              localHomeBuilder: (_) => const _DestinationScreen('Local Home'),
            ),
          ),
          body: const SizedBox.shrink(),
        ),
      ),
    );

    await tester.tap(find.byType(InkWell).first);
    await tester.pumpAndSettle();

    expect(find.text('Local Home'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
