import 'package:flutter/material.dart';

import 'package:brisconnect/auth/visitor_auth.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/widgets/fallback_image.dart';

/// A prominent food-business card for the visitor discover feed.
///
/// Displays a large image, favourite action, open status, name, rating,
/// cuisine, and suburb. Tapping the card invokes [onTap]; tapping the
/// favourite button toggles save state via VisitorAuth.
class DiscoverBusinessCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback? onTap;
  final VoidCallback? onShareTap;
  final double width;

  const DiscoverBusinessCard({
    super.key,
    required this.item,
    this.onTap,
    this.onShareTap,
    this.width = 280,
  });

  @override
  Widget build(BuildContext context) {
    final id = (item['id'] as String? ?? '').trim();
    final imageUrl = (item['imageUrl'] as String? ?? '').trim();
    final title = (item['title'] as String? ?? 'Food').trim();
    final suburb = (item['suburb'] as String? ?? '').trim();
    final location = (item['location'] as String? ?? '').trim();
    final rating = (item['rating'] as num?)?.toDouble() ?? 0.0;
    final reviewCount = (item['reviewCount'] as num?)?.toInt() ?? 0;
    final categories = (item['categories'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .where((s) => s.isNotEmpty)
            .toList(growable: false) ??
        const <String>[];
    final cuisine = categories.isNotEmpty ? categories.first : 'Food';
    final price = (item['price'] as String? ?? '').trim();
    final openStatus = _openStatusFor(item);
    final isFavorite = VisitorAuth.isBusinessSaved(id);

    return SizedBox(
      width: width,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppPalette.ochre.withValues(alpha: 0.3),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.20),
                blurRadius: 30,
                offset: const Offset(0, 12),
                spreadRadius: -2,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Hero image.
                Stack(
                  children: [
                    SizedBox(
                      height: width * 0.72,
                      width: double.infinity,
                      child: FallbackImage(
                        imageUrl: imageUrl,
                        category: 'food',
                        fit: BoxFit.cover,
                      ),
                    ),

                    // Share button.
                    if (onShareTap != null)
                      Positioned(
                        top: 12,
                        left: 12,
                        child: Material(
                          color: Colors.white.withValues(alpha: 0.95),
                          shape: const CircleBorder(),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: onShareTap,
                            child: const Padding(
                              padding: EdgeInsets.all(9),
                              child: Icon(
                                Icons.share_rounded,
                                color: AppPalette.ochre,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ),

                    // Favourite button.
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Material(
                        color: Colors.white.withValues(alpha: 0.95),
                        shape: const CircleBorder(),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => VisitorAuth.toggleSavedBusiness(id),
                          child: Padding(
                            padding: const EdgeInsets.all(9),
                            child: Icon(
                              isFavorite
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
                    if (openStatus != null)
                      Positioned(
                        bottom: 12,
                        left: 12,
                        child: _OpenStatusBadge(status: openStatus),
                      ),
                  ],
                ),

                // Details.
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
                              title,
                              style: const TextStyle(
                                color: AppPalette.charcoal,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                height: 1.25,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (price.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Text(
                                price,
                                style: const TextStyle(
                                  color: AppPalette.mutedText,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
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
                            color: AppPalette.gold,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            rating.toStringAsFixed(1),
                            style: const TextStyle(
                              color: AppPalette.charcoal,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            ' · $reviewCount reviews',
                            style: const TextStyle(
                              color: AppPalette.mutedText,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              cuisine,
                              style: const TextStyle(
                                color: AppPalette.mutedText,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
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
                              suburb.isNotEmpty ? suburb : location,
                              style: const TextStyle(
                                color: AppPalette.mutedText,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
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

  ({bool isOpen, String label})? _openStatusFor(Map<String, dynamic> item) {
    final label = (item['openStatusText'] as String? ?? '').trim();
    final isOpen = item['isOpenNow'] as bool?;
    if (isOpen == null && label.isEmpty) return null;
    return (
      isOpen: isOpen ?? label.toLowerCase().contains('open'),
      label: label
    );
  }
}

class _OpenStatusBadge extends StatelessWidget {
  final ({bool isOpen, String label}) status;

  const _OpenStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final isOpen = status.isOpen;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isOpen ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: isOpen ? const Color(0xFF2E7D32) : const Color(0xFFB71C1C),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            status.label.isNotEmpty
                ? status.label
                : (isOpen ? 'Open now' : 'Closed'),
            style: TextStyle(
              color: isOpen ? const Color(0xFF1B5E20) : const Color(0xFFB71C1C),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
