import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:brisconnect/auth/app_user_role.dart';
import 'package:brisconnect/services/admin_attraction_service.dart';
import 'package:brisconnect/services/firebase_media_service.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/widgets/inline_status_message.dart';
import 'package:brisconnect/widgets/logo_app_bar_title.dart';
import 'package:brisconnect/widgets/role_guard.dart';

class AdminAttractionManagementScreen extends StatefulWidget {
  AdminAttractionManagementScreen({
    super.key,
    AdminAttractionService? attractionService,
  }) : attractionService = attractionService ?? AdminAttractionService();

  final AdminAttractionService attractionService;

  @override
  State<AdminAttractionManagementScreen> createState() =>
      _AdminAttractionManagementScreenState();
}

class _AdminAttractionManagementScreenState
    extends State<AdminAttractionManagementScreen> {
  Future<void> _openAddForm() async {
    final payload = await showModalBottomSheet<_AttractionFormPayload>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppPalette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _AttractionEditorSheet(),
    );

    if (payload == null) {
      return;
    }

    try {
      await widget.attractionService.addAttraction(
        name: payload.name,
        description: payload.description,
        location: payload.location,
        latitude: payload.latitude,
        longitude: payload.longitude,
        category: payload.category,
        webLink: payload.webLink,
        imageUrl: payload.imageUrl,
        imageStoragePath: payload.imageStoragePath,
        audioUrl: payload.audioUrl,
        audioStoragePath: payload.audioStoragePath,
      );

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${payload.name} added.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add attraction: $error')),
      );
    }
  }

  Future<void> _openEditForm(AdminAttractionItem item) async {
    final payload = await showModalBottomSheet<_AttractionFormPayload>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppPalette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _AttractionEditorSheet(item: item),
    );

    if (payload == null) {
      return;
    }

    try {
      await widget.attractionService.updateAttraction(
        attractionId: item.id,
        name: payload.name,
        description: payload.description,
        location: payload.location,
        latitude: payload.latitude,
        longitude: payload.longitude,
        category: payload.category,
        webLink: payload.webLink,
        imageUrl: payload.imageUrl,
        imageStoragePath: payload.imageStoragePath,
        audioUrl: payload.audioUrl,
        audioStoragePath: payload.audioStoragePath,
      );

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${payload.name} updated.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update attraction: $error')),
      );
    }
  }

  Future<void> _confirmDelete(AdminAttractionItem item) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete attraction?'),
          content: Text('Delete "${item.name}" from Firebase?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style:
                  FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    try {
      await widget.attractionService.deleteAttraction(item.id);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${item.name} deleted.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete attraction: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return RoleGuard(
      allowedRoles: const {AppUserRole.admin},
      deniedMessage: 'Access denied. Admin privileges are required.',
      child: Scaffold(
        backgroundColor: AppPalette.background,
        appBar: AppBar(title: const LogoAppBarTitle('Manage Attractions')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _openAddForm,
          icon: const Icon(Icons.add_location_alt_rounded),
          label: const Text('Add Attraction'),
        ),
        body: StreamBuilder<List<AdminAttractionItem>>(
          stream: widget.attractionService.watchAllAttractions(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: InlineStatusMessage(
                    message:
                        'Unable to load attractions right now. Please try again.',
                    type: InlineStatusType.error,
                    actionLabel: 'Retry',
                    onAction: () => setState(() {}),
                  ),
                ),
              );
            }

            final items = snapshot.data ?? const <AdminAttractionItem>[];
            if (items.isEmpty) {
              return const Center(
                  child: Text('No attractions found in Firebase.'));
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = items[index];
                return Card(
                  color: AppPalette.surface,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.name,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: AppPalette.charcoal,
                                ),
                              ),
                            ),
                            if (item.isApproved)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text(
                                  'Approved',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('Location: ${item.location}'),
                        Text(
                            'Coordinates: ${item.latitude}, ${item.longitude}'),
                        if ((item.category ?? '').trim().isNotEmpty)
                          Text('Category: ${item.category}'),
                        const SizedBox(height: 8),
                        Text(
                          item.description,
                          style: const TextStyle(color: AppPalette.charcoal),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _openEditForm(item),
                                icon: const Icon(Icons.edit_rounded),
                                label: const Text('Edit'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppPalette.deepBlue,
                                  side: const BorderSide(
                                      color: AppPalette.deepBlue),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () => _confirmDelete(item),
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.red.shade700,
                                  foregroundColor: Colors.white,
                                ),
                                icon: const Icon(Icons.delete_rounded),
                                label: const Text('Delete'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _AttractionFormPayload {
  const _AttractionFormPayload({
    required this.name,
    required this.description,
    required this.location,
    required this.latitude,
    required this.longitude,
    this.category,
    this.webLink,
    this.imageUrl,
    this.imageStoragePath,
    this.audioUrl,
    this.audioStoragePath,
  });

  final String name;
  final String description;
  final String location;
  final double latitude;
  final double longitude;
  final String? category;
  final String? webLink;
  final String? imageUrl;
  final String? imageStoragePath;
  final String? audioUrl;
  final String? audioStoragePath;
}

class _AttractionEditorSheet extends StatefulWidget {
  const _AttractionEditorSheet({this.item});

  final AdminAttractionItem? item;

  @override
  State<_AttractionEditorSheet> createState() => _AttractionEditorSheetState();
}

class _AttractionEditorSheetState extends State<_AttractionEditorSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _locationController;
  late final TextEditingController _latitudeController;
  late final TextEditingController _longitudeController;
  late final TextEditingController _categoryController;
  late final TextEditingController _webLinkController;
  late final TextEditingController _imageUrlController;
  late final TextEditingController _audioUrlController;
  final FirebaseMediaService _mediaService = FirebaseMediaService();
  String? _imageStoragePath;
  String? _audioStoragePath;
  bool _uploadingAudio = false;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _nameController = TextEditingController(text: item?.name ?? '');
    _descriptionController =
        TextEditingController(text: item?.description ?? '');
    _locationController = TextEditingController(text: item?.location ?? '');
    _latitudeController = TextEditingController(
      text: item == null ? '' : item.latitude.toString(),
    );
    _longitudeController = TextEditingController(
      text: item == null ? '' : item.longitude.toString(),
    );
    _categoryController = TextEditingController(text: item?.category ?? '');
    _webLinkController = TextEditingController(text: item?.webLink ?? '');
    _imageUrlController = TextEditingController(text: item?.imageUrl ?? '');
    _audioUrlController = TextEditingController(text: item?.audioUrl ?? '');
    _imageStoragePath = item?.imageStoragePath;
    _audioStoragePath = item?.audioStoragePath;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _categoryController.dispose();
    _webLinkController.dispose();
    _imageUrlController.dispose();
    _audioUrlController.dispose();
    super.dispose();
  }

  Future<void> _uploadAudioGuide() async {
    final attractionId = widget.item?.id ?? _nameController.text.trim();
    if (attractionId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Enter an attraction name before uploading audio.')),
      );
      return;
    }

    setState(() => _uploadingAudio = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const <String>['mp3', 'wav', 'm4a', 'aac', 'ogg'],
        withData: true,
      );
      final file = result?.files.single;
      if (file == null || file.bytes == null) {
        return;
      }

      final uploaded = await _mediaService.uploadAttractionAudio(
        attractionId: attractionId,
        bytes: file.bytes!,
        fileName: file.name,
        previousStoragePath: _audioStoragePath,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _audioUrlController.text = uploaded.downloadUrl;
        _audioStoragePath = uploaded.storagePath;
      });
    } on FormatException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } finally {
      if (mounted) {
        setState(() => _uploadingAudio = false);
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final latitude = double.tryParse(_latitudeController.text.trim());
    final longitude = double.tryParse(_longitudeController.text.trim());
    if (latitude == null || longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide valid coordinates.')),
      );
      return;
    }

    final shouldDeleteAudio = _audioUrlController.text.trim().isEmpty &&
        widget.item?.audioStoragePath != null &&
        widget.item!.audioStoragePath!.trim().isNotEmpty &&
        _audioStoragePath == null;
    if (shouldDeleteAudio) {
      await _mediaService.deleteMedia(widget.item!.audioStoragePath);
    }

    Navigator.pop(
      context,
      _AttractionFormPayload(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        location: _locationController.text.trim(),
        latitude: latitude,
        longitude: longitude,
        category: _normalizeOptional(_categoryController.text),
        webLink: _normalizeOptional(_webLinkController.text),
        imageUrl: _normalizeOptional(_imageUrlController.text),
        imageStoragePath: _imageStoragePath,
        audioUrl: _normalizeOptional(_audioUrlController.text),
        audioStoragePath: _audioStoragePath,
      ),
    );
  }

  String? _normalizeOptional(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.item != null;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEditing ? 'Edit Attraction' : 'Add Attraction',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppPalette.charcoal,
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Name is required.'
                      : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _locationController,
                  decoration: const InputDecoration(
                    labelText: 'Location',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Location is required.'
                      : null,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _latitudeController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Latitude',
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        validator: (value) =>
                            double.tryParse((value ?? '').trim()) == null
                                ? 'Invalid latitude.'
                                : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _longitudeController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Longitude',
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        validator: (value) =>
                            double.tryParse((value ?? '').trim()) == null
                                ? 'Invalid longitude.'
                                : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _categoryController,
                  decoration: const InputDecoration(
                    labelText: 'Category (optional)',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _webLinkController,
                  decoration: const InputDecoration(
                    labelText: 'Website Link (optional)',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _imageUrlController,
                  decoration: const InputDecoration(
                    labelText: 'Image URL (optional)',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _audioUrlController,
                  decoration: const InputDecoration(
                    labelText: 'Audio Guide URL (optional)',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _uploadingAudio ? null : _uploadAudioGuide,
                        icon: _uploadingAudio
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.audiotrack_rounded),
                        label: Text(
                          _audioUrlController.text.trim().isNotEmpty
                              ? 'Replace Audio Guide'
                              : 'Upload Audio Guide',
                        ),
                      ),
                    ),
                    if (_audioUrlController.text.trim().isNotEmpty) ...[
                      const SizedBox(width: 10),
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _audioUrlController.clear();
                            _audioStoragePath = null;
                          });
                        },
                        icon: const Icon(Icons.delete_outline_rounded),
                        label: const Text('Clear'),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                    alignLabelWithHint: true,
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Description is required.'
                      : null,
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _submit(),
                    icon: Icon(
                        isEditing ? Icons.save_rounded : Icons.add_rounded),
                    label: Text(isEditing ? 'Save Changes' : 'Add Attraction'),
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
  }
}
