import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:brisconnect/theme/app_palette.dart';

/// Web home page displaying attractions and events from Firestore
class WebHomePage extends StatefulWidget {
  const WebHomePage({super.key});

  @override
  State<WebHomePage> createState() => _WebHomePageState();
}

class _WebHomePageState extends State<WebHomePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'All';
  String _selectedType = 'Events'; // Only Events now

  // Mock data for demonstration while Firestore is being populated
  final List<Map<String, dynamic>> mockData = [
    {
      'title': 'Brisbane Festival 2026',
      'category': 'Music',
      'description': 'The annual Brisbane Festival celebrates diverse performing arts with theatre, dance, music, visual art and family events.',
      'imageUrl': 'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=500&h=300&fit=crop',
    },
    {
      'title': 'South Bank Parklands',
      'category': 'Art & Culture',
      'description': 'A cultural oasis featuring gardens, museums, galleries, and cultural institutions in a 17-hectare riverside precinct.',
      'imageUrl': 'https://images.unsplash.com/photo-1469515782759-481cda802842?w=500&h=300&fit=crop',
    },
    {
      'title': 'Story Bridge',
      'category': 'Art & Culture',
      'description': 'An iconic steel cantilever bridge offering panoramic views of Brisbane and the Brisbane River.',
      'imageUrl': 'https://images.unsplash.com/photo-1570361235855-9f834042e8f3?w=500&h=300&fit=crop',
    },
    {
      'title': 'Lone Pine Koala Sanctuary',
      'category': 'Family',
      'description': 'Australia\'s first and most popular wildlife sanctuary where you can interact with native Australian animals.',
      'imageUrl': 'https://images.unsplash.com/photo-1478098711619-69891b0ec21a?w=500&h=300&fit=crop',
    },
    {
      'title': 'Brisbane Powerhouse Comedy Show',
      'category': 'Art & Culture',
      'description': 'World-class comedy performances at Brisbane\'s premier arts venue in New Farm.',
      'imageUrl': 'https://images.unsplash.com/photo-1514306688286-2ad16fe4f947?w=500&h=300&fit=crop',
    },
    {
      'title': 'South Bank Markets',
      'category': 'Markets',
      'description': 'Fresh produce, craft items, and local goods every Saturday and Sunday at South Bank Parklands.',
      'imageUrl': 'https://images.unsplash.com/photo-1488459716781-6d7d73c2c640?w=500&h=300&fit=crop',
    },
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Scaffold(
      appBar: AppBar(
        title: const Text('BrisConnect+ - Discover'),
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Back'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppPalette.surface,
                foregroundColor: AppPalette.ochre,
              ),
            ),
          ),
        ],
      ),
      body: isMobile ? _buildMobileLayout() : _buildDesktopLayout(),
    );
  }

  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildSearchBar(),
          _buildFilterChips(),
          _buildContentList(),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // Sidebar
        Container(
          width: 280,
          decoration: BoxDecoration(
            color: AppPalette.surface,
            border: Border(
              right: BorderSide(
                color: AppPalette.border.withValues(alpha: 0.2),
              ),
            ),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Filter & Search',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 20),
                _buildSearchBar(),
                const SizedBox(height: 24),
                Text(
                  'Type',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
                _buildTypeFilter(),
                const SizedBox(height: 24),
                Text(
                  'Category',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
                _buildCategoryFilter(),
              ],
            ),
          ),
        ),
        // Main content
        Expanded(
          child: _buildContentGrid(),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search attractions and events...',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onChanged: (value) {
          setState(() {});
        },
      ),
    );
  }

  Widget _buildFilterChips() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Type',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: ['Events']
                .map((type) => FilterChip(
                      label: Text(type),
                      selected: _selectedType == type,
                      onSelected: (selected) {
                        setState(() => _selectedType = type);
                      },
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),
          Text(
            'Category',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          _buildCategoryFilter(),
        ],
      ),
    );
  }

  Widget _buildTypeFilter() {
    return Column(
      children: ['Events']
          .map((type) => RadioListTile<String>(
                title: Text(type),
                value: type,
                groupValue: _selectedType,
                onChanged: (value) {
                  setState(() => _selectedType = value ?? 'Events');
                },
              ))
          .toList(),
    );
  }

  Widget _buildCategoryFilter() {
    // Mock categories while Firestore is being populated
    final mockCategories = [
      'All',
      'Music',
      'Sports',
      'Art & Culture',
      'Food & Drink',
      'Community',
      'Family',
      'Education',
      'Markets',
    ];

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('event_categories').snapshots(),
      builder: (context, snapshot) {
        final categories = (snapshot.hasData && snapshot.data!.docs.isNotEmpty)
            ? ['All', ...snapshot.data!.docs.map((doc) => doc['name'] as String).toList()]
            : mockCategories;

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: categories
              .map((category) => FilterChip(
                    label: Text(category),
                    selected: _selectedCategory == category,
                    onSelected: (selected) {
                      setState(() => _selectedCategory = category);
                    },
                  ))
              .toList(),
        );
      },
    );
  }

  Widget _buildContentList() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: _buildContentStream(isGrid: false),
    );
  }

  Widget _buildContentGrid() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: _buildContentStream(isGrid: true),
    );
  }

  Widget _buildContentStream({required bool isGrid}) {
    Query<Map<String, dynamic>> buildQuery() {
      Query<Map<String, dynamic>> query =
          _firestore.collection('events');

      if (_selectedCategory != 'All') {
        query = query.where('category', isEqualTo: _selectedCategory);
      }

      return query;
    }

    return StreamBuilder<QuerySnapshot>(
      stream: buildQuery().snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // Prepare data - either from Firestore or mock
        List<Map<String, dynamic>> allData = [];
        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          allData = snapshot.data!.docs
              .map((doc) => doc.data() as Map<String, dynamic>)
              .toList();
        } else {
          // Use mock data as fallback
          allData = mockData;
        }

        // Filter by search term
        allData = allData.where((data) {
          final title = (data['title'] as String? ?? '').toLowerCase();
          final description =
              (data['description'] as String? ?? '').toLowerCase();
          final searchLower = _searchController.text.toLowerCase();
          return title.contains(searchLower) ||
              description.contains(searchLower);
        }).toList();

        // Filter by category
        if (_selectedCategory != 'All') {
          allData = allData.where((data) {
            return data['category'] == _selectedCategory;
          }).toList();
        }

        if (allData.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.search_off_rounded,
                  size: 64,
                  color: AppPalette.ochre.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'No results found',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppPalette.mutedText,
                      ),
                ),
              ],
            ),
          );
        }

        if (isGrid) {
          return GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.85,
            ),
            itemCount: allData.length,
            itemBuilder: (context, index) {
              return _buildItemCard(allData[index]);
            },
          );
        } else {
          return ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: allData.length,
            itemBuilder: (context, index) {
              return _buildItemCard(allData[index], isListView: true);
            },
          );
        }
      },
    );
  }

  Widget _buildItemCard(Map<String, dynamic> data, {bool isListView = false}) {
    final title = data['title'] as String? ?? 'Untitled';
    final description = data['description'] as String? ?? '';
    final category = data['category'] as String? ?? '';
    final imageUrl = data['imageUrl'] as String?;

    if (isListView) {
      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: ListTile(
          leading: imageUrl != null
              ? Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    image: DecorationImage(
                      image: NetworkImage(imageUrl),
                      fit: BoxFit.cover,
                    ),
                  ),
                )
              : Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: LinearGradient(
                      colors: [
                        AppPalette.ochre.withValues(alpha: 0.3),
                        AppPalette.gold.withValues(alpha: 0.1),
                      ],
                    ),
                  ),
                  child: const Icon(Icons.image_not_supported_rounded),
                ),
          title: Text(title),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              if (category.isNotEmpty)
                Chip(
                  label: Text(category),
                  labelStyle: const TextStyle(fontSize: 12),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              const SizedBox(height: 4),
              Text(
                description.length > 100
                    ? '${description.substring(0, 100)}...'
                    : description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          onTap: () => _showDetails(context, title, description, imageUrl),
        ),
      );
    }

    return Card(
      child: InkWell(
        onTap: () => _showDetails(context, title, description, imageUrl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imageUrl != null)
              Container(
                width: double.infinity,
                height: 150,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  image: DecorationImage(
                    image: NetworkImage(imageUrl),
                    fit: BoxFit.cover,
                  ),
                ),
              )
            else
              Container(
                width: double.infinity,
                height: 150,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  gradient: LinearGradient(
                    colors: [
                      AppPalette.ochre.withValues(alpha: 0.2),
                      AppPalette.gold.withValues(alpha: 0.1),
                    ],
                  ),
                ),
                child: const Icon(Icons.image_not_supported_rounded),
              ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 6),
                  if (category.isNotEmpty)
                    Chip(
                      label: Text(category),
                      labelStyle: const TextStyle(fontSize: 11),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                  const SizedBox(height: 6),
                  Text(
                    description.length > 60
                        ? '${description.substring(0, 60)}...'
                        : description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppPalette.mutedText,
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

  void _showDetails(
    BuildContext context,
    String title,
    String description,
    String? imageUrl,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (imageUrl != null)
                Container(
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    image: DecorationImage(
                      image: NetworkImage(imageUrl),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              if (imageUrl != null) const SizedBox(height: 16),
              Text(
                description,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
