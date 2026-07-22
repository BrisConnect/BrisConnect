import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:brisconnect/auth/visitor_auth.dart';
import 'package:brisconnect/services/restaurant_view_tracker_service.dart';
import 'package:brisconnect/services/business_profile_service.dart';
import 'package:brisconnect/models/business.dart';
import 'package:brisconnect/screens/top_restaurants_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedNearby = 2; // Default 5 km
  String _selectedCategory = '';
  String _selectedPrice = ''; // Filter by price
  String _selectedRating = ''; // Filter by rating
  bool _sortByViews = false; // Sort by views toggle
  final TextEditingController _searchController = TextEditingController();
  late final RestaurantViewTrackerService _viewTrackerService =
      RestaurantViewTrackerService();
  final Map<String, int> _localViewCounts = {}; // Live tap counter

  final List<String> _foodCategories = [
    'Burgers',
    'Pizza',
    'Cafe',
    'BBQ',
    'Asian',
    'Noodles',
    'Bakery',
    'Japanese'
  ];

  final List<String> _priceFilters = ['\$', '\$\$', '\$\$\$'];
  final List<String> _ratingFilters = ['4+', '4.5+', '4.8+'];

  List<RestaurantCard> _convertFirestoreToRestaurantCards(List<QueryDocumentSnapshot> docs) {
    return docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return RestaurantCard(
        id: doc.id,
        image: data['imageUrl'] ?? 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=500',
        name: data['name'] ?? 'Unknown Restaurant',
        rating: (data['rating'] ?? 4.0).toDouble(),
        cuisine: (data['cuisineTypes'] is List && (data['cuisineTypes'] as List).isNotEmpty)
            ? (data['cuisineTypes'] as List).first.toString()
            : 'Dining',
        distance: '1.5', // Default distance
        suburb: data['address']?.toString().split(',').last.trim() ?? 'Brisbane CBD',
        isOpen: data['openNow'] ?? true,
        buzzScore: ((data['rating'] ?? 4.0) * 20).toInt().clamp(0, 100),
        priceRange: data['priceRange'] ?? '\$\$',
        views: data['views'] ?? 0,
      );
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0F1A),
        elevation: 1,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_rounded,
            color: Color(0xFFFF7A1A),
            size: 28,
          ),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Go back',
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              // Header with greeting & profile
              _buildHeader(),

              const SizedBox(height: 24),

              // Search bar
              _buildSearchBar(),

              const SizedBox(height: 16),

              // Filter chips (price, rating)
              _buildFilterChips(),

              const SizedBox(height: 20),

              // Category chips
              _buildCategoryChips(),

              const SizedBox(height: 24),

              // Trending banner
              _buildTrendingBanner(),

              const SizedBox(height: 28),

              // Statistics row
              _buildStatisticsRow(),

              const SizedBox(height: 28),

              // Top Restaurants Button
              _buildTopRestaurantsButton(),

              const SizedBox(height: 28),

              // Trending section
              if (_sortByViews) ...[
                _buildTrendingRestaurantsSection(),
                const SizedBox(height: 32),
              ],

              // Recommended section
              _buildRecommendedSection(),

              const SizedBox(height: 32),

              // Nearby filters
              _buildNearbyFilters(),

              const SizedBox(height: 28),

              // AI Assistant card
              _buildAIAssistantCard(),

              const SizedBox(height: 100), // Space for bottom nav
            ],
          ),
        ),
      ),
      floatingActionButton: _buildFloatingAIAssistant(),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  String _getTimeBasedGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning';
    } else if (hour < 18) {
      return 'Good Afternoon';
    } else {
      return 'Good Evening';
    }
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Greeting section
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '👋 ${_getTimeBasedGreeting()},',
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF7A8FA6),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                VisitorAuth.currentVisitor?.name ?? 'Visitor',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                "Discover Brisbane's Best Local Food",
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF7A8FA6),
                ),
              ),
            ],
          ),

          // Profile image & notification
          Row(
            children: [
              // Notification bell
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1F2E),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF2A2F3F),
                    width: 1,
                  ),
                ),
                child: IconButton(
                  icon: const Icon(
                    Icons.notifications_rounded,
                    color: Color(0xFF7A8FA6),
                    size: 20,
                  ),
                  onPressed: () {},
                ),
              ),
              const SizedBox(width: 12),

              // Profile image
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF1C1F2E),
                  border: Border.all(
                    color: const Color(0xFF2A2F3F),
                    width: 1,
                  ),
                ),
                child: ClipOval(
                  child: CachedNetworkImage(
                    imageUrl:
                        'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=100',
                    fit: BoxFit.cover,
                    placeholder: (context, url) =>
                        const Icon(Icons.person, color: Color(0xFF7A8FA6)),
                    errorWidget: (context, url, error) =>
                        const Icon(Icons.person, color: Color(0xFF7A8FA6)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1C1F2E),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFF2A2F3F),
                  width: 1,
                ),
              ),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Search food, cafes or suburbs…',
                  hintStyle: TextStyle(
                    color: Color(0xFF7A8FA6),
                    fontSize: 14,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: Color(0xFF7A8FA6),
                    size: 20,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
                cursorColor: const Color(0xFFFF7A1A),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Filter button
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF1C1F2E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF2A2F3F),
                width: 1,
              ),
            ),
            child: IconButton(
              icon: const Icon(
                Icons.tune_rounded,
                color: Color(0xFF7A8FA6),
                size: 20,
              ),
              onPressed: () {},
            ),
          ),
          const SizedBox(width: 12),
          // Sort by popularity button
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _sortByViews
                  ? const Color(0xFFFF7A1A)
                  : const Color(0xFF1C1F2E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _sortByViews
                    ? const Color(0xFFFF7A1A)
                    : const Color(0xFF2A2F3F),
                width: 1,
              ),
            ),
            child: IconButton(
              icon: Icon(
                Icons.trending_up_rounded,
                color:
                    _sortByViews ? Colors.white : const Color(0xFF7A8FA6),
                size: 20,
              ),
              onPressed: () {
                setState(() {
                  _sortByViews = !_sortByViews;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChips() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: _foodCategories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = _foodCategories[index];
          final isSelected = _selectedCategory == category;

          return GestureDetector(
            onTap: () => setState(
              () => _selectedCategory =
                  isSelected ? '' : category,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFFF7A1A)
                    : const Color(0xFF1C1F2E),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFFFF7A1A)
                      : const Color(0xFF2A2F3F),
                  width: 1,
                ),
              ),
              child: Center(
                child: Text(
                  category,
                  style: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFF7A8FA6),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterChips() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Price filter
            Wrap(
              spacing: 8,
              children: _priceFilters.map((price) {
                final isSelected = _selectedPrice == price;
                return GestureDetector(
                  onTap: () => setState(
                    () => _selectedPrice = isSelected ? '' : price,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFFF7A1A)
                          : const Color(0xFF1C1F2E),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFFFF7A1A)
                            : const Color(0xFF2A2F3F),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      price,
                      style: TextStyle(
                        color: isSelected ? Colors.white : const Color(0xFF7A8FA6),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(width: 12),
            // Rating filter
            Wrap(
              spacing: 8,
              children: _ratingFilters.map((rating) {
                final isSelected = _selectedRating == rating;
                return GestureDetector(
                  onTap: () => setState(
                    () => _selectedRating = isSelected ? '' : rating,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFFF7A1A)
                          : const Color(0xFF1C1F2E),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFFFF7A1A)
                            : const Color(0xFF2A2F3F),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star, size: 12, color: Colors.amber),
                        const SizedBox(width: 4),
                        Text(
                          rating,
                          style: TextStyle(
                            color: isSelected ? Colors.white : const Color(0xFF7A8FA6),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendingBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFF7A1A),
              Color(0xFFE85C0D),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF7A1A).withOpacity(0.4),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.all(24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '🔥 Trending This Week',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Local BBQ Festival',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '20% OFF',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Explore Now',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendedSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _sortByViews ? 'Popular by Views' : 'Recommended for you',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _sortByViews
                        ? 'Sorted by popularity this week'
                        : 'Based on your likes: BBQ, Italian, Cafe',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF7A8FA6),
                    ),
                  ),
                ],
              ),
              Text(
                'See all',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFFF7A1A),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('food_businesses')
              .orderBy(_sortByViews ? 'views' : 'rating', descending: true)
              .limit(20)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return SizedBox(
                height: 280,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF7A1A)),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Loading restaurants...',
                        style: const TextStyle(
                          color: Color(0xFF7A8FA6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (snapshot.hasError) {
              return SizedBox(
                height: 280,
                child: Center(
                  child: Text(
                    'Error loading restaurants',
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              );
            }

            final docs = snapshot.data?.docs ?? [];
            final restaurants = _convertFirestoreToRestaurantCards(docs);

            if (restaurants.isEmpty) {
              return SizedBox(
                height: 280,
                child: Center(
                  child: Text(
                    'No restaurants found',
                    style: const TextStyle(
                      color: Color(0xFF7A8FA6),
                      fontSize: 12,
                    ),
                  ),
                ),
              );
            }

            return SizedBox(
              height: 280,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: restaurants.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) =>
                    _buildRestaurantCard(restaurants[index]),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildRestaurantCard(RestaurantCard restaurant) {
    return GestureDetector(
      onTap: () {
        // Track the view and increment local count
        _viewTrackerService.trackRestaurantView(restaurant.id);
        setState(() {
          _localViewCounts[restaurant.id] =
              (_localViewCounts[restaurant.id] ?? 0) + 1;
        });

        // Show feedback
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('👁 View recorded for ${restaurant.name}'),
            duration: const Duration(milliseconds: 800),
            backgroundColor: const Color(0xFF1C1F2E),
          ),
        );
      },
      child: Container(
        width: 240,
        decoration: BoxDecoration(
          color: const Color(0xFF1C1F2E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF2A2F3F),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          // Image
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(16)),
            child: Stack(
              children: [
                CachedNetworkImage(
                  imageUrl: restaurant.image,
                  height: 140,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    height: 140,
                    color: const Color(0xFF2A2F3F),
                  ),
                  errorWidget: (context, url, error) => Container(
                    height: 140,
                    color: const Color(0xFF2A2F3F),
                  ),
                ),
                // Save button
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.favorite_border,
                      color: Color(0xFFFF7A1A),
                      size: 18,
                    ),
                  ),
                ),
                // View count badge
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.visibility,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${restaurant.views + (_localViewCounts[restaurant.id] ?? 0)}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Hot badge
                if (restaurant.buzzScore > 80)
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        children: [
                          Text(
                            '🔥 ',
                            style: TextStyle(fontSize: 11),
                          ),
                          Text(
                            'HOT',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name
                Text(
                  restaurant.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),

                // Rating & Reviews count
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: Color(0xFFFFB900),
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${restaurant.rating}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          '(310)',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF7A8FA6),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Cuisine
                Text(
                  '${restaurant.cuisine} • ${restaurant.cuisine.contains('Dinner') ? 'Dinner' : 'Breakfast'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF7A8FA6),
                  ),
                ),
                const SizedBox(height: 6),

                // Distance & Suburb
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_rounded,
                      size: 12,
                      color: Color(0xFF7A8FA6),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${restaurant.distance} km • ${restaurant.suburb}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF7A8FA6),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Open status & Buzz score & Price
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          size: 12,
                          color: Color(0xFF00D084),
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Open Now',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF00D084),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      restaurant.priceRange,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF7A8FA6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '🔥 Buzz ${restaurant.buzzScore}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFFF7A1A),
                  ),
                ),
              ],
            ),
          ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _StatCard(
              value: '1,420+',
              label: 'Local Businesses',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatCard(
              value: '250+',
              label: 'Trending Today',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatCard(
              value: '100+',
              label: 'Events This Week',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopRestaurantsButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const TopRestaurantsScreen(),
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF7A1A), Color(0xFFE85C0D)],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF7A1A).withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🔥 Trending Analytics',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'View top restaurants & insights',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
              Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrendingRestaurantsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Trending by Views',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Sorted by popularity this week',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF7A8FA6),
                    ),
                  ),
                ],
              ),
              Text(
                'See all',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFFF7A1A),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        StreamBuilder<List<Business>>(
          stream: BusinessProfileService().getTrendingBusinessesStream(limit: 20),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return SizedBox(
                height: 280,
                child: Center(
                  child: const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF7A1A)),
                  ),
                ),
              );
            }

            if (snapshot.hasError || !snapshot.hasData) {
              return const SizedBox(height: 280);
            }

            final businesses = snapshot.data ?? [];
            if (businesses.isEmpty) {
              return const SizedBox(
                height: 280,
                child: Center(
                  child: Text(
                    'No trending businesses yet',
                    style: TextStyle(color: Color(0xFF7A8FA6)),
                  ),
                ),
              );
            }

            return SizedBox(
              height: 280,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: businesses.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) =>
                    _buildTrendingBusinessCard(businesses[index]),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildTrendingBusinessCard(Business business) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).pushNamed(
          '/business/view',
          arguments: business.id,
        );
      },
      child: Container(
        width: 220,
        decoration: BoxDecoration(
          color: const Color(0xFF1C1F2E),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: CachedNetworkImage(
                imageUrl: business.logoUrl ?? business.coverImageUrl ??
                    'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=500',
                height: 140,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  color: const Color(0xFF2A2F3F),
                  child: const Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (_, __, ___) => Container(
                  color: const Color(0xFF2A2F3F),
                  child: const Icon(Icons.restaurant, color: Colors.white54),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (business.isTrending) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '🔥 TRENDING',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Expanded(
                        child: Text(
                          business.businessName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    business.category,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF7A8FA6)),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.flash_on, color: Colors.orange, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        '${business.buzzScore.toInt()} Buzz',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNearbyFilters() {
    final nearbyOptions = ['1 km', '2 km', '5 km', '10 km+'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: const Text(
            'Nearby you',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: List.generate(
              nearbyOptions.length,
              (index) {
                final isSelected = _selectedNearby == index;
                return Expanded(
                  child: GestureDetector(
                    onTap: () =>
                        setState(() => _selectedNearby = index),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      margin: EdgeInsets.only(
                        right: index < nearbyOptions.length - 1 ? 8 : 0,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFFF7A1A)
                            : const Color(0xFF1C1F2E),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFFFF7A1A)
                              : const Color(0xFF2A2F3F),
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          nearbyOptions[index],
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFF7A8FA6),
                          ),
                        ),
                      ),
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

  Widget _buildAIAssistantCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF1C1F2E),
              const Color(0xFF2A2F3F).withOpacity(0.6),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF2A2F3F),
            width: 1,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFF0D0F1A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFFF7A1A),
                  width: 1.5,
                ),
              ),
              child: const Icon(
                Icons.smart_toy_rounded,
                color: Color(0xFFFF7A1A),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Need help?',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Tap to chat with our AI',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF7A8FA6),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_rounded,
              color: Color(0xFF7A8FA6),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingAIAssistant() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF7A1A), Color(0xFFE85C0D)],
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF7A1A).withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: FloatingActionButton(
        onPressed: () {},
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: const Icon(
          Icons.smart_toy_rounded,
          size: 28,
        ),
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1F2E),
        border: Border(
          top: BorderSide(
            color: const Color(0xFF2A2F3F),
            width: 1,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(Icons.home_rounded, 'Home', 0),
            _buildNavItem(Icons.map_rounded, 'Map', 1),
            // Center add button (larger)
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF7A1A), Color(0xFFE85C0D)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF7A1A).withOpacity(0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {},
                  borderRadius: BorderRadius.circular(30),
                  child: const Icon(
                    Icons.add_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
            ),
            _buildNavItem(Icons.bookmark_rounded, 'Saved', 2),
            _buildNavItem(Icons.person_rounded, 'Profile', 3),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: const Color(0xFF7A8FA6), size: 24),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Color(0xFF7A8FA6),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;

  const _StatCard({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1F2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF2A2F3F),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFFFF7A1A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF7A8FA6),
            ),
          ),
        ],
      ),
    );
  }
}

class RestaurantCard {
  final String id;
  final String image;
  final String name;
  final double rating;
  final String cuisine;
  final String distance;
  final String suburb;
  final bool isOpen;
  final int buzzScore;
  final String priceRange;
  final int views;

  RestaurantCard({
    required this.id,
    required this.image,
    required this.name,
    required this.rating,
    required this.cuisine,
    required this.distance,
    required this.suburb,
    required this.isOpen,
    required this.buzzScore,
    required this.priceRange,
    required this.views,
  });
}
