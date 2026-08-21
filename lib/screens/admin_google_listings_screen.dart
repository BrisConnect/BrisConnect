import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:brisconnect/models/google_listing_monitoring_result.dart';
import 'package:brisconnect/services/google_listing_monitoring_service.dart';
import 'package:brisconnect/screens/admin_google_listing_review_screen.dart';
import 'package:brisconnect/features/admin/dashboard/admin_neon_theme.dart';

/// Admin screen for viewing and managing Google listing monitoring records
class AdminGoogleListingsScreen extends StatefulWidget {
  const AdminGoogleListingsScreen({super.key});

  @override
  State<AdminGoogleListingsScreen> createState() =>
      _AdminGoogleListingsScreenState();
}

class _AdminGoogleListingsScreenState extends State<AdminGoogleListingsScreen> {
  late GoogleListingMonitoringService _service;
  GoogleListingSeverity? _selectedSeverity;
  MonitoringStatus? _selectedStatus;
  AdminReviewStatus? _selectedReviewStatus;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _service = GoogleListingMonitoringService();
  }

  Stream<List<GoogleListingMonitoringResult>> _getFilteredRecords() {
    // Apply filters
    if (_selectedSeverity != null) {
      return _service.watchMonitoringBySeverity(severity: _selectedSeverity!);
    }
    if (_selectedStatus != null) {
      return _service.watchMonitoringByStatus(status: _selectedStatus!);
    }
    if (_selectedReviewStatus == AdminReviewStatus.pending) {
      return _service.watchUnreviewedChanges();
    }
    
    // Default: show recent records
    return _service.watchRecentMonitoringRecords();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Scaffold(
      backgroundColor: AdminNeonTheme.bgDeepNavy,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AdminNeonTheme.bgDeepNavy,
        foregroundColor: AdminNeonTheme.textPrimary,
        title: Text('Google Listings Monitoring'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Filter bar
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey[800]!)),
            ),
            child: Column(
              children: [
                // Search field
                TextField(
                  onChanged: (value) {
                    setState(() => _searchQuery = value);
                  },
                  decoration: InputDecoration(
                    hintText: 'Search by business name...',
                    hintStyle: TextStyle(color: Colors.grey[500]),
                    prefixIcon: Icon(Icons.search, color: AdminNeonTheme.neonBlue),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AdminNeonTheme.neonBlue),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          BorderSide(color: AdminNeonTheme.neonBlue, width: 0.5),
                    ),
                  ),
                  style: TextStyle(color: AdminNeonTheme.textPrimary),
                ),
                SizedBox(height: 12),
                // Filter chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip(
                        label: 'All',
                        isSelected: _selectedSeverity == null &&
                            _selectedStatus == null &&
                            _selectedReviewStatus == null,
                        onTap: () {
                          setState(() {
                            _selectedSeverity = null;
                            _selectedStatus = null;
                            _selectedReviewStatus = null;
                          });
                        },
                      ),
                      SizedBox(width: 8),
                      _buildFilterChip(
                        label: '🔴 Critical',
                        isSelected: _selectedSeverity == GoogleListingSeverity.critical,
                        onTap: () {
                          setState(
                            () => _selectedSeverity =
                                _selectedSeverity == GoogleListingSeverity.critical
                                    ? null
                                    : GoogleListingSeverity.critical,
                          );
                        },
                      ),
                      SizedBox(width: 8),
                      _buildFilterChip(
                        label: '⚠️ Attention',
                        isSelected: _selectedSeverity == GoogleListingSeverity.attention,
                        onTap: () {
                          setState(
                            () => _selectedSeverity =
                                _selectedSeverity == GoogleListingSeverity.attention
                                    ? null
                                    : GoogleListingSeverity.attention,
                          );
                        },
                      ),
                      SizedBox(width: 8),
                      _buildFilterChip(
                        label: '⏳ Pending',
                        isSelected: _selectedReviewStatus == AdminReviewStatus.pending,
                        onTap: () {
                          setState(
                            () => _selectedReviewStatus =
                                _selectedReviewStatus == AdminReviewStatus.pending
                                    ? null
                                    : AdminReviewStatus.pending,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Records list
          Expanded(
            child: StreamBuilder<List<GoogleListingMonitoringResult>>(
              stream: _getFilteredRecords(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation(AdminNeonTheme.neonBlue),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading records: ${snapshot.error}',
                      style: TextStyle(color: Colors.red),
                    ),
                  );
                }

                final records = snapshot.data ?? [];
                
                // Filter by search query
                final filtered = _searchQuery.isEmpty
                    ? records
                    : records
                        .where((r) =>
                            r.businessName
                                .toLowerCase()
                                .contains(_searchQuery.toLowerCase()) ||
                            r.businessId
                                .toLowerCase()
                                .contains(_searchQuery.toLowerCase()))
                        .toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle,
                            size: 48, color: Colors.green[300]),
                        SizedBox(height: 16),
                        Text(
                          'No monitoring records found',
                          style: TextStyle(
                              color: AdminNeonTheme.textPrimary, fontSize: 16),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) =>
                      _buildMonitoringCard(filtered[index], context, isMobile),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AdminNeonTheme.neonBlue.withValues(alpha: 0.3)
              : Colors.grey[800],
          border: Border.all(
            color: isSelected ? AdminNeonTheme.neonBlue : Colors.grey[700]!,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? AdminNeonTheme.neonBlue : Colors.grey[400],
          ),
        ),
      ),
    );
  }

  Widget _buildMonitoringCard(
    GoogleListingMonitoringResult result,
    BuildContext context,
    bool isMobile,
  ) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[800]!),
        borderRadius: BorderRadius.circular(8),
        color: Colors.black.withValues(alpha: 0.3),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.all(12),
        leading: _buildSeverityIcon(result.severity),
        title: Text(
          result.businessName,
          style: TextStyle(
            color: AdminNeonTheme.textPrimary,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4),
            Text(
              'Status: ${result.status.label} • Review: ${result.adminReviewStatus.label}',
              style: TextStyle(fontSize: 12, color: Colors.grey[400]),
            ),
            SizedBox(height: 2),
            Text(
              DateFormat('MMM d, y · h:mm a').format(result.checkTimestamp),
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
          ],
        ),
        trailing: isMobile
            ? Icon(Icons.arrow_forward, color: AdminNeonTheme.neonBlue, size: 20)
            : Wrap(
                spacing: 8,
                children: [
                  if (result.hasChanges)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.2),
                        border: Border.all(color: Colors.orange),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${result.changes.length} Changes',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.orange,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  Icon(Icons.arrow_forward,
                      color: AdminNeonTheme.neonBlue, size: 20),
                ],
              ),
        onTap: () => _openReviewScreen(context, result),
      ),
    );
  }

  Widget _buildSeverityIcon(GoogleListingSeverity severity) {
    final colors = {
      GoogleListingSeverity.info: (Colors.blue, Icons.info),
      GoogleListingSeverity.attention: (Colors.orange, Icons.warning),
      GoogleListingSeverity.critical: (Colors.red, Icons.error),
    };

    final (color, icon) = colors[severity] ?? (Colors.grey, Icons.help);

    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  Future<void> _openReviewScreen(
    BuildContext context,
    GoogleListingMonitoringResult result,
  ) async {
    final reviewed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => AdminGoogleListingReviewScreen(
          monitoringResult: result,
          onReviewComplete: () {
            setState(() {}); // Refresh list
          },
        ),
      ),
    );

    if (reviewed != null) {
      setState(() {}); // Refresh list
    }
  }
}
