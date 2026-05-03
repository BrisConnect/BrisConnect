import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:brisconnect/auth/app_user_role.dart';
import 'package:brisconnect/auth/local_auth.dart';
import 'package:brisconnect/models/event_item.dart';
import 'package:brisconnect/screens/add_event_screen.dart';
import 'package:brisconnect/screens/appearance_settings_screen.dart';
import 'package:brisconnect/screens/attraction_detail_screen.dart';
import 'package:brisconnect/screens/local_edit_event_screen.dart';
import 'package:brisconnect/screens/local_event_detail_screen.dart';
import 'package:brisconnect/screens/map_events_screen.dart';
import 'package:brisconnect/screens/local_notifications_screen.dart';
import 'package:brisconnect/screens/notification_settings_screen.dart';
import 'package:brisconnect/screens/local_settings_screen.dart';
import 'package:brisconnect/screens/my_feedback_screen.dart';
import 'package:brisconnect/screens/interest_categories_screen.dart';
import 'package:brisconnect/screens/welcome_screen.dart';
import 'package:brisconnect/screens/visitor_saved_events_calendar_screen.dart';
import 'package:brisconnect/services/approved_attraction_service.dart';
import 'package:brisconnect/services/discover_data_service.dart';
import 'package:brisconnect/services/firestore_service.dart';
import 'package:brisconnect/services/location_utilities.dart';
import 'package:brisconnect/services/firebase_media_service.dart';
import 'package:brisconnect/services/local_event_service.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/utils/profile_image_utils.dart';
import 'package:brisconnect/widgets/audio_guide_widget.dart';
import 'package:brisconnect/widgets/reusable_event_card.dart';
import 'package:brisconnect/widgets/role_guard.dart';
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
  String? _selectedCategoryFilter;
  FirebaseMediaService? _mediaService;
  Uint8List? _pendingProfileImageBytes;
  DiscoverDataService? _discoverDataService;
  ApprovedAttractionService? _approvedAttractionService;
  LocalEventService? _localEventService;
  FirestoreService? _firestoreService;
  Stream<List<Map<String, dynamic>>>? _discoverItemsStreamCache;
  Stream<List<Map<String, dynamic>>>? _approvedEventsStreamCache;
  late int _selectedIndex;
  bool _isNavVisible = true;
  late double _userLatitude;
  late double _userLongitude;
  late int _radiusKm;
  late bool _isUsingRadius;
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

  FirebaseMediaService get _effectiveMediaService {
    return _mediaService ??= FirebaseMediaService();
  }

  Stream<List<Map<String, dynamic>>> _discoverItemsStream() {
    return _discoverItemsStreamCache ??=
        (widget.discoverItemsStreamOverride ??
                _effectiveDiscoverDataService.watchApprovedDiscoverItems())
            .asBroadcastStream();
  }

  Stream<List<Map<String, dynamic>>> _approvedEventsStream() {
    final stream = _approvedEventsStreamCache ??= (_firestoreService ??=
            FirestoreService())
        .getEvents()
        .asBroadcastStream();
    return stream;
  }

  Map<String, dynamic> _toSavedEventCardItem(Map<String, dynamic> item) {
    final date = (item['date'] as String? ?? '').trim();
    final time = (item['time'] as String? ?? '').trim();
    final dateLower = date.toLowerCase();
    final timeLower = time.toLowerCase();
    final hasConcreteDate = date.isNotEmpty && dateLower != 'date tba';
    final hasConcreteTime = time.isNotEmpty && timeLower != 'time tba';
    final rawDateTime = ((item['dateTime'] as String?) ?? '').trim();
    final dateTime = hasConcreteDate || hasConcreteTime
        ? '${hasConcreteDate ? date : 'Date TBA'} • ${hasConcreteTime ? time : 'Time TBA'}'
        : (rawDateTime.isNotEmpty ? rawDateTime : 'Date TBA • Time TBA');

    return {
      ...item,
      'id': (item['id'] as String? ?? '').trim(),
      'section': 'events',
      'imageUrl': (item['imageUrl'] as String? ?? '').trim(),
      'badge': 'EVENT',
      'title': ((item['title'] as String?) ?? 'Untitled Event').trim(),
      'description': ((item['description'] as String?) ?? '').trim(),
      'dateTime': dateTime,
      'location': ((item['location'] as String?) ?? 'Location TBA').trim(),
      'price': ((item['price'] as String?) ?? 'Price TBA').trim(),
      'webLink': ((item['webLink'] as String?) ?? '').trim(),
    };
  }

  Widget _buildCalendarTab() {
    return ValueListenableBuilder<int>(
      valueListenable: LocalAuth.profileVersion,
      builder: (context, _, __) {
        final savedEventIds = LocalAuth.getInterestedEventIds();

        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: _discoverItemsStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final allItems = snapshot.data ?? const <Map<String, dynamic>>[];
            final savedDiscoverEvents = allItems.where((item) {
              final id = (item['id'] as String? ?? '').trim();
              final section = (item['section'] as String? ?? '').trim().toLowerCase();
              return id.isNotEmpty &&
                  section == 'events' &&
                  savedEventIds.contains(id);
            }).toList();

            return StreamBuilder<List<Map<String, dynamic>>>(
              stream: _approvedEventsStream(),
              builder: (context, approvedSnapshot) {
                final approvedEvents =
                    approvedSnapshot.data ?? const <Map<String, dynamic>>[];
                final savedFirestoreEvents = approvedEvents
                    .where((event) {
                      final id = (event['id'] as String? ?? '').trim();
                      return id.isNotEmpty && savedEventIds.contains(id);
                    })
                    .where(
                      (event) => !savedDiscoverEvents.any(
                        (item) => ((item['id'] as String? ?? '').trim() ==
                            (event['id'] as String? ?? '').trim()),
                      ),
                    )
                    .map(_toSavedEventCardItem)
                    .toList(growable: false);

                return VisitorSavedEventsCalendarScreen(
                  savedItems: [
                    ...savedDiscoverEvents,
                    ...savedFirestoreEvents,
                  ],
                  embedded: true,
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _discoverDataService = widget.discoverDataService;
    _approvedAttractionService = widget.approvedAttractionService;
    _localEventService = widget.localEventService;
    _selectedIndex = widget.initialTabIndex;
    _updateUserPreferences();
  }

  void _updateUserPreferences() {
    final local = LocalAuth.currentLocal;
    if (local != null) {
      _radiusKm = local.locationRadiusKm;
      _isUsingRadius = local.useCurrentLocation;
    } else {
      _radiusKm = 20;
      _isUsingRadius = false;
    }

    // Use default Brisbane location
    final (defaultLat, defaultLon) = LocationUtilities.getDefaultLocation();
    _userLatitude = defaultLat;
    _userLongitude = defaultLon;
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
    var filtered = items;

    if (_selectedCategoryFilter != null) {
      filtered = filtered
          .where((item) =>
              item.category.toLowerCase() ==
              _selectedCategoryFilter!.toLowerCase())
          .toList();
    }

    if (query.isEmpty) return filtered;

    return filtered.where((item) {
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
    var filtered = items;

    // Apply category filter
    if (_selectedCategoryFilter != null) {
      filtered = filtered.where((item) {
        return (item['category'] as String? ?? '')
                .toLowerCase() ==
            _selectedCategoryFilter!.toLowerCase();
      }).toList();
    }

    // Apply search filter
    if (query.isNotEmpty) {
      filtered = filtered.where((item) {
        return (item['title'] as String? ?? '').toLowerCase().contains(query) ||
            (item['description'] as String? ?? '')
                .toLowerCase()
                .contains(query) ||
            (item['location'] as String? ?? '').toLowerCase().contains(query) ||
            (item['section'] as String? ?? '').toLowerCase().contains(query);
      }).toList();
    }

    // Apply radius filter if enabled
    if (_isUsingRadius && filtered.isNotEmpty) {
      filtered = _effectiveDiscoverDataService.filterByRadius(
        items: filtered,
        userLatitude: _userLatitude,
        userLongitude: _userLongitude,
        radiusKm: _radiusKm,
      );
    }

    return filtered;
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
        final section = (item['section'] as String? ?? '').trim().toLowerCase();
        final narrationText = _buildDiscoverNarrationText(item);
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
                  if ((item['venue'] as String? ?? '').trim().isNotEmpty &&
                      (item['venue'] as String) != (item['location'] as String? ?? '')) ...[
                    const SizedBox(height: 8),
                    _buildDetailLine(
                      Icons.location_city_rounded,
                      item['venue'] as String,
                    ),
                  ],
                  if ((item['cuisine'] as String? ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _buildDetailLine(
                      Icons.restaurant_rounded,
                      item['cuisine'] as String,
                    ),
                  ],
                  if ((item['rating'] as num?)?.toDouble() != null &&
                      (item['rating'] as num).toDouble() > 0) ...[
                    const SizedBox(height: 8),
                    _buildDetailLine(
                      Icons.star_rounded,
                      '${(item['rating'] as num).toDouble().toStringAsFixed(1)} rating',
                    ),
                  ],
                  if ((item['source'] as String? ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _buildDetailLine(
                      Icons.verified_rounded,
                      'Source: ${item['source']}',
                    ),
                  ],
                  if ((item['categories'] as List<dynamic>?)?.isNotEmpty ==
                      true) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: (item['categories'] as List<dynamic>)
                          .take(6)
                          .map(
                            (cat) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppPalette.deepBlue
                                    .withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                cat.toString(),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppPalette.deepBlue,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Text(
                    item['description'] as String? ??
                        'No description available.',
                    style: const TextStyle(
                      color: AppPalette.mutedText,
                      height: 1.5,
                      fontSize: 14,
                    ),
                  ),
                  if ((item['culturalBackground'] as String? ?? '')
                      .trim()
                      .isNotEmpty) ...[
                    const SizedBox(height: 14),
                    const Text(
                      'Cultural Background',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppPalette.charcoal,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item['culturalBackground'] as String,
                      style: const TextStyle(
                        color: AppPalette.mutedText,
                        height: 1.5,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  if (section == 'events' &&
                      narrationText.trim().isNotEmpty) ...[
                    const SizedBox(height: 14),
                    const Text(
                      'AI Narration',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppPalette.charcoal,
                      ),
                    ),
                    const SizedBox(height: 8),
                    AiNarrationWidget(
                      narrationText: narrationText,
                      helperText:
                          'Tap play to hear your AI tour guide walk you through this event.',
                    ),
                  ],
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
      if (title.isNotEmpty &&
          (attractionName.contains(title) || title.contains(attractionName))) {
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

  String _buildDiscoverNarrationText(Map<String, dynamic> item) {
    final aiAudio = (item['aiAudio'] as String? ?? '').trim();
    if (aiAudio.isNotEmpty) {
      return aiAudio;
    }

    final title = (item['title'] as String? ?? '').trim();
    final dateTime = (item['dateTime'] as String? ?? '').trim();
    final location = (item['location'] as String? ?? '').trim();
    final description = (item['description'] as String? ?? '').trim();

    final parts = <String>[];
    if (title.isNotEmpty) {
      parts.add('Welcome to $title');
    }
    if (dateTime.isNotEmpty) {
      parts.add('This approved event is scheduled for $dateTime');
    }
    if (location.isNotEmpty) {
      parts.add('It takes place at $location');
    }
    if (description.isNotEmpty) {
      parts.add('Event overview: $description');
    }

    return '${parts.where((part) => part.trim().isNotEmpty).join('. ')}.';
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppPalette.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (_) => setState(() {}),
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => FocusScope.of(context).unfocus(),
        decoration: InputDecoration(
          hintText: 'Search events, bookings...',
          hintStyle: TextStyle(
            color: AppPalette.mutedText,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon:
              const Icon(Icons.search_rounded, color: AppPalette.mutedText),
          suffixIcon:
              const Icon(Icons.mic_rounded, color: AppPalette.mutedText),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _buildManagementCard(EventItem event) {
    return ReusableManagementCard(
      imageUrl: (event.imageAsset?.isNotEmpty == true)
          ? event.imageAsset!
          : _defaultImageUrl,
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

  Widget _buildEventPreviewSection(
    List<Map<String, dynamic>> discoverItems,
    AsyncSnapshot<List<Map<String, dynamic>>> snapshot,
  ) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (snapshot.hasError) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: _LocalEmptyState(
          'Unable to load discover events right now.',
        ),
      );
    }
    if (discoverItems.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: _LocalEmptyState('No events available.'),
      );
    }

    final eventItems = discoverItems
        .where((i) => (i['section'] as String? ?? '') == 'events')
        .toList();
    final historicalItems = discoverItems
        .where((i) => (i['section'] as String? ?? '') == 'historical')
        .toList();
    final foodItems = discoverItems
        .where((i) => (i['section'] as String? ?? '') == 'food')
        .toList();
    final stadiumItems = discoverItems
        .where((i) => (i['section'] as String? ?? '') == 'stadiums')
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (eventItems.isNotEmpty) ...[
          _buildDiscoverSectionHeader('Events', 'Upcoming events in Brisbane'),
          ...eventItems.map((item) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildDiscoverEventCard(item),
              )),
          const SizedBox(height: 16),
        ],
        if (historicalItems.isNotEmpty) ...[
          _buildDiscoverSectionHeader(
              'Attractions', 'Cultural and historical highlights'),
          ...historicalItems.map((item) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildDiscoverEventCard(item),
              )),
          const SizedBox(height: 16),
        ],
        if (foodItems.isNotEmpty) ...[
          _buildDiscoverSectionHeader(
              'Food', 'Discover local dining experiences'),
          ...foodItems.map((item) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildDiscoverEventCard(item),
              )),
          const SizedBox(height: 16),
        ],
        if (stadiumItems.isNotEmpty) ...[
          _buildDiscoverSectionHeader(
              'Stadiums', 'Explore iconic sporting venues'),
          ...stadiumItems.map((item) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildDiscoverEventCard(item),
              )),
        ],
      ],
    );
  }

  Widget _buildDiscoverSectionHeader(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppPalette.charcoal,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              color: AppPalette.mutedText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscoverEventCard(Map<String, dynamic> item) {
    final id = item['id'] as String? ?? '';
    final section = (item['section'] as String? ?? '').trim();
    final isFavorite = LocalAuth.isInterestedInEvent(id);

    return ReusableEventCard(
      imageUrl: item['imageUrl'] as String? ?? '',
      badgeText: item['badge'] as String? ?? '',
      title: item['title'] as String? ?? 'Event',
      section: section,
      description: item['description'] as String? ?? '',
      dateTime: item['dateTime'] as String? ?? '',
      location: item['location'] as String? ?? '',
      price: item['price'] as String? ?? '',
      source: item['source'] as String?,
      venue: item['venue'] as String?,
      categories: (item['categories'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      cuisine: item['cuisine'] as String?,
      rating: (item['rating'] as num?)?.toDouble(),
      isFavorite: isFavorite,
      cardColor: AppPalette.surface.withValues(alpha: 0.80),
      onShareTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Share: ${item['title'] ?? 'Event'}')),
        );
      },
      onCardTap: () async {
        if (section == 'events') {
          _showDiscoverItemDetails(item);
          return;
        }
        final opened = await _openAttractionDetailsIfAvailable(item);
        if (!opened && mounted) {
          _showDiscoverItemDetails(item);
        }
      },
      onWebTap: () async {
        final link = (item['webLink'] as String? ?? '').trim();
        if (section == 'events') {
          if (link.isNotEmpty) {
            _openWebLink(link);
          } else {
            _showDiscoverItemDetails(item);
          }
          return;
        }
        if (link.isEmpty) {
          final opened = await _openAttractionDetailsIfAvailable(item);
          if (!opened && mounted) {
            _showDiscoverItemDetails(item);
          }
          return;
        }
        _openWebLink(link);
      },
      onFavoriteTap: () {
        setState(() {
          LocalAuth.toggleInterestedEvent(id);
        });
      },
    );
  }

  Widget _buildDashboard(List<EventItem> mySubmittedEvents) {
    final localName = LocalAuth.currentLocal?.name.split(' ').first ?? 'Local';
    final heroProfileImage = _profileImageProvider(LocalAuth.currentLocal);

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _discoverItemsStream(),
      builder: (context, snapshot) {
        final discoverItems = _filterDiscoverItems(snapshot.data ?? const []);

        return CustomScrollView(
          slivers: [
            // ── Hero section ──
            SliverToBoxAdapter(
              child: Stack(
                children: [
                  // Transparent spacer for hero height
                  const SizedBox(
                    height: 340,
                    width: double.infinity,
                  ),
                  // Logo + greeting + search
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 12,
                    left: 16,
                    right: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Image.asset('assets/logo.png', height: 52),
                            const SizedBox(width: 10),
                            const Text(
                              'BrisConnect',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                shadows: [
                                  Shadow(
                                    offset: Offset(0, 1),
                                    blurRadius: 6,
                                    color: Colors.black45,
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: () => setState(() => _selectedIndex = 3),
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.25),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: CircleAvatar(
                                  radius: 38,
                                  backgroundColor: AppPalette.deepBlue,
                                  backgroundImage: heroProfileImage,
                                  child: heroProfileImage == null
                                      ? const Icon(Icons.person_rounded, color: Colors.white, size: 36)
                                      : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),
                        Text(
                          'Welcome Back, $localName',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                offset: Offset(0, 1),
                                blurRadius: 8,
                                color: Colors.black54,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Manage Your Events',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.white70,
                            shadows: [
                              Shadow(
                                offset: Offset(0, 1),
                                blurRadius: 6,
                                color: Colors.black38,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        _buildSearchBar(),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Content sheet ──
            SliverToBoxAdapter(
              child: Transform.translate(
                offset: const Offset(0, -24),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F3EA).withValues(alpha: 0.85),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 22),

                      // Event preview carousel
                      _buildEventPreviewSection(discoverItems, snapshot),
                      const SizedBox(height: 28),
                    ],
                  ),
                ),
              ),
            ),
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
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
          color: AppPalette.brown.withValues(alpha: 0.85),
        ),
      ),
    );
  }

  ImageProvider<Object>? _profileImageProvider(LocalUser? local) {
    if (_pendingProfileImageBytes != null) {
      return MemoryImage(_pendingProfileImageBytes!);
    }

    final imageUrl = local?.profileImageUrl?.trim() ?? '';
    if (imageUrl.isNotEmpty) {
      return NetworkImage(imageUrl);
    }

    final raw = local?.profileImageBase64?.trim() ?? '';
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

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      imageQuality: 75,
      maxWidth: 720,
      maxHeight: 720,
      preferredCameraDevice: CameraDevice.front,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    final fileName = picked.name;

    if (!ProfileImageUtils.isSupportedImage(bytes)) {
      setState(() => _pendingProfileImageBytes = null);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only JPG and PNG images are supported.')),
      );
      return;
    }

    if (bytes.length > ProfileImageUtils.maxImageBytes) {
      setState(() => _pendingProfileImageBytes = null);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Image is too large. Please choose a smaller image.')),
      );
      return;
    }

    bool ok = false;
    setState(() => _pendingProfileImageBytes = bytes);
    try {
      final uploaded = await _effectiveMediaService.uploadProfileImage(
        role: 'local',
        email: local.email,
        bytes: bytes,
        fileName: fileName,
        previousStoragePath: local.profileImageStoragePath,
      );
      if (!mounted) return;
      ok = await LocalAuth.updateProfileImage(
        base64Image: null,
        imageUrl: uploaded.downloadUrl,
        storagePath: uploaded.storagePath,
      );
      if (!mounted) return;
      if (ok) {
        setState(() => _pendingProfileImageBytes = null);
      }
    } on FormatException catch (error) {
      setState(() => _pendingProfileImageBytes = null);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
      return;
    } catch (error) {
      debugPrint('[LocalPortal] Profile image upload failed: $error');
      setState(() => _pendingProfileImageBytes = null);
    }
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
    final result = await showModalBottomSheet<_LocalProfileUpdateRequest>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppPalette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => _LocalProfileEditorSheet(local: local),
    );

    if (result == null || !mounted) {
      return;
    }

    final ok = await LocalAuth.updateProfile(
      name: result.name,
      phone: result.phone,
      suburb: result.suburb,
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Profile updated successfully.'
              : LocalAuth.lastErrorMessage ?? 'Could not update profile.',
        ),
        backgroundColor: ok ? Colors.green.shade700 : Colors.red.shade700,
      ),
    );
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
        final profileImage = _profileImageProvider(local);

        final myEvents =
            local != null ? mySubmittedEvents : const <EventItem>[];
        final totalEvents = myEvents.length;
        final pendingCount = myEvents.where((e) => e.isPending).length;
        final approvedCount = myEvents.where((e) => e.isApproved).length;
        final rejectedCount = myEvents.where((e) => e.isRejected).length;

        final (Color statusColor, String statusLabel) =
            switch (local?.approvalStatus) {
          AccountApprovalStatus.approved => (Colors.green.shade700, 'Approved'),
          AccountApprovalStatus.rejected => (Colors.red.shade700, 'Rejected'),
          _ => (Colors.orange.shade700, 'Pending Approval'),
        };

        return Container(
          color: const Color(0xFFF8F3EA).withValues(alpha: 0.85),
          child: ListView(
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
            _buildSectionLabel('Profile Info'),
            Card(
              color: AppPalette.surface.withValues(alpha: 0.96),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: AppPalette.border.withValues(alpha: 0.5)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 48,
                          backgroundColor: AppPalette.deepBlue,
                          backgroundImage: profileImage,
                          child: profileImage == null
                              ? const Icon(
                                  Icons.person_rounded,
                                  color: Colors.white,
                                  size: 48,
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
                              border:
                                  Border.all(color: Colors.white, width: 1.5),
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
                                fontSize: 12, color: AppPalette.mutedText),
                          ),
                          if (phone.isNotEmpty) ...[
                            const SizedBox(height: 1),
                            Text(
                              phone,
                              style: const TextStyle(
                                  fontSize: 12, color: AppPalette.mutedText),
                            ),
                          ],
                          if (suburb.isNotEmpty) ...[
                            const SizedBox(height: 1),
                            Text(
                              suburb,
                              style: const TextStyle(
                                  fontSize: 12, color: AppPalette.mutedText),
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
                            tooltip:
                                (local.profileImageUrl?.isNotEmpty == true ||
                                        local.profileImageBase64?.isNotEmpty ==
                                            true)
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
            _buildSectionLabel('My Activity'),
            Card(
              color: AppPalette.surface.withValues(alpha: 0.96),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: AppPalette.border.withValues(alpha: 0.5)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 8,
                    ),
                    child: Row(
                      children: [
                        _StatChip(
                          label: 'Total',
                          count: totalEvents,
                          color: AppPalette.deepBlue,
                        ),
                        _StatChip(
                          label: 'Pending',
                          count: pendingCount,
                          color: Colors.orange.shade700,
                        ),
                        _StatChip(
                          label: 'Approved',
                          count: approvedCount,
                          color: Colors.green.shade700,
                        ),
                        _StatChip(
                          label: 'Rejected',
                          count: rejectedCount,
                          color: Colors.red.shade700,
                        ),
                      ],
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
                      child: const Icon(
                        Icons.event_note_rounded,
                        color: AppPalette.deepBlue,
                        size: 20,
                      ),
                    ),
                    title: const Text(
                      'Submitted Events & Activity History',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text('$totalEvents submitted event'
                        '${totalEvents == 1 ? '' : 's'}'),
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                      color: AppPalette.mutedText,
                    ),
                    onTap: () => setState(() => _selectedIndex = 2),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildSectionLabel('Notifications'),
            Card(
              color: AppPalette.surface.withValues(alpha: 0.96),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: AppPalette.border.withValues(alpha: 0.5)),
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
                        builder: (_) => const NotificationSettingsScreen.local(),
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
                      child: const Icon(Icons.notifications_none_rounded,
                          color: AppPalette.deepBlue, size: 20),
                    ),
                    title: const Text('Notifications',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle:
                        const Text('Account status and event approval updates'),
                    trailing: const Icon(Icons.chevron_right_rounded,
                        color: AppPalette.mutedText),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LocalNotificationsScreen(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildSectionLabel('Preferences'),
            Card(
              color: AppPalette.surface.withValues(alpha: 0.96),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: AppPalette.border.withValues(alpha: 0.5)),
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
                      child: const Icon(Icons.interests_rounded,
                          color: AppPalette.deepBlue, size: 20),
                    ),
                    title: const Text('Interest Categories',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Set focus areas for local content'),
                    trailing: const Icon(Icons.chevron_right_rounded,
                        color: AppPalette.mutedText),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const InterestCategoriesScreen.local(),
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
                      child: const Icon(Icons.pin_drop_outlined,
                          color: AppPalette.deepBlue, size: 20),
                    ),
                    title: const Text('Location Radius',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle:
                        const Text('Control distance for nearby opportunities'),
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
                        color: AppPalette.deepBlue.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.palette_outlined,
                          color: AppPalette.deepBlue, size: 20),
                    ),
                    title: const Text('Appearance Settings',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle:
                        const Text('Theme, text size & feedback'),
                    trailing: const Icon(Icons.chevron_right_rounded,
                        color: AppPalette.mutedText),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AppearanceSettingsScreen.local(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildSectionLabel('Feedback'),
            Card(
              color: AppPalette.surface.withValues(alpha: 0.96),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: AppPalette.border.withValues(alpha: 0.5)),
              ),
              child: ListTile(
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppPalette.deepBlue.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.inbox_rounded,
                    color: AppPalette.deepBlue,
                    size: 20,
                  ),
                ),
                title: const Text(
                  'My Feedback',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'View your submitted feedback and admin responses',
                ),
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: AppPalette.mutedText,
                ),
                onTap: () {
                  final email = LocalAuth.currentLocal?.email ?? '';
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MyFeedbackScreen(
                        reporterEmail: email,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            _buildSectionLabel('Sign Out'),
            Card(
              color: AppPalette.surface.withValues(alpha: 0.96),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: AppPalette.border.withValues(alpha: 0.5)),
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
            const SizedBox(height: 24),
            _buildSectionLabel('About'),
            Card(
              color: AppPalette.surface.withValues(alpha: 0.96),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: AppPalette.border.withValues(alpha: 0.5)),
              ),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'BrisConnect',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppPalette.charcoal,
                        fontSize: 15,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'BrisConnect is a smart city guide that helps visitors and locals discover events, explore attractions, and capture their Brisbane experiences in one connected platform.',
                      style: TextStyle(
                        color: AppPalette.mutedText,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Version 1.0.0',
                      style: TextStyle(
                        color: AppPalette.mutedText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isHome = _selectedIndex == 0;

    final scaffold = Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      extendBody: true,
      appBar: isHome
          ? null
          : AppBar(
              automaticallyImplyLeading: false,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _selectedIndex = 0),
              ),
              title: LogoAppBarTitle(
                _selectedIndex == 1
                    ? 'Map'
                    : _selectedIndex == 2
                        ? 'Calendar'
                        : _selectedIndex == 3
                            ? 'My Events'
                            : 'Profile',
              ),
              backgroundColor: Colors.transparent,
              elevation: 0,
            ),
      body: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollUpdateNotification) {
            final delta = notification.scrollDelta ?? 0;
            if (delta > 2 && _isNavVisible) {
              setState(() => _isNavVisible = false);
            } else if (delta < -2 && !_isNavVisible) {
              setState(() => _isNavVisible = true);
            }
          } else if (notification is ScrollEndNotification) {
            if (!_isNavVisible) setState(() => _isNavVisible = true);
          }
          return false;
        },
        child: StreamBuilder<List<EventItem>>(
          stream: _mySubmittedEventsStream(),
          builder: (context, snapshot) {
            final mySubmittedEvents = snapshot.data ?? const <EventItem>[];
            return IndexedStack(
              index: _selectedIndex,
              children: [
                _buildDashboard(mySubmittedEvents),
                SafeArea(child: MapEventsScreen(
                  embedded: true,
                  onBackPressed: () => setState(() => _selectedIndex = 0),
                )),
                SafeArea(child: _buildCalendarTab()),
                SafeArea(child: _buildMyEventsTab(mySubmittedEvents)),
                SafeArea(child: _buildProfileTab(mySubmittedEvents)),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: AnimatedSlide(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        offset: _isNavVisible ? Offset.zero : const Offset(0, 1),
        child: _buildLocalBottomNav(),
      ),
    );

    // Wrap scaffold with full-screen background image
    final withBackground = Stack(
      children: [
        // Full-screen kookaburra background
        Positioned.fill(
          child: Image.asset(
            'assets/Kookaburra1.png',
            fit: BoxFit.cover,
          ),
        ),
        // Orange-brown tinted overlay
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFFC1440E).withValues(alpha: 0.55),
                  const Color(0xFF5C3D2E).withValues(alpha: 0.60),
                  const Color(0xFFF8F3EA).withValues(alpha: 0.88),
                ],
                stops: const [0.0, 0.35, 1.0],
              ),
            ),
          ),
        ),
        scaffold,
      ],
    );

    if (!widget.enforceRoleGuard) {
      return withBackground;
    }

    return RoleGuard(
      allowedRoles: const {AppUserRole.local},
      deniedMessage: 'Access denied. Local account access is required.',
      child: withBackground,
    );
  }

  Widget _buildLocalBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: AppPalette.ochre.withValues(alpha: 0.92),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _LocalNavItem(
                icon: Icons.home_rounded,
                label: 'Home',
                isSelected: _selectedIndex == 0,
                onTap: () => setState(() => _selectedIndex = 0),
              ),
              _LocalNavItem(
                icon: Icons.map_rounded,
                label: 'Map',
                isSelected: _selectedIndex == 1,
                onTap: () => setState(() => _selectedIndex = 1),
              ),
              // Center Add Event button
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AddEventScreen(),
                  ),
                ),
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppPalette.ochre, Color(0xFFD4740E)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppPalette.ochre.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_rounded,
                          color: Colors.white, size: 24),
                      Text(
                        'Add Event',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _LocalNavItem(
                icon: Icons.calendar_month_rounded,
                label: 'Calendar',
                isSelected: _selectedIndex == 2,
                onTap: () => setState(() => _selectedIndex = 2),
              ),
              _LocalNavItem(
                icon: Icons.event_note_rounded,
                label: 'My Events',
                isSelected: _selectedIndex == 3,
                onTap: () => setState(() => _selectedIndex = 3),
              ),
              _LocalNavItem(
                icon: Icons.person_outline_rounded,
                label: 'Profile',
                isSelected: _selectedIndex == 4,
                onTap: () => setState(() => _selectedIndex = 4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocalProfileUpdateRequest {
  const _LocalProfileUpdateRequest({
    required this.name,
    required this.phone,
    required this.suburb,
  });

  final String name;
  final String phone;
  final String suburb;
}

class _LocalProfileEditorSheet extends StatefulWidget {
  const _LocalProfileEditorSheet({required this.local});

  final LocalUser local;

  @override
  State<_LocalProfileEditorSheet> createState() =>
      _LocalProfileEditorSheetState();
}

class _LocalProfileEditorSheetState extends State<_LocalProfileEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _suburbController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.local.name);
    _phoneController = TextEditingController(text: widget.local.phone);
    _suburbController = TextEditingController(text: widget.local.suburb);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _suburbController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _saving = true);
    Navigator.pop(
      context,
      _LocalProfileUpdateRequest(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        suburb: _suburbController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
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
                controller: _nameController,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Display name',
                  prefixIcon: const Icon(Icons.person_outline_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
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
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Phone number',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _suburbController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Suburb',
                  prefixIcon: const Icon(Icons.location_on_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppPalette.ochre,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Save Changes'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _saving ? null : () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
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

class _LocalEmptyState extends StatelessWidget {
  final String text;

  const _LocalEmptyState(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppPalette.surface.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppPalette.border.withValues(alpha: 0.5)),
      ),
      child: Text(
        text,
        style: const TextStyle(color: AppPalette.mutedText),
      ),
    );
  }
}

// ── Bottom nav item ──
class _LocalNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _LocalNavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 60,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 24,
              color: isSelected ? Colors.white : Colors.white70,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
