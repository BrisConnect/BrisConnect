import 'package:flutter/material.dart';
import 'package:brisconnect/theme/app_palette.dart';

class FoodReviewDialog extends StatefulWidget {
  final String foodTitle;
  final String? existingReview;
  final double? existingRating;
  final double? existingBuzzRating;

  const FoodReviewDialog({
    super.key,
    required this.foodTitle,
    this.existingReview,
    this.existingRating,
    this.existingBuzzRating,
  });

  @override
  State<FoodReviewDialog> createState() => _FoodReviewDialogState();
}

class _FoodReviewDialogState extends State<FoodReviewDialog> {
  late TextEditingController _reviewController;
  late double _rating;
  late double _buzzRating;

  @override
  void initState() {
    super.initState();
    _reviewController = TextEditingController(text: widget.existingReview ?? '');
    _rating = widget.existingRating ?? 0;
    _buzzRating = widget.existingBuzzRating ?? 0;
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppPalette.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Add Your Review',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppPalette.charcoal,
                    ),
                  ),
                  IconButton(
                    onPressed: Navigator.of(context).pop,
                    icon: const Icon(Icons.close_rounded),
                    color: AppPalette.mutedText,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                widget.foodTitle,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppPalette.mutedText,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 20),
              // Rating Stars
              const Text(
                'How would you rate this place?',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppPalette.charcoal,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: List.generate(5, (index) {
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _rating = (index + 1).toDouble();
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        index < _rating ? Icons.star_rounded : Icons.star_border_rounded,
                        color: AppPalette.gold,
                        size: 32,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 20),
              // Buzz Rating
              const Text(
                'Buzz Rating (How much buzz is there?)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppPalette.charcoal,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: List.generate(5, (index) {
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _buzzRating = (index + 1).toDouble();
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        index < _buzzRating ? Icons.flash_on_rounded : Icons.flash_on_outlined,
                        color: AppPalette.ochre,
                        size: 32,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 20),
              // Review Text
              const Text(
                'Write your review',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppPalette.charcoal,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: AppPalette.surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppPalette.border),
                ),
                child: TextField(
                  controller: _reviewController,
                  maxLines: 4,
                  minLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Share your experience... (optional)',
                    hintStyle: TextStyle(color: AppPalette.mutedText),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(12),
                  ),
                  style: const TextStyle(color: AppPalette.charcoal),
                ),
              ),
              const SizedBox(height: 20),
              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: Navigator.of(context).pop,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppPalette.border),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: AppPalette.charcoal),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppPalette.ochre,
                    ),
                    onPressed: () {
                      Navigator.of(context).pop({
                        'review': _reviewController.text,
                        'rating': _rating,
                        'buzzRating': _buzzRating,
                      });
                    },
                    child: const Text(
                      'Submit Review',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
