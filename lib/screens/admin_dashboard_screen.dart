import 'package:flutter/material.dart';
import 'package:brisconnect/auth/admin_auth.dart';
import 'package:brisconnect/screens/admin_event_review_screen.dart';
import 'package:brisconnect/screens/admin_local_account_review_screen.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/widgets/logo_app_bar_title.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (!AdminAuth.isAdminLoggedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushNamedAndRemoveUntil(context, '/admin/login', (_) => false);
      });

      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppPalette.ochre)),
      );
    }

    return Scaffold(
      backgroundColor: AppPalette.background,
      appBar: AppBar(
        title: const LogoAppBarTitle('Admin Dashboard'),
        actions: [
          TextButton.icon(
            onPressed: () {
              AdminAuth.logout();
              Navigator.pushNamedAndRemoveUntil(context, '/admin/login', (_) => false);
            },
            icon: const Icon(Icons.logout),
            label: const Text('Logout'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Management',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppPalette.charcoal,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Admin-only access to manage users, events, and attractions.',
              style: TextStyle(color: AppPalette.mutedText),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                children: [
                  _AdminTile(
                    icon: Icons.group,
                    title: 'Manage Users',
                    subtitle: 'Approve, edit, and deactivate user accounts',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AdminLocalAccountReviewScreen(),
                        ),
                      );
                    },
                  ),
                  _AdminTile(
                    icon: Icons.event,
                    title: 'Manage Events',
                    subtitle: 'Review pending events and approve submissions',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AdminEventReviewScreen(),
                        ),
                      );
                    },
                  ),
                  const _AdminTile(
                    icon: Icons.place,
                    title: 'Manage Attractions',
                    subtitle: 'Maintain attraction info and categories',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _AdminTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppPalette.surface,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 28, color: AppPalette.deepBlue),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppPalette.charcoal,
                ),
              ),
              const SizedBox(height: 6),
              Text(subtitle,
                  style: const TextStyle(color: AppPalette.mutedText)),
            ],
          ),
        ),
      ),
    );
  }
}
