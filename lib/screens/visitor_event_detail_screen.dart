import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:brisconnect/auth/visitor_auth.dart';
import 'package:brisconnect/services/share/content_share_service.dart';
import 'package:brisconnect/services/visitor_notification_service.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/utils/venue_image_fallback.dart';
import 'package:brisconnect/widgets/audio_guide_widget.dart';
import 'package:brisconnect/widgets/crowd_report_widget.dart';
import 'package:brisconnect/widgets/logo_app_bar_title.dart';
import 'package:brisconnect/widgets/share_bottom_sheet.dart';

/// Full-page event detail screen shown when a Visitor taps an event card.
/// Displays hero image, cultural background description, optional AI narration,
/// and navigation actions (map, website, share, save/interested).
class VisitorEventDetailScreen extends StatefulWidget {
  /// The raw Firestore discover-item map for the event.
  final Map<String, dynamic> event;
  final ContentShareService? shareService;

  const VisitorEventDetailScreen({
    super.key,
    required this.event,
    this.shareService,
  });

  @override
  State<VisitorEventDetailScreen> createState() =>
      _VisitorEventDetailScreenState();
}

class _VisitorEventDetailScreenState extends State<VisitorEventDetailScreen> {
  late final ContentShareService _shareService =
      widget.shareService ?? ContentShareService();

  String get _fallbackImage => VenueImageFallback.forItem(widget.event);

  bool get _isSaved {
    final id = (widget.event['id'] as String? ?? '').trim();
    return id.isNotEmpty && VisitorAuth.isInterestedInEvent(id);
  }

  Future<void> _toggleInterested() async {
    final id = (widget.event['id'] as String? ?? '').trim();
    if (id.isEmpty) return;

    final didUpdate = VisitorAuth.toggleInterestedEvent(id);
    if (!didUpdate) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please log in as a Visitor to save events.')),
      );
      return;
    }

    final isNowInterested = VisitorAuth.isInterestedInEvent(id);
    if (isNowInterested && VisitorAuth.areEventRemindersEnabled()) {
      final svc = VisitorNotificationService();
      await svc
          .scheduleNotificationForInterestedEvent(
            eventTitle: widget.event['title'] as String? ?? 'Event',
            eventDatetime: widget.event['dateTime'] as String? ?? 'Date TBA',
            eventLocation:
                widget.event['location'] as String? ?? 'Location TBA',
            eventId: id,
            userEmail: VisitorAuth.currentVisitor?.email ?? '',
            reminderTiming: VisitorAuth.getReminderTiming(),
          )
          .catchError(
            (Object e) => debugPrint('[EventDetail] Notification error: $e'),
          );
    } else if (!isNowInterested) {
      final svc = VisitorNotificationService();
      await svc
          .cancelNotificationForInterestedEvent(
            eventTitle: widget.event['title'] as String? ?? 'Event',
            eventDatetime: widget.event['dateTime'] as String? ?? 'Date TBA',
            eventId: id,
            userEmail: VisitorAuth.currentVisitor?.email ?? '',
          )
          .catchError(
            (Object e) =>
                debugPrint('[EventDetail] Notification cancel error: $e'),
          );
    }

    if (mounted) setState(() {});
  }

  Future<void> _openLink(String? rawUrl) async {
    if (rawUrl == null || rawUrl.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No link available for this event.')),
      );
      return;
    }
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open this link right now.')),
      );
    }
  }

  Future<void> _openMap() async {
    final mapQuery = (widget.event['mapQuery'] as String? ?? '').trim();
    final location = (widget.event['location'] as String? ?? '').trim();
    final q = mapQuery.isNotEmpty ? mapQuery : location;
    if (q.isEmpty) return;
    await _openLink('https://maps.google.com/?q=${Uri.encodeComponent(q)}');
  }

  Future<void> _share() async {
    final id = (widget.event['id'] as String? ?? '').trim();
    final title = (widget.event['title'] as String? ?? 'Event').trim();
    final dateTime = (widget.event['dateTime'] as String? ?? '').trim();
    final location = (widget.event['location'] as String? ?? '').trim();
    final description =
        (widget.event['description'] as String? ?? '').trim();

    if (id.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This event cannot be shared right now.')),
      );
      return;
    }

    await showShareBottomSheet(
      context: context,
      shareService: _shareService,
      type: ShareContentType.event,
      id: id,
      title: title,
      description: description,
      location: location,
      dateTime: dateTime,
    );
  }

  String _buildNarrationText({
    required String badge,
    required String title,
    required String dateTime,
    required String location,
    required String price,
    required String description,
    required String culturalBackground,
    required String aiAudio,
  }) {
    if (aiAudio.isNotEmpty) return aiAudio;
    final narrative = <String>[];

    if (title.isNotEmpty) {
      final opening = badge.isNotEmpty
          ? 'Welcome to $title, one of Brisbane\'s standout $badge experiences'
          : 'Welcome to $title';
      narrative.add(opening);
    }

    final timeLocation = <String>[];
    if (dateTime.isNotEmpty) timeLocation.add('happening on $dateTime');
    if (location.isNotEmpty) timeLocation.add('at $location');
    if (timeLocation.isNotEmpty) {
      narrative.add('You can catch it ${timeLocation.join(', ')}');
    }

    if (description.isNotEmpty) {
      narrative.add('Here\'s what makes it worth your time. $description');
    }

    if (culturalBackground.isNotEmpty) {
      narrative
          .add('There\'s also deeper context behind it. $culturalBackground');
    }

    if (price.isNotEmpty) {
      final priceText = price.toLowerCase().contains('free')
          ? 'The best part is that this event is completely free'
          : 'Plan ahead for entry priced at $price';
      narrative.add(priceText);
    }

    return '${narrative.join('. ')}.';
  }

  @override
  Widget build(BuildContext context) {
    final title = (widget.event['title'] as String? ?? 'Event').trim();
    final badge = (widget.event['badge'] as String? ?? '').trim();
    final imageUrl = (widget.event['imageUrl'] as String? ?? '').trim();
    final dateTime = (widget.event['dateTime'] as String? ?? '').trim();
    final location = (widget.event['location'] as String? ?? '').trim();
    final price = (widget.event['price'] as String? ?? '').trim();
    final description = (widget.event['description'] as String? ?? '').trim();
    final culturalBackground =
        (widget.event['culturalBackground'] as String? ?? '').trim();
    final aiAudio = (widget.event['aiAudio'] as String? ?? '').trim();
    final aiNarration =
        (widget.event['aiNarration'] as String? ?? '').trim();
    final narrationText = _buildNarrationText(
      badge: badge,
      title: title,
      dateTime: dateTime,
      location: location,
      price: price,
      description: description,
      culturalBackground: culturalBackground,
      aiAudio: aiAudio.isNotEmpty ? aiAudio : aiNarration,
    );
    final webLink = (widget.event['webLink'] as String? ?? '').trim();
    final hasMapQuery =
        (widget.event['mapQuery'] as String? ?? '').trim().isNotEmpty ||
            location.isNotEmpty;

    final effective = imageUrl.isNotEmpty ? imageUrl : _fallbackImage;

    return ValueListenableBuilder<int>(
      valueListenable: VisitorAuth.interestedEventsVersion,
      builder: (context, _, __) {
        return Scaffold(
          backgroundColor: AppPalette.background,
          appBar: AppBar(
            title: const LogoAppBarTitle('Event Details'),
            actions: [
              IconButton(
                tooltip: _isSaved ? 'Remove from saved' : 'Save event',
                onPressed: _toggleInterested,
                icon: Icon(
                  _isSaved
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: _isSaved ? AppPalette.ochre : AppPalette.charcoal,
                ),
              ),
              IconButton(
                tooltip: 'Share',
                onPressed: _share,
                icon: const Icon(Icons.share_rounded),
              ),
            ],
          ),
          body: ListView(
            children: [
              // ── Hero image ──────────────────────────────────────────────
              CachedNetworkImage(
                imageUrl: effective,
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

              // ── Content ─────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Badge
                    if (badge.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppPalette.ochre,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          badge,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),

                    // Title
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

                    // Date / time
                    if (dateTime.isNotEmpty) ...[
                      _InfoRow(
                        icon: Icons.calendar_today_rounded,
                        iconColor: AppPalette.deepBlue,
                        text: dateTime,
                      ),
                      const SizedBox(height: 8),
                    ],

                    // Location
                    if (location.isNotEmpty) ...[
                      _InfoRow(
                        icon: Icons.place_rounded,
                        iconColor: AppPalette.ochre,
                        text: location,
                      ),
                      const SizedBox(height: 8),
                    ],

                    // Price chip
                    if (price.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      _PriceChip(price: price),
                    ],

                    const SizedBox(height: 18),
                    const Divider(color: AppPalette.border),
                    const SizedBox(height: 18),

                    // About this event
                    if (description.isNotEmpty) ...[
                      const _SectionHeader(title: 'About this Event'),
                      const SizedBox(height: 8),
                      Text(
                        description,
                        style: const TextStyle(
                          color: AppPalette.charcoal,
                          height: 1.55,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 22),
                    ],

                    // Crowd level reporting
                    if ((widget.event['id'] as String? ?? '').isNotEmpty) ...[
                      CrowdReportWidget(
                        eventId: widget.event['id'] as String,
                      ),
                      const SizedBox(height: 22),
                    ],

                    // Cultural background
                    if (culturalBackground.isNotEmpty) ...[
                      const _SectionHeader(title: 'Cultural Background'),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppPalette.surfaceAlt,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppPalette.border),
                        ),
                        child: Text(
                          culturalBackground,
                          style: const TextStyle(
                            color: AppPalette.charcoal,
                            height: 1.55,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                    ],

                    // AI tour guide narration
                    if (narrationText.isNotEmpty) ...[
                      _SectionHeader(
                        title: 'AI Tour Guide',
                      ),
                      const SizedBox(height: 10),
                      AiNarrationWidget(
                        narrationText: narrationText,
                        helperText:
                            'Tap play to hear your personal AI tour guide walk you through this event.',
                      ),
                      const SizedBox(height: 22),
                    ],

                    const Divider(color: AppPalette.border),
                    const SizedBox(height: 16),

                    // Action row: map + website
                    Row(
                      children: [
                        if (hasMapQuery)
                          Expanded(
                            child: _ActionButton(
                              icon: Icons.map_rounded,
                              label: 'View on Map',
                              backgroundColor: AppPalette.deepBlue,
                              onPressed: _openMap,
                            ),
                          ),
                        if (hasMapQuery && webLink.isNotEmpty)
                          const SizedBox(width: 10),
                        if (webLink.isNotEmpty)
                          Expanded(
                            child: _ActionButton(
                              icon: Icons.open_in_browser_rounded,
                              label: 'Website',
                              backgroundColor: AppPalette.deepBlue,
                              onPressed: () => _openLink(webLink),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Save / interested CTA
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: Icon(
                          _isSaved
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                        ),
                        label: Text(
                          _isSaved
                              ? 'Saved to My Events'
                              : 'Save & Get Reminder',
                        ),
                        onPressed: _toggleInterested,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isSaved
                              ? AppPalette.surfaceAlt
                              : AppPalette.ochre,
                          foregroundColor:
                              _isSaved ? AppPalette.charcoal : Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Private helper widgets ────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  const _InfoRow({
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

class _PriceChip extends StatelessWidget {
  const _PriceChip({required this.price});
  final String price;

  bool get _isFree => price.toLowerCase().contains('free');

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _isFree ? const Color(0xFFEAF7EE) : AppPalette.surfaceAlt,
        border: Border.all(
          color: _isFree ? const Color(0xFF4CAF50) : AppPalette.border,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        price,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: _isFree ? const Color(0xFF2E7D32) : AppPalette.charcoal,
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
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

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.onPressed,
  });
  final IconData icon;
  final String label;
  final Color backgroundColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      icon: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
