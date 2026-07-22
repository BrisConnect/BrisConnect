import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:brisconnect/models/event_item.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/widgets/audio_guide_widget.dart';
import 'package:brisconnect/widgets/crowd_report_widget.dart';
import 'package:brisconnect/widgets/logo_app_bar_title.dart';

class EventDetailScreen extends StatelessWidget {
  final EventItem event;

  const EventDetailScreen({super.key, required this.event});

  String _buildNarrationText() {
    final parts = <String>[
      'Welcome to ${event.title}',
      if (event.date.trim().isNotEmpty || event.time.trim().isNotEmpty)
        'Here\'s when to be there: ${[
          event.date,
          event.time
        ].where((value) => value.trim().isNotEmpty).join(' at ')}',
      if (event.location.trim().isNotEmpty)
        'The event is happening at ${event.location}',
      if (event.description.trim().isNotEmpty)
        'Here\'s the experience in a nutshell. ${event.description}',
    ];
    return '${parts.where((part) => part.trim().isNotEmpty).join('. ')}.';
  }

  @override
  Widget build(BuildContext context) {
    final narrationText = _buildNarrationText();
    return Scaffold(
      backgroundColor: AppPalette.background,
      appBar: AppBar(
        title: const LogoAppBarTitle('Event Details'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          decoration: BoxDecoration(
            color: AppPalette.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border(
              top: BorderSide(
                color: AppPalette.ochre.withValues(alpha: 0.4),
                width: 3,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0x14000000),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: AppPalette.ochre.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (event.imageAsset != null) ...[
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: event.imageAsset!.startsWith('http')
                            ? CachedNetworkImage(
                                imageUrl: event.imageAsset!,
                                width: double.infinity,
                                height: 200,
                                fit: BoxFit.cover,
                              )
                            : Image.asset(
                                event.imageAsset!,
                                width: double.infinity,
                                height: 200,
                                fit: BoxFit.cover,
                              ),
                      ),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          width: double.infinity,
                          height: 200,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                AppPalette.ochre.withValues(alpha: 0.2),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                ],
                Text(
                  event.title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppPalette.deepBlue,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppPalette.surfaceAlt,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppPalette.gold.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.calendar_today,
                              size: 18,
                              color: AppPalette.ochre.withValues(alpha: 0.8)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Date & Time',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppPalette.mutedText,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '${event.date} • ${event.time}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: AppPalette.charcoal,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(Icons.location_on,
                              size: 18,
                              color: AppPalette.gold.withValues(alpha: 0.8)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Location',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppPalette.mutedText,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  event.location,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: AppPalette.charcoal,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 24,
                      decoration: BoxDecoration(
                        color: AppPalette.ochre,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'About this event',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppPalette.charcoal,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  event.description,
                  style: const TextStyle(
                    height: 1.6,
                    fontSize: 15,
                    color: AppPalette.charcoal,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 20),
                // Crowd reporting
                CrowdReportWidget(eventId: event.id),
                if (narrationText.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Container(
                    decoration: BoxDecoration(
                      color: AppPalette.surfaceAlt,
                      borderRadius: BorderRadius.circular(14),
                      border: Border(
                        left: BorderSide(
                          color: AppPalette.gold,
                          width: 4,
                        ),
                      ),
                    ),
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.headphones,
                              color: AppPalette.gold,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'AI Narration',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppPalette.deepBlue,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        AiNarrationWidget(
                          narrationText: narrationText,
                          helperText:
                              'Tap play to hear your AI tour guide walk you through this event.',
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
