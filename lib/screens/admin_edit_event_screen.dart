import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:brisconnect/auth/app_user_role.dart';
import 'package:brisconnect/models/event_item.dart';
import 'package:brisconnect/services/admin_event_service.dart';
import 'package:brisconnect/services/event_category_service.dart';
import 'package:brisconnect/services/firebase_media_service.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/utils/narration_builder.dart';
import 'package:brisconnect/widgets/logo_app_bar_title.dart';
import 'package:brisconnect/widgets/role_guard.dart';

class AdminEditEventScreen extends StatefulWidget {
  AdminEditEventScreen({
    super.key,
    required this.event,
    AdminEventService? eventService,
    this.enforceRoleGuard = true,
    this.mediaService,
    this.categoryService,
  }) : eventService = eventService ?? AdminEventService();

  final EventItem event;
  final AdminEventService eventService;
  final bool enforceRoleGuard;
  final FirebaseMediaService? mediaService;
  final EventCategoryService? categoryService;

  @override
  State<AdminEditEventScreen> createState() => _AdminEditEventScreenState();
}

class _AdminEditEventScreenState extends State<AdminEditEventScreen> {
  final _formKey = GlobalKey<FormState>();
  late final FirebaseMediaService _mediaService;
  late final EventCategoryService _categoryService;
  late final TextEditingController _titleController;
  late final TextEditingController _locationController;
  late final TextEditingController _descriptionController;

  List<String> _eventCategories = EventCategoryService.defaultCategories;
  DateTime? _selectedDate;
  late String _selectedCategory;
  late EventReviewStatus _selectedReviewStatus;
  XFile? _selectedImage;
  late String? _currentImageUrl;
  late String? _currentImageStoragePath;
  bool _removeImage = false;

  XFile? _selectedVideo;
  late String? _currentVideoUrl;
  late String? _currentVideoStoragePath;
  bool _removeVideo = false;

  XFile? _selectedAudio;
  late String? _currentAudioUrl;
  late String? _currentAudioStoragePath;
  bool _removeAudio = false;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _mediaService = widget.mediaService ?? FirebaseMediaService();
    _categoryService = widget.categoryService ?? EventCategoryService();
    _titleController = TextEditingController(text: widget.event.title);
    _locationController = TextEditingController(text: widget.event.location);
    _descriptionController = TextEditingController(
      text: widget.event.description,
    );
    _selectedDate = _tryParseDate(widget.event.date);
    _selectedCategory = _eventCategories.contains(widget.event.category)
        ? widget.event.category
        : 'General';
    _selectedReviewStatus = widget.event.reviewStatus;
    _loadCategories();
    _currentImageUrl = widget.event.imageAsset;
    _currentImageStoragePath = widget.event.imageStoragePath;
    _currentVideoUrl = widget.event.videoUrl;
    _currentVideoStoragePath = widget.event.videoStoragePath;
    _currentAudioUrl = widget.event.audioUrl;
    _currentAudioStoragePath = widget.event.audioStoragePath;
  }

  Future<void> _loadCategories() async {
    final categories = await _categoryService.fetchCategories();
    if (!mounted) return;
    setState(() {
      _eventCategories = categories;
      if (!categories.contains(_selectedCategory)) {
        _selectedCategory = categories.isNotEmpty ? categories.first : 'General';
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  DateTime? _tryParseDate(String input) {
    final trimmed = input.trim();

    final slashParts = trimmed.split('/');
    if (slashParts.length == 3) {
      final day = int.tryParse(slashParts[0]);
      final month = int.tryParse(slashParts[1]);
      final year = int.tryParse(slashParts[2]);
      if (day != null && month != null && year != null) {
        return DateTime(year, month, day);
      }
    }

    final spaceParts = trimmed.split(' ');
    if (spaceParts.length == 3) {
      final day = int.tryParse(spaceParts[0]);
      final month = _monthFromName(spaceParts[1]);
      final year = int.tryParse(spaceParts[2]);
      if (day != null && month != null && year != null) {
        return DateTime(year, month, day);
      }
    }

    return null;
  }

  int? _monthFromName(String monthName) {
    const months = {
      'jan': 1,
      'feb': 2,
      'mar': 3,
      'apr': 4,
      'may': 5,
      'jun': 6,
      'jul': 7,
      'aug': 8,
      'sep': 9,
      'oct': 10,
      'nov': 11,
      'dec': 12,
    };

    return months[monthName.toLowerCase()];
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day/$month/$year';
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initialDate = _selectedDate ?? now;

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickEventImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
      maxWidth: 1440,
      maxHeight: 1440,
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _selectedImage = picked;
      _removeImage = false;
    });
  }

  Future<void> _pickEventVideo() async {
    final picker = ImagePicker();
    final picked = await picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 5),
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _selectedVideo = picked;
      _removeVideo = false;
    });
  }

  Future<void> _pickEventAudio() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'wav', 'm4a', 'aac', 'ogg'],
    );
    if (result == null || result.files.isEmpty || !mounted) {
      return;
    }
    final path = result.files.single.path;
    if (path == null) return;
    setState(() {
      _selectedAudio = XFile(path, name: result.files.single.name);
      _removeAudio = false;
    });
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an event date.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final ownerEmail = widget.event.createdByLocalEmail ?? 'admin';

      // --- Image ---
      String? oldImageStoragePath;
      String? imageUrl = _removeImage ? null : _currentImageUrl;
      String? imageStoragePath = _removeImage ? null : _currentImageStoragePath;
      if (_selectedImage != null) {
        final bytes = await _selectedImage!.readAsBytes();
        final uploaded = await _mediaService.uploadEventImage(
          eventId: widget.event.id,
          ownerEmail: ownerEmail,
          bytes: bytes,
          fileName: _selectedImage!.name,
          previousStoragePath: _currentImageStoragePath,
        );
        imageUrl = uploaded.downloadUrl;
        imageStoragePath = uploaded.storagePath;
      } else if (_removeImage &&
          (_currentImageStoragePath?.isNotEmpty ?? false)) {
        oldImageStoragePath = _currentImageStoragePath;
      }

      // --- Video ---
      String? oldVideoStoragePath;
      String? videoUrl = _removeVideo ? null : _currentVideoUrl;
      String? videoStoragePath = _removeVideo ? null : _currentVideoStoragePath;
      if (_selectedVideo != null) {
        final bytes = await _selectedVideo!.readAsBytes();
        final uploaded = await _mediaService.uploadEventVideo(
          eventId: widget.event.id,
          ownerEmail: ownerEmail,
          bytes: bytes,
          fileName: _selectedVideo!.name,
          previousStoragePath: _currentVideoStoragePath,
        );
        videoUrl = uploaded.downloadUrl;
        videoStoragePath = uploaded.storagePath;
      } else if (_removeVideo &&
          (_currentVideoStoragePath?.isNotEmpty ?? false)) {
        oldVideoStoragePath = _currentVideoStoragePath;
      }

      // --- Audio ---
      String? oldAudioStoragePath;
      String? audioUrl = _removeAudio ? null : _currentAudioUrl;
      String? audioStoragePath = _removeAudio ? null : _currentAudioStoragePath;
      if (_selectedAudio != null) {
        final bytes = await _selectedAudio!.readAsBytes();
        final uploaded = await _mediaService.uploadEventAudio(
          eventId: widget.event.id,
          ownerEmail: ownerEmail,
          bytes: bytes,
          fileName: _selectedAudio!.name,
          previousStoragePath: _currentAudioStoragePath,
        );
        audioUrl = uploaded.downloadUrl;
        audioStoragePath = uploaded.storagePath;
      } else if (_removeAudio &&
          (_currentAudioStoragePath?.isNotEmpty ?? false)) {
        oldAudioStoragePath = _currentAudioStoragePath;
      }

      final aiNarration = buildEventNarration(
        title: _titleController.text.trim(),
        dateTime: _formatDate(_selectedDate!),
        location: _locationController.text.trim(),
        description: _descriptionController.text.trim(),
      );

      await widget.eventService.updateEvent(
        eventId: widget.event.id,
        title: _titleController.text.trim(),
        date: _formatDate(_selectedDate!),
        category: _selectedCategory,
        reviewStatus: _selectedReviewStatus,
        location: _locationController.text.trim(),
        description: _descriptionController.text.trim(),
        imageUrl: imageUrl,
        imageStoragePath: imageStoragePath,
        videoUrl: videoUrl,
        videoStoragePath: videoStoragePath,
        audioUrl: audioUrl,
        audioStoragePath: audioStoragePath,
        aiNarration: aiNarration,
      );

      // Clean up removed media from Storage
      if (oldImageStoragePath != null) {
        await _mediaService.deleteMedia(oldImageStoragePath);
      }
      if (oldVideoStoragePath != null) {
        await _mediaService.deleteMedia(oldVideoStoragePath);
      }
      if (oldAudioStoragePath != null) {
        await _mediaService.deleteMedia(oldAudioStoragePath);
      }

      if (!mounted) {
        return;
      }

      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event updated successfully.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update event: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = Scaffold(
        backgroundColor: AppPalette.background,
        appBar: AppBar(title: const LogoAppBarTitle('Edit Event')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppPalette.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppPalette.border),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Event Title',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter event title';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: _pickDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Event Date',
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                        suffixIcon: Icon(
                          Icons.calendar_today,
                          color: AppPalette.deepBlue,
                        ),
                      ),
                      child: Text(
                        _selectedDate == null
                            ? 'Select date'
                            : _formatDate(_selectedDate!),
                        style: TextStyle(
                          color: _selectedDate == null
                              ? AppPalette.mutedText
                              : AppPalette.charcoal,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(),
                    ),
                    items: _eventCategories
                        .map(
                          (category) => DropdownMenuItem<String>(
                            value: category,
                            child: Text(category),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: _isSaving
                        ? null
                        : (value) {
                            if (value == null) return;
                            setState(() => _selectedCategory = value);
                          },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<EventReviewStatus>(
                    initialValue: _selectedReviewStatus,
                    decoration: const InputDecoration(
                      labelText: 'Review Status',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: EventReviewStatus.pending,
                        child: Text('Pending'),
                      ),
                      DropdownMenuItem(
                        value: EventReviewStatus.approved,
                        child: Text('Approved'),
                      ),
                      DropdownMenuItem(
                        value: EventReviewStatus.rejected,
                        child: Text('Rejected'),
                      ),
                    ],
                    onChanged: _isSaving
                        ? null
                        : (value) {
                            if (value == null) return;
                            setState(() => _selectedReviewStatus = value);
                          },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _locationController,
                    decoration: const InputDecoration(
                      labelText: 'Location',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter location';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter description';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _isSaving ? null : _pickEventImage,
                    icon: const Icon(Icons.image_outlined),
                    label: Text(
                      _selectedImage != null ||
                              (_currentImageUrl?.isNotEmpty ?? false)
                          ? 'Change Event Image'
                          : 'Upload Event Image',
                    ),
                  ),
                  if (_currentImageUrl?.isNotEmpty == true &&
                      !_removeImage &&
                      _selectedImage == null) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.network(
                        _currentImageUrl!,
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ],
                  if (_selectedImage != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _selectedImage!.name,
                      style: const TextStyle(color: AppPalette.mutedText),
                    ),
                  ],
                  if (_selectedImage != null ||
                      (_currentImageUrl?.isNotEmpty ?? false)) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _isSaving
                          ? null
                          : () {
                              setState(() {
                                _selectedImage = null;
                                _removeImage = true;
                              });
                            },
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: const Text('Remove Image'),
                    ),
                  ],

                  // --- Video Section ---
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _isSaving ? null : _pickEventVideo,
                    icon: const Icon(Icons.videocam_outlined),
                    label: Text(
                      _selectedVideo != null ||
                              (_currentVideoUrl?.isNotEmpty ?? false)
                          ? 'Change Event Video'
                          : 'Upload Event Video',
                    ),
                  ),
                  if (_currentVideoUrl?.isNotEmpty == true &&
                      !_removeVideo &&
                      _selectedVideo == null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppPalette.deepBlue.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.video_file_rounded, color: AppPalette.deepBlue),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Video attached',
                              style: TextStyle(color: AppPalette.charcoal),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (_selectedVideo != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _selectedVideo!.name,
                      style: const TextStyle(color: AppPalette.mutedText),
                    ),
                  ],
                  if (_selectedVideo != null ||
                      (_currentVideoUrl?.isNotEmpty ?? false)) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _isSaving
                          ? null
                          : () {
                              setState(() {
                                _selectedVideo = null;
                                _removeVideo = true;
                              });
                            },
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: const Text('Remove Video'),
                    ),
                  ],

                  // --- Audio Section ---
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _isSaving ? null : _pickEventAudio,
                    icon: const Icon(Icons.audio_file_outlined),
                    label: Text(
                      _selectedAudio != null ||
                              (_currentAudioUrl?.isNotEmpty ?? false)
                          ? 'Change Event Audio'
                          : 'Upload Event Audio',
                    ),
                  ),
                  if (_currentAudioUrl?.isNotEmpty == true &&
                      !_removeAudio &&
                      _selectedAudio == null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.audiotrack_rounded, color: Colors.orange.shade700),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Audio attached',
                              style: TextStyle(color: AppPalette.charcoal),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (_selectedAudio != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _selectedAudio!.name,
                      style: const TextStyle(color: AppPalette.mutedText),
                    ),
                  ],
                  if (_selectedAudio != null ||
                      (_currentAudioUrl?.isNotEmpty ?? false)) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _isSaving
                          ? null
                          : () {
                              setState(() {
                                _selectedAudio = null;
                                _removeAudio = true;
                              });
                            },
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: const Text('Remove Audio'),
                    ),
                  ],

                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _saveChanges,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save),
                      label: const Text('Save Changes'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppPalette.deepBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
    );

    if (!widget.enforceRoleGuard) {
      return content;
    }
    return RoleGuard(
      allowedRoles: const {AppUserRole.admin},
      deniedMessage: 'Access denied. Admin privileges are required.',
      child: content,
    );
  }
}
