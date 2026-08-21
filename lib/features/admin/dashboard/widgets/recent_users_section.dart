import 'package:flutter/material.dart';
import 'package:brisconnect/features/admin/dashboard/widgets/admin_layout.dart';
import 'package:brisconnect/services/admin_dashboard_service.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:intl/intl.dart';

class RecentUsersSection extends StatelessWidget {
  const RecentUsersSection({
    super.key,
    required this.users,
    this.onViewAll,
  });

  final List<RecentAdminUser> users;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: 'Recent Users', onViewAll: onViewAll),
        const SizedBox(height: 12),
        if (users.isEmpty)
          const AdminCard(
            child: SizedBox(
              height: 120,
              child: Center(
                child: Text(
                  'No recent users',
                  style: TextStyle(color: AppPalette.mutedText),
                ),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: users.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _UserCard(user: users[index]),
          ),
      ],
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({required this.user});

  final RecentAdminUser user;

  @override
  Widget build(BuildContext context) {
    final dateLabel = user.createdAt != null
        ? DateFormat('dd MMM yyyy').format(user.createdAt!)
        : 'Unknown';
    final displayName = user.name;
    final displaySubtitle = _subtitle(user);

    return AdminCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          _Avatar(name: displayName),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppPalette.charcoal,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  displaySubtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppPalette.mutedText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dateLabel,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppPalette.mutedText,
                  ),
                ),
              ],
            ),
          ),
          StatusBadge(label: user.status.label, color: user.status.color),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded,
                color: AppPalette.mutedText),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'view', child: Text('View Profile')),
              PopupMenuItem(value: 'edit', child: Text('Edit Role')),
            ],
            onSelected: (value) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Open $value for ${user.email}')),
              );
            },
          ),
        ],
      ),
    );
  }

  String _subtitle(RecentAdminUser user) {
    if (user.email.isNotEmpty && user.email != user.id) return user.email;
    return 'Role: ${_capitalize(user.role)}';
  }

  String _capitalize(String value) {
    if (value.isEmpty) return value;
    return '${value[0].toUpperCase()}${value.substring(1)}';
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 22,
      backgroundColor: AppPalette.ochre.withValues(alpha: 0.18),
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          color: AppPalette.ochre,
          fontSize: 16,
        ),
      ),
    );
  }
}
