import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:brisconnect/screens/attraction_detail_screen.dart';
import 'package:brisconnect/screens/food_detail_screen.dart';
import 'package:brisconnect/screens/stadium_detail_screen.dart';
import 'package:brisconnect/screens/visitor_event_detail_screen.dart';
import 'package:brisconnect/screens/visitor_interested_events_screen.dart';
import 'package:brisconnect/screens/visitor_saved_events_calendar_screen.dart';
import 'package:brisconnect/screens/profile_camera_capture_screen.dart';
import 'package:brisconnect/widgets/report_event_dialog.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/auth/visitor_auth.dart';
import 'package:brisconnect/services/approved_attraction_service.dart';
import 'package:brisconnect/services/discover_data_service.dart';
import 'package:brisconnect/services/event_repository.dart';
import 'package:brisconnect/services/visitor_notification_service.dart';
import 'package:brisconnect/screens/welcome_screen.dart';
import 'package:brisconnect/utils/error_messages.dart';
import 'package:brisconnect/utils/profile_image_utils.dart';
import 'visitor_notifications_screen.dart';
import 'visitor_settings_screen.dart';
import 'map_events_screen.dart';
import '../widgets/inline_status_message.dart';
import '../widgets/reusable_event_card.dart';
import '../widgets/logo_app_bar_title.dart';

class VisitorPortalScreen extends StatefulWidget {
  const VisitorPortalScreen({
    super.key,
    this.discoverItemsStreamOverride,
  });

  final Stream<List<Map<String, dynamic>>>? discoverItemsStreamOverride;

  @override
  State<VisitorPortalScreen> createState() => _VisitorPortalScreenState();
}

class _VisitorPortalScreenState extends State<VisitorPortalScreen> {
  final TextEditingController _searchController = TextEditingController();
  int _selectedIndex = 0;
  DateTime? _selectedEventDate;
  DiscoverDataService? _discoverDataService;
  ApprovedAttractionService? _approvedAttractionService;

  final Set<_VisitorFilterSection> _selectedSections = {
    _VisitorFilterSection.events,
    _VisitorFilterSection.historical,
    _VisitorFilterSection.food,
    _VisitorFilterSection.stadiums,
  };
  final Set<_VisitorPriceFilter> _selectedPriceFilters = {
    _VisitorPriceFilter.free,
    _VisitorPriceFilter.paid,
  };

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Stream<List<Map<String, dynamic>>> _discoverItemsStream() {
    return widget.discoverItemsStreamOverride ??
      (_discoverDataService ??= DiscoverDataService())
        .watchApprovedDiscoverItems();
  }

  List<Map<String, dynamic>> _filterItems(
    List<Map<String, dynamic>> items, {
    required _VisitorFilterSection section,
  }) {
    if (!_selectedSections.contains(section)) {
      return const [];
    }

    final query = _searchController.text.trim().toLowerCase();
    return items.where((item) {
      final matchesSection =
          (item['section'] as String? ?? '') == _sectionKey(section);
      final matchesSearch = query.isEmpty ||
          (item['title'] as String? ?? '').toLowerCase().contains(query) ||
          (item['description'] as String? ?? '')
              .toLowerCase()
              .contains(query) ||
          (item['location'] as String? ?? '').toLowerCase().contains(query);
      final matchesPrice =
          _selectedPriceFilters.any((p) => _itemMatchesPrice(item, p));
      final matchesDate = _selectedEventDate == null ||
          (() {
            final dateStr = (item['dateTime'] as String? ?? '').trim();
            final parsed = _parseDateFromString(dateStr);
            if (parsed == null) return false;
            final sel = _selectedEventDate!;
            return parsed.year == sel.year &&
                parsed.month == sel.month &&
                parsed.day == sel.day;
          })();
      return matchesSection && matchesSearch && matchesPrice && matchesDate;
    }).toList();
  }

  String _sectionKey(_VisitorFilterSection section) {
    switch (section) {
      case _VisitorFilterSection.events:
        return 'events';
      case _VisitorFilterSection.historical:
        return 'historical';
      case _VisitorFilterSection.food:
        return 'food';
      case _VisitorFilterSection.stadiums:
        return 'stadiums';
    }
  }

  bool _itemMatchesPrice(
      Map<String, dynamic> item, _VisitorPriceFilter filter) {
    final price = (item['price'] as String? ?? '').toLowerCase();
    if (filter == _VisitorPriceFilter.free) {
      return price.contains('free');
    } else {
      return !price.contains('free');
    }
  }

  DateTime? _parseDateFromString(String value) {
    final datePart = value.split('•').first.trim();

    final slashParts = datePart.split('/');
    if (slashParts.length == 3) {
      final day = int.tryParse(slashParts[0]);
      final month = int.tryParse(slashParts[1]);
      final year = int.tryParse(slashParts[2]);
      if (day != null && month != null && year != null) {
        return DateTime(year, month, day);
      }
    }

    final spaceParts = datePart.split(RegExp(r'\s+'));
    if (spaceParts.length >= 3) {
      final day = int.tryParse(spaceParts[0]);
      const monthMap = {
        'jan': 1,
        'feb': 2,
        'mar': 3,
        'apr': 4,
        'may': 5,
        'jun': 6,
        'jul': 7,
        'aug': 8,
        'sep': 9,
        'oct': 10,
        'nov': 11,
        'dec': 12,
      };
      final month = monthMap[spaceParts[1].toLowerCase()];
      final year = int.tryParse(spaceParts[2]);
      if (day != null && month != null && year != null) {
        return DateTime(year, month, day);
      }
    }

    return null;
  }

  String _formatFilterDate(DateTime date) {
    const monthNames = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${monthNames[date.month - 1]} ${date.year}';
  }

  String _sectionLabel(_VisitorFilterSection section) {
    switch (section) {
      case _VisitorFilterSection.events:
        return 'Events';
      case _VisitorFilterSection.historical:
        return 'Attractions';
      case _VisitorFilterSection.food:
        return 'Food';
      case _VisitorFilterSection.stadiums:
        return 'Stadiums';
    }
  }

  String _priceLabel(_VisitorPriceFilter filter) {
    switch (filter) {
      case _VisitorPriceFilter.free:
        return 'Free';
      case _VisitorPriceFilter.paid:
        return 'Paid';
    }
  }

  Future<void> _openFilterSheet() async {
    final sections = Set<_VisitorFilterSection>.from(_selectedSections);
    final prices = Set<_VisitorPriceFilter>.from(_selectedPriceFilters);
    DateTime? selectedDate = _selectedEventDate;

    final result = await showModalBottomSheet<
        ({
          Set<_VisitorFilterSection> sections,
          Set<_VisitorPriceFilter> prices,
          DateTime? selectedDate,
        })>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppPalette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Widget buildSectionTile(_VisitorFilterSection section) {
              return CheckboxListTile(
                value: sections.contains(section),
                contentPadding: EdgeInsets.zero,
                title: Text(_sectionLabel(section)),
                onChanged: (value) {
                  setModalState(() {
                    if (value == true) {
                      sections.add(section);
                    } else if (sections.length > 1) {
                      sections.remove(section);
                    }
                  });
                },
              );
            }

            Widget buildPriceTile(_VisitorPriceFilter filter) {
              return CheckboxListTile(
                value: prices.contains(filter),
                contentPadding: EdgeInsets.zero,
                title: Text(_priceLabel(filter)),
                onChanged: (value) {
                  setModalState(() {
                    if (value == true) {
                      prices.add(filter);
                    } else if (prices.length > 1) {
                      prices.remove(filter);
                    }
                  });
                },
              );
            }

            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            final maxSheetHeight = MediaQuery.of(context).size.height * 0.85;

            return SafeArea(
              top: false,
              child: AnimatedPadding(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                padding: EdgeInsets.only(bottom: bottomInset),
                child: SizedBox(
                  height: maxSheetHeight,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ListView(
                          physics: const ClampingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                          children: [
                            const Text(
                              'Filter Events',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: AppPalette.charcoal,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Sections',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppPalette.charcoal,
                              ),
                            ),
                            buildSectionTile(_VisitorFilterSection.events),
                            buildSectionTile(_VisitorFilterSection.historical),
                            buildSectionTile(_VisitorFilterSection.food),
                            buildSectionTile(_VisitorFilterSection.stadiums),
                            const SizedBox(height: 8),
                            const Text(
                              'Price',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppPalette.charcoal,
                              ),
                            ),
                            buildPriceTile(_VisitorPriceFilter.free),
                            buildPriceTile(_VisitorPriceFilter.paid),
                            const SizedBox(height: 12),
                            const Text(
                              'Date',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppPalette.charcoal,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (selectedDate == null)
                              OutlinedButton.icon(
                                onPressed: () async {
                                  final now = DateTime.now();
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: now,
                                    firstDate: DateTime(now.year - 1),
                                    lastDate: DateTime(now.year + 3),
                                  );
                                  if (picked != null) {
                                    setModalState(() => selectedDate = picked);
                                  }
                                },
                                icon: const Icon(
                                  Icons.calendar_today_rounded,
                                  size: 16,
                                ),
                                label: const Text('Pick a date'),
                              )
                            else
                              InputChip(
                                label: Text(_formatFilterDate(selectedDate!)),
                                onDeleted: () =>
                                    setModalState(() => selectedDate = null),
                                backgroundColor: AppPalette.surfaceAlt,
                                side: const BorderSide(color: AppPalette.border),
                              ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  Navigator.pop(
                                    context,
                                    (
                                      sections: Set<_VisitorFilterSection>.from(
                                        _VisitorFilterSection.values,
                                      ),
                                      prices: Set<_VisitorPriceFilter>.from(
                                        _VisitorPriceFilter.values,
                                      ),
                                      selectedDate: null,
                                    ),
                                  );
                                },
                                child: const Text('Reset'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(
                                    context,
                                    (
                                      sections: sections,
                                      prices: prices,
                                      selectedDate: selectedDate,
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppPalette.deepBlue,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Apply'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (result != null && mounted) {
      setState(() {
        _selectedSections
          ..clear()
          ..addAll(result.sections);
        _selectedPriceFilters
          ..clear()
          ..addAll(result.prices);
        _selectedEventDate = result.selectedDate;
      });
    }
  }

  bool get _hasCustomFilters {
    return _selectedSections.length != _VisitorFilterSection.values.length ||
        _selectedPriceFilters.length != _VisitorPriceFilter.values.length ||
        _selectedEventDate != null;
  }

  Widget _buildActiveFilterChips() {
    if (!_hasCustomFilters) {
      return const SizedBox.shrink();
    }

    final chips = <Widget>[
      ..._selectedSections.map(
        (section) => Chip(
          label: Text(_sectionLabel(section)),
          backgroundColor: AppPalette.surfaceAlt,
          side: const BorderSide(color: AppPalette.border),
        ),
      ),
      ..._selectedPriceFilters.map(
        (filter) => Chip(
          label: Text(_priceLabel(filter)),
          backgroundColor: AppPalette.surfaceAlt,
          side: const BorderSide(color: AppPalette.border),
        ),
      ),
      if (_selectedEventDate != null)
        Chip(
          label: Text(_formatFilterDate(_selectedEventDate!)),
          backgroundColor: AppPalette.surfaceAlt,
          side: const BorderSide(color: AppPalette.border),
        ),
      ActionChip(
        label: const Text('Clear filters'),
        backgroundColor: AppPalette.surfaceAlt,
        side: const BorderSide(color: AppPalette.border),
        onPressed: () {
          setState(() {
            _selectedSections
              ..clear()
              ..addAll(_VisitorFilterSection.values);
            _selectedPriceFilters
              ..clear()
              ..addAll(_VisitorPriceFilter.values);
            _selectedEventDate = null;
          });
        },
      ),
    ];

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: chips,
      ),
    );
  }

  void _toggleFavorite(String id, {Map<String, dynamic>? eventData}) {
    final didUpdate = VisitorAuth.toggleInterestedEvent(id);
    if (!didUpdate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in as a Visitor to save events.'),
        ),
      );
      return;
    }

    // Schedule notification if:
    // 1. Event was marked as interested (not removed)
    // 2. Notifications are enabled
    // 3. Event data is available
    final isNowInterested = VisitorAuth.isInterestedInEvent(id);
    if (isNowInterested &&
        VisitorAuth.areNotificationsEnabled() &&
        eventData != null) {
      final notificationService = VisitorNotificationService();
      final eventTitle = eventData['title'] as String? ?? 'Event';
      final eventDateTime = eventData['dateTime'] as String? ?? 'Date TBA';
      final eventLocation = eventData['location'] as String? ?? 'Location TBA';

      notificationService
          .scheduleNotificationForInterestedEvent(
        eventTitle: eventTitle,
        eventDatetime: eventDateTime,
        eventLocation: eventLocation,
        eventId: id,
        userEmail: VisitorAuth.currentVisitor?.email ?? '',
      )
          .catchError((e) {
        debugPrint('[VisitorPortal] Failed to schedule notification: $e');
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$eventTitle saved to Interested.')),
      );
    } else if (!isNowInterested && eventData != null) {
      final notificationService = VisitorNotificationService();
      final eventTitle = eventData['title'] as String? ?? 'Event';
      final eventDateTime = eventData['dateTime'] as String? ?? 'Date TBA';
      notificationService
          .cancelNotificationForInterestedEvent(
            eventTitle: eventTitle,
            eventDatetime: eventDateTime,
            eventId: id,
            userEmail: VisitorAuth.currentVisitor?.email ?? '',
          )
          .catchError((e) {
            debugPrint('[VisitorPortal] Failed to cancel notification: $e');
          });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$eventTitle removed from Interested.')),
      );
    }

    setState(() {});
  }

  Future<void> _openWebLink(String link) async {
    if (link.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('No external link available for this item yet.')),
        );
      }
      return;
    }

    try {
      final uri = Uri.parse(link);
      final didLaunch =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!mounted) {
        return;
      }
      if (!didLaunch && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Unable to open the event link right now.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Unable to open the event link right now.')),
        );
      }
      if (!mounted) {
        return;
      }
    }
  }

  void _showItemDetails(Map<String, dynamic> item) {
    final imageUrl = (item['imageUrl'] as String? ?? '').trim();
    final title = (item['title'] as String? ?? 'Event').trim();
    final description = (item['description'] as String? ?? '').trim();
    final dateTime = (item['dateTime'] as String? ?? '').trim();
    final location = (item['location'] as String? ?? '').trim();
    final price = (item['price'] as String? ?? '').trim();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppPalette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: AppPalette.border,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                ReusableEventCard(
                  imageUrl: imageUrl,
                  badgeText: item['badge'] as String? ?? '',
                  title: title,
                  description: description,
                  dateTime: dateTime,
                  location: location,
                  price: price,
                  onShareTap: null,
                  onWebTap: null,
                  onFavoriteTap: null,
                ),
                if (description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      description,
                      style: const TextStyle(
                        color: AppPalette.charcoal,
                        height: 1.4,
                      ),
                    ),
                  ),
              ],
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
      await (_approvedAttractionService ??= ApprovedAttractionService())
        .fetchApprovedAttractions();
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

  Future<void> _openFoodDetails(Map<String, dynamic> item) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FoodDetailScreen(
          title: (item['title'] as String? ?? 'Food Experience').trim(),
          description: (item['description'] as String? ?? '').trim(),
          location: (item['location'] as String? ?? '').trim(),
          cuisine: (item['cuisine'] as String? ?? '').trim(),
          imageUrl: (item['imageUrl'] as String? ?? '').trim(),
          categories:
              List<String>.from(item['categories'] as List? ?? const []),
          rating: (item['rating'] as num?)?.toDouble(),
          badge: (item['badge'] as String? ?? 'Food').trim(),
          dateTime: (item['dateTime'] as String? ?? '').trim(),
          price: (item['price'] as String? ?? '').trim(),
          mapQuery: (item['mapQuery'] as String? ?? '').trim(),
          webLink: (item['webLink'] as String? ?? '').trim(),
          aiAudio: (item['aiAudio'] as String? ?? '').trim(),
        ),
      ),
    );
  }

  Future<void> _openStadiumDetails(Map<String, dynamic> item) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StadiumDetailScreen(
          title: (item['title'] as String? ?? 'Stadium').trim(),
          description: (item['description'] as String? ?? '').trim(),
          location: (item['location'] as String? ?? '').trim(),
          imageUrl: (item['imageUrl'] as String? ?? '').trim(),
          categories:
              List<String>.from(item['categories'] as List? ?? const []),
          badge: (item['badge'] as String? ?? 'Stadium').trim(),
          dateTime: (item['dateTime'] as String? ?? '').trim(),
          price: (item['price'] as String? ?? '').trim(),
          mapQuery: (item['mapQuery'] as String? ?? '').trim(),
          webLink: (item['webLink'] as String? ?? '').trim(),
          aiAudio: (item['aiAudio'] as String? ?? '').trim(),
        ),
      ),
    );
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
                hintText: 'Find things to do in Brisbane',
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
              onPressed: _openFilterSheet,
              icon: const Icon(Icons.tune_rounded, size: 20),
              color: AppPalette.deepBlue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapBanner() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const MapEventsScreen(),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppPalette.deepBlue, Color(0xFF2A5298)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: AppPalette.cardShadow,
              blurRadius: 12,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child:
                  const Icon(Icons.map_rounded, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Explore Brisbane on Map',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Cultural, Events, Historical and Olympic venues',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.white70, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildEventCard(Map<String, dynamic> item) {
    final id = item['id'] as String? ?? '';
    final section = (item['section'] as String? ?? '').trim();
    final isEvent = section == 'events';
    final visitorEmail = VisitorAuth.currentVisitor?.email ?? '';
   
     return Column(
       children: [
         ReusableEventCard(
      imageUrl: item['imageUrl'] as String? ?? '',
      badgeText: item['badge'] as String? ?? '',
      title: item['title'] as String? ?? 'Event',
      description: item['description'] as String? ?? '',
      dateTime: item['dateTime'] as String? ?? '',
      location: item['location'] as String? ?? '',
      price: item['price'] as String? ?? '',
      isFavorite: VisitorAuth.isInterestedInEvent(id),
      onShareTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Share: ${item['title'] ?? 'Event'}')),
        );
      },
      onCardTap: () async {
        final section = (item['section'] as String? ?? '').trim();
        if (section == 'events') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => VisitorEventDetailScreen(event: item),
            ),
          );
          return;
        }
        if (section == 'food') {
          await _openFoodDetails(item);
          return;
        }
        if (section == 'stadiums') {
          await _openStadiumDetails(item);
          return;
        }
        final openedAttraction = await _openAttractionDetailsIfAvailable(item);
        if (!openedAttraction && mounted) {
          _showItemDetails(item);
        }
      },
      onWebTap: () async {
        final section = (item['section'] as String? ?? '').trim();
        final link = (item['webLink'] as String? ?? '').trim();
        if (section == 'events') {
          if (link.isNotEmpty) {
            _openWebLink(link);
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => VisitorEventDetailScreen(event: item),
              ),
            );
          }
          return;
        }
        if (section == 'food' && link.isEmpty) {
          await _openFoodDetails(item);
          return;
        }
        if (section == 'stadiums' && link.isEmpty) {
          await _openStadiumDetails(item);
          return;
        }
        if (link.isEmpty) {
          final openedAttraction =
              await _openAttractionDetailsIfAvailable(item);
          if (!openedAttraction && mounted) {
            _showItemDetails(item);
          }
          return;
        }
        _openWebLink(link);
      },
      onFavoriteTap: () => _toggleFavorite(id, eventData: item),
       ),
       if (isEvent && visitorEmail.isNotEmpty)
         Padding(
           padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
           child: SizedBox(
             width: double.infinity,
             child: TextButton.icon(
               onPressed: () async {
                 final result = await ReportEventDialog.show(
                   context: context,
                   eventId: id,
                   visitorEmail: visitorEmail,
                 );
                 if (result == true && mounted) {
                   setState(() {});
                 }
               },
               icon: const Icon(Icons.flag, size: 18),
               label: const Text('Report Event'),
               style: TextButton.styleFrom(
                 foregroundColor: Colors.red,
               ),
             ),
           ),
         ),
     ],
   );
  }

  Widget _buildDiscoverBody() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _discoverItemsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          final message = AppErrorMessages.fromException(
            snapshot.error,
            fallback: 'Unable to load events right now. Please try again.',
          );
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: InlineStatusMessage(
                message: message,
                type: InlineStatusType.error,
                actionLabel: 'Retry',
                onAction: () => setState(() {}),
              ),
            ),
          );
        }

        final allItems = snapshot.data ?? [];
        final filteredItems = <Map<String, dynamic>>[
          ..._filterItems(allItems, section: _VisitorFilterSection.events),
          ..._filterItems(allItems, section: _VisitorFilterSection.historical),
          ..._filterItems(allItems, section: _VisitorFilterSection.food),
          ..._filterItems(allItems, section: _VisitorFilterSection.stadiums),
        ];

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Welcome, ${VisitorAuth.currentVisitor?.name ?? 'Visitor'}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppPalette.charcoal,
                    ),
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Notifications',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const VisitorNotificationsScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.notifications_none_rounded),
                  color: AppPalette.deepBlue,
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'Interested events',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const VisitorInterestedEventsScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.favorite_rounded),
                  color: AppPalette.ochre,
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Discover Brisbane events, heritage, and food experiences',
              style: TextStyle(
                color: AppPalette.mutedText,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 14),
            _buildSearchBar(),
            _buildActiveFilterChips(),
            const SizedBox(height: 14),
            _buildMapBanner(),
            const SizedBox(height: 18),
            if (filteredItems.isEmpty)
              const _EmptyState(
                title: 'No discovery items available',
                subtitle:
                    'Try changing your search or filters to see more results.',
              )
            else ...[
              const _SectionHeader(
                title: 'Discovery Feed',
                subtitle:
                    'Cultural events, food, historical places and stadiums',
              ),
              ...filteredItems.map(_buildEventCard),
            ],
          ],
        );
      },
    );
  }

  Widget _buildSavedBody() {
    return ValueListenableBuilder<int>(
      valueListenable: VisitorAuth.interestedEventsVersion,
      builder: (context, _, __) {
        final savedIds = VisitorAuth.getInterestedEventIds();

        if (savedIds.isEmpty) {
          return const Center(
            child: _EmptyState(
              title: 'No saved items yet',
              subtitle:
                  'Tap the heart icon on discovery cards to save events here.',
            ),
          );
        }

        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: _discoverItemsStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              final message = AppErrorMessages.fromException(
                snapshot.error,
                fallback:
                    'Unable to load saved items right now. Please try again.',
              );
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: InlineStatusMessage(
                    message: message,
                    type: InlineStatusType.error,
                    actionLabel: 'Retry',
                    onAction: () => setState(() {}),
                  ),
                ),
              );
            }

            final allItems = snapshot.data ?? const <Map<String, dynamic>>[];
            final savedDiscoverItems = allItems.where((item) {
              final id = (item['id'] as String? ?? '').trim();
              return id.isNotEmpty && savedIds.contains(id);
            }).toList();

            final savedRepoItems = EventRepository.getApprovedEvents()
                .where((event) => savedIds.contains(event.id))
                .where(
                  (event) => !savedDiscoverItems.any(
                    (item) =>
                        ((item['id'] as String? ?? '').trim() == event.id),
                  ),
                )
                .map<Map<String, dynamic>>(
                  (event) => {
                    'id': event.id,
                    'section': 'events',
                    'imageUrl': event.imageAsset ?? '',
                    'badge': 'EVENT',
                    'title': event.title,
                    'description': event.description,
                    'dateTime': '${event.date} • ${event.time}',
                    'location': event.location,
                    'price': 'Price TBA',
                    'webLink': '',
                  },
                )
                .toList();

            final savedItems = <Map<String, dynamic>>[
              ...savedDiscoverItems,
              ...savedRepoItems,
            ];

            if (savedItems.isEmpty) {
              return const Center(
                child: _EmptyState(
                  title: 'Saved items unavailable',
                  subtitle:
                      'Some saved items are no longer published in discovery feed.',
                ),
              );
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: _SectionHeader(
                        title: 'Saved Items',
                        subtitle:
                            'Quick access to events you marked with heart icon',
                      ),
                    ),
                    IconButton.filledTonal(
                      tooltip: 'Calendar view',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => VisitorSavedEventsCalendarScreen(
                              savedItems: savedItems,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.calendar_month_rounded),
                      color: AppPalette.deepBlue,
                    ),
                  ],
                ),
                ...savedItems.map(_buildEventCard),
              ],
            );
          },
        );
      },
    );
  }

  // ── Profile helpers ────────────────────────────────────────────────────

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
      final bytes = base64Decode(raw);
      return MemoryImage(bytes);
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

  Future<void> _uploadVisitorProfileImage() async {
    final visitor = VisitorAuth.currentVisitor;
    if (visitor == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in as a Visitor first.')),
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
    final ok = await VisitorAuth.updateProfileImage(encoded);
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

  Future<void> _showEditProfileSheet(String currentName, String currentEmail) async {
    final formKey = GlobalKey<FormState>();
    bool saving = false;
    String editedName = currentName;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppPalette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            MediaQuery.of(sheetContext).viewInsets.bottom + 24,
          ),
          child: StatefulBuilder(
            builder: (_, setSheetState) {
              return Form(
                key: formKey,
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
                      initialValue: currentName,
                      autofocus: true,
                      textCapitalization: TextCapitalization.words,
                      onChanged: (value) => editedName = value,
                      decoration: InputDecoration(
                        labelText: 'Display name',
                        hintText: 'Enter your name',
                        prefixIcon: const Icon(Icons.person_outline_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Name cannot be empty.';
                        }
                        if (value.trim().length < 2) {
                          return 'Name must be at least 2 characters.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: currentEmail,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        prefixIcon: const Icon(Icons.alternate_email_rounded),
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
                      onPressed: saving
                          ? null
                          : () async {
                              if (!formKey.currentState!.validate()) return;
                              setSheetState(() => saving = true);
                              final ok = await VisitorAuth.updateName(
                                editedName,
                              );
                              if (!sheetContext.mounted) return;
                              Navigator.pop(sheetContext);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      ok
                                          ? 'Profile updated successfully.'
                                          : 'Could not update profile. Please try again.',
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
                                color: Colors.white,
                              ),
                            )
                          : const Text('Save Changes'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await VisitorAuth.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (route) => false,
    );
  }

  Widget _buildProfileBody() {
    return ValueListenableBuilder<int>(
      valueListenable: VisitorAuth.profileVersion,
      builder: (context, _, __) {
        final visitor = VisitorAuth.currentVisitor;
        final savedCount = VisitorAuth.getInterestedEventIds().length;
        final displayName = visitor?.name ?? 'Visitor User';
        final displayEmail = visitor?.email ?? '';
        final profileImage = _profileImageProvider(visitor?.profileImageBase64);

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 36),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Profile',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppPalette.charcoal,
                    ),
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Settings',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const VisitorSettingsScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.settings_rounded),
                  color: AppPalette.deepBlue,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Profile header card ──────────────────────────────────
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
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppPalette.charcoal,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            displayEmail,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppPalette.mutedText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: visitor?.profileImageBase64?.isNotEmpty == true
                          ? 'Change profile picture'
                          : 'Upload profile picture',
                      onPressed: _uploadVisitorProfileImage,
                      icon: const Icon(
                        Icons.photo_camera_outlined,
                        color: AppPalette.deepBlue,
                        size: 20,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Edit profile',
                      onPressed: () =>
                          _showEditProfileSheet(displayName, displayEmail),
                      icon: const Icon(
                        Icons.edit_rounded,
                        color: AppPalette.deepBlue,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ── My Activity ─────────────────────────────────────────
            _buildSectionLabel('My Activity'),
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
                        color: AppPalette.ochre.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.favorite_rounded,
                        color: AppPalette.ochre,
                        size: 20,
                      ),
                    ),
                    title: const Text(
                      'Saved & Interested Events',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      savedCount > 0
                          ? '$savedCount item${savedCount == 1 ? '' : 's'} saved'
                          : 'No saved events yet',
                    ),
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                      color: AppPalette.mutedText,
                    ),
                    onTap: () => setState(() => _selectedIndex = 1),
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
                        size: 20,
                      ),
                    ),
                    title: const Text(
                      'Event Notifications',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle:
                        const Text('Reminders for your interested events'),
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                      color: AppPalette.mutedText,
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const VisitorNotificationsScreen(),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Preferences ─────────────────────────────────────────
            _buildSectionLabel('Preferences'),
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
                    color: AppPalette.deepBlue.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.settings_rounded,
                    color: AppPalette.deepBlue,
                    size: 20,
                  ),
                ),
                title: const Text(
                  'Settings',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Manage notifications and preferences'),
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: AppPalette.mutedText,
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const VisitorSettingsScreen(),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ── Account ─────────────────────────────────────────────
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
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.logout_rounded,
                    color: Colors.red.shade700,
                    size: 20,
                  ),
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
    return Scaffold(
      backgroundColor: const Color(0xFFF8F3EA),
      appBar: AppBar(
        title: const LogoAppBarTitle('Visitor Portal'),
        backgroundColor: AppPalette.deepBlue,
      ),
      body: SafeArea(
        child: IndexedStack(
          index: _selectedIndex,
          children: [
            _buildDiscoverBody(),
            _buildSavedBody(),
            _buildProfileBody(),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        selectedItemColor: AppPalette.ochre,
        unselectedItemColor: AppPalette.deepBlue,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.explore_rounded),
            label: 'Discover',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite_border_rounded),
            activeIcon: Icon(Icons.favorite_rounded),
            label: 'Saved',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded),
            activeIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({required this.title, required this.subtitle});

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

class _EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;

  const _EmptyState({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppPalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppPalette.charcoal,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(color: AppPalette.mutedText),
          ),
        ],
      ),
    );
  }
}

enum _VisitorFilterSection { events, historical, food, stadiums }

enum _VisitorPriceFilter { free, paid }
