import 'package:flutter/material.dart';
import 'package:brisconnect/features/admin/dashboard/widgets/admin_layout.dart';
import 'package:brisconnect/services/admin_dashboard_service.dart';
import 'package:brisconnect/theme/app_palette.dart';

class TodaySummaryCard extends StatelessWidget {
  const TodaySummaryCard({
    super.key,
    required this.summary,
    this.onReviewApprovals,
    this.onViewReports,
    this.onManagePromotions,
  });

  final TodaySummary? summary;
  final VoidCallback? onReviewApprovals;
  final VoidCallback? onViewReports;
  final VoidCallback? onManagePromotions;

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
            "Today's Summary",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppPalette.charcoal,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _SummaryChip(
                icon: Icons.person_add_rounded,
                color: const Color(0xFF3B82F6),
                label: 'New Users',
                value: data.newUsers,
              ),
              _SummaryChip(
                icon: Icons.business_rounded,
                color: const Color(0xFF1E3A8A),
                label: 'New Businesses',
                value: data.newBusinesses,
              ),
              _SummaryChip(
                icon: Icons.pending_actions_rounded,
                color: const Color(0xFFF59E0B),
                label: 'Awaiting Approval',
                value: data.pendingApprovals,
              ),
              _SummaryChip(
                icon: Icons.report_rounded,
                color: const Color(0xFFEF4444),
                label: 'New Reports',
                value: data.newReports,
              ),
              _SummaryChip(
                icon: Icons.campaign_rounded,
                color: const Color(0xFF8B5CF6),
                label: 'Active Promotions',
                value: data.activePromotions,
              ),
              _SummaryChip(
                icon: Icons.calendar_today_rounded,
                color: const Color(0xFFEC4899),
                label: 'Expiring Subs',
                value: data.expiringSubscriptions,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _ActionChipButton(
                label: 'Review Approvals',
                onTap: onReviewApprovals,
              ),
              _ActionChipButton(
                label: 'View Reports',
                onTap: onViewReports,
              ),
              _ActionChipButton(
                label: 'Manage Promotions',
                onTap: onManagePromotions,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$value',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: color,
                  height: 1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppPalette.mutedText,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionChipButton extends StatelessWidget {
  const _ActionChipButton({
    required this.label,
    this.onTap,
  });

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: AppPalette.deepBlue,
        ),
      ),
      backgroundColor: AppPalette.deepBlue.withValues(alpha: 0.08),
      side: BorderSide.none,
      onPressed: onTap,
    );
  }
}
