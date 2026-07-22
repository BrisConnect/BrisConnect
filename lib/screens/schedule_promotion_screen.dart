import 'package:flutter/material.dart';
import 'package:brisconnect/auth/local_auth.dart';
import 'package:brisconnect/models/promotion_schedule.dart';
import 'package:brisconnect/services/best_time_to_post_service.dart';
import 'package:brisconnect/theme/app_palette.dart';

/// Screen for scheduling a new promotion with best-time-to-post guidance.
class SchedulePromotionScreen extends StatefulWidget {
  final BestTimeToPostService? bestTimeService;

  const SchedulePromotionScreen({super.key, this.bestTimeService});

  @override
  State<SchedulePromotionScreen> createState() =>
      _SchedulePromotionScreenState();
}

class _SchedulePromotionScreenState extends State<SchedulePromotionScreen> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  DateTime _scheduledAt = DateTime.now().add(const Duration(hours: 1));
  bool _isLoadingRecommendations = true;
  BestTimeToPostResult? _recommendationResult;
  String? _softWarning;
  bool _ignoreWarning = false;

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
  }

  Future<void> _loadRecommendations() async {
    final ownerId = LocalAuth.currentLocal?.email ?? '';
    if (ownerId.trim().isEmpty) {
      setState(() => _isLoadingRecommendations = false);
      return;
    }

    final result = await (widget.bestTimeService ?? BestTimeToPostService())
        .getRecommendations(ownerId);

    if (!mounted) return;
    setState(() {
      _recommendationResult = result;
      _isLoadingRecommendations = false;
      _updateSoftWarning();
    });
  }

  void _updateSoftWarning() {
    final warning = BestTimeToPostService().warningForSchedule(
      _scheduledAt,
      _recommendationResult?.recommendations ?? const [],
    );
    setState(() {
      _softWarning = warning;
      if (warning == null) _ignoreWarning = false;
    });
  }

  Future<void> _pickScheduleDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledAt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppPalette.ochre,
            onPrimary: Colors.white,
            surface: Color(0xFF1C1C2E),
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledAt),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppPalette.ochre,
            onPrimary: Colors.white,
            surface: Color(0xFF1C1C2E),
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (time == null || !mounted) return;

    setState(() {
      _scheduledAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      _updateSoftWarning();
    });
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      _showSnackBar('Please enter a promotion title.');
      return;
    }

    final ownerId = LocalAuth.currentLocal?.email ?? '';
    if (ownerId.trim().isEmpty) {
      _showSnackBar('You must be signed in to schedule a promotion.');
      return;
    }

    // Soft warning confirmation if not yet acknowledged.
    if (_softWarning != null && !_ignoreWarning) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1C1C2E),
          title: const Text(
            'Timing Warning',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            _softWarning!,
            style: const TextStyle(color: Color(0xFF8B8FA8)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Change Time',
                  style: TextStyle(color: Colors.white70)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Schedule Anyway',
                  style: TextStyle(color: AppPalette.ochre)),
            ),
          ],
        ),
      );
      if (proceed != true || !mounted) return;
      setState(() => _ignoreWarning = true);
    }

    // Placeholder: record promotion without a real businessId mapping.
    // In production, the owner should pick a business from their profiles.
    final promotion = PromotionSchedule(
      businessId: 'placeholder',
      ownerId: ownerId,
      title: title,
      description: _descCtrl.text.trim(),
      scheduledAt: _scheduledAt,
      endAt: _scheduledAt.add(const Duration(days: 7)),
      status: PromotionStatus.scheduled,
      createdAt: DateTime.now(),
    );

    await (widget.bestTimeService ?? BestTimeToPostService())
        .recordScheduledPromotion(promotion);

    if (!mounted) return;
    _showSnackBar('Promotion scheduled for ${_formatDateTime(_scheduledAt)}');
    Navigator.of(context).pop();
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green[700],
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        title: const Text('Schedule Promotion'),
        backgroundColor: AppPalette.ochre,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildRecommendedTimes(),
              const SizedBox(height: 20),
              _buildForm(),
              const SizedBox(height: 20),
              if (_softWarning != null) _buildWarningCard(),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppPalette.ochre,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Schedule Promotion',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecommendedTimes() {
    if (_isLoadingRecommendations) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(color: AppPalette.ochre),
        ),
      );
    }

    final result = _recommendationResult;
    if (result == null || !result.hasEnoughData) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C2E),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            Icon(Icons.lightbulb_outline_rounded,
                color: AppPalette.ochre.withValues(alpha: 0.8)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                result?.insufficientDataReason ??
                    'No timing insights yet. Schedule whenever works for you.',
                style: const TextStyle(
                  color: Color(0xFF8B8FA8),
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppPalette.ochre.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recommended windows',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 10),
          ...result.recommendations.map(
            (rec) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: AppPalette.ochre, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${rec.dayLabel}s ${rec.timeRangeLabel}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField(
          controller: _titleCtrl,
          label: 'Promotion Title',
          hint: 'e.g. Weekend Burger Special',
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _descCtrl,
          label: 'Description (optional)',
          hint: 'Brief description of the promotion',
          maxLines: 3,
        ),
        const SizedBox(height: 16),
        InkWell(
          onTap: _pickScheduleDateTime,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C2E),
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Row(
              children: [
                const Icon(Icons.date_range_rounded,
                    color: AppPalette.ochre, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Scheduled Date & Time',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatDateTime(_scheduledAt),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.edit_rounded,
                    color: Color(0xFF8B8FA8), size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: Colors.white70),
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
        filled: true,
        fillColor: const Color(0xFF1C1C2E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              BorderSide(color: AppPalette.ochre.withValues(alpha: 0.5)),
        ),
      ),
    );
  }

  Widget _buildWarningCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFF39C12).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: Color(0xFFF39C12), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _softWarning!,
              style: const TextStyle(
                color: Color(0xFF8B8FA8),
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final period = date.hour < 12 ? 'am' : 'pm';
    final displayHour = date.hour == 0
        ? 12
        : date.hour > 12
            ? date.hour - 12
            : date.hour;
    final minute = date.minute.toString().padLeft(2, '0');
    return '${date.day} ${months[date.month - 1]} ${date.year} at '
        '$displayHour:$minute$period';
  }
}
