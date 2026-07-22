import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:brisconnect/auth/local_auth.dart';
import 'package:brisconnect/services/ai_post_service.dart';
import 'package:brisconnect/services/business_profile_service.dart';
import 'package:brisconnect/theme/app_palette.dart';

/// Bottom sheet for AI-powered social media post generation.
class AiPostSheet extends StatefulWidget {
  final String initialType;
  const AiPostSheet({super.key, this.initialType = '📅 New Event'});

  @override
  State<AiPostSheet> createState() => _AiPostSheetState();
}

class _AiPostSheetState extends State<AiPostSheet> {
  static const _postTypes = [
    '📅 New Event',
    '🎉 Promotion',
    '📣 Announcement',
    '⭐ Review Highlight',
    '🍽️ Menu Feature',
  ];

  late String _selectedType;
  final _extraCtrl = TextEditingController();
  String? _generatedPost;
  bool _generating = false;
  String? _error;
  String _businessName = '';
  String _category = '';

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType;
    _loadBusiness();
  }

  Future<void> _loadBusiness() async {
    final email = LocalAuth.currentLocal?.email;
    if (email == null) return;
    try {
      final list =
          await BusinessProfileService().getUserBusinessProfiles(email);
      if (list.isNotEmpty && mounted) {
        setState(() {
          _businessName = list.first.businessName;
          _category = list.first.category;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _extraCtrl.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    if (_businessName.isEmpty) {
      setState(() => _error =
          'Complete your Business Profile first so AI knows your business name.');
      return;
    }
    setState(() {
      _generating = true;
      _error = null;
      _generatedPost = null;
    });
    try {
      final post = await AiPostService.generatePost(
        postType: _selectedType.replaceAll(RegExp(r'[^\x20-\x7E]'), '').trim(),
        businessName: _businessName,
        category: _category,
        extraContext: _extraCtrl.text,
      );
      setState(() => _generatedPost = post);
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

  void _copy() {
    if (_generatedPost == null) return;
    Clipboard.setData(ClipboardData(text: _generatedPost!));
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
                    _error = null;
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
                    child: Text(type,
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

            // Extra context
            const Text('Extra details (optional)',
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            TextField(
              controller: _extraCtrl,
              maxLines: 2,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'e.g. "Friday night live music 7-10pm, free entry"',
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
            ),
            const SizedBox(height: 16),

            // Generate button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _generating ? null : _generate,
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
                        onPressed: _generate,
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
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A3E),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppPalette.ochre.withValues(alpha: 0.3)),
                ),
                child: Text(
                  _generatedPost!,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 14, height: 1.55),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
