import 'dart:typed_data';

import 'package:brisconnect/services/app_feedback_service.dart';
import 'package:brisconnect/services/firebase_media_service.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/widgets/logo_app_bar_title.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class FeedbackFormScreen extends StatefulWidget {
  const FeedbackFormScreen({
    super.key,
    required this.reporterRole,
    required this.reporterName,
    required this.reporterEmail,
    this.feedbackService,
    this.mediaService,
  });

  final String reporterRole;
  final String reporterName;
  final String reporterEmail;
  final AppFeedbackService? feedbackService;
  final FirebaseMediaService? mediaService;

  @override
  State<FeedbackFormScreen> createState() => _FeedbackFormScreenState();
}

class _FeedbackFormScreenState extends State<FeedbackFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _detailsController = TextEditingController();
  final _screenController = TextEditingController();
  final _appVersionController = TextEditingController(text: '1.0.0');

  String _selectedCategory = 'bug';
  String _selectedSeverity = 'medium';
  bool _isSubmitting = false;

  Uint8List? _imageBytes;
  String? _imageFileName;

  FirebaseMediaService get _mediaService =>
      widget.mediaService ?? FirebaseMediaService();

  AppFeedbackService get _feedbackService =>
      widget.feedbackService ?? AppFeedbackService();

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 80,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() {
      _imageBytes = bytes;
      _imageFileName = picked.name;
    });
  }

  void _removeImage() {
    setState(() {
      _imageBytes = null;
      _imageFileName = null;
    });
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _detailsController.dispose();
    _screenController.dispose();
    _appVersionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      String? imageUrl;
      String? imageStoragePath;

      if (_imageBytes != null && _imageFileName != null) {
        final ext = FirebaseMediaService.inferImageExtension(
          _imageBytes!,
          fileName: _imageFileName,
        );
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final path =
            'feedback-images/${widget.reporterEmail.trim().toLowerCase()}/$timestamp.$ext';
        final contentType = ext == 'png' ? 'image/png' : 'image/jpeg';
        final result = await _mediaService.uploadBytes(
          path: path,
          bytes: _imageBytes!,
          contentType: contentType,
        );
        imageUrl = result;
        imageStoragePath = path;
      }

      await _feedbackService.submitFeedback(
        reporterRole: widget.reporterRole,
        reporterEmail: widget.reporterEmail,
        reporterName: widget.reporterName,
        subject: _subjectController.text,
        details: _detailsController.text,
        category: _selectedCategory,
        severity: _selectedSeverity,
        screenContext: _screenController.text,
        appVersion: _appVersionController.text,
        imageUrl: imageUrl,
        imageStoragePath: imageStoragePath,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Feedback submitted. Thank you for helping improve BrisConnect+.'),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (error, stackTrace) {
      debugPrint('[FeedbackForm] Submit failed: $error');
      debugPrint('[FeedbackForm] Stack trace: $stackTrace');
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not submit feedback. Please try again.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.background,
      appBar: AppBar(
        title: const LogoAppBarTitle('App Feedback'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Report problems, misleading information, or ideas for improvement.',
                style: TextStyle(
                  color: AppPalette.mutedText,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              _buildCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Category',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedCategory,
                      items: const [
                        DropdownMenuItem(value: 'bug', child: Text('Bug')),
                        DropdownMenuItem(value: 'misleading_info', child: Text('Misleading Information')),
                        DropdownMenuItem(value: 'usability', child: Text('Usability')),
                        DropdownMenuItem(value: 'performance', child: Text('Performance')),
                        DropdownMenuItem(value: 'other', child: Text('Other')),
                      ],
                      onChanged: _isSubmitting
                          ? null
                          : (value) {
                              if (value == null) {
                                return;
                              }
                              setState(() => _selectedCategory = value);
                            },
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Severity',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedSeverity,
                      items: const [
                        DropdownMenuItem(value: 'low', child: Text('Low')),
                        DropdownMenuItem(value: 'medium', child: Text('Medium')),
                        DropdownMenuItem(value: 'high', child: Text('High')),
                        DropdownMenuItem(value: 'critical', child: Text('Critical')),
                      ],
                      onChanged: _isSubmitting
                          ? null
                          : (value) {
                              if (value == null) {
                                return;
                              }
                              setState(() => _selectedSeverity = value);
                            },
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _buildCard(
                child: Column(
                  children: [
                    TextFormField(
                      controller: _subjectController,
                      enabled: !_isSubmitting,
                      decoration: const InputDecoration(
                        labelText: 'Subject',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a short subject.';
                        }
                        if (value.trim().length < 5) {
                          return 'Subject should be at least 5 characters.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _detailsController,
                      enabled: !_isSubmitting,
                      minLines: 4,
                      maxLines: 8,
                      decoration: const InputDecoration(
                        labelText: 'Feedback details',
                        hintText: 'Describe what happened and what should be fixed.',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please provide details.';
                        }
                        if (value.trim().length < 15) {
                          return 'Please add more detail so the team can reproduce it.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _screenController,
                      enabled: !_isSubmitting,
                      decoration: const InputDecoration(
                        labelText: 'Screen/page (optional)',
                        hintText: 'Example: Visitor Portal > Events',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _appVersionController,
                      enabled: !_isSubmitting,
                      decoration: const InputDecoration(
                        labelText: 'App version (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _buildCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Screenshot (optional)',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Attach a screenshot to help describe the issue.',
                      style: TextStyle(
                        color: AppPalette.mutedText,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_imageBytes != null) ...[                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.memory(
                          _imageBytes!,
                          width: double.infinity,
                          height: 200,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _imageFileName ?? 'image',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppPalette.mutedText,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _isSubmitting ? null : _removeImage,
                            icon: const Icon(Icons.close, size: 18),
                            label: const Text('Remove'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red.shade700,
                            ),
                          ),
                        ],
                      ),
                    ] else
                      OutlinedButton.icon(
                        onPressed: _isSubmitting ? null : _pickImage,
                        icon: const Icon(Icons.image_rounded),
                        label: const Text('Attach Screenshot'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppPalette.deepBlue,
                          side: const BorderSide(color: AppPalette.deepBlue),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _buildCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Submitted as ${widget.reporterRole.toLowerCase()} (${widget.reporterEmail})',
                      style: const TextStyle(
                        color: AppPalette.mutedText,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Every submission is marked for review and assigned a maintenance target date.',
                      style: TextStyle(
                        color: AppPalette.charcoal,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submit,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(_isSubmitting ? 'Submitting...' : 'Submit Feedback'),
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
    );
  }

  Widget _buildCard({required Widget child}) {
    return Card(
      margin: EdgeInsets.zero,
      color: AppPalette.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppPalette.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}
