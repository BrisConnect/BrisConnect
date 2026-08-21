import 'package:flutter/material.dart';
import 'package:brisconnect/auth/app_user_role.dart';
import 'package:brisconnect/features/admin/dashboard/admin_neon_theme.dart';
import 'package:brisconnect/services/report_event_service.dart';
import 'package:brisconnect/services/photo_report_service.dart';
import 'package:brisconnect/widgets/role_guard.dart';
import 'package:brisconnect/features/admin/dashboard/widgets/admin_sidebar.dart';
import 'package:intl/intl.dart';

/// Unified reports management screen for all trust-and-safety content.
/// Displays event reports, photo reports, recommendation reports, and feed moderation
/// in a single unified list with filtering, search, and action capabilities.
class AdminReportsHubScreen extends StatefulWidget {
  final bool enforceRoleGuard;
  final bool isEmbedded;

  const AdminReportsHubScreen({
    super.key,
    this.enforceRoleGuard = true,
    this.isEmbedded = false,
  });

  @override
  State<AdminReportsHubScreen> createState() => _AdminReportsHubScreenState();
}

class _AdminReportsHubScreenState extends State<AdminReportsHubScreen> {
  late final ReportEventService _eventReportService = ReportEventService();
  late final PhotoReportService _photoReportService = PhotoReportService();

  final TextEditingController _searchController = TextEditingController();
  String _selectedTypeFilter = 'all'; // all, events, recommendations, photos, feed
  String _selectedStatusFilter = 'all'; // all, open, pending, reviewed, resolved, rejected
  final String _sortOrder = 'newest'; // newest, oldest

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width > 1024;

    final bodyContent = Scaffold(
      backgroundColor: AdminNeonTheme.bgDeepNavy,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AdminNeonTheme.headerBg,
        foregroundColor: AdminNeonTheme.textPrimary,
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reports',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: AdminNeonTheme.textPrimary,
                fontSize: 24,
              ),
            ),
            Text(
              'Review and manage reported content',
              style: TextStyle(
                fontWeight: FontWeight.w400,
                color: AdminNeonTheme.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
          children: [
            _buildSearchBar(),
            const SizedBox(height: 16),
            _buildFilterChips(),
            const SizedBox(height: 20),
            _buildReportsList(),
          ],
        ),
      ),
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
          selectedIndex: 3, // Reports
          onDestinationSelected: (index) {
            _handleNavigation(context, index);
          },
        ),
        Expanded(child: guarded),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: AdminNeonTheme.glassSurfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AdminNeonTheme.glassBorder,
          width: 1,
        ),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: 'Search reports...',
          hintStyle: const TextStyle(color: AdminNeonTheme.textMuted),
          prefixIcon: const Icon(Icons.search_rounded,
              color: AdminNeonTheme.textSecondary),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
        ),
        style: const TextStyle(color: AdminNeonTheme.textPrimary),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Report Type Filter
        Text(
          'REPORT TYPE',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AdminNeonTheme.textSecondary,
                letterSpacing: 0.5,
              ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _FilterChip(
                label: 'All',
                selected: _selectedTypeFilter == 'all',
                onTap: () => setState(() => _selectedTypeFilter = 'all'),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Events',
                selected: _selectedTypeFilter == 'events',
                onTap: () => setState(() => _selectedTypeFilter = 'events'),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Recommendations',
                selected: _selectedTypeFilter == 'recommendations',
                onTap: () =>
                    setState(() => _selectedTypeFilter = 'recommendations'),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Photos',
                selected: _selectedTypeFilter == 'photos',
                onTap: () => setState(() => _selectedTypeFilter = 'photos'),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Feed/Posts',
                selected: _selectedTypeFilter == 'feed',
                onTap: () => setState(() => _selectedTypeFilter = 'feed'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Report Status Filter
        Text(
          'STATUS',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AdminNeonTheme.textSecondary,
                letterSpacing: 0.5,
              ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _FilterChip(
                label: 'All',
                selected: _selectedStatusFilter == 'all',
                onTap: () => setState(() => _selectedStatusFilter = 'all'),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Open',
                selected: _selectedStatusFilter == 'open',
                onTap: () => setState(() => _selectedStatusFilter = 'open'),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Pending',
                selected: _selectedStatusFilter == 'pending',
                onTap: () => setState(() => _selectedStatusFilter = 'pending'),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Reviewed',
                selected: _selectedStatusFilter == 'reviewed',
                onTap: () =>
                    setState(() => _selectedStatusFilter = 'reviewed'),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Resolved',
                selected: _selectedStatusFilter == 'resolved',
                onTap: () =>
                    setState(() => _selectedStatusFilter = 'resolved'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReportsList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchUnifiedReports(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              valueColor: const AlwaysStoppedAnimation<Color>(
                AdminNeonTheme.neonOrange,
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading reports: ${snapshot.error}',
              style: const TextStyle(color: AdminNeonTheme.textSecondary),
            ),
          );
        }

        final reports = snapshot.data ?? [];
        if (reports.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'No reports match your filters',
                style: const TextStyle(
                  color: AdminNeonTheme.textSecondary,
                  fontSize: 16,
                ),
              ),
            ),
          );
        }

        return Column(
          children: reports
              .map((report) => _ReportRow(report: report))
              .toList(),
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _fetchUnifiedReports() async {
    final reports = <Map<String, dynamic>>[];

    // Fetch event reports
    if (_selectedTypeFilter == 'all' || _selectedTypeFilter == 'events') {
      try {
        final eventReports =
            await _eventReportService.watchReportsByStatus('pending').first;
        for (final report in eventReports) {
          if (_matchesFilters(
            type: 'events',
            status: report.status,
            title: report.eventId,
          )) {
            reports.add({
              'type': 'events',
              'id': report.id,
              'reportType': 'Event Report',
              'title': report.eventId,
              'reason': report.reason,
              'reporter': report.visitorEmail,
              'status': report.status,
              'severity': report.severity,
              'date': report.createdAt,
              'comments': report.comments,
            });
          }
        }
      } catch (e) {
        debugPrint('[AdminReports] Error fetching event reports: $e');
      }
    }

    // Fetch photo reports
    if (_selectedTypeFilter == 'all' || _selectedTypeFilter == 'photos') {
      try {
        final photoReports =
            await _photoReportService.watchReportsByStatus('pending').first;
        for (final report in photoReports) {
          if (_matchesFilters(
            type: 'photos',
            status: report.status,
            title: report.photoId,
          )) {
            reports.add({
              'type': 'photos',
              'id': report.id,
              'reportType': 'Photo Report',
              'title': report.photoId,
              'reason': report.reason,
              'reporter': report.visitorEmail,
              'status': report.status,
              'severity': report.severity,
              'date': report.createdAt,
              'comments': report.comments,
            });
          }
        }
      } catch (e) {
        debugPrint('[AdminReports] Error fetching photo reports: $e');
      }
    }

    // Sort reports
    reports.sort((a, b) {
      if (_sortOrder == 'newest') {
        return (b['date'] as DateTime).compareTo(a['date'] as DateTime);
      } else {
        return (a['date'] as DateTime).compareTo(b['date'] as DateTime);
      }
    });

    return reports;
  }

  bool _matchesFilters({
    required String type,
    required String status,
    required String title,
  }) {
    // Search filter
    final search = _searchController.text.toLowerCase();
    if (search.isNotEmpty &&
        !title.toLowerCase().contains(search) &&
        !status.toLowerCase().contains(search)) {
      return false;
    }

    // Status filter
    if (_selectedStatusFilter != 'all') {
      // Map report statuses to unified statuses
      String unified = status;
      if (status == 'pending') unified = 'open';
      if (status == 'reviewing') unified = 'reviewed';
      if (status == 'dismissed') unified = 'rejected';

      if (unified != _selectedStatusFilter) {
        return false;
      }
    }

    return true;
  }

  void _handleNavigation(BuildContext context, int index) {
    // index: 0=Dashboard, 1=Users, 2=Businesses, 3=Reports, 4=Feedback, 5=Broadcast, 6=Settings
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
      case 3: // Reports - already here
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
      case 6: // Settings
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/admin/settings',
          (route) => false,
        );
        break;
    }
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AdminNeonTheme.neonOrange.withValues(alpha: 0.2)
              : AdminNeonTheme.glassSurfaceAlt,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? AdminNeonTheme.neonOrange
                : AdminNeonTheme.glassBorder,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? AdminNeonTheme.neonOrange
                : AdminNeonTheme.textSecondary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _ReportRow extends StatefulWidget {
  final Map<String, dynamic> report;

  const _ReportRow({required this.report});

  @override
  State<_ReportRow> createState() => _ReportRowState();
}

class _ReportRowState extends State<_ReportRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final date = widget.report['date'] as DateTime;
    final formattedDate = DateFormat('MMM d, y • h:mm a').format(date);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: AdminNeonTheme.glassCard(
          accent: AdminNeonTheme.neonBlue,
          radius: 12,
          borderOpacity: _hovered ? 0.6 : 0.35,
          borderWidth: _hovered ? 1.4 : 1.0,
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Type badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AdminNeonTheme.neonBlue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: AdminNeonTheme.neonBlue.withValues(alpha: 0.4),
                    width: 1,
                  ),
                ),
                child: Text(
                  widget.report['reportType'] as String,
                  style: const TextStyle(
                    color: AdminNeonTheme.neonBlue,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.report['title'].toString().length > 60
                          ? '${widget.report['title'].toString().substring(0, 57)}...'
                          : widget.report['title'].toString(),
                      style: const TextStyle(
                        color: AdminNeonTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Reason: ${widget.report['reason'] ?? 'unknown'}',
                            style: const TextStyle(
                              color: AdminNeonTheme.textSecondary,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Reporter: ${widget.report['reporter']}',
                          style: const TextStyle(
                            color: AdminNeonTheme.textSecondary,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        // Status badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color:
                                _getStatusColor(widget.report['status'] as String)
                                    .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            (widget.report['status'] as String).toUpperCase(),
                            style: TextStyle(
                              color: _getStatusColor(
                                  widget.report['status'] as String),
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Date
                        Text(
                          formattedDate,
                          style: const TextStyle(
                            color: AdminNeonTheme.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Action button
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminNeonTheme.neonBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                onPressed: () {
                  // Action would open detailed view
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'View report: ${widget.report['id']}',
                      ),
                    ),
                  );
                },
                child: const Text('Review'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
      case 'open':
        return AdminNeonTheme.neonOrange;
      case 'reviewing':
      case 'reviewed':
        return AdminNeonTheme.neonBlue;
      case 'resolved':
        return const Color(0xFF10B981); // Green
      case 'dismissed':
      case 'rejected':
        return AdminNeonTheme.neonRed;
      default:
        return AdminNeonTheme.textSecondary;
    }
  }
}
