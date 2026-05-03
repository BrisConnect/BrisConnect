import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:brisconnect/auth/local_auth.dart';
import 'package:brisconnect/utils/narration_builder.dart';
import 'package:brisconnect/models/event_item.dart';
import 'package:brisconnect/services/event_category_service.dart';
import 'package:brisconnect/services/firebase_media_service.dart';
import 'package:brisconnect/services/local_event_service.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/widgets/logo_app_bar_title.dart';

class LocalEditEventScreen extends StatefulWidget {
  final EventItem event;

  const LocalEditEventScreen({
    super.key,
    required this.event,
  });

  @override
  State<LocalEditEventScreen> createState() => _LocalEditEventScreenState();
}

class _LocalEditEventScreenState extends State<LocalEditEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final LocalEventService _localEventService = LocalEventService();
  final FirebaseMediaService _mediaService = FirebaseMediaService();
  final EventCategoryService _categoryService = EventCategoryService();
  late final TextEditingController _titleController;
  late final TextEditingController _locationController;
  late final TextEditingController _descriptionController;

  List<String> _eventCategories = EventCategoryService.defaultCategories;
  DateTime? _selectedDate;
  late String _selectedCategory;
  XFile? _selectedImage;
  late String? _currentImageUrl;
  late String? _currentImageStoragePath;
  bool _removeImage = false;
  PlatformFile? _selectedAudio;
  late String? _currentAudioUrl;
  late String? _currentAudioStoragePath;
  bool _removeAudio = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.event.title);
    _locationController = TextEditingController(text: widget.event.location);
    _descriptionController =
        TextEditingController(text: widget.event.description);
    _selectedDate = _tryParseDate(widget.event.date);
    _selectedCategory = _eventCategories.contains(widget.event.category)
        ? widget.event.category
        : 'General';
    _currentImageUrl = widget.event.imageAsset;
    _currentImageStoragePath = widget.event.imageStoragePath;
    _currentAudioUrl = widget.event.audioUrl;
    _currentAudioStoragePath = widget.event.audioStoragePath;
    _loadCategories();
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
    // Strip time portion from composite "dd/mm/yyyy • hh:mm AM" format.
    final datePart = input.split('•').first.trim();
    final trimmed = datePart.trim();

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
      lastDate: DateTime(now.year + 2),
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

  Future<void> _pickEventAudio() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'wav', 'm4a', 'aac', 'ogg'],
    );
    if (result == null || result.files.isEmpty || !mounted) {
      return;
    }
    setState(() {
      _selectedAudio = result.files.first;
      _removeAudio = false;
    });
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an event date')),
      );
      return;
    }

    final localEmail = LocalAuth.currentLocal?.email;
    if (localEmail == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to edit events.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    bool didUpdate = false;
    String? oldImageStoragePath;
    try {
      String? imageUrl = _removeImage ? null : _currentImageUrl;
      String? imageStoragePath = _removeImage ? null : _currentImageStoragePath;
      if (_selectedImage != null) {
        final bytes = await _selectedImage!.readAsBytes();
        final uploaded = await _mediaService.uploadEventImage(
          eventId: widget.event.id,
          ownerEmail: localEmail,
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

      String? audioUrl = _removeAudio ? null : _currentAudioUrl;
      String? audioStoragePath = _removeAudio ? null : _currentAudioStoragePath;
      String? oldAudioStoragePath;
      if (_selectedAudio != null) {
        debugPrint('[LocalEditEvent] Uploading audio for event=${widget.event.id} email=$localEmail');
        try {
          final audioBytes = _selectedAudio!.bytes ??
              await File(_selectedAudio!.path!).readAsBytes();
          debugPrint('[LocalEditEvent] Audio bytes: ${audioBytes.length}, file: ${_selectedAudio!.name}');
          final uploaded = await _mediaService.uploadEventAudio(
            eventId: widget.event.id,
            ownerEmail: localEmail,
            bytes: audioBytes,
            fileName: _selectedAudio!.name,
            previousStoragePath: _currentAudioStoragePath,
          );
          audioUrl = uploaded.downloadUrl;
          audioStoragePath = uploaded.storagePath;
          debugPrint('[LocalEditEvent] Audio uploaded OK: $audioStoragePath');
        } catch (storageError) {
          debugPrint('[LocalEditEvent] AUDIO STORAGE UPLOAD FAILED: $storageError');
          rethrow;
        }
      } else if (_removeAudio &&
          (_currentAudioStoragePath?.isNotEmpty ?? false)) {
        oldAudioStoragePath = _currentAudioStoragePath;
      }

      debugPrint('[LocalEditEvent] Updating Firestore doc ${widget.event.id}');
      final title = _titleController.text.trim();
      final date = _formatDate(_selectedDate!);
      final location = _locationController.text.trim();
      final description = _descriptionController.text.trim();
      final aiNarration = buildEventNarration(
        title: title,
        dateTime: date,
        location: location,
        description: description,
      );
      didUpdate = await _localEventService.updateSubmittedEvent(
        eventId: widget.event.id,
        localEmail: localEmail,
        title: title,
        date: date,
        category: _selectedCategory,
        location: location,
        description: description,
        imageUrl: imageUrl,
        imageStoragePath: imageStoragePath,
        audioUrl: audioUrl,
        audioStoragePath: audioStoragePath,
        aiNarration: aiNarration,
      );
      if (didUpdate && oldImageStoragePath != null) {
        await _mediaService.deleteMedia(oldImageStoragePath);
      }
      if (didUpdate && oldAudioStoragePath != null) {
        await _mediaService.deleteMedia(oldAudioStoragePath);
      }
    } catch (error) {
      debugPrint('[LocalEditEvent] Save failed: $error');
      if (!mounted) {
        return;
      }
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save: $error'),
        ),
      );
      return;
    }

    if (!mounted) {
      return;
    }
    setState(() => _isSaving = false);

    if (!didUpdate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('You can only edit events created by your own account.'),
        ),
      );
      return;
    }

    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.background,
      appBar: AppBar(
        title: const LogoAppBarTitle('Edit Event'),
      ),
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
                      suffixIcon: Icon(Icons.calendar_today,
                          color: AppPalette.deepBlue),
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
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _isSaving ? null : _pickEventAudio,
                  icon: const Icon(Icons.audiotrack_outlined),
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
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppPalette.surfaceAlt,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppPalette.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.audiotrack_rounded,
                            color: AppPalette.deepBlue, size: 20),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Audio file attached',
                            style: TextStyle(color: AppPalette.charcoal),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (_selectedAudio != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppPalette.surfaceAlt,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppPalette.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.audiotrack_rounded,
                            color: AppPalette.deepBlue, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _selectedAudio!.name,
                            style:
                                const TextStyle(color: AppPalette.charcoal),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (_selectedAudio != null ||
                    ((_currentAudioUrl?.isNotEmpty ?? false) &&
                        !_removeAudio)) ...[
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
                    icon: const Icon(Icons.save),
                    label: const Text('Save Changes'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppPalette.deepBlue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
