import 'package:flutter/material.dart';

import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/widgets/fallback_image.dart';

/// A large, visually prominent business card designed to be the hero of the
/// home feed.
///
/// Shows an edge-to-edge food image, favourite action, business name, rating,
/// open/closed status, and location.
class BusinessCard extends StatelessWidget {
  final String id;
  final String imageUrl;
  final String name;
  final double rating;
  final String? reviewCount;
  final String cuisine;
  final String? suburb;
  final bool isOpen;
  final String? priceRange;
  final bool isFavourite;
  final ValueChanged<bool>? onFavouriteChanged;
  final VoidCallback? onTap;

  const BusinessCard({
    super.key,
    required this.id,
    required this.imageUrl,
    required this.name,
    required this.rating,
    this.reviewCount,
    required this.cuisine,
    this.suburb,
    required this.isOpen,
    this.priceRange,
    this.isFavourite = false,
    this.onFavouriteChanged,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final width = _cardWidth(context);

    return SizedBox(
      width: width,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppPalette.border,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.14),
                blurRadius: 24,
                offset: const Offset(0, 10),
                spreadRadius: -3,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Large edge-to-edge food image.
                Stack(
                  children: [
                    SizedBox(
                      height: width * 0.72,
                      width: double.infinity,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return FallbackImage(
                            imageUrl: imageUrl,
                            width: constraints.maxWidth,
                            height: constraints.maxHeight,
                            fit: BoxFit.cover,
                            category: cuisine,
                          );
                        },
                      ),
                    ),

                    // Favourite heart.
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Material(
                        color: Colors.white.withValues(alpha: 0.95),
                        shape: const CircleBorder(),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => onFavouriteChanged?.call(!isFavourite),
                          child: Padding(
                            padding: const EdgeInsets.all(9),
                            child: Icon(
                              isFavourite
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              color: AppPalette.ochre,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Open/Closed badge.
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: isOpen
                              ? const Color(0xFFE8F5E9)
                              : const Color(0xFFFFEBEE),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: isOpen
                                    ? const Color(0xFF2E7D32)
                                    : const Color(0xFFB71C1C),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              isOpen ? 'Open' : 'Closed',
                              style: TextStyle(
                                color: isOpen
                                    ? const Color(0xFF1B5E20)
                                    : const Color(0xFFB71C1C),
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                // Business details.
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(
                                color: AppPalette.charcoal,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                height: 1.25,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (priceRange != null && priceRange!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Text(
                                priceRange!,
                                style: TextStyle(
                                  color: AppPalette.mutedText
                                      .withValues(alpha: 0.8),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            color: Color(0xFFFFB900),
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            rating.toStringAsFixed(1),
                            style: const TextStyle(
                              color: AppPalette.charcoal,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (reviewCount != null && reviewCount!.isNotEmpty)
                            Text(
                              ' ($reviewCount)',
                              style: TextStyle(
                                color:
                                    AppPalette.mutedText.withValues(alpha: 0.8),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              cuisine,
                              style: TextStyle(
                                color: AppPalette.mutedText
                                    .withValues(alpha: 0.85),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (suburb != null && suburb!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_rounded,
                              size: 14,
                              color: AppPalette.mutedText,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                suburb!,
                                style: TextStyle(
                                  color: AppPalette.mutedText
                                      .withValues(alpha: 0.9),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
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

  double _cardWidth(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    if (screenWidth >= 1200) {
      return 340;
    } else if (screenWidth >= 900) {
      return 310;
    } else if (screenWidth >= 600) {
      return 290;
    }
    return 278;
  }
}
