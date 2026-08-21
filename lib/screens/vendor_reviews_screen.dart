import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:brisconnect/auth/local_auth.dart';
import 'package:brisconnect/models/social_share_event.dart';
import 'package:brisconnect/services/business_profile_service.dart';
import 'package:brisconnect/services/review_service.dart';
import 'package:brisconnect/services/social_share_tracking_service.dart';
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
  String? _businessName;
  int _reviewsRetryToken = 0;
  int _socialRetryToken = 0;
  late final SocialShareTrackingService _shareTrackingService =
      SocialShareTrackingService();

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _tab.addListener(() {
      if (mounted) setState(() {});
    });
    _loadBusinessId();
  }

  Stream<int> _reviewsCountStream() {
    if (_businessId == null) return Stream.value(0);
    return FirebaseFirestore.instance
        .collection('reviews')
        .where('businessId', isEqualTo: _businessId)
        .where('visible', isEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  Future<void> _loadBusinessId() async {
    String? email = LocalAuth.currentLocal?.email;

    // Dev fallback for unsigned macOS builds where Firebase Auth keychain
    // access fails and currentLocal may not be populated even though the
    // user logged in. Fall back to the first business in Firestore so the
    // vendor reviews screen still renders during development.
    if (email == null || email.isEmpty) {
      try {
        final firstBusiness =
            await BusinessProfileService().getFirstBusiness();
        if (firstBusiness != null && mounted) {
          setState(() {
            _businessId = firstBusiness.id;
            _businessName = firstBusiness.businessName;
          });
          debugPrint('[VendorReviewsScreen] dev fallback businessId: $_businessId');
        }
      } catch (e) {
        debugPrint('[VendorReviewsScreen] fallback lookup failed: $e');
      }
      return;
    }

    try {
      final list =
          await BusinessProfileService().getUserBusinessProfiles(email);
      if (list.isNotEmpty && mounted) {
        setState(() {
          _businessId = list.first.id;
          _businessName = list.first.businessName;
        });
      }
    } catch (e) {
      debugPrint('[VendorReviewsScreen] business lookup failed: $e');
    }
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEBF4FF),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
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
                    ],
                  ),
                ),
              ],
            ),
          ),
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('Vendors & Reviews',
                  style: TextStyle(
                      color: Colors.black,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              Text('Customer feedback & social activity',
                  style:
                      TextStyle(color: Color(0xFF5A5F73), fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Row(
        children: [
          StreamBuilder<int>(
            stream: _reviewsCountStream(),
            builder: (context, snap) {
              return _buildTabChip(
                index: 0,
                label: 'Reviews',
                count: snap.data,
              );
            },
          ),
          const SizedBox(width: 8),
          _buildTabChip(index: 1, label: 'Social'),
        ],
      ),
    );
  }

  Widget _buildTabChip({
    required int index,
    required String label,
    int? count,
  }) {
    final isSelected = _tab.index == index;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => _tab.animateTo(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppPalette.ochre.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border(
            bottom: BorderSide(
              color: isSelected ? AppPalette.ochre : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppPalette.ochre : AppPalette.mutedText,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppPalette.ochre
                      : AppPalette.mutedText.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppPalette.mutedText,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
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
      key: ValueKey('reviews-$_reviewsRetryToken'),
      stream: FirebaseFirestore.instance
          .collection('reviews')
          .where('businessId', isEqualTo: _businessId)
          .where('visible', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .timeout(const Duration(seconds: 12),
              onTimeout: (sink) => sink.addError(TimeoutException(
                  'Taking longer than expected. Check your connection and try again.'))),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: AppPalette.ochre));
        }

        if (snap.hasError) {
          return _emptyState(
            icon: Icons.error_outline_rounded,
            title: 'Could not load reviews',
            subtitle: snap.error is TimeoutException
                ? (snap.error as TimeoutException).message!
                : snap.error.toString(),
            onRetry: () => setState(() => _reviewsRetryToken++),
          );
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
              return _ReviewCard(
                docId: doc.id,
                data: data,
                businessName: _businessName,
              );
            }),
          ],
        );
      },
    );
  }

  // ── Social Mentions ─────────────────────────────────────────────────
  Widget _buildSocialMentions() {
    if (_businessId == null) {
      return _emptyState(
        icon: Icons.share_outlined,
        title: 'No business profile yet',
        subtitle:
            'Complete your Business Profile to see when visitors share your content.',
      );
    }

    return StreamBuilder<List<SocialShareEvent>>(
      key: ValueKey('social-$_socialRetryToken'),
      stream: _shareTrackingService
          .streamForBusiness(_businessId!)
          .timeout(const Duration(seconds: 12),
              onTimeout: (sink) => sink.addError(TimeoutException(
                  'Taking longer than expected. Check your connection and try again.'))),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppPalette.ochre),
          );
        }

        if (snap.hasError) {
          return _emptyState(
            icon: Icons.error_outline_rounded,
            title: 'Could not load social shares',
            subtitle: snap.error is TimeoutException
                ? (snap.error as TimeoutException).message!
                : snap.error.toString(),
            onRetry: () => setState(() => _socialRetryToken++),
          );
        }

        final events = snap.data ?? [];
        if (events.isEmpty) {
          return _emptyState(
            icon: Icons.share_outlined,
            title: 'No social shares yet',
            subtitle:
                'When visitors share your business, event or promotion to social media, it will appear here live.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: events.length,
          itemBuilder: (context, index) => _SocialShareCard(event: events[index]),
        );
      },
    );
  }

  Widget _emptyState(
      {required IconData icon,
      required String title,
      required String subtitle,
      VoidCallback? onRetry}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.black.withValues(alpha: 0.2), size: 56),
            const SizedBox(height: 16),
            Text(title,
                style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(subtitle,
                style: const TextStyle(
                    color: AppPalette.mutedText, fontSize: 13, height: 1.5),
                textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Retry'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppPalette.ochre,
                  side: const BorderSide(color: AppPalette.ochre),
                ),
              ),
            ],
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppPalette.surface,
            AppPalette.ochre.withValues(alpha: 0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: AppPalette.ochre.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Text(avg.toStringAsFixed(1),
              style: const TextStyle(
                  color: AppPalette.ochre,
                  fontSize: 22,
                  fontWeight: FontWeight.bold)),
          const SizedBox(width: 6),
          Row(
            children: List.generate(5, (i) {
              return Icon(
                i < avg.round()
                    ? Icons.star_rounded
                    : Icons.star_outline_rounded,
                color: AppPalette.ochre,
                size: 12,
              );
            }),
          ),
          const SizedBox(width: 12),
          Container(
            width: 1,
            height: 18,
            color: AppPalette.ochre.withValues(alpha: 0.2),
          ),
          const SizedBox(width: 12),
          Text('$count ${count == 1 ? 'Review' : 'Reviews'} on BrisConnect',
              style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w600,
                  fontSize: 13)),
        ],
      ),
    );
  }
}

// ── Review Card ───────────────────────────────────────────────────────
class _ReviewCard extends StatefulWidget {
  const _ReviewCard({
    required this.docId,
    required this.data,
    this.businessName,
  });
  final String docId;
  final Map<String, dynamic> data;
  final String? businessName;

  @override
  State<_ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends State<_ReviewCard> {
  bool _isReplying = false;
  final _replyController = TextEditingController();

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rating = (widget.data['rating'] as num?)?.toDouble() ?? 0;
    final comment = (widget.data['comment'] as String?) ?? '';
    final visitorName = (widget.data['visitorName'] as String?) ?? 'Anonymous';
    final reply = (widget.data['reply'] as String?) ?? '';
    final replyAt = (widget.data['replyAt'] as Timestamp?)?.toDate();
    final hasReply = reply.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 10, left: 6, right: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppPalette.surface,
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
                        color: Colors.black,
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
                    color: AppPalette.mutedText,
                    fontSize: 13,
                    height: 1.4)),
          ],
          if (hasReply) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppPalette.deepBlue.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border(
                  left: BorderSide(color: AppPalette.deepBlue, width: 3),
                  top: BorderSide(
                      color: AppPalette.deepBlue.withValues(alpha: 0.15)),
                  right: BorderSide(
                      color: AppPalette.deepBlue.withValues(alpha: 0.15)),
                  bottom: BorderSide(
                      color: AppPalette.deepBlue.withValues(alpha: 0.15)),
                ),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppPalette.deepBlue.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.storefront_rounded,
                                color: AppPalette.deepBlue, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              (widget.businessName?.trim().isNotEmpty ?? false)
                                  ? widget.businessName!.trim()
                                  : 'Business reply',
                              style: const TextStyle(
                                  color: AppPalette.deepBlue,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      if (replyAt != null)
                        Text(
                          '${replyAt.day.toString().padLeft(2, '0')}/${replyAt.month.toString().padLeft(2, '0')}/${replyAt.year}',
                          style: const TextStyle(
                              color: AppPalette.mutedText, fontSize: 11),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(reply,
                      style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 13,
                          height: 1.4)),
                ],
              ),
            ),
          ],
          if (_isReplying) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _replyController,
              maxLines: 3,
              maxLength: 500,
              style: const TextStyle(color: Colors.black, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Write a reply to this review…',
                hintStyle: const TextStyle(color: Color(0xFF8B8FA8)),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.all(12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _isReplying = false;
                        _replyController.clear();
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppPalette.mutedText,
                      side: BorderSide(
                          color: AppPalette.mutedText.withValues(alpha: 0.3)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _submitReply,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppPalette.ochre,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Post Reply'),
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => setState(() => _isReplying = true),
                icon: Icon(hasReply ? Icons.edit : Icons.reply,
                    color: AppPalette.ochre, size: 16),
                label: Text(
                  hasReply ? 'Edit reply' : 'Reply',
                  style: const TextStyle(
                      color: AppPalette.ochre,
                      fontWeight: FontWeight.w600,
                      fontSize: 12),
                ),
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _submitReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty) return;

    try {
      await ReviewService().addReply(
        reviewId: widget.docId,
        reply: text,
        ownerName: widget.businessName,
      );
      if (mounted) {
        setState(() {
          _isReplying = false;
          _replyController.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reply posted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to post reply: $e')),
        );
      }
    }
  }
}

// ── Social Share Card ────────────────────────────────────────────────
class _SocialShareCard extends StatelessWidget {
  const _SocialShareCard({required this.event});

  final SocialShareEvent event;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _platformIcon(event.platform);
    final visitor = event.visitorName?.trim().isNotEmpty == true
        ? event.visitorName!
        : 'A visitor';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$visitor shared to ${event.platform}',
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      '${event.shareKind.toUpperCase()} • ${event.contentType.name}',
                      style: const TextStyle(
                        color: AppPalette.mutedText,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                _formatTimeAgo(event.createdAt),
                style: const TextStyle(
                  color: AppPalette.mutedText,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          if (event.title.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              event.title,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 13,
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  (IconData, Color) _platformIcon(String platform) {
    final lower = platform.toLowerCase();
    if (lower.contains('instagram')) {
      return (Icons.camera_alt_rounded, const Color(0xFFE1306C));
    }
    if (lower.contains('facebook')) {
      return (Icons.facebook_rounded, const Color(0xFF1877F2));
    }
    if (lower.contains('tiktok')) {
      return (Icons.music_note_rounded, Colors.black);
    }
    return (Icons.share_rounded, AppPalette.ochre);
  }

  String _formatTimeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
