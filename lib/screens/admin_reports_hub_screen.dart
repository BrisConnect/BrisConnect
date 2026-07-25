import 'package:flutter/material.dart';
import 'package:brisconnect/auth/app_user_role.dart';
import 'package:brisconnect/screens/admin_reported_events_screen.dart';
import 'package:brisconnect/screens/admin_reported_reviews_screen.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/widgets/logo_app_bar_title.dart';
import 'package:brisconnect/widgets/role_guard.dart';

/// Unified admin landing page for trust-and-safety reporting.
/// Replaces the separate Reported Events / Reported Recommendations tiles
/// with a single Reports Hub that links to the content-specific workflows.
class AdminReportsHubScreen extends StatelessWidget {
  final bool enforceRoleGuard;

  const AdminReportsHubScreen({
    super.key,
    this.enforceRoleGuard = true,
  });

  @override
  Widget build(BuildContext context) {
    final screen = Scaffold(
      backgroundColor: AppPalette.background,
      appBar: AppBar(
        title: const LogoAppBarTitle('Reports Hub'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _HubCard(
            icon: Icons.event_note_outlined,
            title: 'Reported Events',
            subtitle: 'Review and moderate event reports',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AdminReportedEventsScreen(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _HubCard(
            icon: Icons.reviews_outlined,
            title: 'Reported Recommendations',
            subtitle: 'Review and moderate recommendation reports',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AdminReportedReviewsScreen(),
              ),
            ),
          ),
        ],
      ),
    );

    if (enforceRoleGuard) {
      return RoleGuard(
        allowedRoles: const {AppUserRole.admin},
        child: screen,
      );
    }
    return screen;
  }
}

class _HubCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _HubCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppPalette.surface,
      elevation: 4,
      shadowColor: AppPalette.cardShadow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppPalette.border.withValues(alpha: 0.5)),
      ),
      child: ListTile(
        leading: Icon(icon, color: AppPalette.primary),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: AppPalette.charcoal,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: AppPalette.mutedText),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: AppPalette.mutedText),
        onTap: onTap,
      ),
    );
  }
}
