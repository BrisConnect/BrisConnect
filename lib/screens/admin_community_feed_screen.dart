import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:brisconnect/utils/admin_utils.dart';
import 'package:brisconnect/auth/app_user_role.dart';
import 'package:brisconnect/models/activity_feed_item.dart';
import 'package:brisconnect/services/activity_feed_service.dart';
import 'package:brisconnect/features/admin/dashboard/admin_neon_theme.dart';
import 'package:brisconnect/widgets/role_guard.dart';

/// Admin moderation screen for BrisConnect community content.
///
/// Admins can curate reviews, visitor photos, business posts, and recommendations.
/// Content can be pinned, highlighted, or removed. Changes are reflected
/// in the visitor feed in real time through Firestore snapshots.
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

/// Moderation-focused content types for the admin community feed.
enum AdminContentType {
  all,
  reviews,
  photos,
  businessPosts,
}

/// Moderation status for filtering content.
enum ModerationStatus {
  active,
  pinned,
  highlighted,
  removed,
}

class _AdminCommunityFeedScreenState extends State<AdminCommunityFeedScreen> {
  late final ActivityFeedService _service =
      widget.activityFeedService ?? ActivityFeedService();
  AdminContentType _selectedContentType = AdminContentType.all;
  final Set<ModerationStatus> _selectedStatuses = {ModerationStatus.active};
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screen = Scaffold(
      backgroundColor: AdminNeonTheme.bgDeepNavy,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AdminNeonTheme.headerBg,
        foregroundColor: AdminNeonTheme.textPrimary,
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'BrisConnect Community Feed',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: AdminNeonTheme.textPrimary,
                fontSize: 20,
              ),
            ),
            Text(
              'Moderate community content shared across BrisConnect',
              style: TextStyle(
                fontWeight: FontWeight.w400,
                color: AdminNeonTheme.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildContentTypeFilters(),
          _buildModerationStatusFilters(),
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

  Widget _buildSearchBar() {
    return Container(
      color: AdminNeonTheme.sidebarBg,
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
        style: const TextStyle(
          color: AdminNeonTheme.textPrimary,
          fontSize: 14,
        ),
        decoration: InputDecoration(
          hintText: 'Search community content...',
          hintStyle: const TextStyle(
            color: AdminNeonTheme.textMuted,
            fontSize: 14,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AdminNeonTheme.neonBlue,
            size: 20,
          ),
          filled: true,
          fillColor: AdminNeonTheme.glassSurface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: AdminNeonTheme.glassBorder,
              width: 1,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: AdminNeonTheme.glassBorder,
              width: 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: AdminNeonTheme.neonBlue,
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContentTypeFilters() {
    return Container(
      color: AdminNeonTheme.bgMidnight,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Content Type',
              style: TextStyle(
                color: AdminNeonTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: AdminContentType.values.map((type) {
                final selected = _selectedContentType == type;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _buildFilterChip(
                    label: _labelForContentType(type),
                    selected: selected,
                    onSelected: (_) =>
                        setState(() => _selectedContentType = type),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModerationStatusFilters() {
    return Container(
      color: AdminNeonTheme.bgMidnight,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Moderation Status',
              style: TextStyle(
                color: AdminNeonTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ModerationStatus.values.map((status) {
                final selected = _selectedStatuses.contains(status);
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _buildFilterChip(
                    label: _labelForStatus(status),
                    selected: selected,
                    onSelected: (_) {
                      setState(() {
                        if (selected) {
                          _selectedStatuses.remove(status);
                        } else {
                          _selectedStatuses.add(status);
                        }
                      });
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required ValueChanged<bool> onSelected,
  }) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      backgroundColor: AdminNeonTheme.glassSurface,
      selectedColor: AdminNeonTheme.neonBlue.withValues(alpha: 0.2),
      side: BorderSide(
        color: selected
            ? AdminNeonTheme.neonBlue
            : AdminNeonTheme.glassBorder.withValues(alpha: 0.5),
        width: selected ? 1.5 : 1,
      ),
      labelStyle: TextStyle(
        color: selected ? AdminNeonTheme.neonBlue : AdminNeonTheme.textSecondary,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }

  Widget _buildFeed() {
    return StreamBuilder<List<ActivityFeedItem>>(
      stream: _buildFeedStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: AdminNeonTheme.neonBlue,
            ),
          );
        }

        if (snapshot.hasError) {
          return _buildEmptyOrError(
            icon: Icons.error_outline_rounded,
            title: 'Could not load content',
            subtitle: _shortError(snapshot.error),
          );
        }

        final allItems = snapshot.data ?? [];
        final filteredItems =
            _filterItems(allItems).where(_matchesSearch).toList();

        if (filteredItems.isEmpty) {
          return _buildEmptyOrError(
            icon: Icons.dynamic_feed_outlined,
            title: 'No content found',
            subtitle: _searchQuery.isNotEmpty
                ? 'Try a different search query'
                : 'There is nothing to show for the selected filters.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          itemCount: filteredItems.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) => _AdminModerationCard(
            item: filteredItems[index],
            service: _service,
          ),
        );
      },
    );
  }

  Stream<List<ActivityFeedItem>> _buildFeedStream() {
    switch (_selectedContentType) {
      case AdminContentType.reviews:
        return _service
            .activityFeedStreamByType(ActivityFeedType.review)
            .map((items) => _sortByPriorityThenDate(items));
      case AdminContentType.photos:
        return _service
            .activityFeedStreamByType(ActivityFeedType.photo)
            .map((items) => _sortByPriorityThenDate(items));
      case AdminContentType.businessPosts:
        return _service
            .activityFeedStreamByType(ActivityFeedType.business)
            .map((items) => _sortByPriorityThenDate(items));
      case AdminContentType.all:
        return _buildAllContentStream();
    }
  }

  /// Returns every supported activity type for the "All" view.
  Stream<List<ActivityFeedItem>> _buildAllContentStream() {
    return _service.activityFeedStream(limit: 100).map(
          (items) => _sortByPriorityThenDate(items),
        );
  }

  List<ActivityFeedItem> _filterItems(List<ActivityFeedItem> items) {
    return items.where((item) {
      // Determine if item matches selected statuses
      if (_selectedStatuses.isEmpty) return true;

      bool matchesStatus = false;
      if (_selectedStatuses.contains(ModerationStatus.active) &&
          !item.isPinned &&
          !item.isHighlighted) {
        matchesStatus = true;
      }
      if (_selectedStatuses.contains(ModerationStatus.pinned) &&
          item.isPinned) {
        matchesStatus = true;
      }
      if (_selectedStatuses.contains(ModerationStatus.highlighted) &&
          item.isHighlighted) {
        matchesStatus = true;
      }
      return matchesStatus;
    }).toList();
  }

  bool _matchesSearch(ActivityFeedItem item) {
    if (_searchQuery.isEmpty) return true;

    return item.title.toLowerCase().contains(_searchQuery) ||
        item.subtitle.toLowerCase().contains(_searchQuery) ||
        item.body.toLowerCase().contains(_searchQuery) ||
        (item.businessName?.toLowerCase().contains(_searchQuery) ?? false) ||
        (item.actorName?.toLowerCase().contains(_searchQuery) ?? false);
  }

  List<ActivityFeedItem> _sortByPriorityThenDate(
    List<ActivityFeedItem> items,
  ) {
    items.sort((a, b) {
      // Pinned items first
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;
      if (a.isPinned && b.isPinned) {
        return (b.pinnedAt ?? b.createdAt)
            .compareTo(a.pinnedAt ?? a.createdAt);
      }

      // Then highlighted items
      if (a.isHighlighted && !b.isHighlighted) return -1;
      if (!a.isHighlighted && b.isHighlighted) return 1;
      if (a.isHighlighted && b.isHighlighted) {
        return (b.highlightedAt ?? b.createdAt)
            .compareTo(a.highlightedAt ?? a.createdAt);
      }

      // Then by date
      return b.createdAt.compareTo(a.createdAt);
    });
    return items;
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
            Icon(icon, color: AdminNeonTheme.textMuted, size: 56),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AdminNeonTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AdminNeonTheme.textMuted,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _labelForContentType(AdminContentType type) {
    switch (type) {
      case AdminContentType.all:
        return 'All';
      case AdminContentType.reviews:
        return 'Reviews';
      case AdminContentType.photos:
        return 'Photos';
      case AdminContentType.businessPosts:
        return 'Business Posts';
    }
  }

  String _labelForStatus(ModerationStatus status) {
    switch (status) {
      case ModerationStatus.active:
        return 'Active';
      case ModerationStatus.pinned:
        return 'Pinned';
      case ModerationStatus.highlighted:
        return 'Highlighted';
      case ModerationStatus.removed:
        return 'Removed';
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
}

class _AdminModerationCard extends StatefulWidget {
  final ActivityFeedItem item;
  final ActivityFeedService service;

  const _AdminModerationCard({required this.item, required this.service});

  @override
  State<_AdminModerationCard> createState() => _AdminModerationCardState();
}

class _AdminModerationCardState extends State<_AdminModerationCard>
    with AdminScreenMixin<_AdminModerationCard> {
  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final hasImage = item.imageUrl.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: AdminNeonTheme.glassSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getBorderColor(item),
          width: item.isPinned || item.isHighlighted ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasImage) _buildImage(item.imageUrl),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(item),
                const SizedBox(height: 8),
                _buildMetadata(item),
                if (item.body.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    item.body,
                    style: const TextStyle(
                      color: AdminNeonTheme.textPrimary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 10),
                _buildActions(item),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getBorderColor(ActivityFeedItem item) {
    if (item.isPinned) return AdminNeonTheme.neonBlue;
    if (item.isHighlighted) return AdminNeonTheme.neonOrange;
    return AdminNeonTheme.glassBorder.withValues(alpha: 0.5);
  }

  Widget _buildImage(String url) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      child: CachedNetworkImage(
        imageUrl: url,
        height: 150,
        width: double.infinity,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          height: 150,
          color: AdminNeonTheme.bgMidnight,
          alignment: Alignment.center,
          child: const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AdminNeonTheme.neonBlue,
            ),
          ),
        ),
        errorWidget: (_, __, ___) => Container(
          height: 150,
          color: AdminNeonTheme.bgMidnight,
          alignment: Alignment.center,
          child: Icon(
            Icons.image_not_supported_rounded,
            color: AdminNeonTheme.textMuted,
            size: 40,
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ActivityFeedItem item) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: AdminNeonTheme.neonBlue.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            _getContentTypeLabel(item.type),
            style: const TextStyle(
              color: AdminNeonTheme.neonBlue,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            item.title,
            style: const TextStyle(
              color: AdminNeonTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        _buildStatusBadges(item),
      ],
    );
  }

  Widget _buildStatusBadges(ActivityFeedItem item) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (item.isPinned)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AdminNeonTheme.neonBlue.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.push_pin_rounded,
                      size: 10, color: AdminNeonTheme.neonBlue),
                  SizedBox(width: 2),
                  Text(
                    'Pinned',
                    style: TextStyle(
                      color: AdminNeonTheme.neonBlue,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (item.isHighlighted)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AdminNeonTheme.neonOrange.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.star_rounded,
                    size: 10, color: AdminNeonTheme.neonOrange),
                SizedBox(width: 2),
                Text(
                  'Highlighted',
                  style: TextStyle(
                    color: AdminNeonTheme.neonOrange,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildMetadata(ActivityFeedItem item) {
    final author = item.actorName ?? item.businessName ?? 'Unknown';
    final dateStr = DateFormat('dd MMM yyyy • h:mm a').format(item.createdAt);

    return Row(
      children: [
        Expanded(
          child: Text(
            'By $author',
            style: const TextStyle(
              color: AdminNeonTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          dateStr,
          style: const TextStyle(
            color: AdminNeonTheme.textMuted,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildActions(ActivityFeedItem item) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _buildActionButton(
          icon: item.isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
          label: item.isPinned ? 'Unpin' : 'Pin',
          onPressed: isLoading ? null : _togglePin,
          color: AdminNeonTheme.neonBlue,
        ),
        const SizedBox(width: 8),
        _buildActionButton(
          icon:
              item.isHighlighted ? Icons.star_rounded : Icons.star_outline_rounded,
          label: item.isHighlighted ? 'Unhighlight' : 'Highlight',
          onPressed: isLoading ? null : _toggleHighlight,
          color: AdminNeonTheme.neonOrange,
        ),
        const SizedBox(width: 8),
        _buildActionButton(
          icon: Icons.delete_outline_rounded,
          label: 'Remove',
          onPressed: isLoading ? null : _confirmRemove,
          color: Colors.red,
          isDestructive: true,
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    required Color color,
    bool isDestructive = false,
  }) {
    return SizedBox(
      height: 32,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(label, style: const TextStyle(fontSize: 12)),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withValues(alpha: 0.5), width: 1),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
    );
  }

  String _getContentTypeLabel(ActivityFeedType type) {
    switch (type) {
      case ActivityFeedType.review:
        return 'REVIEW';
      case ActivityFeedType.photo:
        return 'PHOTO';
      case ActivityFeedType.business:
        return 'POST';
      default:
        return 'CONTENT';
    }
  }

  Future<void> _togglePin() async {
    await runAdminAction(
      () async {
        if (widget.item.isPinned) {
          await widget.service.unpinItem(widget.item);
        } else {
          await widget.service.pinItem(widget.item);
        }
      },
      success: widget.item.isPinned ? 'Unpinned' : 'Pinned',
    );
  }

  Future<void> _toggleHighlight() async {
    await runAdminAction(
      () async {
        if (widget.item.isHighlighted) {
          await widget.service.unhighlightItem(widget.item);
        } else {
          await widget.service.highlightItem(widget.item);
        }
      },
      success:
          widget.item.isHighlighted ? 'Highlight removed' : 'Highlighted',
    );
  }

  Future<void> _confirmRemove() async {
    final confirmed = await AdminUtils.showConfirmDialog(
      context,
      title: 'Remove from community feed',
      content: 'Remove "${widget.item.title}" from the community feed? '
          'This action cannot be undone.',
      confirmText: 'Remove',
      confirmColor: Colors.red,
    );
    if (confirmed != true || !mounted) return;

    await runAdminAction(
      () => widget.service.removeItem(
        widget.item,
        adminEmail: AdminUtils.currentAdminEmail,
      ),
      success: 'Removed from feed',
    );
  }
}
