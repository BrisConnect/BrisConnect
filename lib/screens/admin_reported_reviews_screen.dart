import 'package:flutter/material.dart';
import 'package:brisconnect/auth/admin_auth.dart';
import 'package:brisconnect/auth/app_user_role.dart';
import 'package:brisconnect/models/moderation_action.dart';
import 'package:brisconnect/models/review.dart';
import 'package:brisconnect/services/admin_moderation_service.dart';
import 'package:brisconnect/services/admin_user_management_service.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/widgets/logo_app_bar_title.dart';
import 'package:brisconnect/widgets/role_guard.dart';

class AdminReportedReviewsScreen extends StatefulWidget {
  final AdminModerationService moderationService;
  final bool enforceRoleGuard;

  AdminReportedReviewsScreen({
    super.key,
    AdminModerationService? moderationService,
    this.enforceRoleGuard = true,
  }) : moderationService = moderationService ?? AdminModerationService();

  @override
  State<AdminReportedReviewsScreen> createState() =>
      _AdminReportedReviewsScreenState();
}

class _AdminReportedReviewsScreenState
    extends State<AdminReportedReviewsScreen> {
  String _selectedStatusFilter = 'reported'; // 'reported', 'deleted'
  String _selectedReasonFilter = 'all';
  String _selectedSeverityFilter = 'all';
  DateTime? _selectedDateFrom;
  DateTime? _selectedDateTo;
  late Stream<List<Review>> _reviewsStream;
  late final AdminUserManagementService _userManagementService;

  static const List<String> _reportReasons = [
    'inappropriate',
    'spam',
    'offensive',
    'misleading',
    'other',
  ];

  static const List<String> _severities = [
    'low',
    'medium',
    'high',
    'critical',
  ];

  @override
  void initState() {
    super.initState();
    _userManagementService = AdminUserManagementService();
    _updateStream();
  }

  void _updateStream() {
    if (_selectedStatusFilter == 'deleted') {
      _reviewsStream = widget.moderationService.deletedReviewsStream;
    } else {
      _reviewsStream = widget.moderationService.reportedReviewsStream;
    }
  }

  List<Review> _applyLocalFilters(List<Review> reviews) {
    return reviews.where((review) {
      if (_selectedReasonFilter != 'all' &&
          review.reportReason?.toLowerCase() != _selectedReasonFilter) {
        return false;
      }
      if (_selectedSeverityFilter != 'all' &&
          review.severity != _selectedSeverityFilter) {
        return false;
      }
      final from = _selectedDateFrom;
      final to = _selectedDateTo;
      if (from != null && review.createdAt.isBefore(from)) return false;
      if (to != null &&
          review.createdAt.isAfter(to.add(const Duration(days: 1)))) {
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

  String _reasonLabel(String reason) {
    const labels = {
      'inappropriate': 'Inappropriate',
      'spam': 'Spam',
      'offensive': 'Offensive',
      'misleading': 'Misleading',
      'other': 'Other',
    };
    return labels[reason] ?? reason;
  }

  String _severityLabel(String severity) {
    const labels = {
      'low': 'Low',
      'medium': 'Medium',
      'high': 'High',
      'critical': 'Critical',
    };
    return labels[severity] ?? severity;
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final screen = Scaffold(
      backgroundColor: AppPalette.background,
      appBar: AppBar(
        title: const LogoAppBarTitle('Reported Recommendations'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Filter Recommendations',
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
                      label: const Text('Reported'),
                      selected: _selectedStatusFilter == 'reported',
                      onSelected: (selected) {
                        setState(() {
                          _selectedStatusFilter = 'reported';
                          _updateStream();
                        });
                      },
                    ),
                    FilterChip(
                      label: const Text('Deleted'),
                      selected: _selectedStatusFilter == 'deleted',
                      onSelected: (selected) {
                        setState(() {
                          _selectedStatusFilter = 'deleted';
                          _updateStream();
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
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
                        ..._reportReasons.map(
                          (reason) => DropdownMenuItem(
                            value: reason,
                            child: Text(_reasonLabel(reason)),
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
                        ..._severities.map(
                          (severity) => DropdownMenuItem(
                            value: severity,
                            child: Text(_severityLabel(severity)),
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
          Expanded(
            child: StreamBuilder<List<Review>>(
              stream: _reviewsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('Error loading recommendations: ${snapshot.error}'),
                    ),
                  );
                }

                final reviews = snapshot.data ?? [];
                final filtered = _applyLocalFilters(
                  _selectedStatusFilter == 'deleted'
                      ? reviews.where((r) => r.isDeleted).toList()
                      : reviews,
                );

                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      'No $_selectedStatusFilter recommendations',
                      style: const TextStyle(color: AppPalette.charcoal),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final review = filtered[index];
                    return _ReviewCard(
                      review: review,
                      moderationService: widget.moderationService,
                      userManagementService: _userManagementService,
                      onAction: () => setState(() => _updateStream()),
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

class _ReviewCard extends StatefulWidget {
  final Review review;
  final AdminModerationService moderationService;
  final AdminUserManagementService userManagementService;
  final VoidCallback onAction;

  const _ReviewCard({
    required this.review,
    required this.moderationService,
    required this.userManagementService,
    required this.onAction,
  });

  @override
  State<_ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends State<_ReviewCard> {
  bool _isLoading = false;

  Future<void> _moderate(ModerationDecision decision) async {
    final adminEmail = AdminAuth.currentAdminEmail ?? widget.moderationService.currentAdminEmail;
    if (adminEmail == null || adminEmail.isEmpty) {
      _showSnack('Admin email not available.', isError: true);
      return;
    }

    final reason = await _showReasonDialog(decision);
    if (reason == null || reason.trim().isEmpty) return;

    setState(() => _isLoading = true);
    try {
      await widget.moderationService.moderateReview(
        reviewId: widget.review.id,
        decision: decision,
        adminEmail: adminEmail,
        reason: reason.trim(),
      );
      widget.onAction();
      if (mounted) _showSnack('Recommendation ${decision.label.toLowerCase()}.');
    } catch (e) {
      if (mounted) _showSnack('Action failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _warnReporter() async {
    final adminEmail = AdminAuth.currentAdminEmail ?? widget.moderationService.currentAdminEmail;
    if (adminEmail == null || adminEmail.isEmpty) {
      _showSnack('Admin email not available.', isError: true);
      return;
    }

    final reason = await _showReasonDialog(ModerationDecision.flag);
    if (reason == null || reason.trim().isEmpty) return;

    setState(() => _isLoading = true);
    try {
      await widget.moderationService.moderateReview(
        reviewId: widget.review.id,
        decision: ModerationDecision.flag,
        adminEmail: adminEmail,
        reason: 'Warning issued: ${reason.trim()}',
      );
      widget.onAction();
      if (mounted) _showSnack('Warning recorded.');
    } catch (e) {
      if (mounted) _showSnack('Warning failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _suspendReporter() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Suspend reporter'),
        content: Text(
          'Deactivate the account for ${widget.review.visitorId}?',
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

    setState(() => _isLoading = true);
    try {
      await widget.userManagementService.deactivateUser(
        widget.review.visitorId,
        'visitor',
      );
      if (mounted) _showSnack('${widget.review.visitorId} suspended.');
    } catch (e) {
      if (mounted) _showSnack('Suspend failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<String?> _showReasonDialog(ModerationDecision decision) async {
    final controller = TextEditingController();
    final title = decision == ModerationDecision.dismiss
        ? 'Dismiss report'
        : decision == ModerationDecision.flag
            ? 'Warn reporter'
            : '${decision.label} recommendation';
    final hint = decision == ModerationDecision.dismiss
        ? 'Reason for dismissing the report'
        : decision == ModerationDecision.flag
            ? 'Warning message to send the reporter'
            : 'Reason for ${decision.label.toLowerCase()}';

    if (!mounted) return null;

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(title, key: const ValueKey('moderation_reason_title')),
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
    final review = widget.review;
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        review.visitorName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Rating: ${review.rating} • Buzz: ${review.buzzRating}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppPalette.charcoal,
                        ),
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(
                    review.isDeleted
                        ? 'DELETED'
                        : review.isReported
                            ? 'REPORTED'
                            : review.isFlagged
                                ? 'FLAGGED'
                                : 'VISIBLE',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  backgroundColor: _statusColor.withValues(alpha: 0.2),
                  side: BorderSide(color: _statusColor),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              review.comment,
              style: const TextStyle(fontSize: 14),
            ),
            if (review.reportReason != null && review.reportReason!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppPalette.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Report reason: ${review.reportReason}',
                  style: const TextStyle(fontSize: 13, color: AppPalette.charcoal),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              children: [
                Text(
                  'Submitted: ${_formatDate(review.createdAt)}',
                  style: const TextStyle(fontSize: 11, color: AppPalette.charcoal),
                ),
                Text(
                  'Severity: ${_severityLabel(review.severity)}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _severityColor(review.severity),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (!_isLoading)
              Wrap(
                spacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  if (!review.isDeleted) ...[
                    TextButton(
                      onPressed: () => _moderate(ModerationDecision.dismiss),
                      child: const Text('Dismiss'),
                    ),
                    TextButton(
                      onPressed: _warnReporter,
                      child: const Text('Warn'),
                    ),
                    ElevatedButton(
                      onPressed: () => _moderate(ModerationDecision.delete),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Delete'),
                    ),
                  ],
                  if (review.isDeleted)
                    ElevatedButton(
                      onPressed: () => _moderate(ModerationDecision.restore),
                      child: const Text('Restore'),
                    ),
                  TextButton(
                    onPressed: _suspendReporter,
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Suspend Reporter'),
                  ),
                ],
              )
            else
              const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }

  Color get _statusColor {
    if (widget.review.isDeleted) return Colors.red;
    if (widget.review.isReported) return Colors.orange;
    if (widget.review.isFlagged) return Colors.blue;
    return Colors.green;
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
