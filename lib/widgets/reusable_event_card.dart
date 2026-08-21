import 'package:flutter/material.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/widgets/fallback_image.dart';
import 'package:url_launcher/url_launcher.dart';

class ReusableEventCard extends StatelessWidget {
  final String imageUrl;
  final String badgeText;
  final String title;
  final String? section;
  final String? description;
  final String dateTime;
  final String location;
  final String price;
  final String? source;
  final String? venue;
  final String? phone;
  final String? website;
  final String? email;
  final String? facebookUrl;
  final String? instagramUrl;
  final String? onlineOrderUrl;
  final List<String>? categories;
  final String? cuisine;
  final double? rating;
  final String? distance;
  final bool? isOpenNow;
  final String? openStatusText;
  final String? waitTime;
  final String? suburb;
  final bool isVerified;
  final DateTime? createdAt;
  final bool isFavorite;
  final VoidCallback? onShareTap;
  final VoidCallback? onWebTap;
  final VoidCallback? onFavoriteTap;
  final VoidCallback? onReviewTap;
  final VoidCallback? onCardTap;
  final Color? cardColor;
  final BoxBorder? border;

  const ReusableEventCard({
    super.key,
    required this.imageUrl,
    required this.badgeText,
    required this.title,
    this.section,
    this.description,
    required this.dateTime,
    required this.location,
    required this.price,
    this.source,
    this.venue,
    this.phone,
    this.website,
    this.email,
    this.facebookUrl,
    this.instagramUrl,
    this.onlineOrderUrl,
    this.categories,
    this.cuisine,
    this.rating,
    this.distance,
    this.isOpenNow,
    this.openStatusText,
    this.waitTime,
    this.suburb,
    this.isVerified = false,
    this.createdAt,
    this.isFavorite = false,
    this.onShareTap,
    this.onWebTap,
    this.onFavoriteTap,
    this.onReviewTap,
    this.onCardTap,
    this.cardColor,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return RepaintBoundary(
            child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onCardTap,
            borderRadius: BorderRadius.circular(22),
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppPalette.surface,
                borderRadius: BorderRadius.circular(22),
                border: border ??
                    Border.all(
                      color: const Color(0xFF93C5FD),
                      width: 1.5,
                    ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x26000000),
                    blurRadius: 22,
                    offset: Offset(0, 10),
                    spreadRadius: -2,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      FallbackImage(
                        imageUrl: imageUrl,
                        height: 190,
                        width: double.infinity,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(22),
                          topRight: Radius.circular(22),
                        ),
                        category: section,
                      ),
                      if (badgeText.trim().isNotEmpty)
                        Positioned(
                          top: 12,
                          right: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
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
                      mainAxisSize: MainAxisSize.min,
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
                        const SizedBox(height: 8),
                        _BusinessHeaderRow(
                          suburb: suburb,
                          isVerified: isVerified,
                          createdAt: createdAt,
                        ),
                        if (description != null &&
                            description!.trim().isNotEmpty) ...[
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
                        _MetadataRow(
                          rating: rating,
                          price: price,
                          distance: distance,
                          isOpenNow: isOpenNow,
                          openStatusText: openStatusText,
                          waitTime: waitTime,
                        ),
                        const SizedBox(height: 10),
                        _DetailRow(
                            icon: Icons.calendar_today_rounded, text: dateTime),
                        const SizedBox(height: 6),
                        _DetailRow(icon: Icons.place_rounded, text: location),
                        if (venue != null &&
                            venue!.trim().isNotEmpty &&
                            venue != location) ...[
                          const SizedBox(height: 6),
                          _DetailRow(
                              icon: Icons.location_city_rounded, text: venue!),
                        ],
                        if (cuisine != null && cuisine!.trim().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          _DetailRow(
                              icon: Icons.restaurant_rounded, text: cuisine!),
                        ],
                        if (source != null && source!.trim().isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.verified_rounded,
                                  size: 14,
                                  color: AppPalette.deepBlue
                                      .withValues(alpha: 0.6)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Source: $source',
                                  style: TextStyle(
                                    color: AppPalette.deepBlue
                                        .withValues(alpha: 0.6),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (categories != null && categories!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: categories!
                                .take(4)
                                .map(
                                  (cat) => Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppPalette.deepBlue
                                          .withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      cat,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: AppPalette.deepBlue,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Quick contact / action chips on the business card itself.
                  if ((phone ?? '').trim().isNotEmpty ||
                      (website ?? '').trim().isNotEmpty ||
                      (email ?? '').trim().isNotEmpty ||
                      (facebookUrl ?? '').trim().isNotEmpty ||
                      (instagramUrl ?? '').trim().isNotEmpty ||
                      (onlineOrderUrl ?? '').trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if ((phone ?? '').trim().isNotEmpty)
                            _ContactChip(
                              icon: Icons.phone_rounded,
                              label: 'Call',
                              onTap: () => _launchUrl(
                                  context,
                                  Uri(scheme: 'tel', path: phone!.trim()),
                                  'No phone number available'),
                            ),
                          if ((website ?? '').trim().isNotEmpty)
                            _ContactChip(
                              icon: Icons.language_rounded,
                              label: 'Website',
                              onTap: () => _launchUrl(
                                  context,
                                  Uri.parse(website!.trim()),
                                  'No website available'),
                            ),
                          if ((email ?? '').trim().isNotEmpty)
                            _ContactChip(
                              icon: Icons.email_rounded,
                              label: 'Email',
                              onTap: () => _launchUrl(
                                  context,
                                  Uri(scheme: 'mailto', path: email!.trim()),
                                  'No email available'),
                            ),
                          if ((onlineOrderUrl ?? '').trim().isNotEmpty)
                            _ContactChip(
                              icon: Icons.shopping_bag_rounded,
                              label: 'Order',
                              onTap: () => _launchUrl(
                                  context,
                                  Uri.parse(onlineOrderUrl!.trim()),
                                  'No order link available'),
                            ),
                          if ((facebookUrl ?? '').trim().isNotEmpty)
                            _ContactChip(
                              icon: Icons.facebook,
                              label: 'Facebook',
                              onTap: () => _launchUrl(
                                  context,
                                  Uri.parse(facebookUrl!.trim()),
                                  'No Facebook link available'),
                            ),
                          if ((instagramUrl ?? '').trim().isNotEmpty)
                            _ContactChip(
                              icon: Icons.camera_alt_rounded,
                              label: 'Instagram',
                              onTap: () => _launchUrl(
                                  context,
                                  Uri.parse(instagramUrl!.trim()),
                                  'No Instagram link available'),
                            ),
                        ],
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                    child: Row(
                      children: [
                        IconButton.filledTonal(
                          constraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 36,
                          ),
                          iconSize: 18,
                          onPressed: onShareTap,
                          icon: const Icon(Icons.share_rounded),
                          color: AppPalette.deepBlue,
                        ),
                        const SizedBox(width: 6),
                        IconButton.filledTonal(
                          constraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 36,
                          ),
                          iconSize: 18,
                          onPressed: onReviewTap,
                          tooltip: 'Add/Edit review',
                          icon: const Icon(Icons.rate_review_rounded),
                          color: AppPalette.deepBlue,
                        ),
                        const SizedBox(width: 6),
                        IconButton.filledTonal(
                          constraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 36,
                          ),
                          iconSize: 18,
                          onPressed: onWebTap,
                          tooltip: 'More information',
                          icon: const Icon(Icons.info_outline_rounded),
                          color: AppPalette.deepBlue,
                        ),
                        const SizedBox(width: 6),
                        IconButton.filledTonal(
                          constraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 36,
                          ),
                          iconSize: 18,
                          onPressed: onFavoriteTap,
                          icon: Icon(
                            isFavorite
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                          ),
                          color: isFavorite
                              ? AppPalette.ochre
                              : AppPalette.deepBlue,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ));
      },
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

class _BusinessHeaderRow extends StatelessWidget {
  final String? suburb;
  final bool isVerified;
  final DateTime? createdAt;

  const _BusinessHeaderRow({
    this.suburb,
    this.isVerified = false,
    this.createdAt,
  });

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];

    if (isVerified) {
      items.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.verified_rounded, size: 12, color: Color(0xFF047857)),
              SizedBox(width: 3),
              Text(
                'Verified',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF047857),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final suburbText = suburb?.trim() ?? '';
    if (suburbText.isNotEmpty) {
      if (items.isNotEmpty) items.add(const SizedBox(width: 8));
      items.add(
        Flexible(
          child: Text(
            suburbText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppPalette.mutedText,
            ),
          ),
        ),
      );
    }

    if (createdAt != null) {
      if (items.isNotEmpty) items.add(const SizedBox(width: 8));
      items.add(
        Text(
          _formatTimeAgo(createdAt!),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppPalette.mutedText,
          ),
        ),
      );
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: items,
    );
  }
}

String _formatTimeAgo(DateTime date) {
  final diff = DateTime.now().difference(date);
  if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

class _MetadataRow extends StatelessWidget {
  final double? rating;
  final String? price;
  final String? distance;
  final bool? isOpenNow;
  final String? openStatusText;
  final String? waitTime;

  const _MetadataRow({
    this.rating,
    this.price,
    this.distance,
    this.isOpenNow,
    this.openStatusText,
    this.waitTime,
  });

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];

    if (rating != null && rating! > 0) {
      chips.add(_MetadataChip(
        icon: Icons.star_rounded,
        text: rating!.toStringAsFixed(1),
        iconColor: const Color(0xFFF59E0B),
      ));
    }

    final priceText = price?.trim() ?? '';
    if (priceText.isNotEmpty) {
      chips.add(_MetadataChip(
        icon: Icons.attach_money_rounded,
        text: priceText,
      ));
    }

    if (distance != null && distance!.isNotEmpty) {
      chips.add(_MetadataChip(
        icon: Icons.place_rounded,
        text: distance!,
      ));
    }

    if (openStatusText != null && openStatusText!.isNotEmpty) {
      final isOpen = isOpenNow ?? false;
      chips.add(_MetadataChip(
        icon: isOpen
            ? Icons.access_time_filled_rounded
            : Icons.access_time_rounded,
        text: openStatusText!,
        iconColor: isOpen ? const Color(0xFF10B981) : const Color(0xFFEF4444),
        textColor: isOpen ? const Color(0xFF047857) : const Color(0xFFB91C1C),
      ));
    }

    final waitText = waitTime?.trim() ?? '';
    if (waitText.isNotEmpty) {
      chips.add(_MetadataChip(
        icon: Icons.hourglass_top_rounded,
        text: waitText,
      ));
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: chips,
    );
  }
}

class _MetadataChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? iconColor;
  final Color? textColor;

  const _MetadataChip({
    required this.icon,
    required this.text,
    this.iconColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppPalette.deepBlue.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: iconColor ?? AppPalette.deepBlue,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: textColor ?? AppPalette.deepBlue,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ContactChip({
    required this.icon,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 16, color: Colors.white),
      label: Text(label),
      labelStyle: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      backgroundColor: AppPalette.ochre,
      side: BorderSide.none,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      onPressed: onTap,
    );
  }
}

Future<void> _launchUrl(
    BuildContext context, Uri uri, String fallbackMessage) async {
  try {
    // Add a scheme to web links if the stored value is missing one.
    var resolved = uri;
    final urlString = uri.toString();
    if (uri.scheme.isEmpty &&
        (urlString.startsWith('www.') ||
            urlString.contains('.') && !urlString.contains(' '))) {
      resolved = Uri.parse('https://$urlString');
    }
    if (await canLaunchUrl(resolved)) {
      await launchUrl(resolved, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(fallbackMessage)),
        );
      }
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open link: $e')),
      );
    }
  }
}
