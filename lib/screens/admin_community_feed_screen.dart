import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:brisconnect/auth/app_user_role.dart';
import 'package:brisconnect/models/activity_feed_item.dart';
import 'package:brisconnect/services/activity_feed_service.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/widgets/role_guard.dart';

/// Admin screen for curating the visitor community feed.
///
/// Admins can pin or highlight posts, remove spam or irrelevant content,
/// and filter the feed by content type. Changes are reflected in the
/// visitor feed in real time through Firestore snapshots.
class AdminCommunityFeedScreen extends StatefulWidget {
  final ActivityFeedService? activityFeedService;
  final bool enforceRoleGuard;

  const AdminCommunityFeedScreen({
    super.key,
    this.activityFeedService,
    this.enforceRoleGuard = true,
  });

  @override
  State<AdminCommunityFeedScreen> createState() =>
      _AdminCommunityFeedScreenState();
}

class _AdminCommunityFeedScreenState extends State<AdminCommunityFeedScreen> {
  late final ActivityFeedService _service =
      widget.activityFeedService ?? ActivityFeedService();
  ActivityFeedType _selectedType = ActivityFeedType.all;

  @override
  Widget build(BuildContext context) {
    final screen = Scaffold(
      backgroundColor: const Color(0xFFEBF4FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFEBF4FF),
        foregroundColor: const Color(0xFF1E3A8A),
        elevation: 0,
        title: const Text(
          'Community Feed',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: Color(0xFF1E3A8A),
          ),
        ),
      ),
      body: Column(
        children: [
          _buildFilterChips(),
          Expanded(child: _buildFeed()),
        ],
      ),
    );

    if (widget.enforceRoleGuard) {
      return RoleGuard(
        allowedRoles: const {AppUserRole.admin},
        deniedMessage: 'Access denied. Admin privileges are required.',
        child: screen,
      );
    }
    return screen;
  }

  Widget _buildFilterChips() {
    const filters = ActivityFeedType.values;
    return Container(
      color: AppPalette.background,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filters.map((type) {
            final selected = _selectedType == type;
            return Padding(
              padding: const EdgeInsets.only(right: 10),
              child: ChoiceChip(
                label: Text(_labelForType(type)),
                avatar: Icon(
                  _iconForType(type),
                  size: 18,
                  color: selected ? Colors.white : AppPalette.ochre,
                ),
                selected: selected,
                selectedColor: AppPalette.ochre,
                backgroundColor: AppPalette.surface,
                labelStyle: TextStyle(
                  color: selected ? Colors.white : AppPalette.charcoal,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: BorderSide(
                    color: selected
                        ? AppPalette.ochre
                        : AppPalette.border.withValues(alpha: 0.5),
                  ),
                ),
                onSelected: (_) => setState(() => _selectedType = type),
                showCheckmark: false,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildFeed() {
    return StreamBuilder<List<ActivityFeedItem>>(
      stream: _service.activityFeedStreamByType(_selectedType),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _buildEmptyOrError(
            icon: Icons.error_outline_rounded,
            title: 'Could not load activity',
            subtitle: _shortError(snapshot.error),
          );
        }

        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return _buildEmptyOrError(
            icon: Icons.dynamic_feed_outlined,
            title: 'No activity',
            subtitle: 'There is nothing to show for the selected filter.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) => _AdminFeedCard(
            item: items[index],
            service: _service,
          ),
        );
      },
    );
  }

  Widget _buildEmptyOrError({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppPalette.mutedText, size: 56),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppPalette.charcoal,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppPalette.mutedText,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _labelForType(ActivityFeedType type) {
    switch (type) {
      case ActivityFeedType.all:
        return 'All';
      case ActivityFeedType.review:
        return 'Reviews';
      case ActivityFeedType.event:
        return 'Events';
      case ActivityFeedType.business:
        return 'Businesses';
      case ActivityFeedType.photo:
        return 'Photos';
    }
  }

  String _shortError(Object? error) {
    final message = error.toString();
    if (message.contains('permission-denied')) {
      return 'Permission denied. Please log in again.';
    }
    if (message.contains('failed-precondition')) {
      return 'Database index is still building. Try again shortly.';
    }
    return message.length > 120 ? '${message.substring(0, 120)}…' : message;
  }

  IconData _iconForType(ActivityFeedType type) {
    switch (type) {
      case ActivityFeedType.all:
        return Icons.dynamic_feed_rounded;
      case ActivityFeedType.review:
        return Icons.rate_review_rounded;
      case ActivityFeedType.event:
        return Icons.calendar_today_rounded;
      case ActivityFeedType.business:
        return Icons.storefront_rounded;
      case ActivityFeedType.photo:
        return Icons.photo_library_rounded;
    }
  }
}

class _AdminFeedCard extends StatefulWidget {
  final ActivityFeedItem item;
  final ActivityFeedService service;

  const _AdminFeedCard({required this.item, required this.service});

  @override
  State<_AdminFeedCard> createState() => _AdminFeedCardState();
}

class _AdminFeedCardState extends State<_AdminFeedCard> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Card(
      color: AppPalette.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: item.isPinned
              ? AppPalette.ochre
              : item.isHighlighted
                  ? AppPalette.gold
                  : AppPalette.border,
          width: item.isPinned || item.isHighlighted ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item.imageUrl.isNotEmpty) _buildImage(item.imageUrl),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildTypeIcon(),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.title,
                        style: const TextStyle(
                          color: AppPalette.charcoal,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (item.isPinned)
                      _buildBadge(
                          Icons.push_pin_rounded, 'Pinned', AppPalette.ochre),
                    if (item.isHighlighted)
                      _buildBadge(
                          Icons.star_rounded, 'Highlighted', AppPalette.gold),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  item.subtitle,
                  style: const TextStyle(
                    color: AppPalette.ochre,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (item.body.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    item.body,
                    style: const TextStyle(
                      color: AppPalette.charcoal,
                      fontSize: 13,
                      height: 1.5,
                    ),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  alignment: WrapAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: _isLoading ? null : _togglePin,
                      icon: Icon(
                        item.isPinned
                            ? Icons.push_pin_rounded
                            : Icons.push_pin_outlined,
                        size: 18,
                      ),
                      label: Text(item.isPinned ? 'Unpin' : 'Pin'),
                    ),
                    TextButton.icon(
                      onPressed: _isLoading ? null : _toggleHighlight,
                      icon: Icon(
                        item.isHighlighted
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        size: 18,
                      ),
                      label: Text(
                          item.isHighlighted ? 'Unhighlight' : 'Highlight'),
                    ),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _confirmRemove,
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: const Text('Remove'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImage(String url) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: CachedNetworkImage(
        imageUrl: url,
        height: 170,
        width: double.infinity,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          height: 170,
          color: AppPalette.background,
        ),
        errorWidget: (_, __, ___) => Container(
          height: 170,
          color: AppPalette.background,
          alignment: Alignment.center,
          child: const Icon(Icons.image_not_supported_rounded,
              color: AppPalette.mutedText),
        ),
      ),
    );
  }

  Widget _buildBadge(IconData icon, String label, Color color) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeIcon() {
    final icon = switch (widget.item.type) {
      ActivityFeedType.review => Icons.rate_review_rounded,
      ActivityFeedType.event => Icons.calendar_today_rounded,
      ActivityFeedType.business => Icons.storefront_rounded,
      ActivityFeedType.photo => Icons.photo_library_rounded,
      ActivityFeedType.all => Icons.dynamic_feed_rounded,
    };
    return Icon(icon, color: AppPalette.ochre, size: 16);
  }

  Future<void> _togglePin() async {
    await _runAction(() async {
      if (widget.item.isPinned) {
        await widget.service.unpinItem(widget.item);
      } else {
        await widget.service.pinItem(widget.item);
      }
    }, success: widget.item.isPinned ? 'Item unpinned' : 'Item pinned');
  }

  Future<void> _toggleHighlight() async {
    await _runAction(() async {
      if (widget.item.isHighlighted) {
        await widget.service.unhighlightItem(widget.item);
      } else {
        await widget.service.highlightItem(widget.item);
      }
    },
        success: widget.item.isHighlighted
            ? 'Highlight removed'
            : 'Item highlighted');
  }

  Future<void> _confirmRemove() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove from feed'),
        content: Text(
          'Remove "${widget.item.title}" from the community feed? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await _runAction(
      () => widget.service.removeItem(widget.item),
      success: 'Item removed from feed',
    );
  }

  Future<void> _runAction(Future<void> Function() action,
      {required String success}) async {
    setState(() => _isLoading = true);
    try {
      await action();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(success)),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Action failed: $error'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
