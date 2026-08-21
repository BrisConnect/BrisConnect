import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:brisconnect/auth/visitor_auth.dart';
import 'package:brisconnect/models/visitor_photo.dart';
import 'package:brisconnect/services/photo_report_service.dart';
import 'package:brisconnect/services/visitor_photo_service.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/widgets/visitor_photo_upload_sheet.dart';

/// Displays a gallery of visitor-contributed photos for a business or event,
/// with an action to upload a new photo when the current user is signed in.
class VisitorPhotoGalleryWidget extends StatelessWidget {
  final String? businessId;
  final String? eventId;
  final String title;
  final VisitorPhotoService? service;

  const VisitorPhotoGalleryWidget({
    super.key,
    this.businessId,
    this.eventId,
    this.title = 'Visitor Photos',
    this.service,
  });

  @override
  Widget build(BuildContext context) {
    final hasBusiness = businessId != null && businessId!.isNotEmpty;
    final hasEvent = eventId != null && eventId!.isNotEmpty;
    if (hasBusiness == hasEvent) {
      throw ArgumentError(
        'VisitorPhotoGalleryWidget requires either a non-empty businessId or eventId, not both.',
      );
    }

    final effectiveService = service ?? VisitorPhotoService();
    final stream = hasBusiness
        ? effectiveService.getApprovedPhotosForBusiness(businessId!)
        : effectiveService.getApprovedPhotosForEvent(eventId!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppPalette.charcoal,
                  ),
                ),
              ),
              _UploadButton(
                businessId: businessId,
                eventId: eventId,
                service: effectiveService,
              ),
            ],
          ),
        ),
        StreamBuilder<List<VisitorPhoto>>(
          stream: stream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final photos = snapshot.data ?? [];
            if (photos.isEmpty) {
              return _EmptyState(
                businessId: businessId,
                eventId: eventId,
                service: effectiveService,
              );
            }

            return SizedBox(
              height: 140,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: photos.length + 1,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  if (index == photos.length) {
                    return _AddTile(
                      businessId: businessId,
                      eventId: eventId,
                      service: effectiveService,
                    );
                  }
                  return _PhotoTile(photo: photos[index]);
                },
              ),
            );
          },
        ),
      ],
    );
  }
}

class _PhotoTile extends StatelessWidget {
  final VisitorPhoto photo;

  const _PhotoTile({required this.photo});

  Future<void> _showReportSheet(BuildContext context) async {
    final visitorEmail = VisitorAuth.currentVisitor?.email;
    if (visitorEmail == null || visitorEmail.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in as a Visitor to report a photo.')),
      );
      return;
    }

    final reason = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('Report this photo',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            for (final reason in PhotoReportService.reportReasons)
              ListTile(
                title: Text(PhotoReportService.getReasonLabel(reason)),
                onTap: () => Navigator.pop(ctx, reason),
              ),
          ],
        ),
      ),
    );
    if (reason == null) return;

    final submitted = await PhotoReportService().submitReport(
      photoId: photo.id,
      visitorEmail: visitorEmail,
      reason: reason,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(submitted
            ? 'Report submitted. Thank you for helping keep our community safe.'
            : 'Could not submit report. Please try again.'),
        backgroundColor: submitted ? Colors.green : Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        children: [
          CachedNetworkImage(
            imageUrl: photo.imageUrl,
            width: 140,
            height: 140,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(
              width: 140,
              height: 140,
              color: AppPalette.surfaceAlt,
              child: const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            errorWidget: (_, __, ___) => Container(
              width: 140,
              height: 140,
              color: AppPalette.surfaceAlt,
              child: const Icon(Icons.broken_image_rounded,
                  color: AppPalette.mutedText),
            ),
          ),
          if (photo.caption != null && photo.caption!.isNotEmpty)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.7),
                    ],
                  ),
                ),
                child: Text(
                  photo.caption!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: () => _showReportSheet(context),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.flag_outlined,
                    color: Colors.white, size: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  final String? businessId;
  final String? eventId;
  final VisitorPhotoService service;

  const _AddTile({
    this.businessId,
    this.eventId,
    required this.service,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openUpload(context),
      child: Container(
        width: 140,
        height: 140,
        decoration: BoxDecoration(
          color: AppPalette.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppPalette.border),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate_rounded,
                color: AppPalette.ochre, size: 32),
            SizedBox(height: 6),
            Text(
              'Add Photo',
              style: TextStyle(
                color: AppPalette.ochre,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openUpload(BuildContext context) {
    final visitor = VisitorAuth.currentVisitor;
    if (visitor == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in as a Visitor to upload photos.'),
        ),
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => VisitorPhotoUploadSheet(
        businessId: businessId,
        eventId: eventId,
        visitorName: visitor.name,
        service: service,
      ),
    );
  }
}

class _UploadButton extends StatelessWidget {
  final String? businessId;
  final String? eventId;
  final VisitorPhotoService service;

  const _UploadButton({
    this.businessId,
    this.eventId,
    required this.service,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () => _AddTile(
        businessId: businessId,
        eventId: eventId,
        service: service,
      )._openUpload(context),
      icon: const Icon(Icons.add_photo_alternate_rounded, size: 18),
      label: const Text('Add'),
      style: TextButton.styleFrom(foregroundColor: AppPalette.ochre),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String? businessId;
  final String? eventId;
  final VisitorPhotoService service;

  const _EmptyState({
    this.businessId,
    this.eventId,
    required this.service,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _AddTile(
        businessId: businessId,
        eventId: eventId,
        service: service,
      )._openUpload(context),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
        decoration: BoxDecoration(
          color: AppPalette.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppPalette.border),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate_rounded, color: AppPalette.ochre),
            SizedBox(width: 10),
            Text(
              'Be the first to share a photo',
              style: TextStyle(
                color: AppPalette.charcoal,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
