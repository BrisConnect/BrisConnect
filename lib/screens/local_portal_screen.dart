// ignore_for_file: unused_element, unused_field, unused_local_variable

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:brisconnect/auth/app_user_role.dart';
import 'package:brisconnect/auth/local_auth.dart';
import 'package:brisconnect/models/event_item.dart';
import 'package:brisconnect/screens/business_audience_screen.dart';
import 'package:brisconnect/screens/business_search_screen.dart';
import 'package:brisconnect/screens/business_map_screen.dart';
import 'package:brisconnect/services/business_profile_service.dart';
import 'package:brisconnect/screens/appearance_settings_screen.dart';
import 'package:brisconnect/screens/local_edit_event_screen.dart';
import 'package:brisconnect/screens/local_event_detail_screen.dart';
import 'package:brisconnect/screens/vendor_feed_screen.dart';
import 'package:brisconnect/screens/business_dashboard_screen.dart';
import 'package:brisconnect/screens/vendor_reviews_screen.dart';
import 'package:brisconnect/screens/business_profile_screen.dart';
import 'package:brisconnect/screens/local_settings_screen.dart';
import 'package:brisconnect/screens/business_notification_settings_screen.dart';
import 'package:brisconnect/screens/my_feedback_screen.dart';
import 'package:brisconnect/screens/welcome_screen_new.dart';
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
import 'package:brisconnect/widgets/help_support_sheet.dart';
import 'package:brisconnect/widgets/desktop_top_app_bar.dart';
import 'package:brisconnect/utils/responsive_utils.dart';

class LocalPortalScreen extends StatefulWidget {
  const LocalPortalScreen({
    super.key,
    this.localEventService,
    this.submittedEventsStreamOverride,
    this.enforceRoleGuard = true,
    this.initialTabIndex = 0,
  });

  final LocalEventService? localEventService;
  final Stream<List<EventItem>>? submittedEventsStreamOverride;
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
  LocalEventService? _localEventService;
  FirestoreService? _firestoreService;
  Stream<List<Map<String, dynamic>>>? _approvedEventsStreamCache;
  late int _selectedIndex;
  final ValueNotifier<bool> _navVisibleNotifier = ValueNotifier<bool>(true);
  DateTime? _lastNavToggle;
  late double _userLatitude;
  late double _userLongitude;
  late int _radiusKm;
  late bool _isUsingRadius;
  LocalEventService get _effectiveLocalEventService {
    return _localEventService ??= LocalEventService();
  }

  FirebaseMediaService get _effectiveMediaService {
    return _mediaService ??= FirebaseMediaService();
  }

  AppLocalizations get l10n => AppLocalizations.of(context)!;

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

  @override
  void initState() {
    super.initState();
    _localEventService = widget.localEventService;
    _selectedIndex = widget.initialTabIndex;
    _updateUserPreferences();
  }

  @override
  void dispose() {
    _navVisibleNotifier.dispose();
    super.dispose();
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
        return l10n.approved;
      case EventReviewStatus.pending:
        return l10n.pendingApproval;
      case EventReviewStatus.rejected:
        return l10n.rejected;
    }
  }

  Future<void> _showDeleteConfirmationDialog(EventItem event) async {
    final currentLocal = LocalAuth.currentLocal;
    if (currentLocal == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.pleaseLoginToDelete)),
        );
      }
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteEvent),
        content: Text(
          l10n.deleteEventConfirmation(event.title),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: AppPalette.ochre,
            ),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (shouldDelete != true || !mounted) {
      return;
    }

    // Show loading indicator
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.deletingEvent),
        duration: const Duration(seconds: 1),
      ),
    );

    try {
      final deleted = await _effectiveLocalEventService.deleteSubmittedEvent(
        eventId: event.id,
        localEmail: currentLocal.email,
      );

      if (!mounted) return;

      if (deleted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.eventDeleted(event.title)),
            backgroundColor: AppPalette.deepBlue,
          ),
        );
        // Stream will automatically refresh and remove the deleted event
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.failedToDeleteEvent),
            backgroundColor: AppPalette.ochre,
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.errorDeletingEvent(error.toString())),
            backgroundColor: AppPalette.ochre,
          ),
        );
      }
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
        return (item['category'] as String? ?? '').toLowerCase() ==
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

    return filtered;
  }

  Future<void> _openWebLink(String link) async {
    final uri = Uri.tryParse(link);
    if (uri == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.thisLinkUnavailable)),
      );
      return;
    }

    final didLaunch = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!didLaunch && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.unableToOpenLink)),
      );
    }
  }

  Future<void> _showDiscoverItemDetails(Map<String, dynamic> item) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppPalette.background,
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
                      (item['venue'] as String) !=
                          (item['location'] as String? ?? '')) ...[
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
                                color:
                                    AppPalette.deepBlue.withValues(alpha: 0.08),
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
                      label: Text(l10n.openSourceLink),
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
          hintText: l10n.searchHintEvents,
          hintStyle: const TextStyle(
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
      imageUrl: event.imageAsset ?? '',
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
      onDeleteTap: () async {
        await _showDeleteConfirmationDialog(event);
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding =
            constraints.maxWidth >= Breakpoints.desktop ? 32.0 : 20.0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (eventItems.isNotEmpty) ...[
              _buildDiscoverSectionHeader(
                'Events',
                'Upcoming events in Brisbane',
                horizontalPadding,
              ),
              _buildDiscoverCardGrid(eventItems, constraints.maxWidth),
              const SizedBox(height: 16),
            ],
            if (historicalItems.isNotEmpty) ...[
              _buildDiscoverSectionHeader(
                'Attractions',
                'Cultural and historical highlights',
                horizontalPadding,
              ),
              _buildDiscoverCardGrid(historicalItems, constraints.maxWidth),
              const SizedBox(height: 16),
            ],
            if (foodItems.isNotEmpty) ...[
              _buildDiscoverSectionHeader(
                'Food',
                'Discover local dining experiences',
                horizontalPadding,
              ),
              _buildDiscoverCardGrid(foodItems, constraints.maxWidth),
              const SizedBox(height: 16),
            ],
            if (stadiumItems.isNotEmpty) ...[
              _buildDiscoverSectionHeader(
                'Stadiums',
                'Explore iconic sporting venues',
                horizontalPadding,
              ),
              _buildDiscoverCardGrid(stadiumItems, constraints.maxWidth),
            ],
          ],
        );
      },
    );
  }

  /// Renders discover cards in a responsive grid on desktop/tablet.
  Widget _buildDiscoverCardGrid(
    List<Map<String, dynamic>> items,
    double maxWidth,
  ) {
    if (maxWidth >= Breakpoints.mobile) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.symmetric(
          horizontal: maxWidth >= Breakpoints.desktop ? 32 : 20,
        ),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: ResponsiveUtils.gridColumnCount(
            context,
            itemMinWidth: 340,
            minColumns: 2,
            maxColumns: maxWidth >= Breakpoints.desktop ? 4 : 3,
            spacing: 16,
          ),
          crossAxisSpacing: 16,
          mainAxisSpacing: 0,
          childAspectRatio: 0.78,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) => _buildDiscoverEventCard(items[index]),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items
          .map((item) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildDiscoverEventCard(item),
              ))
          .toList(),
    );
  }

  Widget _buildBusinessDiscoverySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDiscoverSectionHeader(
          'Discover Local Food Businesses',
          'Find and support small & medium food enterprises in Brisbane',
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const BusinessSearchScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.search),
                  label: Text(l10n.search),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppPalette.ochre,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    try {
                      final businesses = await BusinessProfileService()
                          .getVerifiedBusinesses();
                      if (mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BusinessMapScreen(
                              businesses: businesses,
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l10n.errorLoadingMap(e.toString()))),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.map),
                  label: Text(l10n.map),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppPalette.ochre,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDiscoverSectionHeader(
    String title,
    String subtitle, [
    double horizontalPadding = 20,
  ]) {
    return Padding(
      padding: EdgeInsets.fromLTRB(horizontalPadding, 8, horizontalPadding, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: horizontalPadding >= 32 ? 22 : 18,
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
        _showDiscoverItemDetails(item);
      },
      onWebTap: () async {
        final link = (item['webLink'] as String? ?? '').trim();
        if (link.isNotEmpty) {
          _openWebLink(link);
        } else {
          _showDiscoverItemDetails(item);
        }
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
      stream: _approvedEventsStream(),
      builder: (context, snapshot) {
        final items = snapshot.data ?? const <Map<String, dynamic>>[];
        final discoverItems = _filterDiscoverItems(items);
        final width = ResponsiveUtils.widthOf(context);
        final isMobile = width < Breakpoints.mobile;
        final isDesktop = width >= Breakpoints.desktop;

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
                    left: isMobile ? 16.0 : 32.0,
                    right: isMobile ? 16.0 : 32.0,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isMobile)
                          Row(
                            children: [
                              ClipOval(
                                child: Container(
                                  width: 64,
                                  height: 64,
                                  color: Colors.white.withValues(alpha: 0.1),
                                  child: Image.asset(
                                      'assets/Brisconnect New.jpg',
                                      fit: BoxFit.cover),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                l10n.appTitle,
                                style: const TextStyle(
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
                                onTap: () => setState(() => _selectedIndex = 4),
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white, width: 2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black
                                            .withValues(alpha: 0.25),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: CircleAvatar(
                                    radius: 52,
                                    backgroundColor: AppPalette.deepBlue,
                                    backgroundImage: heroProfileImage,
                                    child: heroProfileImage == null
                                        ? const Icon(Icons.person_rounded,
                                            color: Colors.white, size: 48)
                                        : null,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        if (isMobile) const SizedBox(height: 22),
                        Text(
                          'Welcome Back, $localName',
                          style: TextStyle(
                            fontSize: isDesktop ? 36 : 28,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            shadows: const [
                              Shadow(
                                offset: Offset(0, 1),
                                blurRadius: 8,
                                color: Colors.black54,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Manage Your Events',
                          style: TextStyle(
                            fontSize: isDesktop ? 20 : 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.white70,
                            shadows: const [
                              Shadow(
                                offset: Offset(0, 1),
                                blurRadius: 6,
                                color: Colors.black38,
                              ),
                            ],
                          ),
                        ),
                        if (isMobile) ...[
                          const SizedBox(height: 18),
                          _buildSearchBar(),
                        ],
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
                  decoration: const BoxDecoration(
                    color: Color(0xFF1C1C2E),
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 22),

                      // Event preview carousel
                      _buildEventPreviewSection(discoverItems, snapshot),
                      const SizedBox(height: 28),

                      // Business Discovery Section
                      _buildBusinessDiscoverySection(),
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

  // ── Profile helpers ───────────────────────────────────────────────────

  Widget _buildSectionLabel(String label) {
    final isDesktop = ResponsiveUtils.widthOf(context) >= Breakpoints.desktop;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: isDesktop ? 13 : 11,
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
      builder: (ctx) {
        final sheetL10n = AppLocalizations.of(ctx)!;
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: Text(sheetL10n.chooseFromGallery),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: Text(sheetL10n.takeAPhoto),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _uploadLocalProfileImage() async {
    final local = LocalAuth.currentLocal;
    if (local == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pleaseLoginLocal)),
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
        SnackBar(content: Text(l10n.onlyJpgPng)),
      );
      return;
    }

    if (bytes.length > ProfileImageUtils.maxImageBytes) {
      setState(() => _pendingProfileImageBytes = null);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(l10n.imageTooLarge)),
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

  void _showHelpSupport(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const HelpSupportSheet(),
    );
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final dialogL10n = AppLocalizations.of(ctx)!;
        return AlertDialog(
          title: Text(dialogL10n.signOut),
          content: Text(dialogL10n.areYouSureSignOut),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(dialogL10n.cancel),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(dialogL10n.signOut),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    await LocalAuth.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AnimatedWelcomeScreen()),
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

        final width = ResponsiveUtils.widthOf(context);
        final isProfileDesktop = width >= Breakpoints.desktop;
        final isProfileTablet =
            width >= Breakpoints.mobile && width < Breakpoints.tablet;
        final horizontalPadding = isProfileDesktop
            ? 48.0
            : isProfileTablet
                ? 32.0
                : 16.0;

        return Container(
          color: const Color(0xFFF8F3EA).withValues(alpha: 0.85),
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              isProfileDesktop ? 32 : 14,
              horizontalPadding,
              36,
            ),
            children: [
              _buildSectionLabel('Profile Info'),
              Card(
                color: AppPalette.surface.withValues(alpha: 0.96),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                      color: AppPalette.border.withValues(alpha: 0.5)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundColor: AppPalette.deepBlue,
                            backgroundImage: profileImage,
                            child: profileImage == null
                                ? const Icon(
                                    Icons.person_rounded,
                                    color: Colors.white,
                                    size: 40,
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
                              tooltip: (local.profileImageUrl?.isNotEmpty ==
                                          true ||
                                      local.profileImageBase64?.isNotEmpty ==
                                          true)
                                  ? l10n.changeProfilePicture
                                  : l10n.uploadProfilePicture,
                              onPressed: _uploadLocalProfileImage,
                              icon: const Icon(
                                Icons.photo_camera_outlined,
                                color: AppPalette.deepBlue,
                                size: 20,
                              ),
                            ),
                            IconButton(
                              tooltip: l10n.editProfile,
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
              _buildSectionLabel(l10n.myActivity),
              Card(
                color: AppPalette.surface.withValues(alpha: 0.96),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                      color: AppPalette.border.withValues(alpha: 0.5)),
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
                            label: l10n.total,
                            count: totalEvents,
                            color: AppPalette.deepBlue,
                          ),
                          _StatChip(
                            label: l10n.pending,
                            count: pendingCount,
                            color: Colors.orange.shade700,
                          ),
                          _StatChip(
                            label: l10n.approved,
                            count: approvedCount,
                            color: Colors.green.shade700,
                          ),
                          _StatChip(
                            label: l10n.rejected,
                            count: rejectedCount,
                            color: Colors.red.shade700,
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _buildSectionLabel(l10n.preferences),
              Card(
                color: AppPalette.surface.withValues(alpha: 0.96),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                      color: AppPalette.border.withValues(alpha: 0.5)),
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
                        child: const Icon(Icons.pin_drop_outlined,
                            color: AppPalette.deepBlue, size: 20),
                      ),
                      title: Text(l10n.locationRadius,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(l10n.controlDistance),
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
                      title: Text(l10n.appearanceSettings,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(l10n.themeTextSizeFeedback),
                      trailing: const Icon(Icons.chevron_right_rounded,
                          color: AppPalette.mutedText),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const AppearanceSettingsScreen.local(),
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
                        child: const Icon(Icons.notifications_outlined,
                            color: AppPalette.deepBlue, size: 20),
                      ),
                      title: Text(l10n.businessNotifications,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(l10n.pushAlerts),
                      trailing: const Icon(Icons.chevron_right_rounded,
                          color: AppPalette.mutedText),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const BusinessNotificationSettingsScreen(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _buildSectionLabel(l10n.feedback),
              Card(
                color: AppPalette.surface.withValues(alpha: 0.96),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                      color: AppPalette.border.withValues(alpha: 0.5)),
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
                  title: Text(
                    l10n.myFeedback,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    l10n.viewSubmittedFeedback,
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
              _buildSectionLabel(l10n.helpAndSupport),
              Card(
                color: AppPalette.surface.withValues(alpha: 0.96),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                      color: AppPalette.border.withValues(alpha: 0.5)),
                ),
                child: ListTile(
                  leading: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppPalette.ochre.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.help_outline_rounded,
                        color: AppPalette.ochre, size: 20),
                  ),
                  title: Text(
                    l10n.helpAndSupport,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(l10n.faqsContactAppInfo),
                  trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                  onTap: () => _showHelpSupport(context),
                ),
              ),
              const SizedBox(height: 24),
              _buildSectionLabel(l10n.signOut),
              Card(
                color: AppPalette.surface.withValues(alpha: 0.96),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                      color: AppPalette.border.withValues(alpha: 0.5)),
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
                    l10n.signOut,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.red.shade700,
                    ),
                  ),
                  subtitle: Text(l10n.returnWelcome),
                  onTap: _confirmLogout,
                ),
              ),
              const SizedBox(height: 24),
              _buildSectionLabel(l10n.about),
              Card(
                color: AppPalette.surface.withValues(alpha: 0.96),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                      color: AppPalette.border.withValues(alpha: 0.5)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.appTitle,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppPalette.charcoal,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.aboutDescription,
                        style: const TextStyle(
                          color: AppPalette.mutedText,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.versionLabel('1.0.0'),
                        style: const TextStyle(
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

  Widget _localDesktopBody() {
    return Row(
      children: [
        NavigationRail(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) =>
              setState(() => _selectedIndex = index),
          backgroundColor: AppPalette.surface,
          selectedIconTheme:
              const IconThemeData(color: AppPalette.ochre, size: 28),
          unselectedIconTheme: IconThemeData(color: AppPalette.mutedText),
          selectedLabelTextStyle: const TextStyle(
            color: AppPalette.ochre,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelTextStyle: TextStyle(color: AppPalette.mutedText),
          labelType: NavigationRailLabelType.all,
          destinations: [
            NavigationRailDestination(
              icon: const Icon(Icons.dashboard_outlined),
              selectedIcon: const Icon(Icons.dashboard_rounded),
              label: Text(l10n.dashboard),
            ),
            NavigationRailDestination(
              icon: const Icon(Icons.people_outline_rounded),
              selectedIcon: const Icon(Icons.people_rounded),
              label: Text(l10n.audience),
            ),
            NavigationRailDestination(
              icon: const Icon(Icons.dynamic_feed_outlined),
              selectedIcon: const Icon(Icons.dynamic_feed_rounded),
              label: Text(l10n.feed),
            ),
            NavigationRailDestination(
              icon: const Icon(Icons.reviews_outlined),
              selectedIcon: const Icon(Icons.reviews_rounded),
              label: Text(l10n.reviews),
            ),
            NavigationRailDestination(
              icon: const Icon(Icons.business_center_outlined),
              selectedIcon: const Icon(Icons.business_center_rounded),
              label: Text(l10n.businessLabel),
            ),
          ],
        ),
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1400),
              child: NotificationListener<ScrollNotification>(
                onNotification: _handleScrollNotification,
                child: IndexedStack(
                  index: _selectedIndex,
                  children: [
                    BusinessDashboardScreen(
                      ownerId: LocalAuth.currentLocal?.email ?? '',
                    ),
                    BusinessAudienceScreen(
                      ownerId: LocalAuth.currentLocal?.email ?? '',
                    ),
                    VendorFeedScreen(),
                    VendorReviewsScreen(),
                    BusinessProfileScreen(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isHome = _selectedIndex == 0;
    final width = ResponsiveUtils.widthOf(context);
    final isDesktop = width >= Breakpoints.desktop;
    final isTablet = width >= Breakpoints.mobile && width < Breakpoints.tablet;

    final scaffold = Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      extendBody: true,
      appBar: isHome && (isDesktop || isTablet)
          ? DesktopTopAppBar(
              title: l10n.appTitle,
              subtitle: l10n.localBusinessPortal,
              searchController: _searchController,
              searchHint: l10n.searchHintEvents,
              onSearchChanged: (_) => setState(() {}),
              onProfileTap: () => setState(() => _selectedIndex = 4),
              profileImage: _profileImageProvider(LocalAuth.currentLocal),
              userName: LocalAuth.currentLocal?.name ?? l10n.localUser,
              userEmail: LocalAuth.currentLocal?.email,
            )
          : isHome
              ? null
              : AppBar(
                  automaticallyImplyLeading: false,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => setState(() => _selectedIndex = 0),
                  ),
                  title: LogoAppBarTitle(
                    _appBarTitleForIndex(_selectedIndex),
                  ),
                  backgroundColor: AppPalette.ochre,
                  foregroundColor: Colors.white,
                  elevation: 0,
                ),
      body: isDesktop
          ? _localDesktopBody()
          : NotificationListener<ScrollNotification>(
              onNotification: _handleScrollNotification,
              child: IndexedStack(
                index: _selectedIndex,
                children: [
                  BusinessDashboardScreen(
                    ownerId: LocalAuth.currentLocal?.email ?? '',
                  ),
                  BusinessAudienceScreen(
                    ownerId: LocalAuth.currentLocal?.email ?? '',
                  ),
                  VendorFeedScreen(),
                  VendorReviewsScreen(),
                  BusinessProfileScreen(),
                ],
              ),
            ),
      bottomNavigationBar: isDesktop ? null : _buildLocalBottomNav(),
    );

    // Wrap scaffold with solid dark navy background
    final withBackground = Stack(
      children: [
        // Dark navy background
        const Positioned.fill(
          child: ColoredBox(color: Color(0xFF0D1117)),
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

  bool _shouldToggleNav(bool nextVisible) {
    if (_navVisibleNotifier.value == nextVisible) return false;
    final now = DateTime.now();
    final last = _lastNavToggle;
    if (last != null && now.difference(last).inMilliseconds < 80) {
      return false;
    }
    _lastNavToggle = now;
    return true;
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification) {
      final delta = notification.scrollDelta ?? 0;
      if (delta > 2 && _shouldToggleNav(false)) {
        _navVisibleNotifier.value = false;
      } else if (delta < -2 && _shouldToggleNav(true)) {
        _navVisibleNotifier.value = true;
      }
    } else if (notification is ScrollEndNotification) {
      if (_shouldToggleNav(true)) {
        _navVisibleNotifier.value = true;
      }
    }
    return false;
  }

  Widget _buildLocalBottomNav() {
    return ValueListenableBuilder<bool>(
      valueListenable: _navVisibleNotifier,
      builder: (context, isVisible, child) => AnimatedSlide(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        offset: isVisible ? Offset.zero : const Offset(0, 1),
        child: child!,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppPalette.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.20),
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
                  icon: Icons.dashboard_rounded,
                  label: l10n.dashboard,
                  isSelected: _selectedIndex == 0,
                  onTap: () => setState(() => _selectedIndex = 0),
                ),
                _LocalNavItem(
                  icon: Icons.people_alt_rounded,
                  label: l10n.audience,
                  isSelected: _selectedIndex == 1,
                  onTap: () => setState(() => _selectedIndex = 1),
                ),
                _LocalNavItem(
                  icon: Icons.dynamic_feed_rounded,
                  label: l10n.feed,
                  isSelected: _selectedIndex == 2,
                  onTap: () => setState(() => _selectedIndex = 2),
                ),
                _LocalNavItem(
                  icon: Icons.reviews_rounded,
                  label: l10n.reviews,
                  isSelected: _selectedIndex == 3,
                  onTap: () => setState(() => _selectedIndex = 3),
                ),
                _LocalNavItem(
                  icon: Icons.business_center_rounded,
                  label: l10n.businessLabel,
                  isSelected: _selectedIndex == 4,
                  onTap: () => setState(() => _selectedIndex = 4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _appBarTitleForIndex(int index) {
    switch (index) {
      case 1:
        return l10n.audience;
      case 2:
        return l10n.feed;
      case 3:
        return l10n.reviews;
      case 4:
        return l10n.profile;
      case 0:
      default:
        return l10n.dashboard;
    }
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
  AppLocalizations get l10n => AppLocalizations.of(context)!;

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
                  labelText: l10n.displayName,
                  prefixIcon: const Icon(Icons.person_outline_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.trim().length < 2) {
                    return l10n.nameMinLength;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: l10n.phoneNumber,
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
                  labelText: l10n.suburb,
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
                    : Text(l10n.saveChanges),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _saving ? null : () => Navigator.pop(context),
                child: Text(l10n.cancel),
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
              color: isSelected ? AppPalette.ochre : AppPalette.mutedText,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppPalette.ochre : AppPalette.mutedText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
