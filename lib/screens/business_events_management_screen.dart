import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:brisconnect/auth/local_auth.dart';
import 'package:brisconnect/models/business.dart';
import 'package:brisconnect/models/business_event.dart';
import 'package:brisconnect/screens/business_event_form_screen.dart';
import 'package:brisconnect/screens/create_business_form_screen.dart';
import 'package:brisconnect/services/business_event_service.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/widgets/logo_app_bar_title.dart';

class BusinessEventsManagementScreen extends StatefulWidget {
  final Business business;

  const BusinessEventsManagementScreen({
    super.key,
    required this.business,
  });

  @override
  State<BusinessEventsManagementScreen> createState() =>
      _BusinessEventsManagementScreenState();
}

class _BusinessEventsManagementScreenState
    extends State<BusinessEventsManagementScreen> {
  final BusinessEventService _eventService = BusinessEventService();

  Future<void> _createNewBusiness() async {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (userId.isEmpty) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateBusinessFormScreen(userId: userId),
      ),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('New business profile created! Go to My Business to create events for it.'),
          backgroundColor: Colors.green,
        ),
      );
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) Navigator.pop(context);
      });
    }
  }

  Future<void> _createNewEvent() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BusinessEventFormScreen(
          business: widget.business,
        ),
      ),
    );

    if (result == true && mounted) {
      setState(() {}); // Refresh list
    }
  }

  Future<void> _editEvent(BusinessEvent event) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BusinessEventFormScreen(
          business: widget.business,
          event: event,
        ),
      ),
    );

    if (result == true && mounted) {
      setState(() {}); // Refresh list
    }
  }

  Future<void> _deleteEvent(BusinessEvent event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Event'),
        content: const Text(
          'Are you sure you want to delete this event? It will be marked as cancelled.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final userEmail = LocalAuth.currentLocal?.email ?? '';
    final success = await _eventService.deleteBusinessEvent(
      eventId: event.id!,
      businessId: widget.business.id!,
      ownerEmail: userEmail,
      softDelete: true,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? 'Event cancelled successfully'
              : 'Failed to cancel event'),
          backgroundColor:
              success ? Colors.green.shade700 : Colors.red.shade700,
        ),
      );
      if (success) {
        setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F3EA),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const LogoAppBarTitle('My Events'),
        backgroundColor: AppPalette.ochre,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              icon: const Icon(Icons.event_note_rounded),
              tooltip: 'Add Event',
              onPressed: _createNewEvent,
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<BusinessEvent>>(
        stream: _eventService.watchBusinessEvents(
          businessId: widget.business.id!,
          publishedOnly: false,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final events = snapshot.data ?? [];
          final publishedEvents =
              events.where((e) => e.isPublished).toList();
          final cancelledEvents =
              events.where((e) => e.isCancelled).toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                const Text(
                  'Active Events',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppPalette.charcoal,
                  ),
                ),
                const SizedBox(height: 12),
                if (publishedEvents.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppPalette.border),
                      borderRadius: BorderRadius.circular(12),
                      color: AppPalette.surface,
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.event_note_outlined,
                            size: 40,
                            color: AppPalette.ochre,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'No active events yet',
                            style: TextStyle(
                              color: AppPalette.mutedText,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...publishedEvents
                      .map((event) => _buildEventCard(event))
                      .toList(),
                if (cancelledEvents.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const Text(
                    'Cancelled Events',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppPalette.charcoal,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...cancelledEvents
                      .map((event) => _buildEventCard(event, cancelled: true))
                      .toList(),
                ],
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNewBusiness,
        backgroundColor: AppPalette.ochre,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }

  Widget _buildEventCard(BusinessEvent event, {bool cancelled = false}) {
    final dateTime = '${event.date} • ${event.time}';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: cancelled
              ? Colors.grey.shade300
              : AppPalette.border,
        ),
      ),
      color: cancelled
          ? Colors.grey.shade100
          : AppPalette.surface,
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
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: cancelled
                          ? AppPalette.mutedText
                          : AppPalette.charcoal,
                      decoration: cancelled
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                ),
                if (cancelled)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Cancelled',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              dateTime,
              style: const TextStyle(
                fontSize: 12,
                color: AppPalette.mutedText,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(
                  Icons.location_on_rounded,
                  size: 14,
                  color: AppPalette.mutedText,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    event.location,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppPalette.mutedText,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (event.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                event.description,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppPalette.charcoal,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (event.imageUrl != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  event.imageUrl!,
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.broken_image),
                ),
              ),
            ],
            if (!cancelled) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _editEvent(event),
                    icon: const Icon(Icons.edit_rounded, size: 18),
                    label: const Text('Edit'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppPalette.ochre,
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () => _deleteEvent(event),
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: const Text('Cancel'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
