import 'package:flutter/material.dart';
import 'package:brisconnect/auth/visitor_auth.dart';
import 'package:brisconnect/screens/event_detail_screen.dart';
import 'package:brisconnect/services/event_repository.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/widgets/logo_app_bar_title.dart';

class VisitorInterestedEventsScreen extends StatefulWidget {
  const VisitorInterestedEventsScreen({super.key});

  @override
  State<VisitorInterestedEventsScreen> createState() =>
      _VisitorInterestedEventsScreenState();
}

class _VisitorInterestedEventsScreenState
    extends State<VisitorInterestedEventsScreen> {
  void _toggleInterested(String eventId, String title) {
    final didUpdate = VisitorAuth.toggleInterestedEvent(eventId);
    if (!didUpdate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in as a Visitor to manage interested events.'),
        ),
      );
      return;
    }

    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$title removed from Interested.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final interestedIds = VisitorAuth.getInterestedEventIds();
    final interestedEvents = EventRepository.getApprovedEvents()
        .where((event) => interestedIds.contains(event.id))
        .toList();

    return Scaffold(
      backgroundColor: AppPalette.background,
      appBar: AppBar(
        title: const LogoAppBarTitle('Interested Events'),
      ),
      body: interestedEvents.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No interested events yet. Tap the heart icon on an event to save it for later.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppPalette.mutedText),
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: interestedEvents.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final event = interestedEvents[index];
                return Card(
                  color: AppPalette.surface,
                  child: ListTile(
                    leading: const Icon(
                      Icons.favorite_rounded,
                      color: AppPalette.ochre,
                    ),
                    title: Text(
                      event.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppPalette.charcoal,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Date: ${event.date}'),
                          Text('Location: ${event.location}'),
                        ],
                      ),
                    ),
                    trailing: IconButton(
                      tooltip: 'Remove from interested',
                      icon: const Icon(
                        Icons.favorite_rounded,
                        color: AppPalette.ochre,
                      ),
                      onPressed: () => _toggleInterested(event.id, event.title),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EventDetailScreen(event: event),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}