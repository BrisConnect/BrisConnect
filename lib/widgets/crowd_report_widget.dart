import 'package:flutter/material.dart';
import 'package:brisconnect/services/crowd_report_service.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:intl/intl.dart';

class CrowdReportWidget extends StatefulWidget {
  final String eventId;
  final CrowdReportService? crowdReportService;

  const CrowdReportWidget({
    super.key,
    required this.eventId,
    this.crowdReportService,
  });

  @override
  State<CrowdReportWidget> createState() => _CrowdReportWidgetState();
}

class _CrowdReportWidgetState extends State<CrowdReportWidget> {
  late final CrowdReportService _service;
  CrowdLevel? _selected;
  bool _submitting = false;
  bool _submitted = false;
  bool _onCooldown = false;

  @override
  void initState() {
    super.initState();
    _service = widget.crowdReportService ?? CrowdReportService();
    _checkCooldown();
  }

  Future<void> _checkCooldown() async {
    final canSubmit = await _service.canSubmitReport(widget.eventId);
    if (mounted) setState(() => _onCooldown = !canSubmit);
  }

  Future<void> _submit() async {
    if (_selected == null || _submitting) return;
    setState(() => _submitting = true);
    try {
      await _service.submitReport(widget.eventId, _selected!);
      if (!mounted) return;
      setState(() {
        _submitted = true;
        _submitting = false;
        _onCooldown = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Report submitted successfully'),
            ],
          ),
          backgroundColor: Colors.green[700],
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not submit report. Try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Color _levelColor(CrowdLevel level) {
    switch (level) {
      case CrowdLevel.low:
        return const Color(0xFF00D084);
      case CrowdLevel.moderate:
        return const Color(0xFFFFB900);
      case CrowdLevel.high:
        return const Color(0xFFE85C0D);
    }
  }

  IconData _levelIcon(CrowdLevel level) {
    switch (level) {
      case CrowdLevel.low:
        return Icons.people_outline;
      case CrowdLevel.moderate:
        return Icons.people;
      case CrowdLevel.high:
        return Icons.groups;
    }
  }

  String _levelDescription(CrowdLevel level) {
    switch (level) {
      case CrowdLevel.low:
        return 'Quiet – easy to move around';
      case CrowdLevel.moderate:
        return 'Moderate – some wait times';
      case CrowdLevel.high:
        return 'Busy – expect queues';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppPalette.ochre.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: AppPalette.ochre,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Crowd Level',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppPalette.charcoal,
                ),
              ),
              const Spacer(),
              const Icon(Icons.people_alt_outlined,
                  size: 20, color: AppPalette.mutedText),
            ],
          ),
          const SizedBox(height: 12),

          // Current crowd status from Firestore
          StreamBuilder<CrowdStatus?>(
            stream: _service.watchCrowdStatus(widget.eventId),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: LinearProgressIndicator(),
                );
              }
              final status = snap.data;
              if (status == null) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'No crowd reports yet. Be the first!',
                    style: TextStyle(
                      color: AppPalette.mutedText,
                      fontSize: 13,
                    ),
                  ),
                );
              }
              return _buildCurrentStatus(status);
            },
          ),

          const Divider(height: 24),

          // Report form
          if (_onCooldown && _submitted) ...[
            Row(
              children: [
                const Icon(Icons.check_circle,
                    color: Color(0xFF00D084), size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Thanks! Your report was submitted.',
                    style: TextStyle(color: AppPalette.charcoal, fontSize: 13),
                  ),
                ),
              ],
            ),
          ] else if (_onCooldown) ...[
            Row(
              children: [
                const Icon(Icons.timer_outlined,
                    color: AppPalette.mutedText, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'You can report again in 30 minutes.',
                    style: TextStyle(color: AppPalette.mutedText, fontSize: 13),
                  ),
                ),
              ],
            ),
          ] else ...[
            const Text(
              'How busy is it right now?',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppPalette.charcoal,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: CrowdLevel.values.map((level) {
                final isSelected = _selected == level;
                final color = _levelColor(level);
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: GestureDetector(
                      onTap: () => setState(() => _selected = level),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? color.withValues(alpha: 0.15)
                              : AppPalette.surfaceAlt,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected ? color : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(_levelIcon(level),
                                color: isSelected ? color : AppPalette.mutedText,
                                size: 22),
                            const SizedBox(height: 4),
                            Text(
                              level.label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isSelected ? color : AppPalette.mutedText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            if (_selected != null) ...[
              const SizedBox(height: 8),
              Text(
                _levelDescription(_selected!),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppPalette.mutedText,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selected == null || _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppPalette.ochre,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      AppPalette.mutedText.withValues(alpha: 0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: _submitting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Submit Report',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCurrentStatus(CrowdStatus status) {
    final color = _levelColor(status.level);
    final icon = _levelIcon(status.level);
    final timeAgo = _formatRelative(status.lastReported);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${status.level.label} Crowd',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${status.reportCount} report${status.reportCount == 1 ? '' : 's'}',
                        style: TextStyle(
                          fontSize: 11,
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  'Updated $timeAgo',
                  style: const TextStyle(
                    color: AppPalette.mutedText,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          // Crowd bar indicator
          _CrowdBar(level: status.level),
        ],
      ),
    );
  }

  String _formatRelative(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return DateFormat('h:mm a').format(dt);
  }
}

class _CrowdBar extends StatelessWidget {
  final CrowdLevel level;

  const _CrowdBar({required this.level});

  @override
  Widget build(BuildContext context) {
    final filledBars = level.weight; // 1, 2, or 3
    final colors = [
      const Color(0xFF00D084),
      const Color(0xFFFFB900),
      const Color(0xFFE85C0D),
    ];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final filled = i < filledBars;
        return Container(
          width: 6,
          height: 14 + (i * 4.0),
          margin: const EdgeInsets.symmetric(horizontal: 1.5),
          decoration: BoxDecoration(
            color: filled ? colors[level.weight - 1] : Colors.grey[300],
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}
