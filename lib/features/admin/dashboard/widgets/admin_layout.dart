import 'package:flutter/material.dart';
import 'package:brisconnect/features/admin/dashboard/admin_dashboard_state.dart';
import 'package:brisconnect/features/admin/dashboard/admin_neon_theme.dart';
import 'package:brisconnect/features/admin/dashboard/widgets/admin_header.dart';
import 'package:brisconnect/features/admin/dashboard/widgets/admin_neon_background.dart';
import 'package:brisconnect/features/admin/dashboard/widgets/admin_sidebar.dart';

/// Responsive layout shell for the admin dashboard.
class AdminLayout extends StatelessWidget {
  const AdminLayout({
    super.key,
    required this.controller,
    required this.body,
    this.selectedNavIndex = 0,
    this.onNavIndexChanged,
  });

  final AdminDashboardController controller;
  final Widget body;
  final int selectedNavIndex;
  final ValueChanged<int>? onNavIndexChanged;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 600;
    final isDesktop = width > 1024;
    final isTablet = width >= 600 && width <= 1024;

    if (isMobile) {
      // Mobile layout with bottom navigation
      return Scaffold(
        backgroundColor: const Color(0xFF060812),
        body: Stack(
          children: [
            const Positioned.fill(child: AdminNeonBackground()),
            Column(
              children: [
                AdminHeader(
                  showMenuButton: false,
                  onMenuPressed: () {},
                  showWelcomeText: selectedNavIndex == 0,
                  showDashboardTitle: selectedNavIndex == 0,
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1400),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: body,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        bottomNavigationBar: _AdminMobileBottomNav(
          selectedIndex: selectedNavIndex,
          onDestinationSelected: onNavIndexChanged,
        ),
      );
    } else {
      // Desktop/Tablet layout with side navigation
      return Scaffold(
        backgroundColor: const Color(0xFF060812),
        body: Stack(
          children: [
            const Positioned.fill(child: AdminNeonBackground()),
            Row(
              children: [
                AdminSidebar(
                  selectedIndex: selectedNavIndex,
                  onDestinationSelected: onNavIndexChanged,
                ),
                Expanded(
                  child: Column(
                    children: [
                      AdminHeader(
                        showMenuButton: false,
                        onMenuPressed: () {},
                        showWelcomeText: selectedNavIndex == 0,
                        showDashboardTitle: selectedNavIndex == 0,
                      ),
                      Expanded(
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1400),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: isDesktop
                                    ? 32
                                    : isTablet
                                        ? 24
                                        : 16,
                              ),
                              child: body,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }
  }
}

/// Mobile bottom navigation bar for admin dashboard
class _AdminMobileBottomNav extends StatelessWidget {
  const _AdminMobileBottomNav({
    required this.selectedIndex,
    this.onDestinationSelected,
  });

  final int selectedIndex;
  final ValueChanged<int>? onDestinationSelected;

  static const _items = [
    ('Dashboard', Icons.home_rounded),
    ('Users', Icons.groups_rounded),
    ('Businesses', Icons.business_rounded),
    ('Reports', Icons.report_rounded),
    ('Feedback', Icons.feedback_rounded),
    ('Email', Icons.email_rounded),
    ('Engagement', Icons.people_rounded),
    ('Listings', Icons.location_on_rounded),
    ('Settings', Icons.settings_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AdminNeonTheme.sidebarBg,
        border: Border(
          top: BorderSide(
            color: AdminNeonTheme.glassBorder.withValues(alpha: 0.6),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(_items.length, (index) {
              final (label, icon) = _items[index];
              final isSelected = index == selectedIndex;
              final accent = index % 2 == 0
                  ? AdminNeonTheme.neonBlue
                  : AdminNeonTheme.neonOrange;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Material(
                  color: isSelected
                      ? accent.withValues(alpha: 0.14)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    onTap: () => onDestinationSelected?.call(index),
                    child: Container(
                      decoration: isSelected
                          ? BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: accent.withValues(alpha: 0.55),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: accent.withValues(alpha: 0.25),
                                  blurRadius: 8,
                                ),
                              ],
                            )
                          : null,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            icon,
                            color:
                                isSelected ? accent : AdminNeonTheme.textMuted,
                            size: 20,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: isSelected
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: isSelected
                                  ? AdminNeonTheme.textPrimary
                                  : AdminNeonTheme.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

/// A consistent dashboard card container - dark glass panel.
class AdminCard extends StatelessWidget {
  const AdminCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.accent = AdminNeonTheme.neonBlue,
  });

  final Widget child;
  final EdgeInsets padding;

  /// Subtle border/glow tint - alternate blue/orange per panel.
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: AdminNeonTheme.glassCard(accent: accent),
      child: child,
    );
  }
}

/// A section header with optional View All action.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.onViewAll,
  });

  final String title;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AdminNeonTheme.textPrimary,
          ),
        ),
        if (onViewAll != null)
          TextButton.icon(
            onPressed: onViewAll,
            icon: const Text('View All'),
            label: const Icon(Icons.chevron_right_rounded, size: 18),
            style: TextButton.styleFrom(
              foregroundColor: AdminNeonTheme.neonOrange,
              textStyle: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
      ],
    );
  }
}

/// A compact status badge pill.
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
