import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:brisconnect/auth/app_user_role.dart';
import 'package:brisconnect/auth/local_auth.dart';
import 'package:brisconnect/utils/narration_builder.dart';
import 'package:brisconnect/services/event_document_id_service.dart';
import 'package:brisconnect/services/event_repository.dart';
import 'package:brisconnect/services/event_category_service.dart';
import 'package:brisconnect/services/firebase_media_service.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/widgets/logo_app_bar_title.dart';
import 'package:brisconnect/widgets/role_guard.dart';

class AddEventScreen extends StatefulWidget {
  const AddEventScreen({super.key});

  @override
  State<AddEventScreen> createState() => _AddEventScreenState();
}

class _AddEventScreenState extends State<AddEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();
  final FirebaseMediaService _mediaService = FirebaseMediaService();
  final EventCategoryService _categoryService = EventCategoryService();

  List<String> _eventCategories = EventCategoryService.defaultCategories;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  String _selectedCategory = EventCategoryService.defaultCategories.first;
  XFile? _selectedImage;
  XFile? _selectedVideo;
  PlatformFile? _selectedAudio;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final categories = await _categoryService.fetchCategories();
    if (!mounted) return;
    setState(() {
      _eventCategories = categories;
      if (!categories.contains(_selectedCategory)) {
        _selectedCategory = categories.first;
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

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: DateTime(now.year + 2),
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day/$month/$year';
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
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
    setState(() => _selectedImage = picked);
  }

  Future<void> _pickEventVideo() async {
    final picker = ImagePicker();
    final picked = await picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 2),
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() => _selectedVideo = picked);
  }

  Future<void> _pickEventAudio() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'wav', 'm4a', 'aac', 'ogg'],
    );
    if (result == null || result.files.isEmpty || !mounted) {
      return;
    }
    setState(() => _selectedAudio = result.files.first);
  }

  Future<void> _saveEvent() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an event date')),
      );
      return;
    }

    if (_selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an event time')),
      );
      return;
    }

    final currentUser = LocalAuth.currentLocal;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to submit an event.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final title = _titleController.text.trim();
    final date = _formatDate(_selectedDate!);
    final time = _formatTime(_selectedTime!);
    final category = _selectedCategory.trim();
    final location = _locationController.text.trim();
    final description = _descriptionController.text.trim();
    final eventId = EventDocumentIdService.buildLocalSubmissionId(
      title: title,
      date: date,
      email: currentUser.email,
    );

    try {
      final eventsRef =
          FirebaseFirestore.instance.collection('events').doc(eventId);
      String? imageUrl;
      String? imageStoragePath;
      if (_selectedImage != null) {
        final bytes = await _selectedImage!.readAsBytes();
        final uploaded = await _mediaService.uploadEventImage(
          eventId: eventId,
          ownerEmail: currentUser.email,
          bytes: bytes,
          fileName: _selectedImage!.name,
        );
        imageUrl = uploaded.downloadUrl;
        imageStoragePath = uploaded.storagePath;
      }

      String? videoUrl;
      String? videoStoragePath;
      if (_selectedVideo != null) {
        final videoBytes = await _selectedVideo!.readAsBytes();
        final uploaded = await _mediaService.uploadEventVideo(
          eventId: eventId,
          ownerEmail: currentUser.email,
          bytes: videoBytes,
          fileName: _selectedVideo!.name,
        );
        videoUrl = uploaded.downloadUrl;
        videoStoragePath = uploaded.storagePath;
      }

      String? audioUrl;
      String? audioStoragePath;
      if (_selectedAudio != null) {
        final audioBytes = _selectedAudio!.bytes ??
            await File(_selectedAudio!.path!).readAsBytes();
        final uploaded = await _mediaService.uploadEventAudio(
          eventId: eventId,
          ownerEmail: currentUser.email,
          bytes: audioBytes,
          fileName: _selectedAudio!.name,
        );
        audioUrl = uploaded.downloadUrl;
        audioStoragePath = uploaded.storagePath;
      }

      final aiNarration = buildEventNarration(
        title: title,
        dateTime: '$date • $time',
        location: location,
        description: description,
      );
      debugPrint('[AddEvent] aiNarration generated (${aiNarration.length} chars): $aiNarration');

      await eventsRef.set({
        'id': eventId,
        'title': title,
        'date': date,
        'time': time,
        'dateTime': '$date • $time',
        'category': category,
        'location': location,
        'description': description,
        'reviewStatus': 'pending',
        'createdByLocalEmail': currentUser.email.toLowerCase(),
        'imageUrl': imageUrl,
        'imageStoragePath': imageStoragePath,
        'videoUrl': videoUrl,
        'videoStoragePath': videoStoragePath,
        'audioUrl': audioUrl,
        'audioStoragePath': audioStoragePath,
        'aiNarration': aiNarration,
        'createdAt': FieldValue.serverTimestamp(),
        'source': 'local_submission',
      });

      // Keep local in-memory view in sync for existing local dashboard tabs.
      EventRepository.addPendingEvent(
        id: eventId,
        title: title,
        date: date,
        location: location,
        description: description,
        createdByLocalEmail: currentUser.email,
      );
    } on FirebaseException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.code == 'permission-denied'
                  ? 'Submission blocked by Firestore rules. Please ensure your Local account is approved.'
                  : 'Could not submit event (${e.code}).',
            ),
          ),
        );
      }
      setState(() => _isSaving = false);
      return;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Could not submit event. Please try again.')),
        );
      }
      setState(() => _isSaving = false);
      return;
    }

    if (!mounted) return;
    setState(() => _isSaving = false);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Event Submitted'),
        content: const Text(
          'Your event has been saved and marked as Pending Approval. It will not be visible to visitors until approved.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String message,
  }) {
    return Scaffold(
      backgroundColor: AppPalette.background,
      appBar: AppBar(
        title: const LogoAppBarTitle('Add Event (Local)'),
      ),
      body: Center(
        child: Card(
          color: AppPalette.surface,
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 48, color: iconColor),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = LocalAuth.currentLocal;

    Widget child;
    if (currentUser == null) {
      child = _buildStatusCard(
        icon: Icons.error,
        iconColor: AppPalette.ochre,
        title: 'Not Logged In',
        message: 'Please log in to your Local account to add events.',
      );
    } else if (currentUser.approvalStatus == AccountApprovalStatus.pending) {
      child = _buildStatusCard(
        icon: Icons.schedule,
        iconColor: AppPalette.gold,
        title: 'Account Pending Approval',
        message:
            'Your account is awaiting admin approval. You will be able to submit events once your account is approved. Please check back later.',
      );
    } else if (currentUser.approvalStatus == AccountApprovalStatus.rejected) {
      child = _buildStatusCard(
        icon: Icons.block,
        iconColor: AppPalette.ochre,
        title: 'Account Rejected',
        message:
            'Your account has been rejected and you cannot submit events. Please contact support for more information.',
      );
    } else {
      child = Scaffold(
        backgroundColor: AppPalette.background,
        appBar: AppBar(
          title: const LogoAppBarTitle('Add Event (Local)'),
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
                    decoration: const InputDecoration(labelText: 'Event Title'),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                            ? 'Title is required'
                            : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedCategory,
                    decoration: const InputDecoration(labelText: 'Category'),
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
                    decoration: const InputDecoration(labelText: 'Location'),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                            ? 'Location is required'
                            : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'Description'),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                            ? 'Description is required'
                            : null,
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _isSaving ? null : _pickEventImage,
                    icon: const Icon(Icons.image_outlined),
                    label: Text(
                      _selectedImage == null
                          ? 'Upload Event Image'
                          : 'Change Event Image',
                    ),
                  ),
                  if (_selectedImage != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppPalette.surfaceAlt,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppPalette.border),
                      ),
                      child: Text(
                        'Selected image: ${_selectedImage!.name}',
                        style: const TextStyle(color: AppPalette.charcoal),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _isSaving ? null : _pickEventVideo,
                    icon: const Icon(Icons.videocam_outlined),
                    label: Text(
                      _selectedVideo == null
                          ? 'Upload Event Video'
                          : 'Change Event Video',
                    ),
                  ),
                  if (_selectedVideo != null) ...[                    const SizedBox(height: 10),
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
                          const Icon(Icons.videocam_rounded,
                              color: AppPalette.deepBlue, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _selectedVideo!.name,
                              style:
                                  const TextStyle(color: AppPalette.charcoal),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close,
                                size: 18, color: AppPalette.mutedText),
                            onPressed: () =>
                                setState(() => _selectedVideo = null),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _isSaving ? null : _pickEventAudio,
                    icon: const Icon(Icons.audiotrack_outlined),
                    label: Text(
                      _selectedAudio == null
                          ? 'Upload Event Audio'
                          : 'Change Event Audio',
                    ),
                  ),
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
                          IconButton(
                            icon: const Icon(Icons.close,
                                size: 18, color: AppPalette.mutedText),
                            onPressed: () =>
                                setState(() => _selectedAudio = null),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_month),
                    label: Text(
                      _selectedDate == null
                          ? 'Select Date'
                          : 'Date: ${_formatDate(_selectedDate!)}',
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _pickTime,
                    icon: const Icon(Icons.access_time_rounded),
                    label: Text(
                      _selectedTime == null
                          ? 'Select Time'
                          : 'Time: ${_formatTime(_selectedTime!)}',
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveEvent,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppPalette.ochre,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Submit Event'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return RoleGuard(
      allowedRoles: const {AppUserRole.local},
      deniedMessage: 'Access denied. Local account access is required.',
      child: child,
    );
  }
}
