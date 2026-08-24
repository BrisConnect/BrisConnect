import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:brisconnect/auth/visitor_auth.dart';
import 'package:brisconnect/models/activity_feed_item.dart';
import 'package:brisconnect/models/business.dart';
import 'package:brisconnect/services/activity_feed_service.dart';
import 'package:brisconnect/services/business_profile_service.dart';
import 'package:brisconnect/services/post_engagement_service.dart';
import 'package:brisconnect/services/visitor_photo_service.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/widgets/activity_feed_card.dart';
import 'package:brisconnect/widgets/activity_feed_create_post_card.dart';
import 'package:brisconnect/widgets/activity_feed_filter_bar.dart';
import 'package:brisconnect/widgets/submit_review_bottom_sheet.dart';
import 'package:brisconnect/widgets/visitor_photo_upload_sheet.dart';

/// Visitor-facing community activity feed.
///
/// Shows a unified stream of reviews, events, businesses, and photo activity.
/// Users can filter by content type using a single-tap chip bar. Tapping a
/// card opens the related business or event detail screen.
///
/// The UI has been broken into reusable widgets while all Firebase logic,
/// routing, authentication, and models remain unchanged.
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
  late final PostEngagementService _engagementService = PostEngagementService();
  ActivityFeedType _selectedType = ActivityFeedType.all;

  @override
  Widget build(BuildContext context) {
    // No Scaffold here: this is embedded as a tab inside the visitor
    // portal's Scaffold, which paints the falling food background behind it.
    return Column(
      children: [
        ActivityFeedFilterBar(
          selectedType: _selectedType,
          onSelected: (type) => setState(() => _selectedType = type),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 900;
              final content = CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: ActivityFeedCreatePostCard(
                      onWriteReview: () => _onWriteReview(context),
                      onAddPhoto: () => _onAddPhoto(context),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 8)),
                  _buildFeedSliver(),
                ],
              );

              if (isWide) {
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 960),
                    child: content,
                  ),
                );
              }

              return content;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFeedSliver() {
    final stream = _selectedType == ActivityFeedType.all
        ? _service.activityFeedStream(limit: 100)
        : _service.activityFeedStreamByType(_selectedType);
    return StreamBuilder<List<ActivityFeedItem>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverFillRemaining(
            child: Center(
              child: CircularProgressIndicator(color: AppPalette.ochre),
            ),
          );
        }

        if (snapshot.hasError) {
          return SliverFillRemaining(
            child: _buildEmptyOrError(
              icon: Icons.error_outline_rounded,
              title: 'Could not load activity',
              subtitle: _shortError(snapshot.error),
            ),
          );
        }

        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return SliverFillRemaining(
            child: _buildEmptyOrError(
              icon: Icons.dynamic_feed_outlined,
              title: 'No activity yet',
              subtitle: 'Be the first to post a review or share an event!',
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          sliver: SliverList.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 24),
            itemBuilder: (context, index) => ActivityFeedCard(
              item: items[index],
              engagementService: _engagementService,
            ),
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
            Icon(icon,
                color: AppPalette.mutedText.withValues(alpha: 0.4), size: 56),
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

  Future<void> _onWriteReview(BuildContext context) async {
    if (!VisitorAuth.isVisitorLoggedIn) {
      _showSignInSnack(context, 'sign in to write a review');
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final businessId = await _pickBusinessForPost(context, 'review');
    if (businessId == null || !context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppPalette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SubmitReviewBottomSheet(
        businessId: businessId,
        visitorId: user.uid,
        visitorName:
            user.displayName ?? VisitorAuth.currentVisitor?.name ?? 'Anonymous',
        onReviewSubmitted: (_) {},
      ),
    );
  }

  Future<void> _onAddPhoto(BuildContext context) async {
    if (!VisitorAuth.isVisitorLoggedIn) {
      _showSignInSnack(context, 'sign in to upload a photo');
      return;
    }
    final visitor = VisitorAuth.currentVisitor;
    if (visitor == null) return;

    final businessId = await _pickBusinessForPost(context, 'photo');
    if (businessId == null || !context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => VisitorPhotoUploadSheet(
        businessId: businessId,
        visitorName: visitor.name,
        service: VisitorPhotoService(),
      ),
    );
  }

  Future<String?> _pickBusinessForPost(
    BuildContext context,
    String actionLabel,
  ) async {
    final service = BusinessProfileService();

    // Show a non-dismissible loading indicator while the merged business list
    // loads; this prevents the user from thinking the tap was ignored.
    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: CircularProgressIndicator(color: AppPalette.ochre),
        ),
      );
    }

    final List<Business> businesses;
    try {
      businesses = await service.searchBusinesses('');
    } catch (e) {
      if (context.mounted) Navigator.of(context).pop();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load businesses: ${e.toString()}')),
        );
      }
      return null;
    }

    if (context.mounted) Navigator.of(context).pop();
    if (!context.mounted) return null;
    if (businesses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No businesses available yet.')),
      );
      return null;
    }

    String? selectedId;
    await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppPalette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return _BusinessPickerSheet(
          actionLabel: actionLabel,
          businesses: businesses,
          onSelected: (id) {
            selectedId = id;
            Navigator.pop(ctx);
          },
        );
      },
    );
    return selectedId;
  }
}

class _BusinessPickerSheet extends StatefulWidget {
  final String actionLabel;
  final List<Business> businesses;
  final ValueChanged<String?> onSelected;

  const _BusinessPickerSheet({
    required this.actionLabel,
    required this.businesses,
    required this.onSelected,
  });

  @override
  State<_BusinessPickerSheet> createState() => _BusinessPickerSheetState();
}

class _BusinessPickerSheetState extends State<_BusinessPickerSheet> {
  late final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Business> get _filtered {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return widget.businesses;
    return widget.businesses.where((b) {
      final name = b.businessName.isNotEmpty ? b.businessName : (b.id ?? '');
      return name.toLowerCase().contains(query) ||
          b.category.toLowerCase().contains(query) ||
          b.address.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select a business to ${widget.actionLabel}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppPalette.charcoal,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search ${widget.businesses.length} businesses...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppPalette.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 8),
            Text(
              '${filtered.length} of ${widget.businesses.length} shown',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppPalette.mutedText,
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: filtered.isEmpty
                  ? const Center(
                      child: Text(
                        'No matching businesses',
                        style: TextStyle(color: AppPalette.mutedText),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: filtered.length,
                      itemBuilder: (_, index) {
                        final b = filtered[index];
                        final displayName = b.businessName.isNotEmpty
                            ? b.businessName
                            : (b.id?.isNotEmpty == true
                                ? b.id!
                                : 'Untitled');
                        final displayCategory =
                            b.category.isNotEmpty ? b.category : 'Business';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Material(
                            color: AppPalette.background,
                            borderRadius: BorderRadius.circular(12),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: () => widget.onSelected(b.id),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    b.logoUrl != null
                                        ? ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            child: CachedNetworkImage(
                                              imageUrl: b.logoUrl!,
                                              width: 48,
                                              height: 48,
                                              fit: BoxFit.cover,
                                            ),
                                          )
                                        : Container(
                                            width: 48,
                                            height: 48,
                                            decoration: BoxDecoration(
                                              color: AppPalette.surfaceAlt,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: const Icon(
                                              Icons.business_rounded,
                                              color: AppPalette.mutedText,
                                            ),
                                          ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            displayName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 15,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            displayCategory,
                                            style:
                                                const TextStyle(fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

void _showSignInSnack(BuildContext context, String action) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Please $action.'),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
