import 'package:flutter/material.dart';
import 'package:brisconnect/models/simple_event.dart';
import 'package:brisconnect/screens/event_map_screen.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/widgets/logo_app_bar_title.dart';

class EventDetailsScreen extends StatelessWidget {
  final SimpleEvent event;

  const EventDetailsScreen({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.background,
      appBar: AppBar(
        title: const LogoAppBarTitle('Event Details'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          color: AppPalette.surface,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppPalette.charcoal,
                  ),
                ),
                const SizedBox(height: 14),
                Text('Date: ${event.date}',
                    style: const TextStyle(color: AppPalette.mutedText)),
                const SizedBox(height: 6),
                Text('Location: ${event.location}',
                    style: const TextStyle(color: AppPalette.deepBlue)),
                const SizedBox(height: 16),
                const Text(
                  'Description',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppPalette.charcoal,
                  ),
                ),
                const SizedBox(height: 6),
                Text(event.description,
                    style: const TextStyle(color: AppPalette.charcoal)),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('View on Map'),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EventMapScreen(
                            events: [event],
                            focusedEvent: event,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppPalette.ochre,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}