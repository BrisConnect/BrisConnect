// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:brisconnect/services/review_service.dart';
import 'package:brisconnect/theme/app_palette.dart';

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;

  const _SectionLabel({
    required this.icon,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: AppPalette.ochre),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 15,
                color: AppPalette.charcoal,
              ),
            ),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: const TextStyle(
              color: AppPalette.mutedText,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

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
        const SnackBar(
            content: Text('Please share why you recommend this business')),
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
          const SnackBar(
              content: Text('Recommendation submitted successfully!')),
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
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppPalette.ochre.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.rate_review_rounded,
                          color: AppPalette.ochre, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Recommend this Business',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppPalette.charcoal,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: AppPalette.mutedText),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Star Rating
                _SectionLabel(
                  icon: Icons.star_rounded,
                  title: 'Your Rating',
                  subtitle: '$_rating out of 5 stars',
                ),
                const SizedBox(height: 10),
                Row(
                  children: List.generate(5, (index) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: GestureDetector(
                        onTap: () => setState(() => _rating = index + 1),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          transform: index < _rating
                              ? (Matrix4.identity()..scale(1.05))
                              : Matrix4.identity(),
                          child: Icon(
                            index < _rating
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            color: AppPalette.ochre,
                            size: 36,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 20),

                // Buzz Rating
                _SectionLabel(
                  icon: Icons.flash_on_rounded,
                  title: 'Buzz Rating',
                  subtitle: _buzzRating > 0
                      ? '$_buzzRating out of 5 lightning bolts'
                      : 'How much buzz is this business generating?',
                ),
                const SizedBox(height: 10),
                Row(
                  children: List.generate(5, (index) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: GestureDetector(
                        onTap: () => setState(() => _buzzRating = index + 1),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          transform: index < _buzzRating
                              ? (Matrix4.identity()..scale(1.05))
                              : Matrix4.identity(),
                          child: Icon(
                            index < _buzzRating
                                ? Icons.flash_on_rounded
                                : Icons.flash_on_outlined,
                            color: AppPalette.ochre,
                            size: 32,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 20),

                // Comment Input
                _SectionLabel(
                  icon: Icons.chat_bubble_outline_rounded,
                  title: 'Why do you recommend this business?',
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _commentController,
                  maxLines: 4,
                  minLines: 3,
                  maxLength: 500,
                  enabled: !_isSubmitting,
                  decoration: InputDecoration(
                    hintText: 'Share what you loved about your visit...',
                    filled: true,
                    fillColor: AppPalette.surfaceAlt.withValues(alpha: 0.4),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: AppPalette.border.withValues(alpha: 0.6)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppPalette.ochre, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.all(14),
                    counterStyle: const TextStyle(
                      color: AppPalette.mutedText,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Privacy consent
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppPalette.surfaceAlt.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppPalette.border.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: _privacyConsent,
                        onChanged: _isSubmitting
                            ? null
                            : (value) => setState(
                                () => _privacyConsent = value ?? false),
                        activeColor: AppPalette.ochre,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            _privacyNotice,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppPalette.mutedText,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _submitReview,
                    icon: _isSubmitting
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Icon(Icons.send_rounded, size: 18),
                    label: _isSubmitting
                        ? const Text('Submitting...')
                        : const Text('Submit Recommendation'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: AppPalette.ochre,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          AppPalette.mutedText.withValues(alpha: 0.3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
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
