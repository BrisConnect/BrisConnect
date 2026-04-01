import 'package:flutter/material.dart';
import 'package:brisconnect/models/event_item.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/widgets/audio_guide_widget.dart';
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
        child: Card(
          color: AppPalette.surface,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (event.imageAsset != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      event.imageAsset!,
                      width: double.infinity,
                      height: 180,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                Text(
                  event.title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppPalette.charcoal,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Icon(Icons.calendar_today,
                        size: 18, color: AppPalette.deepBlue),
                    const SizedBox(width: 8),
                    Text('Date & Time: ${event.date} • ${event.time}'),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.place, size: 18, color: AppPalette.ochre),
                    const SizedBox(width: 8),
                    Expanded(child: Text(event.location)),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'About this event',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppPalette.charcoal,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  event.description,
                  style: const TextStyle(
                    height: 1.4,
                    color: AppPalette.charcoal,
                  ),
                ),
                if (narrationText.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  const Text(
                    'Audio Guide',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppPalette.charcoal,
                    ),
                  ),
                  const SizedBox(height: 8),
                  AudioGuideWidget(
                    narrationText: narrationText,
                    helperText:
                        'Listen to a short guided intro to the event, timing, and location.',
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
