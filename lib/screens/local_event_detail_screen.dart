import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:brisconnect/models/event_item.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/widgets/audio_guide_widget.dart';
import 'package:brisconnect/widgets/logo_app_bar_title.dart';

class LocalEventDetailScreen extends StatelessWidget {
  final EventItem event;

  const LocalEventDetailScreen({
    super.key,
    required this.event,
  });

  String _statusText(EventReviewStatus status) {
    switch (status) {
      case EventReviewStatus.approved:
        return 'Approved';
      case EventReviewStatus.pending:
        return 'Pending Approval';
      case EventReviewStatus.rejected:
        return 'Rejected';
    }
  }

  Color _statusColor(EventReviewStatus status) {
    switch (status) {
      case EventReviewStatus.approved:
        return AppPalette.deepBlue;
      case EventReviewStatus.pending:
        return AppPalette.gold;
      case EventReviewStatus.rejected:
        return AppPalette.ochre;
    }
  }

  String _buildNarrationText() {
    final parts = <String>[
      'Welcome to ${event.title}',
      if (event.date.trim().isNotEmpty || event.time.trim().isNotEmpty)
        'Here is when it happens: ${[
          event.date,
          event.time,
        ].where((value) => value.trim().isNotEmpty).join(' at ')}',
      if (event.location.trim().isNotEmpty)
        'The event location is ${event.location}',
      if (event.description.trim().isNotEmpty)
        'Event overview: ${event.description}',
    ];
    return '${parts.where((part) => part.trim().isNotEmpty).join('. ')}.';
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(event.reviewStatus);
    final narrationText = _buildNarrationText();

    return Scaffold(
      backgroundColor: AppPalette.background,
      appBar: AppBar(
        title: const LogoAppBarTitle('Event Details'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: AppPalette.surface,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          event.title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppPalette.charcoal,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          _statusText(event.reviewStatus),
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (event.imageAsset != null &&
                      event.imageAsset!.startsWith('http')) ...[                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: event.imageAsset!,
                        width: double.infinity,
                        height: 200,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          height: 200,
                          color: AppPalette.border.withValues(alpha: 0.3),
                          child: const Center(
                              child: CircularProgressIndicator()),
                        ),
                        errorWidget: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  _DetailRow(label: 'Date', value: event.date),
                  _DetailRow(label: 'Time', value: event.time),
                  _DetailRow(label: 'Location', value: event.location),
                  if (event.location.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final url = Uri.parse(
                            'https://maps.google.com/?q=${Uri.encodeComponent(event.location.trim())}',
                          );
                          await launchUrl(url, mode: LaunchMode.inAppBrowserView);
                        },
                        icon: const Icon(Icons.map_rounded, size: 18),
                        label: const Text('View on Map'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppPalette.deepBlue,
                          side: const BorderSide(color: AppPalette.deepBlue),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  const Text(
                    'Description',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppPalette.charcoal,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    event.description,
                    style: const TextStyle(
                      color: AppPalette.charcoal,
                      height: 1.35,
                    ),
                  ),
                  if (narrationText.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    const Text(
                      'AI Narration',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppPalette.charcoal,
                      ),
                    ),
                    const SizedBox(height: 8),
                    AiNarrationWidget(
                      narrationText: narrationText,
                      helperText:
                          'Tap play to hear your AI tour guide walk you through this event.',
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppPalette.charcoal,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: AppPalette.charcoal),
            ),
          ),
        ],
      ),
    );
  }
}
