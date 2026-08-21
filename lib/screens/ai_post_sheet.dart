import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:brisconnect/auth/local_auth.dart';
import 'package:brisconnect/models/ai_generated_post.dart';
import 'package:brisconnect/services/ai_post_service.dart';
import 'package:brisconnect/services/ai_post_storage_service.dart';
import 'package:brisconnect/services/business_profile_service.dart';
import 'package:brisconnect/services/firebase_media_service.dart';
import 'package:brisconnect/services/google_places_autocomplete_service.dart';
import 'package:brisconnect/theme/app_palette.dart';

/// Bottom sheet for AI-powered social media post generation.
class AiPostSheet extends StatefulWidget {
  final AiPostType initialType;
  const AiPostSheet({super.key, this.initialType = AiPostType.businessEvent});

  @override
  State<AiPostSheet> createState() => _AiPostSheetState();
}

class _AiPostSheetState extends State<AiPostSheet> {
  static const _postTypes = [
    AiPostType.businessEvent,
    AiPostType.promotion,
    AiPostType.menuItem,
    AiPostType.announcement,
    AiPostType.reviewHighlight,
  ];

  late AiPostType _selectedType;

  final _titleCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _discountCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _locationFocusNode = FocusNode();
  DateTime? _eventDate;

  final _placesService = GooglePlacesAutocompleteService();

  final _generatedCtrl = TextEditingController();
  String? _generatedPost;
  bool _generating = false;
  bool _saving = false;
  bool _uploadingImage = false;
  String? _error;
  String? _successMessage;
  XFile? _selectedImage;
  Uint8List? _selectedImageBytes;
  String? _uploadedImageUrl;

  final _picker = ImagePicker();
  final _mediaService = FirebaseMediaService();

  String _businessId = '';
  String _businessName = '';
  String _category = '';
  String _ownerId = '';

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType;
    _ownerId = LocalAuth.currentLocal?.email ?? '';
    _loadBusiness();
  }

  Widget _buildRecentPostsPreview() {
    if (_ownerId.isEmpty) return const SizedBox.shrink();
    return StreamBuilder<List<AiGeneratedPost>>(
      stream: AiPostStorageService().getPostsForOwner(_ownerId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const SizedBox.shrink();
        }
        final posts = snap.data ?? [];
        if (posts.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Your generated posts',
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            ...posts.take(3).map((post) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A3E),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppPalette.ochre.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            post.postType.displayName,
                            style: const TextStyle(
                                color: AppPalette.ochre, fontSize: 10),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          post.status == AiPostStatus.published
                              ? 'Published'
                              : 'Draft',
                          style: TextStyle(
                            color: post.status == AiPostStatus.published
                                ? const Color(0xFF2ECC71)
                                : const Color(0xFF8B8FA8),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (post.imageUrl != null && post.imageUrl!.isNotEmpty) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          post.imageUrl!,
                          height: 120,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Text(
                      post.generatedContent,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Future<void> _loadBusiness() async {
    if (_ownerId.isEmpty) return;
    try {
      final list =
          await BusinessProfileService().getUserBusinessProfiles(_ownerId);
      if (list.isNotEmpty && mounted) {
        setState(() {
          _businessId = list.first.id ?? '';
          _businessName = list.first.businessName;
          _category = list.first.category;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descriptionCtrl.dispose();
    _priceCtrl.dispose();
    _discountCtrl.dispose();
    _locationCtrl.dispose();
    _locationFocusNode.dispose();
    _generatedCtrl.dispose();
    super.dispose();
  }

  String get _extraContext {
    final parts = <String>[
      if (_titleCtrl.text.trim().isNotEmpty) 'Title: ${_titleCtrl.text.trim()}',
      if (_descriptionCtrl.text.trim().isNotEmpty)
        'Description: ${_descriptionCtrl.text.trim()}',
      if (_priceCtrl.text.trim().isNotEmpty) 'Price: ${_priceCtrl.text.trim()}',
      if (_discountCtrl.text.trim().isNotEmpty)
        'Discount: ${_discountCtrl.text.trim()}',
      if (_eventDate != null)
        'Date: ${_eventDate!.day}/${_eventDate!.month}/${_eventDate!.year}',
      if (_locationCtrl.text.trim().isNotEmpty)
        'Location: ${_locationCtrl.text.trim()}',
    ];
    return parts.join('\n');
  }

  Future<void> _generate() async {
    if (_businessName.isEmpty) {
      setState(() => _error =
          'Complete your Business Profile first so AI knows your business name.');
      return;
    }
    if (_titleCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Please enter a title or name for the post.');
      return;
    }
    setState(() {
      _generating = true;
      _error = null;
      _successMessage = null;
      _generatedPost = null;
      _generatedCtrl.clear();
    });
    try {
      final post = await AiPostService().generatePost(
        postType: _selectedType.displayName,
        businessName: _businessName,
        category: _category,
        extraContext: _extraContext,
      );
      setState(() {
        _generatedPost = post;
        _generatedCtrl.text = post;
      });
    } catch (e) {
      String msg;
      if (e is FirebaseFunctionsException) {
        msg = e.message ?? 'AI service error (${e.code}). Please try again.';
      } else {
        msg = e.toString().replaceFirst('Exception: ', '');
      }
      setState(() => _error = msg);
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  AiGeneratedPost get _currentPost {
    final now = DateTime.now();
    return AiGeneratedPost(
      businessId: _businessId,
      businessName: _businessName,
      ownerId: _ownerId,
      postType: _selectedType,
      title: _titleCtrl.text.trim(),
      description: _descriptionCtrl.text.trim(),
      price: _priceCtrl.text.trim().isNotEmpty ? _priceCtrl.text.trim() : null,
      discount: _discountCtrl.text.trim().isNotEmpty
          ? _discountCtrl.text.trim()
          : null,
      eventDate: _eventDate,
      location: _locationCtrl.text.trim().isNotEmpty
          ? _locationCtrl.text.trim()
          : null,
      generatedContent: _generatedCtrl.text.trim(),
      imageUrl: _uploadedImageUrl,
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<void> _pickImage() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1200,
      );
      if (picked == null) return;

      // Read bytes via XFile so this works on both mobile and web.
      final bytes = await picked.readAsBytes();
      if (bytes.isEmpty) {
        setState(() => _error = 'Selected image is empty.');
        return;
      }

      setState(() {
        _selectedImage = picked;
        _selectedImageBytes = bytes;
        _uploadedImageUrl = null;
      });
      await _uploadImage(bytes);
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Could not pick image: $e');
      }
    }
  }

  Future<void> _uploadImage(Uint8List bytes) async {
    if (bytes.isEmpty) return;

    setState(() {
      _uploadingImage = true;
      _uploadedImageUrl = null;
      _error = null;
    });
    try {
      final ext = _inferImageExtension(bytes, fileName: _selectedImage?.name);
      final contentType = ext == 'png' ? 'image/png' : 'image/jpeg';
      final path =
          'ai_post_images/$_ownerId/${DateTime.now().millisecondsSinceEpoch}.$ext';
      debugPrint(
          '[AiPostSheet] uploading image to $path (${bytes.length} bytes)');
      final url = await _mediaService.uploadBytes(
        path: path,
        bytes: bytes,
        contentType: contentType,
      );
      debugPrint('[AiPostSheet] uploaded image url: $url');
      if (mounted) {
        setState(() => _uploadedImageUrl = url);
      }
    } catch (e) {
      debugPrint('[AiPostSheet] image upload failed: $e');
      if (mounted) {
        setState(() {
          _error = 'Image upload failed: $e';
          _selectedImage = null;
          _selectedImageBytes = null;
          _uploadedImageUrl = null;
        });
      }
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  String _inferImageExtension(Uint8List bytes, {String? fileName}) {
    final lowerName = (fileName ?? '').toLowerCase();
    if (lowerName.endsWith('.png')) return 'png';
    if (lowerName.endsWith('.jpg') || lowerName.endsWith('.jpeg')) return 'jpg';
    // Simple PNG magic number fallback.
    if (bytes.length > 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'png';
    }
    return 'jpg';
  }

  Future<void> _saveDraft() async {
    if (_generatedCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Generate or enter a post before saving.');
      return;
    }
    await _persist(
        () => AiPostStorageService().saveDraft(_currentPost), 'Draft saved');
  }

  Future<void> _publish() async {
    if (_generatedCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Generate or enter a post before publishing.');
      return;
    }
    if (_selectedImageBytes != null &&
        (_uploadedImageUrl == null || _uploadedImageUrl!.isEmpty)) {
      setState(
          () => _error = 'Image is still uploading. Please wait or remove it.');
      return;
    }
    await _persist(
        () => AiPostStorageService().publish(_currentPost), 'Post published');
  }

  Future<void> _persist(
      Future<String> Function() action, String success) async {
    setState(() {
      _saving = true;
      _error = null;
      _successMessage = null;
    });
    try {
      await action();
      if (mounted) {
        setState(() => _successMessage = '✓ $success');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _copy() {
    final text = _generatedCtrl.text.trim();
    if (text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✓ Copied to clipboard'),
        backgroundColor: AppPalette.ochre,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1C1C2E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 16),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppPalette.ochre.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.auto_awesome_rounded,
                      color: AppPalette.ochre, size: 20),
                ),
                const SizedBox(width: 10),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('AI Post Creator',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold)),
                    Text('Generate a post in seconds',
                        style:
                            TextStyle(color: Color(0xFF8B8FA8), fontSize: 12)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Generated posts preview
            _buildRecentPostsPreview(),
            const SizedBox(height: 20),

            // Business info chip
            if (_businessName.isNotEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A3E),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.storefront_rounded,
                        color: AppPalette.ochre, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('$_businessName · $_category',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13)),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),

            // Post type selector
            const Text('Post Type',
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _postTypes.map((type) {
                final selected = type == _selectedType;
                return GestureDetector(
                  onTap: () => setState(() {
                    _selectedType = type;
                    _generatedPost = null;
                    _generatedCtrl.clear();
                    _error = null;
                    _successMessage = null;
                  }),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color:
                          selected ? AppPalette.ochre : const Color(0xFF2A2A3E),
                      borderRadius: BorderRadius.circular(20),
                      border: selected
                          ? null
                          : Border.all(
                              color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: Text(type.displayName,
                        style: TextStyle(
                            color: selected
                                ? Colors.white
                                : const Color(0xFF8B8FA8),
                            fontSize: 12,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.normal)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Structured input form
            _buildTextField(
              controller: _titleCtrl,
              label: _titleLabel,
              hint: _titleHint,
              maxLines: 1,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _descriptionCtrl,
              label: 'Description',
              hint: 'Add a short description or notes for the AI',
              maxLines: 3,
            ),
            if (_selectedType == AiPostType.promotion ||
                _selectedType == AiPostType.menuItem) ...[
              const SizedBox(height: 12),
              _buildTextField(
                controller: _priceCtrl,
                label: 'Price (optional)',
                hint: r'e.g. $24 or $15 per person',
                maxLines: 1,
              ),
            ],
            if (_selectedType == AiPostType.promotion) ...[
              const SizedBox(height: 12),
              _buildTextField(
                controller: _discountCtrl,
                label: 'Discount (optional)',
                hint: 'e.g. 20% off or buy-one-get-one-free',
                maxLines: 1,
              ),
            ],
            if (_selectedType == AiPostType.businessEvent) ...[
              const SizedBox(height: 12),
              _buildDatePicker(),
              const SizedBox(height: 12),
              _buildAddressAutocompleteField(),
            ],
            const SizedBox(height: 16),

            // Image picker
            _buildImagePicker(),
            const SizedBox(height: 16),

            // Generate button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _generating || _saving ? null : _generate,
                icon: _generating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.auto_awesome_rounded, size: 18),
                label: Text(_generating ? 'Generating…' : 'Generate Post',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppPalette.ochre,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),

            // Error
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: Colors.redAccent.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: Colors.redAccent, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_error!,
                          style: const TextStyle(
                              color: Colors.redAccent, fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ],

            // Success
            if (_successMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: Colors.green.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline_rounded,
                        color: Colors.green, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_successMessage!,
                          style: const TextStyle(
                              color: Colors.green, fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ],

            // Generated post
            if (_generatedPost != null) ...[
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Generated Post',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold)),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: _generating || _saving ? null : _generate,
                        icon: const Icon(Icons.refresh_rounded, size: 14),
                        label: const Text('Regenerate',
                            style: TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF8B8FA8),
                            padding: const EdgeInsets.symmetric(horizontal: 8)),
                      ),
                      const SizedBox(width: 4),
                      ElevatedButton.icon(
                        onPressed: _copy,
                        icon: const Icon(Icons.copy_rounded, size: 14),
                        label: const Text('Copy',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppPalette.ochre,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _generatedCtrl,
                maxLines: 8,
                style: const TextStyle(
                    color: Colors.white, fontSize: 14, height: 1.55),
                decoration: InputDecoration(
                  hintText: 'Edit your generated post here...',
                  hintStyle:
                      const TextStyle(color: Color(0xFF8B8FA8), fontSize: 13),
                  filled: true,
                  fillColor: const Color(0xFF2A2A3E),
                  contentPadding: const EdgeInsets.all(16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        const BorderSide(color: AppPalette.ochre, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          (_saving || _uploadingImage) ? null : _saveDraft,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF8B8FA8),
                        side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.15)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Color(0xFF8B8FA8)))
                          : const Text('Save Draft'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: (_saving || _uploadingImage) ? null : _publish,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppPalette.ochre,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Publish'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String get _titleLabel {
    switch (_selectedType) {
      case AiPostType.menuItem:
        return 'Menu Item Name';
      case AiPostType.businessEvent:
        return 'Event Title';
      case AiPostType.promotion:
      case AiPostType.announcement:
      case AiPostType.reviewHighlight:
        return 'Title';
    }
  }

  String get _titleHint {
    switch (_selectedType) {
      case AiPostType.menuItem:
        return 'e.g. Truffle Mushroom Risotto';
      case AiPostType.businessEvent:
        return 'e.g. Friday Night Live Music';
      case AiPostType.promotion:
        return 'e.g. Midweek Special';
      case AiPostType.announcement:
        return 'e.g. New Opening Hours';
      case AiPostType.reviewHighlight:
        return 'e.g. Customer Favourite';
    }
  }

  Widget _buildImagePicker() {
    final hasUploadedImage =
        _uploadedImageUrl != null && _uploadedImageUrl!.isNotEmpty;
    final hasLocalImage = _selectedImageBytes != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Image (optional)',
            style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _uploadingImage ? null : _pickImage,
          child: Container(
            height: 160,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A3E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              image: hasUploadedImage
                  ? DecorationImage(
                      image: NetworkImage(_uploadedImageUrl!),
                      fit: BoxFit.cover,
                    )
                  : hasLocalImage
                      ? DecorationImage(
                          image: MemoryImage(_selectedImageBytes!),
                          fit: BoxFit.cover,
                        )
                      : null,
            ),
            child: (hasUploadedImage || hasLocalImage)
                ? Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.close_rounded,
                              color: Colors.white, size: 18),
                          onPressed: _uploadingImage
                              ? null
                              : () => setState(() {
                                    _selectedImage = null;
                                    _selectedImageBytes = null;
                                    _uploadedImageUrl = null;
                                  }),
                          padding: EdgeInsets.zero,
                          constraints:
                              const BoxConstraints(minWidth: 32, minHeight: 32),
                        ),
                      ),
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _uploadingImage
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppPalette.ochre))
                          : const Icon(Icons.add_photo_alternate_rounded,
                              color: Color(0xFF8B8FA8), size: 32),
                      const SizedBox(height: 8),
                      Text(
                        _uploadingImage ? 'Uploading…' : 'Tap to add an image',
                        style: const TextStyle(
                            color: Color(0xFF8B8FA8), fontSize: 12),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Future<Iterable<String>> _getAddressSuggestions(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return const <String>[];
    try {
      return await _placesService.fetchBrisbaneAddressSuggestions(trimmed);
    } catch (_) {
      return const <String>[];
    }
  }

  Widget _buildAddressAutocompleteField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Location (optional)',
            style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        RawAutocomplete<String>(
          textEditingController: _locationCtrl,
          focusNode: _locationFocusNode,
          optionsBuilder: (value) => _getAddressSuggestions(value.text),
          onSelected: (selection) {
            _locationCtrl.text = selection;
          },
          fieldViewBuilder: (
            context,
            textEditingController,
            focusNode,
            onFieldSubmitted,
          ) {
            return TextField(
              controller: textEditingController,
              focusNode: focusNode,
              maxLines: 1,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'e.g. 123 Queen St, Brisbane',
                hintStyle:
                    const TextStyle(color: Color(0xFF8B8FA8), fontSize: 12),
                filled: true,
                fillColor: const Color(0xFF2A2A3E),
                contentPadding: const EdgeInsets.all(12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppPalette.ochre),
                ),
              ),
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(10),
                color: const Color(0xFF2A2A3E),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width - 64,
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: options.length,
                      itemBuilder: (context, index) {
                        final option = options.elementAt(index);
                        return ListTile(
                          dense: true,
                          leading: const Icon(
                            Icons.location_on_rounded,
                            color: AppPalette.ochre,
                            size: 18,
                          ),
                          title: Text(
                            option,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13),
                          ),
                          onTap: () => onSelected(option),
                        );
                      },
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required int maxLines,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF8B8FA8), fontSize: 12),
            filled: true,
            fillColor: const Color(0xFF2A2A3E),
            contentPadding: const EdgeInsets.all(12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppPalette.ochre),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDatePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Event Date (optional)',
            style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _eventDate ?? DateTime.now(),
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (picked != null) {
              setState(() => _eventDate = picked);
            }
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A3E),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_rounded,
                    color: AppPalette.ochre, size: 16),
                const SizedBox(width: 10),
                Text(
                  _eventDate == null
                      ? 'Tap to select a date'
                      : '${_eventDate!.day}/${_eventDate!.month}/${_eventDate!.year}',
                  style: TextStyle(
                    color: _eventDate == null
                        ? const Color(0xFF8B8FA8)
                        : Colors.white,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
