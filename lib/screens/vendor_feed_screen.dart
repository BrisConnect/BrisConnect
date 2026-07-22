import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
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

  Widget _buildFeed() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('events')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
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

        final docs = snapshot.data?.docs ?? [];
        final filtered = _searchQuery.isEmpty
            ? docs
            : docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final title =
                    ((data['title'] as String?) ?? '').toLowerCase();
                final business =
                    ((data['createdByBusiness'] as String?) ?? '').toLowerCase();
                return title.contains(_searchQuery) ||
                    business.contains(_searchQuery);
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
                      ? 'No events in the feed yet.\nBe the first to create one!'
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
            final data =
                filtered[index].data() as Map<String, dynamic>;
            return _VendorFeedCard(data: data);
          },
        );
      },
    );
  }
}

class _VendorFeedCard extends StatelessWidget {
  const _VendorFeedCard({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final title = ((data['title'] as String?) ?? 'Untitled Event').trim();
    final business =
        ((data['createdByBusiness'] as String?) ?? '').trim();
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
                // Business name + category chip
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
}
