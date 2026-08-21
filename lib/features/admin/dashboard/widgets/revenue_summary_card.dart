import 'package:flutter/material.dart';
import 'package:brisconnect/features/admin/dashboard/widgets/admin_layout.dart';
import 'package:brisconnect/services/admin_dashboard_service.dart';
import 'package:brisconnect/theme/app_palette.dart';

class RevenueSummaryCard extends StatelessWidget {
  const RevenueSummaryCard({
    super.key,
    required this.summary,
  });

  final RevenueSummary? summary;

  @override
  Widget build(BuildContext context) {
    final data = summary;
    if (data == null) {
      return const AdminCard(
        child: SizedBox(
          height: 160,
          child: Center(
            child: CircularProgressIndicator(color: AppPalette.ochre),
          ),
        ),
      );
    }

    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Revenue & Subscriptions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppPalette.charcoal,
            ),
          ),
          const SizedBox(height: 16),
          _RevenueRow(
            label: 'Revenue Today',
            value: '\$${_formatMoney(data.revenueToday)}',
            icon: Icons.attach_money_rounded,
            color: const Color(0xFF10B981),
          ),
          const SizedBox(height: 12),
          _RevenueRow(
            label: 'Monthly Revenue',
            value: '\$${_formatMoney(data.monthlyRevenue)}',
            icon: Icons.account_balance_wallet_rounded,
            color: const Color(0xFF3B82F6),
          ),
          const SizedBox(height: 12),
          _RevenueRow(
            label: 'Active Subscribers',
            value: '${data.activeSubscribers}',
            icon: Icons.workspace_premium_rounded,
            color: const Color(0xFF8B5CF6),
          ),
          const SizedBox(height: 12),
          _RevenueRow(
            label: 'Cancelled Subscriptions',
            value: '${data.cancelledSubscriptions}',
            icon: Icons.cancel_rounded,
            color: const Color(0xFFEF4444),
          ),
          const SizedBox(height: 12),
          _RevenueRow(
            label: 'Monthly Recurring Revenue',
            value: '\$${_formatMoney(data.monthlyRecurringRevenue)}',
            icon: Icons.repeat_rounded,
            color: const Color(0xFFEC4899),
          ),
          const SizedBox(height: 12),
          _RevenueRow(
            label: 'Promotions Running',
            value: '${data.runningPromotions}',
            icon: Icons.campaign_rounded,
            color: const Color(0xFFF59E0B),
          ),
        ],
      ),
    );
  }

  String _formatMoney(double value) {
    return value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 2);
  }
}

class _RevenueRow extends StatelessWidget {
  const _RevenueRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppPalette.mutedText,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: AppPalette.charcoal,
          ),
        ),
      ],
    );
  }
}
