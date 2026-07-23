import 'package:flutter/material.dart';
import 'package:brisconnect/models/business_review.dart';
import 'package:brisconnect/services/business_ratings_service.dart';
import 'package:intl/intl.dart';

class BusinessReviewsWidget extends StatefulWidget {
  final String businessId;
  final double? currentAverageRating;
  final int? currentReviewCount;

  const BusinessReviewsWidget({
    Key? key,
    required this.businessId,
    this.currentAverageRating,
    this.currentReviewCount,
  }) : super(key: key);

  @override
  State<BusinessReviewsWidget> createState() => _BusinessReviewsWidgetState();
}

class _BusinessReviewsWidgetState extends State<BusinessReviewsWidget> {
  final _ratingsService = BusinessRatingsService();
  final _ratingController = TextEditingController();
  double _selectedRating = 3.0;
  double _selectedBuzzRating = 0.0;

  @override
  void dispose() {
    _ratingController.dispose();
    super.dispose();
  }

  void _submitReview() {
    if (_ratingController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please write a review')),
      );
      return;
    }

    _ratingsService
        .submitReview(
          businessId: widget.businessId,
          rating: _selectedRating,
          buzzRating: _selectedBuzzRating,
          comment: _ratingController.text,
        )
        .then((_) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Review submitted successfully'),
              backgroundColor: Color(0xFF00D084),
            ),
          );
          _ratingController.clear();
          setState(() {
            _selectedRating = 3.0;
            _selectedBuzzRating = 0.0;
          });
        })
        .catchError((e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Rating Header
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ratings & Reviews',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (widget.currentAverageRating != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.currentAverageRating?.toStringAsFixed(1) ?? '0',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: List.generate(
                            5,
                            (i) => Icon(
                              Icons.star,
                              color: i < widget.currentAverageRating!.round()
                                  ? Colors.amber
                                  : Colors.grey[300],
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(width: 24),
                  Text(
                    '${widget.currentReviewCount ?? 0} reviews',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(),

        // Review Submission Form
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Write a Review',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              // Rating Slider
              Row(
                children: [
                  const Text('Rating: '),
                  Expanded(
                    child: Slider(
                      value: _selectedRating,
                      onChanged: (value) => setState(() => _selectedRating = value),
                      min: 1,
                      max: 5,
                      divisions: 4,
                      label: _selectedRating.toStringAsFixed(1),
                    ),
                  ),
                  Text(_selectedRating.toStringAsFixed(1)),
                ],
              ),
              const SizedBox(height: 12),
              // Buzz Rating Slider
              Row(
                children: [
                  const Text('Buzz: '),
                  Expanded(
                    child: Slider(
                      value: _selectedBuzzRating,
                      onChanged: (value) =>
                          setState(() => _selectedBuzzRating = value),
                      min: 0,
                      max: 5,
                      divisions: 5,
                      label: _selectedBuzzRating.toStringAsFixed(1),
                    ),
                  ),
                  Text(_selectedBuzzRating.toStringAsFixed(1)),
                ],
              ),
              const SizedBox(height: 12),
              // Comment TextField
              TextField(
                controller: _ratingController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Share your experience...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitReview,
                  child: const Text('Submit Review'),
                ),
              ),
            ],
          ),
        ),
        const Divider(),

        // Reviews List
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Recent Reviews',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        StreamBuilder<List<BusinessReview>>(
          stream: _ratingsService.getBusinessReviews(widget.businessId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Error loading reviews: ${snapshot.error}'),
              );
            }

            final reviews = snapshot.data ?? [];

            if (reviews.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No reviews yet. Be the first to review!'),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: reviews.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, index) {
                final review = reviews[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            review.userName ?? 'Anonymous',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            DateFormat('MMM d, yyyy')
                                .format(review.createdAt),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: List.generate(
                          5,
                          (i) => Icon(
                            Icons.star,
                            color: i < review.rating.toInt()
                                ? Colors.amber
                                : Colors.grey[300],
                            size: 14,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        review.comment,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}
