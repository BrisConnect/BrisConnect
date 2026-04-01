import 'package:flutter/material.dart';
import 'package:brisconnect/auth/app_user_role.dart';
import 'package:brisconnect/auth/local_auth.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/widgets/logo_app_bar_title.dart';
import 'package:brisconnect/widgets/role_guard.dart';

class AdminLocalAccountReviewScreen extends StatefulWidget {
  const AdminLocalAccountReviewScreen({super.key});

  @override
  State<AdminLocalAccountReviewScreen> createState() => _AdminLocalAccountReviewScreenState();
}

class _AdminLocalAccountReviewScreenState extends State<AdminLocalAccountReviewScreen> {
  bool _isUpdating = false;

  Future<void> _approveAccount(LocalUser account) async {
    if (_isUpdating) return;
    setState(() {
      _isUpdating = true;
    });

    final success = await LocalAuth.approveAccount(account);
    if (!mounted) {
      return;
    }

    setState(() {
      _isUpdating = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? '${account.name} approved.'
              : (LocalAuth.lastErrorMessage ?? 'Could not approve account.'),
        ),
      ),
    );
  }

  Future<void> _rejectAccount(LocalUser account) async {
    if (_isUpdating) return;
    setState(() {
      _isUpdating = true;
    });

    final success = await LocalAuth.rejectAccount(account);
    if (!mounted) {
      return;
    }

    setState(() {
      _isUpdating = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? '${account.name} rejected.'
              : (LocalAuth.lastErrorMessage ?? 'Could not reject account.'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RoleGuard(
      allowedRoles: const {AppUserRole.admin},
      deniedMessage: 'Access denied. Admin privileges are required.',
      child: Scaffold(
      backgroundColor: AppPalette.background,
      appBar: AppBar(
        title: const LogoAppBarTitle('Local Account Request'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Pending Accounts',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppPalette.charcoal,
            ),
          ),
          const SizedBox(height: 12),
          StreamBuilder<List<LocalUser>>(
            stream: LocalAuth.pendingAccountsStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return const Card(
                  color: AppPalette.surface,
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Unable to load pending accounts from Firestore.'),
                  ),
                );
              }

              final pendingAccounts = snapshot.data ?? const <LocalUser>[];
              if (pendingAccounts.isEmpty) {
                return const Card(
                  color: AppPalette.surface,
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No pending accounts to review.'),
                  ),
                );
              }

              return Column(
                children: pendingAccounts
                    .map(
                      (account) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _PendingAccountCard(
                          account: account,
                          onApprove: _isUpdating ? null : () => _approveAccount(account),
                          onReject: _isUpdating ? null : () => _rejectAccount(account),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 20),
          const Text(
            'Review History',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppPalette.charcoal,
            ),
          ),
          const SizedBox(height: 12),
          StreamBuilder<List<LocalUser>>(
            stream: LocalAuth.reviewedAccountsStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return const Card(
                  color: AppPalette.surface,
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Unable to load review history from Firestore.'),
                  ),
                );
              }

              final reviewedAccounts = snapshot.data ?? const <LocalUser>[];
              if (reviewedAccounts.isEmpty) {
                return const Card(
                  color: AppPalette.surface,
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No reviewed accounts yet.'),
                  ),
                );
              }

              return Column(
                children: reviewedAccounts
                    .map(
                      (account) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ReviewedAccountCard(account: account),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    ));
  }
}

class _PendingAccountCard extends StatelessWidget {
  final LocalUser account;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  const _PendingAccountCard({
    required this.account,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppPalette.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              account.name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppPalette.charcoal,
              ),
            ),
            const SizedBox(height: 8),
            Text('Email: ${account.email}'),
            Text('Phone: ${account.phone}'),
            Text('Suburb: ${account.suburb}'),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onReject,
                    icon: const Icon(Icons.close, color: AppPalette.ochre),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppPalette.ochre,
                      side: const BorderSide(color: AppPalette.ochre),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onApprove,
                    icon: const Icon(Icons.check),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppPalette.deepBlue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewedAccountCard extends StatelessWidget {
  final LocalUser account;

  const _ReviewedAccountCard({required this.account});

  @override
  Widget build(BuildContext context) {
    final isApproved = account.approvalStatus == AccountApprovalStatus.approved;
    final badgeColor = isApproved ? AppPalette.deepBlue : AppPalette.ochre;
    final badgeText = isApproved ? 'Approved' : 'Rejected';

    return Card(
      color: AppPalette.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    account.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppPalette.charcoal,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      color: badgeColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Email: ${account.email}'),
            Text('Suburb: ${account.suburb}'),
          ],
        ),
      ),
    );
  }
}
