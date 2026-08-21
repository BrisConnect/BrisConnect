import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:brisconnect/models/admin_ai_alert_record.dart';
import 'package:brisconnect/services/admin_ai_alert_service.dart';
import 'package:brisconnect/features/admin/dashboard/admin_neon_theme.dart';

/// Manages the display and lifecycle of AI alert popups on the admin dashboard.
///
/// On desktop: Shows compact popup cards stacked in the top-right corner.
/// On mobile: Shows a dismissible top banner or bottom sheet.
class AdminAiAlertPopupManager extends StatefulWidget {
  final AdminAiAlertService alertService;
  final Function(String route)? onNavigate;

  const AdminAiAlertPopupManager({
    super.key,
    required this.alertService,
    this.onNavigate,
  });

  @override
  State<AdminAiAlertPopupManager> createState() => _AdminAiAlertPopupManagerState();
}

class _AdminAiAlertPopupManagerState extends State<AdminAiAlertPopupManager> {
  final Set<String> _dismissedAlertIds = {};
  final Set<String> _expandedAlertIds = {};

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width > 1024;

    return StreamBuilder<List<AdminAiAlertRecord>>(
      stream: widget.alertService.watchActiveAlerts(limit: 10),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final alerts = snapshot.data ?? [];
        final activeAlerts = alerts
            .where((a) => !_dismissedAlertIds.contains(a.id))
            .toList();

        if (activeAlerts.isEmpty) return const SizedBox.shrink();

        // On desktop: Stack popups in top-right
        if (isDesktop) {
          return Positioned(
            top: 80,
            right: 16,
            width: 380,
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height - 160,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: activeAlerts
                      .take(3) // Limit to 3 visible popups
                      .map((alert) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildAlertCard(alert),
                          ))
                      .toList(),
                ),
              ),
            ),
          );
        }

        // On mobile: Show as top banner
        return Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _buildMobileAlertBanner(activeAlerts.first),
        );
      },
    );
  }

  Widget _buildAlertCard(AdminAiAlertRecord alert) {
    final isExpanded = _expandedAlertIds.contains(alert.id);

    return Container(
      decoration: BoxDecoration(
        color: AdminNeonTheme.glassSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: alert.severity.color.withValues(alpha: 0.6),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: alert.severity.color.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with severity badge
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Severity icon
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: alert.severity.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        alert.severity.icon,
                        size: 14,
                        color: alert.severity.color,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Severity label and "BrisConnect AI"
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'BrisConnect AI • ${alert.severity.label}',
                            style: TextStyle(
                              color: AdminNeonTheme.textMuted,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            alert.title,
                            style: const TextStyle(
                              color: AdminNeonTheme.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Dismiss button
                    IconButton(
                      onPressed: () => _dismissAlert(alert.id),
                      icon: const Icon(Icons.close_rounded, size: 16),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                      color: AdminNeonTheme.textMuted,
                      tooltip: 'Dismiss',
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Explanation and metadata
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.explanation,
                  style: const TextStyle(
                    color: AdminNeonTheme.textSecondary,
                    fontSize: 12,
                    height: 1.4,
                  ),
                  maxLines: isExpanded ? null : 2,
                  overflow: isExpanded ? null : TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 12,
                      color: AdminNeonTheme.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('HH:mm').format(alert.createdAt),
                      style: const TextStyle(
                        color: AdminNeonTheme.textMuted,
                        fontSize: 11,
                      ),
                    ),
                    if (alert.duplicateCount > 1) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: alert.severity.color.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '+${alert.duplicateCount - 1}',
                          style: TextStyle(
                            color: alert.severity.color,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Expandable details
          if (isExpanded && alert.alertReason != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AdminNeonTheme.bgDeepNavy,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Why this alert',
                      style: TextStyle(
                        color: AdminNeonTheme.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      alert.alertReason!,
                      style: const TextStyle(
                        color: AdminNeonTheme.textMuted,
                        fontSize: 11,
                        height: 1.3,
                      ),
                    ),
                    if (alert.recommendations.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Recommendations',
                        style: TextStyle(
                          color: AdminNeonTheme.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      ...alert.recommendations.take(2).map((rec) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '• ',
                                  style: TextStyle(
                                    color: alert.severity.color,
                                    fontSize: 11,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    rec,
                                    style: const TextStyle(
                                      color: AdminNeonTheme.textMuted,
                                      fontSize: 11,
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )),
                    ],
                  ],
                ),
              ),
            ),

          // Action buttons
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Expand/collapse details
                if (alert.alertReason != null)
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        if (_expandedAlertIds.contains(alert.id)) {
                          _expandedAlertIds.remove(alert.id);
                        } else {
                          _expandedAlertIds.add(alert.id);
                        }
                      });
                    },
                    icon: Icon(
                      isExpanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      size: 14,
                    ),
                    label: Text(isExpanded ? 'Hide Details' : 'View Details'),
                    style: TextButton.styleFrom(
                      foregroundColor: alert.severity.color,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                    ),
                  ),

                // Primary action button
                if (alert.actionRoute != null)
                  SizedBox(
                    height: 32,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _markAsRead(alert.id);
                        widget.onNavigate?.call(alert.actionRoute!);
                      },
                      icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                      label: const Text('Review'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: alert.severity.color,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileAlertBanner(AdminAiAlertRecord alert) {
    return Container(
      color: alert.severity.color.withValues(alpha: 0.15),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      child: Row(
        children: [
          Icon(alert.severity.icon, size: 18, color: alert.severity.color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  alert.title,
                  style: TextStyle(
                    color: alert.severity.color,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  alert.explanation,
                  style: TextStyle(
                    color: alert.severity.color.withValues(alpha: 0.8),
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _dismissAlert(alert.id),
            icon: const Icon(Icons.close_rounded, size: 16),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  void _dismissAlert(String alertId) {
    setState(() => _dismissedAlertIds.add(alertId));
    widget.alertService.dismissAlert(alertId);
  }

  void _markAsRead(String alertId) {
    widget.alertService.markAlertAsRead(alertId);
  }
}
