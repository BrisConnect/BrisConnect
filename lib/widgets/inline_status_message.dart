import 'package:flutter/material.dart';
import 'package:brisconnect/theme/app_palette.dart';

enum InlineStatusType { error, success, info }

class InlineStatusMessage extends StatelessWidget {
  final String message;
  final InlineStatusType type;
  final String? actionLabel;
  final VoidCallback? onAction;

  const InlineStatusMessage({
    super.key,
    required this.message,
    this.type = InlineStatusType.error,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final _StatusColors colors = switch (type) {
      InlineStatusType.error => const _StatusColors(
          background: Color(0xFFFFF1F1),
          border: Color(0xFFFFD1D1),
          foreground: Color(0xFF9E1B1B),
          icon: Icons.error_outline,
        ),
      InlineStatusType.success => const _StatusColors(
          background: Color(0xFFEAF9EE),
          border: Color(0xFFC0E8CB),
          foreground: Color(0xFF1E6A3A),
          icon: Icons.check_circle_outline,
        ),
      InlineStatusType.info => const _StatusColors(
          background: Color(0xFFEFF5FF),
          border: Color(0xFFCFE0FF),
          foreground: AppPalette.deepBlue,
          icon: Icons.info_outline,
        ),
    };

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.background,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(colors.icon, size: 18, color: colors.foreground),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: colors.foreground,
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
          ),
          if (onAction != null && actionLabel != null) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: colors.foreground,
                minimumSize: const Size(0, 32),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusColors {
  final Color background;
  final Color border;
  final Color foreground;
  final IconData icon;

  const _StatusColors({
    required this.background,
    required this.border,
    required this.foreground,
    required this.icon,
  });
}
