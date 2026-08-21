import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'package:brisconnect/config/app_config.dart';
import 'package:brisconnect/models/promotion_plan.dart';

/// Service for admin promotion plan and active promotion management.
class AdminPromotionService {
  AdminPromotionService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ??
            FirebaseFunctions.instanceFor(
                region: AppConfig.firebaseFunctionsRegion);

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  static const String _plansCollection = 'promotion_plans';
  static const String _paymentsCollection = 'business_payments';

  /// Stream of all promotion plans ordered by creation date.
  Stream<List<PromotionPlan>> getPromotionPlans() {
    return _firestore
        .collection(_plansCollection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map(PromotionPlan.fromFirestore).toList());
  }

  /// Stream of currently active business promotions.
  Stream<List<ActivePromotion>> getActivePromotions() {
    final now = Timestamp.now();
    return _firestore
        .collection(_paymentsCollection)
        .where('type', isEqualTo: 'promotion')
        .where('status', isEqualTo: 'paid')
        .where('expiresAt', isGreaterThan: now)
        .orderBy('expiresAt', descending: false)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map(ActivePromotion.fromFirestore).toList());
  }

  /// Create or update a promotion plan. Returns the plan ID.
  ///
  /// The backend will create/update the corresponding Stripe Product and Price.
  Future<String> savePromotionPlan(PromotionPlan plan) async {
    final callable = _functions.httpsCallable('savePromotionPlan');
    final result = await callable.call<Map<String, dynamic>>({
      'id': plan.id,
      'type': plan.type.name,
      'name': plan.name,
      'description': plan.description,
      'priceCents': plan.priceCents,
      'durationDays': plan.durationDays,
      'features': plan.features,
      'isActive': plan.isActive,
    });
    final data = result.data;
    final planId = data['planId'] as String?;
    if (planId == null || planId.isEmpty) {
      throw Exception('Backend did not return a plan ID.');
    }
    return planId;
  }

  /// Toggle whether a plan is active.
  Future<void> setPlanActive(String planId, bool isActive) async {
    final callable = _functions.httpsCallable('setPlanActive');
    await callable.call({'planId': planId, 'isActive': isActive});
  }

  /// Manually deactivate a business promotion.
  Future<void> deactivatePromotion(String paymentId) async {
    final callable = _functions.httpsCallable('deactivatePromotion');
    await callable.call({'paymentId': paymentId});
  }
}

/// Lightweight view model for an active business promotion.
class ActivePromotion {
  final String id;
  final String ownerId;
  final String businessId;
  final String promotionTitle;
  final String? planName;
  final int amountCents;
  final DateTime? paidAt;
  final DateTime? expiresAt;
  final String status;
  final String? receiptUrl;

  const ActivePromotion({
    required this.id,
    required this.ownerId,
    required this.businessId,
    required this.promotionTitle,
    this.planName,
    required this.amountCents,
    this.paidAt,
    this.expiresAt,
    required this.status,
    this.receiptUrl,
  });

  factory ActivePromotion.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ActivePromotion(
      id: doc.id,
      ownerId: data['ownerId'] as String? ?? '',
      businessId: data['businessId'] as String? ?? '',
      promotionTitle: data['promotionTitle'] as String? ?? '',
      planName: data['planName'] as String?,
      amountCents: (data['amountCents'] as num?)?.toInt() ?? 0,
      paidAt: (data['paidAt'] as Timestamp?)?.toDate(),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate(),
      status: data['status'] as String? ?? '',
      receiptUrl: data['receiptUrl'] as String?,
    );
  }
}
