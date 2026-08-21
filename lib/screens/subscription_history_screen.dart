import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:brisconnect/auth/local_auth.dart';
import 'package:brisconnect/screens/subscription_plans_screen.dart';
import 'package:brisconnect/services/stripe_payment_service.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/utils/checkout_window_export.dart';
import 'package:url_launcher/url_launcher.dart';

/// Screen where a business owner views their subscription status and history.
class SubscriptionHistoryScreen extends StatelessWidget {
  const SubscriptionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ownerId = LocalAuth.currentLocal?.email ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFEBF4FF),
      appBar: AppBar(
        title: const Text('Subscription'),
        backgroundColor: AppPalette.ochre,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot>(
          stream: ownerId.isEmpty
              ? const Stream.empty()
              : FirebaseFirestore.instance
                  .collection('business_subscriptions')
                  .doc(ownerId)
                  .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppPalette.ochre),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Could not load subscription details.',
                  style: TextStyle(color: AppPalette.mutedText),
                ),
              );
            }

            final data = snapshot.data?.data() as Map<String, dynamic>?;
            final hasSubscription = data != null &&
                (data['status'] == 'active' || data['status'] == 'trialing');

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatusCard(context, ownerId, hasSubscription, data),
                  const SizedBox(height: 24),
                  const Text(
                    'Billing History',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppPalette.charcoal,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _BillingHistoryList(ownerId: ownerId),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context, String ownerId, bool isActive,
      Map<String, dynamic>? data) {
    final planName = data?['planName'] as String? ?? 'Premium Subscription';
    final status = data?['status'] as String? ?? 'none';
    final currentPeriodEnd = data?['currentPeriodEnd'];
    final endDate =
        currentPeriodEnd is Timestamp ? currentPeriodEnd.toDate() : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFD1FAE5) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive
              ? Colors.green.withValues(alpha: 0.3)
              : Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isActive ? Icons.workspace_premium_rounded : Icons.lock_outline,
                color: isActive ? Colors.green : AppPalette.mutedText,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isActive ? planName : 'No active subscription',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color:
                        isActive ? AppPalette.charcoal : AppPalette.mutedText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isActive
                ? 'Status: ${status[0].toUpperCase()}${status.substring(1)}'
                : 'Subscribe to unlock AI post creation and premium visibility.',
            style: TextStyle(
              color: isActive ? AppPalette.charcoal : AppPalette.mutedText,
            ),
          ),
          if (isActive && endDate != null) ...[
            const SizedBox(height: 8),
            Text(
              'Renews on: ${_formatDate(endDate)}',
              style: const TextStyle(
                color: AppPalette.charcoal,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _handlePortalAction(context, ownerId, isActive),
              icon: Icon(
                isActive ? Icons.settings_rounded : Icons.lock_open_rounded,
                size: 18,
              ),
              label: Text(isActive ? 'Manage Subscription' : 'View Plans'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppPalette.ochre,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handlePortalAction(
      BuildContext context, String ownerId, bool isActive) async {
    if (ownerId.isEmpty) return;

    if (!isActive) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const SubscriptionPlansScreen(),
        ),
      );
      return;
    }

    final checkoutWindow = kIsWeb ? openBlankCheckoutWindow() : null;
    if (kIsWeb && (checkoutWindow == null || !checkoutWindow.isOpen)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not open portal. Please allow pop-ups for this site.',
            ),
          ),
        );
      }
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: Center(
          child: CircularProgressIndicator(color: AppPalette.ochre),
        ),
      ),
    );

    final opened = await StripePaymentService.openBillingPortal(
      ownerId: ownerId,
      checkoutWindow: checkoutWindow,
    );

    if (context.mounted) Navigator.of(context).pop();

    if (!opened && context.mounted) {
      checkoutWindow?.close();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            StripePaymentService.lastErrorMessage ??
                'Could not open billing portal.',
          ),
        ),
      );
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

class _BillingHistoryList extends StatelessWidget {
  final String ownerId;

  const _BillingHistoryList({required this.ownerId});

  @override
  Widget build(BuildContext context) {
    if (ownerId.isEmpty) {
      return const Center(
        child: Text(
          'Sign in to view billing history.',
          style: TextStyle(color: AppPalette.mutedText),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('business_payments')
          .where('ownerId', isEqualTo: ownerId)
          .where('type', isEqualTo: 'subscription')
          .orderBy('paidAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppPalette.ochre),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Could not load billing history.',
              style: TextStyle(color: AppPalette.mutedText),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(
            child: Text(
              'No subscription payments yet.',
              style: TextStyle(color: AppPalette.mutedText),
            ),
          );
        }

        return Column(
          children: docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return _BillingHistoryCard(data: data);
          }).toList(),
        );
      },
    );
  }
}

class _BillingHistoryCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const _BillingHistoryCard({required this.data});

  String _formattedPrice(int cents) {
    return '\$${(cents / 100).toStringAsFixed(2)} AUD';
  }

  String _formattedDate(dynamic value) {
    if (value is Timestamp) {
      final date = value.toDate();
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    }
    return '—';
  }

  Future<void> _openReceipt(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = data['planName'] as String? ?? 'Subscription';
    final amountCents = (data['amountCents'] as num?)?.toInt() ?? 0;
    final paidAt = data['paidAt'];
    final receiptUrl = data['receiptUrl'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppPalette.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppPalette.charcoal,
              ),
            ),
            const SizedBox(height: 8),
            _InfoRow(label: 'Amount', value: _formattedPrice(amountCents)),
            _InfoRow(label: 'Paid', value: _formattedDate(paidAt)),
            if (receiptUrl != null && receiptUrl.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: InkWell(
                  onTap: () => _openReceipt(receiptUrl),
                  child: Row(
                    children: [
                      Icon(Icons.receipt_long_rounded,
                          size: 18, color: AppPalette.ochre),
                      const SizedBox(width: 8),
                      Text(
                        'View Stripe receipt',
                        style: TextStyle(
                          color: AppPalette.ochre,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppPalette.mutedText,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppPalette.charcoal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
