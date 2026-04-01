import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:brisconnect/auth/app_user_role.dart';
import 'package:brisconnect/auth/local_auth.dart';
import 'package:brisconnect/models/event_item.dart';
import 'package:brisconnect/screens/add_event_screen.dart';
import 'package:brisconnect/screens/attraction_detail_screen.dart';
import 'package:brisconnect/screens/local_edit_event_screen.dart';
import 'package:brisconnect/screens/local_event_detail_screen.dart';
import 'package:brisconnect/screens/local_notifications_screen.dart';
import 'package:brisconnect/screens/local_settings_screen.dart';
import 'package:brisconnect/screens/profile_camera_capture_screen.dart';
import 'package:brisconnect/screens/welcome_screen.dart';
import 'package:brisconnect/services/approved_attraction_service.dart';
import 'package:brisconnect/services/discover_data_service.dart';
import 'package:brisconnect/services/local_event_service.dart';
import 'package:brisconnect/services/visitor_notification_service.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/utils/profile_image_utils.dart';
import 'package:brisconnect/widgets/role_guard.dart';
import 'package:brisconnect/widgets/reusable_event_card.dart';
import 'package:brisconnect/widgets/reusable_management_card.dart';
import 'package:brisconnect/widgets/logo_app_bar_title.dart';

class LocalPortalScreen extends StatefulWidget {
  const LocalPortalScreen({
    super.key,
    this.localEventService,
    this.discoverDataService,
    this.approvedAttractionService,
    this.submittedEventsStreamOverride,
    this.discoverItemsStreamOverride,
    this.enforceRoleGuard = true,
    this.initialTabIndex = 0,
  });

  final LocalEventService? localEventService;
  final DiscoverDataService? discoverDataService;
  final ApprovedAttractionService? approvedAttractionService;
  final Stream<List<EventItem>>? submittedEventsStreamOverride;
  final Stream<List<Map<String, dynamic>>>? discoverItemsStreamOverride;
  final bool enforceRoleGuard;
  final int initialTabIndex;

  @override
  State<LocalPortalScreen> createState() => _LocalPortalScreenState();
}

class _LocalPortalScreenState extends State<LocalPortalScreen> {
  final TextEditingController _searchController = TextEditingController();
  DiscoverDataService? _discoverDataService;
  ApprovedAttractionService? _approvedAttractionService;
  LocalEventService? _localEventService;
  late int _selectedIndex;
  static const String _defaultImageUrl =
      'https://images.unsplash.com/photo-1472653431158-6364773b2a56?auto=format&fit=crop&w=1400&q=80';

  DiscoverDataService get _effectiveDiscoverDataService {
    return _discoverDataService ??= DiscoverDataService();
  }

  ApprovedAttractionService get _effectiveApprovedAttractionService {
    return _approvedAttractionService ??= ApprovedAttractionService();
  }

  LocalEventService get _effectiveLocalEventService {
    return _localEventService ??= LocalEventService();
  }

  @override
  void initState() {
    super.initState();
    _discoverDataService = widget.discoverDataService;
    _approvedAttractionService = widget.approvedAttractionService;
    _localEventService = widget.localEventService;
    _selectedIndex = widget.initialTabIndex;
  }

  Stream<List<EventItem>> _mySubmittedEventsStream() {
    final override = widget.submittedEventsStreamOverride;
    if (override != null) {
      return override;
    }
    final localEmail = LocalAuth.currentLocal?.email;
    if (localEmail == null || localEmail.trim().isEmpty) {
      return Stream<List<EventItem>>.value(const <EventItem>[]);
    }
    return _effectiveLocalEventService.watchSubmittedEvents(localEmail);
  }

  List<EventItem> _searchItems(List<EventItem> items) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return items;

    return items.where((item) {
      return item.title.toLowerCase().contains(query) ||
          item.location.toLowerCase().contains(query) ||
          _statusText(item.reviewStatus).toLowerCase().contains(query);
    }).toList();
  }

  String _statusText(EventReviewStatus status) {
    switch (status) {
      case EventReviewStatus.approved:
        return 'Approved';
      case EventReviewStatus.pending:
        return 'Pending Approval';
      case EventReviewStatus.rejected:
        return 'Rejected';
    }
  }

  List<Map<String, dynamic>> _filterDiscoverItems(
    List<Map<String, dynamic>> items,
  ) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return items;
    }

    return items.where((item) {
      return (item['title'] as String? ?? '').toLowerCase().contains(query) ||
          (item['description'] as String? ?? '').toLowerCase().contains(query) ||
          (item['location'] as String? ?? '').toLowerCase().contains(query) ||
          (item['section'] as String? ?? '').toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _openWebLink(String link) async {
    final uri = Uri.tryParse(link);
    if (uri == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This link is not available right now.')),
      );
      return;
    }

    final didLaunch = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!didLaunch && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open the link right now.')),
      );
    }
  }

  Future<void> _showDiscoverItemDetails(Map<String, dynamic> item) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppPalette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final link = (item['webLink'] as String? ?? '').trim();
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item['title'] as String? ?? 'Discover Item',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppPalette.charcoal,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if ((item['badge'] as String? ?? '').trim().isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppPalette.ochre,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        item['badge'] as String,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  _buildDetailLine(
                    Icons.calendar_today_rounded,
                    item['dateTime'] as String? ?? 'Date TBA',
                  ),
                  const SizedBox(height: 8),
                  _buildDetailLine(
                    Icons.place_rounded,
                    item['location'] as String? ?? 'Location TBA',
                  ),
                  const SizedBox(height: 8),
                  _buildDetailLine(
                    Icons.sell_rounded,
                    item['price'] as String? ?? 'Price TBA',
                  ),
                  const SizedBox(height: 14),
                  Text(
                    item['description'] as String? ?? 'No description available.',
                    style: const TextStyle(
                      color: AppPalette.mutedText,
                      height: 1.5,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: link.isEmpty ? null : () => _openWebLink(link),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppPalette.deepBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.open_in_new_rounded),
                      label: const Text('Open Source Link'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<bool> _openAttractionDetailsIfAvailable(
    Map<String, dynamic> item,
  ) async {
    final section = (item['section'] as String? ?? '').trim().toLowerCase();
    if (section == 'events') {
      return false;
    }

    final title = (item['title'] as String? ?? '').trim().toLowerCase();
    final location = (item['location'] as String? ?? '').trim().toLowerCase();
    final attractions =
      await _effectiveApprovedAttractionService.fetchApprovedAttractions();
    if (!mounted) return true;

    ApprovedAttraction? matched;
    for (final attraction in attractions) {
      final attractionName = attraction.name.trim().toLowerCase();
      final attractionLocation = attraction.location.trim().toLowerCase();
      if (attractionName == title || attractionLocation == location) {
        matched = attraction;
        break;
      }
      if (title.isNotEmpty && (attractionName.contains(title) || title.contains(attractionName))) {
        matched = attraction;
        break;
      }
    }

    if (matched == null) {
      return false;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AttractionDetailScreen(
          attraction: matched!,
          allAttractions: attractions,
        ),
      ),
    );
    return true;
  }

  Widget _buildDetailLine(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppPalette.deepBlue),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: AppPalette.mutedText,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDiscoverCard(Map<String, dynamic> item) {
    final id = (item['id'] as String? ?? '').trim();
    return ReusableEventCard(
      imageUrl: item['imageUrl'] as String? ?? '',
      badgeText: item['badge'] as String? ?? '',
      title: item['title'] as String? ?? 'Discover Item',
      description: item['description'] as String? ?? '',
      dateTime: item['dateTime'] as String? ?? '',
      location: item['location'] as String? ?? '',
      price: item['price'] as String? ?? '',
      isFavorite: id.isNotEmpty && LocalAuth.isInterestedInEvent(id),
      onShareTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Share: ${item['title'] ?? 'Discover Item'}')),
        );
      },
      onCardTap: () async {
        final openedAttraction = await _openAttractionDetailsIfAvailable(item);
        if (!openedAttraction) {
          _showDiscoverItemDetails(item);
        }
      },
      onWebTap: () async {
        final link = (item['webLink'] as String? ?? '').trim();
        if (link.isEmpty) {
          final openedAttraction = await _openAttractionDetailsIfAvailable(item);
          if (!openedAttraction) {
            _showDiscoverItemDetails(item);
          }
          return;
        }
        _openWebLink(link);
      },
      onFavoriteTap: () {
        if (id.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('This event is missing an ID.')),
          );
          return;
        }
        _toggleInterestedEvent(id, eventData: item);
      },
    );
  }

  void _toggleInterestedEvent(String id, {Map<String, dynamic>? eventData}) {
    final didUpdate = LocalAuth.toggleInterestedEvent(id);
    if (!didUpdate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in as a Local user first.')),
      );
      return;
    }

    final isNowInterested = LocalAuth.isInterestedInEvent(id);
    if (isNowInterested &&
        LocalAuth.areNotificationsEnabled() &&
        eventData != null) {
      final notificationService = VisitorNotificationService();
      notificationService
          .scheduleNotificationForInterestedEvent(
            eventTitle: eventData['title'] as String? ?? 'Event',
            eventDatetime: eventData['dateTime'] as String? ?? 'Date TBA',
            eventLocation: eventData['location'] as String? ?? 'Location TBA',
            eventId: id,
            userEmail: LocalAuth.currentLocal?.email ?? '',
            userType: 'local',
          )
          .catchError((e) {
            debugPrint('[LocalPortal] Failed to schedule notification: $e');
          });
    }

    setState(() {});
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppPalette.border),
        boxShadow: const [
          BoxShadow(
            color: AppPalette.cardShadow,
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: AppPalette.ochre),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Manage local events in Brisbane',
                hintStyle: TextStyle(color: AppPalette.mutedText),
              ),
            ),
          ),
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: AppPalette.surfaceAlt,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Management filters coming soon')),
                );
              },
              icon: const Icon(Icons.tune_rounded, size: 20),
              color: AppPalette.deepBlue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManagementCard(EventItem event) {
    return ReusableManagementCard(
      imageUrl: _defaultImageUrl,
      title: event.title,
      dateTime: '${event.date} • ${event.time}',
      location: event.location,
      status: _statusText(event.reviewStatus),
      onEditTap: () async {
        final didEdit = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => LocalEditEventScreen(event: event),
          ),
        );
        if (didEdit == true && mounted) {
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Updated "${event.title}" saved and sent for admin re-approval.',
              ),
            ),
          );
        }
      },
      onDeleteTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete: ${event.title}')),
        );
      },
      onViewDetailsTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LocalEventDetailScreen(event: event),
          ),
        );
      },
    );
  }

  Widget _buildDashboard(List<EventItem> mySubmittedEvents) {
    final all = _searchItems(mySubmittedEvents);
    final pending = _searchItems(
      mySubmittedEvents.where((item) => item.isPending).toList(),
    );
    final approved = _searchItems(
      mySubmittedEvents.where((item) => item.isApproved).toList(),
    );

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: widget.discoverItemsStreamOverride ??
          _effectiveDiscoverDataService.watchApprovedDiscoverItems(),
      builder: (context, snapshot) {
        final discoverItems = _filterDiscoverItems(snapshot.data ?? const []);

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          children: [
            Text(
              'Welcome, ${LocalAuth.currentLocal?.name ?? 'Local'}',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppPalette.charcoal,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Organize, submit, and track your local events',
              style: TextStyle(
                color: AppPalette.mutedText,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 14),
            _buildSearchBar(),
            const SizedBox(height: 18),
            _SectionTitle(
              title: 'My Submitted Events',
              subtitle: '${all.length} total events',
            ),
            ...all.map(_buildManagementCard),
            const SizedBox(height: 10),
            _SectionTitle(
              title: 'Pending Events',
              subtitle: '${pending.length} waiting for approval',
            ),
            if (pending.isEmpty)
              const _LocalEmptyState('No pending events right now.')
            else
              ...pending.map(_buildManagementCard),
            const SizedBox(height: 10),
            _SectionTitle(
              title: 'Approved Events',
              subtitle: '${approved.length} live events',
            ),
            if (approved.isEmpty)
              const _LocalEmptyState('No approved events yet.')
            else
              ...approved.map(_buildManagementCard),
            const SizedBox(height: 18),
            const _SectionTitle(
              title: 'Discover Events',
              subtitle: 'Live visitor discovery items visible to local users',
            ),
            if (snapshot.connectionState == ConnectionState.waiting)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (snapshot.hasError)
              const _LocalEmptyState(
                'Unable to load discover events right now.',
              )
            else if (discoverItems.isEmpty)
              const _LocalEmptyState(
                'No discover events available for the current search.',
              )
            else
              ...discoverItems.map(_buildDiscoverCard),
          ],
        );
      },
    );
  }

  Widget _buildMyEventsTab(List<EventItem> mySubmittedEvents) {
    final all = _searchItems(mySubmittedEvents);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        const Text(
          'My Events',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppPalette.charcoal,
          ),
        ),
        const SizedBox(height: 12),
        _buildSearchBar(),
        const SizedBox(height: 16),
        if (all.isEmpty)
          const _LocalEmptyState('You have not submitted any events yet.')
        else
          ...all.map(_buildManagementCard),
      ],
    );
  }

  // ── Profile helpers ───────────────────────────────────────────────────

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
          color: AppPalette.mutedText,
        ),
      ),
    );
  }

  ImageProvider<Object>? _profileImageProvider(String? profileImageBase64) {
    final raw = profileImageBase64?.trim() ?? '';
    if (raw.isEmpty) {
      return null;
    }
    try {
      return MemoryImage(base64Decode(raw));
    } catch (_) {
      return null;
    }
  }

  Future<ImageSource?> _pickImageSource() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppPalette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadLocalProfileImage() async {
    final local = LocalAuth.currentLocal;
    if (local == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in as a Local user first.')),
      );
      return;
    }

    final source = await _pickImageSource();
    if (source == null) return;
    if (!mounted) return;

    Uint8List bytes;
    if (source == ImageSource.camera) {
      final captured = await Navigator.of(context).push<Uint8List>(
        MaterialPageRoute(builder: (_) => const ProfileCameraCaptureScreen()),
      );
      if (captured == null) return;
      bytes = captured;
    } else {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 75,
        maxWidth: 720,
        maxHeight: 720,
      );
      if (picked == null) return;
      bytes = await picked.readAsBytes();
    }

    if (!ProfileImageUtils.isSupportedImage(bytes)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only JPG and PNG images are supported.')),
      );
      return;
    }

    if (bytes.length > ProfileImageUtils.maxImageBytes) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image is too large. Please choose a smaller image.')),
      );
      return;
    }

    final encoded = base64Encode(bytes);
    final ok = await LocalAuth.updateProfileImage(encoded);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Profile picture updated successfully.'
              : 'Could not update profile picture. Please try again.',
        ),
        backgroundColor: ok ? Colors.green.shade700 : Colors.red.shade700,
      ),
    );
  }

  Future<void> _showEditProfileSheet(LocalUser local) async {
    final nameCtrl = TextEditingController(text: local.name);
    final phoneCtrl = TextEditingController(text: local.phone);
    final suburbCtrl = TextEditingController(text: local.suburb);
    final formKey = GlobalKey<FormState>();
    bool saving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppPalette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            MediaQuery.of(sheetCtx).viewInsets.bottom + 24,
          ),
          child: StatefulBuilder(
            builder: (_, setSS) {
              return Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Edit Profile',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppPalette.charcoal,
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: nameCtrl,
                        autofocus: true,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          labelText: 'Display name',
                          prefixIcon:
                              const Icon(Icons.person_outline_rounded),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().length < 2) {
                            return 'Name must be at least 2 characters.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: phoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: 'Phone number',
                          prefixIcon:
                              const Icon(Icons.phone_outlined),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: suburbCtrl,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          labelText: 'Suburb',
                          prefixIcon:
                              const Icon(Icons.location_on_outlined),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppPalette.ochre,
                          foregroundColor: Colors.white,
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: saving
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) {
                                  return;
                                }
                                setSS(() => saving = true);
                                final ok = await LocalAuth.updateProfile(
                                  name: nameCtrl.text,
                                  phone: phoneCtrl.text,
                                  suburb: suburbCtrl.text,
                                );
                                if (!sheetCtx.mounted) return;
                                Navigator.pop(sheetCtx);
                                if (mounted) {
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        ok
                                            ? 'Profile updated successfully.'
                                            : LocalAuth.lastErrorMessage ??
                                                'Could not update profile.',
                                      ),
                                      backgroundColor: ok
                                          ? Colors.green.shade700
                                          : Colors.red.shade700,
                                    ),
                                  );
                                }
                              },
                        child: saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white),
                              )
                            : const Text('Save Changes'),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => Navigator.pop(sheetCtx),
                        child: const Text('Cancel'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
    nameCtrl.dispose();
    phoneCtrl.dispose();
    suburbCtrl.dispose();
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await LocalAuth.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (route) => false,
    );
  }

  Widget _buildProfileTab(List<EventItem> mySubmittedEvents) {
    return ValueListenableBuilder<int>(
      valueListenable: LocalAuth.profileVersion,
      builder: (context, _, __) {
        final local = LocalAuth.currentLocal;
        final displayName = local?.name ?? 'Local User';
        final displayEmail = local?.email ?? '';
        final phone = local?.phone ?? '';
        final suburb = local?.suburb ?? '';
        final profileImage = _profileImageProvider(local?.profileImageBase64);

        final myEvents = local != null ? mySubmittedEvents : const <EventItem>[];
        final totalEvents = myEvents.length;
        final pendingCount =
            myEvents.where((e) => e.isPending).length;
        final approvedCount =
            myEvents.where((e) => e.isApproved).length;
        final rejectedCount =
            myEvents.where((e) => e.isRejected).length;

        final (Color statusColor, String statusLabel) =
            switch (local?.approvalStatus) {
          AccountApprovalStatus.approved => (
              Colors.green.shade700,
              'Approved'
            ),
          AccountApprovalStatus.rejected => (
              Colors.red.shade700,
              'Rejected'
            ),
          _ => (Colors.orange.shade700, 'Pending Approval'),
        };

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 36),
          children: [
            const Text(
              'Profile',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppPalette.charcoal,
              ),
            ),
            const SizedBox(height: 16),

            // ── Profile header card ─────────────────────────────────
            Card(
              color: AppPalette.surface,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppPalette.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: AppPalette.deepBlue,
                          backgroundImage: profileImage,
                          child: profileImage == null
                              ? const Icon(
                                  Icons.person_rounded,
                                  color: Colors.white,
                                  size: 30,
                                )
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusColor,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: Colors.white, width: 1.5),
                            ),
                            child: Text(
                              statusLabel,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppPalette.charcoal,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            displayEmail,
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppPalette.mutedText),
                          ),
                          if (phone.isNotEmpty) ...[
                            const SizedBox(height: 1),
                            Text(
                              phone,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppPalette.mutedText),
                            ),
                          ],
                          if (suburb.isNotEmpty) ...[
                            const SizedBox(height: 1),
                            Text(
                              suburb,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppPalette.mutedText),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (local != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Notification settings',
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const LocalSettingsScreen(),
                              ),
                            ),
                            icon: const Icon(
                              Icons.settings_rounded,
                              color: AppPalette.deepBlue,
                              size: 20,
                            ),
                          ),
                          IconButton(
                            tooltip:
                                local.profileImageBase64?.isNotEmpty == true
                                    ? 'Change profile picture'
                                    : 'Upload profile picture',
                            onPressed: _uploadLocalProfileImage,
                            icon: const Icon(
                              Icons.photo_camera_outlined,
                              color: AppPalette.deepBlue,
                              size: 20,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Edit profile',
                            onPressed: () => _showEditProfileSheet(local),
                            icon: const Icon(
                              Icons.edit_rounded,
                              color: AppPalette.deepBlue,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ── Event stats ────────────────────────────────────────
            _buildSectionLabel('My Events'),
            Card(
              color: AppPalette.surface,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppPalette.border),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    vertical: 16, horizontal: 8),
                child: Row(
                  children: [
                    _StatChip(
                        label: 'Total',
                        count: totalEvents,
                        color: AppPalette.deepBlue),
                    _StatChip(
                        label: 'Pending',
                        count: pendingCount,
                        color: Colors.orange.shade700),
                    _StatChip(
                        label: 'Approved',
                        count: approvedCount,
                        color: Colors.green.shade700),
                    _StatChip(
                        label: 'Rejected',
                        count: rejectedCount,
                        color: Colors.red.shade700),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ── Activity ───────────────────────────────────────────
            _buildSectionLabel('Activity'),
            Card(
              color: AppPalette.surface,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppPalette.border),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppPalette.deepBlue.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.settings_outlined,
                        color: AppPalette.deepBlue,
                        size: 20,
                      ),
                    ),
                    title: const Text('Notification Settings',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text(
                        'Enable or disable event reminder notifications'),
                    trailing: const Icon(Icons.chevron_right_rounded,
                        color: AppPalette.mutedText),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LocalSettingsScreen(),
                      ),
                    ),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  ListTile(
                    leading: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppPalette.ochre.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.add_circle_outline_rounded,
                          color: AppPalette.ochre, size: 20),
                    ),
                    title: const Text('Submit a New Event',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text(
                        'Create and submit an event for admin review'),
                    trailing: const Icon(Icons.chevron_right_rounded,
                        color: AppPalette.mutedText),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const AddEventScreen()),
                      );
                      if (mounted) setState(() {});
                    },
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  ListTile(
                    leading: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppPalette.deepBlue.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                          Icons.notifications_none_rounded,
                          color: AppPalette.deepBlue,
                          size: 20),
                    ),
                    title: const Text('Notifications',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text(
                        'Account status and event approval updates'),
                    trailing: const Icon(Icons.chevron_right_rounded,
                        color: AppPalette.mutedText),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const LocalNotificationsScreen(),
                      ),
                    ),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  ListTile(
                    leading: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppPalette.deepBlue.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.event_note_rounded,
                          color: AppPalette.deepBlue, size: 20),
                    ),
                    title: const Text('My Submitted Events',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('$totalEvents submitted event'
                        '${totalEvents == 1 ? '' : 's'}'),
                    trailing: const Icon(Icons.chevron_right_rounded,
                        color: AppPalette.mutedText),
                    onTap: () => setState(() => _selectedIndex = 1),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Account ────────────────────────────────────────────
            _buildSectionLabel('Account'),
            Card(
              color: AppPalette.surface,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppPalette.border),
              ),
              child: ListTile(
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.logout_rounded,
                      color: Colors.red.shade700, size: 20),
                ),
                title: Text(
                  'Sign Out',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.red.shade700,
                  ),
                ),
                subtitle: const Text('Return to the welcome screen'),
                onTap: _confirmLogout,
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scaffold = Scaffold(
      backgroundColor: const Color(0xFFF8F3EA),
      appBar: AppBar(
        title: const LogoAppBarTitle('Local Portal'),
        backgroundColor: AppPalette.deepBlue,
      ),
      body: StreamBuilder<List<EventItem>>(
        stream: _mySubmittedEventsStream(),
        builder: (context, snapshot) {
          final mySubmittedEvents = snapshot.data ?? const <EventItem>[];
          return SafeArea(
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                _buildDashboard(mySubmittedEvents),
                _buildMyEventsTab(mySubmittedEvents),
                _buildProfileTab(mySubmittedEvents),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        selectedItemColor: AppPalette.ochre,
        unselectedItemColor: AppPalette.deepBlue,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_rounded),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.event_note_rounded),
            label: 'My Events',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded),
            activeIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );

    if (!widget.enforceRoleGuard) {
      return scaffold;
    }

    return RoleGuard(
      allowedRoles: const {AppUserRole.local},
      deniedMessage: 'Access denied. Local account access is required.',
      child: scaffold,
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatChip({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppPalette.mutedText,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionTitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppPalette.charcoal,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppPalette.mutedText,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _LocalEmptyState extends StatelessWidget {
  final String text;

  const _LocalEmptyState(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppPalette.border),
      ),
      child: Text(
        text,
        style: const TextStyle(color: AppPalette.mutedText),
      ),
    );
  }
}
