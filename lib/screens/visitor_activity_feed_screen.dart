import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:brisconnect/models/activity_feed_item.dart';
import 'package:brisconnect/screens/visitor_event_detail_screen.dart';
import 'package:brisconnect/services/activity_feed_service.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/widgets/logo_app_bar_title.dart';

/// Visitor-facing community activity feed.
///
/// Shows a unified stream of reviews, events, businesses, and photo activity.
/// Users can filter by content type using a single-tap chip bar. Tapping a
/// card opens the related business or event detail screen.
class VisitorActivityFeedScreen extends StatefulWidget {
  final ActivityFeedService? activityFeedService;

  const VisitorActivityFeedScreen({super.key, this.activityFeedService});

  @override
  State<VisitorActivityFeedScreen> createState() =>
      _VisitorActivityFeedScreenState();
}

class _VisitorActivityFeedScreenState extends State<VisitorActivityFeedScreen> {
  late final ActivityFeedService _service =
      widget.activityFeedService ?? ActivityFeedService();
  ActivityFeedType _selectedType = ActivityFeedType.all;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const LogoAppBarTitle('Community'),
        backgroundColor: const Color(0xFF1C1C2E),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildFilterChips(),
          Expanded(child: _buildFeed()),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    const filters = ActivityFeedType.values;
    return Container(
      color: const Color(0xFF0D1117),
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
                backgroundColor: const Color(0xFF1C1C2E),
                labelStyle: TextStyle(
                  color: selected ? Colors.white : Colors.white70,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: BorderSide(
                    color: selected
                        ? AppPalette.ochre
                        : Colors.white.withValues(alpha: 0.12),
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
          return const Center(
            child: CircularProgressIndicator(color: AppPalette.ochre),
          );
        }

        if (snapshot.hasError) {
          return _buildEmptyOrError(
            icon: Icons.error_outline_rounded,
            title: 'Could not load activity',
            subtitle: 'Pull down to try again.',
          );
        }

        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return _buildEmptyOrError(
            icon: Icons.dynamic_feed_outlined,
            title: 'No activity yet',
            subtitle: 'Be the first to post a review or share an event!',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) => _ActivityFeedCard(item: items[index]),
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
            Icon(icon, color: Colors.white.withValues(alpha: 0.2), size: 56),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF8B8FA8),
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
        return 'New';
      case ActivityFeedType.photo:
        return 'Photos';
    }
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

class _ActivityFeedCard extends StatelessWidget {
  const _ActivityFeedCard({required this.item});

  final ActivityFeedItem item;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _openDetail(context),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C2E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.06),
            width: 1,
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
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
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
                        color: Color(0xFF8B8FA8),
                        fontSize: 13,
                        height: 1.5,
                      ),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
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
          color: const Color(0xFF2A2A3E),
        ),
        errorWidget: (_, __, ___) => Container(
          height: 170,
          color: const Color(0xFF2A2A3E),
          alignment: Alignment.center,
          child: const Icon(Icons.image_not_supported_rounded,
              color: Color(0xFF8B8FA8)),
        ),
      ),
    );
  }

  Widget _buildTypeIcon() {
    final icon = switch (item.type) {
      ActivityFeedType.review => Icons.rate_review_rounded,
      ActivityFeedType.event => Icons.calendar_today_rounded,
      ActivityFeedType.business => Icons.storefront_rounded,
      ActivityFeedType.photo => Icons.photo_library_rounded,
      ActivityFeedType.all => Icons.dynamic_feed_rounded,
    };
    return Icon(icon, color: AppPalette.ochre, size: 16);
  }

  void _openDetail(BuildContext context) {
    // Cards navigate directly to the relevant detail screen. Review cards
    // deep-link to the business profile so the visitor can see the
    // recommendation in context.
    switch (item.type) {
      case ActivityFeedType.review:
      case ActivityFeedType.business:
      case ActivityFeedType.photo:
        Navigator.of(context).pushNamed(
          '/business/view',
          arguments: item.targetId,
        );
      case ActivityFeedType.event:
        _openEventDetail(context, item.targetId);
      case ActivityFeedType.all:
        // Should never happen; individual items always have a concrete type.
        break;
    }
  }

  void _openEventDetail(BuildContext context, String eventId) async {
    final doc = await FirebaseFirestore.instance
        .collection('business_events')
        .doc(eventId)
        .get();
    if (!context.mounted) return;
    if (!doc.exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This event is no longer available.')),
      );
      return;
    }
    final data = doc.data()!;
    final event = <String, dynamic>{'id': doc.id, ...data};
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VisitorEventDetailScreen(event: event),
      ),
    );
  }
}
