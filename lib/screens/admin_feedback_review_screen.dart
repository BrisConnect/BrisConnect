import 'package:brisconnect/auth/app_user_role.dart';
import 'package:brisconnect/services/app_feedback_service.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/widgets/logo_app_bar_title.dart';
import 'package:brisconnect/widgets/role_guard.dart';
import 'package:flutter/material.dart';

class AdminFeedbackReviewScreen extends StatefulWidget {
  AdminFeedbackReviewScreen({
    super.key,
    AppFeedbackService? feedbackService,
    this.enforceRoleGuard = true,
  }) : feedbackService = feedbackService ?? AppFeedbackService();

  final AppFeedbackService feedbackService;
  final bool enforceRoleGuard;

  @override
  State<AdminFeedbackReviewScreen> createState() =>
      _AdminFeedbackReviewScreenState();
}

class _AdminFeedbackReviewScreenState extends State<AdminFeedbackReviewScreen> {
  String _selectedStatus = 'pending_triage';
  String _selectedSeverity = 'all';

  static const List<String> _severityOptions = [
    'all',
    'critical',
    'high',
    'medium',
    'low',
  ];

  @override
  Widget build(BuildContext context) {
    final content = Scaffold(
        backgroundColor: AppPalette.background,
        appBar: AppBar(
          title: const LogoAppBarTitle('App Feedback'),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Status',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppPalette.charcoal,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: AppFeedbackService.feedbackStatuses
                        .map(
                          (status) => FilterChip(
                            label: Text(_label(status)),
                            selected: _selectedStatus == status,
                            onSelected: (_) {
                              setState(() => _selectedStatus = status);
                            },
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Severity',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppPalette.charcoal,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _severityOptions
                        .map(
                          (severity) => FilterChip(
                            label: Text(_severityLabel(severity)),
                            selected: _selectedSeverity == severity,
                            onSelected: (_) {
                              setState(() => _selectedSeverity = severity);
                            },
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<List<AppFeedbackItem>>(
                stream: widget.feedbackService.watchFeedbackByStatus(_selectedStatus),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Could not load feedback right now: ${snapshot.error}',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  final items = snapshot.data ?? const <AppFeedbackItem>[];
                  final filteredItems = items
                      .where(
                        (item) => _selectedSeverity == 'all'
                            ? true
                            : item.severity.toLowerCase() == _selectedSeverity,
                      )
                      .toList();

                  if (filteredItems.isEmpty) {
                    return Center(
                      child: Text(
                        'No ${_severityLabel(_selectedSeverity).toLowerCase()} feedback with status ${_label(_selectedStatus)}.',
                        style: const TextStyle(color: AppPalette.mutedText),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: filteredItems.length,
                    itemBuilder: (context, index) {
                      return _FeedbackCard(
                        item: filteredItems[index],
                        onStatusChange: (nextStatus) async {
                          await widget.feedbackService.updateFeedbackStatus(
                            feedbackId: filteredItems[index].id,
                            status: nextStatus,
                            consideredForFix: nextStatus != 'wont_fix',
                          );
                        },
                        onReply: (reply) async {
                          await widget.feedbackService.replyToFeedback(
                            feedbackId: filteredItems[index].id,
                            reply: reply,
                          );
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
    if (!widget.enforceRoleGuard) return content;
    return RoleGuard(
      allowedRoles: const {AppUserRole.admin},
      deniedMessage: 'Access denied. Admin privileges are required.',
      child: content,
    );
  }

  String _label(String status) {
    switch (status) {
      case 'pending_triage':
        return 'Pending Triage';
      case 'in_progress':
        return 'In Progress';
      case 'resolved':
        return 'Resolved';
      case 'wont_fix':
        return 'Won\'t Fix';
      default:
        return status;
    }
  }

  String _severityLabel(String value) {
    switch (value) {
      case 'all':
        return 'All';
      case 'critical':
        return 'Critical';
      case 'high':
        return 'High';
      case 'medium':
        return 'Medium';
      case 'low':
        return 'Low';
      default:
        return value;
    }
  }
}

class _FeedbackCard extends StatefulWidget {
  const _FeedbackCard({
    required this.item,
    required this.onStatusChange,
    required this.onReply,
  });

  final AppFeedbackItem item;
  final Future<void> Function(String status) onStatusChange;
  final Future<void> Function(String reply) onReply;

  @override
  State<_FeedbackCard> createState() => _FeedbackCardState();
}

class _FeedbackCardState extends State<_FeedbackCard> {
  bool _isUpdating = false;
  bool _showReplyField = false;
  final _replyController = TextEditingController();

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _updateStatus(String status) async {
    if (_isUpdating) {
      return;
    }

    setState(() => _isUpdating = true);
    try {
      await widget.onStatusChange(status);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Feedback marked as ${_label(status)}.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update feedback: $error'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  Future<void> _sendReply() async {
    final reply = _replyController.text.trim();
    if (reply.isEmpty) return;

    setState(() => _isUpdating = true);
    try {
      await widget.onReply(reply);
      if (!mounted) return;
      setState(() => _showReplyField = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reply sent.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send reply: $error'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final dueStatus = _dueStatus(item.resolutionDueAt);
    final dueColor = _dueStatusColor(dueStatus);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: AppPalette.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppPalette.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.referenceId.isNotEmpty) ...[
              Text(
                item.referenceId,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: AppPalette.deepBlue,
                ),
              ),
              const SizedBox(height: 4),
            ],
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.subject,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: AppPalette.charcoal,
                    ),
                  ),
                ),
                _StatusBadge(status: item.status),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${item.reporterRole.toUpperCase()} • ${item.reporterEmail}',
              style: const TextStyle(color: AppPalette.mutedText, fontSize: 12),
            ),
            const SizedBox(height: 10),
            Text(
              item.details,
              style: const TextStyle(color: AppPalette.charcoal, height: 1.4),
            ),
            if ((item.imageUrl ?? '').isNotEmpty) ...[
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => _showFullImage(context, item.imageUrl!),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    item.imageUrl!,
                    width: double.infinity,
                    height: 180,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MetaChip(label: 'Category: ${item.category}'),
                _MetaChip(label: 'Severity: ${item.severity}'),
                _MetaChip(label: 'Due: ${_formatDate(item.resolutionDueAt)}'),
                _MetaChip(
                  label: dueStatus,
                  color: dueColor.withValues(alpha: 0.14),
                  textColor: dueColor,
                ),
                if ((item.screenContext ?? '').isNotEmpty)
                  _MetaChip(label: 'Screen: ${item.screenContext}'),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: _isUpdating ? null : () => _updateStatus('in_progress'),
                  child: const Text('Mark In Progress'),
                ),
                OutlinedButton(
                  onPressed: _isUpdating ? null : () => _updateStatus('resolved'),
                  child: const Text('Mark Resolved'),
                ),
                TextButton(
                  onPressed: _isUpdating ? null : () => _updateStatus('wont_fix'),
                  child: const Text('Mark Won\'t Fix'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if ((item.adminReply ?? '').isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppPalette.deepBlue.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppPalette.deepBlue.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Admin Reply',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: AppPalette.deepBlue,
                          ),
                        ),
                        const Spacer(),
                        if (item.adminReplyAt != null)
                          Text(
                            _formatDateTime(item.adminReplyAt!),
                            style: const TextStyle(
                              color: AppPalette.mutedText,
                              fontSize: 11,
                            ),
                          ),
                        if (!item.replyReadByReporter) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade700,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'Unread',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.adminReply!,
                      style: const TextStyle(color: AppPalette.charcoal, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (_showReplyField) ...[
              TextField(
                controller: _replyController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Write a reply to the user...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: _isUpdating ? null : _sendReply,
                    icon: const Icon(Icons.send_rounded, size: 18),
                    label: const Text('Send Reply'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppPalette.deepBlue,
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => setState(() => _showReplyField = false),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ] else
              OutlinedButton.icon(
                onPressed: () {
                  _replyController.text = item.adminReply ?? '';
                  setState(() => _showReplyField = true);
                },
                icon: const Icon(Icons.reply_rounded, size: 18),
                label: Text(
                  (item.adminReply ?? '').isNotEmpty ? 'Edit Reply' : 'Reply',
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _label(String status) {
    switch (status) {
      case 'pending_triage':
        return 'Pending Triage';
      case 'in_progress':
        return 'In Progress';
      case 'resolved':
        return 'Resolved';
      case 'wont_fix':
        return 'Won\'t Fix';
      default:
        return status;
    }
  }

  String _formatDate(DateTime? value) {
    if (value == null) {
      return 'N/A';
    }

    final y = value.year.toString().padLeft(4, '0');
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _formatDateTime(DateTime value) {
    final d = value.day.toString().padLeft(2, '0');
    final m = value.month.toString().padLeft(2, '0');
    final y = value.year.toString();
    final h = value.hour > 12 ? value.hour - 12 : (value.hour == 0 ? 12 : value.hour);
    final min = value.minute.toString().padLeft(2, '0');
    final period = value.hour >= 12 ? 'PM' : 'AM';
    return '$d/$m/$y $h:$min $period';
  }

  String _dueStatus(DateTime? value) {
    if (value == null) {
      return 'No Due Date';
    }

    final today = DateTime.now();
    final due = DateTime(value.year, value.month, value.day);
    final now = DateTime(today.year, today.month, today.day);
    final diffDays = due.difference(now).inDays;

    if (diffDays < 0) {
      return 'Overdue';
    }
    if (diffDays <= 3) {
      return 'Due Soon';
    }
    return 'On Track';
  }

  Color _dueStatusColor(String dueStatus) {
    switch (dueStatus) {
      case 'Overdue':
        return Colors.red.shade700;
      case 'Due Soon':
        return Colors.orange.shade700;
      case 'On Track':
        return Colors.green.shade700;
      default:
        return AppPalette.mutedText;
    }
  }

  void _showFullImage(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(url, fit: BoxFit.contain),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }

  Color _statusColor(String value) {
    switch (value) {
      case 'pending_triage':
        return Colors.orange.shade700;
      case 'in_progress':
        return AppPalette.deepBlue;
      case 'resolved':
        return Colors.green.shade700;
      case 'wont_fix':
        return AppPalette.ochre;
      default:
        return AppPalette.charcoal;
    }
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.label,
    this.color = AppPalette.background,
    this.textColor = AppPalette.charcoal,
  });

  final String label;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, color: textColor),
      ),
    );
  }
}
