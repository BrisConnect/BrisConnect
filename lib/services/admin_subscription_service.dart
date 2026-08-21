import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'package:brisconnect/config/app_config.dart';
import 'package:brisconnect/models/subscription_plan.dart';

/// Service for admin subscription plan management.
class AdminSubscriptionService {
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  AdminSubscriptionService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ??
            FirebaseFunctions.instanceFor(
                region: AppConfig.firebaseFunctionsRegion);

  static const String _plansCollection = 'subscription_plans';

  Stream<List<SubscriptionPlan>> getSubscriptionPlans() {
    return _firestore
        .collection(_plansCollection)
        .orderBy('priceCents')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SubscriptionPlan.fromFirestore(doc))
            .toList());
  }

  Future<String> saveSubscriptionPlan(SubscriptionPlan plan) async {
    final callable = _functions.httpsCallable('saveSubscriptionPlan');
    final result =
        await callable.call(plan.toFirestore()..['id'] = plan.id ?? '');
    final data = result.data as Map<String, dynamic>? ?? {};
    final planId = data['planId'] as String?;
    if (planId == null || planId.isEmpty) {
      throw Exception('Server did not return a plan ID.');
    }
    return planId;
  }

  Future<void> setPlanActive(String planId, bool isActive) async {
    final callable = _functions.httpsCallable('setSubscriptionPlanActive');
    await callable.call({'planId': planId, 'isActive': isActive});
  }
}
