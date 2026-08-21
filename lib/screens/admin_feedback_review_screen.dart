import 'package:brisconnect/auth/app_user_role.dart';
import 'package:brisconnect/features/admin/dashboard/admin_neon_theme.dart';
import 'package:brisconnect/services/app_feedback_service.dart';
import 'package:brisconnect/widgets/role_guard.dart';
import 'package:flutter/material.dart';
import 'package:brisconnect/features/admin/dashboard/widgets/admin_sidebar.dart';

class AdminFeedbackReviewScreen extends StatefulWidget {
  AdminFeedbackReviewScreen({
    super.key,
    AppFeedbackService? feedbackService,
    this.enforceRoleGuard = true,
    this.isEmbedded = false,
  }) : feedbackService = feedbackService ?? AppFeedbackService();

  final AppFeedbackService feedbackService;
  final bool enforceRoleGuard;
  final bool isEmbedded;

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
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width > 1024;
    
    // Build the body content (without Scaffold wrapper for embedded case)
    final bodyContent = Column(
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
                  color: AdminNeonTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: AppFeedbackService.feedbackStatuses.map(
                  (status) {
                    final isSelected = _selectedStatus == status;
                    return FilterChip(
                      label: Text(
                        _label(status),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color:
                              isSelected ? Colors.white : AdminNeonTheme.textPrimary,
                        ),
                      ),
                      selected: isSelected,
                      onSelected: (_) {
                        setState(() => _selectedStatus = status);
                      },
                      selectedColor: AdminNeonTheme.neonOrange,
                      backgroundColor: AdminNeonTheme.glassSurface,
                      checkmarkColor: Colors.white,
                      side: BorderSide(
                        color: isSelected
                            ? AdminNeonTheme.neonOrange
                            : AdminNeonTheme.glassBorder,
                      ),
                    );
                  },
                ).toList(),
              ),
              const SizedBox(height: 12),
              const Text(
                'Severity',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AdminNeonTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _severityOptions.map(
                  (severity) {
                    final isSelected = _selectedSeverity == severity;
                    return FilterChip(
                      label: Text(
                        _severityLabel(severity),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color:
                              isSelected ? Colors.white : AdminNeonTheme.textPrimary,
                        ),
                      ),
                      selected: isSelected,
                      onSelected: (_) {
                        setState(() => _selectedSeverity = severity);
                      },
                      selectedColor: AdminNeonTheme.neonOrange,
                      backgroundColor: AdminNeonTheme.glassSurface,
                      checkmarkColor: Colors.white,
                      side: BorderSide(
                        color: isSelected
                            ? AdminNeonTheme.neonOrange
                            : AdminNeonTheme.glassBorder,
                      ),
                    );
                  },
                ).toList(),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<AppFeedbackItem>>(
            stream:
                widget.feedbackService.watchFeedbackByStatus(_selectedStatus),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: AdminNeonTheme.neonOrange),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Could not load feedback right now: ${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AdminNeonTheme.textPrimary),
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
                final severity = _selectedSeverity == 'all'
                    ? ''
                    : ' ${_severityLabel(_selectedSeverity).toLowerCase()}';
                return Center(
                  child: Text(
                    'No$severity feedback with status "${_label(_selectedStatus)}".',
                    style: const TextStyle(color: AdminNeonTheme.textSecondary),
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
    );
    
    // When embedded, wrap in Container with proper layout constraints
    if (widget.isEmbedded) {
      final guarded = widget.enforceRoleGuard
          ? RoleGuard(
              allowedRoles: const {AppUserRole.admin},
              deniedMessage: 'Access denied. Admin privileges are required.',
              child: bodyContent,
            )
          : bodyContent;
      return guarded;
    }
    
    // When standalone, wrap in Scaffold with AppBar
    final content = Scaffold(
      backgroundColor: AdminNeonTheme.bgDeepNavy,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AdminNeonTheme.headerBg,
        foregroundColor: AdminNeonTheme.textPrimary,
        elevation: 0,
        title: const Text(
          'App Feedback',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: AdminNeonTheme.textPrimary,
          ),
        ),
      ),
      body: bodyContent,
    );
    
    final guarded = widget.enforceRoleGuard
        ? RoleGuard(
            allowedRoles: const {AppUserRole.admin},
            deniedMessage: 'Access denied. Admin privileges are required.',
            child: content,
          )
        : content;
    
    if (!isDesktop) return guarded;
    
    return Row(
      children: [
        AdminSidebar(
          selectedIndex: 4, // Feedback
          onDestinationSelected: (index) {
            _handleNavigation(context, index);
          },
        ),
        Expanded(child: guarded),
      ],
    );
  }

  void _handleNavigation(BuildContext context, int index) {
    // index: 0=Home, 1=Users, 2=Businesses, 3=Reports, 4=Feedback, 5=Broadcast, 6=Settings
    switch (index) {
      case 0: // Home
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/admin/dashboard',
          (route) => false,
        );
        break;
      case 1: // Users
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/admin/users',
          (route) => false,
        );
        break;
      case 2: // Businesses
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/admin/businesses',
          (route) => false,
        );
        break;
      case 3: // Reports
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/admin/reports',
          (route) => false,
        );
        break;
      case 4: // Feedback - already here
        break;
      case 5: // Broadcast Email
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/admin/broadcast',
          (route) => false,
        );
        break;
      case 6: // Settings
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/admin/settings',
          (route) => false,
        );
        break;
    }
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
  bool _hovered = false;
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

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: AdminNeonTheme.glassCard(
          accent: AdminNeonTheme.neonBlue,
          radius: 14,
          borderOpacity: _hovered ? 0.7 : 0.35,
          borderWidth: _hovered ? 1.6 : 1.1,
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
                  color: AdminNeonTheme.neonBlue,
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
                      color: AdminNeonTheme.textPrimary,
                    ),
                  ),
                ),
                _StatusBadge(status: item.status),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${item.reporterRole.toUpperCase()} • ${item.reporterEmail}',
              style: const TextStyle(color: AdminNeonTheme.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 10),
            Text(
              item.details,
              style: const TextStyle(color: AdminNeonTheme.textSecondary, height: 1.4),
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
                  onPressed:
                      _isUpdating ? null : () => _updateStatus('in_progress'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AdminNeonTheme.neonBlue,
                    side: const BorderSide(color: AdminNeonTheme.neonBlue),
                  ),
                  child: const Text('Mark In Progress'),
                ),
                OutlinedButton(
                  onPressed:
                      _isUpdating ? null : () => _updateStatus('resolved'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF22C55E),
                    side: const BorderSide(color: Color(0xFF22C55E)),
                  ),
                  child: const Text('Mark Resolved'),
                ),
                TextButton(
                  onPressed:
                      _isUpdating ? null : () => _updateStatus('wont_fix'),
                  style: TextButton.styleFrom(foregroundColor: AdminNeonTheme.neonOrange),
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
                  color: AdminNeonTheme.neonBlue.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AdminNeonTheme.neonBlue.withValues(alpha: 0.3)),
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
                            color: AdminNeonTheme.neonBlue,
                          ),
                        ),
                        const Spacer(),
                        if (item.adminReplyAt != null)
                          Text(
                            _formatDateTime(item.adminReplyAt!),
                            style: const TextStyle(
                              color: AdminNeonTheme.textMuted,
                              fontSize: 11,
                            ),
                          ),
                        if (!item.replyReadByReporter) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AdminNeonTheme.neonOrange,
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
                      style: const TextStyle(
                          color: AdminNeonTheme.textPrimary, height: 1.4),
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
                style: const TextStyle(color: AdminNeonTheme.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Write a reply to the user...',
                  hintStyle: const TextStyle(color: AdminNeonTheme.textMuted),
                  filled: true,
                  fillColor: AdminNeonTheme.glassSurfaceAlt,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: AdminNeonTheme.glassBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: AdminNeonTheme.glassBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AdminNeonTheme.neonBlue),
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
                      backgroundColor: AdminNeonTheme.neonBlue,
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => setState(() => _showReplyField = false),
                    style: TextButton.styleFrom(foregroundColor: AdminNeonTheme.textSecondary),
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
                style: OutlinedButton.styleFrom(
                  foregroundColor: AdminNeonTheme.neonOrange,
                  side: const BorderSide(color: AdminNeonTheme.neonOrange),
                ),
                icon: const Icon(Icons.reply_rounded, size: 18),
                label: Text(
                  (item.adminReply ?? '').isNotEmpty ? 'Edit Reply' : 'Reply',
                ),
              ),
          ],
        ),
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
    final h =
        value.hour > 12 ? value.hour - 12 : (value.hour == 0 ? 12 : value.hour);
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
        return AdminNeonTheme.neonRed;
      case 'Due Soon':
        return AdminNeonTheme.neonOrange;
      case 'On Track':
        return const Color(0xFF22C55E);
      default:
        return AdminNeonTheme.textMuted;
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
        return AdminNeonTheme.neonOrange;
      case 'in_progress':
        return AdminNeonTheme.neonBlue;
      case 'resolved':
        return const Color(0xFF22C55E);
      case 'wont_fix':
        return AdminNeonTheme.neonRed;
      default:
        return AdminNeonTheme.textPrimary;
    }
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.label,
    this.color = AdminNeonTheme.glassSurfaceAlt,
    this.textColor = AdminNeonTheme.textSecondary,
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
        border: Border.all(color: AdminNeonTheme.glassBorder),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, color: textColor),
      ),
    );
  }
}
