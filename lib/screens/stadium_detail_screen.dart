import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/widgets/audio_guide_widget.dart';
import 'package:brisconnect/widgets/logo_app_bar_title.dart';

class StadiumDetailScreen extends StatelessWidget {
  const StadiumDetailScreen({
    super.key,
    required this.title,
    required this.description,
    required this.location,
    required this.imageUrl,
    required this.categories,
    this.badge,
    this.dateTime,
    this.price,
    this.mapQuery,
    this.webLink,
    this.aiAudio,
  });

  static const String _fallbackImage =
      'https://images.unsplash.com/photo-1517466787929-bc90951d0974?auto=format&fit=crop&w=1400&q=80';

  final String title;
  final String description;
  final String location;
  final String imageUrl;
  final List<String> categories;
  final String? badge;
  final String? dateTime;
  final String? price;
  final String? mapQuery;
  final String? webLink;
  final String? aiAudio;

  String _buildNarrationText() {
    if ((aiAudio ?? '').trim().isNotEmpty) return aiAudio!.trim();
    final parts = <String>[
      'Welcome to $title',
      if ((badge ?? '').trim().isNotEmpty)
        'This is one of Brisbane\'s notable ${badge!.trim().toLowerCase()} venues',
      if (location.trim().isNotEmpty)
        'You\'ll find it in $location, right in the middle of Brisbane\'s live event energy',
      if ((dateTime ?? '').trim().isNotEmpty)
        'Schedules change through the year, with activity listed as ${dateTime!.trim()}',
      if (description.trim().isNotEmpty)
        'Here\'s the feel of the place. ${description.trim()}',
      if ((price ?? '').trim().isNotEmpty)
        (price!.toLowerCase().contains('free') ||
                price!.toLowerCase().contains('mix'))
            ? 'Access and event pricing can vary depending on what\'s on'
            : 'Entry usually requires a paid ticket',
      if (categories.isNotEmpty)
        'It is especially relevant for ${categories.join(', ')}',
    ];
    return '${parts.where((part) => part.trim().isNotEmpty).join('. ')}.';
  }

  Future<void> _openLink(BuildContext context, String rawUrl) async {
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null) return;
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open this link right now.')),
      );
    }
  }

  Future<void> _openMap(BuildContext context) async {
    final query =
        (mapQuery ?? '').trim().isNotEmpty ? mapQuery!.trim() : location;
    if (query.trim().isEmpty) return;
    await _openLink(
      context,
      'https://maps.google.com/?q=${Uri.encodeComponent(query)}',
    );
  }

  Future<void> _share() async {
    final lines = [
      title,
      if (location.trim().isNotEmpty) location,
      if ((dateTime ?? '').trim().isNotEmpty) dateTime!.trim(),
      if ((webLink ?? '').trim().isNotEmpty) webLink!.trim(),
    ];
    await SharePlus.instance.share(ShareParams(text: lines.join('\n')));
  }

  @override
  Widget build(BuildContext context) {
    final effectiveImage =
        imageUrl.trim().isNotEmpty ? imageUrl.trim() : _fallbackImage;
    final narrationText = _buildNarrationText();

    return Scaffold(
      backgroundColor: AppPalette.background,
      appBar: AppBar(
        title: const LogoAppBarTitle('Stadium Details'),
        backgroundColor: AppPalette.surface,
        foregroundColor: AppPalette.charcoal,
        actions: [
          IconButton(
            tooltip: 'Share',
            onPressed: _share,
            icon: const Icon(Icons.share_rounded),
          ),
        ],
      ),
      body: ListView(
        children: [
          CachedNetworkImage(
            imageUrl: effectiveImage,
            height: 230,
            width: double.infinity,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(
              height: 230,
              color: AppPalette.surfaceAlt,
              alignment: Alignment.center,
              child: const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            errorWidget: (_, __, ___) => Container(
              height: 230,
              color: AppPalette.surfaceAlt,
              alignment: Alignment.center,
              child: const Icon(
                Icons.image_not_supported_rounded,
                size: 48,
                color: AppPalette.mutedText,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if ((badge ?? '').trim().isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppPalette.deepBlue,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      badge!.trim(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppPalette.charcoal,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 14),
                if (location.trim().isNotEmpty) ...[
                  _StadiumInfoRow(
                    icon: Icons.place_rounded,
                    iconColor: AppPalette.ochre,
                    text: location,
                  ),
                  const SizedBox(height: 8),
                ],
                if ((dateTime ?? '').trim().isNotEmpty) ...[
                  _StadiumInfoRow(
                    icon: Icons.schedule_rounded,
                    iconColor: AppPalette.deepBlue,
                    text: dateTime!.trim(),
                  ),
                  const SizedBox(height: 8),
                ],
                if ((price ?? '').trim().isNotEmpty) ...[
                  _StadiumInfoRow(
                    icon: Icons.sell_rounded,
                    iconColor: AppPalette.ochre,
                    text: price!.trim(),
                  ),
                  const SizedBox(height: 12),
                ],
                const Divider(color: AppPalette.border),
                const SizedBox(height: 18),
                if (description.trim().isNotEmpty) ...[
                  const _StadiumSectionHeader(title: 'About this Venue'),
                  const SizedBox(height: 8),
                  Text(
                    description.trim(),
                    style: const TextStyle(
                      color: AppPalette.charcoal,
                      height: 1.55,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 22),
                ],
                if (categories.isNotEmpty) ...[
                  const _StadiumSectionHeader(title: 'Venue Highlights'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: categories
                        .map(
                          (category) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppPalette.surfaceAlt,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: AppPalette.border),
                            ),
                            child: Text(
                              category,
                              style: const TextStyle(
                                color: AppPalette.charcoal,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
                  const SizedBox(height: 22),
                ],
                if (narrationText.isNotEmpty) ...[
                  const _StadiumSectionHeader(title: 'Audio Guide'),
                  const SizedBox(height: 10),
                  AudioGuideWidget(
                    narrationText: narrationText,
                    helperText:
                        'Listen to a quick guided intro to the venue, schedule, and atmosphere.',
                  ),
                  const SizedBox(height: 22),
                ],
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _openMap(context),
                        icon: const Icon(Icons.map_rounded),
                        label: const Text('View on Map'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppPalette.deepBlue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    if ((webLink ?? '').trim().isNotEmpty) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _openLink(context, webLink!.trim()),
                          icon: const Icon(Icons.open_in_browser_rounded),
                          label: const Text('Website'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppPalette.mutedText,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StadiumInfoRow extends StatelessWidget {
  const _StadiumInfoRow({
    required this.icon,
    required this.iconColor,
    required this.text,
  });

  final IconData icon;
  final Color iconColor;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: AppPalette.charcoal,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _StadiumSectionHeader extends StatelessWidget {
  const _StadiumSectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppPalette.deepBlue,
        letterSpacing: 0.2,
      ),
    );
  }
}
