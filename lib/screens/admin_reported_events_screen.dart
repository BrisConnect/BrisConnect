import 'package:flutter/material.dart';
import 'package:brisconnect/services/report_event_service.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/widgets/logo_app_bar_title.dart';

class AdminReportedEventsScreen extends StatefulWidget {
  final ReportEventService reportService;
  final bool enforceRoleGuard;

  AdminReportedEventsScreen({
    super.key,
    ReportEventService? reportService,
    this.enforceRoleGuard = true,
  }) : reportService = reportService ?? ReportEventService();

  @override
  State<AdminReportedEventsScreen> createState() =>
      _AdminReportedEventsScreenState();
}

class _AdminReportedEventsScreenState extends State<AdminReportedEventsScreen> {
  String _selectedStatusFilter = 'pending'; // 'pending', 'reviewing', 'resolved', 'dismissed'
  late Stream<List<EventReport>> _reportsStream;

  @override
  void initState() {
    super.initState();
    _updateStream();
  }

  void _updateStream() {
    _reportsStream = widget.reportService.watchReportsByStatus(_selectedStatusFilter);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.background,
      appBar: AppBar(
        title: const LogoAppBarTitle('Reported Events'),
      ),
      body: Column(
        children: [
          // Status filter chips
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Filter Reports by Status',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppPalette.charcoal,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    FilterChip(
                      label: const Text('Pending'),
                      selected: _selectedStatusFilter == 'pending',
                      onSelected: (selected) {
                        setState(() {
                          _selectedStatusFilter = 'pending';
                          _updateStream();
                        });
                      },
                    ),
                    FilterChip(
                      label: const Text('Reviewing'),
                      selected: _selectedStatusFilter == 'reviewing',
                      onSelected: (selected) {
                        setState(() {
                          _selectedStatusFilter = 'reviewing';
                          _updateStream();
                        });
                      },
                    ),
                    FilterChip(
                      label: const Text('Resolved'),
                      selected: _selectedStatusFilter == 'resolved',
                      onSelected: (selected) {
                        setState(() {
                          _selectedStatusFilter = 'resolved';
                          _updateStream();
                        });
                      },
                    ),
                    FilterChip(
                      label: const Text('Dismissed'),
                      selected: _selectedStatusFilter == 'dismissed',
                      onSelected: (selected) {
                        setState(() {
                          _selectedStatusFilter = 'dismissed';
                          _updateStream();
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Reports list
          Expanded(
            child: StreamBuilder<List<EventReport>>(
              stream: _reportsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('Error loading reports: ${snapshot.error}'),
                    ),
                  );
                }

                final reports = snapshot.data ?? [];
                if (reports.isEmpty) {
                  return Center(
                    child: Text(
                      'No $_selectedStatusFilter reports',
                      style: const TextStyle(color: AppPalette.charcoal),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: reports.length,
                  itemBuilder: (context, index) {
                    final report = reports[index];
                    return ReportCard(
                      report: report,
                      reportService: widget.reportService,
                      onStatusChanged: () {
                        // Refresh stream by updating state
                        setState(() => _updateStream());
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class ReportCard extends StatefulWidget {
  final EventReport report;
  final ReportEventService reportService;
  final VoidCallback onStatusChanged;

  const ReportCard({
    super.key,
    required this.report,
    required this.reportService,
    required this.onStatusChanged,
  });

  @override
  State<ReportCard> createState() => _ReportCardState();
}

class _ReportCardState extends State<ReportCard> {
  bool _isUpdating = false;

  Future<void> _updateStatus(String newStatus) async {
    if (_isUpdating) return;

    setState(() => _isUpdating = true);
    try {
      await widget.reportService.updateReportStatus(widget.report.id, newStatus);
      widget.onStatusChanged();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Report status updated to $newStatus')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating status: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppPalette.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppPalette.border),
      ),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with event ID and status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Event ID: ${widget.report.eventId}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Reported by: ${widget.report.visitorEmail}',
                        style: const TextStyle(fontSize: 12, color: AppPalette.charcoal),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(
                    widget.report.status.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  backgroundColor: _getStatusColor(widget.report.status).withValues(alpha: 0.2),
                  side: BorderSide(color: _getStatusColor(widget.report.status)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Reason
            Text(
              'Reason: ${ReportEventService.getReasonLabel(widget.report.reason)}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (widget.report.comments != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppPalette.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.report.comments!,
                  style: const TextStyle(fontSize: 13, color: AppPalette.charcoal),
                ),
              ),
            ],
            const SizedBox(height: 12),
            // Timestamps
            Text(
              'Reported: ${_formatDate(widget.report.createdAt)}',
              style: const TextStyle(fontSize: 11, color: AppPalette.charcoal),
            ),
            if (widget.report.reviewedAt != null)
              Text(
                'Reviewed: ${_formatDate(widget.report.reviewedAt!)}',
                style: const TextStyle(fontSize: 11, color: AppPalette.charcoal),
              ),
            const SizedBox(height: 12),
            // Action buttons
            if (widget.report.status == 'pending')
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isUpdating ? null : () => _updateStatus('dismissed'),
                    child: const Text('Dismiss'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isUpdating ? null : () => _updateStatus('reviewing'),
                    child: const Text('Review'),
                  ),
                ],
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isUpdating ? null : () => _updateStatus('resolved'),
                    child: const Text('Mark Resolved'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'reviewing':
        return Colors.blue;
      case 'resolved':
        return Colors.green;
      case 'dismissed':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
