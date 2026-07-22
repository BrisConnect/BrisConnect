import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';

import 'package:brisconnect/models/audience_interaction.dart';

/// Breakdown of new vs returning viewers in a date range.
class AudienceBreakdown {
  final int newVisitors;
  final int returningVisitors;
  final int totalInteractions;

  const AudienceBreakdown({
    this.newVisitors = 0,
    this.returningVisitors = 0,
    this.totalInteractions = 0,
  });

  double get newPercentage =>
      totalInteractions == 0 ? 0 : newVisitors / totalInteractions;

  double get returningPercentage =>
      totalInteractions == 0 ? 0 : returningVisitors / totalInteractions;
}

/// Engagement counts grouped by hour of day (0-23) or day of week (1-7).
class EngagementDistribution {
  final Map<int, int> byHour;
  final Map<int, int> byDayOfWeek;
  final int total;

  const EngagementDistribution({
    this.byHour = const {},
    this.byDayOfWeek = const {},
    this.total = 0,
  });
}

/// Service for business owner audience analytics.
///
/// All data is anonymised and aggregated. The service never stores or returns
/// personally identifiable information.
class AudienceAnalyticsService {
  final FirebaseFirestore _firestore;

  AudienceAnalyticsService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  static const String _interactionsCollection = 'audience_interactions';
  static const int _minSampleSize = 20;

  /// Hashes a visitor identifier into a privacy-preserving stable token.
  ///
  /// The result is a truncated SHA-256 hash so the original UID cannot be
  /// reversed, while still allowing new vs returning detection.
  static String anonymiseVisitorId(String visitorId) {
    final bytes = utf8.encode(visitorId);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 16);
  }

  /// Whether the provided [interactionCount] is large enough to be considered
  /// statistically meaningful.
  static bool isSampleMeaningful(int interactionCount) =>
      interactionCount >= _minSampleSize;

  /// Streams all anonymised interactions for businesses owned by [ownerId]
  /// within the optional [dateRange].
  Stream<List<AudienceInteraction>> interactionsStream(
    String ownerId, {
    DateTimeRange? dateRange,
  }) async* {
    Query query = _firestore
        .collection(_interactionsCollection)
        .where('ownerId', isEqualTo: ownerId)
        .orderBy('timestamp', descending: true);

    if (dateRange != null) {
      query = query
          .where('timestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(dateRange.start))
          .where('timestamp',
              isLessThanOrEqualTo: Timestamp.fromDate(dateRange.end));
    }

    yield* query.snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => AudienceInteraction.fromFirestore(doc))
              .toList(),
        );
  }

  /// Computes new vs returning viewer breakdown for the date range.
  Future<AudienceBreakdown> getAudienceBreakdown(
    String ownerId, {
    required DateTime start,
    required DateTime end,
  }) async {
    // Fetch all interactions in range up-front so we can compare the
    // selected range to the lifetime history of each visitor.
    final snapshot = await _firestore
        .collection(_interactionsCollection)
        .where('ownerId', isEqualTo: ownerId)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .get();

    final interactions = snapshot.docs
        .map((doc) => AudienceInteraction.fromFirestore(doc))
        .toList();

    if (interactions.isEmpty) return const AudienceBreakdown();

    final visitorsInRange = <String>{};
    for (final i in interactions) {
      visitorsInRange.add(i.visitorHash);
    }

    // A visitor is "new" in this range if their first ever interaction across
    // all of the owner's businesses is within the range.
    var newVisitors = 0;
    var returningVisitors = 0;
    for (final visitorHash in visitorsInRange) {
      final firstInteractionSnap = await _firestore
          .collection(_interactionsCollection)
          .where('ownerId', isEqualTo: ownerId)
          .where('visitorHash', isEqualTo: visitorHash)
          .orderBy('timestamp', descending: false)
          .limit(1)
          .get();

      if (firstInteractionSnap.docs.isEmpty) continue;

      final first = AudienceInteraction.fromFirestore(
        firstInteractionSnap.docs.first,
      );
      if (!first.timestamp.isBefore(start) && !first.timestamp.isAfter(end)) {
        newVisitors++;
      } else {
        returningVisitors++;
      }
    }

    return AudienceBreakdown(
      newVisitors: newVisitors,
      returningVisitors: returningVisitors,
      totalInteractions: interactions.length,
    );
  }

  /// Computes engagement distribution by hour of day and day of week.
  Future<EngagementDistribution> getEngagementDistribution(
    String ownerId, {
    required DateTime start,
    required DateTime end,
  }) async {
    final snapshot = await _firestore
        .collection(_interactionsCollection)
        .where('ownerId', isEqualTo: ownerId)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .get();

    final byHour = <int, int>{};
    final byDayOfWeek = <int, int>{};
    var total = 0;

    for (final doc in snapshot.docs) {
      final interaction = AudienceInteraction.fromFirestore(doc);
      final local = interaction.timestamp.toLocal();
      byHour[local.hour] = (byHour[local.hour] ?? 0) + 1;
      byDayOfWeek[local.weekday] = (byDayOfWeek[local.weekday] ?? 0) + 1;
      total++;
    }

    return EngagementDistribution(
      byHour: byHour,
      byDayOfWeek: byDayOfWeek,
      total: total,
    );
  }

  /// Records a single anonymised interaction.
  Future<void> recordInteraction({
    required String businessId,
    required String ownerId,
    required String visitorId,
    required AudienceInteractionType type,
    DateTime? timestamp,
  }) async {
    if (businessId.trim().isEmpty ||
        ownerId.trim().isEmpty ||
        visitorId.trim().isEmpty) {
      return;
    }

    final visitorHash = anonymiseVisitorId(visitorId);
    final interaction = AudienceInteraction(
      businessId: businessId,
      ownerId: ownerId,
      visitorHash: visitorHash,
      type: type,
      timestamp: timestamp ?? DateTime.now(),
    );

    try {
      await _firestore.collection(_interactionsCollection).add(
            interaction.toFirestore(),
          );
    } catch (e) {
      debugPrint('[AudienceAnalyticsService] recordInteraction failed: $e');
    }
  }
}
