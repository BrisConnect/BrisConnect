import 'package:cloud_firestore/cloud_firestore.dart';

/// The kinds of subscription plans an admin can configure.
enum SubscriptionInterval {
  monthly,
  yearly,
}

/// Admin-configurable subscription plan.
///
/// Plans define pricing, billing interval, and feature flags. When a plan is
/// active, business owners can purchase it through Stripe Checkout using the
/// linked [stripePriceId].
class SubscriptionPlan {
  final String? id;
  final String name;
  final String description;
  final int priceCents;
  final SubscriptionInterval interval;
  final List<String> features;
  final String? stripeProductId;
  final String? stripePriceId;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SubscriptionPlan({
    this.id,
    required this.name,
    this.description = '',
    required this.priceCents,
    this.interval = SubscriptionInterval.monthly,
    this.features = const [],
    this.stripeProductId,
    this.stripePriceId,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  String get intervalLabel {
    switch (interval) {
      case SubscriptionInterval.monthly:
        return 'month';
      case SubscriptionInterval.yearly:
        return 'year';
    }
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'priceCents': priceCents,
      'interval': interval.name,
      'features': features,
      'stripeProductId': stripeProductId,
      'stripePriceId': stripePriceId,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory SubscriptionPlan.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return SubscriptionPlan(
      id: doc.id,
      name: data['name'] as String? ?? '',
      description: data['description'] as String? ?? '',
      priceCents: (data['priceCents'] as num?)?.toInt() ?? 0,
      interval: _parseInterval(data['interval'] as String?),
      features:
          (data['features'] as List<dynamic>?)?.map((e) => '$e').toList() ?? [],
      stripeProductId: data['stripeProductId'] as String?,
      stripePriceId: data['stripePriceId'] as String?,
      isActive: data['isActive'] == true,
      createdAt: _toDateTime(data['createdAt']),
      updatedAt: _toDateTime(data['updatedAt']),
    );
  }

  SubscriptionPlan copyWith({
    String? id,
    String? name,
    String? description,
    int? priceCents,
    SubscriptionInterval? interval,
    List<String>? features,
    String? stripeProductId,
    String? stripePriceId,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SubscriptionPlan(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      priceCents: priceCents ?? this.priceCents,
      interval: interval ?? this.interval,
      features: features ?? this.features,
      stripeProductId: stripeProductId ?? this.stripeProductId,
      stripePriceId: stripePriceId ?? this.stripePriceId,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static SubscriptionInterval _parseInterval(String? value) {
    switch (value) {
      case 'yearly':
        return SubscriptionInterval.yearly;
      case 'monthly':
      default:
        return SubscriptionInterval.monthly;
    }
  }

  static DateTime _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.now();
  }
}
