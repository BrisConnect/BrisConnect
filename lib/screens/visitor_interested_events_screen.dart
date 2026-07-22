import 'dart:async';

import 'package:flutter/material.dart';
import 'package:brisconnect/auth/visitor_auth.dart';
import 'package:brisconnect/models/event_item.dart';
import 'package:brisconnect/screens/event_detail_screen.dart';
import 'package:brisconnect/services/admin_event_service.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/utils/error_messages.dart';
import 'package:brisconnect/widgets/inline_status_message.dart';
import 'package:brisconnect/widgets/logo_app_bar_title.dart';

class VisitorInterestedEventsScreen extends StatefulWidget {
  const VisitorInterestedEventsScreen({super.key});

  @override
  State<VisitorInterestedEventsScreen> createState() =>
      _VisitorInterestedEventsScreenState();
}

class _VisitorInterestedEventsScreenState
    extends State<VisitorInterestedEventsScreen> {
  late final AdminEventService _eventService;
  DateTime _loadStartedAt = DateTime.now();
  Timer? _loadingHintTimer;

  @override
  void initState() {
    super.initState();
    _eventService = AdminEventService();
    _loadStartedAt = DateTime.now();
    _loadingHintTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _loadingHintTimer?.cancel();
    super.dispose();
  }

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

  List<EventItem> _filterInterestedEvents(
    List<EventItem> events,
  ) {
    final interestedIds = VisitorAuth.getInterestedEventIds();
    if (interestedIds.isEmpty) {
      return const [];
    }

    return events.where((event) {
      // Only include approved events
      if (!event.isApproved) {
        return false;
      }
      return event.id.isNotEmpty && interestedIds.contains(event.id);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.background,
      appBar: AppBar(
        title: const LogoAppBarTitle('Interested Events'),
      ),
      body: StreamBuilder<List<EventItem>>(
        stream: _eventService.watchAllEvents(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            final elapsed = DateTime.now().difference(_loadStartedAt);
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 12),
                    Text(
                      elapsed.inSeconds >= 2
                          ? 'Loading interested events is taking longer than expected. Retrying...'
                          : 'Loading interested events...',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppPalette.mutedText),
                    ),
                  ],
                ),
              ),
            );
          }

          if (snapshot.hasError) {
            final message = AppErrorMessages.fromException(
              snapshot.error,
              fallback: 'Unable to load interested events right now.',
            );
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: InlineStatusMessage(
                  message: message,
                  type: InlineStatusType.error,
                  actionLabel: 'Retry',
                  onAction: () => setState(() {}),
                ),
              ),
            );
          }

          final interestedEvents = _filterInterestedEvents(snapshot.data ?? const []);
          if (interestedEvents.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No interested events yet. Tap the heart icon on an event to save it for later.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppPalette.mutedText),
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: interestedEvents.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final event = interestedEvents[index];
              final eventId = event.id;
              final title = event.title;
              final dateTime = '${event.date} ${event.time}';
              final location = event.location;

              return Card(
                color: AppPalette.surface,
                child: ListTile(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EventDetailScreen(event: event),
                      ),
                    );
                  },
                  leading: const Icon(
                    Icons.favorite_rounded,
                    color: AppPalette.ochre,
                  ),
                  title: Text(
                    title,
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
                        Text('Date: $dateTime'),
                        Text('Location: $location'),
                      ],
                    ),
                  ),
                  trailing: IconButton(
                    tooltip: 'Remove from interested',
                    icon: const Icon(
                      Icons.favorite_rounded,
                      color: AppPalette.ochre,
                    ),
                    onPressed: () => _toggleInterested(eventId, title),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}