// ignore_for_file: unused_element, unused_field, unused_local_variable

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';

import 'package:brisconnect/screens/food_detail_screen.dart';
import 'package:brisconnect/screens/stadium_detail_screen.dart';
import 'package:brisconnect/screens/visitor_event_detail_screen.dart';
import 'package:brisconnect/widgets/report_event_dialog.dart';
import 'package:brisconnect/widgets/food_review_dialog.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/utils/venue_image_fallback.dart';
import 'package:brisconnect/auth/visitor_auth.dart';

import 'package:brisconnect/services/firestore_service.dart';
import 'package:brisconnect/services/location_utilities.dart';
import 'package:brisconnect/services/olympic_event_email_service.dart';
import 'package:brisconnect/services/visitor_notification_service.dart';
import 'package:brisconnect/screens/welcome_screen.dart';
import 'package:brisconnect/services/firebase_media_service.dart';
import 'package:brisconnect/utils/error_messages.dart';
import 'package:brisconnect/utils/profile_image_utils.dart';
import 'package:brisconnect/screens/food_business_discovery_screen.dart';
import 'visitor_settings_screen.dart';
import 'appearance_settings_screen.dart';
import 'my_feedback_screen.dart';
import 'map_events_screen.dart';
import 'business_search_screen.dart';
import 'visitor_activity_feed_screen.dart';
import '../widgets/inline_status_message.dart';
import '../widgets/reusable_event_card.dart';
import '../widgets/logo_app_bar_title.dart';
import '../widgets/help_support_sheet.dart';

class VisitorPortalScreen extends StatefulWidget {
  const VisitorPortalScreen({
    super.key,
  });

  @override
  State<VisitorPortalScreen> createState() => _VisitorPortalScreenState();
}

class _VisitorPortalScreenState extends State<VisitorPortalScreen> {
  final TextEditingController _searchController = TextEditingController();
  FirebaseMediaService? _mediaService;
  Uint8List? _pendingProfileImageBytes;
  Timer? _searchDebounce;
  int _selectedIndex = 0;
  bool _isNavVisible = true;
  DateTime? _selectedEventDate;
  FirestoreService? _firestoreService;
  Stream<List<Map<String, dynamic>>>? _discoverRadiusStreamCache;
  Stream<List<Map<String, dynamic>>>? _approvedEventsStreamCache;
  late double _userLatitude;
  late double _userLongitude;
  late int _radiusKm;
  late bool _isUsingRadius;

  final Set<_VisitorFilterSection> _selectedSections = {
    _VisitorFilterSection.food,
  };
  final Set<_VisitorPriceFilter> _selectedPriceFilters = {
    _VisitorPriceFilter.free,
    _VisitorPriceFilter.paid,
  };
  @override
  void initState() {
    super.initState();
    // Stream caches are lazily initialized in _discoverItemsStream().
    _updateUserPreferences();

    final visitor = VisitorAuth.currentVisitor;
    if (visitor != null) {
      () async {
        try {
          await OlympicEventEmailService()
              .queueUpcomingOlympicEventEmailsForOptedInVisitors();
        } catch (error) {
          debugPrint('[VisitorPortal] Olympic email dispatch failed: $error');
        }
      }();
    }
  }

  void _updateUserPreferences() {

    final visitor = VisitorAuth.currentVisitor;
    if (visitor != null) {
      _radiusKm = visitor.locationRadiusKm;
      _isUsingRadius = visitor.useCurrentLocation;
    } else {
      _radiusKm = 20;
      _isUsingRadius = false;
    }

    // Use default Brisbane location
    final (defaultLat, defaultLon) = LocationUtilities.getDefaultLocation();
    _userLatitude = defaultLat;
    _userLongitude = defaultLon;
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
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

  FirebaseMediaService get _effectiveMediaService {
    return _mediaService ??= FirebaseMediaService();
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
      final categoryList = (item['categories'] as List?)
              ?.map((v) => '$v'.trim().toLowerCase())
              .toList(growable: false) ??
          const <String>[];
      final singleCategory =
          (item['category'] as String? ?? '').toLowerCase();
      final sectionVal = (item['section'] as String? ?? '').toLowerCase();
      final matchesSearch = query.isEmpty ||
          (item['title'] as String? ?? '').toLowerCase().contains(query) ||
          (item['description'] as String? ?? '')
              .toLowerCase()
              .contains(query) ||
          (item['location'] as String? ?? '').toLowerCase().contains(query) ||
          sectionVal.contains(query) ||
          singleCategory.contains(query) ||
          categoryList.any((c) => c.contains(query));
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

  bool _isApprovedItem(Map<String, dynamic> item) {
    final approvalStatus =
        (item['approvalStatus'] as String? ?? '').trim().toLowerCase();
    final reviewStatus =
        (item['reviewStatus'] as String? ?? '').trim().toLowerCase();
    final status = (item['status'] as String? ?? '').trim().toLowerCase();
    final isApproved = (item['isApproved'] as bool?) ?? false;

    if (approvalStatus.isEmpty && reviewStatus.isEmpty && status.isEmpty) {
      return true;
    }
    return isApproved ||
        approvalStatus == 'approved' ||
        reviewStatus == 'approved' ||
        status == 'approved';
  }

  Set<String> _itemInterestTags(Map<String, dynamic> item) {
    final tags = <String>{};

    final badge = (item['badge'] as String? ?? '').trim().toLowerCase();
    if (badge.contains('music')) tags.add('music');
    if (badge.contains('culture')) tags.add('culture');
    if (badge.contains('sport')) tags.add('sports');
    if (badge.contains('histor')) tags.add('historical');

    final categoryValues = (item['categories'] as List?)
            ?.map((value) => '$value'.trim().toLowerCase())
            .where((value) => value.isNotEmpty)
            .toList(growable: false) ??
        const <String>[];
    tags.addAll(categoryValues);

    final title = (item['title'] as String? ?? '').toLowerCase();
    if (title.contains('music') || title.contains('concert')) {
      tags.add('music');
    }
    if (title.contains('culture') || title.contains('festival')) {
      tags.add('culture');
    }
    if (title.contains('sport') || title.contains('stadium')) {
      tags.add('sports');
    }

    return tags.map(_normalizeInterestTag).toSet();
  }

  String _normalizeInterestTag(String raw) {
    final value = raw.trim().toLowerCase();
    if (value.isEmpty) return '';
    if (value.startsWith('sport')) return 'sports';
    if (value.startsWith('histor')) return 'historical';
    if (value == 'history') return 'historical';
    if (value == 'event') return 'events';
    if (value.contains('culture')) return 'culture';
    if (value.contains('music')) return 'music';
    if (value.contains('food') || value.contains('dining')) return 'food';
    if (value.contains('stadium')) return 'stadiums';
    return value;
  }

  List<Map<String, dynamic>> _recommendedItems(
    List<Map<String, dynamic>> allItems,
  ) {
    final interestedIds = VisitorAuth.getInterestedEventIds();
    if (interestedIds.isEmpty) {
      return const <Map<String, dynamic>>[];
    }

    final interestTags = <String>{};
    for (final item in allItems) {
      final id = (item['id'] as String? ?? '').trim();
      if (id.isEmpty || !interestedIds.contains(id)) {
        continue;
      }
      interestTags.addAll(_itemInterestTags(item));
    }

    if (interestTags.isEmpty) {
      return const <Map<String, dynamic>>[];
    }

    final scored = <({Map<String, dynamic> item, int score})>[];
    for (final item in allItems) {
      final id = (item['id'] as String? ?? '').trim();
      final section = (item['section'] as String? ?? '').trim().toLowerCase();
      if (id.isEmpty || interestedIds.contains(id) || section != 'events') {
        continue;
      }
      if (!_isApprovedItem(item)) {
        continue;
      }

      final tags = _itemInterestTags(item);
      final overlapCount = tags.where(interestTags.contains).length;
      final score = overlapCount;
      if (score > 0) {
        scored.add((item: item, score: score));
      }
    }

    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) {
        return byScore;
      }
      final aTitle = (a.item['title'] as String? ?? '').toLowerCase();
      final bTitle = (b.item['title'] as String? ?? '').toLowerCase();
      return aTitle.compareTo(bTitle);
    });

    return scored.take(6).map((entry) => entry.item).toList(growable: false);
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
                                side:
                                    const BorderSide(color: AppPalette.border),
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
    return _selectedPriceFilters.length != _VisitorPriceFilter.values.length ||
        _selectedPriceFilters.length != _VisitorPriceFilter.values.length ||
        _selectedEventDate != null;
  }

  Widget _buildActiveFilterChips() {
    if (!_hasCustomFilters) {
      return const SizedBox.shrink();
    }

    final chips = <Widget>[
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
              ..add(_VisitorFilterSection.food);
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

  void _toggleSavedItem(String id, {Map<String, dynamic>? itemData}) {
    final section =
        (itemData?['section'] as String? ?? '').trim().toLowerCase();
    final isEvent = section == 'events';

    final didUpdate = isEvent
        ? VisitorAuth.toggleInterestedEvent(id)
        : VisitorAuth.toggleSavedAttraction(id);
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
    final isNowSaved = isEvent
        ? VisitorAuth.isInterestedInEvent(id)
        : VisitorAuth.isAttractionSaved(id);
    if (isEvent &&
        isNowSaved &&
        VisitorAuth.areEventRemindersEnabled() &&
        itemData != null) {
      final notificationService = VisitorNotificationService();
      final eventTitle = itemData['title'] as String? ?? 'Event';
      final eventDateTime = itemData['dateTime'] as String? ?? 'Date TBA';
      final eventLocation = itemData['location'] as String? ?? 'Location TBA';

      notificationService
          .scheduleNotificationForInterestedEvent(
        eventTitle: eventTitle,
        eventDatetime: eventDateTime,
        eventLocation: eventLocation,
        eventId: id,
        userEmail: VisitorAuth.currentVisitor?.email ?? '',
        reminderTiming: VisitorAuth.getReminderTiming(),
      )
          .catchError((e) {
        debugPrint('[VisitorPortal] Failed to schedule notification: $e');
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$eventTitle saved to Interested.')),
      );
    } else if (isEvent && !isNowSaved && itemData != null) {
      final notificationService = VisitorNotificationService();
      final eventTitle = itemData['title'] as String? ?? 'Event';
      final eventDateTime = itemData['dateTime'] as String? ?? 'Date TBA';
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
    } else {
      final title = itemData?['title'] as String? ?? 'Attraction';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isNowSaved
                ? '$title saved to Saved Attractions.'
                : '$title removed from Saved Attractions.',
          ),
        ),
      );
    }

    setState(() {});
  }

  void _showFoodReviewDialog(Map<String, dynamic> item) {
    final foodTitle = item['title'] as String? ?? 'Food Place';
    final foodId = item['id'] as String? ?? '';
    
    showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => FoodReviewDialog(
        foodTitle: foodTitle,
        existingReview: null,
        existingRating: null,
        existingBuzzRating: null,
      ),
    ).then((result) {
      if (result != null && mounted) {
        final review = result['review'] as String? ?? '';
        final rating = result['rating'] as double? ?? 0;
        final buzzRating = result['buzzRating'] as double? ?? 0;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Review submitted! ⭐ ${rating.toInt()} / Buzz ⚡ ${buzzRating.toInt()}',
            ),
            duration: const Duration(seconds: 2),
          ),
        );

        // TODO: Save review data to Firestore
        // Future implementation:
        // - Store review with foodId, visitorEmail, timestamp
        // - Update food item's aggregate rating
        // - Track buzz rating trend
      }
    });
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
                  section: (item['section'] as String? ?? '').trim(),
                  description: description,
                  dateTime: dateTime,
                  location: location,
                  price: price,
                  source: item['source'] as String?,
                  venue: item['venue'] as String?,
                  categories: (item['categories'] as List<dynamic>?)
                      ?.map((e) => e.toString())
                      .toList(),
                  cuisine: item['cuisine'] as String?,
                  rating: (item['rating'] as num?)?.toDouble(),
                  onShareTap: null,
                  onWebTap: null,
                  onFavoriteTap: null,
                  cardColor: AppPalette.surface.withValues(alpha: 0.80),
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
    // Attractions have been removed; always return false
    return false;
  }

  Future<void> _openFoodDetails(Map<String, dynamic> item) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FoodDetailScreen(
          id: (item['id'] as String? ?? '').trim(),
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
          id: (item['id'] as String? ?? '').trim(),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      decoration: BoxDecoration(
        color: AppPalette.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(30),
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
              onChanged: (_) {
                _searchDebounce?.cancel();
                _searchDebounce = Timer(const Duration(milliseconds: 300), () {
                  if (mounted) setState(() {});
                });
              },
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => FocusScope.of(context).unfocus(),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Search local food businesses...',
                hintStyle: TextStyle(color: AppPalette.mutedText),
              ),
            ),
          ),
          GestureDetector(
            onTap: _openFilterSheet,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppPalette.surfaceAlt,
                shape: BoxShape.circle,
                border: Border.all(color: AppPalette.border.withValues(alpha: 0.5)),
              ),
              child: const Icon(Icons.mic_rounded, size: 18, color: AppPalette.mutedText),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(Map<String, dynamic> item) {
    final id = item['id'] as String? ?? '';
    final section = (item['section'] as String? ?? '').trim();
    final isEvent = section == 'events';
    final visitorEmail = VisitorAuth.currentVisitor?.email ?? '';
    final isFavorite = isEvent
        ? VisitorAuth.isInterestedInEvent(id)
        : VisitorAuth.isAttractionSaved(id);

    return Column(
      children: [
        ReusableEventCard(
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
            final openedAttraction =
                await _openAttractionDetailsIfAvailable(item);
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
          onReviewTap: () {
            final section = (item['section'] as String? ?? '').trim();
            if (section == 'food') {
              _showFoodReviewDialog(item);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Reviews are only available for food items'),
                ),
              );
            }
          },
          onFavoriteTap: () => _toggleSavedItem(id, itemData: item),
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

  Widget _buildRecommendedCarousel(List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recommended for You',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppPalette.charcoal,
                ),
              ),
              GestureDetector(
                onTap: () {},
                child: const Row(
                  children: [
                    Text(
                      'See All',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppPalette.ochre,
                      ),
                    ),
                    SizedBox(width: 2),
                    Icon(Icons.chevron_right_rounded,
                        color: AppPalette.ochre, size: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 210,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final item = items[index];
              final id = (item['id'] as String? ?? '').trim();
              final imageUrl = (item['imageUrl'] as String? ?? '').trim();
              final title = (item['title'] as String? ?? 'Event').trim();
              final dateTime = (item['dateTime'] as String? ?? '').trim();
              final location = (item['location'] as String? ?? '').trim();
              final section = (item['section'] as String? ?? '').trim();
              final badge = (item['badge'] as String? ?? '').trim();
              final venueFallback = VenueImageFallback.forVenue(
                title: title,
                section: section,
                badge: badge,
              );
              final resolvedImageUrl = imageUrl.isNotEmpty ? imageUrl : venueFallback;
              final isEvent = section == 'events';
              final isFavorite = isEvent
                  ? VisitorAuth.isInterestedInEvent(id)
                  : VisitorAuth.isAttractionSaved(id);

              return GestureDetector(
                onTap: () async {
                  if (section == 'events') {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => VisitorEventDetailScreen(event: item),
                    ));
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
                  final opened = await _openAttractionDetailsIfAvailable(item);
                  if (!opened && mounted) _showItemDetails(item);
                },
                child: SizedBox(
                  width: 170,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Image card
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: CachedNetworkImage(
                              imageUrl: resolvedImageUrl,
                              height: 130,
                              width: 170,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(
                                height: 130,
                                width: 170,
                                decoration: BoxDecoration(
                                  color: AppPalette.surfaceAlt,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                ),
                              ),
                              errorWidget: (_, __, ___) => Image.network(
                                venueFallback,
                                height: 130,
                                width: 170,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  height: 130,
                                  width: 170,
                                  decoration: BoxDecoration(
                                    color: AppPalette.surfaceAlt,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Icon(Icons.image_rounded,
                                      color: AppPalette.mutedText, size: 36),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: GestureDetector(
                              onTap: () => _toggleSavedItem(id, itemData: item),
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isFavorite
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_border_rounded,
                                  size: 18,
                                  color: isFavorite
                                      ? Colors.red
                                      : AppPalette.mutedText,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppPalette.charcoal,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      if (dateTime.isNotEmpty || location.isNotEmpty)
                        Text(
                          [dateTime, location]
                              .where((s) => s.isNotEmpty)
                              .join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppPalette.mutedText,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryChips() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Categories',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppPalette.charcoal,
            ),
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              _CategoryChip(
                label: 'Food',
                emoji: '🍴',
                isSelected: _selectedSections
                    .contains(_VisitorFilterSection.food),
                onTap: () {
                  setState(() {
                    _selectedSections
                      ..clear()
                      ..add(_VisitorFilterSection.food);
                  });
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNearbySection(List<Map<String, dynamic>> items) {
    // Pick items with location set, limit to 5
    final nearby = items
        .where((item) =>
            (item['location'] as String? ?? '').trim().isNotEmpty)
        .take(5)
        .toList();

    if (nearby.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Nearby',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppPalette.charcoal,
            ),
          ),
        ),
        const SizedBox(height: 10),
        ...nearby.map((item) {
          final title = (item['title'] as String? ?? 'Place').trim();
          final location = (item['location'] as String? ?? '').trim();
          final imageUrl = (item['imageUrl'] as String? ?? '').trim();
          final section = (item['section'] as String? ?? '').trim();

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: GestureDetector(
              onTap: () async {
                if (section == 'events') {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => VisitorEventDetailScreen(event: item),
                  ));
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
                final opened = await _openAttractionDetailsIfAvailable(item);
                if (!opened && mounted) _showItemDetails(item);
              },
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppPalette.surface.withValues(alpha: 0.80),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppPalette.border.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: imageUrl.isNotEmpty
                          ? Image.network(
                              imageUrl,
                              width: 64,
                              height: 64,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 64,
                                height: 64,
                                color: AppPalette.surfaceAlt,
                                child: const Icon(Icons.place_rounded,
                                    color: AppPalette.mutedText),
                              ),
                            )
                          : Container(
                              width: 64,
                              height: 64,
                              color: AppPalette.surfaceAlt,
                              child: const Icon(Icons.place_rounded,
                                  color: AppPalette.mutedText),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppPalette.charcoal,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppPalette.mutedText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.place_rounded,
                        color: AppPalette.ochre, size: 22),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildDiscoverBody() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: Stream.value([]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          final message = AppErrorMessages.fromException(
            snapshot.error,
            fallback:
                'Unable to load discover items right now. Please try again.',
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

        return ValueListenableBuilder<int>(
          valueListenable: VisitorAuth.interestedEventsVersion,
          builder: (context, _, __) {
            final items = snapshot.data ?? const <Map<String, dynamic>>[];
            final foodItems = _filterItems(
              items,
              section: _VisitorFilterSection.food,
            );

            final hasAnyVisibleItems = foodItems.isNotEmpty;

            final visitorName =
                VisitorAuth.currentVisitor?.name.split(' ').first ?? 'Visitor';
            final heroProfileImage =
                _profileImageProvider(VisitorAuth.currentVisitor);

            return Stack(
              children: [
                // Dark navy background
                const Positioned.fill(
                  child: ColoredBox(color: Color(0xFF0D1117)),
                ),
                CustomScrollView(
              slivers: [
                // ── Hero section (text over full-screen background) ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(
                      top: MediaQuery.of(context).padding.top + 12,
                      left: 16,
                      right: 16,
                      bottom: 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                            Row(
                              children: [
                                ClipOval(
                                  child: Container(
                                    width: 60,
                                    height: 60,
                                    color: Colors.white.withValues(alpha: 0.1),
                                    child: Image.asset('assets/Brisconnect New.jpg', fit: BoxFit.cover),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Text(
                                  'BrisConnect+',
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
                                  onTap: () => setState(() => _selectedIndex = 4),
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
                                      radius: 52,
                                      backgroundColor: AppPalette.deepBlue,
                                      backgroundImage: heroProfileImage,
                                      child: heroProfileImage == null
                                          ? const Icon(Icons.person_rounded, color: Colors.white, size: 48)
                                          : null,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            Text(
                              '👋 Hi, $visitorName',
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
                              'Discover Local Food',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
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

                          // Active filter chips
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 20),
                            child: _buildActiveFilterChips(),
                          ),

                          // Food items
                          if (!hasAnyVisibleItems)
                            const Padding(
                              padding: EdgeInsets.fromLTRB(20, 8, 20, 0),
                              child: _EmptyState(
                                title: 'No food places found',
                                subtitle:
                                    'Try changing your search or filter selections.',
                              ),
                            ),
                          if (foodItems.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  const _SectionHeader(
                                    title: 'Local Food Businesses',
                                    subtitle:
                                        'Support small & medium Brisbane food enterprises',
                                  ),
                                  ...foodItems.map(_buildEventCard),
                                ],
                              ),
                            ),
                          ],
                          // Businesses section
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _SectionHeader(
                                  title: 'Local Food Businesses',
                                  subtitle: 'Support & review small Brisbane food enterprises',
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const BusinessSearchScreen(),
                                      ),
                                    ),
                                    icon: const Icon(Icons.storefront_rounded),
                                    label: const Text('Explore & Review Food Businesses'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppPalette.ochre,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
              ], // Stack children
            ); // Stack
          },
        );
      },
    );
  }

  Widget _buildSavedBody() {
    return ValueListenableBuilder<int>(
      valueListenable: VisitorAuth.interestedEventsVersion,
      builder: (context, _, __) {
        final savedEventIds = VisitorAuth.getInterestedEventIds();
        final savedAttractionIds = VisitorAuth.getSavedAttractionIds();

        if (savedEventIds.isEmpty && savedAttractionIds.isEmpty) {
          return const Center(
            child: _EmptyState(
              title: 'No saved items yet',
              subtitle:
                  'Tap the heart icon on food business cards to save them here.',
            ),
          );
        }

        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: Stream.value([]),
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
            final savedDiscoverEvents = allItems.where((item) {
              final id = (item['id'] as String? ?? '').trim();
              final section = (item['section'] as String? ?? '').trim();
              return id.isNotEmpty &&
                  section == 'events' &&
                  savedEventIds.contains(id);
            }).toList();

            final savedAttractions = allItems.where((item) {
              final id = (item['id'] as String? ?? '').trim();
              final section = (item['section'] as String? ?? '').trim();
              return id.isNotEmpty &&
                  section != 'events' &&
                  savedAttractionIds.contains(id);
            }).toList();

            return StreamBuilder<List<Map<String, dynamic>>>(
              stream: _approvedEventsStream(),
              builder: (context, approvedSnapshot) {
                if (approvedSnapshot.hasError) {
                  debugPrint(
                    '[VisitorPortal] Approved events fallback unavailable: ${approvedSnapshot.error}',
                  );
                }

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

                final savedEvents = <Map<String, dynamic>>[
                  ...savedDiscoverEvents,
                  ...savedFirestoreEvents,
                ];

                if (savedEvents.isEmpty && savedAttractions.isEmpty) {
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
                    if (savedEvents.isNotEmpty) ...[
                      const _SectionHeader(
                        title: 'Saved Events',
                        subtitle: 'Your event reminders and plans',
                      ),
                      ...savedEvents.map(
                        (item) => KeyedSubtree(
                          key: Key(
                            'saved-event-card-${(item['id'] as String? ?? '').trim()}',
                          ),
                          child: _buildEventCard(item),
                        ),
                      ),
                    ],
                    if (savedAttractions.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      const _SectionHeader(
                        title: 'Saved Attractions',
                        subtitle: 'Places to visit independently of events',
                      ),
                      ...savedAttractions.map(
                        (item) => KeyedSubtree(
                          key: Key(
                            'saved-attraction-card-${(item['id'] as String? ?? '').trim()}',
                          ),
                          child: _buildEventCard(item),
                        ),
                      ),
                    ],
                  ],
                );
              },
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

  ImageProvider<Object>? _profileImageProvider(VisitorUser? visitor) {
    if (_pendingProfileImageBytes != null) {
      return MemoryImage(_pendingProfileImageBytes!);
    }

    final imageUrl = visitor?.profileImageUrl?.trim() ?? '';
    if (imageUrl.isNotEmpty) {
      return NetworkImage(imageUrl);
    }

    final raw = visitor?.profileImageBase64?.trim() ?? '';
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
        role: 'visitor',
        email: visitor.email,
        bytes: bytes,
        fileName: fileName,
        previousStoragePath: visitor.profileImageStoragePath,
      );
      if (!mounted) return;
      ok = await VisitorAuth.updateProfileImage(
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
      debugPrint('[VisitorPortal] Profile image upload failed: $error');
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

  Future<void> _showEditProfileSheet(
    String currentName,
    String currentEmail,
    String currentPhone,
  ) async {
    final formKey = GlobalKey<FormState>();
    bool saving = false;
    String editedName = currentName;
    String editedPhone = currentPhone;

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
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: currentPhone,
                      keyboardType: TextInputType.phone,
                      onChanged: (value) => editedPhone = value,
                      decoration: InputDecoration(
                        labelText: 'Phone number',
                        hintText: 'e.g. 04xxxxxxxx',
                        prefixIcon: const Icon(Icons.phone_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) {
                        final trimmed = (value ?? '').trim();
                        if (trimmed.isEmpty) {
                          return null;
                        }
                        final normalized =
                            trimmed.replaceAll(RegExp(r'[^0-9+]'), '');
                        if (normalized.length < 8 || normalized.length > 16) {
                          return 'Enter a valid phone number.';
                        }
                        return null;
                      },
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
                              final ok = await VisitorAuth.updateProfileInfo(
                                newName: editedName,
                                newPhone: editedPhone,
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
        final displayName = visitor?.name ?? 'Visitor User';
        final displayEmail = visitor?.email ?? '';
        final displayPhone = visitor?.phone.trim() ?? '';
        final profileImage = _profileImageProvider(visitor);

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 36),
          children: [
            _buildSectionLabel('Profile Info'),
            Card(
              color: AppPalette.surface.withValues(alpha: 0.88),
              elevation: 4,
              shadowColor: AppPalette.cardShadow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: AppPalette.border.withValues(alpha: 0.5)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
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
                          if (displayPhone.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              displayPhone,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppPalette.mutedText,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: (visitor?.profileImageUrl?.isNotEmpty == true ||
                              visitor?.profileImageBase64?.isNotEmpty == true)
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
                      onPressed: () => _showEditProfileSheet(
                        displayName,
                        displayEmail,
                        displayPhone,
                      ),
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
            _buildSectionLabel('Preferences'),
            Card(
              color: AppPalette.surface.withValues(alpha: 0.88),
              elevation: 4,
              shadowColor: AppPalette.cardShadow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: AppPalette.border.withValues(alpha: 0.5)),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.pin_drop_outlined,
                      color: AppPalette.deepBlue,
                    ),
                    title: const Text(
                      'Location Radius',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text('Set how far recommendations can be'),
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
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  ListTile(
                    leading: const Icon(
                      Icons.palette_outlined,
                      color: AppPalette.deepBlue,
                    ),
                    title: const Text(
                      'Appearance Settings',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text('Theme, text size & feedback'),
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                      color: AppPalette.mutedText,
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const AppearanceSettingsScreen.visitor(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildSectionLabel('Feedback'),
            Card(
              color: AppPalette.surface.withValues(alpha: 0.88),
              elevation: 4,
              shadowColor: AppPalette.cardShadow,
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
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MyFeedbackScreen(
                      reporterEmail: displayEmail,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
_buildSectionLabel('Help & Support'),
            Card(
              color: AppPalette.surface.withValues(alpha: 0.88),
              elevation: 4,
              shadowColor: AppPalette.cardShadow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: AppPalette.border.withValues(alpha: 0.5)),
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
                title: const Text(
                  'Help & Support',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('FAQs, contact us & app info'),
                trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                onTap: () => _showHelpSupport(context),
              ),
            ),
            const SizedBox(height: 24),
            _buildSectionLabel('Sign Out'),
            Card(
              color: AppPalette.surface.withValues(alpha: 0.88),
              elevation: 4,
              shadowColor: AppPalette.cardShadow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: AppPalette.border.withValues(alpha: 0.5)),
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

  String _appBarTitleForIndex(int index) {
    switch (index) {
      case 1:
        return 'Community';
      case 2:
        return 'Map';
      case 3:
        return 'Saved';
      case 4:
        return 'Profile';
      default:
        return '';
    }
  }

  Widget _kangarooBackground(String assetPath, Widget child) {
    return Stack(
      children: [
        const Positioned.fill(
          child: ColoredBox(color: Color(0xFF0D1117)),
        ),
        Positioned.fill(child: SafeArea(child: child)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDiscover = _selectedIndex == 0;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      extendBodyBehindAppBar: true,
      extendBody: true,
      appBar: isDiscover
          ? null
          : AppBar(
              automaticallyImplyLeading: false,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _selectedIndex = 0),
              ),
              title: LogoAppBarTitle(_appBarTitleForIndex(_selectedIndex)),
              backgroundColor: const Color(0xFF1C1C2E),
              foregroundColor: Colors.white,
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
        child: IndexedStack(
          index: _selectedIndex,
          children: [
            _buildDiscoverBody(),
            const SafeArea(child: VisitorActivityFeedScreen()),
            SafeArea(child: MapEventsScreen(
              embedded: true,
              onBackPressed: () => setState(() => _selectedIndex = 0),
            )),
            _kangarooBackground(
              'assets/Kangaroo2.png',
              _buildSavedBody(),
            ),
            _kangarooBackground(
              'assets/Kangaroo4.png',
              _buildProfileBody(),
            ),
            SafeArea(child: const FoodBusinessDiscoveryScreen()),
          ],
        ),
      ),
      bottomNavigationBar: AnimatedSlide(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        offset: _isNavVisible ? Offset.zero : const Offset(0, 1),
        child: Theme(
        data: Theme.of(context).copyWith(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        selectedItemColor: AppPalette.ochre,
        unselectedItemColor: AppPalette.mutedText,
        backgroundColor: const Color(0xFF1C1C2E),
        type: BottomNavigationBarType.fixed,
        elevation: 12,
        selectedFontSize: 13,
        unselectedFontSize: 12,
        iconSize: 26,
        items: [
          BottomNavigationBarItem(
            icon: const Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Icon(Icons.home_outlined),
            ),
            activeIcon: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.home_rounded),
            ),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: const Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Icon(Icons.people_outline_rounded),
            ),
            activeIcon: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.people_rounded),
            ),
            label: 'Community',
          ),
          BottomNavigationBarItem(
            icon: const Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Icon(Icons.map_outlined),
            ),
            activeIcon: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.map_rounded),
            ),
            label: 'Map',
          ),
          BottomNavigationBarItem(
            icon: const Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Icon(Icons.favorite_border_rounded),
            ),
            activeIcon: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.favorite_rounded),
            ),
            label: 'Saved',
          ),
          BottomNavigationBarItem(
            icon: const Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Icon(Icons.person_outline_rounded),
            ),
            activeIcon: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.person_rounded),
            ),
            label: 'Profile',
          ),
          BottomNavigationBarItem(
            icon: const Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Icon(Icons.restaurant_outlined),
            ),
            activeIcon: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.restaurant_rounded),
            ),
            label: 'Food',
          ),
        ],
      ),
      ),
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
        color: AppPalette.surface.withValues(alpha: 0.80),
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

class _CategoryChip extends StatelessWidget {
  final String label;
  final String emoji;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.emoji,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppPalette.ochre : Colors.white.withValues(alpha: 0.80),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected
                ? AppPalette.ochre
                : AppPalette.border,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppPalette.ochre.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AppPalette.charcoal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}




