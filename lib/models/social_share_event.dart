import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:brisconnect/services/share/content_share_service.dart';

/// A recorded social share/tag action initiated by a visitor.
///
/// Stored in Firestore under the `social_shares` collection and surfaced in
/// the vendor portal so business owners can see when visitors share their
/// business, event, or promotion to Instagram, Facebook, TikTok, etc.
class SocialShareEvent {
  final String? id;
  final String visitorId;
  final String? visitorName;
  final String businessId;
  final String? businessName;
  final String contentId;
  final ShareContentType contentType;
  final String platform;
  final String shareKind;
  final String title;
  final String? description;
  final String? imageUrl;
  final String? shareUrl;
  final DateTime createdAt;

  const SocialShareEvent({
    this.id,
    required this.visitorId,
    this.visitorName,
    required this.businessId,
    this.businessName,
    required this.contentId,
    required this.contentType,
    required this.platform,
    required this.shareKind,
    required this.title,
    this.description,
    this.imageUrl,
    this.shareUrl,
    required this.createdAt,
  });

  factory SocialShareEvent.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? const {};
    final createdAt = data['createdAt'];
    return SocialShareEvent(
      id: doc.id,
      visitorId: data['visitorId']?.toString() ?? '',
      visitorName: data['visitorName']?.toString(),
      businessId: data['businessId']?.toString() ?? '',
      businessName: data['businessName']?.toString(),
      contentId: data['contentId']?.toString() ?? '',
      contentType: _parseContentType(data['contentType']),
      platform: data['platform']?.toString() ?? 'unknown',
      shareKind: data['shareKind']?.toString() ?? 'link',
      title: data['title']?.toString() ?? 'Untitled',
      description: data['description']?.toString(),
      imageUrl: data['imageUrl']?.toString(),
      shareUrl: data['shareUrl']?.toString(),
      createdAt: createdAt is Timestamp ? createdAt.toDate() : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'visitorId': visitorId,
      if (visitorName != null) 'visitorName': visitorName,
      'businessId': businessId,
      if (businessName != null) 'businessName': businessName,
      'contentId': contentId,
      'contentType': contentType.name,
      'platform': platform,
      'shareKind': shareKind,
      'title': title,
      if (description != null) 'description': description,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (shareUrl != null) 'shareUrl': shareUrl,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  static ShareContentType _parseContentType(dynamic value) {
    final name = value?.toString().toLowerCase() ?? '';
    return ShareContentType.values.firstWhere(
      (t) => t.name == name,
      orElse: () => ShareContentType.business,
    );
  }
}
