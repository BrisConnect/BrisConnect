import 'package:cloud_firestore/cloud_firestore.dart';

/// The kinds of promotion plans an admin can configure.
enum PromotionPlanType {
  premium,
  featured,
  promotionDay,
}

/// Admin-configurable promotion plan.
///
/// Plans define pricing, duration, and feature flags. When a plan is active,
/// business owners can purchase it through Stripe Checkout using the linked
/// [stripePriceId].
class PromotionPlan {
  final String? id;
  final PromotionPlanType type;
  final String name;
  final String description;
  final int priceCents;
  final int durationDays;
  final List<String> features;
  final String? stripeProductId;
  final String? stripePriceId;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PromotionPlan({
    this.id,
    required this.type,
    required this.name,
    this.description = '',
    required this.priceCents,
    required this.durationDays,
    this.features = const [],
    this.stripeProductId,
    this.stripePriceId,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  String get typeLabel {
    switch (type) {
      case PromotionPlanType.premium:
        return 'Premium';
      case PromotionPlanType.featured:
        return 'Featured';
      case PromotionPlanType.promotionDay:
        return 'Promotion Day';
    }
  }

  static String typeLabelFor(PromotionPlanType type) => PromotionPlan(
          type: type,
          name: '',
          priceCents: 0,
          durationDays: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now())
      .typeLabel;

  Map<String, dynamic> toFirestore() {
    return {
      'type': type.name,
      'name': name,
      'description': description,
      'priceCents': priceCents,
      'durationDays': durationDays,
      'features': features,
      'stripeProductId': stripeProductId,
      'stripePriceId': stripePriceId,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory PromotionPlan.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return PromotionPlan(
      id: doc.id,
      type: _parseType(data['type'] as String?),
      name: data['name'] as String? ?? '',
      description: data['description'] as String? ?? '',
      priceCents: (data['priceCents'] as num?)?.toInt() ?? 0,
      durationDays: (data['durationDays'] as num?)?.toInt() ?? 0,
      features:
          (data['features'] as List<dynamic>?)?.map((e) => '$e').toList() ?? [],
      stripeProductId: data['stripeProductId'] as String?,
      stripePriceId: data['stripePriceId'] as String?,
      isActive: data['isActive'] == true,
      createdAt: _toDateTime(data['createdAt']),
      updatedAt: _toDateTime(data['updatedAt']),
    );
  }

  PromotionPlan copyWith({
    String? id,
    PromotionPlanType? type,
    String? name,
    String? description,
    int? priceCents,
    int? durationDays,
    List<String>? features,
    String? stripeProductId,
    String? stripePriceId,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PromotionPlan(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      description: description ?? this.description,
      priceCents: priceCents ?? this.priceCents,
      durationDays: durationDays ?? this.durationDays,
      features: features ?? this.features,
      stripeProductId: stripeProductId ?? this.stripeProductId,
      stripePriceId: stripePriceId ?? this.stripePriceId,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static PromotionPlanType _parseType(String? value) {
    switch (value) {
      case 'featured':
        return PromotionPlanType.featured;
      case 'promotionDay':
        return PromotionPlanType.promotionDay;
      case 'premium':
      default:
        return PromotionPlanType.premium;
    }
  }

  static DateTime _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.now();
  }
}
