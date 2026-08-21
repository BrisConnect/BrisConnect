import 'package:flutter/material.dart';
import 'package:brisconnect/auth/app_user_role.dart';
import 'package:brisconnect/models/promotion_plan.dart';
import 'package:brisconnect/services/admin_promotion_service.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/utils/admin_utils.dart';
import 'package:brisconnect/widgets/role_guard.dart';
import 'package:brisconnect/features/admin/dashboard/widgets/admin_sidebar.dart';

/// Admin screen for managing promotion plans and active business promotions.
class AdminPromotionManagementScreen extends StatefulWidget {
  final AdminPromotionService service;
  final bool enforceRoleGuard;

  AdminPromotionManagementScreen({
    super.key,
    AdminPromotionService? service,
    this.enforceRoleGuard = true,
  }) : service = service ?? AdminPromotionService();

  @override
  State<AdminPromotionManagementScreen> createState() =>
      _AdminPromotionManagementScreenState();
}

class _AdminPromotionManagementScreenState
    extends State<AdminPromotionManagementScreen>
    with AdminScreenMixin, SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _savePlan(PromotionPlan plan) async {
    await runAdminAction(
      () => widget.service.savePromotionPlan(plan),
      success: '${plan.name} saved.',
    );
  }

  Future<void> _togglePlanActive(PromotionPlan plan) async {
    final newState = !plan.isActive;
    await runAdminAction(
      () => widget.service.setPlanActive(plan.id!, newState),
      success: '${plan.name} ${newState ? 'activated' : 'deactivated'}.',
    );
  }

  Future<void> _deactivatePromotion(ActivePromotion promo) async {
    final confirmed = await AdminUtils.showConfirmDialog(
      context,
      title: 'Deactivate promotion',
      content:
          'Deactivate "${promo.promotionTitle}" for ${promo.ownerId}? This will remove featured visibility immediately.',
      confirmText: 'Deactivate',
      confirmColor: Colors.red,
    );
    if (confirmed != true || !mounted) return;
    await runAdminAction(
      () => widget.service.deactivatePromotion(promo.id),
      success: 'Promotion deactivated.',
    );
  }

  void _showPlanEditor({PromotionPlan? plan}) {
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
          'Manage Promotions',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: Color(0xFF1E3A8A),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF1E3A8A),
          unselectedLabelColor: AppPalette.mutedText,
          indicatorColor: AppPalette.ochre,
          tabs: const [
            Tab(text: 'Plans', icon: Icon(Icons.local_offer_outlined)),
            Tab(text: 'Active', icon: Icon(Icons.celebration_outlined)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showPlanEditor(),
        backgroundColor: AppPalette.ochre,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Plan'),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPlansTab(),
          _buildActiveTab(),
        ],
      ),
    );

    final guarded = widget.enforceRoleGuard
        ? RoleGuard(
            allowedRoles: const {AppUserRole.admin},
            child: screen,
          )
        : screen;
    
    if (!isDesktop) return guarded;
    
    return Row(
      children: [
        AdminSidebar(
          selectedIndex: 6, // Settings (promotions are in settings area)
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

  Widget _buildPlansTab() {
    return StreamBuilder<List<PromotionPlan>>(
      stream: widget.service.getPromotionPlans(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Error loading plans: ${snapshot.error}'),
            ),
          );
        }
        final plans = snapshot.data ?? [];
        if (plans.isEmpty) {
          return const Center(
            child: Text(
              'No promotion plans yet.',
              style: TextStyle(color: AppPalette.charcoal),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: plans.length,
          itemBuilder: (context, index) {
            final plan = plans[index];
            return _PlanCard(
              plan: plan,
              onEdit: () => _showPlanEditor(plan: plan),
              onToggleActive: () => _togglePlanActive(plan),
            );
          },
        );
      },
    );
  }

  Widget _buildActiveTab() {
    return StreamBuilder<List<ActivePromotion>>(
      stream: widget.service.getActivePromotions(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Error loading promotions: ${snapshot.error}'),
            ),
          );
        }
        final promotions = snapshot.data ?? [];
        if (promotions.isEmpty) {
          return const Center(
            child: Text(
              'No active promotions.',
              style: TextStyle(color: AppPalette.charcoal),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: promotions.length,
          itemBuilder: (context, index) {
            final promo = promotions[index];
            return _ActivePromotionCard(
              promo: promo,
              onDeactivate: () => _deactivatePromotion(promo),
            );
          },
        );
      },
    );
  }
}

class _PlanCard extends StatelessWidget {
  final PromotionPlan plan;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;

  const _PlanCard({
    required this.plan,
    required this.onEdit,
    required this.onToggleActive,
  });

  @override
  Widget build(BuildContext context) {
    final price = '\$${(plan.priceCents / 100).toStringAsFixed(2)}';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: plan.isActive ? AppPalette.border : Colors.transparent,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _typeColor(plan.type).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    plan.typeLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: _typeColor(plan.type),
                    ),
                  ),
                ),
                const Spacer(),
                if (!plan.isActive)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Inactive',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppPalette.mutedText,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Edit plan',
                ),
                IconButton(
                  onPressed: onToggleActive,
                  icon: Icon(plan.isActive
                      ? Icons.toggle_on
                      : Icons.toggle_off_outlined),
                  tooltip: plan.isActive ? 'Deactivate' : 'Activate',
                  color:
                      plan.isActive ? AppPalette.ochre : AppPalette.mutedText,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              plan.name,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppPalette.charcoal,
              ),
            ),
            if (plan.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                plan.description,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppPalette.mutedText,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                _Metric(label: 'Price', value: price),
                const SizedBox(width: 24),
                _Metric(
                  label: 'Duration',
                  value: '${plan.durationDays} days',
                ),
              ],
            ),
            if (plan.features.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: plan.features
                    .map((f) => Chip(
                          visualDensity: VisualDensity.compact,
                          label: Text(
                            f,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _typeColor(PromotionPlanType type) {
    switch (type) {
      case PromotionPlanType.premium:
        return AppPalette.deepBlue;
      case PromotionPlanType.featured:
        return AppPalette.ochre;
      case PromotionPlanType.promotionDay:
        return AppPalette.gold;
    }
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;

  const _Metric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppPalette.mutedText,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppPalette.charcoal,
          ),
        ),
      ],
    );
  }
}

class _ActivePromotionCard extends StatelessWidget {
  final ActivePromotion promo;
  final VoidCallback onDeactivate;

  const _ActivePromotionCard({
    required this.promo,
    required this.onDeactivate,
  });

  @override
  Widget build(BuildContext context) {
    final price = '\$${(promo.amountCents / 100).toStringAsFixed(2)}';
    final expiresText = promo.expiresAt != null
        ? '${promo.expiresAt!.day.toString().padLeft(2, '0')}/${promo.expiresAt!.month.toString().padLeft(2, '0')}/${promo.expiresAt!.year}'
        : '—';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppPalette.border),
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
                    promo.promotionTitle,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppPalette.charcoal,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: onDeactivate,
                  icon: const Icon(Icons.block, size: 18),
                  label: const Text('Deactivate'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _InfoRow(label: 'Business ID', value: promo.businessId),
            _InfoRow(label: 'Owner', value: promo.ownerId),
            if (promo.planName != null && promo.planName!.isNotEmpty)
              _InfoRow(label: 'Plan', value: promo.planName!),
            _InfoRow(label: 'Amount', value: price),
            _InfoRow(label: 'Expires', value: expiresText),
            if (promo.receiptUrl != null && promo.receiptUrl!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: InkWell(
                  onTap: () => AdminUtils.openUrl(promo.receiptUrl!),
                  child: Row(
                    children: [
                      Icon(Icons.receipt_long_rounded,
                          size: 16, color: AppPalette.ochre),
                      const SizedBox(width: 6),
                      Text(
                        'View Stripe receipt',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppPalette.ochre,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppPalette.mutedText,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppPalette.charcoal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanEditorSheet extends StatefulWidget {
  final PromotionPlan? plan;
  final ValueChanged<PromotionPlan> onSave;

  const _PlanEditorSheet({this.plan, required this.onSave});

  @override
  State<_PlanEditorSheet> createState() => _PlanEditorSheetState();
}

class _PlanEditorSheetState extends State<_PlanEditorSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _durationCtrl;
  late final TextEditingController _featuresCtrl;
  late PromotionPlanType _type;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    final plan = widget.plan;
    _nameCtrl = TextEditingController(text: plan?.name ?? '');
    _descCtrl = TextEditingController(text: plan?.description ?? '');
    _priceCtrl = TextEditingController(
      text: plan != null ? (plan.priceCents / 100).toStringAsFixed(2) : '',
    );
    _durationCtrl = TextEditingController(
      text: plan != null ? plan.durationDays.toString() : '',
    );
    _featuresCtrl = TextEditingController(
      text: plan?.features.join(', ') ?? '',
    );
    _type = plan?.type ?? PromotionPlanType.premium;
    _isActive = plan?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _durationCtrl.dispose();
    _featuresCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameCtrl.text.trim();
    final price = double.tryParse(_priceCtrl.text.trim()) ?? 0;
    final duration = int.tryParse(_durationCtrl.text.trim()) ?? 0;
    if (name.isEmpty || price <= 0 || duration <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields.')),
      );
      return;
    }
    final features = _featuresCtrl.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final now = DateTime.now();
    final plan = PromotionPlan(
      id: widget.plan?.id,
      type: _type,
      name: name,
      description: _descCtrl.text.trim(),
      priceCents: (price * 100).round(),
      durationDays: duration,
      features: features,
      isActive: _isActive,
      createdAt: widget.plan?.createdAt ?? now,
      updatedAt: now,
    );
    widget.onSave(plan);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.plan == null
                  ? 'New Promotion Plan'
                  : 'Edit Promotion Plan',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppPalette.charcoal,
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<PromotionPlanType>(
              key: ValueKey<PromotionPlanType>(_type),
              initialValue: _type,
              decoration: const InputDecoration(
                labelText: 'Plan type',
                border: OutlineInputBorder(),
              ),
              items: PromotionPlanType.values
                  .map((t) => DropdownMenuItem(
                        value: t,
                        child: Text(PromotionPlan.typeLabelFor(t)),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _type = v!),
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
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _priceCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Price (AUD) *',
                      prefixText: '\$ ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _durationCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Duration (days) *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _featuresCtrl,
              decoration: const InputDecoration(
                labelText: 'Features (comma separated)',
                hintText: 'Featured badge, Priority search, Homepage carousel',
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
    );
  }
}
