import 'package:flutter/material.dart';
import 'package:brisconnect/auth/admin_auth.dart';
import 'package:brisconnect/auth/app_user_role.dart';
import 'package:brisconnect/features/admin/dashboard/admin_neon_theme.dart';
import 'package:brisconnect/models/business.dart';
import 'package:brisconnect/services/business_profile_service.dart';
import 'package:brisconnect/widgets/role_guard.dart';

/// Admin screen for managing local business listings.
///
/// Supports verifying, deactivating, reactivating, editing, archiving,
/// restoring and viewing duplicate-flagged businesses.
class AdminBusinessManagementScreen extends StatefulWidget {
  final BusinessProfileService businessService;
  final bool enforceRoleGuard;
  final bool buildFullScaffold;

  AdminBusinessManagementScreen({
    super.key,
    BusinessProfileService? businessService,
    this.enforceRoleGuard = true,
    this.buildFullScaffold = true,
  }) : businessService = businessService ?? BusinessProfileService();

  @override
  State<AdminBusinessManagementScreen> createState() =>
      _AdminBusinessManagementScreenState();
}

class _AdminBusinessManagementScreenState
    extends State<AdminBusinessManagementScreen> {
  String _filter =
      'all'; // all, pending, verified, inactive, archived, duplicates

  Stream<List<Business>> _businessStream() {
    switch (_filter) {
      case 'archived':
        return widget.businessService.getArchivedBusinessesStream();
      case 'duplicates':
        return widget.businessService.getFlaggedDuplicatesStream();
      default:
        return widget.businessService.getAllBusinessesAdminStream();
    }
  }

  bool _matchesFilter(Business b) {
    // Exclude Google Places seeded businesses
    if (b.isGoogleListing) {
      return false;
    }
    
    switch (_filter) {
      case 'pending':
        return !b.isVerified && b.isActive && !b.isDeleted;
      case 'verified':
        return b.isVerified && b.isActive && !b.isDeleted;
      case 'inactive':
        return !b.isActive && !b.isDeleted;
      case 'archived':
      case 'duplicates':
        return true;
      default:
        return true;
    }
  }

  Future<void> _verify(Business business) async {
    final adminEmail = AdminAuth.currentAdminEmail;
    if (adminEmail == null || adminEmail.isEmpty) {
      _showSnack('Admin email not available.', isError: true);
      return;
    }
    await _runAction(() => widget.businessService.verifyBusiness(
          businessId: business.id!,
          adminEmail: adminEmail,
        ));
  }

  Future<void> _unverify(Business business) async {
    final adminEmail = AdminAuth.currentAdminEmail;
    if (adminEmail == null || adminEmail.isEmpty) return;
    await _runAction(() => widget.businessService.unverifyBusiness(
          businessId: business.id!,
          adminEmail: adminEmail,
        ));
  }

  Future<void> _deactivate(Business business) async {
    final adminEmail = AdminAuth.currentAdminEmail;
    if (adminEmail == null || adminEmail.isEmpty) return;
    final reason =
        await _showReasonDialog('Deactivate ${business.businessName}');
    if (reason == null) return;
    await _runAction(() => widget.businessService.deactivateBusiness(
          businessId: business.id!,
          adminEmail: adminEmail,
          reason: reason,
        ));
  }

  Future<void> _reactivate(Business business) async {
    final adminEmail = AdminAuth.currentAdminEmail;
    if (adminEmail == null || adminEmail.isEmpty) return;
    await _runAction(() => widget.businessService.reactivateBusiness(
          businessId: business.id!,
          adminEmail: adminEmail,
        ));
  }

  Future<void> _archive(Business business) async {
    final adminEmail = AdminAuth.currentAdminEmail;
    if (adminEmail == null || adminEmail.isEmpty) return;
    final reason = await _showReasonDialog('Archive ${business.businessName}');
    if (reason == null) return;
    await _runAction(() => widget.businessService.archiveBusiness(
          businessId: business.id!,
          adminEmail: adminEmail,
          reason: reason,
        ));
  }

  Future<void> _restore(Business business) async {
    final adminEmail = AdminAuth.currentAdminEmail;
    if (adminEmail == null || adminEmail.isEmpty) return;
    await _runAction(() => widget.businessService.restoreBusiness(
          businessId: business.id!,
          adminEmail: adminEmail,
        ));
  }

  Future<void> _runAction(Future<void> Function() action) async {
    try {
      await action();
      if (mounted) _showSnack('Action completed.');
    } catch (e) {
      if (mounted) _showSnack('Action failed: $e', isError: true);
    }
  }

  Future<String?> _showReasonDialog(String title) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Reason (required)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : null,
      ),
    );
  }

  void _openEdit(Business business) {
    Navigator.pushNamed(context, '/business/edit', arguments: business);
  }

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 8,
            children: [
              _FilterChip(
                  label: 'All',
                  value: 'all',
                  selected: _filter,
                  onSelected: _setFilter),
              _FilterChip(
                  label: 'Pending',
                  value: 'pending',
                  selected: _filter,
                  onSelected: _setFilter),
              _FilterChip(
                  label: 'Verified',
                  value: 'verified',
                  selected: _filter,
                  onSelected: _setFilter),
              _FilterChip(
                  label: 'Inactive',
                  value: 'inactive',
                  selected: _filter,
                  onSelected: _setFilter),
              _FilterChip(
                  label: 'Archived',
                  value: 'archived',
                  selected: _filter,
                  onSelected: _setFilter),
              _FilterChip(
                  label: 'Duplicates',
                  value: 'duplicates',
                  selected: _filter,
                  onSelected: _setFilter),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<Business>>(
            stream: _businessStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: AdminNeonTheme.neonOrange),
                );
              }
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Error loading businesses: ${snapshot.error}',
                      style: const TextStyle(color: AdminNeonTheme.textPrimary),
                    ),
                  ),
                );
              }

              final businesses =
                  (snapshot.data ?? []).where(_matchesFilter).toList();

              if (businesses.isEmpty) {
                return Center(
                  child: Text(
                    'No $_filter businesses',
                    style: const TextStyle(color: AdminNeonTheme.textSecondary),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: businesses.length,
                itemBuilder: (context, index) {
                  final business = businesses[index];
                  return _BusinessCard(
                    business: business,
                    onVerify: _verify,
                    onUnverify: _unverify,
                    onDeactivate: _deactivate,
                    onReactivate: _reactivate,
                    onArchive: _archive,
                    onRestore: _restore,
                    onEdit: _openEdit,
                  );
                },
              );
            },
          ),
        ),
      ],
    );

    Widget screen;
    if (widget.buildFullScaffold) {
      screen = Scaffold(
        backgroundColor: AdminNeonTheme.bgDeepNavy,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: AdminNeonTheme.headerBg,
          foregroundColor: AdminNeonTheme.textPrimary,
          elevation: 0,
          title: const Text(
            'Manage Businesses',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: AdminNeonTheme.textPrimary,
            ),
          ),
        ),
        body: Stack(
          children: [
            // Orange neon food background
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [
                      AdminNeonTheme.bgDeepNavy,
                      AdminNeonTheme.bgDeepNavy.withValues(alpha: 0.95),
                      AdminNeonTheme.bgMidnight,
                    ],
                  ),
                ),
                child: Opacity(
                  opacity: 0.1,
                  child: Stack(
                    children: [
                      // Food plate icon pattern
                      Positioned(
                        right: -80,
                        top: -60,
                        child: Icon(
                          Icons.restaurant,
                          size: 300,
                          color: AdminNeonTheme.neonOrange,
                        ),
                      ),
                      // Utensils pattern
                      Positioned(
                        left: -40,
                        bottom: -40,
                        child: Icon(
                          Icons.restaurant_menu,
                          size: 250,
                          color: AdminNeonTheme.neonOrange,
                        ),
                      ),
                      // Food icon pattern
                      Positioned(
                        right: 50,
                        bottom: 100,
                        child: Icon(
                          Icons.lunch_dining,
                          size: 200,
                          color: AdminNeonTheme.neonOrange,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Content layer
            Positioned.fill(
              child: content,
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () =>
              Navigator.pushNamed(context, '/business/create', arguments: ''),
          backgroundColor: AdminNeonTheme.neonOrange,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_business),
          label: const Text('Add business'),
        ),
      );
    } else {
      screen = content;
    }

    if (widget.enforceRoleGuard) {
      return RoleGuard(
        allowedRoles: const {AppUserRole.admin},
        child: screen,
      );
    }
    return screen;
  }

  void _setFilter(String value) => setState(() => _filter = value);
}

class _FilterChip extends StatelessWidget {
  final String label;
  final String value;
  final String selected;
  final ValueChanged<String> onSelected;

  const _FilterChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = selected == value;
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: isSelected ? Colors.white : AdminNeonTheme.textPrimary,
        ),
      ),
      selected: isSelected,
      onSelected: (_) => onSelected(value),
      selectedColor: AdminNeonTheme.neonOrange,
      backgroundColor: AdminNeonTheme.glassSurface,
      checkmarkColor: Colors.white,
      side: BorderSide(
        color: isSelected
            ? AdminNeonTheme.neonOrange
            : AdminNeonTheme.glassBorder,
      ),
    );
  }
}

class _BusinessCard extends StatefulWidget {
  final Business business;
  final ValueChanged<Business> onVerify;
  final ValueChanged<Business> onUnverify;
  final ValueChanged<Business> onDeactivate;
  final ValueChanged<Business> onReactivate;
  final ValueChanged<Business> onArchive;
  final ValueChanged<Business> onRestore;
  final ValueChanged<Business> onEdit;

  const _BusinessCard({
    required this.business,
    required this.onVerify,
    required this.onUnverify,
    required this.onDeactivate,
    required this.onReactivate,
    required this.onArchive,
    required this.onRestore,
    required this.onEdit,
  });

  @override
  State<_BusinessCard> createState() => _BusinessCardState();
}

class _BusinessCardState extends State<_BusinessCard> {
  bool _hovered = false;

  Business get business => widget.business;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: AdminNeonTheme.glassCard(
            accent: AdminNeonTheme.neonBlue,
            radius: 12,
            borderOpacity: _hovered ? 0.7 : 0.35,
            borderWidth: _hovered ? 1.6 : 1.1,
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        business.businessName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: AdminNeonTheme.textPrimary,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _statusColor.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: _statusColor.withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        business.statusLabel.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text('Category: ${business.category}',
                    style: const TextStyle(color: AdminNeonTheme.textSecondary)),
                Text('Address: ${business.address}',
                    style: const TextStyle(color: AdminNeonTheme.textSecondary)),
                if (business.duplicateOf != null)
                  Text(
                    'Possible duplicate of ${business.duplicateOf}',
                    style: const TextStyle(color: AdminNeonTheme.neonOrange),
                  ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  alignment: WrapAlignment.end,
                  children: [
                    if (!business.isDeleted) ...[
                      if (!business.isVerified)
                        ElevatedButton(
                          onPressed: () => widget.onVerify(business),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF22C55E),
                            foregroundColor: Colors.white,
                            elevation: 0,
                          ),
                          child: const Text('Verify'),
                        )
                      else
                        OutlinedButton(
                          onPressed: () => widget.onUnverify(business),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AdminNeonTheme.neonOrange,
                            side: const BorderSide(color: AdminNeonTheme.neonOrange),
                          ),
                          child: const Text('Unverify'),
                        ),
                      if (business.isActive)
                        OutlinedButton(
                          onPressed: () => widget.onDeactivate(business),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AdminNeonTheme.neonRed,
                            side: const BorderSide(color: AdminNeonTheme.neonRed),
                          ),
                          child: const Text('Deactivate'),
                        )
                      else
                        ElevatedButton(
                          onPressed: () => widget.onReactivate(business),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF22C55E),
                            foregroundColor: Colors.white,
                            elevation: 0,
                          ),
                          child: const Text('Reactivate'),
                        ),
                      OutlinedButton(
                        onPressed: () => widget.onEdit(business),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AdminNeonTheme.neonBlue,
                          side: const BorderSide(color: AdminNeonTheme.neonBlue),
                        ),
                        child: const Text('Edit'),
                      ),
                      ElevatedButton(
                        onPressed: () => widget.onArchive(business),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AdminNeonTheme.neonRed,
                          foregroundColor: Colors.white,
                          elevation: 0,
                        ),
                        child: const Text('Archive'),
                      ),
                    ],
                    if (business.isDeleted)
                      ElevatedButton(
                        onPressed: () => widget.onRestore(business),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AdminNeonTheme.neonOrange,
                          foregroundColor: Colors.white,
                          elevation: 0,
                        ),
                        child: const Text('Restore'),
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

  Color get _statusColor {
    if (business.isDeleted) return Colors.red;
    if (!business.isActive) return Colors.grey;
    if (business.isVerified) return Colors.green;
    return Colors.orange;
  }
}
