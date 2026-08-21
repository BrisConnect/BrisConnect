import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:brisconnect/models/google_listing_monitoring_result.dart';
import 'package:brisconnect/services/google_listing_monitoring_service.dart';
import 'package:brisconnect/features/admin/dashboard/admin_neon_theme.dart';

/// Admin screen for reviewing and accepting/rejecting Google listing changes
class AdminGoogleListingReviewScreen extends StatefulWidget {
  final GoogleListingMonitoringResult monitoringResult;
  final VoidCallback? onReviewComplete;

  const AdminGoogleListingReviewScreen({
    super.key,
    required this.monitoringResult,
    this.onReviewComplete,
  });

  @override
  State<AdminGoogleListingReviewScreen> createState() =>
      _AdminGoogleListingReviewScreenState();
}

class _AdminGoogleListingReviewScreenState
    extends State<AdminGoogleListingReviewScreen> {
  late GoogleListingMonitoringService _service;
  bool _isProcessing = false;
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _service = GoogleListingMonitoringService();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _acceptChanges() async {
    setState(() => _isProcessing = true);
    try {
      await _service.acceptGoogleChanges(
        widget.monitoringResult.id,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Changes accepted for ${widget.monitoringResult.businessName}'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onReviewComplete?.call();
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _rejectChanges() async {
    setState(() => _isProcessing = true);
    try {
      await _service.rejectGoogleChanges(
        widget.monitoringResult.id,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Changes rejected for ${widget.monitoringResult.businessName}'),
            backgroundColor: Colors.orange,
          ),
        );
        widget.onReviewComplete?.call();
        Navigator.pop(context, false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _ignoreRecord() async {
    setState(() => _isProcessing = true);
    try {
      await _service.ignoreMonitoringRecord(
        widget.monitoringResult.id,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Record marked as ignored'),
            backgroundColor: Colors.grey,
          ),
        );
        widget.onReviewComplete?.call();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.monitoringResult;
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Scaffold(
      backgroundColor: AdminNeonTheme.bgDeepNavy,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AdminNeonTheme.bgDeepNavy,
        foregroundColor: AdminNeonTheme.textPrimary,
        title: Text('Review: ${result.businessName}'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Alert banner for critical issues
            if (result.severity == GoogleListingSeverity.critical)
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.2),
                  border: Border.all(color: Colors.red),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_rounded, color: Colors.red, size: 28),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '🚨 CRITICAL ALERT',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          if (result.googleData?.isClosed ?? false)
                            Text(
                              'Business is marked CLOSED on Google',
                              style: TextStyle(color: Colors.red[300]),
                            )
                          else
                            Text(
                              'Critical business information differs',
                              style: TextStyle(color: Colors.red[300]),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            SizedBox(height: 20),

            // Business info header
            _buildBusinessInfoHeader(result),
            SizedBox(height: 24),

            // Comparison section
            if (result.hasChanges && result.changes.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Detected Changes',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AdminNeonTheme.textPrimary,
                    ),
                  ),
                  SizedBox(height: 16),
                  ...result.changes.entries.map((e) =>
                      _buildFieldComparison(e.key, e.value, isMobile)),
                  SizedBox(height: 24),
                ],
              )
            else if (!result.hasChanges)
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  border: Border.all(color: Colors.green),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 24),
                    SizedBox(width: 12),
                    Text(
                      'No differences detected between BrisConnect and Google',
                      style: TextStyle(color: Colors.green[300]),
                    ),
                  ],
                ),
              ),

            // Admin notes section
            SizedBox(height: 20),
            Text(
              'Admin Notes (Optional)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AdminNeonTheme.textPrimary,
              ),
            ),
            SizedBox(height: 8),
            TextField(
              controller: _notesController,
              maxLines: 3,
              enabled: !_isProcessing,
              decoration: InputDecoration(
                hintText: 'Add notes about your decision...',
                hintStyle: TextStyle(color: Colors.grey[500]),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AdminNeonTheme.neonBlue),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AdminNeonTheme.neonBlue, width: 0.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AdminNeonTheme.neonBlue),
                ),
              ),
              style: TextStyle(color: AdminNeonTheme.textPrimary),
            ),

            // Action buttons
            SizedBox(height: 32),
            _buildActionButtons(result),
          ],
        ),
      ),
    );
  }

  Widget _buildBusinessInfoHeader(GoogleListingMonitoringResult result) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.withValues(alpha: 0.1), Colors.purple.withValues(alpha: 0.1)],
        ),
        border: Border.all(color: AdminNeonTheme.neonBlue, width: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                result.businessName,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AdminNeonTheme.textPrimary,
                ),
              ),
              SizedBox(width: 12),
              _buildSeverityBadge(result.severity),
            ],
          ),
          SizedBox(height: 12),
          Text(
            'Business ID: ${result.businessId}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[400],
              fontFamily: 'monospace',
            ),
          ),
          Text(
            'Google Place ID: ${result.googlePlaceId}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[400],
              fontFamily: 'monospace',
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Last Checked: ${DateFormat('MMM d, y · h:mm a').format(result.checkTimestamp)}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldComparison(
    String fieldName,
    GoogleListingChange change,
    bool isMobile,
  ) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[700]!),
        borderRadius: BorderRadius.circular(8),
        color: Colors.black.withValues(alpha: 0.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Field name header
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: change.differs
                  ? Colors.orange.withValues(alpha: 0.2)
                  : Colors.green.withValues(alpha: 0.2),
              border: Border(
                bottom: BorderSide(
                  color: change.differs ? Colors.orange : Colors.green,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  change.differs ? Icons.warning_rounded : Icons.check_circle,
                  color: change.differs ? Colors.orange : Colors.green,
                  size: 18,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    fieldName.toUpperCase(),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AdminNeonTheme.textPrimary,
                    ),
                  ),
                ),
                if (change.differs)
                  Text(
                    '${(change.similarity * 100).toStringAsFixed(0)}% match',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.orange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),

          // Comparison content
          Padding(
            padding: EdgeInsets.all(12),
            child: isMobile
                ? _buildMobileComparison(change)
                : _buildDesktopComparison(change),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopComparison(GoogleListingChange change) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'BRISCONNECT',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[300],
                ),
              ),
              SizedBox(height: 6),
              Text(
                change.brisconnectValue,
                style: TextStyle(
                  fontSize: 14,
                  color: AdminNeonTheme.textPrimary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            '↔',
            style: TextStyle(
              fontSize: 20,
              color: Colors.orange,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'GOOGLE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.red[300],
                ),
              ),
              SizedBox(height: 6),
              Text(
                change.googleValue,
                style: TextStyle(
                  fontSize: 14,
                  color: AdminNeonTheme.textPrimary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileComparison(GoogleListingChange change) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'BRISCONNECT',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.blue[300],
          ),
        ),
        SizedBox(height: 6),
        Container(
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            change.brisconnectValue,
            style: TextStyle(
              fontSize: 13,
              color: AdminNeonTheme.textPrimary,
            ),
          ),
        ),
        SizedBox(height: 12),
        Text(
          'GOOGLE',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.red[300],
          ),
        ),
        SizedBox(height: 6),
        Container(
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            change.googleValue,
            style: TextStyle(
              fontSize: 13,
              color: AdminNeonTheme.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSeverityBadge(GoogleListingSeverity severity) {
    final colors = {
      GoogleListingSeverity.info: (Colors.blue, Colors.blue[300] ?? Colors.blue),
      GoogleListingSeverity.attention: (Colors.orange, Colors.orange[300] ?? Colors.orange),
      GoogleListingSeverity.critical: (Colors.red, Colors.red[300] ?? Colors.red),
    };

    final (bgColor, textColor) = colors[severity]!;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor.withValues(alpha: 0.2),
        border: Border.all(color: textColor),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        severity.label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildActionButtons(GoogleListingMonitoringResult result) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    if (isMobile) {
      return Column(
        children: [
          if (result.hasChanges) ...[
            _buildActionButton(
              label: '✅ Accept Google Changes',
              onPressed: _acceptChanges,
              isLoading: _isProcessing,
              backgroundColor: Colors.green,
            ),
            SizedBox(height: 12),
            _buildActionButton(
              label: '❌ Reject & Keep BrisConnect',
              onPressed: _rejectChanges,
              isLoading: _isProcessing,
              backgroundColor: Colors.orange,
            ),
            SizedBox(height: 12),
          ],
          _buildActionButton(
            label: '⏭️ Ignore This Record',
            onPressed: _ignoreRecord,
            isLoading: _isProcessing,
            backgroundColor: Colors.grey[700]!,
          ),
        ],
      );
    } else {
      return Row(
        children: [
          if (result.hasChanges) ...[
            Expanded(
              child: _buildActionButton(
                label: '✅ Accept Google Changes',
                onPressed: _acceptChanges,
                isLoading: _isProcessing,
                backgroundColor: Colors.green,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                label: '❌ Reject & Keep BrisConnect',
                onPressed: _rejectChanges,
                isLoading: _isProcessing,
                backgroundColor: Colors.orange,
              ),
            ),
            SizedBox(width: 12),
          ],
          Expanded(
            child: _buildActionButton(
              label: '⏭️ Ignore This Record',
              onPressed: _ignoreRecord,
              isLoading: _isProcessing,
              backgroundColor: Colors.grey[700]!,
            ),
          ),
        ],
      );
    }
  }

  Widget _buildActionButton({
    required String label,
    required VoidCallback onPressed,
    required bool isLoading,
    required Color backgroundColor,
  }) {
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(vertical: 14),
        disabledBackgroundColor: backgroundColor.withValues(alpha: 0.5),
      ),
      child: isLoading
          ? SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(Colors.white),
              ),
            )
          : Text(
              label,
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
    );
  }
}
