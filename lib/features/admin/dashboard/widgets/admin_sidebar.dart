import 'package:flutter/material.dart';
import 'package:brisconnect/auth/admin_auth.dart';
import 'package:brisconnect/features/admin/dashboard/admin_neon_theme.dart';
import 'package:brisconnect/screens/welcome_screen_new.dart';

class AdminSidebar extends StatelessWidget {
  const AdminSidebar({
    super.key,
    required this.selectedIndex,
    this.onDestinationSelected,
  });

  final int selectedIndex;
  final ValueChanged<int>? onDestinationSelected;

  static const _items = [
    _NavItemData(icon: Icons.home_rounded, label: 'Dashboard', accent: AdminNeonTheme.neonBlue),
    _NavItemData(icon: Icons.groups_rounded, label: 'Users', accent: AdminNeonTheme.neonOrange),
    _NavItemData(icon: Icons.business_rounded, label: 'Businesses', accent: AdminNeonTheme.neonBlue),
    _NavItemData(icon: Icons.report_rounded, label: 'Reports', accent: AdminNeonTheme.neonOrange),
    _NavItemData(icon: Icons.feedback_rounded, label: 'Feedback', accent: AdminNeonTheme.neonBlue),
    _NavItemData(icon: Icons.email_rounded, label: 'Broadcast Email', accent: AdminNeonTheme.neonOrange),
    _NavItemData(icon: Icons.people_rounded, label: 'Engagement', accent: AdminNeonTheme.neonBlue),
    _NavItemData(icon: Icons.location_on_rounded, label: 'Google Listings', accent: AdminNeonTheme.neonOrange),
    _NavItemData(icon: Icons.settings_rounded, label: 'Settings', accent: AdminNeonTheme.neonBlue),
  ];

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    // Narrow sidebar on mobile, full width on tablet/desktop
    final sidebarWidth = width < 600 ? 80.0 : 260.0;
    
    return Container(
      width: sidebarWidth,
      decoration: BoxDecoration(
        color: AdminNeonTheme.sidebarBg,
        border: Border(
          right: BorderSide(
            color: AdminNeonTheme.glassBorder.withValues(alpha: 0.6),
          ),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 16),
            child: InkWell(
              onTap: () => Navigator.of(context).pushNamedAndRemoveUntil(
                '/welcome',
                (route) => false,
              ),
              borderRadius: BorderRadius.circular(22),
              child: width < 600
                  ? Image.asset('assets/Brisconnect New.jpg', height: 44)
                  : Row(
                      children: [
                        Image.asset('assets/Brisconnect New.jpg', height: 44),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Admin',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: AdminNeonTheme.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          Divider(height: 1, color: AdminNeonTheme.glassBorder.withValues(alpha: 0.5)),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                final isSelected = selectedIndex == index;
                return _SidebarTile(
                  icon: item.icon,
                  label: item.label,
                  accent: item.accent,
                  isSelected: isSelected,
                  onTap: () => onDestinationSelected?.call(index),
                  showLabel: width >= 600,
                );
              },
            ),
          ),
          Divider(height: 1, color: AdminNeonTheme.glassBorder.withValues(alpha: 0.5)),
          _SidebarTile(
            icon: Icons.logout_rounded,
            label: 'Logout',
            accent: AdminNeonTheme.neonRed,
            isSelected: false,
            onTap: () => _logout(context),
            showLabel: width >= 600,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    final navigator = Navigator.of(context);
    await AdminAuth.logout();
    if (!context.mounted) return;
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AnimatedWelcomeScreen()),
      (route) => false,
    );
  }
}

class _SidebarTile extends StatelessWidget {
  const _SidebarTile({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.accent = AdminNeonTheme.neonBlue,
    this.showLabel = true,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color accent;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: isSelected
            ? accent.withValues(alpha: 0.14)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: isSelected
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: accent.withValues(alpha: 0.55)),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.25),
                        blurRadius: 12,
                      ),
                    ],
                  )
                : null,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: showLabel
                ? Row(
                    children: [
                      Icon(
                        icon,
                        color: isSelected ? accent : AdminNeonTheme.textMuted,
                        size: 22,
                      ),
                      const SizedBox(width: 14),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: isSelected
                              ? AdminNeonTheme.textPrimary
                              : AdminNeonTheme.textSecondary,
                        ),
                      ),
                    ],
                  )
                : Tooltip(
                    message: label,
                    child: Icon(
                      icon,
                      color: isSelected ? accent : AdminNeonTheme.textMuted,
                      size: 24,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _NavItemData {
  final IconData icon;
  final String label;
  final Color accent;

  const _NavItemData({
    required this.icon,
    required this.label,
    this.accent = AdminNeonTheme.neonBlue,
  });
}
