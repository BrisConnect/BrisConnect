import 'package:flutter/material.dart';
import 'package:brisconnect/auth/admin_auth.dart';
import 'package:brisconnect/auth/app_user_role.dart';
import 'package:brisconnect/models/business.dart';
import 'package:brisconnect/services/business_profile_service.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/widgets/logo_app_bar_title.dart';
import 'package:brisconnect/widgets/role_guard.dart';

/// Admin screen for managing local business listings.
///
/// Supports verifying, deactivating, reactivating, editing, archiving,
/// restoring and viewing duplicate-flagged businesses.
class AdminBusinessManagementScreen extends StatefulWidget {
  final BusinessProfileService businessService;
  final bool enforceRoleGuard;

  AdminBusinessManagementScreen({
    super.key,
    BusinessProfileService? businessService,
    this.enforceRoleGuard = true,
  }) : businessService = businessService ?? BusinessProfileService();

  @override
  State<AdminBusinessManagementScreen> createState() =>
      _AdminBusinessManagementScreenState();
}

class _AdminBusinessManagementScreenState
    extends State<AdminBusinessManagementScreen> {
  String _filter = 'all'; // all, pending, verified, inactive, archived, duplicates

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
    final reason = await _showReasonDialog('Deactivate ${business.businessName}');
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
    final screen = Scaffold(
      backgroundColor: AppPalette.background,
      appBar: AppBar(
        title: const LogoAppBarTitle('Manage Businesses'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              children: [
                _FilterChip(label: 'All', value: 'all', selected: _filter, onSelected: _setFilter),
                _FilterChip(label: 'Pending', value: 'pending', selected: _filter, onSelected: _setFilter),
                _FilterChip(label: 'Verified', value: 'verified', selected: _filter, onSelected: _setFilter),
                _FilterChip(label: 'Inactive', value: 'inactive', selected: _filter, onSelected: _setFilter),
                _FilterChip(label: 'Archived', value: 'archived', selected: _filter, onSelected: _setFilter),
                _FilterChip(label: 'Duplicates', value: 'duplicates', selected: _filter, onSelected: _setFilter),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Business>>(
              stream: _businessStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('Error loading businesses: ${snapshot.error}'),
                    ),
                  );
                }

                final businesses = (snapshot.data ?? []).where(_matchesFilter).toList();

                if (businesses.isEmpty) {
                  return Center(
                    child: Text(
                      'No $_filter businesses',
                      style: const TextStyle(color: AppPalette.charcoal),
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
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/business/create', arguments: ''),
        icon: const Icon(Icons.add_business),
        label: const Text('Add business'),
      ),
    );

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
    return FilterChip(
      label: Text(label),
      selected: selected == value,
      onSelected: (_) => onSelected(value),
    );
  }
}

class _BusinessCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Card(
      color: AppPalette.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppPalette.border),
      ),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                      fontSize: 16,
                    ),
                  ),
                ),
                Chip(
                  label: Text(
                    business.statusLabel.toUpperCase(),
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  backgroundColor: _statusColor.withValues(alpha: 0.2),
                  side: BorderSide(color: _statusColor),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Category: ${business.category}'),
            Text('Address: ${business.address}'),
            if (business.duplicateOf != null)
              Text(
                'Possible duplicate of ${business.duplicateOf}',
                style: const TextStyle(color: Colors.orangeAccent),
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              alignment: WrapAlignment.end,
              children: [
                if (!business.isDeleted) ...[
                  if (!business.isVerified)
                    ElevatedButton(
                      onPressed: () => onVerify(business),
                      child: const Text('Verify'),
                    )
                  else
                    TextButton(
                      onPressed: () => onUnverify(business),
                      child: const Text('Unverify'),
                    ),
                  if (business.isActive)
                    TextButton(
                      onPressed: () => onDeactivate(business),
                      child: const Text('Deactivate'),
                    )
                  else
                    ElevatedButton(
                      onPressed: () => onReactivate(business),
                      child: const Text('Reactivate'),
                    ),
                  TextButton(
                    onPressed: () => onEdit(business),
                    child: const Text('Edit'),
                  ),
                  ElevatedButton(
                    onPressed: () => onArchive(business),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Archive'),
                  ),
                ],
                if (business.isDeleted)
                  ElevatedButton(
                    onPressed: () => onRestore(business),
                    child: const Text('Restore'),
                  ),
              ],
            ),
          ],
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
