import 'package:flutter/material.dart';
import 'package:brisconnect/auth/app_user_role.dart';
import 'package:brisconnect/features/admin/dashboard/admin_neon_theme.dart';
import 'package:brisconnect/screens/admin_community_feed_screen.dart';
import 'package:brisconnect/widgets/role_guard.dart';
import 'package:brisconnect/features/admin/dashboard/widgets/admin_sidebar.dart';

/// Unified admin engagement screen for community management.
/// Includes community feed curation, content highlighting, and user engagement features.
class AdminEngagementScreen extends StatefulWidget {
  final bool enforceRoleGuard;
  final bool isEmbedded;

  const AdminEngagementScreen({
    super.key,
    this.enforceRoleGuard = true,
    this.isEmbedded = false,
  });

  @override
  State<AdminEngagementScreen> createState() => _AdminEngagementScreenState();
}

class _AdminEngagementScreenState extends State<AdminEngagementScreen> {
  final int _selectedTabIndex = 0; // 0: Community Feed

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width > 1024;

    final bodyContent = Scaffold(
      backgroundColor: AdminNeonTheme.bgDeepNavy,
      appBar: widget.isEmbedded
          ? null
          : AppBar(
              backgroundColor: AdminNeonTheme.headerBg,
              foregroundColor: AdminNeonTheme.textPrimary,
              elevation: 0,
              automaticallyImplyLeading: false,
              title: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Engagement',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AdminNeonTheme.textPrimary,
                      fontSize: 24,
                    ),
                  ),
                  Text(
                    'Manage community content and visitor engagement',
                    style: TextStyle(
                      fontWeight: FontWeight.w400,
                      color: AdminNeonTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
      body: _buildTabContent(),
    );

    final guarded = widget.enforceRoleGuard
        ? RoleGuard(
            allowedRoles: const {AppUserRole.admin},
            child: bodyContent,
          )
        : bodyContent;

    if (!isDesktop || widget.isEmbedded) return guarded;

    return Row(
      children: [
        AdminSidebar(
          selectedIndex: 6, // Engagement
          onDestinationSelected: (index) {
            _handleNavigation(context, index);
          },
        ),
        Expanded(child: guarded),
      ],
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTabIndex) {
      case 0:
        return AdminCommunityFeedScreen(
          enforceRoleGuard: false,
        );
      default:
        return AdminCommunityFeedScreen(
          enforceRoleGuard: false,
        );
    }
  }

  void _handleNavigation(BuildContext context, int index) {
    // index: 0=Dashboard, 1=Users, 2=Businesses, 3=Reports, 4=Feedback, 5=Broadcast, 6=Engagement, 7=Settings
    switch (index) {
      case 0: // Dashboard
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/admin/dashboard',
          (route) => false,
        );
        break;
      case 1: // Users
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/admin/users',
          (route) => false,
        );
        break;
      case 2: // Businesses
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/admin/businesses',
          (route) => false,
        );
        break;
      case 3: // Reports
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/admin/reports',
          (route) => false,
        );
        break;
      case 4: // Feedback
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/admin/feedback',
          (route) => false,
        );
        break;
      case 5: // Broadcast Email
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/admin/broadcast',
          (route) => false,
        );
        break;
      case 6: // Engagement - already here
        break;
      case 7: // Settings
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/admin/settings',
          (route) => false,
        );
        break;
    }
  }
}
