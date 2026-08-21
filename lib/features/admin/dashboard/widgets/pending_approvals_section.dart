import 'package:flutter/material.dart';
import 'package:brisconnect/features/admin/dashboard/admin_dashboard_state.dart';
import 'package:brisconnect/features/admin/dashboard/widgets/admin_layout.dart';
import 'package:brisconnect/services/admin_dashboard_service.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:intl/intl.dart';

class PendingApprovalsSection extends StatelessWidget {
  const PendingApprovalsSection({
    super.key,
    required this.items,
    required this.controller,
    this.onViewAll,
  });

  final List<PendingBusinessApproval> items;
  final AdminDashboardController controller;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Pending Approvals',
          onViewAll: onViewAll,
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          const AdminCard(
            child: SizedBox(
              height: 120,
              child: Center(
                child: Text(
                  'No businesses awaiting approval',
                  style: TextStyle(color: AppPalette.mutedText),
                ),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _ApprovalCard(
              item: items[index],
              onApprove: () => _confirmAction(
                context,
                title: 'Approve Business',
                message: 'Approve ${items[index].name}?',
                onConfirm: () => controller.approveBusiness(items[index].id),
              ),
              onReject: () => _confirmAction(
                context,
                title: 'Reject Business',
                message: 'Reject ${items[index].name}?',
                onConfirm: () => controller.rejectBusiness(items[index].id),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _confirmAction(
    BuildContext context, {
    required String title,
    required String message,
    required VoidCallback onConfirm,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm', style: TextStyle(color: AppPalette.ochre)),
          ),
        ],
      ),
    );
    if (confirmed == true) onConfirm();
  }
}

class _ApprovalCard extends StatelessWidget {
  const _ApprovalCard({
    required this.item,
    required this.onApprove,
    required this.onReject,
  });

  final PendingBusinessApproval item;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final dateLabel = item.createdAt != null
        ? DateFormat('dd MMM yyyy').format(item.createdAt!)
        : 'Unknown date';

    return AdminCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Logo(logoUrl: item.logoUrl),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name.isNotEmpty ? item.name : 'Unnamed Business',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppPalette.charcoal,
                  ),
                ),
                const SizedBox(height: 4),
                _InfoRow(icon: Icons.category_rounded, text: item.category),
                const SizedBox(height: 2),
                _InfoRow(icon: Icons.calendar_today_rounded, text: dateLabel),
              ],
            ),
          ),
          Column(
            children: [
              _IconButton(
                icon: Icons.check_rounded,
                color: const Color(0xFF10B981),
                onTap: onApprove,
              ),
              const SizedBox(height: 8),
              _IconButton(
                icon: Icons.close_rounded,
                color: const Color(0xFFEF4444),
                onTap: onReject,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo({this.logoUrl});

  final String? logoUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: AppPalette.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: logoUrl != null && logoUrl!.isNotEmpty
            ? Image.network(
                logoUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.business_rounded,
                  color: AppPalette.mutedText,
                ),
              )
            : const Icon(
                Icons.business_rounded,
                color: AppPalette.mutedText,
              ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppPalette.mutedText),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text.isNotEmpty ? text : '—',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              color: AppPalette.mutedText,
            ),
          ),
        ),
      ],
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, color: color, size: 20),
        ),
      ),
    );
  }
}
