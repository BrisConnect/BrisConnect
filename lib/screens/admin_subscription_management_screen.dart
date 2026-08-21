import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:brisconnect/auth/app_user_role.dart';
import 'package:brisconnect/models/subscription_plan.dart';
import 'package:brisconnect/services/admin_subscription_service.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/utils/admin_utils.dart';
import 'package:brisconnect/widgets/role_guard.dart';
import 'package:brisconnect/features/admin/dashboard/widgets/admin_sidebar.dart';

/// Admin screen for managing subscription plans.
class AdminSubscriptionManagementScreen extends StatefulWidget {
  final AdminSubscriptionService service;
  final bool enforceRoleGuard;

  AdminSubscriptionManagementScreen({
    super.key,
    AdminSubscriptionService? service,
    this.enforceRoleGuard = true,
  }) : service = service ?? AdminSubscriptionService();

  @override
  State<AdminSubscriptionManagementScreen> createState() =>
      _AdminSubscriptionManagementScreenState();
}

class _AdminSubscriptionManagementScreenState
    extends State<AdminSubscriptionManagementScreen> with AdminScreenMixin {
  Future<void> _savePlan(SubscriptionPlan plan) async {
    await runAdminAction(
      () => widget.service.saveSubscriptionPlan(plan),
      success: '${plan.name} saved.',
    );
  }

  Future<void> _togglePlanActive(SubscriptionPlan plan) async {
    final newState = !plan.isActive;
    await runAdminAction(
      () => widget.service.setPlanActive(plan.id!, newState),
      success: '${plan.name} ${newState ? 'activated' : 'deactivated'}.',
    );
  }

  void _showPlanEditor({SubscriptionPlan? plan}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PlanEditorSheet(
        plan: plan,
        onSave: _savePlan,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width > 1024;
    final screen = Scaffold(
      backgroundColor: const Color(0xFFEBF4FF),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFFEBF4FF),
        foregroundColor: const Color(0xFF1E3A8A),
        elevation: 0,
        title: const Text(
          'Manage Subscriptions',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: Color(0xFF1E3A8A),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showPlanEditor(),
        backgroundColor: AppPalette.ochre,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Plan'),
      ),
      body: StreamBuilder<List<SubscriptionPlan>>(
        stream: widget.service.getSubscriptionPlans(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppPalette.ochre),
            );
          }

          final plans = snapshot.data ?? [];
          if (plans.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.subscriptions_outlined,
                      size: 48, color: AppPalette.mutedText),
                  const SizedBox(height: 12),
                  Text(
                    'No subscription plans yet.',
                    style: TextStyle(color: AppPalette.mutedText),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: plans.length,
            itemBuilder: (context, index) {
              return _PlanCard(
                plan: plans[index],
                onEdit: () => _showPlanEditor(plan: plans[index]),
                onToggleActive: () => _togglePlanActive(plans[index]),
              );
            },
          );
        },
      ),
    );

    final guarded = widget.enforceRoleGuard
        ? RoleGuard(
            allowedRoles: const {AppUserRole.admin},
            deniedMessage: 'Admin access required.',
            child: screen,
          )
        : screen;
    
    if (!isDesktop) return guarded;
    
    return Row(
      children: [
        AdminSidebar(
          selectedIndex: 6, // Settings
          onDestinationSelected: (index) {
            _handleNavigation(context, index);
          },
        ),
        Expanded(child: guarded),
      ],
    );
  }

  void _handleNavigation(BuildContext context, int index) {
    // index: 0=Home, 1=Users, 2=Businesses, 3=Reports, 4=Feedback, 5=Broadcast, 6=Settings
    switch (index) {
      case 0: // Home
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
      case 6: // Settings - already here
        break;
    }
  }
}

class _PlanCard extends StatelessWidget {
  final SubscriptionPlan plan;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;

  const _PlanCard({
    required this.plan,
    required this.onEdit,
    required this.onToggleActive,
  });

  String _formattedPrice(int cents) {
    return '\$${(cents / 100).toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: plan.isActive
              ? AppPalette.ochre.withValues(alpha: 0.4)
              : AppPalette.border,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    plan.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppPalette.charcoal,
                    ),
                  ),
                ),
                Switch(
                  value: plan.isActive,
                  onChanged: (_) => onToggleActive(),
                  activeThumbColor: AppPalette.ochre,
                ),
              ],
            ),
            if (plan.description.isNotEmpty)
              Text(
                plan.description,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppPalette.mutedText,
                ),
              ),
            const SizedBox(height: 8),
            Text(
              '${_formattedPrice(plan.priceCents)} / ${plan.intervalLabel}',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppPalette.charcoal,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: plan.features
                  .map((f) => Chip(
                        label: Text(
                          f,
                          style: const TextStyle(fontSize: 12),
                        ),
                        backgroundColor: const Color(0xFFF3F4F6),
                        side: BorderSide.none,
                        padding: EdgeInsets.zero,
                      ))
                  .toList(),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit, size: 18),
                label: const Text('Edit'),
                style: TextButton.styleFrom(
                  foregroundColor: AppPalette.ochre,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanEditorSheet extends StatefulWidget {
  final SubscriptionPlan? plan;
  final ValueChanged<SubscriptionPlan> onSave;

  const _PlanEditorSheet({
    required this.plan,
    required this.onSave,
  });

  @override
  State<_PlanEditorSheet> createState() => _PlanEditorSheetState();
}

class _PlanEditorSheetState extends State<_PlanEditorSheet> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _featuresCtrl = TextEditingController();
  late SubscriptionInterval _interval;
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    final plan = widget.plan;
    _nameCtrl.text = plan?.name ?? '';
    _descCtrl.text = plan?.description ?? '';
    _priceCtrl.text =
        plan != null ? (plan.priceCents / 100).toStringAsFixed(2) : '';
    _featuresCtrl.text = (plan?.features ?? []).join(', ');
    _interval = plan?.interval ?? SubscriptionInterval.monthly;
    _isActive = plan?.isActive ?? true;
  }

  void _submit() {
    final name = _nameCtrl.text.trim();
    final priceText = _priceCtrl.text.trim();
    final price = double.tryParse(priceText) ?? 0;
    final priceCents = (price * 100).round();

    if (name.isEmpty || priceCents <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name and a valid price are required.')),
      );
      return;
    }

    final features = _featuresCtrl.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final now = DateTime.now();
    final plan = SubscriptionPlan(
      id: widget.plan?.id,
      name: name,
      description: _descCtrl.text.trim(),
      priceCents: priceCents,
      interval: _interval,
      features: features,
      isActive: _isActive,
      createdAt: widget.plan?.createdAt ?? now,
      updatedAt: now,
    );

    widget.onSave(plan);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.plan == null
                    ? 'New Subscription Plan'
                    : 'Edit Subscription Plan',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppPalette.charcoal,
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<SubscriptionInterval>(
                key: ValueKey<SubscriptionInterval>(_interval),
                initialValue: _interval,
                decoration: const InputDecoration(
                  labelText: 'Billing interval',
                  border: OutlineInputBorder(),
                ),
                items: SubscriptionInterval.values
                    .map((i) => DropdownMenuItem(
                          value: i,
                          child: Text(
                              i.name[0].toUpperCase() + i.name.substring(1)),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _interval = v!),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Plan name *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _priceCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Price (AUD) *',
                  prefixText: '\$ ',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _featuresCtrl,
                decoration: const InputDecoration(
                  labelText: 'Features (comma separated)',
                  hintText: 'AI post generation, Premium badge, Map priority',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
                title: const Text('Active'),
                activeThumbColor: AppPalette.ochre,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppPalette.ochre,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Save Plan'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
