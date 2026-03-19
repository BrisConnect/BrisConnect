import 'package:flutter/material.dart';
import 'package:brisconnect/models/simple_event.dart';
import 'package:brisconnect/screens/event_details_screen.dart';
import 'package:brisconnect/screens/event_map_screen.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/widgets/logo_app_bar_title.dart';

class EventListScreen extends StatelessWidget {
  const EventListScreen({super.key});

  static const List<SimpleEvent> allEvents = [
    SimpleEvent(
      title: 'Brisbane Multicultural Festival',
      date: '22 Mar 2026',
      location: 'South Bank Parklands',
      description:
          'A city-wide celebration of food, music, and performances from diverse cultures.',
      isApproved: true,
      lat: -27.4748,
      lng: 153.0234,
    ),
    SimpleEvent(
      title: 'First Nations Storytelling Evening',
      date: '27 Apr 2026',
      location: 'State Library of Queensland',
      description:
          'Guided storytelling and talks showcasing local First Nations heritage and history.',
      isApproved: true,
      lat: -27.4736,
      lng: 153.0219,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final approvedEvents =
        allEvents.where((event) => event.isApproved).toList();

    return Scaffold(
      backgroundColor: AppPalette.background,
      appBar: AppBar(
        title: const LogoAppBarTitle('Events in Brisbane'),
        actions: [
          IconButton(
            icon: const Icon(Icons.map_outlined),
            tooltip: 'View All on Map',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EventMapScreen(events: approvedEvents),
                ),
              );
            },
          ),
        ],
      ),
      body: approvedEvents.isEmpty
          ? const Center(
              child: Text('No events available'),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: approvedEvents.length,
              itemBuilder: (context, index) {
                final event = approvedEvents[index];
                return Card(
                  color: AppPalette.surface,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EventDetailsScreen(event: event),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppPalette.charcoal,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            event.date,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppPalette.mutedText,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            event.location,
                            style: const TextStyle(color: AppPalette.deepBlue),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}