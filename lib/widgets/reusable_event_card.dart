import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:brisconnect/theme/app_palette.dart';

class ReusableEventCard extends StatelessWidget {
  static const String _fallbackImageUrl =
      'https://images.unsplash.com/photo-1472653431158-6364773b2a56?auto=format&fit=crop&w=1400&q=80';

  final String imageUrl;
  final String badgeText;
  final String title;
  final String? description;
  final String dateTime;
  final String location;
  final String price;
  final bool isFavorite;
  final VoidCallback? onShareTap;
  final VoidCallback? onWebTap;
  final VoidCallback? onFavoriteTap;
  final VoidCallback? onCardTap;

  const ReusableEventCard({
    super.key,
    required this.imageUrl,
    required this.badgeText,
    required this.title,
    this.description,
    required this.dateTime,
    required this.location,
    required this.price,
    this.isFavorite = false,
    this.onShareTap,
    this.onWebTap,
    this.onFavoriteTap,
    this.onCardTap,
  });

  @override
  Widget build(BuildContext context) {
    final normalizedImageUrl = imageUrl.trim().isEmpty ? _fallbackImageUrl : imageUrl.trim();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onCardTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: AppPalette.surface,
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [
              BoxShadow(
                color: AppPalette.cardShadow,
                blurRadius: 18,
                offset: Offset(0, 9),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(22),
                      topRight: Radius.circular(22),
                    ),
                    child: CachedNetworkImage(
                      imageUrl: normalizedImageUrl,
                      height: 190,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (context, _) => Container(
                        height: 190,
                        color: AppPalette.surfaceAlt,
                        alignment: Alignment.center,
                        child: const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      errorWidget: (context, _, __) => Container(
                        height: 190,
                        color: AppPalette.surfaceAlt,
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.image_not_supported_rounded,
                          color: AppPalette.mutedText,
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                  if (badgeText.trim().isNotEmpty)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppPalette.ochre,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          badgeText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: AppPalette.charcoal,
                        height: 1.2,
                      ),
                    ),
                    if (description != null && description!.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppPalette.mutedText,
                          fontSize: 13,
                          height: 1.35,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    _DetailRow(icon: Icons.calendar_today_rounded, text: dateTime),
                    const SizedBox(height: 6),
                    _DetailRow(icon: Icons.place_rounded, text: location),
                    const SizedBox(height: 6),
                    _DetailRow(icon: Icons.sell_rounded, text: price),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        IconButton.filledTonal(
                          onPressed: onShareTap,
                          icon: const Icon(Icons.share_rounded),
                          color: AppPalette.deepBlue,
                        ),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          onPressed: onWebTap,
                          tooltip: 'More information',
                          icon: const Icon(Icons.info_outline_rounded),
                          color: AppPalette.deepBlue,
                        ),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          onPressed: onFavoriteTap,
                          icon: Icon(
                            isFavorite
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                          ),
                          color: isFavorite ? AppPalette.ochre : AppPalette.deepBlue,
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
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _DetailRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppPalette.deepBlue),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: AppPalette.mutedText,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
