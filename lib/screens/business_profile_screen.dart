import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:brisconnect/auth/local_auth.dart';
import 'package:brisconnect/models/business.dart';
import 'package:brisconnect/screens/business_profile_setup_screen.dart';
import 'package:brisconnect/services/business_profile_service.dart';
import 'package:brisconnect/services/firebase_media_service.dart';
import 'package:brisconnect/theme/app_palette.dart';

/// Screen 3 of the Local portal — Business Profile viewer/editor.
/// Shows the current profile and an Edit / Complete Profile button.
class BusinessProfileScreen extends StatefulWidget {
  const BusinessProfileScreen({super.key});

  @override
  State<BusinessProfileScreen> createState() => _BusinessProfileScreenState();
}

class _BusinessProfileScreenState extends State<BusinessProfileScreen> {
  Business? _business;
  bool _loading = true;
  bool _profileCompleted = false;
  bool _uploadingLogo = false;
  bool _uploadingBanner = false;
  final _picker = ImagePicker();
  final _mediaService = FirebaseMediaService();
  final _profileService = BusinessProfileService();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final email = LocalAuth.currentLocal?.email;
    if (email == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final profiles =
          await BusinessProfileService().getUserBusinessProfiles(email);
      setState(() {
        _business = profiles.isNotEmpty ? profiles.first : null;
        _profileCompleted = _business != null &&
            _business!.businessName.isNotEmpty &&
            _business!.address.isNotEmpty &&
            _business!.contactNumber.isNotEmpty;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  int get _completionPct {
    if (_business == null) return 0;
    final b = _business!;
    int score = 0;
    if (b.businessName.isNotEmpty) score += 20;
    if (b.description.isNotEmpty) score += 15;
    if (b.address.isNotEmpty) score += 15;
    if (b.contactNumber.isNotEmpty) score += 15;
    if ((b.logoUrl ?? '').isNotEmpty) score += 10;
    if ((b.coverImageUrl ?? '').isNotEmpty) score += 10;
    if (b.businessHours != null) score += 10;
    if ((b.socialMedia ?? {}).isNotEmpty) score += 5;
    return score;
  }

  Future<void> _openEdit() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => BusinessProfileSetupScreen(existing: _business),
      ),
    );
    if (result == true) _load();
  }

  Future<void> _uploadImage({required bool isLogo}) async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: isLogo ? 400 : 1200,
    );
    if (picked == null || _business == null) return;
    final bytes = await picked.readAsBytes();
    final email = LocalAuth.currentLocal?.email ?? 'unknown';
    final path = isLogo
        ? 'business_logos/$email/${DateTime.now().millisecondsSinceEpoch}.jpg'
        : 'business_covers/$email/${DateTime.now().millisecondsSinceEpoch}.jpg';

    setState(() => isLogo ? _uploadingLogo = true : _uploadingBanner = true);
    try {
      final url = await _mediaService.uploadBytes(
        path: path, bytes: bytes, contentType: 'image/jpeg');
      final updated = isLogo
          ? _business!.copyWith(logoUrl: url)
          : _business!.copyWith(coverImageUrl: url);
      await _profileService.updateBusinessProfile(updated);
      setState(() => _business = updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isLogo ? '✓ Logo updated' : '✓ Banner updated'),
          backgroundColor: AppPalette.ochre,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Upload failed: $e'),
          backgroundColor: Colors.redAccent,
        ));
      }
    } finally {
      if (mounted) setState(() => isLogo ? _uploadingLogo = false : _uploadingBanner = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0D1117),
        body: Center(child: CircularProgressIndicator(color: AppPalette.ochre)),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            if (_business == null)
              SliverFillRemaining(child: _buildNoProfile())
            else ...[
              SliverToBoxAdapter(child: _buildCompletionBanner()),
              SliverToBoxAdapter(child: _buildCoverAndLogo()),
              SliverToBoxAdapter(child: _buildInfoSection()),
              SliverToBoxAdapter(child: _buildMenuSection()),
              SliverToBoxAdapter(child: _buildHoursSection()),
              SliverToBoxAdapter(child: _buildPhotosSection()),
              SliverToBoxAdapter(child: _buildContactSection()),
              SliverToBoxAdapter(child: _buildSocialSection()),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ],
        ),
      ),
    );
  }

  // ── Header with Edit / Complete Profile button ──────────────────────
  Widget _buildHeader() {
    final pct = _completionPct;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Business Profile',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
            ),
          ),
          GestureDetector(
            onTap: _openEdit,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _profileCompleted
                    ? AppPalette.ochre
                    : const Color(0xFFE74C3C),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _profileCompleted ? Icons.edit_rounded : Icons.circle,
                    color: Colors.white,
                    size: _profileCompleted ? 16 : 10,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _profileCompleted
                        ? 'Edit Profile'
                        : 'Complete Profile ($pct%)',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Logout button
          GestureDetector(
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: const Color(0xFF1C1C2E),
                  title: const Text('Log Out',
                      style: TextStyle(color: Colors.white)),
                  content: const Text('Are you sure you want to log out?',
                      style: TextStyle(color: Color(0xFF8B8FA8))),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel',
                          style: TextStyle(color: Colors.white70)),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Log Out',
                          style: TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              );
              if (confirm == true && mounted) {
                await LocalAuth.logout();
                Navigator.pushNamedAndRemoveUntil(
                    context, '/', (_) => false);
              }
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C2E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: Colors.redAccent.withValues(alpha: 0.4)),
              ),
              child: const Icon(Icons.logout_rounded,
                  color: Colors.redAccent, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  // ── Completion Banner ───────────────────────────────────────────────
  Widget _buildCompletionBanner() {
    final pct = _completionPct;
    if (pct >= 100) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: AppPalette.ochre.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline_rounded,
                  color: AppPalette.ochre, size: 16),
              const SizedBox(width: 8),
              Text(
                'Profile $pct% complete',
                style: const TextStyle(
                    color: AppPalette.ochre,
                    fontWeight: FontWeight.bold,
                    fontSize: 13),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _openEdit,
                child: const Text('Finish →',
                    style: TextStyle(
                        color: AppPalette.ochre,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct / 100,
              backgroundColor: const Color(0xFF2A2A3E),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppPalette.ochre),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoverAndLogo() {
    final b = _business!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Banner ──────────────────────────────────────────────────
        GestureDetector(
          onTap: () => _uploadImage(isLogo: false),
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            height: 150,
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C2E),
              borderRadius: BorderRadius.circular(16),
              image: (b.coverImageUrl ?? '').isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(b.coverImageUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: _uploadingBanner
                ? const Center(
                    child: CircularProgressIndicator(color: AppPalette.ochre))
                : Stack(
                    children: [
                      if ((b.coverImageUrl ?? '').isEmpty)
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add_photo_alternate_rounded,
                                  color: Colors.white.withValues(alpha: 0.45),
                                  size: 32),
                              const SizedBox(height: 4),
                              Text('Tap to add banner',
                                  style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.45),
                                      fontSize: 12)),
                            ],
                          ),
                        ),
                      // Edit icon (top-right when banner exists)
                      if ((b.coverImageUrl ?? '').isNotEmpty)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.edit_rounded,
                                color: Colors.white, size: 15),
                          ),
                        ),
                    ],
                  ),
          ),
        ),

        // ── Profile pic + name row ────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Profile picture — overlaps banner by 30px
              Transform.translate(
                offset: const Offset(0, -30),
                child: GestureDetector(
                  onTap: () => _uploadImage(isLogo: true),
                  child: Stack(
                    children: [
                      Container(
                        width: 86,
                        height: 86,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A2A3E),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: const Color(0xFF0D1117), width: 4),
                          image: (b.logoUrl ?? '').isNotEmpty
                              ? DecorationImage(
                                  image: NetworkImage(b.logoUrl!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: _uploadingLogo
                            ? const Center(
                                child: SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppPalette.ochre)))
                            : (b.logoUrl ?? '').isEmpty
                                ? const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                        Icon(Icons.add_a_photo_rounded,
                                            color: AppPalette.ochre, size: 26),
                                        SizedBox(height: 2),
                                        Text('Logo',
                                            style: TextStyle(
                                                color: AppPalette.ochre,
                                                fontSize: 9,
                                                fontWeight: FontWeight.w600)),
                                      ])
                                : null,
                      ),
                      // Camera badge
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: const BoxDecoration(
                            color: AppPalette.ochre,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt_rounded,
                              color: Colors.white, size: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Business name + category (pushed down to align with base of circle)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        b.businessName.isNotEmpty
                            ? b.businessName
                            : 'Your Business',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppPalette.ochre.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(b.category,
                                style: const TextStyle(
                                    color: AppPalette.ochre,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600)),
                          ),
                          if (b.isVerified) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.verified_rounded,
                                color: Color(0xFF4F8FFF), size: 14),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Business Info ───────────────────────────────────────────────────
  Widget _buildInfoSection() {
    final b = _business!;
    if (b.description.isEmpty && b.address.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (b.description.isNotEmpty) ...[
            Text(b.description,
                style: const TextStyle(
                    color: Color(0xFFB0B3C1),
                    fontSize: 13,
                    height: 1.5)),
            const SizedBox(height: 8),
          ],
          if (b.address.isNotEmpty)
            _infoRow(Icons.location_on_rounded, b.address),
        ],
      ),
    );
  }

  // ── Opening Hours ───────────────────────────────────────────────────
  Widget _buildHoursSection() {
    final b = _business!;
    if (b.businessHours == null) return const SizedBox.shrink();
    const days = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday',
    ];
    return _card(
      title: 'Opening Hours',
      icon: Icons.schedule_rounded,
      child: Column(
        children: days.map((day) {
          final dh = b.businessHours!.getHoursForDay(day);
          if (dh == null) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                SizedBox(
                  width: 90,
                  child: Text(day.substring(0, 3),
                      style: const TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w500,
                          fontSize: 13)),
                ),
                Text(
                  dh.isClosed ? 'Closed' : dh.getDisplayText(),
                  style: TextStyle(
                    color: dh.isClosed
                        ? const Color(0xFFE74C3C)
                        : Colors.white,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Contact ─────────────────────────────────────────────────────────
  Widget _buildContactSection() {
    final b = _business!;
    return _card(
      title: 'Contact Details',
      icon: Icons.contact_phone_rounded,
      child: Column(
        children: [
          if (b.contactNumber.isNotEmpty)
            _infoRow(Icons.phone_rounded, b.contactNumber),
          if ((b.website ?? '').isNotEmpty)
            _infoRow(Icons.language_rounded, b.website!),
        ],
      ),
    );
  }

  // ── Social ──────────────────────────────────────────────────────────
  Widget _buildMenuSection() {
    final items = _business?.menuItems;
    return _card(
      title: 'Menu / Services',
      icon: Icons.restaurant_menu_rounded,
      editLabel: 'Edit',
      onEdit: _openEdit,
      child: (items == null || items.isEmpty)
          ? GestureDetector(
              onTap: _openEdit,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A3E),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppPalette.ochre.withValues(alpha: 0.3),
                      style: BorderStyle.solid),
                ),
                child: const Center(
                  child: Text('+ Add menu items',
                      style: TextStyle(
                          color: AppPalette.ochre,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ),
              ),
            )
          : Column(
              children: items.map((item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    const Icon(Icons.circle, color: AppPalette.ochre, size: 6),
                    const SizedBox(width: 10),
                    Expanded(child: Text(item,
                        style: const TextStyle(color: Color(0xFFB0B3C1), fontSize: 13))),
                  ],
                ),
              )).toList(),
            ),
    );
  }

  Widget _buildPhotosSection() {
    final photos = _business?.photos ?? [];
    return _card(
      title: 'Photos',
      icon: Icons.photo_library_rounded,
      editLabel: '+ Add',
      onEdit: () => _pickAndUploadPhoto(),
      child: photos.isEmpty
          ? GestureDetector(
              onTap: _pickAndUploadPhoto,
              child: Container(
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A3E),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppPalette.ochre.withValues(alpha: 0.3)),
                ),
                child: const Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.add_photo_alternate_rounded,
                        color: AppPalette.ochre, size: 24),
                    SizedBox(height: 4),
                    Text('Tap to add photos',
                        style: TextStyle(color: AppPalette.ochre, fontSize: 12)),
                  ]),
                ),
              ),
            )
          : GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3, crossAxisSpacing: 6, mainAxisSpacing: 6),
              itemCount: photos.length + 1,
              itemBuilder: (_, i) {
                if (i == photos.length) {
                  return GestureDetector(
                    onTap: _pickAndUploadPhoto,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A2A3E),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppPalette.ochre.withValues(alpha: 0.3)),
                      ),
                      child: const Icon(Icons.add_rounded, color: AppPalette.ochre),
                    ),
                  );
                }
                return ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(photos[i], fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                          color: const Color(0xFF2A2A3E),
                          child: const Icon(Icons.broken_image_rounded,
                              color: Color(0xFF8B8FA8)))),
                );
              },
            ),
    );
  }

  Future<void> _pickAndUploadPhoto() async {
    final picked = await _picker.pickImage(
        source: ImageSource.gallery, imageQuality: 80, maxWidth: 1200);
    if (picked == null || _business == null) return;
    final bytes = await picked.readAsBytes();
    final email = LocalAuth.currentLocal?.email ?? 'unknown';
    final path = 'business_photos/$email/${DateTime.now().millisecondsSinceEpoch}.jpg';
    try {
      final url = await _mediaService.uploadBytes(
          path: path, bytes: bytes, contentType: 'image/jpeg');
      final current = List<String>.from(_business!.photos ?? [])..add(url);
      final updated = _business!.copyWith(photos: current);
      await _profileService.updateBusinessProfile(updated);
      setState(() => _business = updated);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('\u2713 Photo added'),
              backgroundColor: AppPalette.ochre));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'),
              backgroundColor: Colors.redAccent));
    }
  }

  Widget _buildSocialSection() {
    final social = _business?.socialMedia ?? {};
    if (social.isEmpty) return const SizedBox.shrink();
    return _card(
      title: 'Social Media',
      icon: Icons.share_rounded,
      child: Column(
        children: social.entries.map((e) {
          final icon = _socialIcon(e.key);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                Icon(icon, color: AppPalette.ochre, size: 16),
                const SizedBox(width: 10),
                Text(e.key,
                    style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                        fontSize: 13)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(e.value,
                      style: const TextStyle(
                          color: Color(0xFF4F8FFF), fontSize: 12),
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildNoProfile() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.storefront_outlined,
                color: Colors.white.withValues(alpha: 0.2), size: 64),
            const SizedBox(height: 16),
            const Text('No Business Profile Yet',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              'Create your business profile to appear on the BrisConnect map and attract customers.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Color(0xFF8B8FA8), fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _openEdit,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create Business Profile'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppPalette.ochre,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Shared helpers ──────────────────────────────────────────────────
  Widget _card(
      {required String title,
      required IconData icon,
      required Widget child,
      String? editLabel,
      VoidCallback? onEdit}) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppPalette.ochre, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14))),
              if (editLabel != null && onEdit != null)
                GestureDetector(
                  onTap: onEdit,
                  child: Text(editLabel,
                      style: const TextStyle(
                          color: AppPalette.ochre,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF8B8FA8), size: 15),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    color: Color(0xFFB0B3C1), fontSize: 13)),
          ),
        ],
      ),
    );
  }

  IconData _socialIcon(String platform) {
    switch (platform.toLowerCase()) {
      case 'instagram':
        return Icons.camera_alt_rounded;
      case 'facebook':
        return Icons.facebook_rounded;
      case 'tiktok':
        return Icons.music_note_rounded;
      default:
        return Icons.link_rounded;
    }
  }
}
