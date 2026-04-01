import 'package:flutter/material.dart';
import 'package:brisconnect/services/report_event_service.dart';
import 'package:brisconnect/theme/app_palette.dart';

class ReportEventDialog extends StatefulWidget {
  final String eventId;
  final String visitorEmail;
  final ReportEventService reportService;

  ReportEventDialog({
    super.key,
    required this.eventId,
    required this.visitorEmail,
    ReportEventService? reportService,
  }) : reportService = reportService ?? _DefaultReportService();

  @override
  State<ReportEventDialog> createState() => _ReportEventDialogState();

  static Future<bool?> show({
    required BuildContext context,
    required String eventId,
    required String visitorEmail,
    ReportEventService? reportService,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => ReportEventDialog(
        eventId: eventId,
        visitorEmail: visitorEmail,
        reportService: reportService,
      ),
    );
  }
}

class _ReportEventDialogState extends State<ReportEventDialog> {
  late String _selectedReason;
  final _commentsController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedReason = ReportEventService.reportReasons.first;
  }

  @override
  void dispose() {
    _commentsController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await widget.reportService.submitReport(
        eventId: widget.eventId,
        visitorEmail: widget.visitorEmail,
        reason: _selectedReason,
        comments: _commentsController.text.isEmpty ? null : _commentsController.text,
      );

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report submitted successfully. Thank you for helping keep our community safe.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = error.toString();
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Report Event'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Help us keep the community safe by reporting inappropriate events.',
              style: TextStyle(fontSize: 13, color: AppPalette.charcoal),
            ),
            const SizedBox(height: 16),
            const Text(
              'Reason for Report',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            RadioGroup<String>(
              groupValue: _selectedReason,
              onChanged: (value) {
                if (_isSubmitting || value == null) {
                  return;
                }
                setState(() => _selectedReason = value);
              },
              child: Column(
                children: ReportEventService.reportReasons.map((reason) {
                  return RadioListTile<String>(
                    title: Text(ReportEventService.getReasonLabel(reason)),
                    value: reason,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Additional Details (Optional)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _commentsController,
              maxLines: 4,
              maxLength: 500,
              enabled: !_isSubmitting,
              decoration: InputDecoration(
                hintText: 'Please provide any additional information...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submitReport,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Submit Report'),
        ),
      ],
    );
  }
}

class _DefaultReportService extends ReportEventService {
  _DefaultReportService();
}
