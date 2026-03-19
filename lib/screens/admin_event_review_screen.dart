import 'package:flutter/material.dart';
import 'package:brisconnect/models/event_item.dart';
import 'package:brisconnect/services/event_repository.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/widgets/logo_app_bar_title.dart';

class AdminEventReviewScreen extends StatefulWidget {
  const AdminEventReviewScreen({super.key});

  @override
  State<AdminEventReviewScreen> createState() => _AdminEventReviewScreenState();
}

class _AdminEventReviewScreenState extends State<AdminEventReviewScreen> {
  void _approveEvent(EventItem event) {
    EventRepository.approveEvent(event);
    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${event.title} approved.')),
    );
  }

  void _rejectEvent(EventItem event) {
    EventRepository.rejectEvent(event);
    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${event.title} rejected.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendingEvents = EventRepository.getPendingEvents();
    final reviewedEvents = EventRepository.getReviewedEvents()
        .where((event) => !event.isPending)
        .toList()
        .reversed
        .toList();

    return Scaffold(
      backgroundColor: AppPalette.background,
      appBar: AppBar(
        title: const LogoAppBarTitle('Event Reviews'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Pending Events',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppPalette.charcoal,
            ),
          ),
          const SizedBox(height: 12),
          if (pendingEvents.isEmpty)
            const Card(
              color: AppPalette.surface,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No pending events to review.'),
              ),
            )
          else
            ...pendingEvents.map(
              (event) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _PendingEventCard(
                  event: event,
                  onApprove: () => _approveEvent(event),
                  onReject: () => _rejectEvent(event),
                ),
              ),
            ),
          const SizedBox(height: 10),
          const Text(
            'Review History',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppPalette.charcoal,
            ),
          ),
          const SizedBox(height: 12),
          if (reviewedEvents.isEmpty)
            const Card(
              color: AppPalette.surface,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No reviewed events yet.'),
              ),
            )
          else
            ...reviewedEvents.map(
              (event) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ReviewedEventCard(event: event),
              ),
            ),
        ],
      ),
    );
  }
}

class _PendingEventCard extends StatelessWidget {
  final EventItem event;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _PendingEventCard({
    required this.event,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppPalette.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              event.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppPalette.charcoal,
              ),
            ),
            const SizedBox(height: 8),
            Text('Date: ${event.date}'),
            Text('Time: ${event.time}'),
            Text('Location: ${event.location}'),
            const SizedBox(height: 8),
            Text(
              event.description,
              style: const TextStyle(color: AppPalette.charcoal),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onReject,
                    icon: const Icon(Icons.close, color: AppPalette.ochre),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppPalette.ochre,
                      side: const BorderSide(color: AppPalette.ochre),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onApprove,
                    icon: const Icon(Icons.check),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppPalette.deepBlue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewedEventCard extends StatelessWidget {
  final EventItem event;

  const _ReviewedEventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final isApproved = event.isApproved;
    final badgeColor = isApproved ? AppPalette.deepBlue : AppPalette.ochre;
    final badgeText = isApproved ? 'Approved' : 'Rejected';

    return Card(
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
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppPalette.charcoal,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      color: badgeColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Date: ${event.date}'),
            Text('Location: ${event.location}'),
          ],
        ),
      ),
    );
  }
}