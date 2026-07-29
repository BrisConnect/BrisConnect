import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:brisconnect/auth/app_user_role.dart';
import 'package:brisconnect/auth/admin_auth.dart';
import 'package:brisconnect/screens/admin_business_management_screen.dart';
import 'package:brisconnect/screens/admin_community_feed_screen.dart';
import 'package:brisconnect/models/event_item.dart';
import 'package:brisconnect/screens/admin_edit_event_screen.dart';
import 'package:brisconnect/screens/admin_event_review_screen.dart';
import 'package:brisconnect/screens/admin_feedback_review_screen.dart';
import 'package:brisconnect/screens/admin_email_broadcast_screen.dart';
import 'package:brisconnect/screens/admin_sms_broadcast_screen.dart';
import 'package:brisconnect/screens/admin_user_management_screen.dart';
import 'package:brisconnect/screens/admin_reports_hub_screen.dart';
import 'package:brisconnect/screens/create_business_screen.dart';
import 'package:brisconnect/screens/welcome_screen_new.dart';
import 'package:brisconnect/services/admin_dashboard_service.dart';
import 'package:brisconnect/services/admin_event_service.dart';
import 'package:brisconnect/services/event_category_service.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/utils/responsive_utils.dart';
import 'package:brisconnect/widgets/role_guard.dart';

/// Internal descriptor for a single admin dashboard stat tile.
class _StatItem {
  final Stream<int> stream;
  final Stream<MetricTrend> trendStream;
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;

  const _StatItem({
    required this.stream,
    required this.trendStream,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
  });
}

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
  final EventCategoryService _categoryService = EventCategoryService();
  final AdminEventService _adminEventService = AdminEventService();
  bool _isNavVisible = true;
  Timer? _navRestoreTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runLegacyEventIdMigration();
    });
  }

  @override
  void dispose() {
    _navRestoreTimer?.cancel();
    super.dispose();
  }

  Future<void> _runLegacyEventIdMigration() async {
    try {
      final migratedCount =
          await AdminEventService().migrateLegacyLocalSubmissionIds();
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
    setState(() => _selectedNavIndex = 1);
  }

  void _openEventsManagement() {
    setState(() => _selectedNavIndex = 2);
  }

  void _openReportsHub() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AdminReportsHubScreen(),
      ),
    );
  }

  void _openCommunityFeed() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AdminCommunityFeedScreen(),
      ),
    );
  }

  void _openBusinessManagement() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminBusinessManagementScreen(),
      ),
    );
  }

  void _openCreateBusiness() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CreateBusinessScreen(),
      ),
    );
  }

  void _openCreateEvent() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminEditEventScreen(
          event: const EventItem(
            id: '',
            title: '',
            date: '',
            time: '',
            location: '',
            description: '',
            reviewStatus: EventReviewStatus.pending,
          ),
          enforceRoleGuard: false,
        ),
      ),
    );
  }

  void _openFeedbackReview() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminFeedbackReviewScreen(),
      ),
    );
  }

  void _openSmsBroadcast() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminSmsBroadcastScreen(),
      ),
    );
  }

  void _openEmailBroadcast() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminEmailBroadcastScreen(),
      ),
    );
  }

  Future<void> _openCategoryManagement() async {
    final categories = await _categoryService.fetchCategories();
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppPalette.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _CategoryManagementSheet(
        initialCategories: categories,
        onSave: (updated) async {
          await _categoryService.saveCategories(updated);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Event categories updated.')),
          );
        },
      ),
    );
  }

  int _selectedNavIndex = 0;

  @override
  Widget build(BuildContext context) {
    final scaffold = Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: _selectedNavIndex == 0,
      appBar: _selectedNavIndex == 0
          ? null
          : AppBar(
              backgroundColor: const Color(0xFFEBF4FF),
              foregroundColor: const Color(0xFF1E3A8A),
              elevation: 0,
              title: Text(
                _appBarTitleForIndex(_selectedNavIndex),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E3A8A),
                ),
              ),
              actions: [
                _buildLogoutButton(context),
              ],
            ),
      extendBody: true,
      body: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (_selectedNavIndex != 0 || kIsWeb) {
            return false;
          }

          if (notification is ScrollUpdateNotification) {
            final delta = notification.scrollDelta ?? 0;
            if (delta > 8 && _isNavVisible) {
              _navRestoreTimer?.cancel();
              setState(() => _isNavVisible = false);
            } else if (delta < -8 && !_isNavVisible) {
              _navRestoreTimer?.cancel();
              setState(() => _isNavVisible = true);
            }
          } else if (notification is ScrollEndNotification) {
            _navRestoreTimer?.cancel();
            if (!_isNavVisible) {
              _navRestoreTimer = Timer(const Duration(milliseconds: 900), () {
                if (mounted && !_isNavVisible) {
                  setState(() => _isNavVisible = true);
                }
              });
            }
          }
          return false;
        },
        child: IndexedStack(
          index: _selectedNavIndex,
          children: [
            _buildHomeTab(),
            _buildUsersTab(),
            _buildBusinessesTab(),
            _buildEventsTab(),
            _buildSettingsTab(),
          ],
        ),
      ),
      bottomNavigationBar: IgnorePointer(
        ignoring: !_isNavVisible,
        child: AnimatedSlide(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          offset: _isNavVisible ? Offset.zero : const Offset(0, 1),
          child: _buildBottomNav(),
        ),
      ),
    );

    // Wrap scaffold with light blue background
    final withBackground = Stack(
      children: [
        const Positioned.fill(
          child: ColoredBox(color: Color(0xFFEBF4FF)),
        ),
        scaffold,
      ],
    );

    if (!widget.enforceRoleGuard) {
      return withBackground;
    }

    return RoleGuard(
      allowedRoles: const {AppUserRole.admin},
      deniedMessage: 'Access denied. Admin privileges are required.',
      child: withBackground,
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFBFDBFE), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x1A1E3A8A),
            blurRadius: 12,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.home_rounded,
                label: 'Home',
                isSelected: _selectedNavIndex == 0,
                onTap: () => setState(() {
                  _selectedNavIndex = 0;
                  _isNavVisible = true;
                }),
              ),
              _NavItem(
                icon: Icons.groups_rounded,
                label: 'Users',
                isSelected: _selectedNavIndex == 1,
                onTap: () => setState(() {
                  _selectedNavIndex = 1;
                  _isNavVisible = true;
                }),
              ),
              _NavItem(
                icon: Icons.business_rounded,
                label: 'Businesses',
                isSelected: _selectedNavIndex == 2,
                onTap: () => setState(() {
                  _selectedNavIndex = 2;
                  _isNavVisible = true;
                }),
              ),
              // Center Events button
              GestureDetector(
                onTap: () => setState(() {
                  _selectedNavIndex = 3;
                  _isNavVisible = true;
                }),
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF3B82F6), Color(0xFF1E40AF)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFF93C5FD),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.event_rounded, color: Colors.white, size: 22),
                      SizedBox(height: 2),
                      Text(
                        'Events',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _NavItem(
                icon: Icons.settings_rounded,
                label: 'Settings',
                isSelected: _selectedNavIndex == 4,
                onTap: () => setState(() {
                  _selectedNavIndex = 4;
                  _isNavVisible = true;
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _appBarTitleForIndex(int index) {
    switch (index) {
      case 1:
        return 'Users';
      case 2:
        return 'Businesses';
      case 3:
        return 'Events';
      case 4:
        return 'Settings';
      default:
        return 'Admin';
    }
  }

  Widget _buildLogoutButton(BuildContext context) {
    return IconButton(
      tooltip: 'Logout',
      icon: const Icon(Icons.logout_rounded, color: Color(0xFF1E3A8A)),
      onPressed: () async {
        final navigator = Navigator.of(context);
        await AdminAuth.logout();
        if (!mounted) return;
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AnimatedWelcomeScreen()),
          (route) => false,
        );
      },
    );
  }

  Widget _buildUsersTab() {
    return AdminUserManagementScreen(enforceRoleGuard: false);
  }

  Widget _buildBusinessesTab() {
    return AdminBusinessManagementScreen(enforceRoleGuard: false);
  }

  Widget _buildEventsTab() {
    return AdminEventReviewScreen(
      eventService: _adminEventService,
      enforceRoleGuard: false,
    );
  }

  Widget _buildHomeTab() {
    return CustomScrollView(
      physics: const ClampingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Stack(
            children: [
              // Transparent spacer for hero height
              const SizedBox(
                height: 340,
                width: double.infinity,
              ),
              // Title + Greeting + Search
              Positioned(
                top: MediaQuery.of(context).padding.top + 12,
                left: 16,
                right: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // BrisConnect logo
                        Image.asset('assets/Brisconnect New.jpg', height: 48),
                        const SizedBox(width: 12),
                        Expanded(
                          child: RichText(
                            text: const TextSpan(
                              children: [
                                TextSpan(
                                  text: 'Admin ',
                                  style: TextStyle(
                                    fontSize: 30,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF1E3A8A),
                                  ),
                                ),
                                TextSpan(
                                  text: 'Dashboard',
                                  style: TextStyle(
                                    fontSize: 30,
                                    fontWeight: FontWeight.w900,
                                    color: AppPalette.ochre,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Admin profile picture removed for cleaner admin header.
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Welcome back, Admin',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF3B82F6),
                      ),
                    ),
                    const SizedBox(height: 18),
                    // Search bar
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: Color(0xFFBFDBFE)),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x1A1E3A8A),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Search users, businesses, events...',
                          hintStyle: TextStyle(
                            color: AppPalette.mutedText,
                            fontWeight: FontWeight.w500,
                          ),
                          prefixIcon: const Icon(Icons.search_rounded,
                              color: AppPalette.mutedText),
                          suffixIcon: const Icon(Icons.mic_rounded,
                              color: AppPalette.mutedText),
                          border: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ── Content sheet ──
        SliverToBoxAdapter(
          child: Transform.translate(
            offset: const Offset(0, -24),
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFD),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                border: Border(
                  top: BorderSide(color: Color(0xFFBFDBFE), width: 1),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 22),

                  // ── Stats overview cards ──
                  _buildStatsOverview(),
                  const SizedBox(height: 28),

                  // ── Quick Actions ──
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child:
                        _buildSectionHeader('Quick Actions', onViewAll: null),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildQuickActions(),
                  ),
                  const SizedBox(height: 28),

                  // ── Engagement & Activity row ──
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildEngagementOverview(),
                  ),
                  const SizedBox(height: 28),

                  // ── Recent Users ──
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildSectionHeader('Recent Users',
                        onViewAll: _openUsersManagement),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildRecentUsersSection(),
                  ),
                  const SizedBox(height: 28),

                  // ── Weekly Analytics Chart ──
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildWeeklyAnalyticsSection(),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Top-level platform overview stats in a responsive grid.
  Widget _buildStatsOverview() {
    final items = [
      _StatItem(
        stream: widget.dashboardService.totalUsersCount(),
        trendStream: widget.dashboardService.usersTrend(),
        icon: Icons.groups_rounded,
        iconColor: const Color(0xFF3B82F6),
        label: 'Total Users',
        onTap: _openUsersManagement,
      ),
      _StatItem(
        stream: widget.dashboardService.totalBusinessesCount(),
        trendStream: widget.dashboardService.businessesTrend(),
        icon: Icons.business_rounded,
        iconColor: const Color(0xFF1E3A8A),
        label: 'Businesses',
        onTap: _openBusinessManagement,
      ),
      _StatItem(
        stream: widget.dashboardService.totalEventsCount(),
        trendStream: widget.dashboardService.eventsTrend(),
        icon: Icons.event_note_rounded,
        iconColor: const Color(0xFFF59E0B),
        label: 'Events',
        onTap: _openEventsManagement,
      ),
      _StatItem(
        stream: widget.dashboardService.pendingLocalUsersCount(),
        trendStream: widget.dashboardService.approvalsTrend(),
        icon: Icons.person_add_alt_1_rounded,
        iconColor: const Color(0xFF10B981),
        label: 'Pending Approvals',
        onTap: _openUsersManagement,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= Breakpoints.desktop
            ? 4
            : constraints.maxWidth >= Breakpoints.tablet
                ? 2
                : 2;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.55,
            children:
                items.map((item) => _buildStatCard(item: item)).toList(),
          ),
        );
      },
    );
  }

  Widget _buildStatCard({required _StatItem item}) {
    return StreamBuilder<int>(
      stream: item.stream,
      builder: (context, countSnapshot) {
        return StreamBuilder<MetricTrend>(
          stream: item.trendStream,
          builder: (context, trendSnapshot) {
            return _DashboardStatCard(
              icon: item.icon,
              iconColor: item.iconColor,
              value: countSnapshot.data?.toString() ?? '—',
              label: item.label,
              trend: trendSnapshot.data,
              onTap: item.onTap,
            );
          },
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, {VoidCallback? onViewAll}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppPalette.charcoal,
          ),
        ),
        if (onViewAll != null)
          GestureDetector(
            onTap: onViewAll,
            child: const Row(
              children: [
                Text(
                  'View All',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppPalette.ochre,
                  ),
                ),
                SizedBox(width: 2),
                Icon(Icons.chevron_right_rounded,
                    color: AppPalette.ochre, size: 18),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildRecentUsersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        // Stream recent local users
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: _recentUsersStream(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppPalette.surface.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: AppPalette.border.withValues(alpha: 0.5)),
                ),
                child: const Center(
                  child: Text(
                    'No recent users',
                    style: TextStyle(color: AppPalette.mutedText),
                  ),
                ),
              );
            }
            final users = snapshot.data!;
            return Column(
              children: users.map((user) {
                final name = (user['name'] as String? ?? 'Unknown').trim();
                final suburb = (user['suburb'] as String? ?? '').trim();
                final status =
                    (user['approvalStatus'] as String? ?? 'pending').trim();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _RecentUserCard(
                    name: name,
                    subtitle: suburb,
                    status: status,
                    onTap: _openUsersManagement,
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Stream<List<Map<String, dynamic>>> _recentUsersStream() {
    try {
      final fs = _referenceFirestore();
      return fs
          .collection('local_users')
          .orderBy('createdAt', descending: true)
          .limit(3)
          .snapshots()
          .map((snap) =>
              snap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList());
    } catch (_) {
      return const Stream.empty();
    }
  }

  /// Access Firestore instance; works for real usage.
  FirebaseFirestore _referenceFirestore() {
    return FirebaseFirestore.instance;
  }

  /// Wide, tappable quick-action tiles laid out in a responsive grid.
  Widget _buildQuickActions() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= Breakpoints.desktop
            ? 3
            : constraints.maxWidth >= Breakpoints.tablet
                ? 2
                : 2;
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 2.4,
          children: [
            _QuickActionButton(
              icon: Icons.business_outlined,
              color: const Color(0xFF3B82F6),
              label: 'Add Business',
              onTap: _openCreateBusiness,
            ),
            _QuickActionButton(
              icon: Icons.verified_outlined,
              color: const Color(0xFF10B981),
              label: 'Verify Business',
              onTap: _openBusinessManagement,
            ),
            _QuickActionButton(
              icon: Icons.event_available_outlined,
              color: const Color(0xFFF59E0B),
              label: 'Create Event',
              onTap: _openCreateEvent,
            ),
            _QuickActionButton(
              icon: Icons.report_outlined,
              color: const Color(0xFFEF4444),
              label: 'Review Reports',
              onTap: _openReportsHub,
            ),
            _QuickActionButton(
              icon: Icons.feedback_outlined,
              color: const Color(0xFF8B5CF6),
              label: 'Feedback',
              onTap: _openFeedbackReview,
            ),
            _QuickActionButton(
              icon: Icons.email_outlined,
              color: const Color(0xFFEC4899),
              label: 'Broadcast Email',
              onTap: _openEmailBroadcast,
            ),
          ],
        );
      },
    );
  }

  /// Horizontal panel showing engagement metrics with icons and labels.
  Widget _buildEngagementOverview() {
    final items = [
      _EngagementItem(
        stream: widget.dashboardService.totalProfileViewsCount(),
        icon: Icons.visibility_rounded,
        color: const Color(0xFF4F8FFF),
        label: 'Profile Views',
      ),
      _EngagementItem(
        stream: widget.dashboardService.totalSavesCount(),
        icon: Icons.bookmark_rounded,
        color: const Color(0xFF2ECC71),
        label: 'Saves',
      ),
      _EngagementItem(
        stream: widget.dashboardService.totalReviewsCount(),
        icon: Icons.reviews_rounded,
        color: const Color(0xFF9B59B6),
        label: 'Reviews',
      ),
      _EngagementItem(
        stream: widget.dashboardService.totalBuzzVotesCount(),
        icon: Icons.bolt_rounded,
        color: const Color(0xFF3BD0EE),
        label: 'Buzz Votes',
      ),
      _EngagementItem(
        stream: widget.dashboardService.totalCrowdReportsCount(),
        icon: Icons.people_rounded,
        color: const Color(0xFFF39C12),
        label: 'Crowd Reports',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Engagement', onViewAll: _openBusinessManagement),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: items
                .map((item) => _EngagementChip(item: item))
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildWeeklyAnalyticsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Weekly Activity',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppPalette.charcoal,
              ),
            ),
            StreamBuilder<AdminWeeklyAnalytics>(
              stream: widget.dashboardService.weeklyAnalytics(),
              builder: (context, snapshot) {
                final total = snapshot.hasData
                    ? snapshot.data!.newUsers.values.reduce((a, b) => a + b) +
                        snapshot.data!.businessRegistrations.values
                            .reduce((a, b) => a + b) +
                        snapshot.data!.eventsCreated.values
                            .reduce((a, b) => a + b) +
                        snapshot.data!.reportsReceived.values
                            .reduce((a, b) => a + b)
                    : null;
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppPalette.ochre.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    total != null ? '$total this week' : '—',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppPalette.ochre,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'New users, business registrations, events and reports',
          style: TextStyle(
            fontSize: 12,
            color: AppPalette.mutedText,
          ),
        ),
        const SizedBox(height: 14),
        StreamBuilder<AdminWeeklyAnalytics>(
          stream: widget.dashboardService.weeklyAnalytics(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return Container(
                height: 220,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppPalette.surface.withValues(alpha: 0.80),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                      color: AppPalette.border.withValues(alpha: 0.5)),
                ),
                child: const CircularProgressIndicator(color: AppPalette.ochre),
              );
            }

            final analytics = snapshot.data!;
            final maxY =
                analytics.maxValue < 5 ? 5.0 : analytics.maxValue * 1.2;

            return Container(
              height: 260,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppPalette.surface.withValues(alpha: 0.80),
                borderRadius: BorderRadius.circular(18),
                border:
                    Border.all(color: AppPalette.border.withValues(alpha: 0.5)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Expanded(
                    child: LineChart(
                      LineChartData(
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: maxY / 5,
                          getDrawingHorizontalLine: (_) => FlLine(
                            color: Colors.grey.shade300,
                            strokeWidth: 1,
                            dashArray: [4, 4],
                          ),
                        ),
                        titlesData: FlTitlesData(
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 32,
                              interval: maxY / 5,
                              getTitlesWidget: (value, meta) {
                                return Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: Text(
                                    value.toInt().toString(),
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: AppPalette.mutedText,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: 1,
                              getTitlesWidget: (value, meta) {
                                const days = [
                                  'Mon',
                                  'Tue',
                                  'Wed',
                                  'Thu',
                                  'Fri',
                                  'Sat',
                                  'Sun'
                                ];
                                final index = value.toInt();
                                if (index < 0 || index >= days.length) {
                                  return const SizedBox.shrink();
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    days[index],
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: AppPalette.mutedText,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        minX: 0,
                        maxX: 6,
                        minY: 0,
                        maxY: maxY,
                        lineBarsData: [
                          _buildLineBarData(
                            analytics.newUsers.values,
                            AppPalette.ochre,
                            showDots: true,
                          ),
                          _buildLineBarData(
                            analytics.businessRegistrations.values,
                            AppPalette.deepBlue,
                          ),
                          _buildLineBarData(
                            analytics.eventsCreated.values,
                            AppPalette.gold,
                          ),
                          _buildLineBarData(
                            analytics.reportsReceived.values,
                            Colors.red.shade700,
                          ),
                        ],
                        lineTouchData: LineTouchData(
                          touchTooltipData: LineTouchTooltipData(
                            getTooltipColor: (_) => AppPalette.charcoal,
                            getTooltipItems: (touchedSpots) {
                              return touchedSpots.map((spot) {
                                return LineTooltipItem(
                                  '${spot.y.toInt()}',
                                  const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                );
                              }).toList();
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 14,
                    runSpacing: 6,
                    children: [
                      _buildChartLegend('New Users', AppPalette.ochre),
                      _buildChartLegend('Businesses', AppPalette.deepBlue),
                      _buildChartLegend('Events', AppPalette.gold),
                      _buildChartLegend('Reports', Colors.red.shade700),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  LineChartBarData _buildLineBarData(
    List<int> values,
    Color color, {
    bool showDots = false,
  }) {
    return LineChartBarData(
      spots: List.generate(
        values.length,
        (i) => FlSpot(i.toDouble(), values[i].toDouble()),
      ),
      isCurved: true,
      color: color,
      barWidth: 3,
      isStrokeCapRound: true,
      dotData: FlDotData(
        show: showDots,
        getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
          radius: 4,
          color: color,
          strokeWidth: 2,
          strokeColor: Colors.white,
        ),
      ),
      belowBarData: BarAreaData(
        show: true,
        color: color.withValues(alpha: 0.08),
      ),
    );
  }

  Widget _buildChartLegend(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppPalette.mutedText,
          ),
        ),
      ],
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
              color: AppPalette.charcoal,
            ),
          ),
          const SizedBox(height: 20),

          // ── Profile card (admin profile picture removed) ──
          Card(
            color: AppPalette.surface,
            elevation: 4,
            shadowColor: AppPalette.cardShadow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: AppPalette.border.withValues(alpha: 0.5)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.account_circle_rounded,
                      size: 48, color: AppPalette.deepBlue),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Admin',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppPalette.charcoal,
                          ),
                        ),
                        if ((AdminAuth.currentAdminEmail ?? '').isNotEmpty)
                          Text(
                            AdminAuth.currentAdminEmail!,
                            style: const TextStyle(color: AppPalette.mutedText),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ── Account Settings ──
          _settingsSectionLabel('Account Settings'),
          Card(
            color: AppPalette.surface,
            elevation: 4,
            shadowColor: AppPalette.cardShadow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: AppPalette.border.withValues(alpha: 0.5)),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: _settingsIcon(Icons.report_outlined),
                  title: const Text('Reports Hub',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppPalette.charcoal)),
                  subtitle: const Text(
                      'Moderate reported events and recommendations',
                      style: TextStyle(color: AppPalette.mutedText)),
                  trailing: const Icon(Icons.chevron_right_rounded,
                      color: AppPalette.mutedText),
                  onTap: _openReportsHub,
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: _settingsIcon(Icons.store_outlined),
                  title: const Text('Manage Businesses',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppPalette.charcoal)),
                  subtitle: const Text(
                      'Verify, edit, deactivate and archive listings',
                      style: TextStyle(color: AppPalette.mutedText)),
                  trailing: const Icon(Icons.chevron_right_rounded,
                      color: AppPalette.mutedText),
                  onTap: _openBusinessManagement,
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: _settingsIcon(Icons.dynamic_feed_outlined),
                  title: const Text('Community Feed',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppPalette.charcoal)),
                  subtitle: const Text('Pin, highlight and remove feed content',
                      style: TextStyle(color: AppPalette.mutedText)),
                  trailing: const Icon(Icons.chevron_right_rounded,
                      color: AppPalette.mutedText),
                  onTap: _openCommunityFeed,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── App Settings ──
          _settingsSectionLabel('App Settings'),
          Card(
            color: AppPalette.surface,
            elevation: 4,
            shadowColor: AppPalette.cardShadow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: AppPalette.border.withValues(alpha: 0.5)),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: _settingsIcon(Icons.feedback_outlined),
                  title: const Text('Feedback Review',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppPalette.charcoal)),
                  subtitle: const Text('Manage user feedback and responses',
                      style: TextStyle(color: AppPalette.mutedText)),
                  trailing: const Icon(Icons.chevron_right_rounded,
                      color: AppPalette.mutedText),
                  onTap: _openFeedbackReview,
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: _settingsIcon(Icons.category_rounded),
                  title: const Text('Event Categories',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppPalette.charcoal)),
                  subtitle: const Text('Manage event category taxonomy',
                      style: TextStyle(color: AppPalette.mutedText)),
                  trailing: const Icon(Icons.chevron_right_rounded,
                      color: AppPalette.mutedText),
                  onTap: _openCategoryManagement,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── BrisConnect ──
          _settingsSectionLabel('BrisConnect+'),
          Card(
            color: AppPalette.surface,
            elevation: 4,
            shadowColor: AppPalette.cardShadow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: AppPalette.border.withValues(alpha: 0.5)),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: _settingsIcon(Icons.sms_outlined),
                  title: const Text('SMS Broadcast',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppPalette.charcoal)),
                  subtitle: const Text('Send SMS announcements to users',
                      style: TextStyle(color: AppPalette.mutedText)),
                  trailing: const Icon(Icons.chevron_right_rounded,
                      color: AppPalette.mutedText),
                  onTap: _openSmsBroadcast,
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: _settingsIcon(Icons.email_outlined),
                  title: const Text('Email Broadcast',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppPalette.charcoal)),
                  subtitle: const Text('Send email announcements to users',
                      style: TextStyle(color: AppPalette.mutedText)),
                  trailing: const Icon(Icons.chevron_right_rounded,
                      color: AppPalette.mutedText),
                  onTap: _openEmailBroadcast,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Support ──
          _settingsSectionLabel('Support'),
          Card(
            color: AppPalette.surface,
            elevation: 4,
            shadowColor: AppPalette.cardShadow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: AppPalette.border.withValues(alpha: 0.5)),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: _settingsIcon(Icons.help_outline_rounded),
                  title: const Text('Help & Support',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppPalette.charcoal)),
                  subtitle: const Text('Get help with admin features',
                      style: TextStyle(color: AppPalette.mutedText)),
                  trailing: const Icon(Icons.chevron_right_rounded,
                      color: AppPalette.mutedText),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Contact: support@brisconnect.app')),
                    );
                  },
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: _settingsIcon(Icons.info_outline_rounded),
                  title: const Text('About BrisConnect+',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppPalette.charcoal)),
                  subtitle: const Text('Version, credits & legal',
                      style: TextStyle(color: AppPalette.mutedText)),
                  trailing: const Icon(Icons.chevron_right_rounded,
                      color: AppPalette.mutedText),
                  onTap: () {
                    showAboutDialog(
                      context: context,
                      applicationName: 'BrisConnect+',
                      applicationVersion: '1.0.0',
                      applicationLegalese: '© 2026 BrisConnect+ Team',
                      applicationIcon:
                          Image.asset('assets/Brisconnect New.jpg', height: 48),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // ── Logout ──
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () async {
                await AdminAuth.logout();
                if (!mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                      builder: (_) => const AnimatedWelcomeScreen()),
                  (route) => false,
                );
              },
              icon: const Icon(Icons.logout_rounded, size: 20),
              label: const Text('Logout',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade50.withValues(alpha: 0.9),
                foregroundColor: Colors.red.shade700,
                elevation: 0,
                side: BorderSide(color: Colors.red.shade300, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
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
          color: AppPalette.mutedText,
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
        color: AppPalette.deepBlue.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: AppPalette.deepBlue, size: 20),
    );
  }
}

// ── Stat card for the overview grid ──
class _DashboardStatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  final MetricTrend? trend;
  final VoidCallback? onTap;

  const _DashboardStatCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    this.trend,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const Spacer(),
                if (trend != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: trend!.isUp
                          ? Colors.green.shade50
                          : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: trend!.isUp
                            ? Colors.green.shade300
                            : Colors.red.shade300,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          trend!.isUp
                              ? Icons.arrow_upward_rounded
                              : Icons.arrow_downward_rounded,
                          color: trend!.isUp
                              ? Colors.green.shade700
                              : Colors.red.shade700,
                          size: 10,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${trend!.change.abs()}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: trend!.isUp
                                ? Colors.green.shade700
                                : Colors.red.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppPalette.charcoal,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppPalette.mutedText,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Quick action button ──
class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppPalette.charcoal,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: AppPalette.mutedText,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Engagement chip descriptor ──
class _EngagementItem {
  final Stream<int> stream;
  final IconData icon;
  final Color color;
  final String label;

  const _EngagementItem({
    required this.stream,
    required this.icon,
    required this.color,
    required this.label,
  });
}

// ── Engagement metric chip ──
class _EngagementChip extends StatelessWidget {
  final _EngagementItem item;

  const _EngagementChip({required this.item});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: item.stream,
      builder: (context, snapshot) {
        final value = snapshot.data?.toString() ?? '—';
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: item.color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: item.color.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(item.icon, color: item.color, size: 18),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: item.color,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.label,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppPalette.mutedText,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Recent user card ──
class _RecentUserCard extends StatelessWidget {
  final String name;
  final String subtitle;
  final String status;
  final VoidCallback? onTap;

  const _RecentUserCard({
    required this.name,
    required this.subtitle,
    required this.status,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = status == 'approved';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppPalette.surface.withValues(alpha: 0.80),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppPalette.border.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: AppPalette.ochre.withValues(alpha: 0.15),
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppPalette.ochre,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppPalette.charcoal,
                    ),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppPalette.mutedText,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isActive ? Colors.green.shade50 : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color:
                      isActive ? Colors.green.shade300 : Colors.orange.shade300,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: isActive
                          ? Colors.green.shade600
                          : Colors.orange.shade600,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    isActive ? 'Active' : 'Pending',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isActive
                          ? Colors.green.shade700
                          : Colors.orange.shade700,
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
}

// ── Bottom nav item ──
class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 56,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected ? AppPalette.deepBlue : AppPalette.mutedText,
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color:
                      isSelected ? AppPalette.deepBlue : AppPalette.mutedText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryManagementSheet extends StatefulWidget {
  const _CategoryManagementSheet({
    required this.initialCategories,
    required this.onSave,
  });

  final List<String> initialCategories;
  final Future<void> Function(List<String>) onSave;

  @override
  State<_CategoryManagementSheet> createState() =>
      _CategoryManagementSheetState();
}

class _CategoryManagementSheetState extends State<_CategoryManagementSheet> {
  late final List<String> _categories;
  final _addController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _categories = List<String>.from(widget.initialCategories);
  }

  @override
  void dispose() {
    _addController.dispose();
    super.dispose();
  }

  void _addCategory() {
    final value = _addController.text.trim();
    if (value.isEmpty || _categories.contains(value)) return;
    setState(() => _categories.add(value));
    _addController.clear();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await widget.onSave(_categories);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save categories.')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Manage Event Categories',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppPalette.charcoal,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Changes apply to all event forms across the app.',
            style: TextStyle(color: AppPalette.mutedText),
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: ReorderableListView.builder(
              shrinkWrap: true,
              itemCount: _categories.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex--;
                  final item = _categories.removeAt(oldIndex);
                  _categories.insert(newIndex, item);
                });
              },
              itemBuilder: (context, index) {
                final cat = _categories[index];
                return ListTile(
                  key: ValueKey(cat),
                  dense: true,
                  leading: const Icon(Icons.drag_handle_rounded,
                      color: AppPalette.mutedText),
                  title: Text(cat,
                      style: const TextStyle(
                          color: AppPalette.charcoal,
                          fontWeight: FontWeight.w600)),
                  trailing: IconButton(
                    icon: Icon(Icons.close_rounded,
                        color: Colors.red.shade700, size: 20),
                    onPressed: () =>
                        setState(() => _categories.removeAt(index)),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _addController,
                  decoration: const InputDecoration(
                    hintText: 'New category name',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.words,
                  onSubmitted: (_) => _addCategory(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _addCategory,
                icon: const Icon(Icons.add_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: AppPalette.deepBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _isSaving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: AppPalette.deepBlue,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Save Categories'),
            ),
          ),
        ],
      ),
    );
  }
}
