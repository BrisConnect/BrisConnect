import 'package:flutter/material.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/services/admin_dashboard_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Web-optimized admin dashboard with desktop-friendly layout
/// Features desktop navigation, multi-column layout, and admin-specific features
class WebAdminDashboard extends StatefulWidget {
  const WebAdminDashboard({super.key});

  @override
  State<WebAdminDashboard> createState() => _WebAdminDashboardState();
}

class _WebAdminDashboardState extends State<WebAdminDashboard> {
  int _selectedIndex = 0;
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final AdminDashboardService _dashboardService = AdminDashboardService();

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 900;

    return Scaffold(
      backgroundColor: AppPalette.background,
      body: Row(
        children: [
          if (!isMobile)
            // Desktop sidebar navigation
            NavigationRail(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) {
                setState(() => _selectedIndex = index);
              },
              labelType: NavigationRailLabelType.selected,
              backgroundColor: AppPalette.surface,
              elevation: 1,
              leading: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppPalette.ochre,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.dashboard_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.home_rounded),
                  selectedIcon: Icon(Icons.home_rounded),
                  label: Text('Dashboard'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.people_rounded),
                  selectedIcon: Icon(Icons.people_rounded),
                  label: Text('Users'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.event_rounded),
                  selectedIcon: Icon(Icons.event_rounded),
                  label: Text('Events'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.place_rounded),
                  selectedIcon: Icon(Icons.place_rounded),
                  label: Text('Attractions'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.mail_rounded),
                  selectedIcon: Icon(Icons.mail_rounded),
                  label: Text('Communications'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.feedback_rounded),
                  selectedIcon: Icon(Icons.feedback_rounded),
                  label: Text('Feedback'),
                ),
              ],
            ),
          // Main content area
          Expanded(
            child: Column(
              children: [
                // Top bar with user info
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: AppPalette.surface,
                    border: Border(
                      bottom: BorderSide(
                        color: AppPalette.border.withValues(alpha: 0.2),
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (isMobile)
                        Expanded(
                          child: Text(
                            'BrisConnect+ Admin',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppPalette.charcoal,
                                ),
                          ),
                        )
                      else
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Admin Dashboard',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: AppPalette.charcoal,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Welcome back to BrisConnect+',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppPalette.mutedText,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      Row(
                        children: [
                          if (_currentUser != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppPalette.ochre.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: AppPalette.ochre.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: AppPalette.ochre,
                                    child: Text(
                                      (_currentUser!.email?.substring(0, 1) ?? 'A').toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _currentUser!.displayName ?? 'Admin',
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                      Text(
                                        _currentUser!.email ?? 'admin@brisconnect.com',
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              color: AppPalette.mutedText,
                                              fontSize: 10,
                                            ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(width: 12),
                          IconButton(
                            icon: const Icon(Icons.logout_rounded),
                            tooltip: 'Logout',
                            onPressed: _logout,
                            color: AppPalette.ochre,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Content area
                Expanded(
                  child: _buildContent(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    switch (_selectedIndex) {
      case 0:
        return _buildDashboardContent();
      case 1:
        return _buildUsersContent();
      case 2:
        return _buildEventsContent();
      case 3:
        return _buildAttractionsContent();
      case 4:
        return _buildCommunicationsContent();
      case 5:
        return _buildFeedbackContent();
      default:
        return _buildDashboardContent();
    }
  }

  Widget _buildDashboardContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dashboard Overview',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 24),
          StreamBuilder<int>(
            stream: _dashboardService.totalUsersCount(),
            builder: (context, usersSnap) {
              return StreamBuilder<int>(
                stream: _dashboardService.totalEventsCount(),
                builder: (context, eventsSnap) {
                  return StreamBuilder<int>(
                    stream: _dashboardService.pendingFeedbackCount(),
                    builder: (context, feedbackSnap) {
                      return GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: 2,
                        children: [
                          _buildStatCard(
                            'Total Users',
                            usersSnap.data?.toString() ?? '—',
                            Icons.people_rounded,
                          ),
                          _buildStatCard(
                            'Active Events',
                            eventsSnap.data?.toString() ?? '—',
                            Icons.event_rounded,
                          ),
                          _buildStatCard(
                            'Pending Feedback',
                            feedbackSnap.data?.toString() ?? '—',
                            Icons.feedback_rounded,
                          ),
                        ],
                      );
                    },
                  );
                },
              );
            },
          ),
          const SizedBox(height: 32),
          Text(
            'Quick Actions',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ElevatedButton.icon(
                onPressed: _navigateToSection,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Create Event'),
              ),
              ElevatedButton.icon(
                onPressed: _navigateToSection,
                icon: const Icon(Icons.add_location_rounded),
                label: const Text('Add Attraction'),
              ),
              ElevatedButton.icon(
                onPressed: _navigateToSection,
                icon: const Icon(Icons.mail_rounded),
                label: const Text('Send Broadcast'),
              ),
              OutlinedButton.icon(
                onPressed: _navigateToSection,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Resync Data'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUsersContent() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_rounded,
            size: 64,
            color: AppPalette.ochre.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'User Management',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Manage user accounts, roles, and permissions',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppPalette.mutedText,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventsContent() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_rounded,
            size: 64,
            color: AppPalette.ochre.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Event Management',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create, edit, and manage events',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppPalette.mutedText,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttractionsContent() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.place_rounded,
            size: 64,
            color: AppPalette.ochre.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Attraction Management',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Manage Brisbane attractions and locations',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppPalette.mutedText,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommunicationsContent() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.mail_rounded,
            size: 64,
            color: AppPalette.ochre.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Communications',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Email and SMS broadcasts to users',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppPalette.mutedText,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackContent() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.feedback_rounded,
            size: 64,
            color: AppPalette.ochre.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'User Feedback',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Review and manage user feedback',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppPalette.mutedText,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppPalette.border.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppPalette.ochre.withValues(alpha: 0.2),
                        AppPalette.ochre.withValues(alpha: 0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: AppPalette.ochre,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppPalette.mutedText,
                        fontWeight: FontWeight.w500,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppPalette.charcoal,
                      ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.trending_up_rounded,
                      color: Colors.green,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '+12% this month',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.green,
                          ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToSection() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Feature coming soon...'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/admin/login',
          (route) => false,
        );
      }
    }
  }
}
