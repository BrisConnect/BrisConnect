import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:brisconnect/auth/visitor_auth.dart';
import 'package:brisconnect/models/discover_event.dart';
import 'package:brisconnect/models/food_place.dart';
import 'package:brisconnect/models/historical_sight.dart';
import 'package:brisconnect/models/stadium_venue.dart';
import 'package:brisconnect/screens/visitor_login_screen.dart';
import 'package:brisconnect/screens/visitor_signup_screen.dart';
import 'package:brisconnect/screens/welcome_screen.dart';
import 'package:brisconnect/screens/attractions_screen.dart';
import 'package:brisconnect/screens/food_detail_screen.dart';
import 'package:brisconnect/screens/stadium_detail_screen.dart';
import 'package:brisconnect/screens/visitor_event_detail_screen.dart';
import 'package:brisconnect/services/discover_data_service.dart';
import 'package:brisconnect/theme/app_palette.dart';

enum _DiscoverSection { events, sights, food, stadiums }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  final DiscoverDataService _discoverDataService = DiscoverDataService();

  int _selectedTabIndex = 0;
  bool _isLoading = true;
  String? _loadError;

  List<Event> _councilEvents = const [];
  List<HistoricalSight> _historicalSights = const [];
  List<FoodPlace> _foodPlaces = const [];
  List<StadiumVenue> _stadiums = const [];

  final Set<String> _savedIds = <String>{};
  final Set<_DiscoverSection> _enabledSections = <_DiscoverSection>{
    _DiscoverSection.events,
    _DiscoverSection.sights,
    _DiscoverSection.food,
    _DiscoverSection.stadiums,
  };
  final Set<String> _selectedCategoryChips = <String>{};

  static const List<String> _categoryChips = [
    'Culture',
    'Family',
    'Free',
    'Heritage',
    'Food',
    'Outdoor',
    'Stadiums',
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadDiscoverData();
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  Future<void> _loadDiscoverData() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final results = await Future.wait([
        _discoverDataService.fetchCouncilEvents(),
        _discoverDataService.fetchHistoricalSights(),
        _discoverDataService.fetchFoodPlaces(),
        _discoverDataService.fetchStadiumVenues(),
      ]);

      if (!mounted) return;
      setState(() {
        _councilEvents = results[0] as List<Event>;
        _historicalSights = results[1] as List<HistoricalSight>;
        _foodPlaces = results[2] as List<FoodPlace>;
        _stadiums = results[3] as List<StadiumVenue>;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError =
            'Unable to load Discover content right now. Please try again.';
      });
    }
  }

  void _onSearchChanged() => setState(() {});

  bool _matchesCategory(List<String> categories) {
    if (_selectedCategoryChips.isEmpty) return true;
    return categories.any(_selectedCategoryChips.contains);
  }

  bool _matchesSearch(List<String> values) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return true;
    return values.any((value) => value.toLowerCase().contains(query));
  }

  void _toggleSaved(String id) {
    if (!VisitorAuth.isVisitorLoggedIn) {
      _showLoginRequiredSheet();
      return;
    }

    setState(() {
      if (_savedIds.contains(id)) {
        _savedIds.remove(id);
      } else {
        _savedIds.add(id);
      }
    });
  }

  void _showLoginRequiredSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppPalette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Login required',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppPalette.charcoal,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please login as a Visitor to save Discover items.',
                style: TextStyle(color: AppPalette.mutedText),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _openVisitorLogin();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppPalette.ochre,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Login'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openFilterSheet() async {
    final sections = Set<_DiscoverSection>.from(_enabledSections);

    final result = await showModalBottomSheet<Set<_DiscoverSection>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppPalette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  20,
                  20,
                  24 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Filter Discover',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppPalette.charcoal,
                      ),
                    ),
                    const SizedBox(height: 14),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Events'),
                      value: sections.contains(_DiscoverSection.events),
                      onChanged: (value) {
                        setModalState(() {
                          if (value == true) {
                            sections.add(_DiscoverSection.events);
                          } else {
                            sections.remove(_DiscoverSection.events);
                          }
                        });
                      },
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Historical Sights'),
                      value: sections.contains(_DiscoverSection.sights),
                      onChanged: (value) {
                        setModalState(() {
                          if (value == true) {
                            sections.add(_DiscoverSection.sights);
                          } else {
                            sections.remove(_DiscoverSection.sights);
                          }
                        });
                      },
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Food'),
                      value: sections.contains(_DiscoverSection.food),
                      onChanged: (value) {
                        setModalState(() {
                          if (value == true) {
                            sections.add(_DiscoverSection.food);
                          } else {
                            sections.remove(_DiscoverSection.food);
                          }
                        });
                      },
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Stadiums'),
                      value: sections.contains(_DiscoverSection.stadiums),
                      onChanged: (value) {
                        setModalState(() {
                          if (value == true) {
                            sections.add(_DiscoverSection.stadiums);
                          } else {
                            sections.remove(_DiscoverSection.stadiums);
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context, sections),
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
            );
          },
        );
      },
    );

    if (result != null && mounted) {
      setState(() {
        _enabledSections
          ..clear()
          ..addAll(result);
      });
    }
  }

  void _showInfo(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _openVisitorPortal() {
    Navigator.pushNamed(context, '/visitor/portal');
  }

  void _openVisitorLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const VisitorLoginScreen()),
    );
  }

  void _openVisitorSignUp() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const VisitorSignUpScreen()),
    );
  }

  void _openAttractions() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AttractionsScreen()),
    );
  }

  void _openCouncilEventDetails(Event event) {
    final dateTime = [event.date, event.time]
        .where((value) => value.trim().isNotEmpty)
        .join(' • ');
    final location = [event.venue, event.suburb]
        .where((value) => value.trim().isNotEmpty)
        .join(', ');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VisitorEventDetailScreen(
          event: {
            'id': event.id,
            'section': 'events',
            'title': event.title,
            'badge':
                event.categories.isNotEmpty ? event.categories.first : 'Event',
            'imageUrl': event.imageUrl,
            'dateTime': dateTime,
            'location': location,
            'price': '',
            'description': event.description,
            'culturalBackground': '',
            'aiAudio': event.aiAudio,
            'mapQuery': location,
            'webLink': '',
          },
        ),
      ),
    );
  }

  void _openFoodDetails(FoodPlace place) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FoodDetailScreen(
          title: place.name,
          description: place.snippet,
          location: place.suburb,
          cuisine: place.cuisine,
          imageUrl: place.imageUrl,
          categories: place.categories,
          rating: place.rating,
          badge: 'Food',
          mapQuery: place.mapQuery,
          aiAudio: place.aiAudio,
        ),
      ),
    );
  }

  void _openStadiumDetails(StadiumVenue stadium) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StadiumDetailScreen(
          title: stadium.name,
          description: stadium.description,
          location: stadium.location,
          imageUrl: stadium.imageUrl,
          categories: stadium.categories,
          badge: stadium.badge,
          dateTime: stadium.dateTime,
          price: stadium.price,
          mapQuery: stadium.mapQuery,
          webLink: stadium.webLink,
          aiAudio: stadium.aiAudio,
        ),
      ),
    );
  }

  Future<void> _logoutVisitor() async {
    await VisitorAuth.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredEvents = _councilEvents.where((item) {
      return _enabledSections.contains(_DiscoverSection.events) &&
          _matchesCategory(item.categories) &&
          _matchesSearch(
              [item.title, item.venue, item.suburb, item.description]);
    }).toList();

    final filteredSights = _historicalSights.where((item) {
      return _enabledSections.contains(_DiscoverSection.sights) &&
          _matchesCategory(item.categories) &&
          _matchesSearch([item.name, item.location, item.description]);
    }).toList();

    final filteredFood = _foodPlaces.where((item) {
      return _enabledSections.contains(_DiscoverSection.food) &&
          _matchesCategory(item.categories) &&
          _matchesSearch([item.name, item.cuisine, item.suburb, item.snippet]);
    }).toList();

    final filteredStadiums = _stadiums.where((item) {
      return _enabledSections.contains(_DiscoverSection.stadiums) &&
          _matchesCategory(item.categories) &&
          _matchesSearch([item.name, item.location, item.description]);
    }).toList();

    return Scaffold(
      backgroundColor: AppPalette.background,
      body: SafeArea(
        child: _buildTabBody(
          filteredEvents: filteredEvents,
          filteredSights: filteredSights,
          filteredFood: filteredFood,
          filteredStadiums: filteredStadiums,
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedTabIndex,
        onTap: (index) => setState(() => _selectedTabIndex = index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppPalette.surface,
        selectedItemColor: AppPalette.ochre,
        unselectedItemColor: AppPalette.deepBlue,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
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

  Widget _buildTabBody({
    required List<Event> filteredEvents,
    required List<HistoricalSight> filteredSights,
    required List<FoodPlace> filteredFood,
    required List<StadiumVenue> filteredStadiums,
  }) {
    if (_selectedTabIndex == 1) return _buildSavedTab();
    if (_selectedTabIndex == 2) return _buildProfileTab();

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppPalette.ochre),
      );
    }

    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded,
                  size: 44, color: AppPalette.mutedText),
              const SizedBox(height: 10),
              Text(
                _loadError!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppPalette.mutedText),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loadDiscoverData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppPalette.deepBlue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _DiscoverSearchBar(
          controller: _searchController,
          onFilterTap: _openFilterSheet,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _categoryChips.map((chip) {
            final selected = _selectedCategoryChips.contains(chip);
            return FilterChip(
              label: Text(chip),
              selected: selected,
              selectedColor: const Color(0x33D4A017),
              onSelected: (value) {
                setState(() {
                  if (value) {
                    _selectedCategoryChips.add(chip);
                  } else {
                    _selectedCategoryChips.remove(chip);
                  }
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        if (_enabledSections.contains(_DiscoverSection.events)) ...[
          const _SectionTitle('Brisbane City Council Events'),
          const SizedBox(height: 10),
          if (filteredEvents.isEmpty)
            const _EmptySection(
              'No matching council events. Try changing your search or filters.',
            )
          else
            SizedBox(
              height: 360,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: filteredEvents.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final event = filteredEvents[index];
                  return _CouncilEventCard(
                    event: event,
                    isSaved: _savedIds.contains(event.id),
                    onSaveTap: () => _toggleSaved(event.id),
                    onShareTap: () => _openCouncilEventDetails(event),
                  );
                },
              ),
            ),
          const SizedBox(height: 20),
        ],
        if (_enabledSections.contains(_DiscoverSection.sights)) ...[
          const _SectionTitle('Historical Sights in Brisbane'),
          const SizedBox(height: 10),
          if (filteredSights.isEmpty)
            const _EmptySection('No matching historical sights found.')
          else
            SizedBox(
              height: 330,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: filteredSights.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final sight = filteredSights[index];
                  return _HistoricalSightCard(
                    sight: sight,
                    isSaved: _savedIds.contains(sight.id),
                    onSaveTap: () => _toggleSaved(sight.id),
                    onLearnMoreTap: _openAttractions,
                  );
                },
              ),
            ),
          const SizedBox(height: 20),
        ],
        if (_enabledSections.contains(_DiscoverSection.food)) ...[
          const _SectionTitle('Authentic Brisbane Food'),
          const SizedBox(height: 10),
          if (filteredFood.isEmpty)
            const _EmptySection('No matching food places found.')
          else
            SizedBox(
              height: 340,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: filteredFood.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final food = filteredFood[index];
                  return _FoodPlaceCard(
                    place: food,
                    isSaved: _savedIds.contains(food.id),
                    onSaveTap: () => _toggleSaved(food.id),
                    onMapTap: () => _showInfo('View on map: ${food.mapQuery}'),
                    onDetailsTap: () => _openFoodDetails(food),
                  );
                },
              ),
            ),
          const SizedBox(height: 20),
        ],
        if (_enabledSections.contains(_DiscoverSection.stadiums)) ...[
          const _SectionTitle('Brisbane Stadiums & Event Venues'),
          const SizedBox(height: 10),
          if (filteredStadiums.isEmpty)
            const _EmptySection('No matching stadiums found.')
          else
            SizedBox(
              height: 330,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: filteredStadiums.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final stadium = filteredStadiums[index];
                  return _StadiumVenueCard(
                    stadium: stadium,
                    isSaved: _savedIds.contains(stadium.id),
                    onSaveTap: () => _toggleSaved(stadium.id),
                    onMapTap: () =>
                        _showInfo('View on map: ${stadium.mapQuery}'),
                    onDetailsTap: () => _openStadiumDetails(stadium),
                  );
                },
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildSavedTab() {
    final events =
        _councilEvents.where((e) => _savedIds.contains(e.id)).toList();
    final sights =
        _historicalSights.where((e) => _savedIds.contains(e.id)).toList();
    final foods = _foodPlaces.where((e) => _savedIds.contains(e.id)).toList();
    final stadiums = _stadiums.where((e) => _savedIds.contains(e.id)).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        const Text(
          'Saved',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: AppPalette.charcoal,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Your bookmarked Brisbane experiences',
          style: TextStyle(color: AppPalette.mutedText),
        ),
        const SizedBox(height: 16),
        if (events.isEmpty &&
            sights.isEmpty &&
            foods.isEmpty &&
            stadiums.isEmpty)
          const _EmptySection('No saved items yet. Tap a heart icon to save.'),
        ...events.map(
          (item) => _SavedCompactCard(
            title: item.title,
            subtitle: '${item.date} • ${item.venue}',
            icon: Icons.event_rounded,
            onRemoveTap: () => _toggleSaved(item.id),
          ),
        ),
        ...sights.map(
          (item) => _SavedCompactCard(
            title: item.name,
            subtitle: item.location,
            icon: Icons.museum_rounded,
            onRemoveTap: () => _toggleSaved(item.id),
          ),
        ),
        ...foods.map(
          (item) => _SavedCompactCard(
            title: item.name,
            subtitle: '${item.cuisine} • ${item.suburb}',
            icon: Icons.restaurant_rounded,
            onRemoveTap: () => _toggleSaved(item.id),
          ),
        ),
        ...stadiums.map(
          (item) => _SavedCompactCard(
            title: item.name,
            subtitle: item.location,
            icon: Icons.stadium_rounded,
            onRemoveTap: () => _toggleSaved(item.id),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileTab() {
    final visitor = VisitorAuth.currentVisitor;
    final isLoggedIn = visitor != null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        const Text(
          'Profile',
          style: TextStyle(
            fontSize: 28,
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
            title: Text(isLoggedIn ? visitor.name : 'Visitor Account'),
            subtitle: Text(
              isLoggedIn
                  ? visitor.email
                  : 'Sign in to personalize your experience',
            ),
          ),
        ),
        Card(
          color: AppPalette.surface,
          child: ListTile(
            leading: const Icon(Icons.dashboard_customize_outlined,
                color: AppPalette.deepBlue),
            title: const Text('Open Visitor Portal'),
            subtitle: const Text('Go to your main visitor dashboard'),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
            onTap: _openVisitorPortal,
          ),
        ),
        Card(
          color: AppPalette.surface,
          child: ListTile(
            leading: Icon(
              isLoggedIn ? Icons.logout_rounded : Icons.login_rounded,
              color: AppPalette.ochre,
            ),
            title: Text(isLoggedIn ? 'Logout' : 'Login'),
            subtitle: Text(
              isLoggedIn
                  ? 'Sign out and return to Welcome'
                  : 'Sign in to access personalized features',
            ),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
            onTap: isLoggedIn ? _logoutVisitor : _openVisitorLogin,
          ),
        ),
        if (!isLoggedIn)
          Card(
            color: AppPalette.surface,
            child: ListTile(
              leading: const Icon(Icons.app_registration_rounded,
                  color: AppPalette.gold),
              title: const Text('Create Visitor Account'),
              subtitle: const Text('Register a new visitor profile'),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
              onTap: _openVisitorSignUp,
            ),
          ),
      ],
    );
  }
}

class _DiscoverSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onFilterTap;

  const _DiscoverSearchBar({
    required this.controller,
    required this.onFilterTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppPalette.border),
        boxShadow: const [
          BoxShadow(
            color: AppPalette.cardShadow,
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: AppPalette.ochre),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'Find things to do in Brisbane',
                border: InputBorder.none,
              ),
            ),
          ),
          IconButton(
            onPressed: onFilterTap,
            icon: const Icon(Icons.tune_rounded, color: AppPalette.deepBlue),
            tooltip: 'Filter',
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppPalette.charcoal,
      ),
    );
  }
}

class _EmptySection extends StatelessWidget {
  final String message;

  const _EmptySection(this.message);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppPalette.border),
      ),
      child: Text(
        message,
        style: const TextStyle(color: AppPalette.mutedText),
      ),
    );
  }
}

class _CouncilEventCard extends StatelessWidget {
  final Event event;
  final bool isSaved;
  final VoidCallback onSaveTap;
  final VoidCallback onShareTap;

  const _CouncilEventCard({
    required this.event,
    required this.isSaved,
    required this.onSaveTap,
    required this.onShareTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 290,
      child: _BaseCard(
        imageUrl: event.imageUrl,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(event.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, color: AppPalette.charcoal)),
            const SizedBox(height: 6),
            Text('${event.date} • ${event.time}',
                style: const TextStyle(
                    fontSize: 12.5, color: AppPalette.deepBlue)),
            const SizedBox(height: 2),
            Text('${event.venue}, ${event.suburb}',
                style: const TextStyle(
                    fontSize: 12.5, color: AppPalette.mutedText)),
            const SizedBox(height: 8),
            Text(
              event.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppPalette.charcoal,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                TextButton(
                    onPressed: onShareTap, child: const Text('More Details')),
                const Spacer(),
                IconButton(
                  onPressed: onSaveTap,
                  icon: Icon(
                    isSaved
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: isSaved ? AppPalette.ochre : AppPalette.deepBlue,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoricalSightCard extends StatelessWidget {
  final HistoricalSight sight;
  final bool isSaved;
  final VoidCallback onSaveTap;
  final VoidCallback onLearnMoreTap;

  const _HistoricalSightCard({
    required this.sight,
    required this.isSaved,
    required this.onSaveTap,
    required this.onLearnMoreTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 290,
      child: _BaseCard(
        imageUrl: sight.imageUrl,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(sight.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, color: AppPalette.charcoal)),
            const SizedBox(height: 6),
            Text(sight.location,
                style: const TextStyle(
                    fontSize: 12.5, color: AppPalette.deepBlue)),
            const SizedBox(height: 8),
            Text(
              sight.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppPalette.charcoal,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                ElevatedButton(
                  onPressed: onLearnMoreTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppPalette.deepBlue,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Learn More'),
                ),
                const Spacer(),
                IconButton(
                  onPressed: onSaveTap,
                  icon: Icon(
                    isSaved
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: isSaved ? AppPalette.ochre : AppPalette.deepBlue,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FoodPlaceCard extends StatelessWidget {
  final FoodPlace place;
  final bool isSaved;
  final VoidCallback onSaveTap;
  final VoidCallback onMapTap;
  final VoidCallback onDetailsTap;

  const _FoodPlaceCard({
    required this.place,
    required this.isSaved,
    required this.onSaveTap,
    required this.onMapTap,
    required this.onDetailsTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      child: _BaseCard(
        imageUrl: place.imageUrl,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(place.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, color: AppPalette.charcoal)),
            const SizedBox(height: 6),
            Text('${place.cuisine} • ${place.suburb}',
                style: const TextStyle(
                    fontSize: 12.5, color: AppPalette.deepBlue)),
            const SizedBox(height: 4),
            if (place.rating > 0) ...[
              Row(
                children: [
                  const Icon(Icons.star_rounded,
                      size: 16, color: AppPalette.gold),
                  const SizedBox(width: 4),
                  Text(place.rating.toStringAsFixed(1),
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppPalette.charcoal)),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Text(
              place.snippet,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppPalette.charcoal,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                OutlinedButton(
                    onPressed: onMapTap, child: const Text('View on Map')),
                ElevatedButton(
                  onPressed: onDetailsTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppPalette.ochre,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('More Details'),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                onPressed: onSaveTap,
                icon: Icon(
                  isSaved
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: isSaved ? AppPalette.ochre : AppPalette.deepBlue,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StadiumVenueCard extends StatelessWidget {
  final StadiumVenue stadium;
  final bool isSaved;
  final VoidCallback onSaveTap;
  final VoidCallback onMapTap;
  final VoidCallback onDetailsTap;

  const _StadiumVenueCard({
    required this.stadium,
    required this.isSaved,
    required this.onSaveTap,
    required this.onMapTap,
    required this.onDetailsTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      child: _BaseCard(
        imageUrl: stadium.imageUrl,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(stadium.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, color: AppPalette.charcoal)),
            const SizedBox(height: 6),
            Text(stadium.location,
                style: const TextStyle(
                    fontSize: 12.5, color: AppPalette.deepBlue)),
            const SizedBox(height: 8),
            Text(
              stadium.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppPalette.charcoal,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                OutlinedButton(
                    onPressed: onMapTap, child: const Text('View on Map')),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: onDetailsTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppPalette.deepBlue,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('More Details'),
                ),
                const Spacer(),
                IconButton(
                  onPressed: onSaveTap,
                  icon: Icon(
                    isSaved
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: isSaved ? AppPalette.ochre : AppPalette.deepBlue,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BaseCard extends StatelessWidget {
  final String imageUrl;
  final Widget child;

  const _BaseCard({
    required this.imageUrl,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppPalette.border),
        boxShadow: const [
          BoxShadow(
            color: AppPalette.cardShadow,
            blurRadius: 14,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
            ),
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              height: 130,
              width: double.infinity,
              fit: BoxFit.cover,
              placeholder: (context, _) => Container(
                height: 130,
                color: AppPalette.surfaceAlt,
                alignment: Alignment.center,
                child: const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppPalette.deepBlue,
                  ),
                ),
              ),
              errorWidget: (context, _, __) => Container(
                height: 130,
                color: AppPalette.surfaceAlt,
                alignment: Alignment.center,
                child: const Icon(
                  Icons.image_not_supported_rounded,
                  color: AppPalette.mutedText,
                  size: 28,
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SingleChildScrollView(
                child: child,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SavedCompactCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onRemoveTap;

  const _SavedCompactCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onRemoveTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        color: AppPalette.surface,
        child: ListTile(
          leading: Icon(icon, color: AppPalette.deepBlue),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: IconButton(
            onPressed: onRemoveTap,
            icon: const Icon(Icons.favorite_rounded, color: AppPalette.ochre),
          ),
        ),
      ),
    );
  }
}
// test change for Jira connection
