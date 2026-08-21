import 'package:flutter/material.dart';
import 'package:brisconnect/auth/admin_auth.dart';
import 'package:brisconnect/features/admin/dashboard/admin_neon_theme.dart';
import 'package:brisconnect/features/admin/dashboard/widgets/admin_notification_bell.dart';

class AdminHeader extends StatelessWidget {
  const AdminHeader({
    super.key,
    required this.showMenuButton,
    required this.onMenuPressed,
    this.showWelcomeText = false,
    this.showDashboardTitle = false,
  });

  final bool showMenuButton;
  final VoidCallback onMenuPressed;
  final bool showWelcomeText;
  final bool showDashboardTitle;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dateLabel =
        '${_dayName(now.weekday)}, ${now.day} ${_monthName(now.month)} ${now.year}';
    final isDesktop = MediaQuery.sizeOf(context).width > 1024;

    return Container(
      decoration: BoxDecoration(
        color: AdminNeonTheme.headerBg,
        border: Border(
          bottom: BorderSide(
            color: AdminNeonTheme.glassBorder.withValues(alpha: 0.6),
          ),
        ),
      ),
      padding: EdgeInsets.only(
        left: showMenuButton ? 8 : 24,
        right: 24,
        top: MediaQuery.paddingOf(context).top + 12,
        bottom: 16,
      ),
      child: Column(
        children: [
          // Main header content
          Row(
            children: [
              if (showMenuButton)
                IconButton(
                  icon: const Icon(Icons.menu_rounded, color: AdminNeonTheme.textPrimary),
                  onPressed: onMenuPressed,
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showDashboardTitle)
                      const Text(
                        'Admin Dashboard',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: AdminNeonTheme.textPrimary,
                        ),
                      ),
                    if (showWelcomeText)
                      Text(
                        'Welcome back, Admin',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AdminNeonTheme.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              if (isDesktop)
                Text(
                  dateLabel,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AdminNeonTheme.textSecondary,
                  ),
                ),
              if (isDesktop) const SizedBox(width: 12),
              AdminNotificationBell(adminEmail: AdminAuth.currentAdminEmail),
              const SizedBox(width: 8),
              CircleAvatar(
                radius: 20,
                backgroundColor: AdminNeonTheme.neonBlue.withValues(alpha: 0.18),
                child: const Icon(Icons.person_rounded, color: AdminNeonTheme.neonBlue),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _dayName(int day) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[day - 1];
  }

  String _monthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }
}
