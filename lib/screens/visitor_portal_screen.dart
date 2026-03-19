import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:brisconnect/auth/visitor_auth.dart';
import 'package:brisconnect/screens/map_events_screen.dart';
import 'package:brisconnect/screens/visitor_interested_events_screen.dart';
import 'package:brisconnect/screens/visitor_notifications_screen.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/widgets/reusable_event_card.dart';

class VisitorPortalScreen extends StatefulWidget {
  const VisitorPortalScreen({super.key});

  @override
  State<VisitorPortalScreen> createState() => _VisitorPortalScreenState();
}

class _VisitorPortalScreenState extends State<VisitorPortalScreen> {
  final TextEditingController _searchController = TextEditingController();
  int _selectedIndex = 0;
  final Set<String> _favoriteIds = <String>{};
  DateTime? _selectedEventDate;
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

  static const List<_VisitorEventItem> _councilEvents = [
    _VisitorEventItem(
      id: 'c1',
      title: 'Brisbane Twilight Music in the Park',
      description:
          'Golden-hour live sets, picnic rugs on the lawn, and a crowd that sings along under the city lights.',
      dateTime: 'Fri, 21 Mar • 6:30 PM',
      location: 'Roma Street Parkland, Brisbane City',
      price: 'Free',
      webLink: 'https://www.brisbane.qld.gov.au/whats-on-and-events',
      badge: 'GOING FAST',
      imageUrl:
          'https://images.unsplash.com/photo-1459749411175-04bf5292ceea?auto=format&fit=crop&w=1400&q=80',
    ),
    _VisitorEventItem(
      id: 'c2',
      title: 'South Bank Cultural Night Market',
      description:
          'Lantern-lit laneways packed with global street food, handmade finds, and cultural performances all night.',
      dateTime: 'Sat, 29 Mar • 5:00 PM',
      location: 'Little Stanley Street, South Brisbane',
      price: 'From \$15',
      webLink: 'https://visit.brisbane.qld.au/whats-on',
      badge: 'LIMITED',
      imageUrl:
          'https://images.unsplash.com/photo-1472653431158-6364773b2a56?auto=format&fit=crop&w=1400&q=80',
    ),
  ];

  static const List<_VisitorEventItem> _historicalSights = [
    _VisitorEventItem(
      id: 'h1',
      title: 'Brisbane City Hall Heritage Tour',
      description:
          'Step behind the sandstone facade to uncover grand architecture, hidden stories, and iconic city history.',
      dateTime: 'Daily • 10:00 AM',
      location: 'King George Square, Brisbane City',
      price: 'From \$12',
      webLink: 'https://www.museumofbrisbane.com.au/visit/city-hall/',
      badge: 'POPULAR',
      imageUrl:
          'https://images.unsplash.com/photo-1477512076069-d5746aa5b6f8?auto=format&fit=crop&w=1400&q=80',
    ),
    _VisitorEventItem(
      id: 'h2',
      title: 'Story Bridge Historical Walk',
      description:
          'A breezy riverside walk with dramatic skyline views and tales of how Brisbane grew around its famous bridge.',
      dateTime: 'Sun, 6 Apr • 8:00 AM',
      location: 'Kangaroo Point Cliffs',
      price: 'Free',
      webLink: 'https://storybridgeadventureclimb.com.au/',
      badge: 'NEW',
      imageUrl:
          'https://images.unsplash.com/photo-1517090504586-fde19ea6066f?auto=format&fit=crop&w=1400&q=80',
    ),
  ];

  static const List<_VisitorEventItem> _foodPlaces = [
    _VisitorEventItem(
      id: 'f1',
      title: 'Riverfront Kitchen Food Experience',
      description:
          'Chef-led tasting plates, fresh Queensland produce, and riverfront sunsets that make every course memorable.',
      dateTime: 'Daily • 12:00 PM - 9:00 PM',
      location: 'South Brisbane',
      price: 'From \$35',
      webLink: 'https://eatstreetnorthshore.com.au/',
      badge: 'TRENDING',
      imageUrl:
          'https://images.unsplash.com/photo-1552566626-52f8b828add9?auto=format&fit=crop&w=1400&q=80',
    ),
    _VisitorEventItem(
      id: 'f2',
      title: 'Laneway Espresso Brunch Session',
      description:
          'Specialty brews, buttery pastries, and an easy weekend vibe tucked into one of the city’s coolest laneways.',
      dateTime: 'Sat-Sun • 8:00 AM - 2:00 PM',
      location: 'Fortitude Valley',
      price: 'From \$18',
      webLink: 'https://www.visitbrisbane.com.au/information/articles/eat-and-drink/best-brisbane-cafes',
      badge: 'TOP RATED',
      imageUrl:
          'https://images.unsplash.com/photo-1509042239860-f550ce710b93?auto=format&fit=crop&w=1400&q=80',
    ),
  ];

  static const List<_VisitorEventItem> _olympicVenues = [
    _VisitorEventItem(
      id: 'o1',
      title: 'The Gabba Stadium Tour Stop',
      description:
          'Walk the players tunnel, hear game-day stories, and feel the roar of one of Brisbane’s legendary grounds.',
      dateTime: 'Open daily • 9:00 AM - 5:00 PM',
      location: 'Woolloongabba',
      price: 'From \$20',
      webLink: 'https://thegabba.com.au/',
      badge: 'OLYMPIC VENUE',
      imageUrl:
          'https://images.unsplash.com/photo-1574629810360-7efbbe195018?auto=format&fit=crop&w=1400&q=80',
    ),
    _VisitorEventItem(
      id: 'o2',
      title: 'Suncorp Stadium Matchday Experience',
      description:
          'Big-match energy, premium views, and behind-the-scenes access at a stadium built for unforgettable nights.',
      dateTime: 'Sat-Sun • 10:00 AM - 8:00 PM',
      location: 'Milton',
      price: 'From \$25',
      webLink: 'https://suncorpstadium.com.au/',
      badge: 'BRISBANE 2032',
      imageUrl:
          'https://images.unsplash.com/photo-1508098682722-e99c43a406b2?auto=format&fit=crop&w=1400&q=80',
    ),
    _VisitorEventItem(
      id: 'o3',
      title: 'RNA Showgrounds Precinct Walk',
      description:
          'Explore a future Olympic precinct where heritage pavilions meet bold new sporting and event spaces.',
      dateTime: 'Fri-Sun • 8:00 AM - 6:00 PM',
      location: 'Bowen Hills',
      price: 'Free',
      webLink: 'https://www.brisbaneshowgrounds.com.au/',
      badge: 'NEW',
      imageUrl:
          'https://images.unsplash.com/photo-1517466787929-bc90951d0974?auto=format&fit=crop&w=1400&q=80',
    ),
  ];

  List<_VisitorEventItem> get _allItems => [
        ..._councilEvents,
        ..._historicalSights,
        ..._foodPlaces,
        ..._olympicVenues,
      ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_VisitorEventItem> _filterItems(
    List<_VisitorEventItem> items, {
    required _VisitorFilterSection section,
  }) {
    if (!_selectedSections.contains(section)) {
      return const [];
    }

    final query = _searchController.text.trim().toLowerCase();
    return items.where((item) {
      final matchesSearch = query.isEmpty ||
          item.title.toLowerCase().contains(query) ||
          item.description.toLowerCase().contains(query) ||
          item.location.toLowerCase().contains(query) ||
          item.dateTime.toLowerCase().contains(query);
      final matchesPrice = _selectedPriceFilters.contains(item.priceFilter);
      final matchesDate = _matchesSelectedDate(item);

      return matchesSearch && matchesPrice && matchesDate;
    }).toList();
  }

  bool _matchesSelectedDate(_VisitorEventItem item) {
    final selectedDate = _selectedEventDate;
    if (selectedDate == null) {
      return true;
    }

    final normalized = item.dateTime.toLowerCase();
    if (normalized.startsWith('daily') || normalized.startsWith('open daily')) {
      return true;
    }

    if (normalized.startsWith('sat-sun')) {
      return selectedDate.weekday == DateTime.saturday ||
          selectedDate.weekday == DateTime.sunday;
    }

    if (normalized.startsWith('fri-sun')) {
      return selectedDate.weekday >= DateTime.friday &&
          selectedDate.weekday <= DateTime.sunday;
    }

    final parsedDate = _parseVisitorItemDate(item.dateTime);
    if (parsedDate == null) {
      return false;
    }

    return parsedDate.year == selectedDate.year &&
        parsedDate.month == selectedDate.month &&
        parsedDate.day == selectedDate.day;
  }

  DateTime? _parseVisitorItemDate(String value) {
    final match = RegExp(r'^[A-Za-z]{3},\s+(\d{1,2})\s+([A-Za-z]{3})').firstMatch(value);
    if (match == null) {
      return null;
    }

    final day = int.tryParse(match.group(1)!);
    final month = _monthFromShortName(match.group(2)!);
    if (day == null || month == null) {
      return null;
    }

    return DateTime(DateTime.now().year, month, day);
  }

  int? _monthFromShortName(String monthText) {
    const months = {
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

    return months[monthText.toLowerCase()];
  }

  String _formatSelectedDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day/$month/$year';
  }

  Future<void> _pickEventDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedEventDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );

    if (picked != null && mounted) {
      setState(() => _selectedEventDate = picked);
    }
  }

  bool get _hasCustomFilters {
    return _selectedSections.length != _VisitorFilterSection.values.length ||
      _selectedPriceFilters.length != _VisitorPriceFilter.values.length ||
      _selectedEventDate != null;
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

    final result = await showModalBottomSheet<({
      Set<_VisitorFilterSection> sections,
      Set<_VisitorPriceFilter> prices,
      DateTime? selectedDate,
    })>(
      context: context,
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

            Future<void> pickDate() async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: selectedDate ?? now,
                firstDate: DateTime(now.year - 1),
                lastDate: DateTime(now.year + 2),
              );
              if (picked != null) {
                setModalState(() => selectedDate = picked);
              }
            }

            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
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
                  const SizedBox(height: 8),
                  const Text(
                    'Date',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppPalette.charcoal,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: pickDate,
                          icon: const Icon(Icons.calendar_today_rounded),
                          label: Text(
                            selectedDate == null
                                ? 'Select date'
                                : _formatSelectedDate(selectedDate!),
                          ),
                        ),
                      ),
                      if (selectedDate != null) ...[
                        const SizedBox(width: 10),
                        IconButton(
                          tooltip: 'Clear date',
                          onPressed: () => setModalState(() => selectedDate = null),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
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
                ],
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
          label: Text(_formatSelectedDate(_selectedEventDate!)),
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

  void _toggleFavorite(String id) {
    setState(() {
      if (_favoriteIds.contains(id)) {
        _favoriteIds.remove(id);
      } else {
        _favoriteIds.add(id);
      }
    });
  }

  Future<void> _openWebLink(String link) async {
    final uri = Uri.parse(link);
    final didLaunch = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!didLaunch && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open the event link right now.')),
      );
    }
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

  Widget _buildQuickDateFilter() {
    final hasDate = _selectedEventDate != null;

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          OutlinedButton.icon(
            onPressed: _pickEventDate,
            icon: const Icon(Icons.calendar_today_rounded),
            label: Text(
              hasDate
                  ? 'Date: ${_formatSelectedDate(_selectedEventDate!)}'
                  : 'Filter by date',
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppPalette.deepBlue,
              side: const BorderSide(color: AppPalette.border),
              backgroundColor: AppPalette.surface,
            ),
          ),
          if (hasDate) ...[
            const SizedBox(width: 10),
            TextButton(
              onPressed: () {
                setState(() => _selectedEventDate = null);
              },
              child: const Text('Clear date'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDiscoverBody() {
    final council = _filterItems(
      _councilEvents,
      section: _VisitorFilterSection.events,
    );
    final sights = _filterItems(
      _historicalSights,
      section: _VisitorFilterSection.historical,
    );
    final food = _filterItems(
      _foodPlaces,
      section: _VisitorFilterSection.food,
    );
    final olympic = _filterItems(
      _olympicVenues,
      section: _VisitorFilterSection.stadiums,
    );
    final hasVisibleEvents =
        council.isNotEmpty || sights.isNotEmpty || food.isNotEmpty || olympic.isNotEmpty;

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
        _buildQuickDateFilter(),
        _buildActiveFilterChips(),
        const SizedBox(height: 14),
        _buildMapBanner(),
        const SizedBox(height: 18),
        if (!hasVisibleEvents)
          const _EmptyState(
            title: 'No events available',
            subtitle: 'Try changing your search or filters to see more results.',
          )
        else ...[
        _SectionHeader(
          title: 'Brisbane City Council Events',
          subtitle: 'Popular community events and cultural activities',
        ),
        ...council.map(_buildEventCard),
        const SizedBox(height: 10),
        const _SectionHeader(
          title: 'Historical Sights in Brisbane',
          subtitle: 'Stories, landmarks, and heritage tours',
        ),
        ...sights.map(_buildEventCard),
        const SizedBox(height: 10),
        const _SectionHeader(
          title: 'Authentic Brisbane Food Places',
          subtitle: 'Curated local dining and food culture picks',
        ),
        ...food.map(_buildEventCard),
        const SizedBox(height: 10),
        const _SectionHeader(
          title: 'Olympic Stadium Venues',
          subtitle: 'Brisbane 2032 stadiums and key sports precincts',
        ),
        ...olympic.map(_buildEventCard),
        ],
      ],
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
              child: const Icon(Icons.map_rounded, color: Colors.white, size: 24),
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

  Widget _buildEventCard(_VisitorEventItem item) {
    return ReusableEventCard(
      imageUrl: item.imageUrl,
      badgeText: item.badge,
      title: item.title,
      description: item.description,
      dateTime: item.dateTime,
      location: item.location,
      price: item.price,
      isFavorite: _favoriteIds.contains(item.id),
      onShareTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Share: ${item.title}')),
        );
      },
      onWebTap: () => _openWebLink(item.webLink),
      onFavoriteTap: () => _toggleFavorite(item.id),
    );
  }

  Widget _buildSavedBody() {
    final items = _allItems.where((item) => _favoriteIds.contains(item.id)).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        const Text(
          'Saved',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppPalette.charcoal,
          ),
        ),
        const SizedBox(height: 10),
        if (items.isEmpty)
          const _EmptyState(
            title: 'No saved experiences yet',
            subtitle: 'Tap the heart icon on any card to save it here.',
          )
        else
          ...items.map(_buildEventCard),
      ],
    );
  }

  Widget _buildProfileBody() {
    final visitor = VisitorAuth.currentVisitor;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        const Text(
          'Profile',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppPalette.charcoal,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          color: AppPalette.surface,
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: AppPalette.surfaceAlt,
              child: Icon(Icons.person_rounded, color: AppPalette.deepBlue),
            ),
            title: Text(visitor?.name ?? 'Visitor User'),
            subtitle: Text(visitor?.email ?? 'visitor@brisconnect.com'),
          ),
        ),
        Card(
          color: AppPalette.surface,
          child: ListTile(
            leading: const Icon(Icons.logout_rounded, color: AppPalette.ochre),
            title: const Text('Logout'),
            subtitle: const Text('Sign out and return to welcome screen'),
            onTap: () {
              VisitorAuth.logout();
              Navigator.popUntil(context, (route) => route.isFirst);
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F3EA),
      appBar: AppBar(
        title: const Text('Visitor Portal'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded),
            tooltip: 'Notifications',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const VisitorNotificationsScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.favorite_rounded),
            tooltip: 'Interested events',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const VisitorInterestedEventsScreen(),
                ),
              );
            },
          ),
        ],
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

class _VisitorEventItem {
  final String id;
  final String imageUrl;
  final String badge;
  final String title;
  final String description;
  final String dateTime;
  final String location;
  final String price;
  final String webLink;

  _VisitorPriceFilter get priceFilter =>
      price.toLowerCase().contains('free')
          ? _VisitorPriceFilter.free
          : _VisitorPriceFilter.paid;

  const _VisitorEventItem({
    required this.id,
    required this.imageUrl,
    required this.badge,
    required this.title,
    required this.description,
    required this.dateTime,
    required this.location,
    required this.price,
    required this.webLink,
  });
}

enum _VisitorFilterSection { events, historical, food, stadiums }

enum _VisitorPriceFilter { free, paid }
