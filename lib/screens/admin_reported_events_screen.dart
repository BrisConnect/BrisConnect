import 'package:flutter/material.dart';
import 'package:brisconnect/auth/admin_auth.dart';
import 'package:brisconnect/auth/app_user_role.dart';
import 'package:brisconnect/models/moderation_action.dart';
import 'package:brisconnect/services/admin_moderation_service.dart';
import 'package:brisconnect/services/admin_user_management_service.dart';
import 'package:brisconnect/services/report_event_service.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/widgets/logo_app_bar_title.dart';
import 'package:brisconnect/widgets/role_guard.dart';

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
  String _selectedReasonFilter = 'all';
  DateTime? _selectedDateFrom;
  DateTime? _selectedDateTo;
  String _selectedSeverityFilter = 'all';
  late Stream<List<EventReport>> _reportsStream;
  late final AdminModerationService _moderationService;
  late final AdminUserManagementService _userManagementService;

  @override
  void initState() {
    super.initState();
    _moderationService = AdminModerationService(
      reportEventService: widget.reportService,
    );
    _userManagementService = AdminUserManagementService();
    _updateStream();
  }

  void _updateStream() {
    _reportsStream = widget.reportService.watchReportsByStatus(_selectedStatusFilter);
  }

  List<EventReport> _applyLocalFilters(List<EventReport> reports) {
    return reports.where((report) {
      if (_selectedReasonFilter != 'all' && report.reason != _selectedReasonFilter) {
        return false;
      }
      if (_selectedSeverityFilter != 'all' && report.severity != _selectedSeverityFilter) {
        return false;
      }
      final from = _selectedDateFrom;
      final to = _selectedDateTo;
      if (from != null && report.createdAt.isBefore(from)) {
        return false;
      }
      if (to != null && report.createdAt.isAfter(to.add(const Duration(days: 1)))) {
        return false;
      }
      return true;
    }).toList();
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final initial = isFrom ? _selectedDateFrom : _selectedDateTo;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) {
      setState(() {
        if (isFrom) {
          _selectedDateFrom = picked;
        } else {
          _selectedDateTo = picked;
        }
      });
    }
  }

  void _clearDateFilters() {
    setState(() {
      _selectedDateFrom = null;
      _selectedDateTo = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screen = Scaffold(
      backgroundColor: AppPalette.background,
      appBar: AppBar(
        title: const LogoAppBarTitle('Reported Events'),
      ),
      body: Column(
        children: [
          // Filters
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Filter Reports',
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
                const SizedBox(height: 12),
                // Category / reason / severity / date filters
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    DropdownButton<String>(
                      value: _selectedReasonFilter,
                      hint: const Text('Reason'),
                      items: [
                        const DropdownMenuItem(value: 'all', child: Text('All reasons')),
                        ...ReportEventService.reportReasons.map(
                          (reason) => DropdownMenuItem(
                            value: reason,
                            child: Text(ReportEventService.getReasonLabel(reason)),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => _selectedReasonFilter = value);
                      },
                    ),
                    DropdownButton<String>(
                      value: _selectedSeverityFilter,
                      hint: const Text('Severity'),
                      items: [
                        const DropdownMenuItem(value: 'all', child: Text('All severities')),
                        ...ReportEventService.reportSeverities.map(
                          (severity) => DropdownMenuItem(
                            value: severity,
                            child: Text(ReportEventService.getSeverityLabel(severity)),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => _selectedSeverityFilter = value);
                      },
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.calendar_today, size: 16),
                      label: Text(_selectedDateFrom == null
                          ? 'From date'
                          : 'From ${_formatDate(_selectedDateFrom!)}'),
                      onPressed: () => _pickDate(isFrom: true),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.calendar_today, size: 16),
                      label: Text(_selectedDateTo == null
                          ? 'To date'
                          : 'To ${_formatDate(_selectedDateTo!)}'),
                      onPressed: () => _pickDate(isFrom: false),
                    ),
                    if (_selectedDateFrom != null || _selectedDateTo != null)
                      TextButton.icon(
                        onPressed: _clearDateFilters,
                        icon: const Icon(Icons.clear, size: 16),
                        label: const Text('Clear dates'),
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

                final reports = _applyLocalFilters(snapshot.data ?? []);
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
                      moderationService: _moderationService,
                      userManagementService: _userManagementService,
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

    if (widget.enforceRoleGuard) {
      return RoleGuard(
        allowedRoles: const {AppUserRole.admin},
        child: screen,
      );
    }
    return screen;
  }
}

class ReportCard extends StatefulWidget {
  final EventReport report;
  final ReportEventService reportService;
  final AdminModerationService moderationService;
  final AdminUserManagementService userManagementService;
  final VoidCallback onStatusChanged;

  const ReportCard({
    super.key,
    required this.report,
    required this.reportService,
    required this.moderationService,
    required this.userManagementService,
    required this.onStatusChanged,
  });

  @override
  State<ReportCard> createState() => _ReportCardState();
}

class _ReportCardState extends State<ReportCard> {
  bool _isUpdating = false;

  Future<void> _moderate(ModerationDecision decision) async {
    if (_isUpdating) return;

    final adminEmail = AdminAuth.currentAdminEmail;
    if (adminEmail == null || adminEmail.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Admin email not available.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final reason = await _showReasonDialog(decision);
    if (reason == null || reason.trim().isEmpty) return;

    setState(() => _isUpdating = true);
    try {
      await widget.moderationService.moderateEventReport(
        reportId: widget.report.id,
        decision: decision,
        adminEmail: adminEmail,
        reason: reason.trim(),
      );
      widget.onStatusChanged();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Report ${decision.label.toLowerCase()}')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Action failed: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<String?> _showReasonDialog(ModerationDecision decision) async {
    final controller = TextEditingController();
    final title = decision == ModerationDecision.dismiss
        ? 'Dismiss report'
        : '${decision.label} report';
    final hint = decision == ModerationDecision.dismiss
        ? 'Reason for dismissing the report'
        : 'Reason for ${decision.label.toLowerCase()}';

    if (!mounted) return null;

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: hint,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Future<void> _warnUser() async {
    final adminEmail = AdminAuth.currentAdminEmail;
    if (adminEmail == null || adminEmail.isEmpty) {
      _showSnack('Admin email not available.', isError: true);
      return;
    }

    final reason = await _showReasonDialog(ModerationDecision.dismiss);
    if (reason == null || reason.trim().isEmpty) return;

    setState(() => _isUpdating = true);
    try {
      // Warnings are recorded as audit entries with decision=flag.
      await widget.moderationService.moderateEventReport(
        reportId: widget.report.id,
        decision: ModerationDecision.flag,
        adminEmail: adminEmail,
        reason: 'Warning issued: ${reason.trim()}',
      );
      widget.onStatusChanged();
      if (mounted) _showSnack('Warning recorded for ${widget.report.visitorEmail}.');
    } catch (e) {
      if (mounted) _showSnack('Warning failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _suspendReporter() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Suspend reporter'),
        content: Text(
          'Deactivate the account for ${widget.report.visitorEmail}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Suspend'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isUpdating = true);
    try {
      await widget.userManagementService.deactivateUser(
        widget.report.visitorEmail,
        'visitor',
      );
      if (mounted) _showSnack('${widget.report.visitorEmail} suspended.');
    } catch (e) {
      if (mounted) _showSnack('Suspend failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : null,
      ),
    );
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
            // Reason and severity
            Wrap(
              spacing: 12,
              children: [
                Text(
                  'Reason: ${ReportEventService.getReasonLabel(widget.report.reason)}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  'Severity: ${ReportEventService.getSeverityLabel(widget.report.severity)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: _severityColor(widget.report.severity),
                  ),
                ),
              ],
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
            Wrap(
              spacing: 8,
              alignment: WrapAlignment.end,
              children: [
                if (widget.report.status == 'pending') ...[
                  TextButton(
                    onPressed: _isUpdating ? null : () => _moderate(ModerationDecision.dismiss),
                    child: const Text('Dismiss'),
                  ),
                  TextButton(
                    onPressed: _isUpdating ? null : _warnUser,
                    child: const Text('Warn'),
                  ),
                  ElevatedButton(
                    onPressed: _isUpdating ? null : () => _moderate(ModerationDecision.delete),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Remove Event'),
                  ),
                ] else if (widget.report.status == 'reviewing') ...[
                  TextButton(
                    onPressed: _isUpdating ? null : () => _moderate(ModerationDecision.dismiss),
                    child: const Text('Dismiss'),
                  ),
                  ElevatedButton(
                    onPressed: _isUpdating ? null : () => _moderate(ModerationDecision.delete),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Remove Event'),
                  ),
                ],
                TextButton(
                  onPressed: _isUpdating ? null : _suspendReporter,
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Suspend Reporter'),
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

  Color _severityColor(String severity) {
    switch (severity) {
      case 'critical':
        return Colors.red.shade700;
      case 'high':
        return Colors.orange.shade700;
      case 'low':
        return Colors.green.shade700;
      default:
        return Colors.blue.shade700;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
