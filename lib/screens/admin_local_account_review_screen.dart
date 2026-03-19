import 'package:flutter/material.dart';
import 'package:brisconnect/auth/local_auth.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/widgets/logo_app_bar_title.dart';

class AdminLocalAccountReviewScreen extends StatefulWidget {
  const AdminLocalAccountReviewScreen({super.key});

  @override
  State<AdminLocalAccountReviewScreen> createState() => _AdminLocalAccountReviewScreenState();
}

class _AdminLocalAccountReviewScreenState extends State<AdminLocalAccountReviewScreen> {
  void _approveAccount(LocalUser account) {
    LocalAuth.approveAccount(account);
    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${account.name} approved.')),
    );
  }

  void _rejectAccount(LocalUser account) {
    LocalAuth.rejectAccount(account);
    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${account.name} rejected.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendingAccounts = LocalAuth.getPendingAccounts();
    final reviewedAccounts = LocalAuth.getReviewedAccounts();

    return Scaffold(
      backgroundColor: AppPalette.background,
      appBar: AppBar(
        title: const LogoAppBarTitle('Local Account Reviews'),
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
          if (pendingAccounts.isEmpty)
            const Card(
              color: AppPalette.surface,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No pending accounts to review.'),
              ),
            )
          else
            ...pendingAccounts.map(
              (account) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _PendingAccountCard(
                  account: account,
                  onApprove: () => _approveAccount(account),
                  onReject: () => _rejectAccount(account),
                ),
              ),
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
          if (reviewedAccounts.isEmpty)
            const Card(
              color: AppPalette.surface,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No reviewed accounts yet.'),
              ),
            )
          else
            ...reviewedAccounts.map(
              (account) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ReviewedAccountCard(account: account),
              ),
            ),
        ],
      ),
    );
  }
}

class _PendingAccountCard extends StatelessWidget {
  final LocalUser account;
  final VoidCallback onApprove;
  final VoidCallback onReject;

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
