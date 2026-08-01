// ignore_for_file: unused_element, unused_field, unused_local_variable

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';

import 'package:brisconnect/screens/food_detail_screen.dart';
import 'package:brisconnect/screens/visitor_event_detail_screen.dart';
import 'package:brisconnect/widgets/report_event_dialog.dart';
import 'package:brisconnect/widgets/food_review_dialog.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/widgets/fallback_image.dart';
import 'package:brisconnect/auth/visitor_auth.dart';

import 'package:brisconnect/services/app_display_settings_controller.dart';
import 'package:brisconnect/services/firestore_service.dart';
import 'package:brisconnect/services/location_utilities.dart';
import 'package:brisconnect/services/olympic_event_email_service.dart';
import 'package:brisconnect/services/visitor_notification_service.dart';
import 'package:brisconnect/screens/welcome_screen_new.dart';
import 'package:brisconnect/services/firebase_media_service.dart';
import 'package:brisconnect/services/review_service.dart';
import 'package:brisconnect/utils/error_messages.dart';
import 'package:brisconnect/utils/profile_image_utils.dart';
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
import '../widgets/desktop_top_app_bar.dart';
import '../utils/responsive_utils.dart';

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
  DateTime? _selectedEventDate;
  FirestoreService? _firestoreService;

  String _formatLanguageLabel(AppLocalizations l10n, String code) {
    switch (code) {
      case 'en':
        return l10n.languageEnglish;
      case 'es':
        return l10n.languageSpanish;
      case 'fr':
        return l10n.languageFrench;
      case 'de':
        return l10n.languageGerman;
      case 'zh':
        return l10n.languageChinese;
      case 'ar':
        return l10n.languageArabic;
      case 'hi':
        return l10n.languageHindi;
      case 'it':
        return l10n.languageItalian;
      case 'ja':
        return l10n.languageJapanese;
      case 'ko':
        return l10n.languageKorean;
      case 'pt':
        return l10n.languagePortuguese;
      case 'ru':
        return l10n.languageRussian;
      case 'vi':
        return l10n.languageVietnamese;
      case 'el':
        return l10n.languageGreek;
      case 'pa':
        return l10n.languagePunjabi;
      default:
        return l10n.languageEnglish;
    }
  }

  Stream<List<Map<String, dynamic>>>? _discoverRadiusStreamCache;
  Stream<List<Map<String, dynamic>>>? _approvedEventsStreamCache;
  late double _userLatitude;
  late double _userLongitude;
  late int _radiusKm;
  late bool _isUsingRadius;
  final ValueNotifier<bool> _navVisibleNotifier = ValueNotifier<bool>(true);
  DateTime? _lastNavToggle;

  final Set<_VisitorFilterSection> _selectedSections = {
    _VisitorFilterSection.food,
  };
  final Set<_VisitorPriceFilter> _selectedPriceFilters = {
    _VisitorPriceFilter.free,
    _VisitorPriceFilter.paid,
  };

  // Caches for expensive list computations so they don't re-run on every
  // frame caused by animations, scrolling, or nested ValueListenableBuilders.
  List<Map<String, dynamic>>? _cachedFoodItems;
  List<Map<String, dynamic>>? _cachedFoodSource;
  String? _cachedFoodFilterKey;
  List<Map<String, dynamic>>? _cachedRecommendedItems;
  List<Map<String, dynamic>>? _cachedRecommendedSource;
  List<Map<String, dynamic>>? _cachedTopRatedFoodItems;
  List<Map<String, dynamic>>? _cachedTopRatedFoodSource;
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
    _navVisibleNotifier.dispose();
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
      final singleCategory = (item['category'] as String? ?? '').toLowerCase();
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

  String _foodFilterCacheKey() {
    return '${_searchController.text.trim()}_'
        '${_selectedSections.toString()}_'
        '${_selectedPriceFilters.toString()}_'
        '${_selectedEventDate?.millisecondsSinceEpoch ?? 0}';
  }

  List<Map<String, dynamic>> _getCachedFoodItems(
    List<Map<String, dynamic>> items,
  ) {
    final key = _foodFilterCacheKey();
    if (!identical(_cachedFoodSource, items) || _cachedFoodFilterKey != key) {
      _cachedFoodSource = items;
      _cachedFoodFilterKey = key;
      _cachedFoodItems = _filterItems(
        items,
        section: _VisitorFilterSection.food,
      );
    }
    return _cachedFoodItems ?? items;
  }

  List<Map<String, dynamic>> _getCachedRecommendedItems(
    List<Map<String, dynamic>> items,
  ) {
    if (!identical(_cachedRecommendedSource, items)) {
      _cachedRecommendedSource = items;
      _cachedRecommendedItems = _recommendedItems(items);
    }
    return _cachedRecommendedItems ?? items;
  }

  List<Map<String, dynamic>> _topRatedFoodItems(
    List<Map<String, dynamic>> items,
  ) {
    final foodItems = items.where((item) {
      final section = (item['section'] as String? ?? '').trim().toLowerCase();
      return section == 'food';
    }).toList(growable: false);

    final scored = foodItems
        .map((item) {
          final rating = (item['rating'] as num?)?.toDouble() ?? 0.0;
          final reviewCount = (item['reviewCount'] as num?)?.toInt() ?? 0;
          final score = (rating * 10) + (reviewCount.clamp(0, 100) / 10);
          return (
            item: item,
            score: score,
            rating: rating,
            reviewCount: reviewCount
          );
        })
        .where((entry) => entry.rating >= 3.5)
        .toList(growable: false);

    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return b.rating.compareTo(a.rating);
    });
    return scored.take(8).map((entry) => entry.item).toList(growable: false);
  }

  List<Map<String, dynamic>> _getCachedTopRatedFoodItems(
    List<Map<String, dynamic>> items,
  ) {
    if (!identical(_cachedTopRatedFoodSource, items)) {
      _cachedTopRatedFoodSource = items;
      _cachedTopRatedFoodItems = _topRatedFoodItems(items);
    }
    return _cachedTopRatedFoodItems ?? const <Map<String, dynamic>>[];
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

  String _formatFilterDate(String locale, DateTime date) {
    return DateFormat.yMMMd(locale).format(date);
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

  String _priceLabel(AppLocalizations l10n, _VisitorPriceFilter filter) {
    switch (filter) {
      case _VisitorPriceFilter.free:
        return l10n.freeLabel;
      case _VisitorPriceFilter.paid:
        return l10n.paidLabel;
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
        final l10n = AppLocalizations.of(context)!;
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
                title: Text(_priceLabel(l10n, filter)),
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
                            Text(
                              AppLocalizations.of(context)!.filterEventsTitle,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: AppPalette.charcoal,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              AppLocalizations.of(context)!.priceLabel,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppPalette.charcoal,
                              ),
                            ),
                            buildPriceTile(_VisitorPriceFilter.free),
                            buildPriceTile(_VisitorPriceFilter.paid),
                            const SizedBox(height: 12),
                            Text(
                              AppLocalizations.of(context)!.dateLabel,
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
                                label: Text(
                                    AppLocalizations.of(context)!.pickADate),
                              )
                            else
                              InputChip(
                                label: Text(_formatFilterDate(
                                    Localizations.localeOf(context).toString(),
                                    selectedDate!)),
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
                                child: Text(
                                    AppLocalizations.of(context)!.resetButton),
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
                                child: Text(
                                    AppLocalizations.of(context)!.applyButton),
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
          label: Text(_priceLabel(AppLocalizations.of(context)!, filter)),
          backgroundColor: AppPalette.surfaceAlt,
          side: const BorderSide(color: AppPalette.border),
        ),
      ),
      if (_selectedEventDate != null)
        Chip(
          label: Text(_formatFilterDate(
              Localizations.localeOf(context).toString(), _selectedEventDate!)),
          backgroundColor: AppPalette.surfaceAlt,
          side: const BorderSide(color: AppPalette.border),
        ),
      ActionChip(
        label: Text(AppLocalizations.of(context)!.clearFilters),
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
    final l10n = AppLocalizations.of(context)!;
    final section =
        (itemData?['section'] as String? ?? '').trim().toLowerCase();
    final isEvent = section == 'events';

    final didUpdate = isEvent
        ? VisitorAuth.toggleInterestedEvent(id)
        : VisitorAuth.toggleSavedAttraction(id);
    if (!didUpdate) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.pleaseSignInToSaveEvents),
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
        SnackBar(content: Text(l10n.eventSavedToInterested(eventTitle))),
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
        SnackBar(content: Text(l10n.eventRemovedFromInterested(eventTitle))),
      );
    } else {
      final title = itemData?['title'] as String? ?? 'Attraction';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isNowSaved
                ? l10n.savedToAttractions(title)
                : l10n.removedFromAttractions(title),
          ),
        ),
      );
    }

    setState(() {});
  }

  void _showFoodReviewDialog(Map<String, dynamic> item) {
    // Guests must sign in before writing a review or submitting a BuzzVote.
    if (!VisitorAuth.isVisitorLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.pleaseSignInToReview),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final l10n = AppLocalizations.of(context)!;
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
    ).then((result) async {
      if (result != null && mounted) {
        final review = result['review'] as String? ?? '';
        final rating = result['rating'] as double? ?? 0;
        final buzzRating = result['buzzRating'] as double? ?? 0;

        final visitor = VisitorAuth.currentVisitor;
        final visitorName = visitor?.name ?? 'Anonymous';

        try {
          await ReviewService().createReview(
            businessId: foodId,
            visitorName: visitorName,
            rating: rating.toInt(),
            buzzRating: buzzRating.toInt(),
            comment: review,
          );

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  l10n.reviewSubmitted(
                    rating.toInt().toString(),
                    buzzRating.toInt().toString(),
                  ),
                ),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.reviewSubmitFailed(e.toString())),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      }
    });
  }

  Future<void> _openWebLink(String link) async {
    final l10n = AppLocalizations.of(context)!;
    if (link.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.noExternalLink)),
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
          SnackBar(content: Text(l10n.unableToOpenLink)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.unableToOpenLink)),
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
          webLink: (item['website'] as String? ?? '').trim(),
          phone: (item['phone'] as String? ?? '').trim(),
          email: (item['email'] as String? ?? '').trim(),
          openingHours: (item['openingHours'] as String? ?? '').trim(),
          facebookUrl: (item['facebookUrl'] as String? ?? '').trim(),
          instagramUrl: (item['instagramUrl'] as String? ?? '').trim(),
          onlineOrderUrl: (item['onlineOrderUrl'] as String? ?? '').trim(),
          aiAudio: (item['aiAudio'] as String? ?? '').trim(),
          menu: _parseMenu(item['menu']),
          photoGallery:
              _parsePhotoGallery(item['photoGallery'], item['imageUrl']),
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
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: AppLocalizations.of(context)!.searchHintLocalFood,
                hintStyle: const TextStyle(color: AppPalette.mutedText),
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
                border:
                    Border.all(color: AppPalette.border.withValues(alpha: 0.5)),
              ),
              child: const Icon(Icons.mic_rounded,
                  size: 18, color: AppPalette.mutedText),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(Map<String, dynamic> item) {
    final l10n = AppLocalizations.of(context)!;
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
          phone: item['phone'] as String?,
          website: item['website'] as String?,
          email: item['email'] as String?,
          facebookUrl: item['facebookUrl'] as String?,
          instagramUrl: item['instagramUrl'] as String?,
          onlineOrderUrl: item['onlineOrderUrl'] as String?,
          categories: (item['categories'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList(),
          cuisine: item['cuisine'] as String?,
          rating: (item['rating'] as num?)?.toDouble(),
          isFavorite: isFavorite,
          cardColor: AppPalette.surface.withValues(alpha: 0.80),
          border: isEvent
              ? null
              : Border.all(
                  color: const Color(0xFF93C5FD),
                  width: 1.5,
                ),
          onShareTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(l10n.shareTitle(
                      item['title'] as String? ?? l10n.eventFallback))),
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
            final openedAttraction =
                await _openAttractionDetailsIfAvailable(item);
            if (!openedAttraction && mounted) {
              _showItemDetails(item);
            }
          },
          onWebTap: () async {
            final section = (item['section'] as String? ?? '').trim();
            final link =
                (item['website'] as String? ?? item['webLink'] as String? ?? '')
                    .trim();
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
            final reviewL10n = AppLocalizations.of(context)!;
            if (section == 'food') {
              _showFoodReviewDialog(item);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(reviewL10n.reviewsOnlyForFood),
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
                label: Text(AppLocalizations.of(context)!.reportEvent),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Lazy sliver grid used in the discover page so tall cards don't force
  /// an enormous shrink-wrapped height.
  Widget _buildFoodSliverGrid(List<Map<String, dynamic>> items) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final crossAxisExtent = constraints.crossAxisExtent;
        if (crossAxisExtent >= Breakpoints.desktop) {
          final crossAxisCount = ResponsiveUtils.gridColumnCount(
            context,
            itemMinWidth: 340,
            minColumns: 2,
            maxColumns: 4,
            spacing: 16,
          );
          return SliverPadding(
            padding: EdgeInsets.symmetric(
              horizontal: ResponsiveUtils.isDesktop(context) ? 32 : 20,
            ),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 16,
                mainAxisSpacing: 0,
                childAspectRatio: 0.42,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildEventCard(items[index]),
                childCount: items.length,
              ),
            ),
          );
        }
        if (crossAxisExtent >= Breakpoints.mobile) {
          return SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 0,
                childAspectRatio: 0.40,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildEventCard(items[index]),
                childCount: items.length,
              ),
            ),
          );
        }
        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildEventCard(items[index]),
              childCount: items.length,
            ),
          ),
        );
      },
    );
  }

  /// Converts a saved-events list into a responsive grid on tablet/desktop.
  Widget _buildSavedCardGrid(List<Map<String, dynamic>> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= Breakpoints.mobile) {
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: ResponsiveUtils.gridColumnCount(
                context,
                itemMinWidth: 340,
                minColumns: 2,
                maxColumns: 3,
                spacing: 16,
              ),
              crossAxisSpacing: 16,
              mainAxisSpacing: 0,
              childAspectRatio: 0.44,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) => _buildEventCard(items[index]),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: items.map(_buildEventCard).toList(),
        );
      },
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
              Text(
                AppLocalizations.of(context)!.recommendedForYou,
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
              final isEvent = section == 'events';
              final isFavorite = isEvent
                  ? VisitorAuth.isInterestedInEvent(id)
                  : VisitorAuth.isAttractionSaved(id);

              return GestureDetector(
                onTap: () async {
                  if (section == 'events') {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => VisitorEventDetailScreen(event: item),
                        ));
                    return;
                  }
                  if (section == 'food') {
                    await _openFoodDetails(item);
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
                          FallbackImage(
                            imageUrl: imageUrl,
                            height: 130,
                            width: 170,
                            borderRadius: BorderRadius.circular(16),
                            category: section,
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

  Widget _buildTopRatedFoodCarousel(List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: ResponsiveUtils.isDesktop(context) ? 32 : 20,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppLocalizations.of(context)!.recommendedForYou,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppPalette.charcoal,
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => _RecommendedFoodAllScreen(
                        items: items,
                        onFoodTap: _openFoodDetails,
                      ),
                    ),
                  );
                },
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
          height: 230,
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(
              dragDevices: {
                PointerDeviceKind.touch,
                PointerDeviceKind.mouse,
                PointerDeviceKind.trackpad,
              },
            ),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(
                horizontal: ResponsiveUtils.isDesktop(context) ? 32 : 20,
              ),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (context, index) {
                final item = items[index];
                final id = (item['id'] as String? ?? '').trim();
                final imageUrl = (item['imageUrl'] as String? ?? '').trim();
                final title = (item['title'] as String? ?? 'Food').trim();
                final location = (item['location'] as String? ?? '').trim();
                final rating = (item['rating'] as num?)?.toDouble() ?? 0.0;
                final reviewCount = (item['reviewCount'] as num?)?.toInt() ?? 0;
                final isFavorite = VisitorAuth.isBusinessSaved(id);

                return GestureDetector(
                  onTap: () => _openFoodDetails(item),
                  child: SizedBox(
                    width: 180,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Stack(
                          children: [
                            FallbackImage(
                              imageUrl: imageUrl,
                              height: 140,
                              width: 180,
                              borderRadius: BorderRadius.circular(16),
                              category: 'food',
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: GestureDetector(
                                onTap: () {
                                  VisitorAuth.toggleSavedBusiness(id);
                                  setState(() {});
                                },
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.85),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isFavorite
                                        ? Icons.bookmark_rounded
                                        : Icons.bookmark_border_rounded,
                                    size: 18,
                                    color: isFavorite
                                        ? AppPalette.ochre
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
                        Row(
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              color: AppPalette.gold,
                              size: 14,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '${rating.toStringAsFixed(1)} · $reviewCount reviews',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppPalette.mutedText,
                              ),
                            ),
                          ],
                        ),
                        if (location.isNotEmpty)
                          Text(
                            location,
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
                label: AppLocalizations.of(context)!.food,
                emoji: '🍴',
                isSelected:
                    _selectedSections.contains(_VisitorFilterSection.food),
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
        .where((item) => (item['location'] as String? ?? '').trim().isNotEmpty)
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
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => VisitorEventDetailScreen(event: item),
                      ));
                  return;
                }
                if (section == 'food') {
                  await _openFoodDetails(item);
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
                  border: Border.all(
                      color: AppPalette.border.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    FallbackImage(
                      imageUrl: imageUrl,
                      width: 64,
                      height: 64,
                      borderRadius: BorderRadius.circular(10),
                      category: section,
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

  Stream<List<Map<String, dynamic>>> _discoverFoodStream() {
    return FirebaseFirestore.instance
        .collection('food_businesses')
        .orderBy('rating', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        final cuisineTypes = data['cuisineTypes'];
        final categories = cuisineTypes is List
            ? cuisineTypes.map((v) => '$v').toList()
            : <String>[];
        return <String, dynamic>{
          'id': doc.id,
          'section': 'food',
          'badge': 'FOOD',
          'title': data['name'] ?? data['businessName'] ?? 'Untitled',
          'description': data['description'] ?? '',
          'location': data['address'] ?? '',
          'imageUrl': data['imageUrl'] ??
              data['logoUrl'] ??
              data['coverImageUrl'] ??
              '',
          'categories': categories,
          'category': categories.isNotEmpty ? categories.first : '',
          'rating': data['rating'] ?? data['averageRating'] ?? 0,
          'reviewCount': data['reviewCount'] ?? data['reviewsCount'] ?? 0,
          'price': data['priceRange'] ?? '',
          'phone': data['phone'] ?? '',
          'website': data['website'] ?? '',
          'openingHours': data['openingHours'] ?? '',
          'email': data['email'] ?? '',
          'facebookUrl': data['facebookUrl'] ?? data['facebook'] ?? '',
          'instagramUrl': data['instagramUrl'] ?? data['instagram'] ?? '',
          'onlineOrderUrl':
              data['onlineOrderUrl'] ?? data['onlineOrderLink'] ?? '',
          'menu': data['menu'] ?? const <Map<String, dynamic>>[],
          'photoGallery': data['photoGallery'] ?? const <String>[],
        };
      }).toList();
    });
  }

  List<Map<String, dynamic>> _parseMenu(dynamic raw) {
    if (raw == null) return const <Map<String, dynamic>>[];
    if (raw is List) {
      return raw.whereType<Map<String, dynamic>>().toList(growable: false);
    }
    if (raw is Map<String, dynamic>) {
      return [raw];
    }
    return const <Map<String, dynamic>>[];
  }

  List<String> _parsePhotoGallery(dynamic raw, String fallbackImageUrl) {
    final urls = <String>[];
    if (raw is List) {
      for (final value in raw) {
        final url = value?.toString().trim() ?? '';
        if (url.isNotEmpty) urls.add(url);
      }
    } else if (raw is String && raw.trim().isNotEmpty) {
      urls.add(raw.trim());
    }
    final fallback = fallbackImageUrl.trim();
    if (fallback.isNotEmpty && !urls.contains(fallback)) {
      urls.insert(0, fallback);
    }
    return urls;
  }

  Widget _buildDiscoverBody() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _discoverFoodStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          final message = AppErrorMessages.fromException(
            snapshot.error,
            fallback: AppLocalizations.of(context)!.unableToLoadDiscover,
          );
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: InlineStatusMessage(
                message: message,
                type: InlineStatusType.error,
                actionLabel: AppLocalizations.of(context)!.retryAction,
                onAction: () => setState(() {}),
              ),
            ),
          );
        }

        return ValueListenableBuilder<int>(
          valueListenable: VisitorAuth.interestedEventsVersion,
          builder: (context, _, __) {
            final items = snapshot.data ?? const <Map<String, dynamic>>[];
            final foodItems = _getCachedFoodItems(items);

            final hasAnyVisibleItems = foodItems.isNotEmpty;

            final visitorName =
                VisitorAuth.currentVisitor?.name.split(' ').first ?? 'Visitor';
            final heroProfileImage =
                _profileImageProvider(VisitorAuth.currentVisitor);
            final isDesktop = ResponsiveUtils.isDesktop(context);
            final isMobile = ResponsiveUtils.isMobile(context);

            return Stack(
              children: [
                // Surface colour fills any gaps between slivers.
                const Positioned.fill(
                  child: ColoredBox(color: AppPalette.surface),
                ),
                CustomScrollView(
                  slivers: [
                    // ── Recommended food businesses carousel ──
                    SliverToBoxAdapter(
                      child: Container(
                        color: AppPalette.background,
                        padding: const EdgeInsets.only(top: 16),
                        child: _buildTopRatedFoodCarousel(
                          _getCachedTopRatedFoodItems(items),
                        ),
                      ),
                    ),

                    // ── Hero section (white background over surface) ──
                    SliverToBoxAdapter(
                      child: Container(
                        color: AppPalette.background,
                        padding: EdgeInsets.only(
                          top: MediaQuery.of(context).padding.top + 12,
                          left: 16,
                          right: 16,
                          bottom: 12,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (isMobile) ...[
                              Row(
                                children: [
                                  ClipOval(
                                    child: Container(
                                      width: 60,
                                      height: 60,
                                      color:
                                          Colors.white.withValues(alpha: 0.1),
                                      child: Image.asset(
                                          'assets/Brisconnect New.jpg',
                                          fit: BoxFit.cover),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    AppLocalizations.of(context)!.appTitle,
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: AppPalette.charcoal,
                                    ),
                                  ),
                                  const Spacer(),
                                  GestureDetector(
                                    onTap: () =>
                                        setState(() => _selectedIndex = 4),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: AppPalette.border, width: 2),
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
                              const SizedBox(height: 18),
                            ],
                            Text(
                              '👋 Hi, $visitorName',
                              style: TextStyle(
                                fontSize: isDesktop ? 36 : 28,
                                fontWeight: FontWeight.w800,
                                color: AppPalette.charcoal,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              AppLocalizations.of(context)!.discoverTitle,
                              style: TextStyle(
                                fontSize: isDesktop ? 22 : 18,
                                fontWeight: FontWeight.w600,
                                color: AppPalette.mutedText,
                              ),
                            ),
                            if (isMobile) ...[
                              const SizedBox(height: 18),
                              _buildSearchBar(),
                            ],
                          ],
                        ),
                      ),
                    ),

                    // ── Content sheet ──
                    SliverToBoxAdapter(
                      child: Container(
                        decoration: const BoxDecoration(
                          color: AppPalette.surface,
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
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(20, 8, 20, 0),
                                child: _EmptyState(
                                  title: AppLocalizations.of(context)!
                                      .noFoodPlacesFound,
                                  subtitle: AppLocalizations.of(context)!
                                      .noFoodPlacesSubtitle,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                    // Food section header + grid
                    if (foodItems.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: isDesktop ? 32 : 20,
                          ),
                          child: _SectionHeader(
                            title: AppLocalizations.of(context)!
                                .localFoodBusinesses,
                            subtitle:
                                AppLocalizations.of(context)!.localFoodSubtitle,
                            titleSize: isDesktop ? 24 : 20,
                          ),
                        ),
                      ),
                      _buildFoodSliverGrid(foodItems),
                    ],

                    // Businesses section
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isDesktop ? 32 : 20,
                        ),
                        child: Column(
                          children: [
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const BusinessSearchScreen(),
                                  ),
                                ),
                                icon: const Icon(Icons.storefront_rounded),
                                label: Text(AppLocalizations.of(context)!
                                    .exploreReviewFoodBusinesses),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppPalette.ochre,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
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
      valueListenable: VisitorAuth.savedAttractionsVersion,
      builder: (context, _, __) {
        final savedEventIds = VisitorAuth.getInterestedEventIds();
        final savedAttractionIds = VisitorAuth.getSavedAttractionIds();
        final savedBusinessIds = VisitorAuth.getSavedBusinessIds();

        if (savedEventIds.isEmpty &&
            savedAttractionIds.isEmpty &&
            savedBusinessIds.isEmpty) {
          return Center(
            child: _EmptyState(
              title: AppLocalizations.of(context)!.noSavedItemsTitle,
              subtitle: AppLocalizations.of(context)!.noSavedItemsSubtitle,
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
                    actionLabel: AppLocalizations.of(context)!.retryAction,
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

            return LayoutBuilder(
              builder: (context, constraints) {
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

                    if (savedEvents.isEmpty &&
                        savedAttractions.isEmpty &&
                        savedBusinessIds.isEmpty) {
                      return Center(
                        child: _EmptyState(
                          title: AppLocalizations.of(context)!
                              .savedItemsUnavailableTitle,
                          subtitle: AppLocalizations.of(context)!
                              .savedItemsUnavailableSubtitle,
                        ),
                      );
                    }

                    final horizontalPadding =
                        constraints.maxWidth >= Breakpoints.desktop
                            ? 48.0
                            : constraints.maxWidth >= Breakpoints.mobile
                                ? 32.0
                                : 16.0;
                    final titleSize =
                        constraints.maxWidth >= Breakpoints.desktop
                            ? 24.0
                            : 20.0;

                    return ListView(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        14,
                        horizontalPadding,
                        24,
                      ),
                      children: [
                        if (savedEvents.isNotEmpty) ...[
                          _SectionHeader(
                            title: AppLocalizations.of(context)!.savedEvents,
                            subtitle: AppLocalizations.of(context)!
                                .savedEventsSubtitle,
                            titleSize: titleSize,
                          ),
                          _buildSavedCardGrid(savedEvents),
                        ],
                        if (savedAttractions.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _SectionHeader(
                            title:
                                AppLocalizations.of(context)!.savedAttractions,
                            subtitle: AppLocalizations.of(context)!
                                .savedAttractionsSubtitle,
                            titleSize: titleSize,
                          ),
                          _buildSavedCardGrid(savedAttractions),
                        ],
                        if (savedBusinessIds.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _SectionHeader(
                            title:
                                AppLocalizations.of(context)!.savedBusinesses,
                            subtitle: AppLocalizations.of(context)!
                                .savedBusinessesSubtitle,
                            titleSize:
                                constraints.maxWidth >= Breakpoints.desktop
                                    ? 24
                                    : 20,
                          ),
                          _buildSavedFoodBusinessesGrid(savedBusinessIds),
                        ],
                      ],
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildSavedFoodBusinessesGrid(Set<String> savedBusinessIds) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('food_businesses')
          .where(FieldPath.documentId, whereIn: savedBusinessIds.toList())
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final items = docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final cuisineTypes = data['cuisineTypes'];
          final categories = cuisineTypes is List
              ? cuisineTypes.map((v) => '$v').toList()
              : <String>[];
          return <String, dynamic>{
            'id': doc.id,
            'section': 'food',
            'badge': 'FOOD',
            'title': data['name'] ?? data['businessName'] ?? 'Untitled',
            'description': data['description'] ?? '',
            'location': data['address'] ?? '',
            'imageUrl': data['imageUrl'] ??
                data['logoUrl'] ??
                data['coverImageUrl'] ??
                '',
            'categories': categories,
            'category': categories.isNotEmpty ? categories.first : '',
            'rating': data['rating'] ?? data['averageRating'] ?? 0,
            'reviewCount': data['reviewCount'] ?? data['reviewsCount'] ?? 0,
            'price': data['priceRange'] ?? '',
            'phone': data['phone'] ?? '',
            'website': data['website'] ?? '',
            'openingHours': data['openingHours'] ?? '',
            'email': data['email'] ?? '',
            'facebookUrl': data['facebookUrl'] ?? data['facebook'] ?? '',
            'instagramUrl': data['instagramUrl'] ?? data['instagram'] ?? '',
            'onlineOrderUrl':
                data['onlineOrderUrl'] ?? data['onlineOrderLink'] ?? '',
            'menu': data['menu'] ?? const <Map<String, dynamic>>[],
            'photoGallery': data['photoGallery'] ?? const <String>[],
          };
        }).toList();

        return _buildSavedCardGrid(items);
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

  Future<void> _uploadVisitorProfileImage() async {
    final visitor = VisitorAuth.currentVisitor;
    if (visitor == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(AppLocalizations.of(context)!.pleaseLoginVisitor)),
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
        SnackBar(content: Text(AppLocalizations.of(context)!.onlyJpgPng)),
      );
      return;
    }

    if (bytes.length > ProfileImageUtils.maxImageBytes) {
      setState(() => _pendingProfileImageBytes = null);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.imageTooLarge)),
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
    String currentLanguage,
  ) async {
    final formKey = GlobalKey<FormState>();
    bool saving = false;
    String editedName = currentName;
    String editedPhone = currentPhone;
    String editedLanguage = currentLanguage;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppPalette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final l10n = AppLocalizations.of(sheetContext)!;
        return Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            MediaQuery.of(sheetContext).viewInsets.bottom + 24,
          ),
          child: StatefulBuilder(
            builder: (_, setSheetState) {
              final currentVisitor = VisitorAuth.currentVisitor;
              final sheetProfileImage = _profileImageProvider(currentVisitor);
              return Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.editProfile,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppPalette.charcoal,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Center(
                        child: GestureDetector(
                          onTap: () async {
                            await _uploadVisitorProfileImage();
                            setSheetState(() {});
                          },
                          child: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              CircleAvatar(
                                radius: 44,
                                backgroundColor: AppPalette.deepBlue,
                                backgroundImage: sheetProfileImage,
                                child: sheetProfileImage == null
                                    ? const Icon(
                                        Icons.person_rounded,
                                        color: Colors.white,
                                        size: 44,
                                      )
                                    : null,
                              ),
                              Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: AppPalette.ochre,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Colors.white, width: 2.5),
                                ),
                                child: const Icon(
                                  Icons.camera_alt_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Center(
                        child: Text(
                          'Tap to change profile picture',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppPalette.mutedText,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      TextFormField(
                        initialValue: currentName,
                        autofocus: true,
                        textCapitalization: TextCapitalization.words,
                        onChanged: (value) => editedName = value,
                        decoration: InputDecoration(
                          labelText: l10n.name,
                          hintText: l10n.enterYourName,
                          prefixIcon: const Icon(Icons.person_outline_rounded),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return l10n.nameCannotBeEmpty;
                          }
                          if (value.trim().length < 2) {
                            return l10n.nameMinLength;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        initialValue: currentEmail,
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: l10n.email,
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
                          labelText: l10n.phone,
                          hintText: l10n.phoneHint,
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
                            return l10n.enterValidPhone;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: editedLanguage,
                        decoration: InputDecoration(
                          labelText: l10n.language,
                          prefixIcon: const Icon(Icons.language_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: [
                          DropdownMenuItem(
                              value: 'en',
                              child: Text(_formatLanguageLabel(l10n, 'en'))),
                          DropdownMenuItem(
                              value: 'es',
                              child: Text(_formatLanguageLabel(l10n, 'es'))),
                          DropdownMenuItem(
                              value: 'fr',
                              child: Text(_formatLanguageLabel(l10n, 'fr'))),
                          DropdownMenuItem(
                              value: 'de',
                              child: Text(_formatLanguageLabel(l10n, 'de'))),
                          DropdownMenuItem(
                              value: 'zh',
                              child: Text(_formatLanguageLabel(l10n, 'zh'))),
                          DropdownMenuItem(
                              value: 'ar',
                              child: Text(_formatLanguageLabel(l10n, 'ar'))),
                          DropdownMenuItem(
                              value: 'hi',
                              child: Text(_formatLanguageLabel(l10n, 'hi'))),
                          DropdownMenuItem(
                              value: 'it',
                              child: Text(_formatLanguageLabel(l10n, 'it'))),
                          DropdownMenuItem(
                              value: 'ja',
                              child: Text(_formatLanguageLabel(l10n, 'ja'))),
                          DropdownMenuItem(
                              value: 'ko',
                              child: Text(_formatLanguageLabel(l10n, 'ko'))),
                          DropdownMenuItem(
                              value: 'pt',
                              child: Text(_formatLanguageLabel(l10n, 'pt'))),
                          DropdownMenuItem(
                              value: 'ru',
                              child: Text(_formatLanguageLabel(l10n, 'ru'))),
                          DropdownMenuItem(
                              value: 'vi',
                              child: Text(_formatLanguageLabel(l10n, 'vi'))),
                          DropdownMenuItem(
                              value: 'el',
                              child: Text(_formatLanguageLabel(l10n, 'el'))),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setSheetState(() => editedLanguage = value);
                          }
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
                                  newLanguage: editedLanguage,
                                );
                                if (ok) {
                                  AppDisplaySettingsController.setAppLocale(
                                      editedLanguage);
                                }
                                if (!sheetContext.mounted) return;
                                Navigator.pop(sheetContext);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        ok
                                            ? l10n.profileUpdated
                                            : l10n.profileUpdateFailed,
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
                            : Text(l10n.save),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        child: Text(l10n.cancel),
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
      builder: (dialogContext) {
        final l10n = AppLocalizations.of(dialogContext)!;
        return AlertDialog(
          title: Text(l10n.signOut),
          content: Text(l10n.areYouSureSignOut),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(l10n.signOut),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    await VisitorAuth.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AnimatedWelcomeScreen()),
      (route) => false,
    );
  }

  Widget _buildProfileBody() {
    return ValueListenableBuilder<int>(
      valueListenable: VisitorAuth.profileVersion,
      builder: (context, _, __) {
        final visitor = VisitorAuth.currentVisitor;
        final displayName = visitor?.name ?? 'Guest Visitor';
        final displayEmail = visitor?.email ?? '';
        final displayPhone = visitor?.phone.trim() ?? '';
        final displayLanguage = visitor?.language ?? 'en';
        final profileImage = _profileImageProvider(visitor);

        final width = ResponsiveUtils.widthOf(context);
        final isProfileDesktop = width >= Breakpoints.desktop;
        final isProfileTablet =
            width >= Breakpoints.mobile && width < Breakpoints.tablet;
        final horizontalPadding = isProfileDesktop
            ? 48.0
            : isProfileTablet
                ? 32.0
                : 16.0;

        final l10n = AppLocalizations.of(context)!;

        return ListView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            isProfileDesktop ? 32 : 20,
            horizontalPadding,
            36,
          ),
          children: [
            _buildSectionLabel(l10n.profileInfo),
            Card(
              color: AppPalette.surface.withValues(alpha: 0.88),
              elevation: 4,
              shadowColor: AppPalette.cardShadow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side:
                    BorderSide(color: AppPalette.border.withValues(alpha: 0.5)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap:
                          visitor != null ? _uploadVisitorProfileImage : null,
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 42,
                            backgroundColor: AppPalette.deepBlue,
                            backgroundImage: profileImage,
                            child: profileImage == null
                                ? const Icon(
                                    Icons.person_rounded,
                                    color: Colors.white,
                                    size: 42,
                                  )
                                : null,
                          ),
                          if (visitor != null)
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppPalette.ochre,
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 2.5),
                              ),
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  displayName,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: AppPalette.charcoal,
                                  ),
                                ),
                              ),
                              if (visitor == null)
                                IconButton(
                                  tooltip: l10n.signOut,
                                  onPressed: _confirmLogout,
                                  icon: Icon(
                                    Icons.logout_rounded,
                                    color: Colors.red.shade700,
                                    size: 20,
                                  ),
                                )
                              else
                                IconButton(
                                  tooltip: l10n.editProfile,
                                  onPressed: () => _showEditProfileSheet(
                                    displayName,
                                    displayEmail,
                                    displayPhone,
                                    displayLanguage,
                                  ),
                                  icon: const Icon(
                                    Icons.edit_rounded,
                                    color: AppPalette.deepBlue,
                                    size: 20,
                                  ),
                                ),
                            ],
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
                          const SizedBox(height: 2),
                          Text(
                            _formatLanguageLabel(l10n, displayLanguage),
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppPalette.mutedText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildSectionLabel(l10n.preferences),
            Card(
              color: AppPalette.surface.withValues(alpha: 0.88),
              elevation: 4,
              shadowColor: AppPalette.cardShadow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side:
                    BorderSide(color: AppPalette.border.withValues(alpha: 0.5)),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.language_outlined,
                      color: AppPalette.deepBlue,
                    ),
                    title: Text(
                      l10n.language,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(_formatLanguageLabel(l10n, displayLanguage)),
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                      color: AppPalette.mutedText,
                    ),
                    onTap: () => _showEditProfileSheet(
                      displayName,
                      displayEmail,
                      displayPhone,
                      displayLanguage,
                    ),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  ListTile(
                    leading: const Icon(
                      Icons.pin_drop_outlined,
                      color: AppPalette.deepBlue,
                    ),
                    title: Text(
                      l10n.locationRadius,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(l10n.setHowFarRecommendations),
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
                    title: Text(
                      l10n.appearanceSettings,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(l10n.themeTextSizeFeedback),
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
            _buildSectionLabel(l10n.feedback),
            Card(
              color: AppPalette.surface.withValues(alpha: 0.88),
              elevation: 4,
              shadowColor: AppPalette.cardShadow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side:
                    BorderSide(color: AppPalette.border.withValues(alpha: 0.5)),
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
            _buildSectionLabel(l10n.helpAndSupport),
            Card(
              color: AppPalette.surface.withValues(alpha: 0.88),
              elevation: 4,
              shadowColor: AppPalette.cardShadow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side:
                    BorderSide(color: AppPalette.border.withValues(alpha: 0.5)),
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
            if (visitor != null) ...[
              const SizedBox(height: 24),
              _buildSectionLabel(l10n.signOut),
              Card(
                color: AppPalette.surface.withValues(alpha: 0.88),
                elevation: 4,
                shadowColor: AppPalette.cardShadow,
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
            ],
          ],
        );
      },
    );
  }

  String _appBarTitleForIndex(BuildContext context, int index) {
    final l10n = AppLocalizations.of(context)!;
    switch (index) {
      case 1:
        return l10n.community;
      case 2:
        return l10n.map;
      case 3:
        return l10n.saved;
      case 4:
        return l10n.profile;
      default:
        return '';
    }
  }

  Widget _kangarooBackground(String assetPath, Widget child) {
    return Stack(
      children: [
        const Positioned.fill(
          child: ColoredBox(color: AppPalette.background),
        ),
        Positioned.fill(
          child: SafeArea(
            // Add bottom padding equal to the bottom nav height so the last
            // list items are not hidden behind the navigation bar.
            bottom: false,
            child: child,
          ),
        ),
      ],
    );
  }

  Widget _buildWebCityBanner() {
    if (!kIsWeb) return const SizedBox.shrink();
    return SizedBox(
      width: double.infinity,
      height: 140,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/Brisbane banner.webp',
            fit: BoxFit.cover,
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.25),
                  Colors.black.withValues(alpha: 0.55),
                ],
              ),
            ),
          ),
          Positioned(
            left: 16,
            bottom: 16,
            child: Row(
              children: [
                const Icon(
                  Icons.location_city_rounded,
                  color: AppPalette.ochre,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text(
                  'Brisbane City',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.95),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    shadows: const [
                      Shadow(
                        color: Colors.black54,
                        offset: Offset(0, 1),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDiscover = _selectedIndex == 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= Breakpoints.desktop;
        final isTablet = constraints.maxWidth >= Breakpoints.mobile &&
            constraints.maxWidth < Breakpoints.desktop;
        return Scaffold(
          backgroundColor: AppPalette.background,
          extendBodyBehindAppBar: false,
          extendBody: false,
          appBar: isDiscover && (isDesktop || isTablet)
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(76),
                  child: DesktopTopAppBar(
                    title: AppLocalizations.of(context)!.appTitle,
                    subtitle: AppLocalizations.of(context)!.discoverSubtitle,
                    searchController: _searchController,
                    searchHint:
                        AppLocalizations.of(context)!.searchHintLocalFood,
                    onSearchChanged: (_) {
                      _searchDebounce?.cancel();
                      _searchDebounce = Timer(
                        const Duration(milliseconds: 300),
                        () {
                          if (mounted) setState(() {});
                        },
                      );
                    },
                    onFilterTap: _openFilterSheet,
                    onProfileTap: () => setState(() => _selectedIndex = 4),
                    profileImage: _profileImageProvider(
                      VisitorAuth.currentVisitor,
                    ),
                    userName: VisitorAuth.currentVisitor?.name ??
                        AppLocalizations.of(context)!.guestVisitor,
                    userEmail: VisitorAuth.currentVisitor?.email,
                  ),
                )
              : isDiscover
                  ? null
                  : AppBar(
                      automaticallyImplyLeading: false,
                      leading: IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => setState(() => _selectedIndex = 0),
                      ),
                      title: LogoAppBarTitle(
                        _appBarTitleForIndex(context, _selectedIndex),
                      ),
                      backgroundColor: AppPalette.background,
                      foregroundColor: AppPalette.charcoal,
                      elevation: 0,
                    ),
          body: Column(
            children: [
              _buildWebCityBanner(),
              Expanded(
                child: isDesktop ? _buildDesktopBody() : _buildMobileBody(),
              ),
            ],
          ),
          bottomNavigationBar: isDesktop ? null : _buildBottomNav(),
        );
      },
    );
  }

  Widget _buildMobileBody() {
    return NotificationListener<ScrollNotification>(
      onNotification: _handleScrollNotification,
      child: IndexedStack(
        index: _selectedIndex,
        children: _tabChildren(),
      ),
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

  Widget _buildDesktopBody() {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        NavigationRail(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) =>
              setState(() => _selectedIndex = index),
          backgroundColor: AppPalette.background,
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
              icon: const Icon(Icons.home_outlined),
              selectedIcon: const Icon(Icons.home_rounded),
              label: Text(l10n.homeLabel),
            ),
            NavigationRailDestination(
              icon: const Icon(Icons.people_outline_rounded),
              selectedIcon: const Icon(Icons.people_rounded),
              label: Text(l10n.community),
            ),
            NavigationRailDestination(
              icon: const Icon(Icons.map_outlined),
              selectedIcon: const Icon(Icons.map_rounded),
              label: Text(l10n.map),
            ),
            NavigationRailDestination(
              icon: const Icon(Icons.favorite_border_rounded),
              selectedIcon: const Icon(Icons.favorite_rounded),
              label: Text(l10n.saved),
            ),
            NavigationRailDestination(
              icon: const Icon(Icons.person_outline_rounded),
              selectedIcon: const Icon(Icons.person_rounded),
              label: Text(l10n.profile),
            ),
          ],
        ),
        Expanded(
          child: _selectedIndex == 2
              ? NotificationListener<ScrollNotification>(
                  onNotification: _handleScrollNotification,
                  child: IndexedStack(
                    index: _selectedIndex,
                    children: _tabChildren(),
                  ),
                )
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1400),
                    child: NotificationListener<ScrollNotification>(
                      onNotification: _handleScrollNotification,
                      child: IndexedStack(
                        index: _selectedIndex,
                        children: _tabChildren(),
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
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

  List<Widget> _tabChildren() {
    const bottomNavHeight = 80.0;
    final width = ResponsiveUtils.widthOf(context);
    final isTabDesktop = width >= Breakpoints.desktop;
    final tabBottomPadding = isTabDesktop
        ? EdgeInsets.zero
        : const EdgeInsets.only(bottom: bottomNavHeight);
    return [
      _buildDiscoverBody(),
      const SafeArea(child: VisitorActivityFeedScreen()),
      // On web, only build the Google Map widget when this tab is active.
      // Keeping the map platform view alive while off-screen (inside
      // IndexedStack) causes the Google Maps JS SDK to throw an
      // IntersectionObserver error and the map renders empty. Native mobile
      // platforms can keep the map alive for better tab-switching UX.
      kIsWeb
          ? _selectedIndex == 2
              ? SafeArea(
                  child: MapEventsScreen(
                    embedded: true,
                    onBackPressed: () => setState(() => _selectedIndex = 0),
                  ),
                )
              : const SizedBox.shrink()
          : SafeArea(
              child: MapEventsScreen(
                embedded: true,
                onBackPressed: () => setState(() => _selectedIndex = 0),
              ),
            ),
      _kangarooBackground(
        'assets/Kangaroo2.png',
        Padding(padding: tabBottomPadding, child: _buildSavedBody()),
      ),
      _kangarooBackground(
        'assets/Kangaroo4.png',
        Padding(padding: tabBottomPadding, child: _buildProfileBody()),
      ),
    ];
  }

  Widget _buildBottomNav() {
    final l10n = AppLocalizations.of(context)!;
    return ValueListenableBuilder<bool>(
      valueListenable: _navVisibleNotifier,
      builder: (context, isVisible, child) => AnimatedSlide(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        offset: isVisible ? Offset.zero : const Offset(0, 1),
        child: child!,
      ),
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
          backgroundColor: AppPalette.background,
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                decoration: BoxDecoration(
                  color: AppPalette.ochre.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.home_rounded),
              ),
              label: l10n.homeLabel,
            ),
            BottomNavigationBarItem(
              icon: const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.people_outline_rounded),
              ),
              activeIcon: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                decoration: BoxDecoration(
                  color: AppPalette.ochre.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.people_rounded),
              ),
              label: l10n.community,
            ),
            BottomNavigationBarItem(
              icon: const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.map_outlined),
              ),
              activeIcon: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                decoration: BoxDecoration(
                  color: AppPalette.ochre.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.map_rounded),
              ),
              label: l10n.map,
            ),
            BottomNavigationBarItem(
              icon: const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.favorite_border_rounded),
              ),
              activeIcon: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                decoration: BoxDecoration(
                  color: AppPalette.ochre.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.favorite_rounded),
              ),
              label: l10n.saved,
            ),
            BottomNavigationBarItem(
              icon: const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.person_outline_rounded),
              ),
              activeIcon: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                decoration: BoxDecoration(
                  color: AppPalette.ochre.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.person_rounded),
              ),
              label: l10n.profile,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final double? titleSize;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    this.titleSize,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: titleSize ?? 20,
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
          color: isSelected
              ? AppPalette.ochre
              : Colors.white.withValues(alpha: 0.80),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? AppPalette.ochre : AppPalette.border,
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

class _RecommendedFoodAllScreen extends StatelessWidget {
  const _RecommendedFoodAllScreen({
    required this.items,
    required this.onFoodTap,
  });

  final List<Map<String, dynamic>> items;
  final void Function(Map<String, dynamic>) onFoodTap;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.background,
      appBar: AppBar(
        backgroundColor: AppPalette.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppPalette.charcoal),
        title: const Text(
          'Recommended For You',
          style: TextStyle(
            color: AppPalette.charcoal,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final imageUrl = (item['imageUrl'] as String? ?? '').trim();
          final title = (item['title'] as String? ?? 'Food').trim();
          final location = (item['location'] as String? ?? '').trim();
          final rating = (item['rating'] as num?)?.toDouble() ?? 0.0;
          final reviewCount = (item['reviewCount'] as num?)?.toInt() ?? 0;

          return Card(
            color: AppPalette.surface,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFF93C5FD), width: 1.5),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => onFoodTap(item),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: FallbackImage(
                        imageUrl: imageUrl,
                        width: 80,
                        height: 80,
                        category: 'food',
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppPalette.charcoal,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                color: AppPalette.gold,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${rating.toStringAsFixed(1)} · $reviewCount reviews',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppPalette.mutedText,
                                ),
                              ),
                            ],
                          ),
                          if (location.isNotEmpty)
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
                    const Icon(Icons.chevron_right_rounded,
                        color: AppPalette.mutedText),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
