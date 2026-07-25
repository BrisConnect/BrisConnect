import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:brisconnect/services/visitor_photo_service.dart';
import 'package:brisconnect/theme/app_palette.dart';

/// Bottom sheet that lets a Visitor pick a photo, add a caption, and upload it
/// for a business or event.
class VisitorPhotoUploadSheet extends StatefulWidget {
  final String? businessId;
  final String? eventId;
  final String visitorName;
  final VisitorPhotoService service;

  const VisitorPhotoUploadSheet({
    super.key,
    this.businessId,
    this.eventId,
    required this.visitorName,
    required this.service,
  });

  @override
  State<VisitorPhotoUploadSheet> createState() =>
      _VisitorPhotoUploadSheetState();
}

class _VisitorPhotoUploadSheetState extends State<VisitorPhotoUploadSheet> {
  final _captionController = TextEditingController();
  PickedImage? _pickedImage;
  bool _picking = false;
  bool _uploading = false;
  String? _error;

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      final picked = await widget.service.pickImage();
      if (mounted) {
        setState(() {
          _pickedImage = picked;
          _picking = false;
        });
      }
    } on FormatException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _picking = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _picking = false;
        });
      }
    }
  }

  Future<void> _upload() async {
    if (_pickedImage == null) return;

    setState(() {
      _uploading = true;
      _error = null;
    });

    try {
      await widget.service.uploadPhoto(
        bytes: _pickedImage!.bytes,
        fileName: _pickedImage!.fileName,
        mimeType: _pickedImage!.mimeType,
        businessId: widget.businessId,
        eventId: widget.eventId,
        caption: _captionController.text,
        visitorName: widget.visitorName,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo submitted for review.'),
            backgroundColor: AppPalette.ochre,
          ),
        );
      }
    } on FormatException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _uploading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _uploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      decoration: const BoxDecoration(
        color: AppPalette.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Share a photo',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppPalette.charcoal,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _picking || _uploading ? null : _pickImage,
              child: Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppPalette.surfaceAlt,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppPalette.border),
                  image: _pickedImage != null
                      ? DecorationImage(
                          image: MemoryImage(_pickedImage!.bytes),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: _pickedImage == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_picking)
                            const CircularProgressIndicator()
                          else ...[
                            const Icon(
                              Icons.add_photo_alternate_rounded,
                              size: 48,
                              color: AppPalette.ochre,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Tap to choose a photo',
                              style: TextStyle(color: AppPalette.charcoal),
                            ),
                          ],
                        ],
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _captionController,
              enabled: !_uploading,
              maxLength: VisitorPhotoService.maxCaptionLength,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Caption (optional)',
                hintText: 'What makes this place special?',
                border: OutlineInputBorder(),
                counterStyle: TextStyle(color: AppPalette.mutedText),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _pickedImage == null || _uploading ? null : _upload,
                icon: _uploading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.upload_rounded),
                label: Text(_uploading ? 'Uploading...' : 'Upload Photo'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppPalette.ochre,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                'Photos are reviewed before they appear publicly.',
                style: TextStyle(
                  color: AppPalette.mutedText,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
