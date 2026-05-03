import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:brisconnect/services/approved_attraction_service.dart';
import 'package:brisconnect/services/attraction_detail_service.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/widgets/audio_guide_widget.dart';

class AttractionDetailScreen extends StatelessWidget {
  const AttractionDetailScreen({
    super.key,
    required this.attraction,
    required this.allAttractions,
  });

  final ApprovedAttraction attraction;
  final List<ApprovedAttraction> allAttractions;

  Future<void> _openLink(BuildContext context, String? rawUrl) async {
    if (rawUrl == null || rawUrl.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This information is not available yet.')),
      );
      return;
    }

    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This link is not available right now.')),
      );
      return;
    }

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open the link right now.')),
      );
    }
  }

  Future<void> _openMap(BuildContext context) async {
    final query = Uri.encodeComponent(attraction.location);
    await _openLink(context, 'https://maps.google.com/?q=$query');
  }

  Future<void> _shareAttraction(
      BuildContext context, AttractionDetailData detail) async {
    final shareText = [
      attraction.name,
      detail.address,
      detail.website ?? attraction.webLink ?? '',
      detail.ticketPrice,
    ].where((line) => line.trim().isNotEmpty).join('\n');

    await SharePlus.instance.share(ShareParams(text: shareText));
  }

  Future<void> _copyContact(
      BuildContext context, String label, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied to clipboard.')),
    );
  }

  String _buildNarrationText(AttractionDetailData detail) {
    final parts = <String>[
      'Welcome to ${attraction.name}',
      if ((attraction.category ?? '').trim().isNotEmpty)
        'This attraction is one of Brisbane\'s memorable ${attraction.category} places',
      if (attraction.description.trim().isNotEmpty)
        'At first glance, here\'s what stands out. ${attraction.description.trim()}',
      if (detail.history.trim().isNotEmpty)
        'Its story adds even more meaning. ${detail.history.trim()}',
      if (detail.address.trim().isNotEmpty)
        'You can find it at ${detail.address.trim()}',
      if (detail.visitDuration.trim().isNotEmpty)
        'Most visitors spend about ${detail.visitDuration.trim()} here',
      if (detail.bestTimeToVisit.trim().isNotEmpty)
        'A great time to visit is ${detail.bestTimeToVisit.trim()}',
      if (detail.ticketPrice.trim().isNotEmpty)
        'For planning, entry details are ${detail.ticketPrice.trim()}',
      if (detail.openingHours.isNotEmpty)
        'One of the listed opening times is ${detail.openingHours.first.trim()}',
    ];
    return '${parts.where((part) => part.trim().isNotEmpty).join('. ')}.';
  }

  @override
  Widget build(BuildContext context) {
    final detail =
        AttractionDetailService.getDetail(attraction, allAttractions);
    final narrationText = (attraction.aiNarration ?? '').isNotEmpty
        ? attraction.aiNarration!
        : _buildNarrationText(detail);
    final accessibilityDetails = attraction.accessibilityDetails.isNotEmpty
        ? attraction.accessibilityDetails
        : const <String>['Accessibility details not provided by admin yet.'];

    return ValueListenableBuilder<int>(
      valueListenable: AttractionDetailService.savedVersion,
      builder: (context, _, __) {
        final isSaved = AttractionDetailService.isSaved(attraction.id);
        final isInItinerary =
            AttractionDetailService.isInItinerary(attraction.id);

        return Scaffold(
          backgroundColor: AppPalette.background,
          appBar: AppBar(
            title: Text(attraction.name),
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: [
                _HeroGallery(
                  title: attraction.name,
                  category: attraction.category,
                  media: detail.media,
                ),
                const SizedBox(height: 14),
                _ActionBar(
                  isSaved: isSaved,
                  isInItinerary: isInItinerary,
                  onSave: () {
                    AttractionDetailService.toggleSaved(attraction.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isSaved
                              ? 'Removed from saved attractions.'
                              : 'Saved to attractions.',
                        ),
                      ),
                    );
                  },
                  onShare: () => _shareAttraction(context, detail),
                  onItinerary: () {
                    AttractionDetailService.toggleItinerary(attraction.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isInItinerary
                              ? 'Removed from itinerary.'
                              : 'Added to itinerary.',
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                _DetailSection(
                  title: 'Overview',
                  children: [
                    _SummaryCard(
                      description: attraction.description,
                      history: detail.history,
                      category: attraction.category ?? 'Attraction',
                    ),
                  ],
                ),
                if (narrationText.isNotEmpty)
                  _DetailSection(
                    title: 'Audio Guide',
                    children: const [],
                  ),
                if (narrationText.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: AiNarrationWidget(
                      narrationText: narrationText,
                      helperText:
                          'Tap play to hear your AI tour guide introduce this attraction and its story.',
                    ),
                  ),
                _DetailSection(
                  title: 'Location & Planning',
                  children: [
                    _MapCard(
                      attraction: attraction,
                      address: detail.address,
                      visitDuration: detail.visitDuration,
                      bestTimeToVisit: detail.bestTimeToVisit,
                      onOpenMap: () => _openMap(context),
                    ),
                  ],
                ),
                _DetailSection(
                  title: 'Hours & Entry',
                  children: [
                    _InfoCard(
                      title: 'Opening Hours',
                      lines: detail.openingHours,
                    ),
                    _InfoCard(
                      title: 'Special Schedule',
                      lines: [detail.specialSchedule],
                    ),
                    _InfoCard(
                      title: 'Entry Requirements',
                      lines: [detail.entryRequirements],
                    ),
                  ],
                ),
                _DetailSection(
                  title: 'Tickets & Booking',
                  children: [
                    _TicketCard(
                      ticketPrice: detail.ticketPrice,
                      bookingLabel: detail.bookingLabel,
                      bookingUrl: detail.bookingUrl,
                      onOpenBooking: () =>
                          _openLink(context, detail.bookingUrl),
                    ),
                  ],
                ),
                _DetailSection(
                  title: 'Media & Tours',
                  children: [
                    _MediaStrip(
                      items: detail.media,
                      onTapMedia: (url) => _openLink(context, url),
                    ),
                    _OptionalLinkCard(
                      title: 'Virtual Tour / Official Media',
                      value: detail.virtualTourUrl,
                      actionLabel: 'Open',
                      onTap: () => _openLink(context, detail.virtualTourUrl),
                    ),
                  ],
                ),
                _DetailSection(
                  title: 'Ratings & Reviews',
                  children: [
                    _RatingsCard(
                      rating: detail.rating,
                      reviewCount: detail.reviewCount,
                      breakdown: detail.ratingBreakdown,
                      reviews: detail.reviews,
                    ),
                  ],
                ),
                _DetailSection(
                  title: 'Contact',
                  children: [
                    _ContactCard(
                      phone: detail.phone,
                      email: detail.email,
                      website: detail.website ?? attraction.webLink,
                      onPhoneTap: detail.phone == null
                          ? null
                          : () => _copyContact(
                              context, 'Phone number', detail.phone!),
                      onEmailTap: detail.email == null
                          ? null
                          : () => _copyContact(context, 'Email', detail.email!),
                      onWebsiteTap: () => _openLink(
                        context,
                        detail.website ?? attraction.webLink,
                      ),
                    ),
                  ],
                ),
                _DetailSection(
                  title: 'Facilities & Accessibility',
                  children: [
                    _ChipCollectionCard(
                      title: 'Facilities',
                      items: detail.facilities,
                    ),
                    _ChipCollectionCard(
                      title: 'Amenities',
                      items: detail.amenities,
                    ),
                    _ChipCollectionCard(
                      title: 'Accessibility',
                      items: accessibilityDetails,
                    ),
                  ],
                ),
                _DetailSection(
                  title: 'Live Updates',
                  children: [
                    _LiveUpdateCard(update: detail.liveUpdate),
                  ],
                ),
                _DetailSection(
                  title: 'Nearby & Recommendations',
                  children: [
                    _InfoCard(
                      title: 'Nearby Attractions',
                      lines: detail.nearbyAttractions,
                    ),
                    _InfoCard(
                      title: 'Nearby Services',
                      lines: detail.nearbyServices,
                    ),
                    _InfoCard(
                      title: 'Personalised Suggestions',
                      lines: detail.personalisedSuggestions,
                    ),
                  ],
                ),
                _DetailSection(
                  title: 'Languages & Audio',
                  children: [
                    _ChipCollectionCard(
                      title: 'Languages',
                      items: detail.languages,
                    ),
                    _ChipCollectionCard(
                      title: 'Audio Features',
                      items: detail.audioFeatures,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppPalette.charcoal,
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _HeroGallery extends StatelessWidget {
  const _HeroGallery({
    required this.title,
    required this.category,
    required this.media,
  });

  final String title;
  final String? category;
  final List<AttractionMediaItem> media;

  @override
  Widget build(BuildContext context) {
    final gallery = media.isEmpty
        ? const <AttractionMediaItem>[
            AttractionMediaItem(
              type: 'photo',
              label: 'Attraction View',
              url:
                  'https://images.unsplash.com/photo-1472653431158-6364773b2a56?auto=format&fit=crop&w=1200&q=80',
            ),
          ]
        : media;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 220,
          child: PageView.builder(
            itemCount: gallery.length,
            itemBuilder: (context, index) {
              final item = gallery[index];
              return ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: item.url,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        color: AppPalette.surfaceAlt,
                        alignment: Alignment.center,
                        child: const Icon(Icons.image_not_supported_rounded),
                      ),
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.08),
                            Colors.black.withValues(alpha: 0.58),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 16,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if ((category ?? '').trim().isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppPalette.ochre,
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Text(
                                category!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          const SizedBox(height: 10),
                          Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.label,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.isSaved,
    required this.isInItinerary,
    required this.onSave,
    required this.onShare,
    required this.onItinerary,
  });

  final bool isSaved;
  final bool isInItinerary;
  final VoidCallback onSave;
  final VoidCallback onShare;
  final VoidCallback onItinerary;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: onSave,
            icon: Icon(isSaved
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded),
            label: Text(isSaved ? 'Saved' : 'Save'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onShare,
            icon: const Icon(Icons.share_rounded),
            label: const Text('Share'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onItinerary,
            icon: Icon(isInItinerary
                ? Icons.checklist_rounded
                : Icons.playlist_add_rounded),
            label: Text(isInItinerary ? 'In Plan' : 'Itinerary'),
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.description,
    required this.history,
    required this.category,
  });

  final String description;
  final String history;
  final String category;

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(category,
              style: const TextStyle(
                  color: AppPalette.deepBlue, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Text(description,
              style: const TextStyle(color: AppPalette.charcoal, height: 1.5)),
          const SizedBox(height: 12),
          const Text('History',
              style: TextStyle(
                  fontWeight: FontWeight.w800, color: AppPalette.charcoal)),
          const SizedBox(height: 6),
          Text(history,
              style: const TextStyle(color: AppPalette.mutedText, height: 1.5)),
        ],
      ),
    );
  }
}

class _MapCard extends StatelessWidget {
  const _MapCard({
    required this.attraction,
    required this.address,
    required this.visitDuration,
    required this.bestTimeToVisit,
    required this.onOpenMap,
  });

  final ApprovedAttraction attraction;
  final String address;
  final String visitDuration;
  final String bestTimeToVisit;
  final VoidCallback onOpenMap;

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 180,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: LatLng(attraction.latitude, attraction.longitude),
                  zoom: 14.5,
                ),
                scrollGesturesEnabled: false,
                zoomGesturesEnabled: false,
                tiltGesturesEnabled: false,
                rotateGesturesEnabled: false,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                markers: {
                  Marker(
                    markerId: const MarkerId('attraction'),
                    position: LatLng(attraction.latitude, attraction.longitude),
                    infoWindow: InfoWindow(title: attraction.name),
                  ),
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(address,
              style: const TextStyle(
                  color: AppPalette.charcoal, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('Estimated visit: $visitDuration',
              style: const TextStyle(color: AppPalette.mutedText)),
          const SizedBox(height: 4),
          Text('Best time to visit: $bestTimeToVisit',
              style: const TextStyle(color: AppPalette.mutedText)),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: onOpenMap,
              icon: const Icon(Icons.map_rounded),
              label: const Text('Open in Maps'),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.lines});

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final visible =
        lines.where((line) => line.trim().isNotEmpty).toList(growable: false);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _CardShell(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.w800, color: AppPalette.charcoal)),
            const SizedBox(height: 8),
            if (visible.isEmpty)
              const Text('Information not available yet.',
                  style: TextStyle(color: AppPalette.mutedText))
            else
              ...visible.map(
                (line) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Icon(Icons.circle,
                            size: 6, color: AppPalette.deepBlue),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(line,
                              style: const TextStyle(
                                  color: AppPalette.mutedText, height: 1.4))),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({
    required this.ticketPrice,
    required this.bookingLabel,
    required this.bookingUrl,
    required this.onOpenBooking,
  });

  final String ticketPrice;
  final String bookingLabel;
  final String? bookingUrl;
  final VoidCallback onOpenBooking;

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(ticketPrice,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppPalette.charcoal)),
          const SizedBox(height: 8),
          const Text(
              'Booking options and ticket availability can vary by operator schedule.',
              style: TextStyle(color: AppPalette.mutedText)),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: bookingUrl == null ? null : onOpenBooking,
            icon: const Icon(Icons.confirmation_num_outlined),
            label: Text(bookingLabel),
          ),
        ],
      ),
    );
  }
}

class _MediaStrip extends StatelessWidget {
  const _MediaStrip({required this.items, required this.onTapMedia});

  final List<AttractionMediaItem> items;
  final ValueChanged<String> onTapMedia;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _InfoCard(
          title: 'Media', lines: ['No photos or videos available yet.']);
    }

    return SizedBox(
      height: 140,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final item = items[index];
          return GestureDetector(
            onTap: () => onTapMedia(item.url),
            child: Container(
              width: 200,
              decoration: BoxDecoration(
                color: AppPalette.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppPalette.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(18)),
                      child: CachedNetworkImage(
                        imageUrl: item.url,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          color: AppPalette.surfaceAlt,
                          alignment: Alignment.center,
                          child: const Icon(Icons.image_not_supported_rounded),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppPalette.charcoal)),
                        const SizedBox(height: 2),
                        Text(item.type.toUpperCase(),
                            style: const TextStyle(
                                fontSize: 11, color: AppPalette.mutedText)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _OptionalLinkCard extends StatelessWidget {
  const _OptionalLinkCard({
    required this.title,
    required this.value,
    required this.actionLabel,
    required this.onTap,
  });

  final String title;
  final String? value;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: _CardShell(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppPalette.charcoal)),
                  const SizedBox(height: 4),
                  Text(
                    value == null
                        ? 'Not available yet.'
                        : 'Open additional tour or official media experience.',
                    style: const TextStyle(color: AppPalette.mutedText),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton(
                onPressed: value == null ? null : onTap,
                child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}

class _RatingsCard extends StatelessWidget {
  const _RatingsCard({
    required this.rating,
    required this.reviewCount,
    required this.breakdown,
    required this.reviews,
  });

  final double rating;
  final int reviewCount;
  final Map<String, int> breakdown;
  final List<AttractionReviewItem> reviews;

  @override
  Widget build(BuildContext context) {
    final total = breakdown.values.fold<int>(0, (sum, value) => sum + value);
    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(rating.toStringAsFixed(1),
                      style: const TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          color: AppPalette.charcoal)),
                  const SizedBox(height: 4),
                  Row(
                    children: List.generate(
                        5,
                        (index) => Icon(
                            index < rating.round()
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            size: 18,
                            color: AppPalette.gold)),
                  ),
                  const SizedBox(height: 4),
                  Text('$reviewCount reviews',
                      style: const TextStyle(color: AppPalette.mutedText)),
                ],
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  children: ['5', '4', '3', '2', '1'].map((star) {
                    final count = breakdown[star] ?? 0;
                    final fraction = total == 0 ? 0.0 : count / total;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          SizedBox(
                              width: 16,
                              child: Text(star,
                                  style: const TextStyle(
                                      color: AppPalette.mutedText))),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(99),
                              child: LinearProgressIndicator(
                                value: fraction,
                                minHeight: 8,
                                backgroundColor: AppPalette.surfaceAlt,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                    AppPalette.ochre),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                              width: 34,
                              child: Text('$count',
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                      color: AppPalette.mutedText))),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...reviews.map(
            (review) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppPalette.surfaceAlt,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                            child: Text(review.author,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppPalette.charcoal))),
                        Text(review.when,
                            style: const TextStyle(
                                fontSize: 12, color: AppPalette.mutedText)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: List.generate(
                          5,
                          (index) => Icon(
                              index < review.rating.round()
                                  ? Icons.star_rounded
                                  : Icons.star_border_rounded,
                              size: 16,
                              color: AppPalette.gold)),
                    ),
                    const SizedBox(height: 8),
                    Text(review.comment,
                        style: const TextStyle(
                            color: AppPalette.mutedText, height: 1.4)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({
    required this.phone,
    required this.email,
    required this.website,
    this.onPhoneTap,
    this.onEmailTap,
    required this.onWebsiteTap,
  });

  final String? phone;
  final String? email;
  final String? website;
  final VoidCallback? onPhoneTap;
  final VoidCallback? onEmailTap;
  final VoidCallback onWebsiteTap;

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      child: Column(
        children: [
          _ContactRow(label: 'Phone', value: phone, onTap: onPhoneTap),
          _ContactRow(label: 'Email', value: email, onTap: onEmailTap),
          _ContactRow(
              label: 'Website',
              value: website,
              onTap: website == null ? null : onWebsiteTap),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.label, required this.value, this.onTap});

  final String label;
  final String? value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
              width: 72,
              child: Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppPalette.charcoal))),
          Expanded(
            child: Text(value ?? 'Not available',
                style: const TextStyle(color: AppPalette.mutedText)),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
              onPressed: onTap, child: Text(value == null ? 'N/A' : 'Open')),
        ],
      ),
    );
  }
}

class _ChipCollectionCard extends StatelessWidget {
  const _ChipCollectionCard({required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _CardShell(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.w800, color: AppPalette.charcoal)),
            const SizedBox(height: 10),
            if (items.isEmpty)
              const Text('Information not available yet.',
                  style: TextStyle(color: AppPalette.mutedText))
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: items
                    .map(
                      (item) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppPalette.surfaceAlt,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: AppPalette.border),
                        ),
                        child: Text(item,
                            style: const TextStyle(
                                color: AppPalette.deepBlue,
                                fontWeight: FontWeight.w600)),
                      ),
                    )
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }
}

class _LiveUpdateCard extends StatelessWidget {
  const _LiveUpdateCard({required this.update});

  final AttractionLiveUpdate update;

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LiveLine(label: 'Crowd level', value: update.crowdLevel),
          _LiveLine(label: 'Closures', value: update.closureStatus),
          _LiveLine(label: 'Events', value: update.eventNote),
          _LiveLine(label: 'Weather', value: update.weatherImpact),
          const SizedBox(height: 8),
          Text(update.lastUpdated,
              style:
                  const TextStyle(color: AppPalette.mutedText, fontSize: 12)),
        ],
      ),
    );
  }
}

class _LiveLine extends StatelessWidget {
  const _LiveLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 90,
              child: Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppPalette.charcoal))),
          Expanded(
              child: Text(value,
                  style: const TextStyle(color: AppPalette.mutedText))),
        ],
      ),
    );
  }
}

class _CardShell extends StatelessWidget {
  const _CardShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppPalette.border),
        boxShadow: const [
          BoxShadow(
            color: AppPalette.cardShadow,
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}
