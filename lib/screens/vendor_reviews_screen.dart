import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:brisconnect/auth/local_auth.dart';
import 'package:brisconnect/services/business_profile_service.dart';
import 'package:brisconnect/theme/app_palette.dart';

/// Screen 2 of the Local portal — Vendor Reviews & Engagement.
/// Shows BrisConnect reviews, social media mentions and customer engagement.
class VendorReviewsScreen extends StatefulWidget {
  const VendorReviewsScreen({super.key});

  @override
  State<VendorReviewsScreen> createState() => _VendorReviewsScreenState();
}

class _VendorReviewsScreenState extends State<VendorReviewsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  String? _businessId;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _loadBusinessId();
  }

  Future<void> _loadBusinessId() async {
    final email = LocalAuth.currentLocal?.email;
    if (email == null) return;
    try {
      final list =
          await BusinessProfileService().getUserBusinessProfiles(email);
      if (list.isNotEmpty && mounted) {
        setState(() => _businessId = list.first.id);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tab,
                children: [
                  _buildBrisConnectReviews(),
                  _buildSocialMentions(),
                  _buildEngagement(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFF4F8FFF).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.reviews_rounded,
                color: Color(0xFF4F8FFF), size: 20),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Vendors & Reviews',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              Text('Customer feedback & social activity',
                  style:
                      TextStyle(color: Color(0xFF8B8FA8), fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C2E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tab,
        indicator: BoxDecoration(
          color: AppPalette.ochre,
          borderRadius: BorderRadius.circular(10),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.white,
        unselectedLabelColor: const Color(0xFF8B8FA8),
        labelStyle:
            const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        padding: const EdgeInsets.all(4),
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(text: 'Reviews'),
          Tab(text: 'Social'),
          Tab(text: 'Engage'),
        ],
      ),
    );
  }

  // ── BrisConnect Reviews ─────────────────────────────────────────────
  Widget _buildBrisConnectReviews() {
    if (_businessId == null) {
      return _emptyState(
        icon: Icons.reviews_outlined,
        title: 'No business profile yet',
        subtitle: 'Complete your Business Profile to start receiving reviews.',
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('reviews')
          .where('businessId', isEqualTo: _businessId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: AppPalette.ochre));
        }

        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return _emptyState(
            icon: Icons.star_border_rounded,
            title: 'No reviews yet',
            subtitle:
                'When customers leave reviews on your business, they\'ll appear here.',
          );
        }

        // Summary stats
        final ratings = docs
            .map((d) =>
                ((d.data() as Map<String, dynamic>)['rating'] as num?)
                    ?.toDouble() ??
                0.0)
            .toList();
        final avg =
            ratings.isEmpty ? 0.0 : ratings.reduce((a, b) => a + b) / ratings.length;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _ReviewSummaryCard(avg: avg, count: docs.length),
            const SizedBox(height: 14),
            ...docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return _ReviewCard(data: data);
            }),
          ],
        );
      },
    );
  }

  // ── Social Mentions ─────────────────────────────────────────────────
  Widget _buildSocialMentions() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SocialPlatformCard(
          platform: 'Instagram',
          icon: Icons.camera_alt_rounded,
          color: const Color(0xFFE1306C),
          description: 'Connect your Instagram account to see mentions and tags.',
        ),
        const SizedBox(height: 12),
        _SocialPlatformCard(
          platform: 'Facebook',
          icon: Icons.facebook_rounded,
          color: const Color(0xFF1877F2),
          description:
              'Link your Facebook page to monitor comments and recommendations.',
        ),
        const SizedBox(height: 12),
        _SocialPlatformCard(
          platform: 'TikTok',
          icon: Icons.music_note_rounded,
          color: Colors.white,
          description:
              'Connect TikTok to track videos that feature your business.',
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppPalette.ochre.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: AppPalette.ochre.withValues(alpha: 0.3)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  color: AppPalette.ochre, size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Social media integration coming soon. Add your links from your Business Profile to get started.',
                  style: TextStyle(
                      color: Colors.white70, fontSize: 12, height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Customer Engagement ─────────────────────────────────────────────
  Widget _buildEngagement() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _engagementMetric(
          icon: Icons.people_rounded,
          color: const Color(0xFF4F8FFF),
          label: 'Profile Visitors',
          value: '—',
          note: 'Tracking coming soon',
        ),
        const SizedBox(height: 10),
        _engagementMetric(
          icon: Icons.bookmark_rounded,
          color: const Color(0xFF9B59B6),
          label: 'Saved by Visitors',
          value: '—',
          note: 'When visitors save your events',
        ),
        const SizedBox(height: 10),
        _engagementMetric(
          icon: Icons.thumb_up_rounded,
          color: const Color(0xFF2ECC71),
          label: 'Positive Sentiment',
          value: '—',
          note: 'Based on review content analysis',
        ),
        const SizedBox(height: 10),
        _engagementMetric(
          icon: Icons.reply_rounded,
          color: AppPalette.ochre,
          label: 'Responses Sent',
          value: '0',
          note: 'Your replies to customer reviews',
        ),
      ],
    );
  }

  Widget _engagementMetric({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
    required String note,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
                Text(note,
                    style: const TextStyle(
                        color: Color(0xFF8B8FA8), fontSize: 11)),
              ],
            ),
          ),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 22,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _emptyState(
      {required IconData icon,
      required String title,
      required String subtitle}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white.withValues(alpha: 0.2), size: 56),
            const SizedBox(height: 16),
            Text(title,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(subtitle,
                style: const TextStyle(
                    color: Color(0xFF8B8FA8), fontSize: 13, height: 1.5),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ── Review Summary Card ───────────────────────────────────────────────
class _ReviewSummaryCard extends StatelessWidget {
  const _ReviewSummaryCard({required this.avg, required this.count});
  final double avg;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1C1C2E),
            AppPalette.ochre.withValues(alpha: 0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: AppPalette.ochre.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Column(
            children: [
              Text(avg.toStringAsFixed(1),
                  style: const TextStyle(
                      color: AppPalette.ochre,
                      fontSize: 36,
                      fontWeight: FontWeight.bold)),
              Row(
                children: List.generate(5, (i) {
                  return Icon(
                    i < avg.round()
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: AppPalette.ochre,
                    size: 14,
                  );
                }),
              ),
            ],
          ),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$count ${count == 1 ? 'Review' : 'Reviews'}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
              const Text('on BrisConnect',
                  style: TextStyle(
                      color: Color(0xFF8B8FA8), fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Review Card ───────────────────────────────────────────────────────
class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final rating = (data['rating'] as num?)?.toDouble() ?? 0;
    final comment = (data['comment'] as String?) ?? '';
    final visitorName = (data['visitorName'] as String?) ?? 'Anonymous';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C2E),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppPalette.ochre.withValues(alpha: 0.2),
                child: Text(
                  visitorName.isNotEmpty ? visitorName[0].toUpperCase() : '?',
                  style: const TextStyle(
                      color: AppPalette.ochre,
                      fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(visitorName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
              ),
              Row(
                children: List.generate(5, (i) {
                  return Icon(
                    i < rating.round()
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: AppPalette.ochre,
                    size: 14,
                  );
                }),
              ),
            ],
          ),
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(comment,
                style: const TextStyle(
                    color: Color(0xFFB0B3C1),
                    fontSize: 13,
                    height: 1.4)),
          ],
        ],
      ),
    );
  }
}

// ── Social Platform Card ──────────────────────────────────────────────
class _SocialPlatformCard extends StatelessWidget {
  const _SocialPlatformCard({
    required this.platform,
    required this.icon,
    required this.color,
    required this.description,
  });
  final String platform;
  final IconData icon;
  final Color color;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(platform,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
                Text(description,
                    style: const TextStyle(
                        color: Color(0xFF8B8FA8),
                        fontSize: 11,
                        height: 1.3)),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Text('Connect',
                style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
