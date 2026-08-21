import 'package:flutter/material.dart';

import 'package:brisconnect/services/notification_permission_service.dart';

/// A dialog that prompts admin users to enable browser notifications.
/// Explains the benefits and provides "Enable" and "Not Now" options.
class NotificationPermissionDialog extends StatefulWidget {
  /// Callback when the user chooses to enable notifications
  final VoidCallback? onEnable;

  /// Callback when the user dismisses the dialog
  final VoidCallback? onDismiss;

  const NotificationPermissionDialog({
    super.key,
    this.onEnable,
    this.onDismiss,
  });

  @override
  State<NotificationPermissionDialog> createState() => _NotificationPermissionDialogState();
}

class _NotificationPermissionDialogState extends State<NotificationPermissionDialog> {
  bool _isLoading = false;

  void _handleEnable() async {
    setState(() => _isLoading = true);

    final permissionGranted = await NotificationPermissionService.instance.requestPermission();

    if (permissionGranted) {
      debugPrint('[NotificationPermissionDialog] Permission granted');
      widget.onEnable?.call();
      if (mounted) Navigator.of(context).pop();
    } else {
      debugPrint('[NotificationPermissionDialog] Permission not granted');
      // Mark as dismissed even if user didn't explicitly allow
      await NotificationPermissionService.instance.markPromptAsDismissed();
      widget.onDismiss?.call();
      if (mounted) Navigator.of(context).pop();
    }
  }

  void _handleDismiss() async {
    await NotificationPermissionService.instance.markPromptAsDismissed();
    widget.onDismiss?.call();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.notifications_active, color: Color(0xFFFF7A29)),
          SizedBox(width: 12),
          Text(
            'Enable Notifications',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFFFFFFFF),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Stay updated with important admin alerts and insights. Notifications help you:',
              style: TextStyle(
                color: Color(0xFFC3CCEA),
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            _buildFeatureItem('🤖 AI Insights', 'Get smart alerts and recommendations'),
            _buildFeatureItem('🚨 Reports', 'Receive user and content reports instantly'),
            _buildFeatureItem('📍 Google Listings', 'Monitor changes to your business profile'),
            _buildFeatureItem('⚕️ System Health', 'Stay aware of notification delivery issues'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0B1226).withValues(alpha: 0.5),
                border: Border.all(
                  color: const Color(0xFF2FA8FF).withValues(alpha: 0.3),
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Notifications work best when the admin portal is open or in the background. Your browser must have notification permissions enabled.',
                style: TextStyle(
                  color: Color(0xFF8E98BE),
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
      backgroundColor: const Color(0xFF060A16),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : _handleDismiss,
          child: const Text(
            'Not Now',
            style: TextStyle(color: Color(0xFF8E98BE)),
          ),
        ),
        ElevatedButton.icon(
          onPressed: _isLoading ? null : _handleEnable,
          icon: _isLoading
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                )
              : const Icon(Icons.notifications, size: 18),
          label: Text(_isLoading ? 'Enabling...' : 'Enable Notifications'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF7A29),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFFFFFFFF),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(
              color: Color(0xFFC3CCEA),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// A compact banner shown when notification permission is denied.
/// Explains how to re-enable through browser settings.
class NotificationDeniedBanner extends StatefulWidget {
  /// Callback when the banner is dismissed
  final VoidCallback? onDismiss;

  const NotificationDeniedBanner({
    super.key,
    this.onDismiss,
  });

  @override
  State<NotificationDeniedBanner> createState() => _NotificationDeniedBannerState();
}

class _NotificationDeniedBannerState extends State<NotificationDeniedBanner> {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2D1A15),
        border: Border.all(
          color: const Color(0xFFFF7A29).withValues(alpha: 0.4),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.only(right: 12),
            child: Icon(
              Icons.notifications_off,
              color: Color(0xFFFF7A29),
              size: 20,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Notifications Disabled',
                  style: TextStyle(
                    color: Color(0xFFFFFFFF),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Re-enable in browser settings (🔒 > Notifications > Allow)',
                  style: TextStyle(
                    color: Color(0xFFC3CCEA),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: Color(0xFF8E98BE)),
            onPressed: () {
              widget.onDismiss?.call();
              setState(() {});
            },
            padding: const EdgeInsets.all(0),
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}
