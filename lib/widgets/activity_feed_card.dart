import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:brisconnect/auth/visitor_auth.dart';
import 'package:brisconnect/models/activity_feed_item.dart';
import 'package:brisconnect/models/post_comment.dart';
import 'package:brisconnect/models/post_engagement.dart';
import 'package:brisconnect/screens/visitor_event_detail_screen.dart';
import 'package:brisconnect/services/post_engagement_service.dart';
import 'package:brisconnect/services/share/content_share_service.dart';
import 'package:brisconnect/services/visitor_photo_service.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/widgets/share_bottom_sheet.dart';

/// A compact, visually engaging card for a single community feed item.
///
/// Displays the actor avatar, display name, timestamp, business context,
/// content-type badge, optional media, and the full engagement bar.
class ActivityFeedCard extends StatefulWidget {
  final ActivityFeedItem item;
  final PostEngagementService engagementService;

  const ActivityFeedCard({
    super.key,
    required this.item,
    required this.engagementService,
  });

  @override
  State<ActivityFeedCard> createState() => _ActivityFeedCardState();
}

class _ActivityFeedCardState extends State<ActivityFeedCard> {
  final Map<PostEngagementAction, bool> _engagedStates = {};
  bool _isDeleting = false;

  ActivityFeedItem get item => widget.item;

  @override
  void initState() {
    super.initState();
    _preloadEngagement();
  }

  Future<void> _preloadEngagement() async {
    for (final action in PostEngagementAction.values) {
      final engaged = await widget.engagementService.hasEngaged(
        item: item,
        action: action,
      );
      if (mounted) {
        setState(() => _engagedStates[action] = engaged);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isDeleting) {
      return const SizedBox.shrink();
    }

    return InkWell(
      onTap: () => _openDetail(context),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: AppPalette.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppPalette.border,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 24,
              offset: const Offset(0, 8),
              spreadRadius: -2,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (item.imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: Stack(
                  children: [
                    _buildImage(context, item.imageUrl),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: _buildPromotionLabel(),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeader(context),
                  const SizedBox(height: 10),
                  _buildTitle(theme),
                  if (item.subtitle.isNotEmpty &&
                      item.type != ActivityFeedType.review) ...[
                    const SizedBox(height: 4),
                    _buildSubtitle(theme),
                  ],
                  if (item.body.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _buildBody(theme),
                  ],
                  if (item.type == ActivityFeedType.event) ...[
                    const SizedBox(height: 10),
                    _buildEventMetaRow(),
                  ],
                  const SizedBox(height: 12),
                  _buildEngagementBar(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAvatar(),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.actorName ?? item.title,
                      style: const TextStyle(
                        color: AppPalette.charcoal,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildTypeBadge(),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  if (item.businessName != null &&
                      item.businessName!.isNotEmpty) ...[
                    Flexible(
                      child: Text(
                        item.businessName!,
                        style: TextStyle(
                          color: AppPalette.ochre,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      width: 3,
                      height: 3,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        color: AppPalette.mutedText.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                  Icon(
                    Icons.access_time_rounded,
                    size: 11,
                    color: AppPalette.mutedText,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatTimestamp(item.createdAt),
                    style: const TextStyle(
                      color: AppPalette.mutedText,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        _buildShareButton(context),
      ],
    );
  }

  Widget _buildAvatar() {
    final name = item.actorName ?? item.title;
    final imageUrl = item.actorPhotoUrl;
    const size = 40.0;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppPalette.surfaceAlt,
        border: Border.all(color: AppPalette.border, width: 1),
      ),
      child: ClipOval(
        child: imageUrl != null && imageUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _fallbackAvatar(name, size),
              )
            : _fallbackAvatar(name, size),
      ),
    );
  }

  Widget _fallbackAvatar(String fallback, double size) {
    return Center(
      child: Text(
        fallback.isNotEmpty ? fallback[0].toUpperCase() : '?',
        style: TextStyle(
          color: AppPalette.ochre,
          fontWeight: FontWeight.w900,
          fontSize: size * 0.45,
        ),
      ),
    );
  }

  Widget _buildTypeBadge() {
    final (label, color, icon) = switch (item.type) {
      ActivityFeedType.review => (
          'Review',
          const Color(0xFF2563EB),
          Icons.rate_review_rounded,
        ),
      ActivityFeedType.event => (
          'Event',
          const Color(0xFF7C3AED),
          Icons.event_rounded,
        ),
      ActivityFeedType.business => (
          'Promotion',
          const Color(0xFFEA580C),
          Icons.local_offer_rounded,
        ),
      ActivityFeedType.photo => (
          'Crowd Update',
          const Color(0xFF059669),
          Icons.people_rounded,
        ),
      _ => (
          'Post',
          AppPalette.mutedText,
          Icons.dynamic_feed_rounded,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitle(ThemeData theme) {
    final title = item.type == ActivityFeedType.review &&
            item.businessName != null &&
            item.businessName!.isNotEmpty
        ? item.businessName!
        : item.title;

    return Text(
      title,
      style: const TextStyle(
        color: AppPalette.charcoal,
        fontSize: 15,
        fontWeight: FontWeight.w800,
        height: 1.25,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildSubtitle(ThemeData theme) {
    return Text(
      item.subtitle,
      style: TextStyle(
        color: AppPalette.mutedText.withValues(alpha: 0.9),
        fontSize: 12,
        fontWeight: FontWeight.w600,
        height: 1.35,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildBody(ThemeData theme) {
    return Text(
      item.body,
      style: const TextStyle(
        color: Colors.black87,
        fontSize: 13,
        fontWeight: FontWeight.w400,
        height: 1.5,
      ),
      maxLines: 4,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildImage(BuildContext context, String url) {
    final width = MediaQuery.of(context).size.width;
    final imageHeight = width < 600
        ? 180.0
        : width < 1024
            ? 220.0
            : 240.0;

    return SizedBox(
      height: imageHeight,
      width: double.infinity,
      child: CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        fadeInDuration: Duration.zero,
        fadeOutDuration: Duration.zero,
        memCacheWidth: (width * MediaQuery.devicePixelRatioOf(context)).toInt(),
        memCacheHeight:
            (imageHeight * MediaQuery.devicePixelRatioOf(context)).toInt(),
        maxWidthDiskCache: 1200,
        maxHeightDiskCache: 800,
        placeholder: (_, __) => Container(
          color: AppPalette.surfaceAlt,
        ),
        errorWidget: (_, __, ___) => Container(
          color: AppPalette.surfaceAlt,
          alignment: Alignment.center,
          child: const Icon(
            Icons.image_not_supported_rounded,
            color: AppPalette.mutedText,
          ),
        ),
      ),
    );
  }

  Widget _buildPromotionLabel() {
    final label = item.promotionLabel;
    if (label == null || label.isEmpty) return const SizedBox.shrink();

    final (background, foreground, icon) = switch (label.toLowerCase()) {
      'limited time' => (
          const Color(0xFFFFF3E0),
          const Color(0xFFE65100),
          Icons.timer_outlined,
        ),
      'today only' => (
          const Color(0xFFFFEBEE),
          const Color(0xFFB71C1C),
          Icons.access_time_filled_rounded,
        ),
      'new' => (
          const Color(0xFFE8F5E9),
          const Color(0xFF1B5E20),
          Icons.fiber_new_rounded,
        ),
      'featured' => (
          const Color(0xFFF3E5F5),
          const Color(0xFF4A148C),
          Icons.star_rounded,
        ),
      _ => (
          AppPalette.deepBlue.withValues(alpha: 0.08),
          AppPalette.deepBlue,
          Icons.local_offer_outlined,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(99),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: foreground),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventMetaRow() {
    final chips = <Widget>[];

    final suburb = item.eventSuburb;
    if (suburb != null && suburb.isNotEmpty) {
      chips.add(_EventMetaChip(
        icon: Icons.place_rounded,
        text: suburb,
      ));
    }

    final isFree = item.isFreeEntry;
    if (isFree != null) {
      chips.add(_EventMetaChip(
        icon: isFree ? Icons.money_off_rounded : Icons.attach_money_rounded,
        text: isFree ? 'Free Entry' : 'Paid',
        color: isFree ? const Color(0xFF047857) : const Color(0xFFB45309),
        backgroundColor:
            isFree ? const Color(0xFFE8F5E9) : const Color(0xFFFEF3C7),
      ));
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: chips,
    );
  }

  Widget _buildEngagementBar(BuildContext context) {
    return StreamBuilder<Map<PostEngagementAction, int>>(
      stream: widget.engagementService.engagementCounts(item: item),
      initialData: const {},
      builder: (context, snapshot) {
        final counts = snapshot.data ?? const {};
        return Row(
          children: [
            _EngagementPill(
              icon: _engagedStates[PostEngagementAction.like] == true
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              label:
                  _formatCount(counts[PostEngagementAction.like] ?? 0, 'Like'),
              active: _engagedStates[PostEngagementAction.like] == true,
              activeColor: const Color(0xFFDC2626),
              onTap: () => _toggleEngagement(PostEngagementAction.like),
            ),
            const SizedBox(width: 8),
            _EngagementPill(
              icon: Icons.chat_bubble_outline_rounded,
              label: _formatCount(
                  counts[PostEngagementAction.comment] ?? 0, 'Comment'),
              active: false,
              onTap: () => _showCommentSheet(context),
            ),
            const SizedBox(width: 8),
            _EngagementPill(
              icon: _engagedStates[PostEngagementAction.save] == true
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
              label:
                  _formatCount(counts[PostEngagementAction.save] ?? 0, 'Save'),
              active: _engagedStates[PostEngagementAction.save] == true,
              onTap: () => _toggleEngagement(PostEngagementAction.save),
            ),
            const Spacer(),
            _BuzzVoteButton(
              active: _engagedStates[PostEngagementAction.buzzVote] == true,
              count: counts[PostEngagementAction.buzzVote] ?? 0,
              onTap: () => _toggleEngagement(PostEngagementAction.buzzVote),
            ),
            if (_canDelete()) ...[
              const SizedBox(width: 8),
              _DeleteButton(onTap: () => _confirmDelete(context)),
            ],
          ],
        );
      },
    );
  }

  Widget _buildShareButton(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _shareItem(context),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(
            Icons.share_outlined,
            color: AppPalette.mutedText.withValues(alpha: 0.8),
            size: 18,
          ),
        ),
      ),
    );
  }

  String _formatCount(int count, String label) {
    if (count <= 0) return label;
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}k';
    }
    return '$count';
  }

  String _formatTimestamp(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 365) {
      return DateFormat.MMMd().format(date);
    }
    return DateFormat.yMMMd().format(date);
  }

  Future<void> _toggleEngagement(PostEngagementAction action) async {
    if (!VisitorAuth.isVisitorLoggedIn) {
      _showSignInSnack(context);
      return;
    }

    setState(() {
      _engagedStates[action] = !(_engagedStates[action] ?? false);
    });

    final result = await widget.engagementService.toggle(
      item: item,
      action: action,
    );

    if (result != null && mounted) {
      setState(() => _engagedStates[action] = result);
    } else if (mounted) {
      setState(() {
        _engagedStates[action] = !(_engagedStates[action] ?? false);
      });
    }
  }

  bool _canDelete() {
    if (!VisitorAuth.isVisitorLoggedIn) return false;
    if (item.type != ActivityFeedType.photo) return false;
    final currentVisitor = FirebaseAuth.instance.currentUser;
    if (currentVisitor == null) return false;
    final currentVisitorId = currentVisitor.uid;
    return item.targetId.isNotEmpty &&
        currentVisitorId.isNotEmpty &&
        currentVisitorId == item.secondaryTargetId;
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete post?'),
        content: const Text('This will permanently remove your photo from the community feed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    setState(() => _isDeleting = true);

    try {
      await VisitorPhotoService().deletePhoto(item.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete post: $e')),
        );
      }
    }
  }

  void _showSignInSnack(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please sign in to interact with posts.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showCommentSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppPalette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return _CommentSheet(
          item: item,
          engagementService: widget.engagementService,
        );
      },
    );
  }

  void _shareItem(BuildContext context) {
    widget.engagementService.recordShare(item: item);

    final type = switch (item.type) {
      ActivityFeedType.event => ShareContentType.event,
      ActivityFeedType.business => ShareContentType.business,
      ActivityFeedType.photo => ShareContentType.business,
      ActivityFeedType.review => ShareContentType.business,
      _ => null,
    };
    if (type == null) return;

    String? businessId;
    if (item.type == ActivityFeedType.event) {
      businessId = item.secondaryTargetId;
    } else {
      businessId = item.targetId;
    }

    showShareBottomSheet(
      context: context,
      type: type,
      id: item.targetId,
      title: item.title,
      description: item.body,
      dateTime: item.type == ActivityFeedType.event ? item.subtitle : null,
      imageUrl: item.imageUrl.isNotEmpty ? item.imageUrl : null,
      businessId: businessId,
      businessName: item.title,
    );
  }

  void _openDetail(BuildContext context) {
    switch (item.type) {
      case ActivityFeedType.review:
      case ActivityFeedType.business:
      case ActivityFeedType.photo:
        Navigator.of(context).pushNamed(
          '/business/view',
          arguments: item.targetId,
        );
      case ActivityFeedType.event:
        _openEventDetail(context, item.targetId);
      case _:
        break;
    }
  }

  void _openEventDetail(BuildContext context, String eventId) async {
    final doc = await FirebaseFirestore.instance
        .collection('business_events')
        .doc(eventId)
        .get();
    if (!context.mounted) return;
    if (!doc.exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This event is no longer available.')),
      );
      return;
    }
    final data = doc.data()!;
    final event = <String, dynamic>{'id': doc.id, ...data};
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VisitorEventDetailScreen(event: event),
      ),
    );
  }
}

class _DeleteButton extends StatelessWidget {
  final VoidCallback onTap;

  const _DeleteButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(
            Icons.delete_outline_rounded,
            color: AppPalette.mutedText.withValues(alpha: 0.8),
            size: 18,
          ),
        ),
      ),
    );
  }
}

class _EventMetaChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;
  final Color? backgroundColor;

  const _EventMetaChip({
    required this.icon,
    required this.text,
    this.color,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? AppPalette.deepBlue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppPalette.deepBlue.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: chipColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: chipColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet showing all comments for a post plus an input row that
/// supports attaching a single photo or short video before posting.
class _CommentSheet extends StatefulWidget {
  final ActivityFeedItem item;
  final PostEngagementService engagementService;

  const _CommentSheet({
    required this.item,
    required this.engagementService,
  });

  @override
  State<_CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends State<_CommentSheet> {
  final TextEditingController _textController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  Uint8List? _mediaBytes;
  String? _mediaFileName;
  String? _mediaMimeType;
  bool _isVideo = false;
  bool _posting = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() {
      _mediaBytes = bytes;
      _mediaFileName = picked.name;
      _mediaMimeType = picked.mimeType ?? 'image/jpeg';
      _isVideo = false;
    });
  }

  Future<void> _pickVideo() async {
    final picked = await _picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 2),
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (bytes.length > PostEngagementService.maxCommentMediaBytes) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Video is too large (max 20 MB).')),
        );
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      _mediaBytes = bytes;
      _mediaFileName = picked.name;
      _mediaMimeType = picked.mimeType ?? 'video/mp4';
      _isVideo = true;
    });
  }

  void _clearMedia() {
    setState(() {
      _mediaBytes = null;
      _mediaFileName = null;
      _mediaMimeType = null;
      _isVideo = false;
    });
  }

  Future<void> _confirmDeleteComment(PostComment comment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete comment?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final ok = await widget.engagementService.deleteComment(comment);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not delete comment')),
      );
    }
  }

  Future<void> _post() async {
    if (!VisitorAuth.isVisitorLoggedIn) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in to interact with posts.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final text = _textController.text.trim();
    if (text.isEmpty && _mediaBytes == null) return;

    setState(() => _posting = true);
    final ok = await widget.engagementService.addComment(
      item: widget.item,
      text: text,
      mediaBytes: _mediaBytes,
      mediaFileName: _mediaFileName,
      mediaMimeType: _mediaMimeType,
    );
    if (!mounted) return;
    setState(() => _posting = false);
    if (ok) {
      _textController.clear();
      _clearMedia();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not post comment')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppPalette.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Comments',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppPalette.charcoal,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: StreamBuilder<List<PostComment>>(
                  stream: widget.engagementService.commentsForPost(
                    item: widget.item,
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        !snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: AppPalette.ochre,
                        ),
                      );
                    }
                    final comments = snapshot.data ?? const [];
                    if (comments.isEmpty) {
                      return Center(
                        child: Text(
                          'No comments yet. Be the first to reply!',
                          style: TextStyle(color: AppPalette.mutedText),
                        ),
                      );
                    }
                    return ListView.separated(
                      controller: scrollController,
                      itemCount: comments.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        final comment = comments[index];
                        final isOwnComment = comment.visitorId ==
                            FirebaseAuth.instance.currentUser?.uid;
                        return _CommentTile(
                          comment: comment,
                          onDelete: isOwnComment
                              ? () => _confirmDeleteComment(comment)
                              : null,
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              if (_mediaBytes != null) _buildMediaPreview(),
              if (_mediaBytes != null) const SizedBox(height: 10),
              Row(
                children: [
                  IconButton(
                    tooltip: 'Add photo',
                    onPressed: _posting ? null : _pickImage,
                    icon: const Icon(
                      Icons.image_rounded,
                      color: AppPalette.ochre,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Add video',
                    onPressed: _posting ? null : _pickVideo,
                    icon: const Icon(
                      Icons.videocam_rounded,
                      color: AppPalette.ochre,
                    ),
                  ),
                  const Spacer(),
                ],
              ),
              TextField(
                controller: _textController,
                maxLines: 4,
                minLines: 1,
                maxLength: 500,
                decoration: InputDecoration(
                  hintText: 'Share your thoughts...',
                  hintStyle: TextStyle(color: AppPalette.mutedText),
                  filled: true,
                  fillColor: AppPalette.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppPalette.ochre,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _posting ? null : _post,
                  child: _posting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Post'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMediaPreview() {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: _isVideo
              ? Container(
                  width: double.infinity,
                  height: 120,
                  color: AppPalette.charcoal,
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.play_circle_fill_rounded,
                          color: Colors.white, size: 32),
                      const SizedBox(height: 4),
                      Text(
                        _mediaFileName ?? 'Video attached',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                )
              : Image.memory(
                  _mediaBytes!,
                  width: double.infinity,
                  height: 120,
                  fit: BoxFit.cover,
                ),
        ),
        Positioned(
          top: 6,
          right: 6,
          child: Material(
            color: Colors.black.withValues(alpha: 0.6),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _clearMedia,
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.close_rounded, size: 16, color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A single comment row, including its optional attached photo or video.
class _CommentTile extends StatelessWidget {
  final PostComment comment;
  final VoidCallback? onDelete;

  const _CommentTile({required this.comment, this.onDelete});

  String _formatTimestamp(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 365) return DateFormat.MMMd().format(date);
    return DateFormat.yMMMd().format(date);
  }

  Future<void> _openVideo() async {
    final url = comment.mediaUrl;
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final hasMedia = (comment.mediaUrl ?? '').isNotEmpty;
    final isVideo = comment.mediaType == 'video';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: AppPalette.ochre.withValues(alpha: 0.15),
          child: Text(
            comment.visitorName.isNotEmpty
                ? comment.visitorName[0].toUpperCase()
                : '?',
            style: const TextStyle(
              color: AppPalette.ochre,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      comment.visitorName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppPalette.charcoal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    _formatTimestamp(comment.createdAt),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppPalette.mutedText,
                    ),
                  ),
                  if (onDelete != null) ...[
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: onDelete,
                      borderRadius: BorderRadius.circular(12),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(
                          Icons.delete_outline_rounded,
                          size: 16,
                          color: AppPalette.mutedText,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (comment.text.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  comment.text,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppPalette.charcoal,
                    height: 1.35,
                  ),
                ),
              ],
              if (hasMedia) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: isVideo
                      ? GestureDetector(
                          onTap: _openVideo,
                          child: Container(
                            width: 160,
                            height: 100,
                            color: AppPalette.charcoal,
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.play_circle_fill_rounded,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                        )
                      : Image.network(
                          comment.mediaUrl!,
                          width: 160,
                          height: 100,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 160,
                            height: 100,
                            color: AppPalette.surfaceAlt,
                            child: const Icon(Icons.broken_image_rounded,
                                color: AppPalette.mutedText),
                          ),
                        ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _EngagementPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final Color? activeColor;

  const _EngagementPill({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        active ? (activeColor ?? AppPalette.ochre) : AppPalette.mutedText;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: active
                ? (activeColor ?? AppPalette.ochre).withValues(alpha: 0.08)
                : AppPalette.background,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: active
                  ? color.withValues(alpha: 0.3)
                  : AppPalette.border.withValues(alpha: 0.6),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BuzzVoteButton extends StatelessWidget {
  final bool active;
  final int count;
  final VoidCallback onTap;

  const _BuzzVoteButton({
    required this.active,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Always rendered with the brand orange/gold gradient so Buzz Vote reads
    // as BrisConnect's signature engagement action across every post.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF6B2B), Color(0xFFF59E0B)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppPalette.ochre
                        .withValues(alpha: active ? 0.45 : 0.25),
                    blurRadius: active ? 14 : 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    active ? Icons.flash_on_rounded : Icons.flash_on_outlined,
                    size: 16,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 5),
                  const Text(
                    'Buzz',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        // Small signature count badge so Buzz Vote is recognisable at a
        // glance, independent of the main pill's active/inactive state.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppPalette.ochre, width: 1.4),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppPalette.ochre,
            ),
          ),
        ),
      ],
    );
  }
}
