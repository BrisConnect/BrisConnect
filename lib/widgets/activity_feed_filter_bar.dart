import 'package:flutter/material.dart';

import 'package:brisconnect/models/activity_feed_item.dart';
import 'package:brisconnect/theme/app_palette.dart';

/// Horizontal scrollable filter chips for the community activity feed.
///
/// Supports the full set of discovery filters: Trending, Nearby, Following,
/// Newest, Popular, and the content-type filters. On narrow screens, only
/// the most common filters are shown by default with the rest collapsed
/// behind a "More" chip to avoid an overwhelming wall of chips.
class ActivityFeedFilterBar extends StatefulWidget {
  final ActivityFeedType selectedType;
  final ValueChanged<ActivityFeedType> onSelected;

  const ActivityFeedFilterBar({
    super.key,
    required this.selectedType,
    required this.onSelected,
  });

  static const List<ActivityFeedType> _filters = [
    ActivityFeedType.all,
    ActivityFeedType.trending,
    ActivityFeedType.nearby,
    ActivityFeedType.following,
    ActivityFeedType.newest,
    ActivityFeedType.popular,
    ActivityFeedType.review,
    ActivityFeedType.event,
    ActivityFeedType.business,
    ActivityFeedType.photo,
  ];

  // The default-visible filters on narrow screens; the rest collapse behind
  // the "More" chip until expanded.
  static const List<ActivityFeedType> _primaryFilters = [
    ActivityFeedType.all,
    ActivityFeedType.trending,
    ActivityFeedType.nearby,
  ];

  static const double _collapseBreakpoint = 600;

  @override
  State<ActivityFeedFilterBar> createState() => _ActivityFeedFilterBarState();
}

class _ActivityFeedFilterBarState extends State<ActivityFeedFilterBar> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppPalette.background,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow =
              constraints.maxWidth < ActivityFeedFilterBar._collapseBreakpoint;
          final selectedInPrimary = ActivityFeedFilterBar._primaryFilters
              .contains(widget.selectedType);
          final expanded = !isNarrow || _expanded || !selectedInPrimary;

          final visibleFilters = expanded
              ? ActivityFeedFilterBar._filters
              : ActivityFeedFilterBar._primaryFilters;

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ...visibleFilters.map((type) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _buildChip(type),
                    )),
                if (isNarrow)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _buildMoreChip(expanded),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMoreChip(bool expanded) {
    return ActionChip(
      avatar: Icon(
        expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
        size: 16,
        color: AppPalette.ochre,
      ),
      label: Text(expanded ? 'Less' : 'More'),
      labelStyle: const TextStyle(
        color: AppPalette.charcoal,
        fontWeight: FontWeight.w700,
        fontSize: 12,
      ),
      backgroundColor: AppPalette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: AppPalette.border.withValues(alpha: 0.6)),
      ),
      onPressed: () => setState(() => _expanded = !_expanded),
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  Widget _buildChip(ActivityFeedType type) {
    final selected = widget.selectedType == type;
    return ChoiceChip(
      label: Text(_labelForType(type)),
      avatar: Icon(
        _iconForType(type),
        size: 16,
        color: selected ? Colors.white : AppPalette.ochre,
      ),
      selected: selected,
      selectedColor: AppPalette.ochre,
      backgroundColor: AppPalette.surface,
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppPalette.charcoal,
        fontWeight: FontWeight.w700,
        fontSize: 12,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: selected
              ? AppPalette.ochre
              : AppPalette.border.withValues(alpha: 0.6),
        ),
      ),
      onSelected: (_) => widget.onSelected(type),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 4),
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
        return 'Promotions';
      case ActivityFeedType.photo:
        return 'Crowd Updates';
      case ActivityFeedType.trending:
        return 'Trending';
      case ActivityFeedType.nearby:
        return 'Nearby';
      case ActivityFeedType.following:
        return 'Following';
      case ActivityFeedType.newest:
        return 'Newest';
      case ActivityFeedType.popular:
        return 'Popular';
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
        return Icons.people_rounded;
      case ActivityFeedType.trending:
        return Icons.trending_up_rounded;
      case ActivityFeedType.nearby:
        return Icons.near_me_rounded;
      case ActivityFeedType.following:
        return Icons.people_rounded;
      case ActivityFeedType.newest:
        return Icons.new_releases_rounded;
      case ActivityFeedType.popular:
        return Icons.whatshot_rounded;
    }
  }
}
