import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:brisconnect/services/share/content_share_service.dart';
import 'package:brisconnect/theme/app_palette.dart';

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
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            _buildSearchBar(),
            Expanded(child: _buildFeed()),
          ],
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
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Vendor Feed',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Latest from the community',
                style: TextStyle(
                  color: Color(0xFF8B8FA8),
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
          fillColor: const Color(0xFF1C1C2E),
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

    void emit() {
      if (eventDocs == null || postDocs == null) return;
      final items = <_FeedItem>[
        for (final doc in eventDocs!)
          _FeedItem(
            id: doc.id,
            type: _FeedItemType.event,
            data: doc.data() as Map<String, dynamic>,
            createdAt: (doc.data() as Map<String, dynamic>)['createdAt']
                    is Timestamp
                ? ((doc.data() as Map<String, dynamic>)['createdAt'] as Timestamp)
                    .toDate()
                : DateTime.now(),
          ),
        for (final doc in postDocs!)
          _FeedItem(
            id: doc.id,
            type: _FeedItemType.aiPost,
            data: doc.data() as Map<String, dynamic>,
            createdAt: (doc.data() as Map<String, dynamic>)['createdAt']
                    is Timestamp
                ? ((doc.data() as Map<String, dynamic>)['createdAt'] as Timestamp)
                    .toDate()
                : DateTime.now(),
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
        .limit(50)
        .snapshots()
        .listen((snap) {
      // Sort client-side until the Firestore composite index is deployed.
      postDocs = snap.docs.toList()
        ..sort((a, b) {
          final aData = a.data();
          final bData = b.data();
          final aTime = aData['createdAt'] is Timestamp
              ? (aData['createdAt'] as Timestamp).toDate()
              : DateTime.now();
          final bTime = bData['createdAt'] is Timestamp
              ? (bData['createdAt'] as Timestamp).toDate()
              : DateTime.now();
          return bTime.compareTo(aTime);
        });
      emit();
    }, onError: controller.addError);

    controller.onCancel = () async {
      await eventsSub.cancel();
      await postsSub.cancel();
    };

    return controller.stream;
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
                  style: const TextStyle(color: Color(0xFF8B8FA8)),
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
                    color: Colors.white.withValues(alpha: 0.2), size: 56),
                const SizedBox(height: 12),
                Text(
                  _searchQuery.isEmpty
                      ? 'No activity in the feed yet.\nBe the first to share something!'
                      : 'No results for "$_searchQuery"',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Color(0xFF8B8FA8), fontSize: 14, height: 1.5),
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

enum _FeedItemType { event, aiPost }

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
          // Image
          if (imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: Image.network(
                imageUrl,
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _placeholderImage(),
              ),
            )
          else
            _placeholderImage(rounded: true),

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
                    color: Colors.white,
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
                        color: Color(0xFF8B8FA8), size: 13),
                    const SizedBox(width: 4),
                    Text(
                      time.isNotEmpty ? '$date • $time' : date,
                      style: const TextStyle(
                          color: Color(0xFF8B8FA8), fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // Location
                Row(
                  children: [
                    const Icon(Icons.location_on_rounded,
                        color: Color(0xFF8B8FA8), size: 13),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        location,
                        style: const TextStyle(
                            color: Color(0xFF8B8FA8), fontSize: 12),
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

  Widget _buildAiPostCard(BuildContext context) {
    final data = item.data;
    final title = ((data['title'] as String?) ?? 'Untitled Post').trim();
    final business = ((data['businessName'] as String?) ?? '').trim();
    final generatedContent =
        ((data['generatedContent'] as String?) ?? '').trim();
    final postType = ((data['postType'] as String?) ?? 'Post').trim();
    final imageUrl = ((data['imageUrl'] as String?) ?? '').trim();
    final createdAt = item.createdAt;

    return Container(
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
          if (imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: Image.network(
                imageUrl,
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _placeholderImage(),
              ),
            )
          else
            _placeholderImage(rounded: true),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Business name + post type chip + share
                Row(
                  children: [
                    const Icon(Icons.auto_awesome_rounded,
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
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppPalette.ochre.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        postType,
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
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),

                // Generated content
                Text(
                  generatedContent,
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 13, height: 1.55),
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),

                // Date
                Row(
                  children: [
                    const Icon(Icons.access_time_rounded,
                        color: Color(0xFF8B8FA8), size: 13),
                    const SizedBox(width: 4),
                    Text(
                      _formatDate(createdAt),
                      style: const TextStyle(
                          color: Color(0xFF8B8FA8), fontSize: 12),
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

  Widget _placeholderImage({bool rounded = false}) {
    return Container(
      height: 100,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A3E),
        borderRadius: rounded
            ? const BorderRadius.vertical(top: Radius.circular(16))
            : null,
      ),
      child: const Icon(Icons.image_outlined,
          color: Color(0xFF8B8FA8), size: 36),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

class _ShareButton extends StatelessWidget {
  const _ShareButton({required this.item});

  final _FeedItem item;

  Future<void> _share(BuildContext context) async {
    final service = ContentShareService();
    final data = item.data;

    if (item.type == _FeedItemType.event) {
      final title = ((data['title'] as String?) ?? 'Event').trim();
      final description = ((data['description'] as String?) ?? '').trim();
      final location = ((data['location'] as String?) ?? '').trim();
      final date = ((data['date'] as String?) ?? '').trim();
      final time = ((data['time'] as String?) ?? '').trim();
      final dateTime = time.isNotEmpty ? '$date • $time' : date;

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
