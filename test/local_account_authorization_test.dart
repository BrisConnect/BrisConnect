import 'package:flutter_test/flutter_test.dart';
import 'package:brisconnect/auth/local_auth.dart';

void main() {
  group('LocalAuth approval authorization', () {
    test('approved accounts are authorized', () {
      expect(
        LocalAuth.isApprovalAuthorized(AccountApprovalStatus.approved),
        isTrue,
      );
    });

    test('pending and rejected accounts are denied authorization', () {
      expect(
        LocalAuth.isApprovalAuthorized(AccountApprovalStatus.pending),
        isFalse,
      );
      expect(
        LocalAuth.isApprovalAuthorized(AccountApprovalStatus.rejected),
        isFalse,
      );
    });

    test('denied messages are explicit for pending and rejected statuses', () {
      expect(
        LocalAuth.approvalDeniedMessage(AccountApprovalStatus.pending),
        contains('pending admin approval'),
      );
      expect(
        LocalAuth.approvalDeniedMessage(AccountApprovalStatus.rejected),
        contains('rejected by admin'),
      );
    });
  });
}