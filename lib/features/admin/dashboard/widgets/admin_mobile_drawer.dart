import 'package:flutter/material.dart';
import 'package:brisconnect/auth/admin_auth.dart';
import 'package:brisconnect/screens/welcome_screen_new.dart';
import 'package:brisconnect/theme/app_palette.dart';

class AdminMobileDrawer extends StatelessWidget {
  const AdminMobileDrawer({
    super.key,
    required this.selectedIndex,
    this.onDestinationSelected,
  });

  final int selectedIndex;
  final ValueChanged<int>? onDestinationSelected;

  static const _items = [
    _DrawerItem(icon: Icons.home_rounded, label: 'Home'),
    _DrawerItem(icon: Icons.groups_rounded, label: 'Users'),
    _DrawerItem(icon: Icons.business_rounded, label: 'Businesses'),
    _DrawerItem(icon: Icons.report_rounded, label: 'Reports'),
    _DrawerItem(icon: Icons.feedback_rounded, label: 'Feedback'),
    _DrawerItem(icon: Icons.email_rounded, label: 'Broadcast Email'),
    _DrawerItem(icon: Icons.settings_rounded, label: 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.of(context).pushNamedAndRemoveUntil(
                      '/welcome',
                      (route) => false,
                    ),
                    borderRadius: BorderRadius.circular(22),
                    child: Image.asset('assets/Brisconnect New.jpg', height: 44),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Admin',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: AppPalette.deepBlue,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 12),
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  final item = _items[index];
                  final isSelected = index == selectedIndex;
                  return ListTile(
                    leading: Icon(
                      item.icon,
                      color:
                          isSelected ? AppPalette.ochre : AppPalette.mutedText,
                    ),
                    title: Text(
                      item.label,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color:
                            isSelected ? AppPalette.ochre : AppPalette.charcoal,
                      ),
                    ),
                    selected: isSelected,
                    onTap: () {
                      Navigator.pop(context);
                      onDestinationSelected?.call(index);
                    },
                  );
                },
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading:
                  const Icon(Icons.logout_rounded, color: AppPalette.ochre),
              title: const Text(
                'Logout',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppPalette.ochre,
                ),
              ),
              onTap: () => _logout(context),
            ),
          ],
        ),
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

class _DrawerItem {
  final IconData icon;
  final String label;

  const _DrawerItem({required this.icon, required this.label});
}
