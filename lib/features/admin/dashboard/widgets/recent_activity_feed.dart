import 'package:flutter/material.dart';
import 'package:brisconnect/features/admin/dashboard/widgets/admin_layout.dart';
import 'package:brisconnect/services/admin_dashboard_service.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:intl/intl.dart';

class RecentActivityFeed extends StatelessWidget {
  const RecentActivityFeed({
    super.key,
    required this.items,
  });

  final List<AdminActivityItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Recent Activity'),
        const SizedBox(height: 12),
        if (items.isEmpty)
          const AdminCard(
            child: SizedBox(
              height: 120,
              child: Center(
                child: Text(
                  'No recent activity',
                  style: TextStyle(color: AppPalette.mutedText),
                ),
              ),
            ),
          )
        else
          AdminCard(
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 24),
              itemBuilder: (context, index) => _ActivityRow(item: items[index]),
            ),
          ),
      ],
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.item});

  final AdminActivityItem item;

  @override
  Widget build(BuildContext context) {
    final timeLabel = item.createdAt != null
        ? DateFormat('dd MMM, HH:mm').format(item.createdAt!)
        : '';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: item.type.color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(item.type.icon, color: item.type.color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.message.isNotEmpty ? item.message : item.type.name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppPalette.charcoal,
                ),
              ),
              if (timeLabel.isNotEmpty)
                Text(
                  timeLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppPalette.mutedText,
                  ),
                ),
            ],
          ),
        ),
        if (item.relatedId != null)
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded,
                color: AppPalette.mutedText),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Open ${item.relatedCollection}/${item.relatedId}')),
              );
            },
          ),
      ],
    );
  }
}
