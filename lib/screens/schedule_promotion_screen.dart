import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:brisconnect/auth/local_auth.dart';
import 'package:brisconnect/models/business.dart';
import 'package:brisconnect/models/promotion_schedule.dart';
import 'package:brisconnect/screens/subscription_plans_screen.dart';
import 'package:brisconnect/services/ai_post_service.dart';
import 'package:brisconnect/services/best_time_to_post_service.dart';
import 'package:brisconnect/services/firebase_media_service.dart';
import 'package:brisconnect/services/stripe_payment_service.dart';
import 'package:brisconnect/theme/app_palette.dart';

/// Screen for scheduling a new promotion with best-time-to-post guidance.
class SchedulePromotionScreen extends StatefulWidget {
  final BestTimeToPostService? bestTimeService;

  const SchedulePromotionScreen({super.key, this.bestTimeService});

  @override
  State<SchedulePromotionScreen> createState() =>
      _SchedulePromotionScreenState();
}

class _SchedulePromotionScreenState extends State<SchedulePromotionScreen> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _aiPromptCtrl = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  DateTime _scheduledAt = DateTime.now().add(const Duration(hours: 1));
  bool _isLoadingRecommendations = true;
  bool _isLoadingBusinesses = true;
  bool _isCheckingSubscription = true;
  bool _hasActiveSubscription = false;
  bool _isGeneratingAi = false;
  bool _isSubmitting = false;
  String? _aiError;
  BestTimeToPostResult? _recommendationResult;
  String? _softWarning;
  bool _ignoreWarning = false;
  List<Business> _ownerBusinesses = [];
  Business? _selectedBusiness;
  Uint8List? _mediaBytes;
  String? _mediaFileName;
  String? _mediaMimeType;
  bool _isVideoMedia = false;

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
    _loadOwnerBusinesses();
    _loadSubscriptionStatus();
  }

  Future<void> _loadSubscriptionStatus() async {
    final ownerId = LocalAuth.currentLocal?.email ?? '';
    if (ownerId.trim().isEmpty) {
      setState(() => _isCheckingSubscription = false);
      return;
    }
    try {
      final status = await StripePaymentService.getSubscriptionStatus(ownerId);
      if (!mounted) return;
      setState(() {
        _hasActiveSubscription = status['active'] == true;
        _isCheckingSubscription = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCheckingSubscription = false);
    }
  }

  void _openSubscriptionPlans() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const SubscriptionPlansScreen(),
      ),
    );
  }

  Future<void> _loadRecommendations() async {
    final ownerId = LocalAuth.currentLocal?.email ?? '';
    if (ownerId.trim().isEmpty) {
      setState(() => _isLoadingRecommendations = false);
      return;
    }

    final result = await (widget.bestTimeService ?? BestTimeToPostService())
        .getRecommendations(ownerId);

    if (!mounted) return;
    setState(() {
      _recommendationResult = result;
      _isLoadingRecommendations = false;
      _updateSoftWarning();
    });
  }

  Future<void> _loadOwnerBusinesses() async {
    final ownerId = LocalAuth.currentLocal?.email ?? '';
    if (ownerId.trim().isEmpty) {
      setState(() => _isLoadingBusinesses = false);
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('businesses')
          .where('ownerId', isEqualTo: ownerId)
          .where('isActive', isEqualTo: true)
          .where('deletedAt', isNull: true)
          .get();

      final businesses = snapshot.docs.map(Business.fromFirestore).toList();

      if (!mounted) return;
      setState(() {
        _ownerBusinesses = businesses;
        _selectedBusiness = businesses.isNotEmpty ? businesses.first : null;
        _isLoadingBusinesses = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingBusinesses = false);
      debugPrint('[SchedulePromotion] Failed to load owner businesses: $e');
    }
  }

  void _updateSoftWarning() {
    final warning = BestTimeToPostService().warningForSchedule(
      _scheduledAt,
      _recommendationResult?.recommendations ?? const [],
    );
    setState(() {
      _softWarning = warning;
      if (warning == null) _ignoreWarning = false;
    });
  }

  Future<void> _pickScheduleDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledAt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppPalette.ochre,
            onPrimary: Colors.white,
            surface: Color(0xFF1C1C2E),
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledAt),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppPalette.ochre,
            onPrimary: Colors.white,
            surface: Color(0xFF1C1C2E),
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (time == null || !mounted) return;

    setState(() {
      _scheduledAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      _updateSoftWarning();
    });
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      _showSnackBar('Please enter a promotion title.');
      return;
    }

    final ownerId = LocalAuth.currentLocal?.email ?? '';
    if (ownerId.trim().isEmpty) {
      _showSnackBar('You must be signed in to schedule a promotion.');
      return;
    }

    // Soft warning confirmation if not yet acknowledged.
    if (_softWarning != null && !_ignoreWarning) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppPalette.background,
          title: const Text(
            'Timing Warning',
            style: TextStyle(color: Colors.black),
          ),
          content: Text(
            _softWarning!,
            style: const TextStyle(color: AppPalette.mutedText),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Change Time',
                  style: TextStyle(color: Colors.black87)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Schedule Anyway',
                  style: TextStyle(color: AppPalette.ochre)),
            ),
          ],
        ),
      );
      if (proceed != true || !mounted) return;
      setState(() => _ignoreWarning = true);
    }

    if (_selectedBusiness == null || _selectedBusiness!.id == null) {
      _showSnackBar('Please select a business for this promotion.');
      return;
    }

    setState(() => _isSubmitting = true);

    String? mediaUrl;
    String? mediaType;
    if (_mediaBytes != null) {
      try {
        final mimeType = _mediaMimeType ?? 'application/octet-stream';
        mediaType = _isVideoMedia ? 'video' : 'image';
        final ext = _isVideoMedia
            ? (mimeType.split('/').last)
            : FirebaseMediaService.inferImageExtension(
                _mediaBytes!,
                fileName: _mediaFileName,
              );
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final path = 'promotion_media/$ownerId/$timestamp.$ext';
        mediaUrl = await FirebaseMediaService().uploadBytes(
          path: path,
          bytes: _mediaBytes!,
          contentType: mimeType,
        );
      } catch (e) {
        if (mounted) {
          setState(() => _isSubmitting = false);
          _showSnackBar('Could not upload media. Please try again.');
        }
        return;
      }
    }

    final promotion = PromotionSchedule(
      businessId: _selectedBusiness!.id!,
      ownerId: ownerId,
      title: title,
      description: _descCtrl.text.trim(),
      scheduledAt: _scheduledAt,
      endAt: _scheduledAt.add(const Duration(days: 7)),
      status: PromotionStatus.scheduled,
      createdAt: DateTime.now(),
      mediaUrl: mediaUrl,
      mediaType: mediaType,
    );

    await (widget.bestTimeService ?? BestTimeToPostService())
        .recordScheduledPromotion(promotion);

    if (!mounted) return;
    setState(() => _isSubmitting = false);
    _showSnackBar('Promotion scheduled for ${_formatDateTime(_scheduledAt)}');
    Navigator.of(context).pop();
  }

  Future<void> _generateWithAi() async {
    final business = _selectedBusiness;
    if (business == null) {
      _showSnackBar('Please select a business first.');
      return;
    }

    final userPrompt = _aiPromptCtrl.text.trim();

    setState(() {
      _isGeneratingAi = true;
      _aiError = null;
    });

    final extraContext = StringBuffer();
    if (business.description.trim().isNotEmpty) {
      extraContext.writeln('Business description: ${business.description.trim()}');
    }
    if (userPrompt.isNotEmpty) {
      extraContext.writeln('Promotion idea: $userPrompt');
    }

    try {
      final generated = await AiPostService().generatePost(
        postType: 'Promotion',
        businessName: business.businessName,
        category: business.category,
        format: 'title-description',
        extraContext: extraContext.toString().trim(),
      );

      if (!mounted) return;

      // The function returns a title on the first line and a description on
      // the following lines when format is 'title-description'.
      final lines = generated
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();

      String title;
      String description;
      if (lines.length >= 2) {
        title = lines.first;
        description = lines.sublist(1).join(' ');
      } else {
        title = generated.split('.').first.trim();
        description = generated.substring(title.length).trim();
      }

      // Strip markdown heading markers from the title.
      title = title.replaceAll(RegExp(r'^#+\s*'), '').trim();
      if (title.endsWith('.')) {
        title = title.substring(0, title.length - 1);
      }

      setState(() {
        _titleCtrl.text = title;
        _descCtrl.text = description;
        _isGeneratingAi = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isGeneratingAi = false;
        _aiError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (bytes.length > FirebaseMediaService.maxEventImageBytes) {
      if (mounted) _showSnackBar('Photo is too large (max 2 MB).');
      return;
    }
    if (!mounted) return;
    setState(() {
      _mediaBytes = bytes;
      _mediaFileName = picked.name;
      _mediaMimeType = picked.mimeType ?? 'image/jpeg';
      _isVideoMedia = false;
    });
  }

  Future<void> _pickVideo() async {
    final picked = await _picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 2),
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (bytes.length > FirebaseMediaService.maxEventVideoBytes) {
      if (mounted) _showSnackBar('Video is too large (max 50 MB).');
      return;
    }
    if (!mounted) return;
    setState(() {
      _mediaBytes = bytes;
      _mediaFileName = picked.name;
      _mediaMimeType = picked.mimeType ?? 'video/mp4';
      _isVideoMedia = true;
    });
  }

  void _clearMedia() {
    setState(() {
      _mediaBytes = null;
      _mediaFileName = null;
      _mediaMimeType = null;
      _isVideoMedia = false;
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green[700],
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEBF4FF),
      appBar: AppBar(
        title: const Text('Schedule Promotion'),
        backgroundColor: AppPalette.ochre,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildRecommendedTimes(),
              const SizedBox(height: 20),
              _buildForm(),
              const SizedBox(height: 20),
              if (_softWarning != null) _buildWarningCard(),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppPalette.ochre,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        AppPalette.ochre.withValues(alpha: 0.6),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Schedule Promotion',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecommendedTimes() {
    if (_isLoadingRecommendations) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(color: AppPalette.ochre),
        ),
      );
    }

    final result = _recommendationResult;
    if (result == null || !result.hasEnoughData) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppPalette.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            Icon(Icons.lightbulb_outline_rounded,
                color: AppPalette.ochre.withValues(alpha: 0.8)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                result?.insufficientDataReason ??
                    'No timing insights yet. Schedule whenever works for you.',
                style: const TextStyle(
                  color: AppPalette.mutedText,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppPalette.ochre.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recommended windows',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 10),
          ...result.recommendations.map(
            (rec) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: AppPalette.ochre, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      // Show why this window is recommended, not just the
                      // window itself (e.g. "Highest engagement on Fridays
                      // 6-8pm").
                      rec.explanation,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBusinessSelector(),
        const SizedBox(height: 20),
        _buildAiAssistantCard(),
        const SizedBox(height: 16),
        _buildMediaSection(),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _titleCtrl,
          label: 'Promotion Title',
          hint: 'e.g. Weekend Burger Special',
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _descCtrl,
          label: 'Description (optional)',
          hint: 'Brief description of the promotion',
          maxLines: 3,
        ),
        const SizedBox(height: 16),
        InkWell(
          onTap: _pickScheduleDateTime,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppPalette.surface,
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Row(
              children: [
                const Icon(Icons.date_range_rounded,
                    color: AppPalette.ochre, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Scheduled Date & Time',
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatDateTime(_scheduledAt),
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.edit_rounded,
                    color: AppPalette.mutedText, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAiAssistantCard() {
    if (_isCheckingSubscription) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C2E),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppPalette.ochre.withValues(alpha: 0.3)),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            SizedBox(width: 12),
            Text(
              'Checking premium status...',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (!_hasActiveSubscription) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C2E),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppPalette.ochre.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome_rounded,
                    color: AppPalette.ochre.withValues(alpha: 0.9), size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'AI Promotion Assistant',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                Icon(Icons.lock_rounded,
                    color: AppPalette.ochre.withValues(alpha: 0.9), size: 18),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'Unlock AI-generated promotion titles and descriptions with a Premium Subscription.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _openSubscriptionPlans,
                icon: const Icon(Icons.workspace_premium_rounded, size: 18),
                label: const Text('Upgrade to Premium'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppPalette.ochre,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppPalette.ochre.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded,
                  color: AppPalette.ochre.withValues(alpha: 0.9), size: 20),
              const SizedBox(width: 8),
              const Text(
                'AI Promotion Assistant',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Describe your promotion and AI will write the title and description.',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _aiPromptCtrl,
            maxLines: 2,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText:
                  'e.g. 20% off all pasta dishes this Friday and Saturday (optional)',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
              filled: true,
              fillColor: const Color(0xFF2A2A3E),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          if (_aiError != null) ...[
            const SizedBox(height: 10),
            Text(
              _aiError!,
              style: const TextStyle(color: Color(0xFFFF6B6B), fontSize: 13),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isGeneratingAi ? null : _generateWithAi,
              icon: _isGeneratingAi
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.auto_awesome_rounded, size: 18),
              label: Text(_isGeneratingAi ? 'Generating...' : 'Generate'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppPalette.ochre,
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    AppPalette.ochre.withValues(alpha: 0.6),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaSection() {
    if (_isCheckingSubscription) return const SizedBox.shrink();

    if (!_hasActiveSubscription) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C2E),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppPalette.ochre.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.photo_camera_rounded,
                    color: AppPalette.ochre.withValues(alpha: 0.9), size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'AI-Powered Photo & Video',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                Icon(Icons.lock_rounded,
                    color: AppPalette.ochre.withValues(alpha: 0.9), size: 18),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'Upload a photo or video with your promotion and let AI help craft the caption. Unlock with a Premium Subscription.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _openSubscriptionPlans,
                icon: const Icon(Icons.workspace_premium_rounded, size: 18),
                label: const Text('Upgrade to Premium'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppPalette.ochre,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppPalette.ochre.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.photo_camera_rounded,
                  color: AppPalette.ochre.withValues(alpha: 0.9), size: 20),
              const SizedBox(width: 8),
              const Text(
                'AI-Powered Photo & Video',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Add a photo or video and AI will help write a caption that matches it.',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 12),
          if (_mediaBytes != null) ...[
            _buildMediaPreview(),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.image_rounded, size: 18),
                  label: const Text('Add Photo'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(
                        color: AppPalette.ochre.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickVideo,
                  icon: const Icon(Icons.videocam_rounded, size: 18),
                  label: const Text('Add Video'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(
                        color: AppPalette.ochre.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMediaPreview() {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: _isVideoMedia
              ? Container(
                  width: double.infinity,
                  height: 140,
                  color: Colors.black,
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.play_circle_fill_rounded,
                          color: Colors.white, size: 36),
                      const SizedBox(height: 4),
                      Text(
                        _mediaFileName ?? 'Video attached',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                )
              : Image.memory(
                  _mediaBytes!,
                  width: double.infinity,
                  height: 140,
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
                child:
                    Icon(Icons.close_rounded, size: 16, color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.black),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: Colors.black87),
        hintStyle: TextStyle(color: Colors.black.withValues(alpha: 0.4)),
        filled: true,
        fillColor: AppPalette.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              BorderSide(color: AppPalette.ochre.withValues(alpha: 0.5)),
        ),
      ),
    );
  }

  Widget _buildBusinessSelector() {
    if (_isLoadingBusinesses) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppPalette.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text(
              'Loading your businesses...',
              style: TextStyle(color: AppPalette.mutedText, fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (_ownerBusinesses.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppPalette.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: const Row(
          children: [
            Icon(Icons.storefront_rounded, color: AppPalette.mutedText),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'No active businesses found. Create a business profile before scheduling a promotion.',
                style: TextStyle(color: AppPalette.mutedText, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Business>(
          isExpanded: true,
          dropdownColor: AppPalette.surface,
          value: _selectedBusiness,
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: AppPalette.mutedText),
          style: const TextStyle(color: Colors.black, fontSize: 14),
          hint: const Text(
            'Select a business',
            style: TextStyle(color: AppPalette.mutedText),
          ),
          items: _ownerBusinesses.map((business) {
            return DropdownMenuItem<Business>(
              value: business,
              child: Text(
                business.businessName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.black),
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() => _selectedBusiness = value);
            }
          },
        ),
      ),
    );
  }

  Widget _buildWarningCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFF39C12).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: Color(0xFFF39C12), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _softWarning!,
              style: const TextStyle(
                color: AppPalette.mutedText,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final period = date.hour < 12 ? 'am' : 'pm';
    final displayHour = date.hour == 0
        ? 12
        : date.hour > 12
            ? date.hour - 12
            : date.hour;
    final minute = date.minute.toString().padLeft(2, '0');
    return '${date.day} ${months[date.month - 1]} ${date.year} at '
        '$displayHour:$minute$period';
  }
}
