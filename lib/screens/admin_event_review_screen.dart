import 'package:flutter/material.dart';
import 'package:brisconnect/auth/app_user_role.dart';
import 'package:brisconnect/models/event_item.dart';
import 'package:brisconnect/screens/admin_edit_event_screen.dart';
import 'package:brisconnect/services/admin_event_service.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/widgets/inline_status_message.dart';
import 'package:brisconnect/widgets/logo_app_bar_title.dart';
import 'package:brisconnect/widgets/role_guard.dart';

class AdminEventReviewScreen extends StatefulWidget {
  AdminEventReviewScreen({
    super.key,
    AdminEventService? eventService,
    this.enforceRoleGuard = true,
  }) : eventService = eventService ?? AdminEventService();

  final AdminEventService eventService;
  final bool enforceRoleGuard;

  @override
  State<AdminEventReviewScreen> createState() => _AdminEventReviewScreenState();
}

class _AdminEventReviewScreenState extends State<AdminEventReviewScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.eventService.migrateLegacyLocalSubmissionIds();
    });
  }

  Future<void> _openEditForm(EventItem event) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AdminEditEventScreen(
          event: event,
          eventService: widget.eventService,
        ),
      ),
    );
  }

  Future<void> _deleteEvent(EventItem event) async {
    try {
      await widget.eventService.deleteEvent(event.id);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${event.title} deleted.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete event: $error')),
      );
    }
  }

  Future<void> _approveEvent(EventItem event) async {
    try {
      await widget.eventService.updateEvent(
        eventId: event.id,
        title: event.title,
        date: event.date,
        location: event.location,
        description: event.description,
        reviewStatus: EventReviewStatus.approved,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${event.title}" approved.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to approve event: $error')),
      );
    }
  }

  Future<void> _rejectEvent(EventItem event) async {
    try {
      await widget.eventService.updateEvent(
        eventId: event.id,
        title: event.title,
        date: event.date,
        location: event.location,
        description: event.description,
        reviewStatus: EventReviewStatus.rejected,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${event.title}" rejected.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to reject event: $error')),
      );
    }
  }

  Future<void> _confirmDelete(EventItem event) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Are you sure?'),
          content: Text('Delete "${event.title}" from Firebase?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete == true) {
      await _deleteEvent(event);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scaffold = Scaffold(
        backgroundColor: widget.enforceRoleGuard ? AppPalette.background : Colors.transparent,
        appBar: AppBar(
          automaticallyImplyLeading: widget.enforceRoleGuard,
          title: const LogoAppBarTitle('Manage Events'),
          backgroundColor: widget.enforceRoleGuard ? null : AppPalette.ochre,
        ),
        body: StreamBuilder<List<EventItem>>(
          stream: widget.eventService.watchAllEvents(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: InlineStatusMessage(
                    message:
                        'Unable to load events right now. Please try again.',
                    type: InlineStatusType.error,
                    actionLabel: 'Retry',
                    onAction: () => setState(() {}),
                  ),
                ),
              );
            }

            final events = snapshot.data ?? const <EventItem>[];
            final pendingCount = events.where((event) => event.isPending).length;
            final approvedCount = events.where((event) => event.isApproved).length;
            final rejectedCount = events.where((event) => event.isRejected).length;

            if (events.isEmpty) {
              return ListView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: const [
                  _AdminEventSummary(total: 0, pending: 0, approved: 0, rejected: 0),
                  SizedBox(height: 16),
                  Card(
                    color: Color(0xCCFFFFFF),
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No events found in Firebase.'),
                    ),
                  ),
                ],
              );
            }

            return ListView.builder(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: events.length + 3, // summary + title + spacer + events
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _AdminEventSummary(
                    total: events.length,
                    pending: pendingCount,
                    approved: approvedCount,
                    rejected: rejectedCount,
                  );
                }
                if (index == 1) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: Text(
                      'All Events',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppPalette.charcoal,
                      ),
                    ),
                  );
                }
                if (index == 2) {
                  return const SizedBox(height: 12);
                }
                final event = events[index - 3];
                return Padding(
                  key: ValueKey(event.id),
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _AdminEventCard(
                    event: event,
                    onApprove: () => _approveEvent(event),
                    onReject: () => _rejectEvent(event),
                    onEdit: () => _openEditForm(event),
                    onDelete: () => _confirmDelete(event),
                  ),
                );
              },
            );
          },
        ),
      );

    if (!widget.enforceRoleGuard) {
      return scaffold;
    }

    return RoleGuard(
      allowedRoles: const {AppUserRole.admin},
      deniedMessage: 'Access denied. Admin privileges are required.',
      child: scaffold,
    );
  }
}

class _AdminEventSummary extends StatelessWidget {
  const _AdminEventSummary({
    required this.total,
    required this.pending,
    required this.approved,
    required this.rejected,
  });

  final int total;
  final int pending;
  final int approved;
  final int rejected;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppPalette.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Admin Event Control',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppPalette.charcoal,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Edit or delete any event stored in Firebase. Changes appear immediately across the app.',
              style: TextStyle(color: AppPalette.mutedText),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _SummaryChip(label: 'Total', value: total, color: AppPalette.deepBlue),
                _SummaryChip(label: 'Pending', value: pending, color: Colors.orange),
                _SummaryChip(label: 'Approved', value: approved, color: Colors.green),
                _SummaryChip(label: 'Rejected', value: rejected, color: AppPalette.ochre),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

class _AdminEventCard extends StatelessWidget {
  const _AdminEventCard({
    required this.event,
    required this.onApprove,
    required this.onReject,
    required this.onEdit,
    required this.onDelete,
  });

  final EventItem event;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  String _statusText(EventReviewStatus status) {
    switch (status) {
      case EventReviewStatus.pending:
        return 'Pending';
      case EventReviewStatus.approved:
        return 'Approved';
      case EventReviewStatus.rejected:
        return 'Rejected';
    }
  }

  Color _statusColor(EventReviewStatus status) {
    switch (status) {
      case EventReviewStatus.pending:
        return Colors.orange.shade700;
      case EventReviewStatus.approved:
        return Colors.green.shade700;
      case EventReviewStatus.rejected:
        return AppPalette.ochre;
    }
  }

  @override
  Widget build(BuildContext context) {
    final badgeColor = _statusColor(event.reviewStatus);
    final ownerEmail = event.createdByLocalEmail?.trim();

    return Card(
      color: AppPalette.surface.withValues(alpha: 0.80),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    event.title,
                    style: const TextStyle(
                      fontSize: 17,
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
                    _statusText(event.reviewStatus),
                    style: TextStyle(
                      color: badgeColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Date: ${event.date}',
              style: const TextStyle(color: AppPalette.charcoal),
            ),
            Text(
              'Time: ${event.time}',
              style: const TextStyle(color: AppPalette.charcoal),
            ),
            Text(
              'Location: ${event.location}',
              style: const TextStyle(color: AppPalette.charcoal),
            ),
            if (ownerEmail != null && ownerEmail.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Submitted by: $ownerEmail',
                style: const TextStyle(color: AppPalette.mutedText),
              ),
            ],
            const SizedBox(height: 10),
            Text(
              event.description.isEmpty
                  ? 'No description provided.'
                  : event.description,
              style: const TextStyle(color: AppPalette.charcoal),
            ),
            const SizedBox(height: 14),
            if (event.isPending) ...[              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onApprove,
                      icon: const Icon(Icons.check_circle_rounded),
                      label: const Text('Approve'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onReject,
                      icon: const Icon(Icons.cancel_rounded),
                      label: const Text('Reject'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppPalette.ochre,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_rounded),
                    label: const Text('Edit'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppPalette.deepBlue,
                      side: const BorderSide(color: AppPalette.deepBlue),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_rounded),
                    label: const Text('Delete'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
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
