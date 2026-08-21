// ignore_for_file: deprecated_member_use

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:brisconnect/services/share/content_share_service.dart';
import 'package:brisconnect/services/share/social_story_service.dart';
import 'package:brisconnect/services/social_share_tracking_service.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/utils/image_download.dart';
import 'package:brisconnect/widgets/logo_app_bar_title.dart';

/// Layout style for a generated social story.
enum StoryLayout {
  gradient,
  photo,
  minimal,
  poster,
}

/// A full-screen preview where the user customises a story card before
/// sharing it to Instagram/Facebook/TikTok.
class StoryPreviewScreen extends StatefulWidget {
  const StoryPreviewScreen({
    super.key,
    required this.platform,
    required this.contentType,
    required this.id,
    required this.title,
    this.description,
    this.location,
    this.dateTime,
    this.imageUrl,
    this.businessId,
    this.businessName,
  });

  final StoryPlatform platform;
  final ShareContentType contentType;
  final String id;
  final String title;
  final String? description;
  final String? location;
  final String? dateTime;
  final String? imageUrl;
  final String? businessId;
  final String? businessName;

  @override
  State<StoryPreviewScreen> createState() => _StoryPreviewScreenState();
}

class _StoryPreviewScreenState extends State<StoryPreviewScreen> {
  final GlobalKey _captureKey = GlobalKey();
  final GlobalKey _editorKey = GlobalKey();
  final ContentShareService _shareService = ContentShareService();
  final SocialStoryService _storyService = SocialStoryService();
  final SocialShareTrackingService _trackingService =
      SocialShareTrackingService();
  final TextEditingController _captionController = TextEditingController();

  StoryLayout _layout = StoryLayout.poster;
  bool _isSharing = false;
  String? _qrData;
  Color _accentColor = const Color(0xFFE1306C);
  bool _showQr = true;

  static const List<Color> _accentColors = [
    Color(0xFFE1306C),
    Color(0xFF1877F2),
    Color(0xFF25F4EE),
    Color(0xFFFF6B2B),
    Color(0xFF8B5CF6),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFF1E293B),
  ];

  @override
  void initState() {
    super.initState();
    _qrData = _shareService.buildShareUrl(
      type: widget.contentType,
      id: widget.id,
      slug: widget.title,
    );
    _captionController.text = widget.description ?? '';
    _accentColor = _platformColor;
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.background,
      appBar: AppBar(
        title: LogoAppBarTitle(
          'Share to ${SocialStoryService.platformLabel(widget.platform)}',
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildAspectFrame(
                        child: RepaintBoundary(
                          key: _captureKey,
                          child: _StoryCard(
                            layout: _layout,
                            title: widget.title,
                            description: widget.description,
                            location: widget.location,
                            dateTime: widget.dateTime,
                            imageUrl: widget.imageUrl,
                            qrData: _showQr ? _qrData : null,
                            platform: widget.platform,
                            caption: _captionController.text,
                            accentColor: _accentColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildLayoutPicker(),
                      const SizedBox(height: 16),
                      _buildEditorCard(),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isSharing ? null : _share,
                      icon: _isSharing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.share_rounded),
                      label: Text(_isSharing
                          ? 'Preparing…'
                          : _primaryButtonLabel),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accentColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _primaryButtonHint,
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isSharing ? null : _saveToGallery,
                          icon: const Icon(Icons.download_rounded, size: 18),
                          label: const Text('Save Image'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppPalette.charcoal,
                            side: const BorderSide(color: AppPalette.border),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isSharing ? null : _openAppDirectly,
                          icon: const Icon(Icons.open_in_new_rounded, size: 18),
                          label: Text(
                              'Open ${SocialStoryService.platformLabel(widget.platform)}'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppPalette.charcoal,
                            side: const BorderSide(color: AppPalette.border),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color get _platformColor => switch (widget.platform) {
        StoryPlatform.instagram => const Color(0xFFE1306C),
        StoryPlatform.facebook => const Color(0xFF1877F2),
        StoryPlatform.tiktok => const Color(0xFF010101),
      };

  String get _primaryButtonLabel {
    if (!kIsWeb) return 'Share Story';
    return _storyService.canShareFilesDirectly
        ? 'Share Story'
        : 'Save & Open ${SocialStoryService.platformLabel(widget.platform)}';
  }

  String get _primaryButtonHint {
    if (!kIsWeb) {
      return 'Opens the ${SocialStoryService.platformLabel(widget.platform)} story composer with this image.';
    }
    if (_storyService.canShareFilesDirectly) {
      return 'Your browser will open the share sheet with the story image.';
    }
    return 'Desktop browsers cannot post directly to ${SocialStoryService.platformLabel(widget.platform)}. The image will be saved and the upload page opened.';
  }

  Widget _buildAspectFrame({required Widget child}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : MediaQuery.of(context).size.height * 0.65;
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width - 32;
        final height = width * 16 / 9;
        final targetHeight = height > maxHeight ? maxHeight : height;
        final targetWidth = targetHeight * 9 / 16;

        // Avoid zero-sized render target and enforce a 9:16 ratio.
        if (targetWidth <= 0 || targetHeight <= 0) {
          return const SizedBox.shrink();
        }

        return Container(
          width: targetWidth,
          height: targetHeight,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: child,
        );
      },
    );
  }

  Widget _buildLayoutPicker() {
    final options = [
      (StoryLayout.poster, 'Poster', Icons.auto_awesome_rounded),
      (StoryLayout.gradient, 'Gradient', Icons.gradient_rounded),
      (StoryLayout.photo, 'Photo', Icons.image_rounded),
      (StoryLayout.minimal, 'Minimal', Icons.format_align_left_rounded),
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.center,
      children: options.map((option) {
        final selected = _layout == option.$1;
        return ChoiceChip(
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(option.$3, size: 16),
              const SizedBox(width: 6),
              Text(option.$2),
            ],
          ),
          selected: selected,
          selectedColor: _accentColor.withValues(alpha: 0.18),
          labelStyle: TextStyle(
            color: selected ? _accentColor : AppPalette.charcoal,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
          ),
          side: BorderSide(
            color: selected ? _accentColor : AppPalette.border,
          ),
          onSelected: (_) => setState(() => _layout = option.$1),
        );
      }).toList(),
    );
  }

  Widget _buildEditorCard() {
    return Container(
      key: _editorKey,
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppPalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Edit Story',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppPalette.charcoal,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _captionController,
            onChanged: (_) => setState(() {}),
            maxLines: 3,
            maxLength: 160,
            decoration: InputDecoration(
              labelText: 'Caption',
              hintText: 'Write something about this…',
              filled: true,
              fillColor: AppPalette.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              counterStyle: const TextStyle(fontSize: 11),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                'Accent colour',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppPalette.charcoal,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Toggle QR code',
                onPressed: () => setState(() => _showQr = !_showQr),
                icon: Icon(
                  _showQr ? Icons.qr_code_rounded : Icons.qr_code_2_outlined,
                  color: _showQr ? _accentColor : AppPalette.mutedText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _accentColors.map((color) {
              final selected = _accentColor == color;
              return GestureDetector(
                onTap: () => setState(() => _accentColor = color),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color:
                          selected ? AppPalette.charcoal : Colors.transparent,
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Future<void> _share() async {
    setState(() => _isSharing = true);
    try {
      final bytes = await _renderStoryImage();
      if (bytes == null) {
        _showError('Could not render story image.');
        return;
      }

      // On web pass the rendered bytes directly; on mobile write a temp file
      // for native share intents.
      final file = kIsWeb ? null : await _writeTempFile(bytes);
      final editedCaption = _captionController.text.trim();
      final result = await _storyService.shareToStory(
        platform: widget.platform,
        contentType: widget.contentType,
        id: widget.id,
        title: widget.title,
        description:
            editedCaption.isNotEmpty ? editedCaption : widget.description,
        location: widget.location,
        dateTime: widget.dateTime,
        imageUrl: null,
        mediaFileParam: file,
        mediaBytesParam: kIsWeb ? bytes : null,
      );

      debugPrint('[StoryPreview] share result: $result');

      // Record the share attempt against the business for the vendor dashboard.
      if (result == StoryShareResult.shared ||
          result == StoryShareResult.nativeShareFallback ||
          result == StoryShareResult.copied) {
        await _trackingService.recordShare(
          businessId: widget.businessId ?? widget.id,
          businessName: widget.businessName,
          contentId: widget.id,
          contentType: widget.contentType,
          platform: widget.platform.name,
          shareKind: 'story',
          title: widget.title,
          description: widget.description,
          imageUrl: widget.imageUrl,
          shareUrl: _shareService.buildShareUrl(
            type: widget.contentType,
            id: widget.id,
            slug: widget.title,
          ),
        );
      }

      if (!mounted) return;

      final platformName = SocialStoryService.platformLabel(widget.platform);
      final messenger = ScaffoldMessenger.of(context);
      switch (result) {
        case StoryShareResult.shared:
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                kIsWeb
                    ? 'Choose $platformName from your browser\'s share sheet to post the image.'
                    : 'Opening $platformName… paste the copied link as a sticker if needed.',
              ),
              backgroundColor: _platformColor,
            ),
          );
        case StoryShareResult.nativeShareFallback:
          final fallbackMessage = widget.platform == StoryPlatform.tiktok
              ? 'Choose TikTok from the share sheet and paste the copied link.'
              : 'Choose $platformName from the share sheet.';
          messenger.showSnackBar(
            SnackBar(
              content: Text(fallbackMessage),
              backgroundColor: _platformColor,
            ),
          );
        case StoryShareResult.copied:
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                kIsWeb
                    ? 'Story image downloaded. Upload it to $platformName and paste the copied link.'
                    : 'Link copied! Open the app and paste it into your story.',
              ),
            ),
          );
        case StoryShareResult.appNotInstalled:
          messenger.showSnackBar(
            SnackBar(
              content: Text('$platformName is not installed.'),
              backgroundColor: Colors.red.shade700,
            ),
          );
        case StoryShareResult.noMediaSelected:
        case StoryShareResult.cancelled:
          // No-op.
          break;
        case StoryShareResult.failed:
          _showError('Could not share. The link was copied to your clipboard.');
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  Future<void> _saveToGallery() async {
    setState(() => _isSharing = true);
    try {
      final bytes = await _renderStoryImage();
      if (bytes == null) {
        _showError('Could not render story image.');
        return;
      }

      if (kIsWeb) {
        final safeName = _sanitisedFileName(widget.title);
        await downloadImage(
          bytes,
          'brisconnect_story_$safeName.png',
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Story image downloaded.'),
          ),
        );
        return;
      }

      if (Platform.isAndroid) {
        final status = await Permission.storage.request();
        if (!status.isGranted && !status.isLimited) {
          _showError('Storage permission is needed to save the image.');
          return;
        }
      }

      final file = await _writeTempFile(bytes);
      await Gal.putImage(file.path);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Story image saved to gallery. You can now post it manually.'),
        ),
      );
    } on GalException catch (e) {
      debugPrint('[StoryPreview] save error: ${e.type}');
      _showError('Could not save image. Check storage permission.');
    } catch (e) {
      debugPrint('[StoryPreview] save error: $e');
      _showError('Could not save image.');
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  Future<void> _openAppDirectly() async {
    if (kIsWeb) {
      final webUrl = switch (widget.platform) {
        StoryPlatform.instagram => 'https://www.instagram.com/',
        StoryPlatform.facebook => 'https://www.facebook.com/',
        StoryPlatform.tiktok => 'https://www.tiktok.com/',
      };
      final uri = Uri.parse(webUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showError(
            'Could not open ${SocialStoryService.platformLabel(widget.platform)}.');
      }
      return;
    }

    final scheme = switch (widget.platform) {
      StoryPlatform.instagram => 'instagram://',
      StoryPlatform.facebook => 'fb://',
      StoryPlatform.tiktok => 'tiktok://',
    };
    final uri = Uri.parse(scheme);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _showError(
          'Could not open ${SocialStoryService.platformLabel(widget.platform)}.');
    }
  }

  String _sanitisedFileName(String input) {
    return input
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }

  /// Renders the story card to a 1080x1920 PNG.
  ///
  /// Instagram/Facebook prefer a 9:16 aspect ratio. The preview widget is
  /// sized to a 9:16 ratio, so we render at a pixel ratio that yields
  /// exactly 1080px width. The resulting PNG is well under 4MB.
  Future<Uint8List?> _renderStoryImage() async {
    final boundary = _captureKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) return null;

    const targetWidth = 1080.0;
    final renderBox =
        _captureKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || renderBox.size.width == 0) return null;
    final pixelRatio = targetWidth / renderBox.size.width;

    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  Future<File> _writeTempFile(Uint8List bytes) async {
    final tempDir = await getTemporaryDirectory();
    final file = File(
      '${tempDir.path}/brisconnect_story_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
      ),
    );
  }
}

/// The visual story card rendered inside the RepaintBoundary.
class _StoryCard extends StatelessWidget {
  const _StoryCard({
    required this.layout,
    required this.title,
    this.description,
    this.location,
    this.dateTime,
    this.imageUrl,
    this.qrData,
    required this.platform,
    this.caption,
    this.accentColor,
  });

  final StoryLayout layout;
  final String title;
  final String? description;
  final String? location;
  final String? dateTime;
  final String? imageUrl;
  final String? qrData;
  final StoryPlatform platform;
  final String? caption;
  final Color? accentColor;

  Color get _accentColor =>
      accentColor ??
      switch (platform) {
        StoryPlatform.instagram => const Color(0xFFE1306C),
        StoryPlatform.facebook => const Color(0xFF1877F2),
        StoryPlatform.tiktok => const Color(0xFF25F4EE),
      };

  @override
  Widget build(BuildContext context) {
    return switch (layout) {
      StoryLayout.gradient => _buildGradientLayout(),
      StoryLayout.photo => _buildPhotoLayout(),
      StoryLayout.minimal => _buildMinimalLayout(),
      StoryLayout.poster => _buildPosterLayout(),
    };
  }

  String? get _captionOrDescription {
    final text = caption?.trim();
    if (text != null && text.isNotEmpty) return text;
    return description;
  }

  Widget _buildPosterLayout() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: AppPalette.charcoal,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _accentColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'BrisConnect+',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const Spacer(),
              if (qrData != null)
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: QrImageView(
                    data: qrData!,
                    size: 56,
                    padding: const EdgeInsets.all(2),
                    backgroundColor: Colors.white,
                    errorCorrectionLevel: QrErrorCorrectLevel.H,
                  ),
                ),
            ],
          ),
          const Spacer(),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          if (dateTime != null && dateTime!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              dateTime!,
              style: TextStyle(
                color: _accentColor,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (location != null && location!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '📍 $location',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const Spacer(),
          if (_captionOrDescription != null) ...[
            const SizedBox(height: 12),
            Text(
              _captionOrDescription!,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 15,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGradientLayout() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _accentColor,
            _accentColor.withBlue((_accentColor.blue + 60).clamp(0, 255)),
          ],
        ),
      ),
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'BrisConnect+',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          if (location != null && location!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              '📍 $location',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const Spacer(),
          if (_captionOrDescription != null) ...[
            const SizedBox(height: 10),
            Text(
              _captionOrDescription!,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (qrData != null)
            Align(
              alignment: Alignment.bottomLeft,
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: QrImageView(
                  data: qrData!,
                  size: 86,
                  padding: const EdgeInsets.all(3),
                  backgroundColor: Colors.white,
                  errorCorrectionLevel: QrErrorCorrectLevel.H,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPhotoLayout() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (imageUrl != null && imageUrl!.isNotEmpty)
            Image.network(
              imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            )
          else
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppPalette.charcoal,
                    AppPalette.charcoal.withValues(alpha: 0.8),
                  ],
                ),
              ),
            ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.3),
                  Colors.black.withValues(alpha: 0.75),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'BrisConnect+',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                if (dateTime != null && dateTime!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    dateTime!,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (location != null && location!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    '📍 $location',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (_captionOrDescription != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _captionOrDescription!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                if (qrData != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: QrImageView(
                        data: qrData!,
                        size: 86,
                        padding: const EdgeInsets.all(3),
                        backgroundColor: Colors.white,
                        errorCorrectionLevel: QrErrorCorrectLevel.H,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMinimalLayout() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'BrisConnect+',
            style: TextStyle(
              color: _accentColor,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          Text(
            title,
            style: const TextStyle(
              color: AppPalette.charcoal,
              fontSize: 34,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          if (_captionOrDescription != null) ...[
            const SizedBox(height: 12),
            Text(
              _captionOrDescription!,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppPalette.mutedText,
                fontSize: 16,
                height: 1.4,
              ),
            ),
          ],
          if (location != null && location!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              '📍 $location',
              style: const TextStyle(
                color: AppPalette.charcoal,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const Spacer(),
          if (qrData != null)
            Align(
              alignment: Alignment.bottomRight,
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: QrImageView(
                  data: qrData!,
                  size: 90,
                  padding: const EdgeInsets.all(3),
                  backgroundColor: Colors.white,
                  errorCorrectionLevel: QrErrorCorrectLevel.H,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
