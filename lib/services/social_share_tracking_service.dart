import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/foundation.dart';

import 'package:brisconnect/auth/visitor_auth.dart';
import 'package:brisconnect/models/social_share_event.dart';
import 'package:brisconnect/services/share/content_share_service.dart';

/// Tracks visitor social-share actions so they can be surfaced live in the
/// vendor portal.
///
/// Each call writes a document to the `social_shares` collection. The write
/// is best-effort: failures are logged but never block the share UI.
class SocialShareTrackingService {
  static const String _collection = 'social_shares';

  final FirebaseFirestore _firestore;

  SocialShareTrackingService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Records a share event to Firestore.
  ///
  /// [businessId] is the canonical business that owns the content. For
  /// [ShareContentType.business] this is the same as [contentId]; for events
  /// and promotions it is the related business id.
  ///
  /// Returns `true` if the write succeeded, `false` otherwise. Callers can
  /// use the result to warn the user when a share could not be tracked.
  Future<bool> recordShare({
    required String businessId,
    String? businessName,
    required String contentId,
    required ShareContentType contentType,
    required String platform,
    required String shareKind,
    required String title,
    String? description,
    String? imageUrl,
    String? shareUrl,
  }) async {
    final visitor = VisitorAuth.currentVisitor;
    final fbUser = fb_auth.FirebaseAuth.instance.currentUser;
    final visitorId = fbUser?.uid ?? visitor?.email ?? 'anonymous';
    final visitorName = visitor?.name;

    final event = SocialShareEvent(
      visitorId: visitorId,
      visitorName: visitorName,
      businessId: businessId,
      businessName: businessName,
      contentId: contentId,
      contentType: contentType,
      platform: platform.toLowerCase(),
      shareKind: shareKind.toLowerCase(),
      title: title,
      description: description,
      imageUrl: imageUrl,
      shareUrl: shareUrl,
      createdAt: DateTime.now(),
    );

    try {
      await _firestore.collection(_collection).add(event.toFirestore());
      return true;
    } catch (e) {
      debugPrint('[SocialShareTrackingService] failed to record share: $e');
      return false;
    }
  }

  /// Live stream of social share events for a given [businessId].
  Stream<List<SocialShareEvent>> streamForBusiness(String businessId,
      {int limit = 50}) {
    return _firestore
        .collection(_collection)
        .where('businessId', isEqualTo: businessId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(SocialShareEvent.fromFirestore)
              .where((e) => e.businessId.isNotEmpty)
              .toList(),
        );
  }

  /// Live stream of social share events for a list of [businessIds].
  Stream<List<SocialShareEvent>> streamForBusinesses(List<String> businessIds,
      {int limit = 50}) {
    if (businessIds.isEmpty) return Stream.value(const []);
    // Firestore supports up to 10 values in a whereIn clause.
    final ids = businessIds.take(10).toList();
    return _firestore
        .collection(_collection)
        .where('businessId', whereIn: ids)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(SocialShareEvent.fromFirestore)
              .where((e) => e.businessId.isNotEmpty)
              .toList(),
        );
  }

  /// One-time count of shares for [businessId] in the last [days].
  Future<int> shareCount(String businessId, {int days = 30}) async {
    final since = DateTime.now().subtract(Duration(days: days));
    try {
      final snap = await _firestore
          .collection(_collection)
          .where('businessId', isEqualTo: businessId)
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
          .count()
          .get();
      return snap.count ?? 0;
    } catch (e) {
      debugPrint('[SocialShareTrackingService] shareCount failed: $e');
      return 0;
    }
  }
}
