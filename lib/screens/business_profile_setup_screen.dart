import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:brisconnect/auth/local_auth.dart';
import 'package:brisconnect/models/business.dart';
import 'package:brisconnect/services/business_profile_service.dart';
import 'package:brisconnect/services/firebase_media_service.dart';
import 'package:brisconnect/services/address_geocoding_service.dart';
import 'package:brisconnect/services/google_places_autocomplete_service.dart';
import 'package:brisconnect/theme/app_palette.dart';

/// Shown on first login after admin approval.
/// Guides the business owner through setting up their full profile.
class BusinessProfileSetupScreen extends StatefulWidget {
  /// If non-null, the screen is in edit mode for an existing business.
  final Business? existing;
  const BusinessProfileSetupScreen({super.key, this.existing});

  @override
  State<BusinessProfileSetupScreen> createState() =>
      _BusinessProfileSetupScreenState();
}

class _BusinessProfileSetupScreenState
    extends State<BusinessProfileSetupScreen> {
  final _pageController = PageController();
  int _currentPage = 0;
  bool _saving = false;
  bool _uploadingLogo = false;
  bool _uploadingBanner = false;
  String? _logoUrl;
  String? _bannerUrl;
  final _picker = ImagePicker();
  final _mediaService = FirebaseMediaService();
  final _placesService = GooglePlacesAutocompleteService();

  // ── Controllers ──────────────────────────────────────────────────
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _addressFocusNode = FocusNode();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _instagramCtrl = TextEditingController();
  final _facebookCtrl = TextEditingController();
  final _tiktokCtrl = TextEditingController();
  final _menuItemCtrl = TextEditingController();

  String _selectedCategory = businessCategories.first;
  final List<String> _menuItems = [];

  // Opening hours: day → {open, close, isClosed}
  final Map<String, _DayEntry> _hours = {
    for (final d in _kDays) d: _DayEntry(),
  };

  static const _kDays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  @override
  void didUpdateWidget(covariant BusinessProfileSetupScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Hot reload or category list changes can leave _selectedCategory stale.
    if (!businessCategories.contains(_selectedCategory)) {
      _selectedCategory = businessCategories.first;
    }
  }

  @override
  void initState() {
    super.initState();
    // Default to the first valid category in case the list changed.
    _selectedCategory = businessCategories.first;
    final b = widget.existing;
    if (b != null) {
      _nameCtrl.text = b.businessName;
      _descCtrl.text = b.description;
      _addressCtrl.text = b.address;
      _phoneCtrl.text = b.contactNumber;
      _websiteCtrl.text = b.website ?? '';
      _instagramCtrl.text = b.socialMedia?['Instagram'] ?? '';
      _facebookCtrl.text = b.socialMedia?['Facebook'] ?? '';
      _tiktokCtrl.text = b.socialMedia?['TikTok'] ?? '';
      _logoUrl = b.logoUrl;
      _bannerUrl = b.coverImageUrl;
      if (b.menuItems != null) _menuItems.addAll(b.menuItems!);
      if (businessCategories.contains(b.category)) {
        _selectedCategory = b.category;
      }
      if (b.businessHours != null) {
        for (final d in _kDays) {
          final dh = b.businessHours!.getHoursForDay(d);
          if (dh != null) {
            _hours[d] = _DayEntry(
              isClosed: dh.isClosed,
              open: dh.openTime ?? '09:00',
              close: dh.closeTime ?? '17:00',
            );
          }
        }
      }
    }
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl,
      _descCtrl,
      _addressCtrl,
      _phoneCtrl,
      _emailCtrl,
      _websiteCtrl,
      _instagramCtrl,
      _facebookCtrl,
      _tiktokCtrl,
      _menuItemCtrl,
    ]) {
      c.dispose();
    }
    _addressFocusNode.dispose();
    _pageController.dispose();
    super.dispose();
  }

  /// Fetches Brisbane-only address suggestions from Google Places.
  Future<Iterable<String>> _getAddressSuggestions(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return const <String>[];
    try {
      return await _placesService.fetchBrisbaneAddressSuggestions(trimmed);
    } catch (_) {
      return const <String>[];
    }
  }

  // ── Progress ─────────────────────────────────────────────────────
  static const _pages = [
    'Business Info',
    'Location & Hours',
    'Contact & Social',
    'Menu Items',
  ];

  double get _completionPercent {
    int filled = 0;
    if (_nameCtrl.text.trim().isNotEmpty) filled++;
    if (_descCtrl.text.trim().isNotEmpty) filled++;
    if (_addressCtrl.text.trim().isNotEmpty) filled++;
    if (_phoneCtrl.text.trim().isNotEmpty) filled++;
    if (_instagramCtrl.text.trim().isNotEmpty ||
        _facebookCtrl.text.trim().isNotEmpty ||
        _tiktokCtrl.text.trim().isNotEmpty) {
      filled++;
    }
    if (_menuItems.isNotEmpty) {
      filled++;
    }
    return filled / 6;
  }

  Future<void> _pickImage({required bool isLogo}) async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: isLogo ? 400 : 1200,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    final email = LocalAuth.currentLocal?.email ?? 'unknown';
    final ts = DateTime.now().millisecondsSinceEpoch;
    final path = isLogo
        ? 'business_logos/$email/$ts.jpg'
        : 'business_covers/$email/$ts.jpg';
    setState(() => isLogo ? _uploadingLogo = true : _uploadingBanner = true);
    try {
      final url = await _mediaService
          .uploadBytes(path: path, bytes: bytes, contentType: 'image/jpeg')
          .timeout(const Duration(seconds: 30));
      setState(() => isLogo ? _logoUrl = url : _bannerUrl = url);
      debugPrint(
          '[BusinessProfileSetup] uploaded ${isLogo ? 'logo' : 'cover'}: $url');
    } on TimeoutException catch (_) {
      debugPrint('[BusinessProfileSetup] upload timed out');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Upload timed out. Please try a smaller image.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      debugPrint('[BusinessProfileSetup] upload failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Upload failed: $e'),
              backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) {
        setState(
            () => isLogo ? _uploadingLogo = false : _uploadingBanner = false);
      }
    }
  }

  void _goNext() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _save();
    }
  }

  void _goBack() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _save() async {
    final owner = LocalAuth.currentLocal;
    if (owner == null) return;
    final name = _nameCtrl.text.trim();
    final description = _descCtrl.text.trim();
    final address = _addressCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final website = _websiteCtrl.text.trim();

    if (name.isEmpty) {
      _showSnack('Business name is required.');
      return;
    }
    if (_selectedCategory.isEmpty) {
      _showSnack('Please select a category.');
      return;
    }
    if (description.isEmpty) {
      _showSnack('Description is required.');
      return;
    }
    if (address.isEmpty) {
      _showSnack('Address is required.');
      return;
    }
    if (phone.isEmpty) {
      _showSnack('Contact number is required.');
      return;
    }
    if (phone.length < 8 || !RegExp(r'^[0-9\-\+\s\(\)]{8,}$').hasMatch(phone)) {
      _showSnack('Please enter a valid contact number.');
      return;
    }
    if (website.isNotEmpty &&
        !RegExp(r'^(https?:\/\/)?([\w\-]+\.)+[\w\-]+(\/[\w\-\.]*)*$')
            .hasMatch(website)) {
      _showSnack('Please enter a valid website URL.');
      return;
    }

    // Reject addresses that don't plausibly refer to Brisbane before doing
    // any geocoding. geocodeAddress() always resolves to *some* coordinates
    // (falling back to Brisbane CBD) so it can't be relied on alone to
    // reject nonsense/invalid input.
    final addressValidator = AddressGeocodingService();
    final isPlausibleAddress = await addressValidator.isValidAddress(address);
    if (!isPlausibleAddress) {
      _showSnack('Please enter a valid Brisbane business address.');
      return;
    }

    setState(() => _saving = true);

    // Validate and geocode the address before saving. Dev fallback: if
    // geocoding fails (e.g. unsigned macOS build with Cloud Functions
    // INTERNAL error), save without coordinates so the profile can still be
    // created. The user can update coordinates later.
    final geocodingService = AddressGeocodingService();
    LatLng? latLng;
    try {
      latLng = await geocodingService
          .geocodeAddress(address)
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('[BusinessProfileSetup] geocoding failed: $e');
    }

    if (latLng != null &&
        !AddressGeocodingService.isWithinBrisbane(
            latLng.latitude, latLng.longitude)) {
      if (mounted) {
        setState(() => _saving = false);
        _showSnack(
            'Address must be within Brisbane. Please enter a Brisbane address.');
      }
      return;
    }

    if (latLng == null && mounted) {
      _showSnack(
          'Could not verify address location. Saving without map coordinates.');
    }

    // Dev fallback: if geocoding returned no coordinates, default to Brisbane
    // CBD so the business still appears on the map.
    latLng ??= const LatLng(-27.4698, 153.0251);

    final hours = BusinessHours(
      hours: {
        for (final entry in _hours.entries)
          entry.key: DayHours(
            isClosed: entry.value.isClosed,
            openTime: entry.value.open,
            closeTime: entry.value.close,
          ),
      },
    );

    final business = Business(
      id: widget.existing?.id,
      ownerId: owner.email,
      businessName: _nameCtrl.text.trim(),
      category: _selectedCategory,
      description: _descCtrl.text.trim(),
      address: address,
      lat: latLng.latitude,
      lng: latLng.longitude,
      contactNumber: _phoneCtrl.text.trim(),
      website:
          _websiteCtrl.text.trim().isEmpty ? null : _websiteCtrl.text.trim(),
      socialMedia: {
        if (_instagramCtrl.text.trim().isNotEmpty)
          'Instagram': _instagramCtrl.text.trim(),
        if (_facebookCtrl.text.trim().isNotEmpty)
          'Facebook': _facebookCtrl.text.trim(),
        if (_tiktokCtrl.text.trim().isNotEmpty)
          'TikTok': _tiktokCtrl.text.trim(),
      },
      businessHours: hours,
      menuItems: _menuItems.isNotEmpty ? List.unmodifiable(_menuItems) : null,
      logoUrl: _logoUrl,
      coverImageUrl: _bannerUrl,
      isVerified: widget.existing?.isVerified ?? false,
    );

    try {
      final service = BusinessProfileService();
      if (widget.existing?.id != null) {
        await service.updateBusinessProfile(business);
      } else {
        await service.createBusinessProfile(business);
      }

      // Mark profile as completed in local_users
      await FirebaseFirestore.instance
          .collection('local_users')
          .doc(owner.email)
          .set({'profileCompleted': true}, SetOptions(merge: true));

      if (mounted) {
        if (widget.existing != null) {
          _showSnack('Business profile updated successfully.');
          Navigator.pop(context, true);
        } else {
          _showSnack('Business profile created successfully.');
          Navigator.pushReplacementNamed(context, '/local/portal');
        }
      }
    } catch (e) {
      _showSnack('Save failed: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Widget _buildApprovalBlockedScreen(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEBF4FF),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline,
                      color: AppPalette.ochre, size: 64),
                  const SizedBox(height: 24),
                  const Text(
                    'Account Pending Approval',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Your Local account must be approved by an admin before you can create a business profile.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: AppPalette.mutedText, fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: 28),
                  ElevatedButton(
                    onPressed: () async {
                      await LocalAuth.logout();
                      if (context.mounted) {
                        Navigator.of(context).pushNamedAndRemoveUntil(
                            '/welcome', (route) => false);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppPalette.ochre,
                      foregroundColor: Colors.black,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Back to Welcome',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;

    // Defence-in-depth: only approved Local users may create or edit a
    // business profile. Login already blocks unapproved users, but this
    // prevents any stale session or deep-link from reaching the form.
    if (!isEdit && !LocalAuth.isApprovedLocal) {
      return _buildApprovalBlockedScreen(context);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFEBF4FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFEBF4FF),
        elevation: 0,
        leading: isEdit
            ? IconButton(
                icon: const Icon(Icons.close, color: Colors.black),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        automaticallyImplyLeading: isEdit,
        title: Text(
          isEdit ? 'Edit Business Profile' : 'Complete Your Business Profile',
          style: const TextStyle(
              color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            children: [
              // Progress bar
              LinearProgressIndicator(
                value: (_currentPage + 1) / _pages.length,
                backgroundColor: AppPalette.surface,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppPalette.ochre),
                minHeight: 3,
              ),
              _buildProgressHeader(),
              // Pages
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  children: [
                    _pageBusinessInfo(),
                    _pageLocationHours(),
                    _pageContactSocial(),
                    _pageMenuItems(),
                  ],
                ),
              ),
              // Bottom buttons
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: _buildBottomBar(isEdit),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Progress header: step circles + labels + % complete pill ───────
  Widget _buildProgressHeader() {
    return Container(
      color: const Color(0xFFEBF4FF),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Step ${_currentPage + 1} of ${_pages.length}',
                style: const TextStyle(
                    color: AppPalette.charcoal,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppPalette.ochre.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${((_completionPercent) * 100).round()}% complete',
                  style: const TextStyle(
                      color: AppPalette.ochre,
                      fontSize: 11,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(_pages.length * 2 - 1, (idx) {
              if (idx.isOdd) {
                final leftStep = idx ~/ 2;
                final connected = leftStep < _currentPage;
                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.only(top: 16),
                    height: 2,
                    color: connected ? AppPalette.ochre : AppPalette.border,
                  ),
                );
              }
              final i = idx ~/ 2;
              final active = i == _currentPage;
              final done = i < _currentPage;
              return SizedBox(
                width: 78,
                child: Column(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color:
                            (done || active) ? AppPalette.ochre : Colors.white,
                        border: active
                            ? Border.all(color: AppPalette.ochre, width: 2.5)
                            : done
                                ? null
                                : Border.all(
                                    color: AppPalette.border, width: 1.5),
                        boxShadow: active
                            ? [
                                BoxShadow(
                                  color:
                                      AppPalette.ochre.withValues(alpha: 0.35),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: done
                            ? const Icon(Icons.check,
                                size: 16, color: Colors.white)
                            : Text(
                                '${i + 1}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: active
                                      ? Colors.white
                                      : AppPalette.mutedText,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _pages[i],
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: active ? FontWeight.bold : FontWeight.w600,
                        color: active ? AppPalette.ochre : AppPalette.charcoal,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ── Bottom bar: full-width on mobile, compact + spread on desktop ──
  Widget _buildBottomBar(bool isEdit) {
    final isDesktop = MediaQuery.of(context).size.width >= 700;
    final nextLabel = _currentPage == _pages.length - 1
        ? (isEdit ? 'Save Changes' : 'Save & Enter App')
        : 'Next';

    final backButton = OutlinedButton(
      onPressed: _saving ? null : _goBack,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.black,
        side: const BorderSide(color: Color(0xFFCBD5E1)),
        padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 24 : 14, vertical: isDesktop ? 12 : 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: const Text('Back'),
    );

    final nextButton = ElevatedButton(
      onPressed: _saving ? null : _goNext,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppPalette.ochre,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 28 : 14, vertical: isDesktop ? 12 : 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: _saving
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white),
            )
          : Text(nextLabel,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
    );

    if (isDesktop) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _currentPage > 0 ? backButton : const SizedBox.shrink(),
          nextButton,
        ],
      );
    }

    return Row(
      children: [
        if (_currentPage > 0) Expanded(child: backButton),
        if (_currentPage > 0) const SizedBox(width: 12),
        Expanded(flex: 2, child: nextButton),
      ],
    );
  }

  // ── Page 1: Business Info ──────────────────────────────────────────
  Widget _pageBusinessInfo() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Business Info', Icons.store_rounded),
          const SizedBox(height: 16),
          _field('Business Name *', _nameCtrl, hint: 'e.g. The Coffee Corner'),
          const SizedBox(height: 16),
          _label('Category'),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: _selectedCategory,
            dropdownColor: AppPalette.surface,
            style: const TextStyle(color: Colors.black),
            decoration: _inputDec('Select a category'),
            items: businessCategories
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (v) => setState(() => _selectedCategory = v!),
          ),
          const SizedBox(height: 16),
          _field('Description', _descCtrl,
              hint: 'Tell customers what makes your business special…',
              maxLines: 4),
          const SizedBox(height: 20),
          _sectionTitle('Photos', Icons.photo_camera_rounded),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppPalette.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: AppPalette.ochre.withValues(alpha: 0.25), width: 1.4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _label('Cover photo'),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => _pickImage(isLogo: false),
                  child: Container(
                    height: 120,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEBF4FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppPalette.ochre.withValues(alpha: 0.3)),
                      image: (_bannerUrl ?? '').isNotEmpty
                          ? DecorationImage(
                              image: NetworkImage(_bannerUrl!),
                              fit: BoxFit.cover)
                          : null,
                    ),
                    child: _uploadingBanner
                        ? const Center(
                            child: CircularProgressIndicator(
                                color: AppPalette.ochre))
                        : (_bannerUrl ?? '').isEmpty
                            ? const Center(
                                child: Icon(Icons.add_photo_alternate_rounded,
                                    color: AppPalette.ochre, size: 28))
                            : null,
                  ),
                ),
                const SizedBox(height: 8),
                _photoActionButton(
                  label: (_bannerUrl ?? '').isEmpty
                      ? 'Add cover photo'
                      : 'Change cover',
                  icon: Icons.image_rounded,
                  onTap: () => _pickImage(isLogo: false),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Recommended: 1200×400px (3:1 ratio), JPG or PNG, max 5MB',
                  style: TextStyle(color: AppPalette.mutedText, fontSize: 11),
                ),
                const SizedBox(height: 20),
                _label('Business logo / profile photo'),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: () => _pickImage(isLogo: true),
                      child: Container(
                        width: 116,
                        height: 116,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEBF4FF),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: AppPalette.ochre.withValues(alpha: 0.3),
                              width: 1.4),
                          image: (_logoUrl ?? '').isNotEmpty
                              ? DecorationImage(
                                  image: NetworkImage(_logoUrl!),
                                  fit: BoxFit.cover)
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
                            : (_logoUrl ?? '').isEmpty
                                ? const Icon(Icons.add_a_photo_rounded,
                                    color: AppPalette.ochre, size: 34)
                                : null,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Shown on your business card and profile header',
                            style: TextStyle(
                                color: AppPalette.mutedText,
                                fontSize: 12,
                                height: 1.4),
                          ),
                          const SizedBox(height: 8),
                          _photoActionButton(
                            label: (_logoUrl ?? '').isEmpty
                                ? 'Add logo'
                                : 'Change logo',
                            icon: Icons.photo_camera_rounded,
                            onTap: () => _pickImage(isLogo: true),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _photoActionButton(
      {required String label,
      required IconData icon,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppPalette.ochre,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 15),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _pageLocationHours() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Location & Hours', Icons.location_on_rounded),
          const SizedBox(height: 16),
          _addressAutocompleteField(),
          const SizedBox(height: 20),
          _label('Opening Hours'),
          const SizedBox(height: 10),
          ..._kDays.map((day) => _buildDayRow(day)),
        ],
      ),
    );
  }

  Widget _addressAutocompleteField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Street Address *'),
        const SizedBox(height: 6),
        RawAutocomplete<String>(
          textEditingController: _addressCtrl,
          focusNode: _addressFocusNode,
          optionsBuilder: (value) => _getAddressSuggestions(value.text),
          onSelected: (selection) {
            _addressCtrl.text = selection;
            setState(() {});
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
              style: const TextStyle(color: AppPalette.charcoal),
              onChanged: (_) => setState(() {}),
              decoration: _inputDec('e.g. 123 Queen St, Brisbane QLD 4000'),
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(10),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width - 40,
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
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
                              color: AppPalette.charcoal,
                              fontSize: 13,
                            ),
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

  Widget _buildDayRow(String day) {
    final entry = _hours[day]!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(day.substring(0, 3),
                style: const TextStyle(
                    color: Colors.black87, fontWeight: FontWeight.w500)),
          ),
          Switch(
            value: !entry.isClosed,
            activeThumbColor: AppPalette.ochre,
            onChanged: (v) =>
                setState(() => _hours[day] = entry.copyWith(isClosed: !v)),
          ),
          if (!entry.isClosed) ...[
            const SizedBox(width: 4),
            _timeChip(entry.open,
                (t) => setState(() => _hours[day] = entry.copyWith(open: t))),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Text('–', style: TextStyle(color: Colors.black54)),
            ),
            _timeChip(entry.close,
                (t) => setState(() => _hours[day] = entry.copyWith(close: t))),
          ] else
            const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Text('Closed',
                  style: TextStyle(color: AppPalette.mutedText, fontSize: 13)),
            ),
        ],
      ),
    );
  }

  Widget _timeChip(String time, void Function(String) onChanged) {
    return GestureDetector(
      onTap: () async {
        final parts = time.split(':');
        final picked = await showTimePicker(
          context: context,
          initialTime: TimeOfDay(
            hour: int.tryParse(parts[0]) ?? 9,
            minute: int.tryParse(parts[1]) ?? 0,
          ),
          builder: (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(
              colorScheme: const ColorScheme.dark(primary: AppPalette.ochre),
            ),
            child: child!,
          ),
        );
        if (picked != null) {
          onChanged(
              '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}');
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A3E),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(time,
            style: const TextStyle(color: Colors.white, fontSize: 13)),
      ),
    );
  }

  // ── Page 3: Contact & Social ───────────────────────────────────────
  Widget _pageContactSocial() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Contact & Social', Icons.contact_phone_rounded),
          const SizedBox(height: 16),
          _field('Phone Number *', _phoneCtrl,
              hint: 'e.g. 07 3000 0000', keyboardType: TextInputType.phone),
          const SizedBox(height: 14),
          _field('Email (optional)', _emailCtrl,
              hint: 'hello@yourbusiness.com.au',
              keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 14),
          _field('Website (optional)', _websiteCtrl,
              hint: 'https://yourbusiness.com.au',
              keyboardType: TextInputType.url),
          const SizedBox(height: 20),
          _sectionTitle('Social Media', Icons.share_rounded),
          const SizedBox(height: 14),
          _socialField(Icons.camera_alt_rounded, 'Instagram', _instagramCtrl,
              'https://instagram.com/yourbusiness'),
          const SizedBox(height: 12),
          _socialField(Icons.facebook_rounded, 'Facebook', _facebookCtrl,
              'https://facebook.com/yourbusiness'),
          const SizedBox(height: 12),
          _socialField(Icons.music_note_rounded, 'TikTok', _tiktokCtrl,
              'https://tiktok.com/@yourbusiness'),
        ],
      ),
    );
  }

  Widget _socialField(
      IconData icon, String label, TextEditingController ctrl, String hint) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppPalette.ochre.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppPalette.ochre, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(child: _field(label, ctrl, hint: hint)),
      ],
    );
  }

  // ── Page 4: Menu Items ─────────────────────────────────────────────
  Widget _pageMenuItems() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Menu / Services', Icons.restaurant_menu_rounded),
          const SizedBox(height: 8),
          const Text(
            'Add your key menu items, services or products. You can edit these later from your Business Profile.',
            style: TextStyle(
                color: AppPalette.mutedText, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _menuItemCtrl,
                  style: const TextStyle(color: AppPalette.charcoal),
                  decoration: _inputDec('e.g. Flat White – \$5.50'),
                  onSubmitted: (_) => _addMenuItem(),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: _addMenuItem,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppPalette.ochre,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(56, 50),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_menuItems.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppPalette.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text(
                  'No items yet. Add your first menu item above.',
                  style: TextStyle(color: AppPalette.mutedText, fontSize: 13),
                ),
              ),
            )
          else
            ...List.generate(_menuItems.length, (i) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppPalette.surface,
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.drag_indicator_rounded,
                        color: AppPalette.mutedText, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(_menuItems[i],
                          style: const TextStyle(
                              color: Colors.black, fontSize: 14)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: AppPalette.mutedText, size: 18),
                      onPressed: () => setState(() => _menuItems.removeAt(i)),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              );
            }),
          const SizedBox(height: 20),
          _infoBox(
              'You\'re almost done! Click "Save & Enter App" to publish your profile and access your dashboard.'),
        ],
      ),
    );
  }

  void _addMenuItem() {
    final text = _menuItemCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _menuItems.add(text);
      _menuItemCtrl.clear();
    });
  }

  // ── Shared helpers ─────────────────────────────────────────────────
  Widget _sectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppPalette.ochre, size: 20),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                color: Colors.black,
                fontSize: 17,
                fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _label(String text) => Text(text,
      style: const TextStyle(
          color: Colors.black87, fontSize: 13, fontWeight: FontWeight.w500));

  Widget _field(
    String label,
    TextEditingController ctrl, {
    String? hint,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: const TextStyle(color: AppPalette.charcoal),
          onChanged: (_) => setState(() {}),
          decoration: _inputDec(hint ?? ''),
        ),
      ],
    );
  }

  InputDecoration _inputDec(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppPalette.mutedText, fontSize: 13),
        filled: true,
        fillColor: AppPalette.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppPalette.ochre),
        ),
      );

  Widget _infoBox(String text) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppPalette.ochre.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppPalette.ochre.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded,
                color: AppPalette.ochre, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text,
                  style: const TextStyle(
                      color: Colors.black87, fontSize: 12, height: 1.4)),
            ),
          ],
        ),
      );
}

// ── Internal day entry model ───────────────────────────────────────────
class _DayEntry {
  final bool isClosed;
  final String open;
  final String close;

  const _DayEntry({
    this.isClosed = false,
    this.open = '09:00',
    this.close = '17:00',
  });

  _DayEntry copyWith({bool? isClosed, String? open, String? close}) =>
      _DayEntry(
        isClosed: isClosed ?? this.isClosed,
        open: open ?? this.open,
        close: close ?? this.close,
      );
}
