import 'package:flutter/material.dart';
import 'package:brisconnect/auth/app_user_role.dart';
import 'package:brisconnect/auth/admin_auth.dart';
import 'package:brisconnect/screens/admin_attraction_management_screen.dart';
import 'package:brisconnect/screens/admin_event_review_screen.dart';
import 'package:brisconnect/screens/admin_user_management_screen.dart';
import 'package:brisconnect/screens/admin_reported_events_screen.dart';
import 'package:brisconnect/screens/welcome_screen.dart';
import 'package:brisconnect/services/admin_dashboard_service.dart';
import 'package:brisconnect/services/admin_event_service.dart';
import 'package:brisconnect/services/discover_data_service.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/widgets/logo_app_bar_title.dart';
import 'package:brisconnect/widgets/role_guard.dart';

class AdminDashboardScreen extends StatefulWidget {
  AdminDashboardScreen({
    super.key,
    AdminDashboardService? dashboardService,
    this.discoverDataService,
    this.enforceRoleGuard = true,
    this.eventsScreenBuilder,
    this.usersScreenBuilder,
  }) : dashboardService = dashboardService ?? AdminDashboardService();

  final AdminDashboardService dashboardService;
  final DiscoverDataService? discoverDataService;
  final bool enforceRoleGuard;
  final WidgetBuilder? eventsScreenBuilder;
  final WidgetBuilder? usersScreenBuilder;

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  @override
  void initState() {
    super.initState();
    _runLegacyEventIdMigration();
  }

  Future<void> _runLegacyEventIdMigration() async {
    try {
      final migratedCount = await AdminEventService().migrateLegacyLocalSubmissionIds();
      if (!mounted || migratedCount == 0) {
        return;
      }

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

  void _openUsersManagement() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: widget.usersScreenBuilder ??
            (_) => AdminUserManagementScreen(),
      ),
    );
  }

  void _openEventsManagement() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: widget.eventsScreenBuilder ??
            (_) => AdminEventReviewScreen(),
      ),
    );
  }

  void _openAttractionsManagement() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminAttractionManagementScreen(),
      ),
    );
  }

  void _openReportedEvents() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminReportedEventsScreen(),
      ),
    );
  }

  Future<void> _seedDiscoverCatalog() async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    final result =
        await (widget.discoverDataService ?? DiscoverDataService()).ensureSeeded();
    if (!mounted) {
      return;
    }

    switch (result) {
      case DiscoverSeedResult.seeded:
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Discovery catalog seeded to Firestore.'),
          ),
        );
      case DiscoverSeedResult.alreadySeeded:
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Discovery catalog is already present in Firestore.'),
          ),
        );
      case DiscoverSeedResult.permissionDenied:
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Seed denied by Firestore rules. Ensure updated rules are deployed and you are signed in as an active admin.'),
          ),
        );
      case DiscoverSeedResult.failed:
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Unable to seed discovery catalog right now.'),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = Scaffold(
        backgroundColor: AppPalette.background,
        appBar: AppBar(
          title: const LogoAppBarTitle('Admin Dashboard'),
          actions: [
            IconButton(
              tooltip: 'Refresh dashboard',
              onPressed: () => setState(() {}),
              icon: const Icon(Icons.refresh_rounded),
            ),
            TextButton(
              onPressed: () async {
                await AdminAuth.logout();
                if (!context.mounted) {
                  return;
                }
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                  (route) => false,
                );
              },
              child: const Text('Logout'),
            ),
          ],
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 950;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Live Admin Metrics',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppPalette.charcoal,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Realtime snapshot of events and users. Tap a metric to open details.',
                  style: TextStyle(color: AppPalette.mutedText),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _MetricCard(
                      width: isWide ? 280 : constraints.maxWidth,
                      icon: Icons.event,
                      title: 'Total Events',
                      stream: widget.dashboardService.totalEventsCount(),
                      onTap: _openEventsManagement,
                      helperText: 'All event records in Firebase',
                    ),
                    _MetricCard(
                      width: isWide ? 280 : constraints.maxWidth,
                      icon: Icons.pending_actions,
                      title: 'Pending Events',
                      stream: widget.dashboardService.pendingEventsCount(),
                      onTap: _openEventsManagement,
                      helperText: 'Events waiting for review',
                      accent: Colors.orange.shade700,
                    ),
                    _MetricCard(
                      width: isWide ? 280 : constraints.maxWidth,
                      icon: Icons.flag_rounded,
                      title: 'Reported Events',
                      stream: widget.dashboardService.pendingEventReportsCount(),
                      onTap: _openReportedEvents,
                      helperText: 'Events flagged by visitors',
                      accent: Colors.red.shade700,
                    ),
                    _MetricCard(
                      width: isWide ? 280 : constraints.maxWidth,
                      icon: Icons.storefront,
                      title: 'Local Users',
                      stream: widget.dashboardService.totalLocalUsersCount(),
                      onTap: _openUsersManagement,
                      helperText: 'Registered local accounts',
                    ),
                    _MetricCard(
                      width: isWide ? 280 : constraints.maxWidth,
                      icon: Icons.groups_rounded,
                      title: 'Total Users',
                      stream: widget.dashboardService.totalUsersCount(),
                      onTap: _openUsersManagement,
                      helperText: 'Local + visitor + admin accounts',
                    ),
                    _MetricCard(
                      width: isWide ? 280 : constraints.maxWidth,
                      icon: Icons.hourglass_top,
                      title: 'Pending Local Approvals',
                      stream: widget.dashboardService.pendingLocalUsersCount(),
                      onTap: _openUsersManagement,
                      helperText: 'Accounts awaiting admin decision',
                      accent: AppPalette.ochre,
                    ),
                    _MetricCard(
                      width: isWide ? 280 : constraints.maxWidth,
                      icon: Icons.people,
                      title: 'Visitor Users',
                      stream: widget.dashboardService.totalVisitorsCount(),
                      onTap: null,
                      helperText: 'Registered visitor profiles',
                    ),
                    _MetricCard(
                      width: isWide ? 280 : constraints.maxWidth,
                      icon: Icons.admin_panel_settings,
                      title: 'Admins',
                      stream: widget.dashboardService.totalAdminsCount(),
                      onTap: null,
                      helperText: 'Admin accounts in Firestore',
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Text(
                  'Actions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppPalette.charcoal,
                  ),
                ),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: isWide ? 3 : 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: isWide ? 1.45 : 1.05,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _AdminTile(
                      icon: Icons.group,
                      title: 'Manage Users',
                      subtitle: 'Approve, edit, and deactivate user accounts',
                      onTap: _openUsersManagement,
                    ),
                    _AdminTile(
                      icon: Icons.event,
                      title: 'Manage Events',
                      subtitle: 'Review, edit, and delete event submissions',
                      onTap: _openEventsManagement,
                    ),
                    _AdminTile(
                      icon: Icons.cloud_upload,
                      title: 'Seed Discover Data',
                      subtitle: 'Write curated events, food, stadiums, and sights to Firestore',
                      onTap: _seedDiscoverCatalog,
                    ),
                    _AdminTile(
                      icon: Icons.place,
                      title: 'Manage Attractions',
                      subtitle: 'Maintain attraction info and categories',
                      onTap: _openAttractionsManagement,
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      );

    if (!widget.enforceRoleGuard) {
      return content;
    }

    return RoleGuard(
      allowedRoles: const {AppUserRole.admin},
      deniedMessage: 'Access denied. Admin privileges are required.',
      child: content,
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.width,
    required this.icon,
    required this.title,
    required this.stream,
    required this.helperText,
    this.onTap,
    this.accent = AppPalette.deepBlue,
  });

  final double width;
  final IconData icon;
  final String title;
  final Stream<int> stream;
  final String helperText;
  final VoidCallback? onTap;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Card(
        color: AppPalette.surface,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: accent, size: 20),
                    ),
                    const Spacer(),
                    if (onTap != null)
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AppPalette.mutedText,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppPalette.charcoal,
                  ),
                ),
                const SizedBox(height: 8),
                StreamBuilder<int>(
                  stream: stream,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Text(
                        '—',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AppPalette.ochre,
                        ),
                      );
                    }

                    if (!snapshot.hasData) {
                      return const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      );
                    }

                    return Text(
                      '${snapshot.data}',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: accent,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 4),
                Text(
                  helperText,
                  style: const TextStyle(color: AppPalette.mutedText),
                ),
              ],
            ),
          ),
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
              Icon(icon, size: 24, color: AppPalette.deepBlue),
              const SizedBox(height: 8),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppPalette.charcoal,
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: Text(
                  subtitle,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppPalette.mutedText),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
