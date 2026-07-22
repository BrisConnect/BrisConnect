import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:brisconnect/models/review.dart';
import 'package:brisconnect/services/review_service.dart';
import 'package:brisconnect/theme/app_palette.dart';

class ReviewsDisplayWidget extends StatefulWidget {
  final String businessId;
  final String? currentVisitorId;
  final ReviewService? reviewService;

  const ReviewsDisplayWidget({
    super.key,
    required this.businessId,
    this.currentVisitorId,
    this.reviewService,
  });

  @override
  State<ReviewsDisplayWidget> createState() => _ReviewsDisplayWidgetState();
}

class _ReviewsDisplayWidgetState extends State<ReviewsDisplayWidget> {
  late final ReviewService _reviewService =
      widget.reviewService ?? ReviewService();

  final List<Review> _reviews = [];
  bool _isLoadingMore = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDocument;

  static const int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _loadMore();
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() => _isLoadingMore = true);

    try {
      final page = await _reviewService.getBusinessReviewsPage(
        widget.businessId,
        limit: _pageSize,
        startAfterDocument: _lastDocument,
      );

      setState(() {
        if (page.items.isEmpty || page.items.length < _pageSize) {
          _hasMore = false;
        }
        if (page.items.isNotEmpty) {
          _lastDocument = page.lastDocument;
          _reviews.addAll(page.items);
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading recommendations: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _markHelpful(String reviewId) async {
    try {
      await _reviewService.markHelpful(reviewId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Rating Summary
        _buildRatingSummary(),
        const SizedBox(height: 20),

        // Recommendations List
        const Text(
          'Visitor Recommendations',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        _buildReviewsList(),
      ],
    );
  }

  Widget _buildRatingSummary() {
    return StreamBuilder<double>(
      stream: _reviewService.getAverageRatingStream(widget.businessId),
      builder: (context, averageSnapshot) {
        return StreamBuilder<int>(
          stream: _reviewService.getReviewCountStream(widget.businessId),
          builder: (context, countSnapshot) {
            if (!averageSnapshot.hasData || !countSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final averageRating = averageSnapshot.data ?? 0.0;
            final reviewCount = countSnapshot.data ?? 0;

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppPalette.surfaceAlt,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            averageRating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildStarRating(averageRating),
                              const SizedBox(height: 4),
                              Text(
                                'Based on $reviewCount recommendations',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppPalette.mutedText,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStarRating(double rating) {
    return Row(
      children: List.generate(5, (index) {
        final fillPercentage = (rating - index).clamp(0, 1);
        return Icon(
          Icons.star,
          size: 16,
          color: fillPercentage > 0.5 ? AppPalette.ochre : AppPalette.background,
        );
      }),
    );
  }

  Widget _buildReviewsList() {
    if (_reviews.isEmpty && _isLoadingMore) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_reviews.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(
                Icons.recommend_outlined,
                size: 48,
                color: AppPalette.border,
              ),
              const SizedBox(height: 12),
              const Text(
                'No recommendations yet',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Be the first to recommend this business!',
                style: TextStyle(
                  fontSize: 12,
                  color: AppPalette.mutedText,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _reviews.length,
          itemBuilder: (context, index) => _buildReviewCard(_reviews[index]),
        ),
        if (_hasMore)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: _isLoadingMore
                ? const Center(child: CircularProgressIndicator())
                : TextButton(
                    onPressed: _loadMore,
                    child: const Text('Load more recommendations'),
                  ),
          ),
      ],
    );
  }

  Widget _buildReviewCard(Review review) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Name, Rating, Date
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        review.visitorName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _buildStarRating(review.rating.toDouble()),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'report') {
                      _showReportDialog(context, review.id);
                    } else if (value == 'delete') {
                      _confirmDeleteReview(context, review.id);
                    }
                  },
                  itemBuilder: (BuildContext context) => [
                    const PopupMenuItem<String>(
                      value: 'report',
                      child: Row(
                        children: [
                          Icon(Icons.flag_outlined, size: 18),
                          SizedBox(width: 8),
                          Text('Report'),
                        ],
                      ),
                    ),
                    if (widget.currentVisitorId != null &&
                        widget.currentVisitorId == review.visitorId)
                      const PopupMenuItem<String>(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.redAccent)),
                          ],
                        ),
                      ),
                  ],
                  icon: const Icon(Icons.more_vert, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Comment
            Text(
              review.comment,
              style: const TextStyle(
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),

            // Date and helpful action
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatReviewDate(review.createdAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: AppPalette.mutedText,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _markHelpful(review.id),
                  icon: const Icon(Icons.thumb_up_outlined, size: 14),
                  label: Text('Helpful ${review.helpfulCount}'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppPalette.mutedText,
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showReportDialog(BuildContext context, String reviewId) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report Recommendation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Why are you reporting this recommendation?',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLines: 3,
              minLines: 2,
              decoration: InputDecoration(
                hintText: 'Please explain...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please provide a reason'),
                  ),
                );
                return;
              }

              try {
                await _reviewService.reportReview(
                  reviewId,
                  reasonController.text.trim(),
                );
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Recommendation reported successfully'),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppPalette.ochre,
            ),
            child: const Text(
              'Report',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteReview(BuildContext context, String reviewId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Recommendation'),
        content: const Text(
          'Are you sure you want to delete your recommendation? It will be hidden from the public but kept in your history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _reviewService.deleteReview(reviewId);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Recommendation deleted')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String _formatReviewDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
