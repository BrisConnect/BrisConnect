import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:brisconnect/auth/admin_auth.dart';
import 'package:brisconnect/services/local_email_notification_service.dart';
import 'package:brisconnect/services/sms_notification_service.dart';
import 'package:brisconnect/theme/app_palette.dart';

/// Shared helpers for the admin portal.
///
/// These utilities intentionally preserve the existing behavior and visual
/// style of each admin screen while removing duplicated code.
class AdminUtils {
  AdminUtils._();

  /// Returns the current admin email, or null if unavailable.
  static String? get currentAdminEmail => AdminAuth.currentAdminEmail;

  /// Opens [url] in the system browser, if it can be launched.
  static Future<bool> openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      return launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }

  /// Shows a SnackBar using the admin portal's existing style.
  static void showSnack(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : null,
      ),
    );
  }

  /// Runs an async action with the standard admin loading/error/success flow.
  ///
  /// The caller is responsible for managing any loading state that must be
  /// visible in the UI (e.g., buttons). This helper only handles snackbars.
  static Future<void> runAction(
    BuildContext context,
    Future<void> Function() action, {
    String? success,
    String? errorPrefix,
  }) async {
    try {
      await action();
      if (context.mounted && success != null && success.isNotEmpty) {
        showSnack(context, success);
      }
    } catch (error) {
      if (context.mounted) {
        final prefix = errorPrefix ?? 'Action failed';
        showSnack(context, '$prefix: $error', isError: true);
      }
    }
  }

  /// Shows a simple reason-input dialog used across moderation and business
  /// management screens.
  static Future<String?> showReasonDialog(
    BuildContext context, {
    required String title,
    String hintText = 'Reason (required)',
    bool barrierDismissible = true,
  }) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: hintText,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  /// Shows a confirmation dialog with cancel and a customizable confirm action.
  static Future<bool> showConfirmDialog(
    BuildContext context, {
    required String title,
    required String content,
    String cancelText = 'Cancel',
    String confirmText = 'Confirm',
    Color? confirmColor,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(cancelText),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: confirmColor != null
                ? TextButton.styleFrom(foregroundColor: confirmColor)
                : null,
            child: Text(confirmText),
          ),
        ],
      ),
    );
    return result == true;
  }

  /// Shows the audience-selection dialog shared by email and SMS broadcasts.
  static Future<void> showAudienceDialog(
    BuildContext context, {
    required String title,
    required String? selectedAudience,
    required List<Map<String, String>> locals,
    required bool isSending,
    required ValueChanged<String?> onSelected,
  }) async {
    final audienceOptions = <Map<String, String>>[
      {'value': 'visitors', 'label': 'All Visitors'},
      ...locals.map((local) => {
            'value': 'local:${local['email'] ?? ''}',
            'label': '${local['name'] ?? ''} (${local['email'] ?? ''})',
          }),
    ];

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: audienceOptions.map((option) {
              final value = option['value']!;
              final label = option['label']!;
              final isSelected = selectedAudience == value;
              return ListTile(
                leading: Checkbox(
                  value: isSelected,
                  onChanged: isSending
                      ? null
                      : (_) {
                          onSelected(value);
                          Navigator.of(ctx).pop();
                        },
                ),
                title: Text(label),
                onTap: isSending
                    ? null
                    : () {
                        onSelected(value);
                        Navigator.of(ctx).pop();
                      },
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// Displays audience label from current selection and loaded locals.
  static String audienceDisplayText(
    String? audience,
    List<Map<String, String>> locals,
  ) {
    if (audience == null) return 'Select Audience';
    if (audience == 'visitors') return 'All Visitors';
    final match = locals.firstWhere(
      (local) => audience == 'local:${local['email']}',
      orElse: () => {'name': '', 'email': ''},
    );
    return match['name'] ?? 'All Visitors';
  }

  /// Queues email and SMS review notifications for a local account.
  ///
  /// Failures are swallowed so the approval/rejection action remains
  /// successful even if notification queueing fails.
  static Future<void> queueAccountReviewNotifications({
    required LocalEmailNotificationService emailService,
    required SmsNotificationService smsService,
    required String email,
    required String? phone,
    required String businessName,
    required bool approved,
  }) async {
    try {
      await emailService.queueAccountReviewEmail(
        recipientEmail: email,
        businessName: businessName,
        approved: approved,
      );
    } catch (_) {
      // Keep action successful even if email queueing fails.
    }

    try {
      final mobile = phone?.trim() ?? '';
      if (mobile.isNotEmpty) {
        await smsService.queueLocalAccountReviewSms(
          recipientPhone: mobile,
          businessName: businessName,
          approved: approved,
        );
      }
    } catch (_) {
      // Keep action successful even if SMS queueing fails.
    }
  }
}

/// A reusable FilterChip used by admin screens that need a simple string
/// selection filter.
class AdminFilterChip extends StatelessWidget {
  final String label;
  final String value;
  final String selected;
  final ValueChanged<String> onSelected;

  const AdminFilterChip({
    super.key,
    required this.label,
    required this.value,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = selected == value;
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: isSelected ? Colors.white : AppPalette.charcoal,
        ),
      ),
      selected: isSelected,
      onSelected: (_) => onSelected(value),
      selectedColor: AppPalette.ochre,
      backgroundColor: AppPalette.surface,
      checkmarkColor: Colors.white,
      side: BorderSide(
        color: isSelected
            ? AppPalette.ochre
            : AppPalette.border.withValues(alpha: 0.6),
      ),
    );
  }
}

/// A styled filter chip used by user management and similar screens.
class AdminStyledFilterChip extends StatelessWidget {
  final IconData? icon;
  final Color? iconColor;
  final Color? dotColor;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const AdminStyledFilterChip({
    super.key,
    this.icon,
    this.iconColor,
    this.dotColor,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppPalette.ochre
              : AppPalette.surface.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? AppPalette.ochre
                : AppPalette.border.withValues(alpha: 0.6),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dotColor != null) ...[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: selected ? Colors.white : dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
            ] else if (icon != null) ...[
              Icon(icon,
                  size: 16,
                  color: selected
                      ? Colors.white
                      : (iconColor ?? AppPalette.mutedText)),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : AppPalette.charcoal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mixin that provides common admin state helpers for StatefulWidgets.
///
/// Keeps behavior identical to the inline patterns previously used in each
/// screen.
mixin AdminScreenMixin<T extends StatefulWidget> on State<T> {
  bool isLoading = false;

  /// Shows a snackbar using the admin portal style.
  void showAdminSnack(String message, {bool isError = false}) {
    AdminUtils.showSnack(context, message, isError: isError);
  }

  /// Runs an action while toggling [isLoading] around it.
  Future<void> runAdminAction(
    Future<void> Function() action, {
    String? success,
    String? errorPrefix,
    VoidCallback? onDone,
  }) async {
    if (!mounted) return;
    setState(() => isLoading = true);
    try {
      await action();
      if (mounted && success != null && success.isNotEmpty) {
        showAdminSnack(success);
      }
    } catch (error) {
      if (mounted) {
        final prefix = errorPrefix ?? 'Action failed';
        showAdminSnack('$prefix: $error', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
      onDone?.call();
    }
  }

  /// Gets the current admin email or shows an error if unavailable.
  String? requireAdminEmail() {
    final email = AdminUtils.currentAdminEmail;
    if (email == null || email.isEmpty) {
      showAdminSnack('Admin email not available.', isError: true);
      return null;
    }
    return email;
  }
}
