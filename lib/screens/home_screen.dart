import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:brisconnect/auth/visitor_auth.dart';
import 'package:brisconnect/screens/top_restaurants_screen.dart';
import 'package:brisconnect/services/restaurant_view_tracker_service.dart';
import 'package:brisconnect/services/weather_service.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/widgets/banner_widget.dart';
import 'package:brisconnect/widgets/business_card.dart';
import 'package:brisconnect/widgets/category_chip.dart';

/// Visitor home screen focused on discovering local food businesses.
///
/// Brisbane appears only as a subtle skyline backdrop; the restaurant cards
/// are the visual hero. Uses a light, modern design with [CustomScrollView]
/// and slivers for smooth scrolling and responsiveness.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  final RestaurantViewTrackerService _viewTrackerService =
      RestaurantViewTrackerService();
  final WeatherService _weatherService = WeatherService();

  String _selectedCategory = '';
  BrisbaneWeather? _weather;
  bool _weatherLoading = false;

  final List<String> _foodCategories = [
    'All',
    'Burgers',
    'Pizza',
    'Cafe',
    'BBQ',
    'Asian',
    'Noodles',
    'Bakery',
    'Japanese',
  ];

  @override
  void initState() {
    super.initState();
    _loadWeather();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _weatherService.dispose();
    super.dispose();
  }

  Future<void> _loadWeather() async {
    setState(() => _weatherLoading = true);
    try {
      final weather = await _weatherService.fetchBrisbaneWeather();
      if (mounted) {
        setState(() {
          _weather = weather;
          _weatherLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _weatherLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.background,
      body: SafeArea(
        child: CustomScrollView(
          physics: const ClampingScrollPhysics(),
          slivers: [
            _buildAppBarSliver(),
            _buildSearchSliver(),
            _buildCategorySliver(),
            _buildBannerSliver(),
            _buildRecommendedHeaderSliver(),
            _buildRecommendedListSliver(),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBarSliver() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _greetingForHour(),
                    style: TextStyle(
                      fontSize: 14,
                      color: AppPalette.mutedText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    VisitorAuth.currentVisitor?.name ?? 'Visitor',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: AppPalette.charcoal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Row(
              children: [
                _IconButton(
                  icon: Icons.notifications_outlined,
                  onTap: () {},
                ),
                const SizedBox(width: 10),
                _ProfileAvatar(
                  imageUrl: VisitorAuth.currentVisitor?.profileImageUrl ?? '',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchSliver() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppPalette.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search food, cafes or suburbs…',
                    hintStyle: TextStyle(
                      color: AppPalette.mutedText.withValues(alpha: 0.7),
                      fontSize: 14,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: AppPalette.mutedText.withValues(alpha: 0.7),
                      size: 20,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  style: const TextStyle(
                    color: AppPalette.charcoal,
                    fontSize: 14,
                  ),
                  cursorColor: AppPalette.ochre,
                ),
              ),
            ),
            const SizedBox(width: 12),
            _IconButton(
              icon: Icons.tune_rounded,
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySliver() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(top: 20),
        child: SizedBox(
          height: 44,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            itemCount: _foodCategories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final category = _foodCategories[index];
              final isSelected = _selectedCategory == category ||
                  (category == 'All' && _selectedCategory.isEmpty);
              return CategoryChip(
                label: category,
                isSelected: isSelected,
                onTap: () => setState(() {
                  _selectedCategory =
                      (category == 'All' || isSelected) ? '' : category;
                }),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBannerSliver() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(top: 20),
        child: BrisbaneBannerWidget(
          height: _bannerHeight(context),
          weather: _weather,
          isWeatherLoading: _weatherLoading,
        ),
      ),
    );
  }

  Widget _buildRecommendedHeaderSliver() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recommended For You',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppPalette.charcoal,
              ),
            ),
            Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const TopRestaurantsScreen(),
                    ),
                  );
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Text(
                    'See All',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppPalette.ochre,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendedListSliver() {
    return StreamBuilder<List<_HomeBusiness>>(
      stream: _recommendedBusinessesStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const SliverToBoxAdapter(
            child: SizedBox(
              height: 380,
              child: Center(
                child: CircularProgressIndicator(color: AppPalette.ochre),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return const SliverToBoxAdapter(
            child: SizedBox(
              height: 380,
              child: Center(
                child: Text(
                  'Could not load restaurants',
                  style: TextStyle(color: AppPalette.mutedText),
                ),
              ),
            ),
          );
        }

        final businesses = snapshot.data ?? [];
        if (businesses.isEmpty) {
          return const SliverToBoxAdapter(
            child: SizedBox(
              height: 380,
              child: Center(
                child: Text(
                  'No restaurants found',
                  style: TextStyle(color: AppPalette.mutedText),
                ),
              ),
            ),
          );
        }

        return SliverToBoxAdapter(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 900;

              if (isWide) {
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: Wrap(
                      spacing: 20,
                      runSpacing: 24,
                      children: businesses.map((b) {
                        return BusinessCard(
                          id: b.id,
                          imageUrl: b.imageUrl,
                          name: b.name,
                          rating: b.rating,
                          cuisine: b.cuisine,
                          suburb: b.suburb,
                          isOpen: b.isOpen,
                          priceRange: b.priceRange,
                          onTap: () => _openBusiness(context, b.id),
                        );
                      }).toList(),
                    ),
                  ),
                );
              }

              return SizedBox(
                height: 420,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  scrollDirection: Axis.horizontal,
                  physics: const ClampingScrollPhysics(),
                  itemCount: businesses.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 16),
                  itemBuilder: (context, index) {
                    final b = businesses[index];
                    return BusinessCard(
                      id: b.id,
                      imageUrl: b.imageUrl,
                      name: b.name,
                      rating: b.rating,
                      cuisine: b.cuisine,
                      suburb: b.suburb,
                      isOpen: b.isOpen,
                      priceRange: b.priceRange,
                      onTap: () => _openBusiness(context, b.id),
                    );
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }

  Stream<List<_HomeBusiness>> _recommendedBusinessesStream() {
    final canonical = FirebaseFirestore.instance
        .collection('businesses')
        .orderBy('rating', descending: true)
        .limit(20)
        .snapshots();
    final legacy = FirebaseFirestore.instance
        .collection('food_businesses')
        .orderBy('rating', descending: true)
        .limit(20)
        .snapshots();

    return _combineLatest2(
      canonical,
      legacy,
      (QuerySnapshot canonicalSnap, QuerySnapshot legacySnap) {
        final merged = <String, _HomeBusiness>{};

        for (final doc in canonicalSnap.docs) {
          final data = doc.data() as Map<String, dynamic>;
          if (data['deletedAt'] != null) continue;
          if (data['isActive'] == false) continue;
          merged[doc.id] = _snapshotToBusiness(doc.id, data);
        }

        for (final doc in legacySnap.docs) {
          if (merged.containsKey(doc.id)) continue;
          final data = doc.data() as Map<String, dynamic>;
          merged[doc.id] = _snapshotToBusiness(doc.id, data);
        }

        var businesses = merged.values.toList();
        businesses.sort((a, b) => b.rating.compareTo(a.rating));

        final selected = _selectedCategory;
        if (selected.isNotEmpty && selected != 'All') {
          businesses = businesses.where((b) {
            return b.cuisine.toLowerCase().contains(selected.toLowerCase());
          }).toList();
        }

        return businesses.take(20).toList();
      },
    );
  }

  _HomeBusiness _snapshotToBusiness(String id, Map<String, dynamic> data) {
    final rawCategories = data['cuisineTypes'];
    final categoryFallback = data['category']?.toString();
    final cuisine = (rawCategories is List && rawCategories.isNotEmpty)
        ? rawCategories.first.toString()
        : (categoryFallback?.isNotEmpty == true ? categoryFallback! : 'Dining');

    final rawAddress = data['address']?.toString() ?? '';
    final suburb = rawAddress.split(',').last.trim();

    return _HomeBusiness(
      id: id,
      imageUrl: data['coverImageUrl'] ??
          data['logoUrl'] ??
          data['imageUrl'] ??
          '',
      name: data['businessName'] ?? data['name'] ?? 'Unknown Restaurant',
      rating: ((data['rating'] ?? data['averageRating']) ?? 4.0).toDouble(),
      cuisine: cuisine,
      suburb: suburb.isNotEmpty ? suburb : 'Brisbane CBD',
      isOpen: data['openNow'] ?? true,
      priceRange: data['priceRange'] ?? '\$\$',
    );
  }

  void _openBusiness(BuildContext context, String businessId) {
    _viewTrackerService.trackRestaurantView(businessId);
    Navigator.of(context).pushNamed('/business/view', arguments: businessId);
  }

  String _greetingForHour() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  double _bannerHeight(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 1200) return 190;
    if (width >= 900) return 185;
    return 180;
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
}

class _HomeBusiness {
  final String id;
  final String imageUrl;
  final String name;
  final double rating;
  final String cuisine;
  final String suburb;
  final bool isOpen;
  final String priceRange;

  _HomeBusiness({
    required this.id,
    required this.imageUrl,
    required this.name,
    required this.rating,
    required this.cuisine,
    required this.suburb,
    required this.isOpen,
    required this.priceRange,
  });
}

class _IconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _IconButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppPalette.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            icon,
            color: AppPalette.charcoal,
            size: 22,
          ),
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  final String imageUrl;

  const _ProfileAvatar({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppPalette.surfaceAlt,
        border: Border.all(color: AppPalette.border),
      ),
      child: ClipOval(
        child: imageUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _fallback(),
              )
            : _fallback(),
      ),
    );
  }

  Widget _fallback() {
    return const Center(
      child: Icon(
        Icons.person_outline_rounded,
        color: AppPalette.mutedText,
        size: 24,
      ),
    );
  }
}
