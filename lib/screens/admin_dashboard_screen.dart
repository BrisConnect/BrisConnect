// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:brisconnect/auth/app_user_role.dart';
import 'package:brisconnect/auth/admin_auth.dart';
import 'package:brisconnect/features/admin/dashboard/admin_dashboard_page.dart';
import 'package:brisconnect/features/admin/dashboard/admin_dashboard_state.dart';
import 'package:brisconnect/features/admin/dashboard/admin_neon_theme.dart';
import 'package:brisconnect/features/admin/dashboard/widgets/admin_layout.dart';
import 'package:brisconnect/screens/admin_business_management_screen.dart';
import 'package:brisconnect/screens/admin_feedback_review_screen.dart';
import 'package:brisconnect/screens/admin_email_broadcast_screen.dart';
import 'package:brisconnect/screens/admin_user_management_screen.dart';
import 'package:brisconnect/screens/admin_reports_hub_screen.dart';
import 'package:brisconnect/screens/admin_engagement_screen.dart';
import 'package:brisconnect/screens/admin_google_listings_screen.dart';
import 'package:brisconnect/services/admin_dashboard_service.dart';
import 'package:brisconnect/services/admin_event_service.dart';
import 'package:brisconnect/widgets/role_guard.dart';

const Color _adminMetricBackground = AdminNeonTheme.glassSurface;
const Color _adminMetricText = AdminNeonTheme.textPrimary;
const Color _adminMetricSubtext = AdminNeonTheme.textSecondary;

class AdminDashboardScreen extends StatefulWidget {
  AdminDashboardScreen({
    super.key,
    AdminDashboardService? dashboardService,
    this.enforceRoleGuard = true,
    this.eventsScreenBuilder,
    this.usersScreenBuilder,
  }) : dashboardService = dashboardService ?? AdminDashboardService();

  final AdminDashboardService dashboardService;
  final bool enforceRoleGuard;
  final WidgetBuilder? eventsScreenBuilder;
  final WidgetBuilder? usersScreenBuilder;

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final AdminDashboardController _controller = AdminDashboardController();
  int _selectedNavIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller.load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runLegacyEventIdMigration();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _runLegacyEventIdMigration() async {
    try {
      final migratedCount =
          await AdminEventService().migrateLegacyLocalSubmissionIds();
      if (!mounted || migratedCount == 0) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Migrated $migratedCount legacy local event ID${migratedCount == 1 ? '' : 's'} to readable format.',
          ),
        ),
      );
    } catch (_) {
      // Ignore migration issues so dashboard metrics can still render.
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget layoutContent;

    switch (_selectedNavIndex) {
      case 1:
        // Users - embedded mode (buildFullScaffold: false returns just content)
        layoutContent = AdminUserManagementScreen(
          enforceRoleGuard: false,
          buildFullScaffold: false,
        );
        break;
      case 2:
        // Businesses - embedded mode (buildFullScaffold: false returns just content)
        layoutContent = AdminBusinessManagementScreen(
          enforceRoleGuard: false,
          buildFullScaffold: false,
        );
        break;
      case 3:
        // Reports - embedded mode
        layoutContent = const AdminReportsHubScreen(
          enforceRoleGuard: false,
          isEmbedded: true,
        );
        break;
      case 4:
        // Feedback - embedded mode
        layoutContent = AdminFeedbackReviewScreen(
          enforceRoleGuard: false,
          isEmbedded: true,
        );
        break;
      case 5:
        // Broadcast Email - embedded mode
        layoutContent = AdminEmailBroadcastScreen(
          enforceRoleGuard: false,
          isEmbedded: true,
        );
        break;
      case 6:
        // Engagement - embedded mode
        layoutContent = AdminEngagementScreen(
          enforceRoleGuard: false,
          isEmbedded: true,
        );
        break;
      case 7:
        // Google Listings - embedded mode
        layoutContent = const AdminGoogleListingsScreen();
        break;
      case 8:
        // Settings - embedded mode
        layoutContent = _buildSettingsTab();
        break;
      case 0:
      default:
        // Dashboard uses AdminDashboardPage which contains AdminLayout internally
        layoutContent = AdminDashboardPage(
          controller: _controller,
          selectedNavIndex: _selectedNavIndex,
          onNavIndexChanged: (index) => setState(() => _selectedNavIndex = index),
        );
        break;
    }

    // Wrap all screens EXCEPT Dashboard (case 0) in AdminLayout for sidebar navigation.
    // NOTE: Do NOT wrap layoutContent in SingleChildScrollView here - each embedded
    // screen already provides its own scrollable widget (CustomScrollView, ListView,
    // or Column+Expanded+ListView), and AdminLayout's body slot is already bounded-height.
    // Adding another scrollable wrapper gives the inner scrollable unbounded height,
    // which silently fails to paint (blank screen) in release builds.
    if (_selectedNavIndex != 0) {
      layoutContent = AdminLayout(
        controller: _controller,
        selectedNavIndex: _selectedNavIndex,
        onNavIndexChanged: (index) => setState(() => _selectedNavIndex = index),
        body: layoutContent,
      );
    }

    // Apply role guard if enforceRoleGuard is true
    if (!widget.enforceRoleGuard) return layoutContent;

    return RoleGuard(
      allowedRoles: const {AppUserRole.admin},
      deniedMessage: 'Access denied. Admin privileges are required.',
      child: layoutContent,
    );
  }

  Widget _buildSettingsTab() {
    return SafeArea(
      child: ListView(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 36),
        children: [
          const Text(
            'Settings',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: _adminMetricText,
            ),
          ),
          const SizedBox(height: 20),
          // Admin Profile Card
          _buildAdminProfileCard(),
          const SizedBox(height: 24),
          // Account Section
          _settingsSectionLabel('Account'),
          _settingsCard(children: [
            _settingsTile(
              icon: Icons.person_outline_rounded,
              title: 'Profile Details',
              subtitle: 'View admin profile information',
              onTap: () => _showProfileDetailsDialog(),
            ),
            _settingsTile(
              icon: Icons.lock_outline_rounded,
              title: 'Change Password',
              subtitle: 'Update your admin account password',
              onTap: () => _showChangePasswordDialog(),
            ),
          ]),
          const SizedBox(height: 24),
          // About Section
          _settingsSectionLabel('About'),
          _settingsCard(children: [
            _settingsTile(
              icon: Icons.info_outline_rounded,
              title: 'About BrisConnect+',
              subtitle: 'Version, credits & legal',
              onTap: () => _showAboutDialog(),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildAdminProfileCard() {
    final email = AdminAuth.currentAdminEmail ?? '';
    final username = email.isNotEmpty ? email.split('@').first : 'Admin';
    
    return Card(
      color: _adminMetricBackground,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
            color: AdminNeonTheme.neonBlue.withValues(alpha: 0.28)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.account_circle_rounded,
                size: 48, color: AdminNeonTheme.neonBlue),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    username.replaceFirstMapped(
                      RegExp('^.'),
                      (match) => match.group(0)!.toUpperCase(),
                    ),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _adminMetricText,
                    ),
                  ),
                  if (email.isNotEmpty)
                    Text(
                      email,
                      style: const TextStyle(color: _adminMetricSubtext),
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 4),
                  const Text(
                    'Administrator',
                    style: TextStyle(
                      fontSize: 12,
                      color: AdminNeonTheme.neonBlue,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showProfileDetailsDialog() {
    final email = AdminAuth.currentAdminEmail ?? '';
    final username = email.isNotEmpty ? email.split('@').first : 'Admin';
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: AdminNeonTheme.bgDeepNavy,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AdminNeonTheme.glassBorder,
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Profile Details',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: _adminMetricText,
                  ),
                ),
                const SizedBox(height: 20),
                _profileDetailRow('Name', username),
                const SizedBox(height: 16),
                _profileDetailRow('Email', email),
                const SizedBox(height: 16),
                _profileDetailRow('Role', 'Administrator'),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AdminNeonTheme.neonBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _profileDetailRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _adminMetricSubtext,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AdminNeonTheme.glassSurfaceAlt,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AdminNeonTheme.glassBorder,
              width: 1,
            ),
          ),
          child: Text(
            value,
            style: const TextStyle(
              color: _adminMetricText,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  void _showChangePasswordDialog() {
    final formKey = GlobalKey<FormState>();
    late String currentPassword;
    late String newPassword;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: StatefulBuilder(
          builder: (context, setState) => Container(
            decoration: BoxDecoration(
              color: AdminNeonTheme.bgDeepNavy,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AdminNeonTheme.glassBorder,
                width: 1,
              ),
            ),
            constraints: const BoxConstraints(maxWidth: 450),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Change Password',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: _adminMetricText,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Update your admin account password. This change only affects your account.',
                        style: TextStyle(
                          fontSize: 13,
                          color: _adminMetricSubtext,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildPasswordField(
                        label: 'Current Password',
                        onChanged: (value) => currentPassword = value,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Current password is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildPasswordField(
                        label: 'New Password',
                        onChanged: (value) => newPassword = value,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'New password is required';
                          }
                          if (value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildPasswordField(
                        label: 'Confirm New Password',
                        onChanged: (value) {
                          // Validation is handled in the validator
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please confirm your new password';
                          }
                          if (value != newPassword) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 28),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    AdminNeonTheme.neonBlue.withValues(alpha: 0.2),
                                foregroundColor: AdminNeonTheme.neonBlue,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: const BorderSide(
                                    color: AdminNeonTheme.neonBlue,
                                  ),
                                ),
                              ),
                              onPressed: isLoading
                                  ? null
                                  : () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AdminNeonTheme.neonBlue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: isLoading
                                  ? null
                                  : () async {
                                if (!formKey.currentState!.validate()) {
                                  return;
                                }
                                
                                setState(() => isLoading = true);
                                
                                try {
                                  final user = fb_auth.FirebaseAuth.instance.currentUser;
                                  if (user == null) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Error: Admin not authenticated'),
                                          backgroundColor: AdminNeonTheme.neonRed,
                                        ),
                                      );
                                    }
                                    return;
                                  }

                                  // Re-authenticate with current password
                                  final credential =
                                      fb_auth.EmailAuthProvider.credential(
                                    email: user.email!,
                                    password: currentPassword,
                                  );
                                  
                                  await user.reauthenticateWithCredential(credential);
                                  
                                  // Update password
                                  await user.updatePassword(newPassword);
                                  
                                  if (mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Password updated successfully'),
                                        backgroundColor: AdminNeonTheme.neonBlue,
                                      ),
                                    );
                                  }
                                } on fb_auth.FirebaseAuthException catch (e) {
                                  setState(() => isLoading = false);
                                  if (mounted) {
                                    String errorMessage =
                                        'Failed to update password';
                                    if (e.code == 'wrong-password') {
                                      errorMessage = 'Current password is incorrect';
                                    } else if (e.code == 'weak-password') {
                                      errorMessage = 'New password is too weak';
                                    } else if (e.code == 'requires-recent-login') {
                                      errorMessage = 'Please log out and log back in';
                                    }
                                    
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(errorMessage),
                                        backgroundColor: AdminNeonTheme.neonRed,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  setState(() => isLoading = false);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Error: ${e.toString()}'),
                                        backgroundColor: AdminNeonTheme.neonRed,
                                      ),
                                    );
                                  }
                                }
                              },
                              child: isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          Colors.white,
                                        ),
                                      ),
                                    )
                                  : const Text('Update Password'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required String label,
    required Function(String) onChanged,
    required String? Function(String?) validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _adminMetricSubtext,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          obscureText: true,
          onChanged: onChanged,
          validator: validator,
          decoration: InputDecoration(
            hintText: 'Enter $label',
            hintStyle: const TextStyle(color: AdminNeonTheme.textMuted),
            filled: true,
            fillColor: AdminNeonTheme.glassSurfaceAlt,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AdminNeonTheme.glassBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AdminNeonTheme.glassBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: AdminNeonTheme.neonBlue,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AdminNeonTheme.neonRed),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
          style: const TextStyle(
            color: _adminMetricText,
          ),
        ),
      ],
    );
  }

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: 'BrisConnect+',
      applicationVersion: '1.0.0',
      applicationLegalese: '© 2026 BrisConnect+ Team',
      applicationIcon:
          Image.asset('assets/Brisconnect New.jpg', height: 48),
    );
  }

  Widget _settingsSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: _adminMetricSubtext,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _settingsIcon(IconData icon) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: AdminNeonTheme.neonBlue.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: AdminNeonTheme.neonBlue, size: 20),
    );
  }

  Widget _settingsCard({required List<Widget> children}) {
    final tiles = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      tiles.add(children[i]);
      if (i < children.length - 1) {
        tiles.add(const Divider(
          height: 1,
          indent: 16,
          endIndent: 16,
          color: AdminNeonTheme.glassBorder,
        ));
      }
    }
    return Card(
      color: _adminMetricBackground,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AdminNeonTheme.glassBorder),
      ),
      child: Column(children: tiles),
    );
  }

  Widget _settingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: _settingsIcon(icon),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: _adminMetricText,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: _adminMetricSubtext),
      ),
      trailing:
          const Icon(Icons.chevron_right_rounded, color: _adminMetricSubtext),
      onTap: onTap,
    );
  }
}
