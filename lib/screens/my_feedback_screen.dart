import 'package:flutter/material.dart';
import 'package:brisconnect/services/app_feedback_service.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/widgets/logo_app_bar_title.dart';

class MyFeedbackScreen extends StatelessWidget {
  const MyFeedbackScreen({
    super.key,
    required this.reporterEmail,
  });

  final String reporterEmail;

  @override
  Widget build(BuildContext context) {
    final service = AppFeedbackService();

    return Scaffold(
      backgroundColor: AppPalette.background,
      appBar: AppBar(title: const LogoAppBarTitle('My Feedback')),
      body: StreamBuilder<List<AppFeedbackItem>>(
        stream: service.watchFeedbackByReporter(reporterEmail),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final items = snapshot.data ?? const <AppFeedbackItem>[];

          if (items.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'You have not submitted any feedback yet.',
                  style: TextStyle(color: AppPalette.mutedText),
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              return _MyFeedbackCard(item: items[index], service: service);
            },
          );
        },
      ),
    );
  }
}

class _MyFeedbackCard extends StatefulWidget {
  const _MyFeedbackCard({required this.item, required this.service});

  final AppFeedbackItem item;
  final AppFeedbackService service;

  @override
  State<_MyFeedbackCard> createState() => _MyFeedbackCardState();
}

class _MyFeedbackCardState extends State<_MyFeedbackCard> {
  late bool _unread;

  @override
  void initState() {
    super.initState();
    _unread = _hasUnreadReply(widget.item);
  }

  @override
  void didUpdateWidget(covariant _MyFeedbackCard old) {
    super.didUpdateWidget(old);
    if (old.item.id != widget.item.id ||
        old.item.adminReplyAt != widget.item.adminReplyAt ||
        old.item.replyReadByReporter != widget.item.replyReadByReporter) {
      _unread = _hasUnreadReply(widget.item);
    }
  }

  bool _hasUnreadReply(AppFeedbackItem item) =>
      (item.adminReply ?? '').isNotEmpty && !item.replyReadByReporter;

  Future<void> _markRead() async {
    if (!_unread) return;
    setState(() => _unread = false);
    try {
      await widget.service.markReplyRead(feedbackId: widget.item.id);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final hasReply = (item.adminReply ?? '').isNotEmpty;

    return GestureDetector(
      onTap: _markRead,
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        color: AppPalette.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: _unread ? AppPalette.deepBlue : AppPalette.border,
            width: _unread ? 2 : 1,
          ),
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
                if (_unread) ...[
                  Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: const BoxDecoration(
                      color: AppPalette.deepBlue,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
                _StatusBadge(status: item.status),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _formatDate(item.createdAt),
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
              ],
            ),
            if (hasReply) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppPalette.deepBlue.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppPalette.deepBlue.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.reply_rounded,
                            size: 16, color: AppPalette.deepBlue),
                        const SizedBox(width: 6),
                        const Text(
                          'Admin Response',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
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
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.adminReply!,
                      style: const TextStyle(
                        color: AppPalette.charcoal,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const SizedBox(height: 12),
              const Text(
                'Awaiting admin response...',
                style: TextStyle(
                  color: AppPalette.mutedText,
                  fontStyle: FontStyle.italic,
                  fontSize: 13,
                ),
              ),
            ],
          ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime value) {
    final d = value.day.toString().padLeft(2, '0');
    final m = value.month.toString().padLeft(2, '0');
    final y = value.year.toString();
    return '$d/$m/$y';
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
        _statusLabel(status),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }

  String _statusLabel(String value) {
    switch (value) {
      case 'pending_triage':
        return 'Pending';
      case 'in_progress':
        return 'In Progress';
      case 'resolved':
        return 'Resolved';
      case 'wont_fix':
        return 'Won\'t Fix';
      default:
        return value;
    }
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
  const _MetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppPalette.background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, color: AppPalette.charcoal),
      ),
    );
  }
}
