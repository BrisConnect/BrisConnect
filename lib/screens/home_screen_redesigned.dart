import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:brisconnect/auth/visitor_auth.dart';

class HomeScreenRedesigned extends StatefulWidget {
  const HomeScreenRedesigned({super.key});

  @override
  State<HomeScreenRedesigned> createState() => _HomeScreenRedesignedState();
}

class _HomeScreenRedesignedState extends State<HomeScreenRedesigned> {
  int _selectedNearby = 2; // Default 5 km
  String _selectedCategory = '';
  final TextEditingController _searchController = TextEditingController();

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

  final List<RestaurantCard> _restaurants = [
    RestaurantCard(
      image:
          'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=500',
      name: 'Urban Kitchen',
      rating: 4.8,
      cuisine: 'Modern Australian',
      distance: '0.5',
      suburb: 'Fortitude Valley',
      isOpen: true,
      buzzScore: 92,
      priceRange: '\$\$\$',
    ),
    RestaurantCard(
      image:
          'https://images.unsplash.com/photo-1555939594-58d7cb561404?w=500',
      name: 'Spice Route',
      rating: 4.6,
      cuisine: 'Asian Fusion',
      distance: '1.2',
      suburb: 'CBD',
      isOpen: true,
      buzzScore: 87,
      priceRange: '\$\$',
    ),
    RestaurantCard(
      image:
          'https://images.unsplash.com/photo-1600565193566-f57f4b74f2e1?w=500',
      name: 'Burger Haven',
      rating: 4.5,
      cuisine: 'American',
      distance: '0.8',
      suburb: 'South Bank',
      isOpen: true,
      buzzScore: 85,
      priceRange: '\$\$',
    ),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0F1A),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              // Header with greeting & profile
              _buildHeader(),

              const SizedBox(height: 24),

              // Search bar & filter
              _buildSearchBar(),

              const SizedBox(height: 20),

              // Food category chips
              _buildCategoryChips(),

              const SizedBox(height: 28),

              // Trending banner
              _buildTrendingBanner(),

              const SizedBox(height: 28),

              // Statistics row
              _buildStatisticsRow(),

              const SizedBox(height: 32),

              // Recommended for you section
              _buildRecommendedSection(),

              const SizedBox(height: 28),

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
                '👋 Good Morning,',
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
                "Find Brisbane's hidden food gems.",
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
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0x1AFF7A1A),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFFFF7A1A),
                width: 1.5,
              ),
            ),
            child: const Icon(
              Icons.tune_rounded,
              color: Color(0xFFFF7A1A),
              size: 20,
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

  Widget _buildRecommendedSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: const Text(
            'Recommended for you',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 280,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: _restaurants.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) =>
                _buildRestaurantCard(_restaurants[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildRestaurantCard(RestaurantCard restaurant) {
    return Container(
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
                // Open status
                if (restaurant.isOpen)
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Open',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
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

                // Rating & Cuisine
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
                          restaurant.rating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      restaurant.priceRange,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF7A8FA6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Cuisine
                Text(
                  restaurant.cuisine,
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

                // Buzz score
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '🔥 ${restaurant.buzzScore} Buzz',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFFF7A1A),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
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
  final String image;
  final String name;
  final double rating;
  final String cuisine;
  final String distance;
  final String suburb;
  final bool isOpen;
  final int buzzScore;
  final String priceRange;

  RestaurantCard({
    required this.image,
    required this.name,
    required this.rating,
    required this.cuisine,
    required this.distance,
    required this.suburb,
    required this.isOpen,
    required this.buzzScore,
    required this.priceRange,
  });
}
