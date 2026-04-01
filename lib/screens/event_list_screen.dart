import 'package:flutter/material.dart';
import 'package:brisconnect/models/simple_event.dart';
import 'package:brisconnect/screens/event_details_screen.dart';
import 'package:brisconnect/screens/event_map_screen.dart';
import 'package:brisconnect/services/firestore_service.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/widgets/logo_app_bar_title.dart';

class EventListScreen extends StatefulWidget {
  const EventListScreen({super.key});

  @override
  State<EventListScreen> createState() => _EventListScreenState();
}

class _EventListScreenState extends State<EventListScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  SimpleEvent _eventFromMap(Map<String, dynamic> map) {
    final status = (map['reviewStatus'] as String? ?? '').trim().toLowerCase();
    final isApproved = status != 'pending' && status != 'rejected';

    return SimpleEvent(
      title: ((map['title'] as String?) ?? 'Untitled Event').trim(),
      date: ((map['date'] as String?) ?? 'Date TBA').trim(),
      location: ((map['location'] as String?) ?? 'Location TBA').trim(),
      description: ((map['description'] as String?) ?? '').trim(),
      isApproved: isApproved,
      lat: _toDouble(map['latitude']) ?? -27.4698,
      lng: _toDouble(map['longitude']) ?? 153.0251,
    );
  }

  double? _toDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.background,
      appBar: AppBar(
        title: const LogoAppBarTitle('Events in Brisbane'),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _firestoreService.getEvents(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text('Unable to load events right now.'));
          }

          final approvedEvents = (snapshot.data ?? const <Map<String, dynamic>>[])
              .map(_eventFromMap)
              .where((event) => event.isApproved)
              .toList(growable: false);

          if (approvedEvents.isEmpty) {
            return const Center(child: Text('No events available'));
          }

          return ListView.builder(
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
          );
        },
      ),
      floatingActionButton: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _firestoreService.getEvents(),
        builder: (context, snapshot) {
          final approvedEvents = (snapshot.data ?? const <Map<String, dynamic>>[])
              .map(_eventFromMap)
              .where((event) => event.isApproved)
              .toList(growable: false);

          if (approvedEvents.isEmpty) {
            return const SizedBox.shrink();
          }

          return FloatingActionButton.extended(
            icon: const Icon(Icons.map_outlined),
            label: const Text('Map'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EventMapScreen(events: approvedEvents),
                ),
              );
            },
          );
        },
      ),
    );
  }
}