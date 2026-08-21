import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:brisconnect/auth/local_auth.dart';
import 'package:brisconnect/models/business.dart';
import 'package:brisconnect/models/subscription_plan.dart';
import 'package:brisconnect/services/stripe_payment_service.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/utils/checkout_window_export.dart';

/// Screen where a local business owner views and purchases subscription plans.
class SubscriptionPlansScreen extends StatefulWidget {
  final String? initialBusinessId;

  const SubscriptionPlansScreen({super.key, this.initialBusinessId});

  @override
  State<SubscriptionPlansScreen> createState() =>
      _SubscriptionPlansScreenState();
}

class _SubscriptionPlansScreenState extends State<SubscriptionPlansScreen> {
  String? _selectedBusinessId;
  List<Business> _ownerBusinesses = [];
  bool _isLoadingBusinesses = true;
  bool _isCheckingOut = false;

  @override
  void initState() {
    super.initState();
    _selectedBusinessId = widget.initialBusinessId;
    _loadOwnerBusinesses();
  }

  Future<void> _loadOwnerBusinesses() async {
    final ownerId = LocalAuth.currentLocal?.email ?? '';
    if (ownerId.trim().isEmpty) {
      setState(() => _isLoadingBusinesses = false);
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('businesses')
          .where('ownerId', isEqualTo: ownerId)
          .where('isActive', isEqualTo: true)
          .where('deletedAt', isNull: true)
          .get();

      final businesses = snapshot.docs.map(Business.fromFirestore).toList();

      if (!mounted) return;
      setState(() {
        _ownerBusinesses = businesses;
        if (_selectedBusinessId == null && businesses.isNotEmpty) {
          _selectedBusinessId = businesses.first.id;
        }
        _isLoadingBusinesses = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingBusinesses = false);
      debugPrint('[SubscriptionPlansScreen] Failed to load businesses: $e');
    }
  }

  Future<void> _purchasePlan(SubscriptionPlan plan) async {
    final ownerId = LocalAuth.currentLocal?.email ?? '';
    if (ownerId.trim().isEmpty) {
      _showSnackBar('You must be signed in to purchase a plan.');
      return;
    }

    if (_selectedBusinessId == null || _selectedBusinessId!.trim().isEmpty) {
      _showSnackBar('Please select a business to make premium.');
      return;
    }

    // Open a blank checkout window synchronously on the web while we still have
    // the user-gesture context. We then navigate it once Stripe returns the URL.
    final checkoutWindow = kIsWeb ? openBlankCheckoutWindow() : null;
    if (kIsWeb && (checkoutWindow == null || !checkoutWindow.isOpen)) {
      _showSnackBar(
        'Could not open checkout. Please allow pop-ups for this site.',
      );
      return;
    }

    setState(() => _isCheckingOut = true);

    final opened = await StripePaymentService.startSubscriptionCheckout(
      ownerId: ownerId,
      businessId: _selectedBusinessId,
      planId: plan.id,
      checkoutWindow: checkoutWindow,
    );

    if (!mounted) return;
    setState(() => _isCheckingOut = false);

    if (!opened) {
      checkoutWindow?.close();
      _showSnackBar(
        StripePaymentService.lastErrorMessage ??
            'Could not open checkout. Please try again.',
      );
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppPalette.charcoal,
      ),
    );
  }

  String _formattedPrice(int cents) {
    final dollars = (cents / 100).toStringAsFixed(2);
    return '\$$dollars AUD';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEBF4FF),
      appBar: AppBar(
        title: const Text('Premium Subscription'),
        backgroundColor: AppPalette.ochre,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBusinessSelector(),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Choose a plan',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppPalette.charcoal,
                ),
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('subscription_plans')
                    .where('isActive', isEqualTo: true)
                    .orderBy('priceCents')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: AppPalette.ochre),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.error_outline_rounded,
                                color: AppPalette.mutedText, size: 40),
                            const SizedBox(height: 12),
                            Text(
                              'Could not load plans. Please try again.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppPalette.mutedText),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'No subscription plans are available right now.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppPalette.mutedText),
                        ),
                      ),
                    );
                  }

                  final plans = docs.map((d) {
                    return SubscriptionPlan.fromFirestore(
                      d as DocumentSnapshot<Map<String, dynamic>>,
                    );
                  }).toList();

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: plans.length,
                    itemBuilder: (context, index) {
                      return _buildPlanCard(plans[index]);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBusinessSelector() {
    if (_isLoadingBusinesses) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              color: AppPalette.ochre,
              strokeWidth: 2,
            ),
          ),
        ),
      );
    }

    if (_ownerBusinesses.isEmpty) {
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
        ),
        child: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'You need an active business listing before you can purchase a subscription.',
                style: TextStyle(color: AppPalette.charcoal),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: _selectedBusinessId,
          hint: const Text('Select a business'),
          items: _ownerBusinesses.map((business) {
            return DropdownMenuItem<String>(
              value: business.id,
              child: Text(
                business.businessName.isNotEmpty
                    ? business.businessName
                    : 'Unnamed business',
                style: const TextStyle(color: AppPalette.charcoal),
              ),
            );
          }).toList(),
          onChanged: (value) {
            setState(() => _selectedBusinessId = value);
          },
        ),
      ),
    );
  }

  Widget _buildPlanCard(SubscriptionPlan plan) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppPalette.ochre.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppPalette.ochre.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    plan.interval.name[0].toUpperCase() +
                        plan.interval.name.substring(1),
                    style: TextStyle(
                      color: AppPalette.ochre,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  _formattedPrice(plan.priceCents),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppPalette.charcoal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              plan.name,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppPalette.charcoal,
              ),
            ),
            if (plan.description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  plan.description,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppPalette.mutedText,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildMetaChip(
                    Icons.calendar_today_rounded, '/ ${plan.intervalLabel}'),
                ...plan.features.map((feature) {
                  return _buildMetaChip(Icons.check_circle_rounded, feature);
                }),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isCheckingOut ? null : () => _purchasePlan(plan),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppPalette.ochre,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _isCheckingOut
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Subscribe',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppPalette.mutedText),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppPalette.charcoal,
            ),
          ),
        ],
      ),
    );
  }
}
