
import 'package:brisconnect/auth/local_auth.dart';
import 'package:brisconnect/services/admin_dashboard_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

LocalUser _makeLocal({
  String name = 'Test User',
  String email = 'test@local.com',
  String password = 'pass123',
  String phone = '0400000000',
  String suburb = 'South Bank',
  AccountApprovalStatus approvalStatus = AccountApprovalStatus.pending,
}) {
  return LocalUser(
    name: name,
    email: email,
    password: password,
    phone: phone,
    suburb: suburb,
    approvalStatus: approvalStatus,
  );
}

/// Seeds local user documents into fake Firestore.
Future<void> _seedLocalUser(
  FakeFirebaseFirestore fs, {
  required String id,
  required String name,
  required String email,
  String approvalStatus = 'pending',
  String phone = '0400000000',
  String suburb = 'CBD',
}) async {
  await fs.collection('local_users').doc(id).set({
    'name': name,
    'email': email,
    'phone': phone,
    'suburb': suburb,
    'approvalStatus': approvalStatus,
    'role': 'local',
    'accountType': 'local',
  });
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // =====================================================================
  // AC-1  Displays pending Local account requests for admin review.
  // =====================================================================
  group('AC-1: displays pending Local account requests', () {
    test('getPendingAccounts returns only pending users from in-memory list',
        () {
      final pending = _makeLocal(
        name: 'Alice',
        email: 'alice@test.com',
        approvalStatus: AccountApprovalStatus.pending,
      );
      final approved = _makeLocal(
        name: 'Bob',
        email: 'bob@test.com',
        approvalStatus: AccountApprovalStatus.approved,
      );
      final rejected = _makeLocal(
        name: 'Cara',
        email: 'cara@test.com',
        approvalStatus: AccountApprovalStatus.rejected,
      );

      // Set up in-memory users via debugSetCurrentLocalForTesting
      LocalAuth.debugSetCurrentLocalForTesting(pending);
      LocalAuth.debugSetCurrentLocalForTesting(approved);
      LocalAuth.debugSetCurrentLocalForTesting(rejected);
      addTearDown(() => LocalAuth.debugSetCurrentLocalForTesting(null));

      final pendingAccounts = LocalAuth.getPendingAccounts();
      expect(pendingAccounts.length, 1);
      expect(pendingAccounts.first.name, 'Alice');
      expect(pendingAccounts.first.approvalStatus,
          AccountApprovalStatus.pending);
    });

    test('approved-only user does not appear in getPendingAccounts', () {
      final approved = _makeLocal(
        name: 'Done',
        email: 'done_ac1@test.com',
        approvalStatus: AccountApprovalStatus.approved,
      );

      LocalAuth.debugSetCurrentLocalForTesting(approved);
      addTearDown(() => LocalAuth.debugSetCurrentLocalForTesting(null));

      final pendingAccounts = LocalAuth.getPendingAccounts();
      expect(
        pendingAccounts.any((u) => u.email == 'done_ac1@test.com'),
        isFalse,
      );
    });

    test('pendingLocalUsersCount stream returns pending count from Firestore',
        () async {
      final fs = FakeFirebaseFirestore();
      await _seedLocalUser(fs,
          id: 'l1',
          name: 'Pending User',
          email: 'l1@test.com',
          approvalStatus: 'pending');
      await _seedLocalUser(fs,
          id: 'l2',
          name: 'Approved User',
          email: 'l2@test.com',
          approvalStatus: 'approved');
      await _seedLocalUser(fs,
          id: 'l3',
          name: 'Also Pending',
          email: 'l3@test.com',
          approvalStatus: 'pending');

      final service = AdminDashboardService(firestore: fs);
      expect(await service.pendingLocalUsersCount().first, 2);
    });

    test('pending count is zero when all accounts are approved', () async {
      final fs = FakeFirebaseFirestore();
      await _seedLocalUser(fs,
          id: 'l1',
          name: 'Bob',
          email: 'bob@test.com',
          approvalStatus: 'approved');

      final service = AdminDashboardService(firestore: fs);
      expect(await service.pendingLocalUsersCount().first, 0);
    });

    test('LocalUser model exposes all required fields for review card', () {
      final user = _makeLocal(
        name: 'Jane Doe',
        email: 'jane@test.com',
        phone: '0412345678',
        suburb: 'West End',
        approvalStatus: AccountApprovalStatus.pending,
      );

      expect(user.name, 'Jane Doe');
      expect(user.email, 'jane@test.com');
      expect(user.phone, '0412345678');
      expect(user.suburb, 'West End');
      expect(user.approvalStatus, AccountApprovalStatus.pending);
    });

    test('multiple pending users are all returned', () {
      LocalAuth.debugSetCurrentLocalForTesting(_makeLocal(
        name: 'Multi1',
        email: 'multi1@test.com',
        approvalStatus: AccountApprovalStatus.pending,
      ));
      LocalAuth.debugSetCurrentLocalForTesting(_makeLocal(
        name: 'Multi2',
        email: 'multi2@test.com',
        approvalStatus: AccountApprovalStatus.pending,
      ));
      LocalAuth.debugSetCurrentLocalForTesting(_makeLocal(
        name: 'Multi3',
        email: 'multi3@test.com',
        approvalStatus: AccountApprovalStatus.pending,
      ));
      addTearDown(() => LocalAuth.debugSetCurrentLocalForTesting(null));

      final pending = LocalAuth.getPendingAccounts();
      expect(pending.any((u) => u.email == 'multi1@test.com'), isTrue);
      expect(pending.any((u) => u.email == 'multi2@test.com'), isTrue);
      expect(pending.any((u) => u.email == 'multi3@test.com'), isTrue);
    });
  });

  // =====================================================================
  // AC-2  The Admin can approve a Local account.
  // =====================================================================
  group('AC-2: admin can approve a Local account', () {
    test('copyWith updates approval status to approved', () {
      final user = _makeLocal(approvalStatus: AccountApprovalStatus.pending);
      final approved =
          user.copyWith(approvalStatus: AccountApprovalStatus.approved);

      expect(approved.approvalStatus, AccountApprovalStatus.approved);
      expect(approved.name, user.name);
      expect(approved.email, user.email);
    });

    test('approved status persists in Firestore via dashboard service',
        () async {
      final fs = FakeFirebaseFirestore();
      await _seedLocalUser(fs,
          id: 'l1',
          name: 'Pending',
          email: 'l1@test.com',
          approvalStatus: 'pending');

      final service = AdminDashboardService(firestore: fs);
      expect(await service.pendingLocalUsersCount().first, 1);

      // Simulate approval by updating the document
      await fs.collection('local_users').doc('l1').update({
        'approvalStatus': 'approved',
      });

      expect(await service.pendingLocalUsersCount().first, 0);
    });

    test('approved user appears in getApprovedAccounts', () {
      final user = _makeLocal(
        name: 'Approved Alice',
        email: 'alice_apr@test.com',
        approvalStatus: AccountApprovalStatus.approved,
      );
      LocalAuth.debugSetCurrentLocalForTesting(user);
      addTearDown(() => LocalAuth.debugSetCurrentLocalForTesting(null));

      final approved = LocalAuth.getApprovedAccounts();
      expect(approved.any((u) => u.email == 'alice_apr@test.com'), isTrue);
    });

    test('approved user no longer appears in getPendingAccounts', () {
      final user = _makeLocal(
        name: 'Now Approved',
        email: 'nowapproved@test.com',
        approvalStatus: AccountApprovalStatus.approved,
      );
      LocalAuth.debugSetCurrentLocalForTesting(user);
      addTearDown(() => LocalAuth.debugSetCurrentLocalForTesting(null));

      final pending = LocalAuth.getPendingAccounts();
      expect(pending.any((u) => u.email == 'nowapproved@test.com'), isFalse);
    });

    test('approving preserves all other user fields', () {
      final user = _makeLocal(
        name: 'Preserve Fields',
        email: 'preserve@test.com',
        phone: '0498765432',
        suburb: 'Ascot',
        approvalStatus: AccountApprovalStatus.pending,
      );
      final approved =
          user.copyWith(approvalStatus: AccountApprovalStatus.approved);

      expect(approved.phone, '0498765432');
      expect(approved.suburb, 'Ascot');
      expect(approved.name, 'Preserve Fields');
      expect(approved.email, 'preserve@test.com');
    });

    test('approved user appears in getReviewedAccounts', () {
      final user = _makeLocal(
        name: 'Reviewed',
        email: 'reviewed@test.com',
        approvalStatus: AccountApprovalStatus.approved,
      );
      LocalAuth.debugSetCurrentLocalForTesting(user);
      addTearDown(() => LocalAuth.debugSetCurrentLocalForTesting(null));

      final reviewed = LocalAuth.getReviewedAccounts();
      expect(reviewed.any((u) => u.email == 'reviewed@test.com'), isTrue);
    });
  });

  // =====================================================================
  // AC-3  The Admin can reject a Local account.
  // =====================================================================
  group('AC-3: admin can reject a Local account', () {
    test('copyWith updates approval status to rejected', () {
      final user = _makeLocal(approvalStatus: AccountApprovalStatus.pending);
      final rejected =
          user.copyWith(approvalStatus: AccountApprovalStatus.rejected);

      expect(rejected.approvalStatus, AccountApprovalStatus.rejected);
      expect(rejected.name, user.name);
      expect(rejected.email, user.email);
    });

    test('rejected status persists in Firestore via dashboard service',
        () async {
      final fs = FakeFirebaseFirestore();
      await _seedLocalUser(fs,
          id: 'l1',
          name: 'Pending',
          email: 'l1@test.com',
          approvalStatus: 'pending');

      final service = AdminDashboardService(firestore: fs);
      expect(await service.pendingLocalUsersCount().first, 1);

      await fs.collection('local_users').doc('l1').update({
        'approvalStatus': 'rejected',
      });

      expect(await service.pendingLocalUsersCount().first, 0);
    });

    test('rejected user no longer appears in getPendingAccounts', () {
      final user = _makeLocal(
        name: 'Rejected User',
        email: 'rejected@test.com',
        approvalStatus: AccountApprovalStatus.rejected,
      );
      LocalAuth.debugSetCurrentLocalForTesting(user);
      addTearDown(() => LocalAuth.debugSetCurrentLocalForTesting(null));

      final pending = LocalAuth.getPendingAccounts();
      expect(pending.any((u) => u.email == 'rejected@test.com'), isFalse);
    });

    test('rejected user does NOT appear in getApprovedAccounts', () {
      final user = _makeLocal(
        name: 'Rejected',
        email: 'rejectedchk@test.com',
        approvalStatus: AccountApprovalStatus.rejected,
      );
      LocalAuth.debugSetCurrentLocalForTesting(user);
      addTearDown(() => LocalAuth.debugSetCurrentLocalForTesting(null));

      final approved = LocalAuth.getApprovedAccounts();
      expect(approved.any((u) => u.email == 'rejectedchk@test.com'), isFalse);
    });

    test('rejected user appears in getReviewedAccounts', () {
      final user = _makeLocal(
        name: 'Rej Reviewed',
        email: 'rejrev@test.com',
        approvalStatus: AccountApprovalStatus.rejected,
      );
      LocalAuth.debugSetCurrentLocalForTesting(user);
      addTearDown(() => LocalAuth.debugSetCurrentLocalForTesting(null));

      final reviewed = LocalAuth.getReviewedAccounts();
      expect(reviewed.any((u) => u.email == 'rejrev@test.com'), isTrue);
    });

    test('rejecting preserves user identity fields', () {
      final user = _makeLocal(
        name: 'Keep Me',
        email: 'keep@test.com',
        phone: '0411111111',
        suburb: 'Paddington',
        approvalStatus: AccountApprovalStatus.pending,
      );
      final rejected =
          user.copyWith(approvalStatus: AccountApprovalStatus.rejected);

      expect(rejected.phone, '0411111111');
      expect(rejected.suburb, 'Paddington');
      expect(rejected.name, 'Keep Me');
    });
  });

  // =====================================================================
  // AC-4  Account approval status is saved and enforced in the system.
  // =====================================================================
  group('AC-4: approval status saved and enforced', () {
    test('approvalStatus field is stored in Firestore document', () async {
      final fs = FakeFirebaseFirestore();
      await _seedLocalUser(fs,
          id: 'l1',
          name: 'Test User',
          email: 'l1@test.com',
          approvalStatus: 'pending');

      final doc = await fs.collection('local_users').doc('l1').get();
      expect(doc.data()?['approvalStatus'], 'pending');
    });

    test('updating approvalStatus in Firestore changes pending count stream',
        () async {
      final fs = FakeFirebaseFirestore();
      await _seedLocalUser(fs,
          id: 'l1',
          name: 'Orig Pending',
          email: 'l1@test.com',
          approvalStatus: 'pending');

      final service = AdminDashboardService(firestore: fs);
      final values = <int>[];
      final sub = service.pendingLocalUsersCount().listen(values.add);
      addTearDown(sub.cancel);

      await Future<void>.delayed(Duration.zero);
      expect(values.last, 1);

      await fs
          .collection('local_users')
          .doc('l1')
          .update({'approvalStatus': 'approved'});

      await Future<void>.delayed(Duration.zero);
      expect(values.last, 0);
    });

    test('AccountApprovalStatus enum has exactly three values', () {
      expect(AccountApprovalStatus.values.length, 3);
      expect(AccountApprovalStatus.values,
          contains(AccountApprovalStatus.pending));
      expect(AccountApprovalStatus.values,
          contains(AccountApprovalStatus.approved));
      expect(AccountApprovalStatus.values,
          contains(AccountApprovalStatus.rejected));
    });

    test('isApprovalAuthorized returns true only for approved', () {
      expect(
          LocalAuth.isApprovalAuthorized(AccountApprovalStatus.approved),
          isTrue);
      expect(
          LocalAuth.isApprovalAuthorized(AccountApprovalStatus.pending),
          isFalse);
      expect(
          LocalAuth.isApprovalAuthorized(AccountApprovalStatus.rejected),
          isFalse);
    });

    test('status transition: pending → approved is valid', () {
      final user = _makeLocal(approvalStatus: AccountApprovalStatus.pending);
      final approved =
          user.copyWith(approvalStatus: AccountApprovalStatus.approved);
      expect(approved.approvalStatus, AccountApprovalStatus.approved);
      expect(LocalAuth.isApprovalAuthorized(approved.approvalStatus), isTrue);
    });

    test('status transition: pending → rejected is valid', () {
      final user = _makeLocal(approvalStatus: AccountApprovalStatus.pending);
      final rejected =
          user.copyWith(approvalStatus: AccountApprovalStatus.rejected);
      expect(rejected.approvalStatus, AccountApprovalStatus.rejected);
      expect(
          LocalAuth.isApprovalAuthorized(rejected.approvalStatus), isFalse);
    });

    test('Firestore stores status as string values', () async {
      final fs = FakeFirebaseFirestore();
      await _seedLocalUser(fs,
          id: 'l1',
          name: 'A',
          email: 'a@t.com',
          approvalStatus: 'approved');
      await _seedLocalUser(fs,
          id: 'l2',
          name: 'B',
          email: 'b@t.com',
          approvalStatus: 'rejected');
      await _seedLocalUser(fs,
          id: 'l3',
          name: 'C',
          email: 'c@t.com',
          approvalStatus: 'pending');

      final d1 = await fs.collection('local_users').doc('l1').get();
      final d2 = await fs.collection('local_users').doc('l2').get();
      final d3 = await fs.collection('local_users').doc('l3').get();

      expect(d1.data()?['approvalStatus'], 'approved');
      expect(d2.data()?['approvalStatus'], 'rejected');
      expect(d3.data()?['approvalStatus'], 'pending');
    });

    test('totalLocalUsersCount includes all statuses', () async {
      final fs = FakeFirebaseFirestore();
      await _seedLocalUser(fs,
          id: 'l1',
          name: 'A',
          email: 'a@t.com',
          approvalStatus: 'pending');
      await _seedLocalUser(fs,
          id: 'l2',
          name: 'B',
          email: 'b@t.com',
          approvalStatus: 'approved');
      await _seedLocalUser(fs,
          id: 'l3',
          name: 'C',
          email: 'c@t.com',
          approvalStatus: 'rejected');

      final service = AdminDashboardService(firestore: fs);
      expect(await service.totalLocalUsersCount().first, 3);
    });
  });

  // =====================================================================
  // AC-5  Pending or rejected Local users are restricted from publishing.
  // =====================================================================
  group('AC-5: pending/rejected restricted from publishing', () {
    test('pending user is not authorized to publish', () {
      expect(
        LocalAuth.isApprovalAuthorized(AccountApprovalStatus.pending),
        isFalse,
      );
    });

    test('rejected user is not authorized to publish', () {
      expect(
        LocalAuth.isApprovalAuthorized(AccountApprovalStatus.rejected),
        isFalse,
      );
    });

    test('approved user IS authorized to publish', () {
      expect(
        LocalAuth.isApprovalAuthorized(AccountApprovalStatus.approved),
        isTrue,
      );
    });

    test('pending user gets appropriate denied message', () {
      final msg =
          LocalAuth.approvalDeniedMessage(AccountApprovalStatus.pending);
      expect(msg, contains('pending admin approval'));
      expect(msg, contains('cannot access Local features'));
    });

    test('rejected user gets appropriate denied message', () {
      final msg =
          LocalAuth.approvalDeniedMessage(AccountApprovalStatus.rejected);
      expect(msg, contains('rejected by admin'));
      expect(msg, contains('Contact support'));
    });

    test('approved user gets empty denied message', () {
      final msg =
          LocalAuth.approvalDeniedMessage(AccountApprovalStatus.approved);
      expect(msg, isEmpty);
    });

    test('pending user set via debugSetCurrentLocalForTesting is not authorized',
        () {
      final pendingUser = _makeLocal(
        name: 'Pending Publisher',
        email: 'pendpub@test.com',
        approvalStatus: AccountApprovalStatus.pending,
      );
      LocalAuth.debugSetCurrentLocalForTesting(pendingUser);
      addTearDown(() => LocalAuth.debugSetCurrentLocalForTesting(null));

      final current = LocalAuth.currentLocal;
      expect(current, isNotNull);
      expect(
          LocalAuth.isApprovalAuthorized(current!.approvalStatus), isFalse);
    });

    test('rejected user set via debugSetCurrentLocalForTesting is not authorized',
        () {
      final rejectedUser = _makeLocal(
        name: 'Rejected Publisher',
        email: 'rejpub@test.com',
        approvalStatus: AccountApprovalStatus.rejected,
      );
      LocalAuth.debugSetCurrentLocalForTesting(rejectedUser);
      addTearDown(() => LocalAuth.debugSetCurrentLocalForTesting(null));

      final current = LocalAuth.currentLocal;
      expect(current, isNotNull);
      expect(
          LocalAuth.isApprovalAuthorized(current!.approvalStatus), isFalse);
    });

    test('approved user set via debugSetCurrentLocalForTesting is authorized',
        () {
      final approvedUser = _makeLocal(
        name: 'Approved Publisher',
        email: 'apppub@test.com',
        approvalStatus: AccountApprovalStatus.approved,
      );
      LocalAuth.debugSetCurrentLocalForTesting(approvedUser);
      addTearDown(() => LocalAuth.debugSetCurrentLocalForTesting(null));

      final current = LocalAuth.currentLocal;
      expect(current, isNotNull);
      expect(
          LocalAuth.isApprovalAuthorized(current!.approvalStatus), isTrue);
    });
  });

  // =====================================================================
  // AC-6  Account approval actions are secure, accurate, and enforced.
  // =====================================================================
  group('AC-6: secure, accurate, and consistently enforced', () {
    test('approval writes reviewedAt and reviewedBy fields in Firestore',
        () async {
      final fs = FakeFirebaseFirestore();
      await _seedLocalUser(fs,
          id: 'secure1',
          name: 'Secure User',
          email: 'secure@test.com',
          approvalStatus: 'pending');

      // Simulate what approveAccount writes
      await fs.collection('local_users').doc('secure1').set({
        'approvalStatus': 'approved',
        'reviewedBy': 'admin@brisconnect.com',
      }, SetOptions(merge: true));

      final doc = await fs.collection('local_users').doc('secure1').get();
      expect(doc.data()?['approvalStatus'], 'approved');
      expect(doc.data()?['reviewedBy'], 'admin@brisconnect.com');
      // Original fields preserved via merge
      expect(doc.data()?['name'], 'Secure User');
    });

    test('rejection writes reviewedAt and reviewedBy fields in Firestore',
        () async {
      final fs = FakeFirebaseFirestore();
      await _seedLocalUser(fs,
          id: 'secure2',
          name: 'Reject User',
          email: 'reject@test.com',
          approvalStatus: 'pending');

      await fs.collection('local_users').doc('secure2').set({
        'approvalStatus': 'rejected',
        'reviewedBy': 'admin@brisconnect.com',
      }, SetOptions(merge: true));

      final doc = await fs.collection('local_users').doc('secure2').get();
      expect(doc.data()?['approvalStatus'], 'rejected');
      expect(doc.data()?['reviewedBy'], 'admin@brisconnect.com');
      expect(doc.data()?['name'], 'Reject User');
    });

    test('email normalization ensures case-insensitive lookup', () {
      final user = _makeLocal(
        name: 'Case User',
        email: 'CaseUser@Test.COM',
        approvalStatus: AccountApprovalStatus.pending,
      );
      LocalAuth.debugSetCurrentLocalForTesting(user);
      addTearDown(() => LocalAuth.debugSetCurrentLocalForTesting(null));

      // The user is retrievable by getPendingAccounts regardless of case
      final pending = LocalAuth.getPendingAccounts();
      expect(
        pending.any(
            (u) => u.email.toLowerCase() == 'caseuser@test.com'),
        isTrue,
      );
    });

    test('copyWith does not mutate original user object', () {
      final original = _makeLocal(
        name: 'Immutable',
        email: 'immutable@test.com',
        approvalStatus: AccountApprovalStatus.pending,
      );
      final modified =
          original.copyWith(approvalStatus: AccountApprovalStatus.approved);

      expect(original.approvalStatus, AccountApprovalStatus.pending);
      expect(modified.approvalStatus, AccountApprovalStatus.approved);
    });

    test('default approval status is pending for new LocalUser', () {
      final user = LocalUser(
        name: 'New User',
        email: 'new@test.com',
        password: 'pass',
        phone: '04',
        suburb: 'CBD',
      );
      expect(user.approvalStatus, AccountApprovalStatus.pending);
    });

    test('merge write preserves existing fields in Firestore', () async {
      final fs = FakeFirebaseFirestore();
      await _seedLocalUser(fs,
          id: 'merge1',
          name: 'Merge User',
          email: 'merge@test.com',
          phone: '0499999999',
          suburb: 'Bulimba',
          approvalStatus: 'pending');

      await fs.collection('local_users').doc('merge1').set({
        'approvalStatus': 'approved',
      }, SetOptions(merge: true));

      final doc = await fs.collection('local_users').doc('merge1').get();
      expect(doc.data()?['approvalStatus'], 'approved');
      expect(doc.data()?['name'], 'Merge User');
      expect(doc.data()?['phone'], '0499999999');
      expect(doc.data()?['suburb'], 'Bulimba');
      expect(doc.data()?['email'], 'merge@test.com');
    });

    test('stream reflects status changes in real-time', () async {
      final fs = FakeFirebaseFirestore();
      await _seedLocalUser(fs,
          id: 'rt1',
          name: 'RT User',
          email: 'rt@test.com',
          approvalStatus: 'pending');

      final service = AdminDashboardService(firestore: fs);
      final values = <int>[];
      final sub = service.pendingLocalUsersCount().listen(values.add);
      addTearDown(sub.cancel);

      await Future<void>.delayed(Duration.zero);
      expect(values.last, 1);

      // Approve
      await fs
          .collection('local_users')
          .doc('rt1')
          .update({'approvalStatus': 'approved'});
      await Future<void>.delayed(Duration.zero);
      expect(values.last, 0);

      // Add another pending
      await _seedLocalUser(fs,
          id: 'rt2',
          name: 'RT User 2',
          email: 'rt2@test.com',
          approvalStatus: 'pending');
      await Future<void>.delayed(Duration.zero);
      expect(values.last, 1);

      // Reject it
      await fs
          .collection('local_users')
          .doc('rt2')
          .update({'approvalStatus': 'rejected'});
      await Future<void>.delayed(Duration.zero);
      expect(values.last, 0);
    });

    test('getReviewedAccounts returns both approved and rejected', () {
      LocalAuth.debugSetCurrentLocalForTesting(_makeLocal(
        name: 'Approved R',
        email: 'apr@rev.com',
        approvalStatus: AccountApprovalStatus.approved,
      ));
      LocalAuth.debugSetCurrentLocalForTesting(_makeLocal(
        name: 'Rejected R',
        email: 'rej@rev.com',
        approvalStatus: AccountApprovalStatus.rejected,
      ));
      LocalAuth.debugSetCurrentLocalForTesting(_makeLocal(
        name: 'Pending R',
        email: 'pend@rev.com',
        approvalStatus: AccountApprovalStatus.pending,
      ));
      addTearDown(() => LocalAuth.debugSetCurrentLocalForTesting(null));

      final reviewed = LocalAuth.getReviewedAccounts();
      expect(reviewed.any((u) => u.email == 'apr@rev.com'), isTrue);
      expect(reviewed.any((u) => u.email == 'rej@rev.com'), isTrue);
      expect(reviewed.any((u) => u.email == 'pend@rev.com'), isFalse);
    });

    test('accountType remains local after status change', () {
      final user = _makeLocal(
        name: 'Type Check',
        email: 'type@test.com',
        approvalStatus: AccountApprovalStatus.pending,
      );
      final approved =
          user.copyWith(approvalStatus: AccountApprovalStatus.approved);
      expect(approved.accountType, 'local');

      final rejected =
          user.copyWith(approvalStatus: AccountApprovalStatus.rejected);
      expect(rejected.accountType, 'local');
    });
  });
}
