import 'package:flutter/material.dart';
import 'package:brisconnect/services/review_service.dart';
import 'package:brisconnect/theme/app_palette.dart';

class SubmitReviewBottomSheet extends StatefulWidget {
  final String businessId;
  final String visitorId;
  final String visitorName;
  final Function(String reviewId) onReviewSubmitted;
  final ReviewService? reviewService;

  const SubmitReviewBottomSheet({
    super.key,
    required this.businessId,
    required this.visitorId,
    required this.visitorName,
    required this.onReviewSubmitted,
    this.reviewService,
  });

  @override
  State<SubmitReviewBottomSheet> createState() =>
      _SubmitReviewBottomSheetState();
}

class _SubmitReviewBottomSheetState extends State<SubmitReviewBottomSheet> {
  late final ReviewService _reviewService =
      widget.reviewService ?? ReviewService();
  final TextEditingController _commentController = TextEditingController();
  int _rating = 5;
  int _buzzRating = 0;
  bool _isSubmitting = false;
  bool _privacyConsent = false;

  static const String _privacyNotice =
      'Your recommendation, first name, and rating will be publicly visible on this business profile. '
      'You can delete your recommendation at any time. By submitting, you consent to this display.';

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    if (_commentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please share why you recommend this business')),
      );
      return;
    }

    if (!_privacyConsent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please agree to the privacy notice')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final reviewId = await _reviewService.createReview(
        businessId: widget.businessId,
        visitorId: widget.visitorId,
        visitorName: widget.visitorName,
        rating: _rating,
        buzzRating: _buzzRating,
        comment: _commentController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recommendation submitted successfully!')),
        );
        widget.onReviewSubmitted(reviewId);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      builder: (context, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Recommend this Business',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Star Rating
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Rating',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: List.generate(5, (index) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => setState(() => _rating = index + 1),
                            child: Icon(
                              index < _rating ? Icons.star : Icons.star_border,
                              color: AppPalette.ochre,
                              size: 32,
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$_rating out of 5 stars',
                      style: TextStyle(
                        color: AppPalette.mutedText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Buzz Rating
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Buzz Rating',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'How much buzz is this business generating?',
                      style: TextStyle(
                        color: AppPalette.mutedText,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: List.generate(5, (index) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => setState(() => _buzzRating = index + 1),
                            child: Icon(
                              index < _buzzRating
                                  ? Icons.flash_on
                                  : Icons.flash_on_outlined,
                              color: AppPalette.ochre,
                              size: 32,
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _buzzRating > 0
                          ? '$_buzzRating out of 5 lightning bolts'
                          : 'Tap a lightning bolt to rate the buzz',
                      style: TextStyle(
                        color: AppPalette.mutedText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Comment Input
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Why do you recommend this business?',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _commentController,
                      maxLines: 4,
                      minLines: 3,
                      maxLength: 500,
                      enabled: !_isSubmitting,
                      decoration: InputDecoration(
                        hintText: 'Share what you loved about your visit...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Privacy consent
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: _privacyConsent,
                          onChanged: _isSubmitting
                              ? null
                              : (value) =>
                                  setState(() => _privacyConsent = value ?? false),
                          activeColor: AppPalette.ochre,
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              _privacyNotice,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppPalette.mutedText,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitReview,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: AppPalette.ochre,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Text(
                            'Submit Recommendation',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
