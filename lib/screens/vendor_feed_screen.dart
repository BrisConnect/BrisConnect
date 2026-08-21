import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:brisconnect/services/share/content_share_service.dart';
import 'package:brisconnect/services/social_share_tracking_service.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/utils/responsive_utils.dart';

/// Vendor Feed — shows a live stream of events and business activity
/// from all local vendors in the BrisConnect community.
class VendorFeedScreen extends StatefulWidget {
  const VendorFeedScreen({super.key});

  @override
  State<VendorFeedScreen> createState() => _VendorFeedScreenState();
}

class _VendorFeedScreenState extends State<VendorFeedScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEBF4FF),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                _buildSearchBar(),
                Expanded(child: _buildFeed()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppPalette.ochre, Color(0xFFD4740E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.dynamic_feed_rounded,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Vendor Feed',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Latest from the community',
                style: TextStyle(
                  color: Color(0xFF5A5F73),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.white),
        onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
        decoration: InputDecoration(
          hintText: 'Search events or businesses…',
          hintStyle: const TextStyle(color: Color(0xFF8B8FA8), fontSize: 14),
          prefixIcon: const Icon(Icons.search_rounded,
              color: Color(0xFF8B8FA8), size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded,
                      color: Color(0xFF8B8FA8), size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          filled: true,
          fillColor: AppPalette.surface,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Stream<List<_FeedItem>> _feedStream() {
    final controller = StreamController<List<_FeedItem>>.broadcast();
    List<DocumentSnapshot>? eventDocs;
    List<DocumentSnapshot>? postDocs;
    List<DocumentSnapshot>? businessEventDocs;
    List<DocumentSnapshot>? promotionDocs;

    void emit() {
      if (eventDocs == null ||
          postDocs == null ||
          businessEventDocs == null ||
          promotionDocs == null) {
        return;
      }
      final items = <_FeedItem>[
        for (final doc in eventDocs!)
          _FeedItem(
            id: doc.id,
            type: _FeedItemType.event,
            data: doc.data() as Map<String, dynamic>,
            createdAt: _createdAtFromDoc(doc),
          ),
        for (final doc in postDocs!)
          _FeedItem(
            id: doc.id,
            type: _FeedItemType.aiPost,
            data: doc.data() as Map<String, dynamic>,
            createdAt: _createdAtFromDoc(doc),
          ),
        for (final doc in businessEventDocs!)
          _FeedItem(
            id: doc.id,
            type: _FeedItemType.businessEvent,
            data: doc.data() as Map<String, dynamic>,
            createdAt: _createdAtFromDoc(doc),
          ),
        for (final doc in promotionDocs!)
          _FeedItem(
            id: doc.id,
            type: _FeedItemType.promotion,
            data: doc.data() as Map<String, dynamic>,
            createdAt: _createdAtFromDoc(doc),
          ),
      ];
      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      controller.add(items.take(50).toList());
    }

    final eventsSub = FirebaseFirestore.instance
        .collection('events')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .listen((snap) {
      eventDocs = snap.docs;
      emit();
    }, onError: controller.addError);

    final postsSub = FirebaseFirestore.instance
        .collection('ai_generated_posts')
        .where('status', isEqualTo: 'published')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .listen((snap) {
      postDocs = snap.docs;
      emit();
    }, onError: controller.addError);

    final businessEventsSub = FirebaseFirestore.instance
        .collection('business_events')
        .where('status', isEqualTo: 'published')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .listen((snap) {
      businessEventDocs = snap.docs;
      emit();
    }, onError: controller.addError);

    final promotionsSub = FirebaseFirestore.instance
        .collection('promotions')
        .where('status', whereIn: ['active', 'scheduled'])
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .listen((snap) {
      promotionDocs = snap.docs;
      emit();
    }, onError: controller.addError);

    controller.onCancel = () async {
      await eventsSub.cancel();
      await postsSub.cancel();
      await businessEventsSub.cancel();
      await promotionsSub.cancel();
    };

    return controller.stream;
  }

  DateTime _createdAtFromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) return DateTime.now();
    final createdAt = data['createdAt'];
    if (createdAt is Timestamp) return createdAt.toDate();
    return DateTime.now();
  }

  Widget _buildFeed() {
    return StreamBuilder<List<_FeedItem>>(
      stream: _feedStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: AppPalette.ochre),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: Colors.redAccent, size: 40),
                const SizedBox(height: 8),
                Text(
                  'Could not load feed.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppPalette.mutedText),
                ),
              ],
            ),
          );
        }

        final docs = snapshot.data ?? [];
        final filtered = _searchQuery.isEmpty
            ? docs
            : docs.where((item) {
                final title =
                    ((item.data['title'] as String?) ?? '').toLowerCase();
                final business = ((item.type == _FeedItemType.event
                            ? item.data['createdByBusiness']
                            : item.data['businessName'])
                        as String? ??
                    '');
                return title.contains(_searchQuery) ||
                    business.toLowerCase().contains(_searchQuery);
              }).toList();

        if (filtered.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.dynamic_feed_outlined,
                    color: Colors.black.withValues(alpha: 0.2), size: 56),
                const SizedBox(height: 12),
                Text(
                  _searchQuery.isEmpty
                      ? 'No activity in the feed yet.\nBe the first to share something!'
                      : 'No results for "$_searchQuery"',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppPalette.mutedText, fontSize: 14, height: 1.5),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          itemCount: filtered.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final item = filtered[index];
            return _VendorFeedCard(item: item);
          },
        );
      },
    );
  }
}

enum _FeedItemType { event, aiPost, businessEvent, promotion }

class _FeedItem {
  const _FeedItem({
    required this.id,
    required this.type,
    required this.data,
    required this.createdAt,
  });

  final String id;
  final _FeedItemType type;
  final Map<String, dynamic> data;
  final DateTime createdAt;
}

class _VendorFeedCard extends StatelessWidget {
  const _VendorFeedCard({required this.item});

  final _FeedItem item;

  @override
  Widget build(BuildContext context) {
    return switch (item.type) {
      _FeedItemType.event => _buildEventCard(context),
      _FeedItemType.aiPost => _buildAiPostCard(context),
      _FeedItemType.businessEvent => _buildBusinessEventCard(context),
      _FeedItemType.promotion => _buildPromotionCard(context),
    };
  }

  Widget _buildEventCard(BuildContext context) {
    final data = item.data;
    final title = ((data['title'] as String?) ?? 'Untitled Event').trim();
    final business = ((data['createdByBusiness'] as String?) ?? '').trim();
    final location = ((data['location'] as String?) ?? 'Location TBA').trim();
    final date = ((data['date'] as String?) ?? 'Date TBA').trim();
    final time = ((data['time'] as String?) ?? '').trim();
    final imageUrl = ((data['imageUrl'] as String?) ?? '').trim();
    final price = ((data['price'] as String?) ?? '').trim();
    final category = ((data['category'] as String?) ?? '').trim();

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Image (omitted entirely when there's none, instead of reserving blank space)
          if (imageUrl.isNotEmpty) _buildAutoFitImage(imageUrl),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Business name + category chip + share
                Row(
                  children: [
                    if (business.isNotEmpty) ...[
                      const Icon(Icons.storefront_rounded,
                          color: AppPalette.ochre, size: 14),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          business,
                          style: const TextStyle(
                            color: AppPalette.ochre,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ] else
                      const Spacer(),
                    if (category.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppPalette.ochre.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          category,
                          style: const TextStyle(
                            color: AppPalette.ochre,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    _ShareButton(item: item),
                  ],
                ),
                const SizedBox(height: 6),

                // Title
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),

                // Date / time
                Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded,
                        color: AppPalette.mutedText, size: 13),
                    const SizedBox(width: 4),
                    Text(
                      time.isNotEmpty ? '$date • $time' : date,
                      style: const TextStyle(
                          color: AppPalette.mutedText, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // Location
                Row(
                  children: [
                    const Icon(Icons.location_on_rounded,
                        color: AppPalette.mutedText, size: 13),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        location,
                        style: const TextStyle(
                            color: AppPalette.mutedText, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (price.isNotEmpty && price.toLowerCase() != 'free')
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A2A3E),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          price,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
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

  Widget _buildBusinessEventCard(BuildContext context) {
    final data = item.data;
    final title = ((data['title'] as String?) ?? 'Untitled Event').trim();
    final business = ((data['businessName'] as String?) ?? '').trim();
    final location = ((data['location'] as String?) ?? 'Location TBA').trim();
    final date = ((data['date'] as String?) ?? 'Date TBA').trim();
    final time = ((data['time'] as String?) ?? '').trim();
    final imageUrl = ((data['imageUrl'] as String?) ?? '').trim();
    final description = ((data['description'] as String?) ?? '').trim();

    return _FeedCard(
      imageUrl: imageUrl,
      chipLabel: 'Business Event',
      business: business.isNotEmpty ? business : 'Community Post',
      date: item.createdAt,
      title: title,
      body: description,
      footer: Row(
        children: [
          const Icon(Icons.calendar_today_rounded,
              color: AppPalette.mutedText, size: 13),
          const SizedBox(width: 4),
          Text(
            time.isNotEmpty ? '$date • $time' : date,
            style: const TextStyle(color: AppPalette.mutedText, fontSize: 12),
          ),
          const SizedBox(width: 12),
          const Icon(Icons.location_on_rounded,
              color: AppPalette.mutedText, size: 13),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              location,
              style: const TextStyle(color: AppPalette.mutedText, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      shareItem: item,
    );
  }

  Widget _buildPromotionCard(BuildContext context) {
    final data = item.data;
    final title = ((data['title'] as String?) ?? 'Untitled Promotion').trim();
    final business = ((data['businessName'] as String?) ?? '').trim();
    final description = ((data['description'] as String?) ?? '').trim();
    final discount = ((data['discount'] as String?) ?? '').trim();
    final imageUrl = ((data['imageUrl'] as String?) ?? '').trim();
    final endAt = data['endAt'];
    final ends = endAt is Timestamp
        ? 'Ends ${_formatDate(endAt.toDate())}'
        : 'Limited time';

    return _FeedCard(
      imageUrl: imageUrl,
      chipLabel: 'Promotion',
      business: business.isNotEmpty ? business : 'Community Post',
      date: item.createdAt,
      title: title,
      body: description,
      footer: Row(
        children: [
          const Icon(Icons.local_offer_rounded,
              color: AppPalette.mutedText, size: 13),
          const SizedBox(width: 4),
          Text(
            discount.isNotEmpty ? '$discount • $ends' : ends,
            style: const TextStyle(color: AppPalette.mutedText, fontSize: 12),
          ),
        ],
      ),
      shareItem: item,
    );
  }

  Widget _buildAiPostCard(BuildContext context) {
    final data = item.data;
    final title = ((data['title'] as String?) ?? 'Untitled Post').trim();
    final business = ((data['businessName'] as String?) ?? '').trim();
    final generatedContent =
        ((data['generatedContent'] as String?) ?? '').trim();
    final postType = ((data['postType'] as String?) ?? 'Post').trim();
    final imageUrl = ((data['imageUrl'] as String?) ?? '').trim();

    return _FeedCard(
      imageUrl: imageUrl,
      chipLabel: postType,
      business: business.isNotEmpty ? business : 'Community Post',
      date: item.createdAt,
      title: title,
      body: generatedContent,
      footer: const SizedBox.shrink(),
      shareItem: item,
    );
  }

  String _formatDate(DateTime date) => _formatFeedDate(date);
}

String _formatFeedDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

Widget _placeholderImage({bool rounded = false}) {
  return Container(
    height: 160,
    width: double.infinity,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: rounded
          ? const BorderRadius.vertical(top: Radius.circular(16))
          : null,
    ),
    alignment: Alignment.center,
    child: const Icon(Icons.image_outlined,
        color: AppPalette.mutedText, size: 36),
  );
}

Widget _buildAutoFitImage(String imageUrl) {
  return Container(
    width: double.infinity,
    height: 220,
    color: Colors.white,
    alignment: Alignment.center,
    child: Image.network(
      imageUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      height: 220,
      loadingBuilder: (_, child, progress) => progress == null
          ? child
          : const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
      errorBuilder: (_, __, ___) => _placeholderImage(),
    ),
  );
}

/// Image column used on wide (desktop) layouts, filling the available
/// height of its row instead of a fixed top banner.
Widget _buildSideImage(String imageUrl) {
  return Container(
    color: Colors.white,
    alignment: Alignment.center,
    child: Image.network(
      imageUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      loadingBuilder: (_, child, progress) => progress == null
          ? child
          : const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
      errorBuilder: (_, __, ___) => _placeholderImage(),
    ),
  );
}

/// Maps a feed card's chip label to a distinct badge colour so post types
/// (Promotion, Menu Item, Business Event, etc.) are easy to tell apart.
Color _chipColorFor(String label) {
  switch (label.toLowerCase()) {
    case 'promotion':
      return AppPalette.ochre;
    case 'menu item':
      return const Color(0xFF2ECC71);
    case 'business event':
      return AppPalette.deepBlue;
    case 'announcement':
      return const Color(0xFF9B59B6);
    case 'review highlight':
      return const Color(0xFF3BD0EE);
    default:
      return AppPalette.ochre;
  }
}

Widget _chipBadge(String label) {
  final color = _chipColorFor(label);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: color,
        fontSize: 10,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _FeedCard extends StatelessWidget {
  const _FeedCard({
    required this.imageUrl,
    required this.chipLabel,
    required this.business,
    required this.date,
    required this.title,
    required this.body,
    required this.footer,
    required this.shareItem,
  });

  final String imageUrl;
  final String chipLabel;
  final String business;
  final DateTime date;
  final String title;
  final String body;
  final Widget footer;
  final _FeedItem shareItem;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.storefront_rounded,
                  color: AppPalette.ochre, size: 14),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  business.isNotEmpty ? business : 'Community Post',
                  style: const TextStyle(
                    color: AppPalette.ochre,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _chipBadge(chipLabel),
              _ShareButton(item: shareItem),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.access_time_rounded,
                  color: AppPalette.mutedText, size: 12),
              const SizedBox(width: 4),
              Text(
                _formatFeedDate(date),
                style: const TextStyle(
                    color: AppPalette.mutedText, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          if (body.isNotEmpty)
            Text(
              body,
              style: const TextStyle(
                  color: Colors.black87, fontSize: 13, height: 1.55),
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
            ),
          if (body.isNotEmpty) const SizedBox(height: 8),
          footer,
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= Breakpoints.tablet;

        if (isDesktop && imageUrl.isNotEmpty) {
          return Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppPalette.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.06),
                width: 1,
              ),
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(width: 220, child: _buildSideImage(imageUrl)),
                  Expanded(child: content),
                ],
              ),
            ),
          );
        }

        return Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppPalette.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.06),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (imageUrl.isNotEmpty) _buildAutoFitImage(imageUrl),
              content,
            ],
          ),
        );
      },
    );
  }
}

class _ShareButton extends StatelessWidget {
  const _ShareButton({required this.item});

  final _FeedItem item;

  Future<void> _share(BuildContext context) async {
    final service = ContentShareService();
    final tracker = SocialShareTrackingService();
    final data = item.data;

    if (item.type == _FeedItemType.event) {
      final title = ((data['title'] as String?) ?? 'Event').trim();
      final description = ((data['description'] as String?) ?? '').trim();
      final location = ((data['location'] as String?) ?? '').trim();
      final date = ((data['date'] as String?) ?? '').trim();
      final time = ((data['time'] as String?) ?? '').trim();
      final dateTime = time.isNotEmpty ? '$date • $time' : date;
      final businessId = ((data['businessId'] as String?) ?? item.id).trim();
      final businessName = ((data['businessName'] as String?) ?? '').trim();

      final result = await service.shareToPlatform(
        platform: 'facebook',
        type: ShareContentType.event,
        id: item.id,
        title: title,
        description:
            description.isNotEmpty ? description : 'Check out $title',
        location: location,
        dateTime: dateTime,
      );

      await tracker.recordShare(
        businessId: businessId,
        businessName: businessName.isNotEmpty ? businessName : null,
        contentId: item.id,
        contentType: ShareContentType.event,
        platform: 'facebook',
        shareKind: 'link',
        title: title,
        description: description,
        shareUrl: service.buildShareUrl(type: ShareContentType.event, id: item.id, slug: title),
      );

      if (context.mounted) _showResult(context, result, service.platformLabel('facebook'));
    } else {
      final title = ((data['title'] as String?) ?? 'Post').trim();
      final business = ((data['businessName'] as String?) ?? '').trim();
      final generatedContent =
          ((data['generatedContent'] as String?) ?? '').trim();
      final businessId = ((data['businessId'] as String?) ?? item.id).trim();

      final result = await service.shareToPlatform(
        platform: 'facebook',
        type: ShareContentType.business,
        id: businessId,
        title: business.isNotEmpty ? business : title,
        description: generatedContent,
      );

      await tracker.recordShare(
        businessId: businessId,
        businessName: business.isNotEmpty ? business : null,
        contentId: item.id,
        contentType: ShareContentType.business,
        platform: 'facebook',
        shareKind: 'link',
        title: business.isNotEmpty ? business : title,
        description: generatedContent,
        shareUrl: service.buildShareUrl(type: ShareContentType.business, id: businessId, slug: business.isNotEmpty ? business : title),
      );

      if (context.mounted) _showResult(context, result, service.platformLabel('facebook'));
    }
  }

  void _showResult(BuildContext context, ShareResult result, String platform) {
    final messenger = ScaffoldMessenger.of(context);
    final snackBar = switch (result) {
      ShareResult.shared => SnackBar(
          content: Text('Opening $platform share…'),
          backgroundColor: AppPalette.ochre,
          duration: const Duration(seconds: 2),
        ),
      ShareResult.copied => const SnackBar(
          content: Text('✓ Link copied to clipboard'),
          backgroundColor: AppPalette.ochre,
          duration: Duration(seconds: 2),
        ),
      ShareResult.timedOut || ShareResult.failed => const SnackBar(
          content: Text('Could not share. Link copied to clipboard instead.'),
          backgroundColor: Colors.redAccent,
          duration: Duration(seconds: 3),
        ),
    };
    messenger.showSnackBar(snackBar);
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.share_rounded, color: AppPalette.ochre, size: 18),
      onPressed: () => _share(context),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      tooltip: 'Share to Facebook',
    );
  }
}
