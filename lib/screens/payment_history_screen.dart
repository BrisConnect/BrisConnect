import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:brisconnect/auth/local_auth.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:url_launcher/url_launcher.dart';

/// Screen where a business owner views their promotion payment history.
class PaymentHistoryScreen extends StatelessWidget {
  const PaymentHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ownerId = LocalAuth.currentLocal?.email ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFEBF4FF),
      appBar: AppBar(
        title: const Text('Payment History'),
        backgroundColor: AppPalette.ochre,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('business_payments')
              .where('ownerId', isEqualTo: ownerId)
              .where('type', isEqualTo: 'promotion')
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
                  'Could not load payment history.',
                  style: TextStyle(color: AppPalette.mutedText),
                ),
              );
            }

            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) {
              return const Center(
                child: Text(
                  'No promotion payments yet.',
                  style: TextStyle(color: AppPalette.mutedText),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final data = docs[index].data() as Map<String, dynamic>;
                return _PaymentHistoryCard(data: data);
              },
            );
          },
        ),
      ),
    );
  }
}

class _PaymentHistoryCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const _PaymentHistoryCard({required this.data});

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
    final title = data['planName'] as String? ??
        data['promotionTitle'] as String? ??
        'Promotion';
    final amountCents = (data['amountCents'] as num?)?.toInt() ?? 0;
    final status = data['status'] as String? ?? 'unknown';
    final paidAt = data['paidAt'];
    final expiresAt = data['expiresAt'];
    final receiptUrl = data['receiptUrl'] as String?;

    Color statusColor;
    switch (status) {
      case 'paid':
        statusColor = Colors.green;
        break;
      case 'expired':
        statusColor = AppPalette.mutedText;
        break;
      case 'deactivated':
        statusColor = Colors.redAccent;
        break;
      default:
        statusColor = AppPalette.mutedText;
    }

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
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppPalette.charcoal,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _InfoRow(label: 'Amount', value: _formattedPrice(amountCents)),
            _InfoRow(label: 'Paid', value: _formattedDate(paidAt)),
            _InfoRow(label: 'Expires', value: _formattedDate(expiresAt)),
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
