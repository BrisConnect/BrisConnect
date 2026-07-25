import 'package:flutter/material.dart';
import 'package:brisconnect/auth/admin_auth.dart';
import 'package:brisconnect/auth/app_user_role.dart';
import 'package:brisconnect/models/moderation_action.dart';
import 'package:brisconnect/models/review.dart';
import 'package:brisconnect/services/admin_moderation_service.dart';
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
  String _selectedStatusFilter = 'reported'; // 'reported', 'flagged', 'deleted'
  late Stream<List<Review>> _reviewsStream;

  @override
  void initState() {
    super.initState();
    _updateStream();
  }

  void _updateStream() {
    if (_selectedStatusFilter == 'deleted') {
      _reviewsStream = widget.moderationService.deletedReviewsStream;
    } else {
      _reviewsStream = widget.moderationService.reportedReviewsStream;
    }
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
                  'Filter by Status',
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
                final filtered = _selectedStatusFilter == 'deleted'
                    ? reviews.where((r) => r.isDeleted).toList()
                    : reviews;

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
  final VoidCallback onAction;

  const _ReviewCard({
    required this.review,
    required this.moderationService,
    required this.onAction,
  });

  @override
  State<_ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends State<_ReviewCard> {
  bool _isLoading = false;

  Future<void> _moderate(ModerationDecision decision) async {
    final adminEmail = AdminAuth.currentAdminEmail;
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

  Future<String?> _showReasonDialog(ModerationDecision decision) async {
    final controller = TextEditingController();
    final title = decision == ModerationDecision.dismiss
        ? 'Dismiss report'
        : '${decision.label} recommendation';
    final hint = decision == ModerationDecision.dismiss
        ? 'Reason for dismissing the report'
        : 'Reason for ${decision.label.toLowerCase()}';

    return showDialog<String>(
      context: context,
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
            Text(
              'Submitted: ${_formatDate(review.createdAt)}',
              style: const TextStyle(fontSize: 11, color: AppPalette.charcoal),
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

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
