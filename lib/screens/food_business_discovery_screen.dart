import 'package:flutter/material.dart';
import 'package:brisconnect/models/food_business.dart';
import 'package:brisconnect/services/food_business_service.dart';
import 'package:brisconnect/screens/food_business_detail_screen.dart';

class FoodBusinessDiscoveryScreen extends StatefulWidget {
  const FoodBusinessDiscoveryScreen({Key? key}) : super(key: key);

  @override
  State<FoodBusinessDiscoveryScreen> createState() =>
      _FoodBusinessDiscoveryScreenState();
}

class _FoodBusinessDiscoveryScreenState extends State<FoodBusinessDiscoveryScreen> {
  final _businessService = FoodBusinessService();
  final _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Food Businesses'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() {
                  _isSearching = value.isNotEmpty;
                }),
                decoration: InputDecoration(
                  hintText: 'Search businesses...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _isSearching
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _isSearching = false);
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            // Business List
            _isSearching
                ? _buildSearchResults()
                : _buildAllBusinesses(),
          ],
        ),
      ),
    );
  }

  Widget _buildAllBusinesses() {
    return StreamBuilder<List<FoodBusiness>>(
      stream: _businessService.getAllBusinesses(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Error loading businesses: ${snapshot.error}'),
            ),
          );
        }

        final businesses = snapshot.data ?? [];

        if (businesses.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text('No businesses found'),
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: businesses.length,
          itemBuilder: (context, index) {
            return _buildBusinessCard(context, businesses[index]);
          },
        );
      },
    );
  }

  Widget _buildSearchResults() {
    return StreamBuilder<List<FoodBusiness>>(
      stream: _businessService.searchBusinesses(_searchController.text),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final businesses = snapshot.data ?? [];

        if (businesses.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'No results for "${_searchController.text}"',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: businesses.length,
          itemBuilder: (context, index) {
            return _buildBusinessCard(context, businesses[index]);
          },
        );
      },
    );
  }

  Widget _buildBusinessCard(BuildContext context, FoodBusiness business) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                FoodBusinessDetailScreen(businessId: business.id),
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image placeholder or actual image
            if (business.imageUrl != null)
              Image.network(
                business.imageUrl!,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 200,
                    width: double.infinity,
                    color: Colors.grey[300],
                    child: const Icon(Icons.restaurant, size: 60),
                  );
                },
              )
            else
              Container(
                height: 200,
                width: double.infinity,
                color: Colors.grey[300],
                child: const Icon(Icons.restaurant, size: 60),
              ),
            // Business Info
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    business.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  // Cuisine types
                  if (business.cuisineTypes != null &&
                      business.cuisineTypes!.isNotEmpty)
                    Text(
                      business.cuisineTypes!.join(', '),
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 8),
                  // Rating
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 18),
                          const SizedBox(width: 4),
                          Text(
                            business.averageRating?.toStringAsFixed(1) ?? 'N/A',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '(${business.reviewCount ?? 0})',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      // Address
                      Expanded(
                        child: Text(
                          business.address,
                          textAlign: TextAlign.right,
                          style: Theme.of(context).textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
}
