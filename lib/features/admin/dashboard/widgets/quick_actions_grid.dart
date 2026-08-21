import 'package:flutter/material.dart';
import 'package:brisconnect/features/admin/dashboard/widgets/admin_layout.dart';
import 'package:brisconnect/theme/app_palette.dart';

class QuickActionsGrid extends StatelessWidget {
  const QuickActionsGrid({
    super.key,
    required this.actions,
  });

  final List<QuickActionItem> actions;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 1024
            ? 3
            : constraints.maxWidth >= 600
                ? 2
                : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: constraints.maxWidth < 400 ? 2.6 : 3.2,
          ),
          itemCount: actions.length,
          itemBuilder: (context, index) => _QuickActionCard(
            item: actions[index],
          ),
        );
      },
    );
  }
}

class QuickActionItem {
  final IconData icon;
  final Color color;
  final String title;
  final String description;
  final VoidCallback onTap;

  QuickActionItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
    required this.onTap,
  });
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({required this.item});

  final QuickActionItem item;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: item.onTap,
        child: AdminCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(item.icon, color: item.color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppPalette.charcoal,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppPalette.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: AppPalette.mutedText,
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
