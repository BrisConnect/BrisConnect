import 'package:flutter/material.dart';
import 'package:brisconnect/services/business_profile_service.dart';
import 'package:brisconnect/models/business.dart';

class TopRestaurantsScreen extends StatefulWidget {
  const TopRestaurantsScreen({super.key});

  @override
  State<TopRestaurantsScreen> createState() => _TopRestaurantsScreenState();
}

class _TopRestaurantsScreenState extends State<TopRestaurantsScreen> {
  final BusinessProfileService _businessService = BusinessProfileService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C1F2E),
        elevation: 0,
        title: const Text(
          '🔥 Trending Businesses',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<List<Business>>(
        stream: _businessService.getTrendingBusinessesStream(limit: 50),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFFF7A1A),
              ),
            );
          }

          final businesses = snapshot.data ?? [];
          if (businesses.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.restaurant_rounded,
                    size: 64,
                    color: Color(0xFF2A2F3F),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No trending businesses yet',
                    style: TextStyle(
                      color: Color(0xFF7A8FA6),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              // Stream refreshes automatically; this gives user pull-to-refresh feedback.
              await Future.delayed(const Duration(milliseconds: 500));
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  _buildAnalyticsSummary(businesses),
                  const SizedBox(height: 24),
                  _buildRestaurantsList(businesses),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAnalyticsSummary(List<Business> businesses) {
    int totalViews = 0;
    for (final business in businesses) {
      totalViews += business.viewCount;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _AnalyticsCard(
              icon: Icons.visibility_rounded,
              label: 'Total Views',
              value: '$totalViews',
              color: const Color(0xFFFF7A1A),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _AnalyticsCard(
              icon: Icons.restaurant_rounded,
              label: 'Trending',
              value: '${businesses.length}',
              color: const Color(0xFF00D084),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _AnalyticsCard(
              icon: Icons.trending_up_rounded,
              label: 'Avg. Buzz',
              value: businesses.isNotEmpty
                  ? (businesses.fold<double>(0, (sum, b) => sum + b.buzzScore) / businesses.length)
                      .toStringAsFixed(0)
                  : '0',
              color: const Color(0xFF7B61FF),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRestaurantsList(List<Business> businesses) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Trending This Week',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Column(
            children: List.generate(
              businesses.length,
              (index) => _buildRestaurantTile(
                businesses[index],
                index + 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRestaurantTile(Business business, int rank) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).pushNamed(
          '/business/view',
          arguments: business.id,
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1F2E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF2A2F3F),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Rank badge
              Container(
                width: 50,
                height: 50,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFFF7A1A), Color(0xFFE85C0D)],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '#$rank',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Restaurant info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      business.businessName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 12,
                          color: Color(0xFFFFB900),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${(business.rating ?? 0).toStringAsFixed(1)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          business.category,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF7A8FA6),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      business.address.split(',').last.trim(),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF7A8FA6),
                      ),
                    ),
                  ],
                ),
              ),
              // Buzz score
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.flash_on,
                        size: 16,
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${business.buzzScore.toInt()}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFFF7A1A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2F3F),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      '🔥 Trending',
                      style: TextStyle(
                        fontSize: 10,
                        color: Color(0xFF00D084),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnalyticsCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _AnalyticsCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1F2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF2A2F3F),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF7A8FA6),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
