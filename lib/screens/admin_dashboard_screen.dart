import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:brisconnect/auth/app_user_role.dart';
import 'package:brisconnect/auth/admin_auth.dart';
import 'package:brisconnect/screens/admin_event_review_screen.dart';
import 'package:brisconnect/screens/admin_feedback_review_screen.dart';
import 'package:brisconnect/screens/admin_email_broadcast_screen.dart';
import 'package:brisconnect/screens/admin_sms_broadcast_screen.dart';
import 'package:brisconnect/screens/admin_user_management_screen.dart';
import 'package:brisconnect/screens/admin_reported_events_screen.dart';
import 'package:brisconnect/screens/welcome_screen_new.dart';
import 'package:brisconnect/services/admin_dashboard_service.dart';
import 'package:brisconnect/services/admin_event_service.dart';
import 'package:brisconnect/services/event_category_service.dart';
import 'package:brisconnect/services/firebase_media_service.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/utils/profile_image_utils.dart';
import 'package:brisconnect/widgets/role_guard.dart';

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
  final FirebaseMediaService _mediaService = FirebaseMediaService();
  final EventCategoryService _categoryService = EventCategoryService();
  final AdminEventService _adminEventService = AdminEventService();
  Uint8List? _pendingProfileImageBytes;
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

  ImageProvider<Object>? _profileImageProvider() {
    if (_pendingProfileImageBytes != null) {
      return MemoryImage(_pendingProfileImageBytes!);
    }
    final imageUrl = AdminAuth.profileImageUrl?.trim() ?? '';
    if (imageUrl.isNotEmpty) {
      return NetworkImage(imageUrl);
    }
    return null;
  }

  Future<ImageSource?> _pickImageSource() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppPalette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadAdminProfileImage() async {
    final email = AdminAuth.currentAdminEmail;
    if (email == null || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in as an admin first.')),
      );
      return;
    }

    final source = await _pickImageSource();
    if (source == null) return;
    if (!mounted) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      imageQuality: 75,
      maxWidth: 720,
      maxHeight: 720,
      preferredCameraDevice: CameraDevice.front,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    final fileName = picked.name;

    if (!ProfileImageUtils.isSupportedImage(bytes)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only JPG and PNG images are supported.')),
      );
      return;
    }

    if (bytes.length > ProfileImageUtils.maxImageBytes) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image is too large. Please choose a smaller image.')),
      );
      return;
    }

    bool ok = false;
    setState(() => _pendingProfileImageBytes = bytes);
    try {
      final uploaded = await _mediaService.uploadProfileImage(
        role: 'admin',
        email: email,
        bytes: bytes,
        fileName: fileName,
        previousStoragePath: AdminAuth.profileImageStoragePath,
      );
      if (!mounted) return;
      ok = await AdminAuth.updateProfileImage(
        imageUrl: uploaded.downloadUrl,
        storagePath: uploaded.storagePath,
      );
      if (!mounted) return;
      if (ok) {
        setState(() => _pendingProfileImageBytes = null);
      }
    } on FormatException catch (error) {
      setState(() => _pendingProfileImageBytes = null);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
      return;
    } catch (error) {
      debugPrint('[AdminDashboard] Profile image upload failed: $error');
      setState(() => _pendingProfileImageBytes = null);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Profile picture updated successfully.'
             : 'Could not update profile picture. Please try again.',
        ),
        backgroundColor: ok ? Colors.green.shade700 : Colors.red.shade700,
      ),
    );
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
    setState(() => _selectedNavIndex = 1);
  }

  void _openEventsManagement() {
    setState(() => _selectedNavIndex = 2);
  }

  void _openReportedEvents() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminReportedEventsScreen(),
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
        extendBodyBehindAppBar: true,
        extendBody: true,
        body: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (_selectedNavIndex != 0) {
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

    // Wrap scaffold with solid dark navy background
    final withBackground = Stack(
      children: [
        const Positioned.fill(
          child: ColoredBox(color: Color(0xFF0D1117)),
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
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C2E),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.20),
            blurRadius: 12,
            offset: const Offset(0, -2),
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
                onTap: () => setState(() { _selectedNavIndex = 0; _isNavVisible = true; }),
              ),
              _NavItem(
                icon: Icons.groups_rounded,
                label: 'Users',
                isSelected: _selectedNavIndex == 1,
                onTap: () => setState(() { _selectedNavIndex = 1; _isNavVisible = true; }),
              ),
              // Center Events button
              GestureDetector(
                onTap: () => setState(() { _selectedNavIndex = 2; _isNavVisible = true; }),
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF252540), Color(0xFF1C1C2E)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFF252540),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.event_rounded, color: Colors.white, size: 24),
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
                isSelected: _selectedNavIndex == 3,
                onTap: () => setState(() { _selectedNavIndex = 3; _isNavVisible = true; }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUsersTab() {
    return AdminUserManagementScreen(enforceRoleGuard: false);
  }

  Widget _buildEventsTab() {
    return AdminEventReviewScreen(
      eventService: _adminEventService,
      enforceRoleGuard: false,
    );
  }

  Widget _buildHomeTab() {
    final email = AdminAuth.currentAdminEmail ?? '';
    final displayName = email.isNotEmpty
        ? email.split('@').first
            .split('.')
            .map((s) => s.isNotEmpty ? '${s[0].toUpperCase()}${s.substring(1)}' : s)
            .join(' ')
        : 'Admin';
    final heroAvatarRadius =
      (MediaQuery.of(context).size.width * 0.16).clamp(56.0, 72.0).toDouble();

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
                                    color: Colors.white,
                                    shadows: [
                                      Shadow(
                                        offset: Offset(0, 1),
                                        blurRadius: 8,
                                        color: Colors.black54,
                                      ),
                                    ],
                                  ),
                                ),
                                TextSpan(
                                  text: 'Dashboard',
                                  style: TextStyle(
                                    fontSize: 30,
                                    fontWeight: FontWeight.w900,
                                    color: AppPalette.ochre,
                                    shadows: [
                                      Shadow(
                                        offset: Offset(0, 1),
                                        blurRadius: 8,
                                        color: Colors.black54,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Admin profile picture (top-right)
                        ValueListenableBuilder<int>(
                          valueListenable: AdminAuth.profileVersion,
                          builder: (context, _, __) {
                            final profileImage = _profileImageProvider();
                            return GestureDetector(
                              onTap: _uploadAdminProfileImage,
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.25),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: CircleAvatar(
                                  radius: heroAvatarRadius,
                                  backgroundColor: AppPalette.ochre,
                                  backgroundImage: profileImage,
                                  child: profileImage == null
                                      ? Icon(
                                          Icons.person_rounded,
                                          color: Colors.white,
                                          size: heroAvatarRadius * 0.9,
                                        )
                                      : null,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Welcome Back, $displayName!',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.white70,
                        shadows: [
                          Shadow(
                            offset: Offset(0, 1),
                            blurRadius: 6,
                            color: Colors.black38,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    // Search bar
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF252540),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Search users, events, stats...',
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
                color: Color(0xFF1C1C2E),
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 22),

                  // ── Stats cards row ──
                  _buildStatsCarousel(),
                  const SizedBox(height: 20),

                  // ── Recent Users ──
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildRecentUsersSection(),
                  ),
                  const SizedBox(height: 20),

                  // ── Quick Actions ──
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildQuickActions(),
                  ),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsCarousel() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: StreamBuilder<int>(
        stream: widget.dashboardService.totalUsersCount(),
        builder: (context, usersSnap) {
          return StreamBuilder<int>(
            stream: widget.dashboardService.totalEventsCount(),
            builder: (context, eventsSnap) {
              return StreamBuilder<int>(
                stream: widget.dashboardService.pendingEventReportsCount(),
                builder: (context, reportsSnap) {
                  return Row(
                    children: [
                      Expanded(
                        child: _DashboardStatCard(
                          icon: Icons.groups_rounded,
                          iconColor: AppPalette.ochre,
                          value: usersSnap.data?.toString() ?? '—',
                          label: 'Users',
                          subtext: 'Total Registered',
                          onTap: _openUsersManagement,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _DashboardStatCard(
                          icon: Icons.event_note_rounded,
                          iconColor: AppPalette.gold,
                          value: eventsSnap.data?.toString() ?? '—',
                          label: 'Events',
                          subtext: 'In System',
                          onTap: _openEventsManagement,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _DashboardStatCard(
                          icon: Icons.flag_rounded,
                          iconColor: Colors.red.shade700,
                          value: reportsSnap.data?.toString() ?? '—',
                          label: 'Reports',
                          subtext: 'Pending Review',
                          onTap: _openReportedEvents,
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildRecentUsersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Users',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppPalette.charcoal,
              ),
            ),
            GestureDetector(
              onTap: _openUsersManagement,
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
        ),
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
                  border: Border.all(color: AppPalette.border.withValues(alpha: 0.5)),
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
                final suburb =
                    (user['suburb'] as String? ?? '').trim();
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
          .map((snap) => snap.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList());
    } catch (_) {
      return const Stream.empty();
    }
  }

  /// Access Firestore instance; works for real usage.
  FirebaseFirestore _referenceFirestore() {
    return FirebaseFirestore.instance;
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppPalette.charcoal,
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 2.8,
          children: const [],
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
              color: Colors.white,
              shadows: [
                Shadow(
                  offset: Offset(0, 1),
                  blurRadius: 6,
                  color: Colors.black38,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Profile card ──
          ValueListenableBuilder<int>(
            valueListenable: AdminAuth.profileVersion,
            builder: (context, _, __) {
              final profileImage = _profileImageProvider();
              final email = AdminAuth.currentAdminEmail ?? '';
              return Card(
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
                      CircleAvatar(
                        radius: 48,
                        backgroundColor: AppPalette.deepBlue,
                        backgroundImage: profileImage,
                        child: profileImage == null
                            ? const Icon(Icons.person_rounded,
                                color: Colors.white, size: 48)
                            : null,
                      ),
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
                            if (email.isNotEmpty)
                              Text(
                                email,
                                style:
                                    const TextStyle(color: AppPalette.mutedText),
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Change profile picture',
                        onPressed: _uploadAdminProfileImage,
                        icon: const Icon(Icons.photo_camera_outlined,
                            color: AppPalette.deepBlue, size: 22),
                      ),
                    ],
                  ),
                ),
              );
            },
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
                  leading: _settingsIcon(Icons.flag_rounded),
                  title: const Text('Reported Events',
                      style: TextStyle(fontWeight: FontWeight.w600, color: AppPalette.charcoal)),
                  subtitle: const Text('Review flagged event reports',
                      style: TextStyle(color: AppPalette.mutedText)),
                  trailing: const Icon(Icons.chevron_right_rounded,
                      color: AppPalette.mutedText),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AdminReportedEventsScreen(),
                    ),
                  ),
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
                      style: TextStyle(fontWeight: FontWeight.w600, color: AppPalette.charcoal)),
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
                      style: TextStyle(fontWeight: FontWeight.w600, color: AppPalette.charcoal)),
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
                      style: TextStyle(fontWeight: FontWeight.w600, color: AppPalette.charcoal)),
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
                      style: TextStyle(fontWeight: FontWeight.w600, color: AppPalette.charcoal)),
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
                      style: TextStyle(fontWeight: FontWeight.w600, color: AppPalette.charcoal)),
                  subtitle: const Text('Get help with admin features',
                      style: TextStyle(color: AppPalette.mutedText)),
                  trailing: const Icon(Icons.chevron_right_rounded,
                      color: AppPalette.mutedText),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Contact: support@brisconnect.app')),
                    );
                  },
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: _settingsIcon(Icons.info_outline_rounded),
                  title: const Text('About BrisConnect+',
                      style: TextStyle(fontWeight: FontWeight.w600, color: AppPalette.charcoal)),
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
                      applicationIcon: Image.asset('assets/Brisconnect New.jpg', height: 48),
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
                  MaterialPageRoute(builder: (_) => const AnimatedWelcomeScreen()),
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
          color: Colors.white,
          letterSpacing: 0.8,
          shadows: [
            Shadow(
              offset: Offset(0, 1),
              blurRadius: 4,
              color: Colors.black38,
            ),
          ],
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

// ── Stat card for the horizontal carousel ──
class _DashboardStatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  final String subtext;
  final VoidCallback? onTap;

  const _DashboardStatCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    required this.subtext,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppPalette.surface.withValues(alpha: 0.80),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppPalette.border.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 18),
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: iconColor,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppPalette.charcoal,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtext,
              style: const TextStyle(
                fontSize: 11,
                color: AppPalette.mutedText,
              ),
            ),
          ],
        ),
      ),
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
                color: isActive
                    ? Colors.green.shade50
                    : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isActive
                      ? Colors.green.shade300
                      : Colors.orange.shade300,
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
        width: 60,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 24,
              color: isSelected ? Colors.white : Colors.white70,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : Colors.white70,
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
                  title: Text(cat, style: const TextStyle(color: AppPalette.charcoal, fontWeight: FontWeight.w600)),
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
