// ignore_for_file: unused_element, unused_field, unused_local_variable

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/gestures.dart';
import '../l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';

import 'package:brisconnect/screens/food_detail_screen.dart';
import 'package:brisconnect/screens/visitor_event_detail_screen.dart';
import 'package:brisconnect/widgets/report_event_dialog.dart';
import 'package:brisconnect/widgets/food_review_dialog.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/widgets/fallback_image.dart';
import 'package:brisconnect/auth/visitor_auth.dart';
import 'package:brisconnect/auth/admin_auth.dart';
import 'package:brisconnect/mixins/locale_listener_mixin.dart';

import 'package:brisconnect/services/app_display_settings_controller.dart';
import 'package:brisconnect/services/firestore_service.dart';
import 'package:brisconnect/services/location_utilities.dart';
import 'package:brisconnect/services/olympic_event_email_service.dart';
import 'package:brisconnect/services/visitor_notification_service.dart';
import 'package:brisconnect/screens/welcome_screen_new.dart';
import 'package:brisconnect/services/firebase_media_service.dart';
import 'package:brisconnect/services/review_service.dart';
import 'package:brisconnect/services/share/content_share_service.dart';
import 'package:brisconnect/services/weather_service.dart';
import 'package:brisconnect/utils/error_messages.dart';
import '../widgets/share_bottom_sheet.dart';
import 'package:brisconnect/utils/profile_image_utils.dart';
import 'visitor_settings_screen.dart';
import 'appearance_settings_screen.dart';
import 'my_feedback_screen.dart';
import 'map_events_screen.dart';
import 'visitor_activity_feed_screen.dart';
import '../widgets/inline_status_message.dart';
import '../widgets/reusable_event_card.dart';
import '../widgets/logo_app_bar_title.dart';
import '../widgets/help_support_sheet.dart';
import '../widgets/desktop_top_app_bar.dart';
import '../widgets/visitor_notification_bell.dart';
import '../widgets/discover_business_card.dart';
import '../widgets/discover_search_bar.dart';
import '../widgets/discover_section_header.dart';
import '../utils/responsive_utils.dart';
import '../models/business.dart';
import 'feedback_form_screen.dart';

class VisitorPortalScreen extends StatefulWidget {
  /// Global key used by nested helper widgets to access the portal's state
  /// without passing callbacks through many layers.
  static final GlobalKey globalKey = GlobalKey();

  const VisitorPortalScreen({
    super.key,
  });

  @override
  State<VisitorPortalScreen> createState() => _VisitorPortalScreenState();
}

class _VisitorPortalHelper {
  static ({bool isOpen, String label})? getOpenStatus(
      Map<String, dynamic> item) {
    return _VisitorPortalScreenState._staticOpenStatus(item);
  }

  static Future<void> openFoodDetails(
      BuildContext context, Map<String, dynamic> item) async {
    return _VisitorPortalScreenState._staticOpenFoodDetails(context, item);
  }
}

class _VisitorPortalScreenState extends State<VisitorPortalScreen>
    with LocaleListenerMixin<VisitorPortalScreen>, SingleTickerProviderStateMixin {
  String _greetingForHour(int hour) {
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _weatherTagline() {
    if (_weatherLoading) return 'Checking the weather in Brisbane…';
    if (_weatherError != null || _weather == null) {
      return 'Discover local food and experiences in Brisbane';
    }
    final temp = _weather!.temperature.round();
    final condition = _weather!.description.toLowerCase();
    String suggestion;
    if (temp >= 28) {
      suggestion = 'stay cool with refreshing local bites';
    } else if (temp >= 20) {
      suggestion = 'perfect weather to explore local flavours';
    } else if (temp >= 10) {
      suggestion = 'a great day to warm up with local favourites';
    } else {
      suggestion = 'ideal weather to discover local comfort food';
    }
    return "It's $temp°C and $condition in Brisbane — $suggestion.";
  }

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

  Stream<List<Map<String, dynamic>>>? _approvedEventsStreamCache;
  late double _userLatitude;
  late double _userLongitude;
  final ValueNotifier<bool> _navVisibleNotifier = ValueNotifier<bool>(true);
  DateTime? _lastNavToggle;

  final Set<_VisitorFilterSection> _selectedSections = {
    _VisitorFilterSection.food,
  };
  final Set<_VisitorPriceFilter> _selectedPriceFilters = {
    _VisitorPriceFilter.free,
    _VisitorPriceFilter.paid,
  };
  _QuickCategory? _selectedQuickCategory;

  final WeatherService _weatherService = WeatherService();
  BrisbaneWeather? _weather;
  bool _weatherLoading = false;
  String? _weatherError;

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
  @override
  void initState() {
    super.initState();
    setupLocaleListener();
    // Stream caches are lazily initialized in _discoverItemsStream().
    _updateUserPreferences();
    _loadWeather();

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
    // Use default Brisbane location
    final (defaultLat, defaultLon) = LocationUtilities.getDefaultLocation();
    _userLatitude = defaultLat;
    _userLongitude = defaultLon;
  }

  Future<void> _loadWeather() async {
    if (!mounted) return;
    setState(() => _weatherLoading = true);
    try {
      final weather = await _weatherService.fetchBrisbaneWeather();
      if (mounted) {
        setState(() {
          _weather = weather;
          _weatherError = null;
          _weatherLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _weatherError = error.toString();
          _weatherLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _navVisibleNotifier.dispose();
    _searchController.dispose();
    _weatherService.dispose();
    super.dispose();
  }

  // Static helpers used by private child widgets that need access to
  // instance methods without passing callbacks through many layers.
  static ({bool isOpen, String label})? _staticOpenStatus(
      Map<String, dynamic> item) {
    return _staticState?._getOpenStatus(item);
  }

  static Future<void> _staticOpenFoodDetails(
      BuildContext context, Map<String, dynamic> item) async {
    return _staticState?._openFoodDetails(item);
  }

  static _VisitorPortalScreenState? get _staticState => _staticKey.currentState;
  static final GlobalKey<_VisitorPortalScreenState> _staticKey =
      VisitorPortalScreen.globalKey as GlobalKey<_VisitorPortalScreenState>;

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
      var matchesQuickCategory = true;
      if (_selectedQuickCategory != null) {
        final lower = _selectedQuickCategory!.label.toLowerCase();
        final rating = (item['rating'] as num?)?.toDouble() ?? 0.0;
        if (lower == 'top rated') {
          matchesQuickCategory = rating >= 4.0;
        } else if (lower == 'trending') {
          final reviewCount = (item['reviewCount'] as num?)?.toInt() ?? 0;
          matchesQuickCategory = rating >= 3.5 && reviewCount > 0;
        } else {
          final categoryList = (item['categories'] as List?)
                  ?.map((v) => '$v'.trim().toLowerCase())
                  .toList(growable: false) ??
              const <String>[];
          final singleCategory =
              (item['category'] as String? ?? '').toLowerCase();
          matchesQuickCategory = singleCategory.contains(lower) ||
              categoryList.any((c) => c.contains(lower));
        }
      }
      return matchesSection &&
          matchesSearch &&
          matchesPrice &&
          matchesDate &&
          matchesQuickCategory;
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
        '${_selectedEventDate?.millisecondsSinceEpoch ?? 0}_'
        '${_selectedQuickCategory?.label ?? ''}';
  }

  List<Map<String, dynamic>> _getCachedFoodItems(
    List<Map<String, dynamic>> items,
  ) {
    final key = _foodFilterCacheKey();
    if (!identical(_cachedFoodSource, items) || _cachedFoodFilterKey != key) {
      _cachedFoodSource = items;
      _cachedFoodFilterKey = key;
      var filtered = _filterItems(
        items,
        section: _VisitorFilterSection.food,
      );
      final quickLabel = _selectedQuickCategory?.label.toLowerCase();
      if (quickLabel == 'top rated') {
        filtered = List<Map<String, dynamic>>.of(filtered)
          ..sort((a, b) {
            final ratingA = (a['rating'] as num?)?.toDouble() ?? 0.0;
            final ratingB = (b['rating'] as num?)?.toDouble() ?? 0.0;
            return ratingB.compareTo(ratingA);
          });
      } else if (quickLabel == 'trending') {
        filtered = List<Map<String, dynamic>>.of(filtered)
          ..sort((a, b) {
            final ratingA = (a['rating'] as num?)?.toDouble() ?? 0.0;
            final ratingB = (b['rating'] as num?)?.toDouble() ?? 0.0;
            final countA = (a['reviewCount'] as num?)?.toInt() ?? 0;
            final countB = (b['reviewCount'] as num?)?.toInt() ?? 0;
            final scoreA = ratingA * countA;
            final scoreB = ratingB * countB;
            return scoreB.compareTo(scoreA);
          });
      }
      _cachedFoodItems = filtered;
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

  DateTime? _itemCreatedAt(Map<String, dynamic> item) {
    final raw = item['createdAt'];
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    return null;
  }

  List<Map<String, dynamic>> _foodItemsOnly(
    List<Map<String, dynamic>> items,
  ) {
    return items
        .where((item) =>
            (item['section'] as String? ?? '').trim().toLowerCase() == 'food')
        .toList(growable: false);
  }

  List<Map<String, dynamic>> _trendingThisWeekItems(
    List<Map<String, dynamic>> items,
  ) {
    final food = _foodItemsOnly(items);
    final scored = food
        .map((item) {
          final rating = (item['rating'] as num?)?.toDouble() ?? 0.0;
          final reviewCount = (item['reviewCount'] as num?)?.toInt() ?? 0;
          final score = rating * reviewCount;
          return (item: item, score: score, rating: rating);
        })
        .where((entry) => entry.rating >= 3.5 && entry.score > 0)
        .toList();
    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(10).map((entry) => entry.item).toList(growable: false);
  }

  List<Map<String, dynamic>> _recentlyAddedItems(
    List<Map<String, dynamic>> items,
  ) {
    final food = _foodItemsOnly(items);
    final withDate =
        food.where((item) => _itemCreatedAt(item) != null).toList();
    withDate.sort(
      (a, b) => _itemCreatedAt(b)!.compareTo(_itemCreatedAt(a)!),
    );
    return withDate.take(10).toList(growable: false);
  }

  List<Map<String, dynamic>> _communityPicksItems(
    List<Map<String, dynamic>> items,
  ) {
    final food = _foodItemsOnly(items);
    final picked = food.where((item) {
      final rating = (item['rating'] as num?)?.toDouble() ?? 0.0;
      final reviewCount = (item['reviewCount'] as num?)?.toInt() ?? 0;
      return rating >= 4.5 && reviewCount >= 3;
    }).toList();
    picked.sort((a, b) {
      final ratingA = (a['rating'] as num?)?.toDouble() ?? 0.0;
      final ratingB = (b['rating'] as num?)?.toDouble() ?? 0.0;
      final countA = (a['reviewCount'] as num?)?.toInt() ?? 0;
      final countB = (b['reviewCount'] as num?)?.toInt() ?? 0;
      final byRating = ratingB.compareTo(ratingA);
      return byRating != 0 ? byRating : countB.compareTo(countA);
    });
    return picked.take(10).toList(growable: false);
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
    final isFood = section == 'food';

    final didUpdate = isEvent
        ? VisitorAuth.toggleInterestedEvent(id)
        : isFood
            ? VisitorAuth.toggleSavedBusiness(id)
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
        : isFood
            ? VisitorAuth.isBusinessSaved(id)
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
    } else if (isFood) {
      final title = itemData?['title'] as String? ?? 'Food business';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isNowSaved
                ? 'Saved $title to your list'
                : 'Removed $title from your list',
          ),
        ),
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

  Future<void> _shareContent(Map<String, dynamic> item) async {
    final id = (item['id'] as String? ?? '').trim();
    final title = (item['title'] as String? ?? '').trim();
    if (id.isEmpty || title.isEmpty || !mounted) return;

    final section = (item['section'] as String? ?? '').trim();
    final type = section == 'food'
        ? ShareContentType.food
        : section == 'events'
            ? ShareContentType.event
            : ShareContentType.business;

    await showShareBottomSheet(
      context: context,
      type: type,
      id: id,
      title: title,
      description: (item['description'] as String?)?.trim(),
      location: (item['location'] as String?)?.trim(),
      dateTime: (item['dateTime'] as String?)?.trim(),
      imageUrl: (item['imageUrl'] as String?)?.trim().isNotEmpty ?? false
          ? (item['imageUrl'] as String?)!.trim()
          : null,
      businessId: id,
      businessName: title,
    );
  }

  Future<void> _shareDiscoverBusiness(Map<String, dynamic> item) async {
    final id = (item['id'] as String? ?? '').trim();
    final title = (item['title'] as String? ?? '').trim();
    if (id.isEmpty || !mounted) return;

    await showShareBottomSheet(
      context: context,
      type: ShareContentType.food,
      id: id,
      title: title.isNotEmpty ? title : 'Food spot',
      description: (item['description'] as String?)?.trim(),
      location: (item['location'] as String?)?.trim()
          ?? (item['suburb'] as String?)?.trim(),
      imageUrl: (item['imageUrl'] as String?)?.trim().isNotEmpty ?? false
          ? (item['imageUrl'] as String?)!.trim()
          : null,
      businessId: id,
      businessName: title.isNotEmpty ? title : 'Food spot',
    );
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
                  suburb: item['suburb'] as String?,
                  isVerified: (item['isVerified'] as bool?) ?? false,
                  createdAt: item['createdAt'] as DateTime?,
                  onShareTap: () => _shareContent(item),
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
          isGoogleListing: item['isGoogleListing'] ?? false,
          sourceProvider: item['sourceProvider'] as String?,
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
        : section == 'food'
            ? VisitorAuth.isBusinessSaved(id)
            : VisitorAuth.isAttractionSaved(id);
    final distance = _formatDistance(item);
    final openStatus = _getOpenStatus(item);
    final rawWaitTime = item['waitTime'];
    final waitTime = rawWaitTime != null ? '$rawWaitTime'.trim() : null;

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
          distance: distance,
          isOpenNow: openStatus?.isOpen,
          openStatusText: openStatus?.label,
          waitTime: waitTime,
          suburb: item['suburb'] as String?,
          isVerified: (item['isVerified'] as bool?) ?? false,
          createdAt: item['createdAt'] as DateTime?,
          isFavorite: isFavorite,
          cardColor: AppPalette.surface.withValues(alpha: 0.80),
          border: isEvent
              ? null
              : Border.all(
                  color: const Color(0xFF93C5FD),
                  width: 1.5,
                ),
          onShareTap: () => _shareContent(item),
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
              final isFood = section == 'food';
              final isFavorite = isEvent
                  ? VisitorAuth.isInterestedInEvent(id)
                  : isFood
                      ? VisitorAuth.isBusinessSaved(id)
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
              itemBuilder: (context, index) =>
                  _buildCompactFoodCard(items[index]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactFoodCard(Map<String, dynamic> item) {
    final id = (item['id'] as String? ?? '').trim();
    final imageUrl = (item['imageUrl'] as String? ?? '').trim();
    final title = (item['title'] as String? ?? 'Food').trim();
    final location = (item['location'] as String? ?? '').trim();
    final suburb = (item['suburb'] as String? ?? '').trim();
    final rating = (item['rating'] as num?)?.toDouble() ?? 0.0;
    final reviewCount = (item['reviewCount'] as num?)?.toInt() ?? 0;
    final isFavorite = VisitorAuth.isBusinessSaved(id);
    final isVerified = (item['isVerified'] as bool?) ?? false;
    final createdAt = item['createdAt'] as DateTime?;

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
                if (isVerified)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified_rounded,
                              size: 12, color: Color(0xFF047857)),
                          SizedBox(width: 3),
                          Text(
                            'Verified',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF047857),
                            ),
                          ),
                        ],
                      ),
                    ),
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
            const SizedBox(height: 4),
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
            const SizedBox(height: 2),
            Row(
              children: [
                const Icon(
                  Icons.place_rounded,
                  color: AppPalette.mutedText,
                  size: 12,
                ),
                const SizedBox(width: 3),
                Expanded(
                  child: Text(
                    suburb.isNotEmpty ? suburb : location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppPalette.mutedText,
                    ),
                  ),
                ),
              ],
            ),
            if (createdAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  _formatTimeAgo(createdAt),
                  style: TextStyle(
                    fontSize: 10,
                    color: AppPalette.mutedText.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeSectionCarousel(
    String title,
    String subtitle,
    List<Map<String, dynamic>> items,
  ) {
    if (items.isEmpty) return const SizedBox.shrink();

    final isDesktop = ResponsiveUtils.isDesktop(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 32 : 20,
          ),
          child: _SectionHeader(
            title: title,
            subtitle: subtitle,
            titleSize: isDesktop ? 24 : 20,
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
                horizontal: isDesktop ? 32 : 20,
              ),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (context, index) =>
                  _buildCompactFoodCard(items[index]),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  final List<_QuickCategory> _quickCategories = const [
    _QuickCategory(label: 'Cafes', emoji: '☕'),
    _QuickCategory(label: 'Burgers', emoji: '🍔'),
    _QuickCategory(label: 'Asian', emoji: '🍜'),
    _QuickCategory(label: 'Pizza', emoji: '🍕'),
    _QuickCategory(label: 'Desserts', emoji: '🍰'),
    _QuickCategory(label: 'Healthy', emoji: '🥗'),
    _QuickCategory(label: 'Top rated', emoji: '⭐'),
    _QuickCategory(label: 'Trending', emoji: '🔥'),
  ];

  void _applyQuickCategoryFilter(_QuickCategory category) {
    setState(() {
      if (_selectedQuickCategory?.label == category.label) {
        _selectedQuickCategory = null;
      } else {
        _selectedQuickCategory = category;
      }
    });
  }

  bool _isQuickCategoryActive(_QuickCategory category) {
    return _selectedQuickCategory?.label == category.label;
  }

  Widget _buildQuickCategoryChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: _quickCategories.map((category) {
          final isActive = _isQuickCategoryActive(category);
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: _CategoryChip(
              label: category.label,
              emoji: category.emoji,
              isSelected: isActive,
              onTap: () => _applyQuickCategoryFilter(category),
            ),
          );
        }).toList(),
      ),
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
    final canonical = FirebaseFirestore.instance
        .collection('businesses')
        .orderBy('rating', descending: true)
        .snapshots();
    final legacy = FirebaseFirestore.instance
        .collection('food_businesses')
        .orderBy('rating', descending: true)
        .snapshots();

    return _combineLatest2(
      canonical,
      legacy,
      (QuerySnapshot<Map<String, dynamic>> canonicalSnap,
          QuerySnapshot<Map<String, dynamic>> legacySnap) {
        final merged = <String, Map<String, dynamic>>{};

        for (final doc in canonicalSnap.docs) {
          final data = doc.data();
          if (data['deletedAt'] != null) continue;
          if (data['isActive'] == false) continue;
          if (!_isFoodListing(data)) continue;
          merged[doc.id] = _mapBusinessDocToDiscoverItem(doc);
        }

        for (final doc in legacySnap.docs) {
          if (merged.containsKey(doc.id)) continue;
          final data = doc.data();
          if (data['deletedAt'] != null || data['isActive'] == false) continue;
          if (!_isFoodListing(data)) continue;
          merged[doc.id] = _mapFoodBusinessDocToDiscoverItem(doc);
        }

        final items = merged.values.toList();
        items.sort((a, b) {
          // Paid featured/promoted listings always rank first.
          final featuredA =
              (a['isFeatured'] == true || a['isPromoted'] == true) ? 1 : 0;
          final featuredB =
              (b['isFeatured'] == true || b['isPromoted'] == true) ? 1 : 0;
          if (featuredA != featuredB) {
            return featuredB.compareTo(featuredA);
          }

          final ratingA = (a['rating'] as num?)?.toDouble() ?? 0.0;
          final ratingB = (b['rating'] as num?)?.toDouble() ?? 0.0;
          return ratingB.compareTo(ratingA);
        });
        return items;
      },
    );
  }

  bool _isFoodListing(Map<String, dynamic> data) {
    final name = '${data['businessName'] ?? ''} ${data['name'] ?? ''}'
        .toLowerCase();
    final category = '${data['category'] ?? ''}'.toLowerCase();
    final cuisines = data['cuisineTypes'] is List
        ? (data['cuisineTypes'] as List).join(' ').toLowerCase()
        : '';
    final text = '$name $category $cuisines';
    const nonFoodTerms = [
      'hotel',
      'apartment',
      'accommodation',
      'suites',
      'gallery',
      'museum',
      'aquatic',
      'laserforce',
      'bowling',
      'arcade',
      'woolworth',
      'target',
      'observatory',
      'apartments',
    ];
    if (nonFoodTerms.any(text.contains)) return false;

    const foodTerms = [
      'restaurant',
      'cafe',
      'bar',
      'food',
      'bakery',
      'pizza',
      'burger',
      'bbq',
      'coffee',
      'dining',
      'steak',
      'seafood',
      'italian',
      'indian',
      'asian',
      'thai',
      'japanese',
      'chinese',
      'mexican',
      'korean',
      'mediterranean',
      'brunch',
      'catering',
      'noodle',
      'sushi',
    ];
    return foodTerms.any(text.contains);
  }

  Stream<R> _combineLatest2<T1, T2, R>(
    Stream<T1> stream1,
    Stream<T2> stream2,
    R Function(T1, T2) combiner,
  ) {
    T1? latest1;
    T2? latest2;
    var has1 = false;
    var has2 = false;

    final controller = StreamController<R>.broadcast();

    void emit() {
      if (has1 && has2 && !controller.isClosed) {
        controller.add(combiner(latest1 as T1, latest2 as T2));
      }
    }

    stream1.listen(
      (value) {
        latest1 = value;
        has1 = true;
        emit();
      },
      onError: controller.addError,
      onDone: () {
        if (!controller.isClosed) controller.close();
      },
    );

    stream2.listen(
      (value) {
        latest2 = value;
        has2 = true;
        emit();
      },
      onError: controller.addError,
      onDone: () {
        if (!controller.isClosed) controller.close();
      },
    );

    return controller.stream;
  }

  Map<String, dynamic> _mapBusinessDocToDiscoverItem(
      QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final rawCategories = data['cuisineTypes'];
    final category = data['category']?.toString();
    List<String> categories;
    if (rawCategories is List && rawCategories.isNotEmpty) {
      categories = rawCategories.map((v) => '$v').toList();
    } else if (category != null && category.isNotEmpty) {
      categories = [category];
    } else {
      categories = <String>[];
    }
    return <String, dynamic>{
      'id': doc.id,
      'section': 'food',
      'badge': 'FOOD',
      'title': data['businessName'] ?? data['name'] ?? 'Untitled',
      'description': data['description'] ?? '',
      'location': data['address'] ?? '',
      'imageUrl':
          data['imageUrl'] ?? data['coverImageUrl'] ?? data['logoUrl'] ?? '',
      'categories': categories,
      'category': categories.isNotEmpty ? categories.first : '',
      'rating': data['rating'] ?? data['averageRating'] ?? 0,
      'reviewCount': data['reviewCount'] ?? data['reviewsCount'] ?? 0,
      'price': data['priceRange'] ?? '',
      'phone': data['phone'] ?? data['contactNumber'] ?? '',
      'website': data['website'] ?? '',
      'openingHours': data['openingHours'] ??
          (data['businessHours'] is String ? data['businessHours'] : ''),
      'email': data['email'] ?? data['businessEmail'] ?? '',
      'facebookUrl': data['facebookUrl'] ??
          data['facebook'] ??
          data['socialMedia']?['facebook'] ??
          '',
      'instagramUrl': data['instagramUrl'] ??
          data['instagram'] ??
          data['socialMedia']?['instagram'] ??
          '',
      'onlineOrderUrl': data['onlineOrderUrl'] ?? data['onlineOrderLink'] ?? '',
      'menu': data['menu'] ?? const <Map<String, dynamic>>[],
      'photoGallery': data['photoGallery'] ?? const <String>[],
      'latitude': data['latitude'],
      'longitude': data['longitude'],
      'waitTime': data['waitTime'],
      'businessHours': data['businessHours'],
      'createdAt': _toDateTime(data['createdAt']),
      'suburb': (data['suburb'] as String? ?? '').trim().isNotEmpty
          ? (data['suburb'] as String?)?.trim()
          : _extractSuburb(data['address'] as String?),
      'isVerified': data['isVerified'] == true,
      'isFeatured': data['isFeatured'] == true,
      'isPromoted': data['isPromoted'] == true,
      'isGoogleListing': data['isGoogleListing'] ?? false,
    };
  }

  Map<String, dynamic> _mapFoodBusinessDocToDiscoverItem(
      QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final rawCategories = data['cuisineTypes'];
    final category = data['category']?.toString();
    List<String> categories;
    if (rawCategories is List && rawCategories.isNotEmpty) {
      categories = rawCategories.map((v) => '$v').toList();
    } else if (category != null && category.isNotEmpty) {
      categories = [category];
    } else {
      categories = <String>[];
    }
    return <String, dynamic>{
      'id': doc.id,
      'section': 'food',
      'badge': 'FOOD',
      'title': data['name'] ?? data['businessName'] ?? 'Untitled',
      'description': data['description'] ?? '',
      'location': data['address'] ?? '',
      'imageUrl':
          data['imageUrl'] ?? data['logoUrl'] ?? data['coverImageUrl'] ?? '',
      'categories': categories,
      'category': categories.isNotEmpty ? categories.first : '',
      'rating': data['rating'] ?? data['averageRating'] ?? 0,
      'reviewCount': data['reviewCount'] ?? data['reviewsCount'] ?? 0,
      'price': data['priceRange'] ?? '',
      'phone': data['phone'] ?? data['contactNumber'] ?? '',
      'website': data['website'] ?? '',
      'openingHours': data['openingHours'] ??
          (data['businessHours'] is String ? data['businessHours'] : ''),
      'email': data['email'] ?? data['businessEmail'] ?? '',
      'facebookUrl': data['facebookUrl'] ??
          data['facebook'] ??
          data['socialMedia']?['facebook'] ??
          '',
      'instagramUrl': data['instagramUrl'] ??
          data['instagram'] ??
          data['socialMedia']?['instagram'] ??
          '',
      'onlineOrderUrl': data['onlineOrderUrl'] ?? data['onlineOrderLink'] ?? '',
      'menu': data['menu'] ?? const <Map<String, dynamic>>[],
      'photoGallery': data['photoGallery'] ?? const <String>[],
      'latitude': data['latitude'] ?? data['coordinates']?['latitude'],
      'longitude': data['longitude'] ?? data['coordinates']?['longitude'],
      'waitTime': data['waitTime'],
      'businessHours': data['businessHours'],
      'createdAt': _toDateTime(data['createdAt']),
      'suburb': (data['suburb'] as String? ?? '').trim().isNotEmpty
          ? (data['suburb'] as String?)?.trim()
          : _extractSuburb(data['address'] as String?),
      'isVerified': data['isVerified'] == true,
      'isFeatured': data['isFeatured'] == true,
      'isPromoted': data['isPromoted'] == true,
      'isGoogleListing': data['isGoogleListing'] ?? false,
    };
  }

  /// Returns a compact distance string from the user's location to the item,
  /// or null when coordinates are unavailable.
  String? _formatDistance(Map<String, dynamic> item) {
    final lat = (item['latitude'] as num?)?.toDouble();
    final lng = (item['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;

    final distanceKm = LocationUtilities.calculateDistance(
      lat1: _userLatitude,
      lon1: _userLongitude,
      lat2: lat,
      lon2: lng,
    );

    if (distanceKm < 1.0) {
      return '${(distanceKm * 1000).toStringAsFixed(0)} m';
    }
    return '${distanceKm.toStringAsFixed(1)} km';
  }

  /// Determines whether a business is currently open based on its structured
  /// [businessHours] map. Returns null if no hours are available.
  ({bool isOpen, String label})? _getOpenStatus(Map<String, dynamic> item) {
    final rawHours = item['businessHours'];
    if (rawHours is! Map<String, dynamic>) return null;

    try {
      final hours = BusinessHours.fromFirestore(rawHours);
      final now = DateTime.now();
      final dayName = DateFormat('EEEE').format(now);
      final dayHours = hours.getHoursForDay(dayName);
      if (dayHours == null) return null;

      if (dayHours.isClosed) {
        return (isOpen: false, label: 'Closed');
      }

      final openTime = dayHours.openTime;
      final closeTime = dayHours.closeTime;
      if (openTime == null || closeTime == null) return null;

      final currentMinutes = now.hour * 60 + now.minute;
      final openParts = openTime.split(':');
      final closeParts = closeTime.split(':');
      final openMinutes =
          int.parse(openParts[0]) * 60 + int.parse(openParts[1]);
      final closeMinutes =
          int.parse(closeParts[0]) * 60 + int.parse(closeParts[1]);

      final isOpen =
          currentMinutes >= openMinutes && currentMinutes < closeMinutes;
      return (isOpen: isOpen, label: isOpen ? 'Open now' : 'Closed');
    } catch (_) {
      return null;
    }
  }

  /// Pulls a suburb/neighbourhood out of a comma-separated address string.
  /// Falls back to the first non-empty segment if the structure is unclear.
  String? _extractSuburb(String? address) {
    final parts = (address ?? '')
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (parts.isEmpty) return null;
    if (parts.length >= 3) return parts[parts.length - 2];
    if (parts.length == 2) return parts.first;
    return parts.first;
  }

  DateTime? _toDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    return null;
  }

  String _formatTimeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  static String _formatCompactTimeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
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

  Widget _buildDiscoverContent() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _discoverFoodStream(),
      builder: (context, foodSnapshot) {
        if (foodSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (foodSnapshot.hasError) {
          final message = AppErrorMessages.fromException(
            foodSnapshot.error,
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
            final items = foodSnapshot.data ?? const <Map<String, dynamic>>[];
            final foodItems = _getCachedFoodItems(items);
            final isMobile = ResponsiveUtils.isMobile(context);

            return CustomScrollView(
              slivers: [
                // ── Header with greeting and search (no chips) ──
                SliverToBoxAdapter(
                  child: Container(
                    color: Colors.transparent,
                    padding: const EdgeInsets.only(top: 16),
                    child: _buildDiscoverHeader(isMobile),
                  ),
                ),

                // ── Responsive bento grid homepage ──
                SliverToBoxAdapter(
                  child: Container(
                    color: Colors.transparent,
                    padding: _bentoHorizontalPadding(context),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1400),
                        child: _buildBentoGrid(
                          items: items,
                          foodItems: foodItems,
                          isMobile: isMobile,
                        ),
                      ),
                    ),
                  ),
                ),

                // Bottom spacing
                const SliverToBoxAdapter(child: SizedBox(height: 48)),
              ],
            );
          },
        );
      },
    );
  }

  /// Builds the bento discover header: greeting and search only.
  /// On desktop/tablet the [DesktopTopAppBar] already provides search and
  /// profile, so we omit them here to avoid duplication. Quick category
  /// chips were removed in favour of the bento category grid.
  Widget _buildDiscoverHeader(bool isMobile) {
    final visitorName =
        VisitorAuth.currentVisitor?.name.split(' ').first ?? 'Visitor';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '👋 ${_greetingForHour(DateTime.now().hour)}, $visitorName',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppPalette.charcoal,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _weatherTagline(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppPalette.charcoal,
                      ),
                    ),
                  ],
                ),
              ),
              if (isMobile) ...[
                const SizedBox(width: 12),
                _buildDiscoverProfileAvatar(),
              ],
            ],
          ),
          if (isMobile) ...[
            const SizedBox(height: 18),
            DiscoverSearchBar(
              controller: _searchController,
              onSearchChanged: (_) {
                // Existing search state is driven by _searchController; the
                // StreamBuilder rebuilds via the debounced setState in the
                // search bar's own controller callback.
                if (mounted) setState(() {});
              },
              onFilterTap: _openFilterSheet,
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Bento-grid discover homepage helpers
  // ─────────────────────────────────────────────────────────────────────────

  /// Orchestrates the responsive bento layout.
  ///
  /// Desktop/tablet: a balanced two-column masonry-style grid. The left
  /// column highlights the featured restaurant and trending spots, while the
  /// right column surfaces nearby locations, cuisine categories, and
  /// community picks.
  ///
  /// Mobile: a single-column stack ordered for food discovery.
  Widget _buildBentoGrid({
    required List<Map<String, dynamic>> items,
    required List<Map<String, dynamic>> foodItems,
    required bool isMobile,
  }) {
    final trending = _trendingThisWeekItems(items).take(6).toList();
    final nearby = _sortedByDistance(foodItems).take(5).toList();
    final communityPicks = _communityPicksItems(items).take(4).toList();

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildCategorySection(foodItems),
          if (foodItems.isNotEmpty) _buildFeaturedCarousel(foodItems),
          if (trending.isNotEmpty) _buildTrendingSection(trending),
          if (nearby.isNotEmpty) _buildBentoNearbySection(nearby),
          if (communityPicks.isNotEmpty)
            _buildCommunityPicksSection(communityPicks),
        ],
      );
    }

    final isTablet = ResponsiveUtils.isTablet(context);
    final columnSpacing = isTablet ? 20.0 : 28.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left column: hero featured carousel + trending.
        Expanded(
          flex: isTablet ? 1 : 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (foodItems.isNotEmpty) _buildFeaturedCarousel(foodItems),
              if (trending.isNotEmpty) _buildTrendingSection(trending),
            ],
          ),
        ),
        SizedBox(width: columnSpacing),
        // Right column: nearby + categories + community picks.
        Expanded(
          flex: isTablet ? 1 : 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (nearby.isNotEmpty) _buildBentoNearbySection(nearby),
              _buildCategorySection(foodItems),
              if (communityPicks.isNotEmpty)
                _buildCommunityPicksSection(communityPicks),
            ],
          ),
        ),
      ],
    );
  }

  /// Auto-rotating featured business carousel.
  Widget _buildFeaturedCarousel(List<Map<String, dynamic>> items) {
    // Paid featured/promoted listings get carousel priority, then top-rated.
    final featured = items
        .where((item) {
          final imageUrl = (item['imageUrl'] as String? ?? '').trim();
          return item['isGoogleListing'] == true &&
              imageUrl.isNotEmpty &&
              !imageUrl.toLowerCase().contains('unsplash.com');
        })
        .toList()
      ..sort((a, b) {
        final paidA =
            (a['isFeatured'] == true || a['isPromoted'] == true) ? 1 : 0;
        final paidB =
            (b['isFeatured'] == true || b['isPromoted'] == true) ? 1 : 0;
        if (paidA != paidB) return paidB.compareTo(paidA);
        final ratingA = (a['rating'] as num?)?.toDouble() ?? 0.0;
        final ratingB = (b['rating'] as num?)?.toDouble() ?? 0.0;
        return ratingB.compareTo(ratingA);
      });

    final selectedCategory = _selectedQuickCategory?.label;
    final borderColor = selectedCategory != null
        ? _categoryColorFor(selectedCategory)
        : AppPalette.border;

    return _AutoRotatingCarousel(
      items: featured,
      autoRotateInterval: const Duration(seconds: 5),
      inactivityResumeDelay: const Duration(seconds: 5),
      borderColor: borderColor,
      cardBuilder: (item) => _FeaturedRestaurantCard(item: item),
      onCardTap: _openFoodDetails,
    );
  }

  /// Vertical list of nearby food spots with distance labels.
  Widget _buildBentoNearbySection(List<Map<String, dynamic>> items) {
    return _BentoTile(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BentoSectionHeader(
            title: AppLocalizations.of(context)!.nearby,
            subtitle: 'Closest to you right now',
          ),
          const SizedBox(height: 12),
          ...items.map((item) => _NearbyRow(
                item: item,
                distance: _formatDistance(item),
                onTap: () => _openFoodDetails(item),
              )),
        ],
      ),
    );
  }

  /// Vertical list of trending food businesses (no horizontal carousel).
  Widget _buildTrendingSection(List<Map<String, dynamic>> items) {
    return _BentoTile(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BentoSectionHeader(
            title: 'Trending now',
            subtitle: 'Popular this week',
          ),
          const SizedBox(height: 12),
          ...items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return _TrendingRow(
              rank: index + 1,
              item: item,
              onTap: () => _openFoodDetails(item),
            );
          }),
        ],
      ),
    );
  }

  /// Compact community-picks grid shown on one of the columns.
  Widget _buildCommunityPicksSection(List<Map<String, dynamic>> items) {
    return _BentoTile(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _BentoSectionHeader(
            title: 'Community picks',
            subtitle: 'Highest rated by foodies',
          ),
          const SizedBox(height: 12),
          ...items.map((item) => _TrendingRow(
                item: item,
                onTap: () => _openFoodDetails(item),
              )),
        ],
      ),
    );
  }

  /// Bento grid of cuisine categories derived from actual items.
  Widget _buildCategorySection(List<Map<String, dynamic>> items) {
    final categoryCounts = <String, int>{};
    for (final item in items) {
      final categories = (item['categories'] as List<dynamic>?)
              ?.map((e) => e.toString().trim())
              .where((s) => s.isNotEmpty) ??
          const [];
      for (final cat in categories.take(1)) {
        categoryCounts[cat] = (categoryCounts[cat] ?? 0) + 1;
      }
    }

    final sortedCategories = categoryCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final displayCategories =
        sortedCategories.take(6).map((e) => e.key).toList();

    // Fallback to quick-categories if the data is sparse.
    final categories = displayCategories.isNotEmpty
        ? displayCategories
        : _quickCategories.map((c) => c.label).toList();

    final isMobile = ResponsiveUtils.isMobile(context);

    return _BentoTile(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BentoSectionHeader(
            title: AppLocalizations.of(context)!.categories,
            subtitle: 'Browse by cuisine',
          ),
          const SizedBox(height: 12),
          if (isMobile)
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.zero,
                itemCount: categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final label = categories[index];
                  final categoryColor = _categoryColorFor(label);
                  final isSelected =
                      _selectedQuickCategory?.label.toLowerCase() ==
                          label.toLowerCase();
                  return _CuisinePill(
                    label: label,
                    color: categoryColor,
                    isSelected: isSelected,
                    onTap: () => _applyQuickCategoryFilterByLabel(label),
                  );
                },
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = constraints.maxWidth > 420 ? 3 : 2;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 2.6,
                  ),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final label = categories[index];
                    final categoryColor = _categoryColorFor(label);
                    final isSelected =
                        _selectedQuickCategory?.label.toLowerCase() ==
                            label.toLowerCase();
                    return _CategoryTile(
                      label: label,
                      color: categoryColor,
                      isSelected: isSelected,
                      onTap: () => _applyQuickCategoryFilterByLabel(label),
                    );
                  },
                );
              },
            ),
        ],
      ),
    );
  }

  /// Returns a stable, deterministic color for any category/cuisine label.
  Color _categoryColorFor(String label) {
    final palette = const <Color>[
      Color(0xFFFF6B2B), // ochre
      Color(0xFF2563EB), // deep blue
      Color(0xFF22C55E), // green
      Color(0xFFF59E0B), // gold
      Color(0xFF9333EA), // purple
      Color(0xFFEC4899), // pink
      Color(0xFF14B8A6), // teal
      Color(0xFFEF4444), // red
      Color(0xFF6366F1), // indigo
      Color(0xFF84CC16), // lime
    ];
    var hash = 0;
    for (var i = 0; i < label.length; i++) {
      hash = label.codeUnitAt(i) + ((hash << 5) - hash);
    }
    return palette[hash.abs() % palette.length];
  }

  /// Returns [items] sorted by distance from the user's default location.
  List<Map<String, dynamic>> _sortedByDistance(
      List<Map<String, dynamic>> items) {
    final scored = items.map((item) {
      final lat = (item['latitude'] as num?)?.toDouble();
      final lng = (item['longitude'] as num?)?.toDouble();
      double distanceKm = double.infinity;
      if (lat != null && lng != null) {
        distanceKm = LocationUtilities.calculateDistance(
          lat1: _userLatitude,
          lon1: _userLongitude,
          lat2: lat,
          lon2: lng,
        );
      }
      return (item: item, distanceKm: distanceKm);
    }).toList();

    scored.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    return scored.map((e) => e.item).toList(growable: false);
  }

  void _applyQuickCategoryFilterByLabel(String label) {
    final category = _quickCategories.firstWhere(
      (c) => c.label.toLowerCase() == label.toLowerCase(),
      orElse: () => _QuickCategory(label: label, emoji: '🍽️'),
    );
    _applyQuickCategoryFilter(category);
  }

  /// Compact profile avatar for the discover header.
  Widget _buildDiscoverProfileAvatar() {
    final heroProfileImage = _profileImageProvider(VisitorAuth.currentVisitor);
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = 4),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppPalette.border, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: CircleAvatar(
          radius: 28,
          backgroundColor: AppPalette.deepBlue,
          backgroundImage: heroProfileImage,
          child: heroProfileImage == null
              ? const Icon(Icons.person_rounded, color: Colors.white, size: 28)
              : null,
        ),
      ),
    );
  }

  /// A section with a header and horizontal business card carousel.
  Widget _buildDiscoverSection(
    String title,
    String subtitle,
    List<Map<String, dynamic>> items,
  ) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      color: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
            child: DiscoverSectionHeader(
              title: title,
              subtitle: subtitle,
            ),
          ),
          _buildDiscoverBusinessCarousel(items),
        ],
      ),
    );
  }

  /// Horizontal carousel of large food business cards.
  Widget _buildDiscoverBusinessCarousel(List<Map<String, dynamic>> items) {
    if (items.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= Breakpoints.desktop;
        final cardWidth = _discoverCardWidth(context);

        if (isWide) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Wrap(
                  spacing: 20,
                  runSpacing: 24,
                  children: items.map((item) {
                    return DiscoverBusinessCard(
                      key: ValueKey(item['id']),
                      item: item,
                      width: cardWidth,
                      onTap: () => _openFoodDetails(item),
                      onShareTap: () => _shareDiscoverBusiness(item),
                    );
                  }).toList(),
                ),
              ),
            ),
          );
        }

        return SizedBox(
          height: cardWidth * 1.42,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final item = items[index];
              return DiscoverBusinessCard(
                key: ValueKey(item['id']),
                item: item,
                width: cardWidth,
                onTap: () => _openFoodDetails(item),
                onShareTap: () => _shareDiscoverBusiness(item),
              );
            },
          ),
        );
      },
    );
  }

  /// Responsive sliver grid/list for all food businesses.
  Widget _buildDiscoverBusinessSliver(List<Map<String, dynamic>> items) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final crossAxisExtent = constraints.crossAxisExtent;
        final cardWidth = _discoverCardWidth(context);

        if (crossAxisExtent >= Breakpoints.desktop) {
          final crossAxisCount = ResponsiveUtils.gridColumnCount(
            context,
            itemMinWidth: cardWidth,
            minColumns: 2,
            maxColumns: 4,
            spacing: 20,
          );
          return SliverPadding(
            padding: _discoverHorizontalPadding(context),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 20,
                mainAxisSpacing: 24,
                childAspectRatio: 0.72,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => DiscoverBusinessCard(
                  key: ValueKey(items[index]['id']),
                  item: items[index],
                  width: cardWidth,
                  onTap: () => _openFoodDetails(items[index]),
                  onShareTap: () => _shareDiscoverBusiness(items[index]),
                ),
                childCount: items.length,
              ),
            ),
          );
        }

        if (crossAxisExtent >= Breakpoints.mobile) {
          return SliverPadding(
            padding: _discoverHorizontalPadding(context),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 20,
                childAspectRatio: 0.70,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => DiscoverBusinessCard(
                  key: ValueKey(items[index]['id']),
                  item: items[index],
                  width: cardWidth,
                  onTap: () => _openFoodDetails(items[index]),
                  onShareTap: () => _shareDiscoverBusiness(items[index]),
                ),
                childCount: items.length,
              ),
            ),
          );
        }

        return SliverPadding(
          padding: _discoverHorizontalPadding(context),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: DiscoverBusinessCard(
                  key: ValueKey(items[index]['id']),
                  item: items[index],
                  width: double.infinity,
                  onTap: () => _openFoodDetails(items[index]),
                  onShareTap: () => _shareDiscoverBusiness(items[index]),
                ),
              ),
              childCount: items.length,
            ),
          ),
        );
      },
    );
  }

  double _discoverCardWidth(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= Breakpoints.desktop) return 320;
    if (width >= Breakpoints.mobile) return 290;
    return 280;
  }

  double _discoverBannerHeight(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= Breakpoints.desktop) return 190;
    if (width >= Breakpoints.mobile) return 185;
    return 180;
  }

  EdgeInsets _discoverHorizontalPadding(BuildContext context) {
    return ResponsiveUtils.isDesktop(context)
        ? const EdgeInsets.symmetric(horizontal: 32)
        : const EdgeInsets.symmetric(horizontal: 20);
  }

  EdgeInsets _bentoHorizontalPadding(BuildContext context) {
    if (ResponsiveUtils.isDesktop(context)) {
      return const EdgeInsets.symmetric(horizontal: 32);
    }
    if (ResponsiveUtils.isTablet(context)) {
      return const EdgeInsets.symmetric(horizontal: 24);
    }
    return const EdgeInsets.symmetric(horizontal: 16);
  }

  /// Quick category chips using the new reusable design but the existing
  /// private [_QuickCategory] model so state and filters stay unchanged.
  Widget _buildDiscoverQuickCategoryChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Row(
        children: _quickCategories.map((category) {
          final isActive = _isQuickCategoryActive(category);
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: _CategoryChip(
              label: category.label,
              emoji: category.emoji,
              isSelected: isActive,
              onTap: () => _applyQuickCategoryFilter(category),
            ),
          );
        }).toList(),
      ),
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
    return StreamBuilder<List<DocumentSnapshot>>(
      stream: _savedBusinessesStream(savedBusinessIds.toList()),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final docs = snapshot.data ?? [];
        if (docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final items = docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>? ?? {};
          final cuisineTypes = data['cuisineTypes'];
          final category = data['category']?.toString();
          final categories = cuisineTypes is List && cuisineTypes.isNotEmpty
              ? cuisineTypes.map((v) => '$v').toList()
              : category != null && category.isNotEmpty
                  ? [category]
                  : <String>[];
          return <String, dynamic>{
            'id': doc.id,
            'section': 'food',
            'badge': 'FOOD',
            'title': data['businessName'] ?? data['name'] ?? 'Untitled',
            'description': data['description'] ?? '',
            'location': data['address'] ?? '',
            'imageUrl': data['coverImageUrl'] ??
                data['imageUrl'] ??
                data['logoUrl'] ??
                '',
            'categories': categories,
            'category': categories.isNotEmpty ? categories.first : '',
            'rating': data['rating'] ?? data['averageRating'] ?? 0,
            'reviewCount': data['reviewCount'] ?? data['reviewsCount'] ?? 0,
            'price': data['priceRange'] ?? '',
            'phone': data['phone'] ?? data['contactNumber'] ?? '',
            'website': data['website'] ?? '',
            'openingHours': data['openingHours'] ??
                (data['businessHours'] is String ? data['businessHours'] : ''),
            'email': data['email'] ?? data['businessEmail'] ?? '',
            'facebookUrl': data['facebookUrl'] ??
                data['facebook'] ??
                data['socialMedia']?['facebook'] ??
                '',
            'instagramUrl': data['instagramUrl'] ??
                data['instagram'] ??
                data['socialMedia']?['instagram'] ??
                '',
            'onlineOrderUrl':
                data['onlineOrderUrl'] ?? data['onlineOrderLink'] ?? '',
            'menu': data['menu'] ?? const <Map<String, dynamic>>[],
            'photoGallery': data['photoGallery'] ?? const <String>[],
            'isGoogleListing': data['isGoogleListing'] ?? false,
          };
        }).toList();

        return _buildSavedCardGrid(items);
      },
    );
  }

  /// Streams saved business docs from the canonical [businesses] collection,
  /// falling back to [food_businesses] when a canonical doc is missing or
  /// effectively empty (legacy data was never migrated into it).
  Stream<List<DocumentSnapshot>> _savedBusinessesStream(List<String> ids) {
    final controller = StreamController<List<DocumentSnapshot>>.broadcast();
    List<DocumentSnapshot>? canonicalDocs;
    List<DocumentSnapshot>? legacyDocs;
    var canonicalDone = false;
    var legacyDone = false;

    bool isEmptyBusinessDoc(DocumentSnapshot doc) {
      if (!doc.exists) return true;
      final data = doc.data() as Map<String, dynamic>? ?? {};
      final hasName = (data['businessName'] as String? ?? data['name'] as String? ?? '').trim().isNotEmpty;
      final hasAddress = (data['address'] as String? ?? '').trim().isNotEmpty;
      return !hasName && !hasAddress;
    }

    void emit() {
      if (!canonicalDone || !legacyDone || controller.isClosed) return;
      final usableCanonical = canonicalDocs?.where((d) => !isEmptyBusinessDoc(d)).toList() ?? [];
      final usableCanonicalIds = usableCanonical.map((d) => d.id).toSet();
      final fallbackDocs = legacyDocs?.where((d) => !usableCanonicalIds.contains(d.id)).toList() ?? [];
      controller.add([...usableCanonical, ...fallbackDocs]);
    }

    FirebaseFirestore.instance
        .collection('businesses')
        .where(FieldPath.documentId, whereIn: ids)
        .snapshots()
        .listen(
          (snap) {
            canonicalDocs = snap.docs;
            canonicalDone = true;
            emit();
          },
          onError: (e) {
            debugPrint('[VisitorPortal] saved businesses canonical error: $e');
            canonicalDocs = [];
            canonicalDone = true;
            emit();
          },
        );

    FirebaseFirestore.instance
        .collection('food_businesses')
        .where(FieldPath.documentId, whereIn: ids)
        .snapshots()
        .listen(
          (snap) {
            legacyDocs = snap.docs;
            legacyDone = true;
            emit();
          },
          onError: (e) {
            debugPrint('[VisitorPortal] saved businesses legacy error: $e');
            legacyDocs = [];
            legacyDone = true;
            emit();
          },
        );

    return controller.stream;
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

  Widget _buildSettingsCard({required List<Widget> children}) {
    return Card(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppPalette.ochre.withValues(alpha: 0.3), width: 2),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 26,
              offset: const Offset(0, 10),
              spreadRadius: -2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required Widget leading,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
    bool showChevron = true,
  }) {
    return ListTile(
      leading: leading,
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: showChevron
          ? const Icon(
              Icons.chevron_right_rounded,
              color: AppPalette.mutedText,
            )
          : null,
      onTap: onTap,
    );
  }

  Widget _buildEmojiIcon(String emoji, Color backgroundColor) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        emoji,
        style: const TextStyle(fontSize: 22),
      ),
    );
  }

  void _showPrivacyPolicy() {
    _showLegalSheet(
      title: 'Privacy Policy',
      icon: '📄',
      content: '''
Your privacy is important to us.

BrisConnect+ collects limited information necessary to provide personalised recommendations, event listings, and community features. Location data is used only when you grant permission and is never sold to third parties.

We use industry-standard security measures to protect your data. You can request deletion of your account and associated data at any time through Help & Support.

This policy may be updated from time to time. Continued use of the app constitutes acceptance of the latest policy.
''',
    );
  }

  void _showTermsOfService() {
    _showLegalSheet(
      title: 'Terms of Service',
      icon: '📜',
      content: '''
Welcome to BrisConnect+.

By using this app, you agree to use the platform responsibly and respectfully. Users must not post harmful, misleading, or illegal content. Event submissions and business listings are reviewed before going live.

BrisConnect+ reserves the right to remove content or suspend accounts that violate these terms. The app and its content are provided "as is" without warranties of any kind.

These terms may be updated periodically. Continued use of the app means you accept the latest terms.
''',
    );
  }

  void _showLegalSheet({
    required String title,
    required String icon,
    required String content,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.92,
        minChildSize: 0.4,
        builder: (_, controller) {
          return Container(
            decoration: const BoxDecoration(
              color: AppPalette.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppPalette.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppPalette.ochre.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(icon, style: const TextStyle(fontSize: 22)),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppPalette.charcoal,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: AppPalette.border),
                Expanded(
                  child: SingleChildScrollView(
                    controller: controller,
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      content.trim(),
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.6,
                        color: AppPalette.charcoal,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showLicences() {
    showLicensePage(
      context: context,
      applicationName: 'BrisConnect+',
      applicationVersion: '1.0.0',
      applicationIcon: Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppPalette.ochre.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Text('🌐', style: TextStyle(fontSize: 28)),
        ),
      ),
    );
  }

  void _goToSignIn() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AnimatedWelcomeScreen()),
      (route) => false,
    );
  }

  Widget _buildBrisConnectAvatar({required double radius}) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.white,
      child: Padding(
        padding: EdgeInsets.all(radius * 0.18),
        child: Image.asset(
          'assets/images/brisconnect_logo.png',
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Widget _buildProfileInfoCard({
    required VisitorUser? visitor,
    required String displayName,
    required String displayEmail,
    required String displayPhone,
    required String displayLanguage,
    required ImageProvider<Object>? profileImage,
    required AppLocalizations l10n,
  }) {
    final isGuest = visitor == null;

    return Card(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppPalette.ochre.withValues(alpha: 0.3), width: 2),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 26,
              offset: const Offset(0, 10),
              spreadRadius: -2,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: isGuest
              ? _buildGuestInfoCard(l10n)
              : _buildSignedInInfoCard(
                  visitor: visitor,
                  displayName: displayName,
                  displayEmail: displayEmail,
                  displayPhone: displayPhone,
                  displayLanguage: displayLanguage,
                  profileImage: profileImage,
                  l10n: l10n,
                ),
        ),
      ),
    );
  }

  Widget _buildGuestInfoCard(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildBrisConnectAvatar(radius: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Guest Visitor',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppPalette.charcoal,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Using BrisConnect without signing in.',
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
        const SizedBox(height: 16),
        Text(
          'Sign in to save businesses, submit reviews, and personalise recommendations.',
          style: TextStyle(
            fontSize: 13,
            height: 1.5,
            color: AppPalette.charcoal.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _goToSignIn,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppPalette.deepBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: const Text('Sign In'),
          ),
        ),
      ],
    );
  }

  Widget _buildSignedInInfoCard({
    required VisitorUser visitor,
    required String displayName,
    required String displayEmail,
    required String displayPhone,
    required String displayLanguage,
    required ImageProvider<Object>? profileImage,
    required AppLocalizations l10n,
  }) {
    return Row(
      children: [
        GestureDetector(
          onTap: _uploadVisitorProfileImage,
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              if (profileImage != null)
                CircleAvatar(
                  radius: 42,
                  backgroundImage: profileImage,
                )
              else
                _buildBrisConnectAvatar(radius: 42),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppPalette.ochre,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
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
                          DropdownMenuItem(
                              value: 'pa',
                              child: Text(_formatLanguageLabel(l10n, 'pa'))),
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

  void _showFeedbackForm() {
    final visitor = VisitorAuth.currentVisitor;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FeedbackFormScreen(
          reporterRole: 'visitor',
          reporterName: visitor?.name ?? 'Guest Visitor',
          reporterEmail: visitor?.email ?? '',
        ),
      ),
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
        const maxContentWidth = 1080.0;

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: maxContentWidth),
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                isProfileDesktop ? 32 : 20,
                horizontalPadding,
                36,
              ),
              children: [
                _buildSectionLabel(l10n.profileInfo),
                _buildProfileInfoCard(
                  visitor: visitor,
                  displayName: displayName,
                  displayEmail: displayEmail,
                  displayPhone: displayPhone,
                  displayLanguage: displayLanguage,
                  profileImage: profileImage,
                  l10n: l10n,
                ),
                const SizedBox(height: 24),
                _buildSectionLabel('Account'),
                _buildSettingsCard(
                  children: [
                    _buildSettingsTile(
                      leading: _buildEmojiIcon('🌏', const Color(0xFFE0F2FE)),
                      title: l10n.language,
                      subtitle: _formatLanguageLabel(l10n, displayLanguage),
                      onTap: () => _showEditProfileSheet(
                        displayName,
                        displayEmail,
                        displayPhone,
                        displayLanguage,
                      ),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    _buildSettingsTile(
                      leading: _buildEmojiIcon('📍', const Color(0xFFFEE2E2)),
                      title: l10n.locationRadius,
                      subtitle: l10n.setHowFarRecommendations,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const VisitorSettingsScreen(),
                        ),
                      ),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    _buildSettingsTile(
                      leading: _buildEmojiIcon('🎨', const Color(0xFFF3E8FF)),
                      title: l10n.appearanceSettings,
                      subtitle: l10n.themeTextSizeFeedback,
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
                const SizedBox(height: 24),
                _buildSectionLabel('Support'),
                _buildSettingsCard(
                  children: [
                    _buildSettingsTile(
                      leading: _buildEmojiIcon('💬', const Color(0xFFD1FAE5)),
                      title: 'Send App Feedback',
                      subtitle:
                          'Report bugs, misleading information, or improvement suggestions.',
                      onTap: () => _showFeedbackForm(),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    _buildSettingsTile(
                      leading: _buildEmojiIcon('📥', const Color(0xFFDBEAFE)),
                      title: l10n.myFeedback,
                      subtitle: l10n.viewSubmittedFeedback,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MyFeedbackScreen(
                            reporterEmail: displayEmail,
                          ),
                        ),
                      ),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    _buildSettingsTile(
                      leading: _buildEmojiIcon('❓', const Color(0xFFFEF3C7)),
                      title: 'Help Centre',
                      subtitle: 'FAQs, contact us & app info',
                      onTap: () => _showHelpSupport(context),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    _buildSettingsTile(
                      leading: _buildEmojiIcon('📄', const Color(0xFFE0E7FF)),
                      title: 'Privacy Policy',
                      subtitle: 'How we handle your data',
                      onTap: _showPrivacyPolicy,
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    _buildSettingsTile(
                      leading: _buildEmojiIcon('📜', const Color(0xFFFFF7ED)),
                      title: 'Terms of Service',
                      subtitle: 'Rules for using the app',
                      onTap: _showTermsOfService,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildSectionLabel('About'),
                _buildSettingsCard(
                  children: [
                    _buildSettingsTile(
                      leading: _buildEmojiIcon('🔖', const Color(0xFFF3F4F6)),
                      title: 'Version',
                      subtitle: '1.0.0',
                      showChevron: false,
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    _buildSettingsTile(
                      leading: _buildEmojiIcon('📚', const Color(0xFFF3F4F6)),
                      title: 'Licences',
                      subtitle: 'Open-source software notices',
                      onTap: _showLicences,
                    ),
                  ],
                ),
                // Admin Portal Link (only for admin users)
                if (AdminAuth.isAdminLoggedIn) ...[
                  const SizedBox(height: 24),
                  _buildSectionLabel('Admin'),
                  _buildSettingsCard(
                    children: [
                      _buildSettingsTile(
                        leading: _buildEmojiIcon('⚙️', const Color(0xFFE0E7FF)),
                        title: 'Admin Portal',
                        subtitle: 'Manage users, businesses & analytics',
                        onTap: () {
                          Navigator.of(context).pushNamedAndRemoveUntil(
                            '/admin/dashboard',
                            (route) => false,
                          );
                        },
                      ),
                    ],
                  ),
                ],
                if (visitor != null) ...[
                  const SizedBox(height: 24),
                  _buildSectionLabel(l10n.signOut),
                  Card(
                    color: AppPalette.surface,
                    elevation: 8,
                    shadowColor: Colors.black.withValues(alpha: 0.12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: AppPalette.border),
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
            ),
          ),
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
    return SafeArea(child: child);
  }

  Widget _buildWeatherChip() {
    if (_weatherLoading) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Colors.white,
        ),
      );
    }

    if (_weatherError != null || _weather == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.network(
            _weather!.iconUrl,
            width: 32,
            height: 32,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.wb_sunny_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 2),
          Text(
            '${_weather!.temperature.round()}°C',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              shadows: [
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
                    notificationBell: VisitorNotificationBell(
                      onTap: () => Navigator.pushNamed(
                        context,
                        '/visitor/notifications',
                      ),
                      iconColor: AppPalette.charcoal,
                    ),
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
                      actions: [
                        VisitorNotificationBell(
                          onTap: () => Navigator.pushNamed(
                            context,
                            '/visitor/notifications',
                          ),
                          iconColor: AppPalette.charcoal,
                        ),
                      ],
                    ),
          body: Stack(
            fit: StackFit.expand,
            children: [
              if (_selectedIndex != 2) const FoodRainBackground(),
              Column(
                children: [
                  Expanded(
                    child: isDesktop ? _buildDesktopBody() : _buildMobileBody(),
                  ),
                ],
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

  Widget _buildDiscoverBody() {
    return _buildDiscoverContent();
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

/// Animated food-themed background pattern used behind visitor portal tabs.
///
/// Food icons gently drift downward in a continuous loop, filling whitespace
/// without distracting from the page content.
/// The Map tab is deliberately excluded because it shows its own map tiles.
class FoodPatternBackground extends StatefulWidget {
  const FoodPatternBackground({super.key});

  static const foodEmojis = [
    '🍕', '🍔', '🍟', '🌭', '🍿', '�', '🥚', '🧇', '🥞',
    '🍞', '🥐', '🥨', '🥯', '🥖', '🧀', '🥗', '🥙', '🥪',
    '🌮', '🌯', '🥫', '🍖', '🍗', '🥩', '🍠', '🥟', '🥠',
    '🍱', '🍘', '🍙', '🍚', '🍛', '🍜', '🦪', '🍣', '🍤',
    '🍦', '🍧', '🍨', '🍩', '🍪', '🎂', '🍰', '🧁', '🥧',
    '🍫', '🍬', '🍭', '🍮', '🍯', '🍎', '🍏', '🍐', '🍊',
  ];

  @override
  State<FoodPatternBackground> createState() => _FoodPatternBackgroundState();
}

class _FoodPatternBackgroundState extends State<FoodPatternBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final columns = 5;
            final cellWidth = constraints.maxWidth / columns;
            final cellHeight = cellWidth;
            final visibleRows = (constraints.maxHeight / cellHeight).ceil();
            final rows = visibleRows + 2;
            final totalHeight = rows * cellHeight;

            return Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: AppPalette.background),
                OverflowBox(
                  maxWidth: constraints.maxWidth,
                  maxHeight: totalHeight,
                  alignment: Alignment.topCenter,
                  child: Transform.translate(
                    offset: Offset(0, _controller.value * cellHeight),
                    child: SizedBox(
                      width: constraints.maxWidth,
                      height: totalHeight,
                      child: Column(
                        children: [
                          for (var row = 0; row < rows; row++)
                            Row(
                              children: [
                                for (var col = 0; col < columns; col++)
                                  _buildTile(
                                    index: row * columns + col,
                                    size: cellWidth - 8,
                                  ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildTile({required int index, required double size}) {
    final emoji = FoodPatternBackground.foodEmojis[index % FoodPatternBackground.foodEmojis.length];
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Text(
          emoji,
          style: TextStyle(fontSize: size * 0.7),
        ),
      ),
    );
  }
}

/// Food emojis falling like rain.
/// Each emoji is an independent positioned Text widget that animates
/// from the top to the bottom of the screen on its own timer, so there
/// is no large scrolling container that could be clipped or hidden.
class FoodRainBackground extends StatefulWidget {
  const FoodRainBackground({super.key});

  @override
  State<FoodRainBackground> createState() => _FoodRainBackgroundState();
}

class _FoodRainBackgroundState extends State<FoodRainBackground> {
  static const _emojiCount = 40;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final random = Random(42);
        final drops = <Widget>[
          const Positioned.fill(
            child: ColoredBox(color: AppPalette.background),
          ),
        ];

        for (var i = 0; i < _emojiCount; i++) {
          final size = 72.0 + random.nextDouble() * 72.0;
          final left = random.nextDouble() * (constraints.maxWidth - size);
          final durationSeconds = 4.0 + random.nextDouble() * 6.0;
          final delaySeconds = random.nextDouble() * 8.0;
          final emojiIndex = random.nextInt(FoodPatternBackground.foodEmojis.length);

          drops.add(
            _FallingEmoji(
              emoji: FoodPatternBackground.foodEmojis[emojiIndex],
              size: size,
              left: left,
              viewportHeight: constraints.maxHeight,
              durationSeconds: durationSeconds,
              delaySeconds: delaySeconds,
            ),
          );
        }

        return Stack(
          fit: StackFit.expand,
          children: drops,
        );
      },
    );
  }
}

class _FallingEmoji extends StatefulWidget {
  final String emoji;
  final double size;
  final double left;
  final double viewportHeight;
  final double durationSeconds;
  final double delaySeconds;

  const _FallingEmoji({
    required this.emoji,
    required this.size,
    required this.left,
    required this.viewportHeight,
    required this.durationSeconds,
    required this.delaySeconds,
  });

  @override
  State<_FallingEmoji> createState() => _FallingEmojiState();
}

class _FallingEmojiState extends State<_FallingEmoji>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (widget.durationSeconds * 1000).round()),
    );

    Future.delayed(Duration(milliseconds: (widget.delaySeconds * 1000).round()), () {
      if (mounted) {
        _controller.forward(from: 0).whenComplete(() {
          if (mounted) {
            _controller.repeat();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final top = -widget.size + _controller.value * (widget.viewportHeight + widget.size * 2);
        return Positioned(
          left: widget.left,
          top: top,
          // Emoji glyphs render with fixed colors, so opacity is used to
          // make them read as a subtle background instead of a loud overlay.
          child: Opacity(
            opacity: 0.14,
            child: Text(
              widget.emoji,
              style: TextStyle(fontSize: widget.size),
            ),
          ),
        );
      },
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

// ─────────────────────────────────────────────────────────────────────────────
// Bento-grid homepage widgets
// ─────────────────────────────────────────────────────────────────────────────

class _BentoTile extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _BentoTile({
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppPalette.ochre.withValues(alpha: 0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 28,
            offset: const Offset(0, 12),
            spreadRadius: -2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

class _BentoSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;

  const _BentoSectionHeader({
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppPalette.charcoal,
          ),
        ),
        if (subtitle != null && subtitle!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppPalette.mutedText,
            ),
          ),
        ],
      ],
    );
  }
}

class _FeaturedPhoto extends StatefulWidget {
  final String url;
  final double width;
  final double height;

  const _FeaturedPhoto({
    required this.url,
    required this.width,
    required this.height,
  });

  @override
  State<_FeaturedPhoto> createState() => _FeaturedPhotoState();
}

class _FeaturedPhotoState extends State<_FeaturedPhoto> {
  late Future<Uint8List> _photo;

  @override
  void initState() {
    super.initState();
    _photo = _loadPhoto();
  }

  @override
  void didUpdateWidget(covariant _FeaturedPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) _photo = _loadPhoto();
  }

  Future<Uint8List> _loadPhoto() async {
    final response = await http.get(Uri.parse(widget.url));
    if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
      throw Exception('Featured photo request failed');
    }
    return response.bodyBytes;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _photo,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Container(
            color: AppPalette.surfaceAlt,
            alignment: Alignment.center,
            child: const Icon(
              Icons.restaurant_rounded,
              color: AppPalette.mutedText,
              size: 40,
            ),
          );
        }
        if (!snapshot.hasData) {
          return Container(
            color: AppPalette.surfaceAlt,
            alignment: Alignment.center,
            child: const CircularProgressIndicator(strokeWidth: 2),
          );
        }
        return Image.memory(
          snapshot.data!,
          width: widget.width,
          height: widget.height,
          fit: BoxFit.cover,
          gaplessPlayback: true,
        );
      },
    );
  }
}

/// Static featured-restaurant card used inside the auto-rotating carousel.
class _FeaturedRestaurantCard extends StatelessWidget {
  final Map<String, dynamic> item;

  const _FeaturedRestaurantCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final title = (item['title'] as String? ?? 'Featured').trim();
    final location = (item['location'] as String? ?? '').trim();
    final imageUrl = (item['imageUrl'] as String? ?? '').trim();
    final categories = (item['categories'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .where((s) => s.isNotEmpty)
            .toList(growable: false) ??
        const <String>[];
    final cuisine = categories.isNotEmpty ? categories.first : 'Food';
    final rating = (item['rating'] as num?)?.toDouble() ?? 0.0;
    final reviewCount = (item['reviewCount'] as num?)?.toInt() ?? 0;

    // Tap is handled by the outer _AutoRotatingCarousel GestureDetector.
    // Do NOT add another GestureDetector here — it would absorb the tap
    // and prevent onCardTap from firing.
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: AppPalette.surfaceAlt,
            alignment: Alignment.center,
            child: const Icon(Icons.restaurant_rounded,
                color: AppPalette.mutedText, size: 40),
          ),
        ),
        Positioned(
          top: 14,
          right: 14,
          child: _FavoriteButton(item: item),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0xE6000000)],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        color: Colors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.star_rounded,
                        color: AppPalette.gold, size: 16),
                    const SizedBox(width: 4),
                    Text(rating.toStringAsFixed(1),
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Colors.white)),
                    Text(' · $reviewCount reviews · $cuisine',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white70)),
                  ],
                ),
                if (location.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(location,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white70),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FavoriteButton extends StatefulWidget {
  final Map<String, dynamic> item;

  const _FavoriteButton({required this.item});

  @override
  State<_FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<_FavoriteButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _burstController;
  late final Animation<double> _heartPulse;
  final List<_HeartParticle> _particles = [];

  @override
  void initState() {
    super.initState();
    _burstController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..addListener(() {
        if (mounted) setState(() {});
      });
    _heartPulse = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.45), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 1.45, end: 1.0), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.15), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.0), weight: 15),
    ]).animate(
      CurvedAnimation(parent: _burstController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _burstController.dispose();
    super.dispose();
  }

  void _triggerBurst() {
    final random = Random();
    _particles.clear();
    const particleCount = 18;
    for (var i = 0; i < particleCount; i++) {
      _particles.add(
        _HeartParticle(
          index: i,
          total: particleCount,
          random: random,
        ),
      );
    }
    _burstController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final id = (widget.item['id'] as String? ?? '').trim();
    final isFavorite = VisitorAuth.isBusinessSaved(id);

    return Material(
      color: Colors.white.withValues(alpha: 0.95),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          if (!isFavorite) _triggerBurst();
          VisitorAuth.toggleSavedBusiness(id);
        },
        child: Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Transform.scale(
                scale: _heartPulse.value,
                child: Icon(
                  isFavorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: AppPalette.ochre,
                  size: 22,
                ),
              ),
              ..._particles.map((particle) {
                return AnimatedBuilder(
                  animation: _burstController,
                  builder: (_, __) {
                    final t = _burstController.value;
                    final easeOut = Curves.easeOut.transform(t);
                    final opacity = t < 0.65 ? 1.0 : 1.0 - ((t - 0.65) / 0.35);
                    final alpha = opacity.clamp(0, 1).toDouble();
                    final scale = t < 0.25
                        ? 0.5 + (t / 0.25) * 0.8
                        : 1.3 - ((t - 0.25) / 0.75) * 0.6;
                    return Positioned(
                      left: 21 + particle.dx * easeOut * particle.distance,
                      top: 21 + particle.dy * easeOut * particle.distance,
                      child: Opacity(
                        opacity: alpha,
                        child: Transform.rotate(
                          angle: particle.rotation * t,
                          child: Transform.scale(
                            scale: scale.clamp(0.4, 1.5),
                            child: Icon(
                              Icons.favorite_rounded,
                              color: particle.color.withValues(alpha: alpha),
                              size: particle.size,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeartParticle {
  static const _colors = [
    AppPalette.ochre,
    Color(0xFFFF4D6D),
    Color(0xFFFF758F),
    Color(0xFFFF8FA3),
    Color(0xFFFFB3C1),
  ];

  final double dx;
  final double dy;
  final double rotation;
  final double size;
  final double distance;
  final Color color;

  _HeartParticle({
    required int index,
    required int total,
    required Random random,
  })  : size = 10 + random.nextDouble() * 9,
        distance = 38 + random.nextDouble() * 34,
        rotation =
            (random.nextBool() ? 1 : -1) * (0.4 + random.nextDouble() * 1.2),
        color = _colors[index % _colors.length],
        dx = cos(index * 2 * pi / total + (random.nextDouble() - 0.5) * 0.35),
        dy = sin(index * 2 * pi / total + (random.nextDouble() - 0.5) * 0.35);
}

class _OpenStatusBadge extends StatelessWidget {
  final ({bool isOpen, String label}) status;

  const _OpenStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color:
            status.isOpen ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
        borderRadius: BorderRadius.circular(99),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        status.label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _NearbyRow extends StatelessWidget {
  final Map<String, dynamic> item;
  final String? distance;
  final VoidCallback onTap;

  const _NearbyRow({
    required this.item,
    required this.distance,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final title = (item['title'] as String? ?? '').trim();
    final suburb = (item['suburb'] as String? ?? '').trim();
    final location = (item['location'] as String? ?? '').trim();
    final isFeatured = (item['isFeatured'] as bool?) ?? false;
    final isPromoted = (item['isPromoted'] as bool?) ?? false;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: FallbackImage(
                    imageUrl: (item['imageUrl'] as String? ?? '').trim(),
                    category: 'food',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppPalette.charcoal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isFeatured || isPromoted) ...[
                          const SizedBox(width: 6),
                          Icon(
                            Icons.local_fire_department_rounded,
                            color: AppPalette.ochre,
                            size: 14,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      suburb.isNotEmpty ? suburb : location,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppPalette.mutedText,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (distance != null)
                Text(
                  distance!,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppPalette.ochre,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrendingRow extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;
  final int? rank;

  const _TrendingRow({
    required this.item,
    required this.onTap,
    this.rank,
  });

  @override
  Widget build(BuildContext context) {
    final title = (item['title'] as String? ?? '').trim();
    final suburb = (item['suburb'] as String? ?? '').trim();
    final location = (item['location'] as String? ?? '').trim();
    final rating = (item['rating'] as num?)?.toDouble() ?? 0.0;
    final isFeatured = (item['isFeatured'] as bool?) ?? false;
    final isPromoted = (item['isPromoted'] as bool?) ?? false;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Row(
            children: [
              if (rank != null) ...[
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppPalette.surface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$rank',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppPalette.charcoal,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: FallbackImage(
                    imageUrl: (item['imageUrl'] as String? ?? '').trim(),
                    category: 'food',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppPalette.charcoal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isFeatured || isPromoted) ...[
                          const SizedBox(width: 6),
                          Icon(
                            Icons.local_fire_department_rounded,
                            color: AppPalette.ochre,
                            size: 14,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      location.isNotEmpty ? location : suburb,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppPalette.mutedText,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.only(left: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star_rounded,
                        color: AppPalette.gold, size: 14),
                    const SizedBox(width: 3),
                    Text(
                      rating.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppPalette.charcoal,
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
  }
}

class _CompactMetaRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _CompactMetaRow({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppPalette.mutedText),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppPalette.mutedText.withValues(alpha: 0.9),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryTile({
    required this.label,
    required this.color,
    required this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? color.withValues(alpha: 0.12) : AppPalette.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isSelected ? color : AppPalette.charcoal,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

/// Compact horizontally-scrollable cuisine pill for the bento category
/// section on mobile.
class _CuisinePill extends StatelessWidget {
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _CuisinePill({
    required this.label,
    required this.color,
    required this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? color.withValues(alpha: 0.12) : Colors.white,
      borderRadius: BorderRadius.circular(99),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
              color: isSelected ? color : AppPalette.border.withValues(alpha: 0.6),
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isSelected ? color : AppPalette.charcoal,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

/// Auto-rotating horizontal carousel with manual swipe, arrow controls,
/// page indicator dots, and pause-on-interaction behaviour.
class _AutoRotatingCarousel extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  final Widget Function(Map<String, dynamic>) cardBuilder;
  final void Function(Map<String, dynamic>) onCardTap;
  final Duration autoRotateInterval;
  final Duration inactivityResumeDelay;
  final Color borderColor;

  const _AutoRotatingCarousel({
    required this.items,
    required this.cardBuilder,
    required this.onCardTap,
    this.autoRotateInterval = const Duration(seconds: 5),
    this.inactivityResumeDelay = const Duration(seconds: 5),
    this.borderColor = AppPalette.border,
  });

  @override
  State<_AutoRotatingCarousel> createState() => _AutoRotatingCarouselState();
}

class _AutoRotatingCarouselState extends State<_AutoRotatingCarousel> {
  Timer? _autoRotateTimer;
  Timer? _resumeTimer;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _startAutoRotate();
  }

  @override
  void dispose() {
    _autoRotateTimer?.cancel();
    _resumeTimer?.cancel();
    super.dispose();
  }

  void _startAutoRotate() {
    _autoRotateTimer?.cancel();
    _autoRotateTimer = Timer.periodic(widget.autoRotateInterval, (_) {
      if (!mounted || widget.items.length <= 1) return;
      final nextPage = (_currentPage + 1) % widget.items.length;
      setState(() => _currentPage = nextPage);
    });
  }

  void _pauseAutoRotate() {
    _autoRotateTimer?.cancel();
    _resumeTimer?.cancel();
    _resumeTimer = Timer(widget.inactivityResumeDelay, () {
      if (mounted) _startAutoRotate();
    });
  }

  void _goToPage(int page) {
    _pauseAutoRotate();
    setState(() => _currentPage = page);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: widget.borderColor,
          width: 4,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.20),
            blurRadius: 32,
            offset: const Offset(0, 14),
            spreadRadius: -2,
          ),
          BoxShadow(
            color: widget.borderColor.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = ResponsiveUtils.isMobile(context);
                final aspectRatio = isMobile ? 16 / 15 : 16 / 13;
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    AspectRatio(
                      aspectRatio: aspectRatio,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () =>
                            widget.onCardTap(widget.items[_currentPage]),
                        onPanStart: (_) => _pauseAutoRotate(),
                        onPanEnd: (_) => _pauseAutoRotate(),
                        child: widget.cardBuilder(widget.items[_currentPage]),
                      ),
                    ),
                    // Left arrow.
                Positioned(
                  left: 8,
                  child: _CarouselArrow(
                    icon: Icons.chevron_left_rounded,
                    onTap: () => _goToPage(
                      (_currentPage - 1 + widget.items.length) %
                          widget.items.length,
                    ),
                  ),
                ),
                // Right arrow.
                Positioned(
                  right: 8,
                  child: _CarouselArrow(
                    icon: Icons.chevron_right_rounded,
                    onTap: () => _goToPage(
                      (_currentPage + 1) % widget.items.length,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        // Page indicator dots.
            Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.items.length, (index) {
                  final isActive = index == _currentPage;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: isActive ? 18 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isActive ? AppPalette.ochre : AppPalette.border,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CarouselArrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CarouselArrow({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.9),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          child: Icon(icon, color: AppPalette.charcoal, size: 22),
        ),
      ),
    );
  }
}

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

class _QuickCategory {
  final String label;
  final String emoji;

  const _QuickCategory({required this.label, required this.emoji});
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
          'Trending This Week',
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
          final suburb = (item['suburb'] as String? ?? '').trim();
          final rating = (item['rating'] as num?)?.toDouble() ?? 0.0;
          final reviewCount = (item['reviewCount'] as num?)?.toInt() ?? 0;
          final isVerified = (item['isVerified'] as bool?) ?? false;
          final createdAt = item['createdAt'] as DateTime?;

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
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppPalette.charcoal,
                                  ),
                                ),
                              ),
                              if (isVerified)
                                const Padding(
                                  padding: EdgeInsets.only(left: 6),
                                  child: Icon(Icons.verified_rounded,
                                      size: 18, color: Color(0xFF047857)),
                                ),
                            ],
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
                          if (suburb.isNotEmpty || location.isNotEmpty)
                            Text(
                              suburb.isNotEmpty ? suburb : location,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppPalette.mutedText,
                              ),
                            ),
                          if (createdAt != null)
                            Text(
                              _VisitorPortalScreenState._formatCompactTimeAgo(
                                  createdAt),
                              style: TextStyle(
                                fontSize: 11,
                                color:
                                    AppPalette.mutedText.withValues(alpha: 0.8),
                                fontWeight: FontWeight.w500,
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
