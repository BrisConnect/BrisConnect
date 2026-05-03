import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import 'package:brisconnect/services/brisbane_stories_service.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/widgets/audio_guide_widget.dart';

class BrisbaneStoriesScreen extends StatefulWidget {
  const BrisbaneStoriesScreen({super.key, this.firestore});

  /// Optional Firestore instance for testing.
  final FirebaseFirestore? firestore;

  @override
  State<BrisbaneStoriesScreen> createState() => _BrisbaneStoriesScreenState();
}

class _BrisbaneStoriesScreenState extends State<BrisbaneStoriesScreen>
    with SingleTickerProviderStateMixin {
  late final FirebaseFirestore _firestore;

  static const String _fallbackImage =
      'https://images.unsplash.com/photo-1472653431158-6364773b2a56?auto=format&fit=crop&w=1400&q=80';

  static const String _heroBannerImage =
      'https://images.unsplash.com/photo-1524293568345-75d62c3664f7?auto=format&fit=crop&w=1400&q=80';

  static const List<_StoryCategory> _categories = [
    _StoryCategory(
      id: 'first_nations',
      label: 'First Nations',
      icon: Icons.public_rounded,
      gradient: [Color(0xFF8B5E3C), Color(0xFFD4A057)],
    ),
    _StoryCategory(
      id: 'arts',
      label: 'Arts',
      icon: Icons.theater_comedy_rounded,
      gradient: [Color(0xFF6A1B9A), Color(0xFFAB47BC)],
    ),
    _StoryCategory(
      id: 'landmarks',
      label: 'Landmarks',
      icon: Icons.account_balance_rounded,
      gradient: [Color(0xFF1E3A5F), Color(0xFF4A90D9)],
    ),
    _StoryCategory(
      id: 'culture_food',
      label: 'Food',
      icon: Icons.restaurant_rounded,
      gradient: [Color(0xFFC65D2E), Color(0xFFE8945A)],
    ),
    _StoryCategory(
      id: 'festivals',
      label: 'Festivals',
      icon: Icons.celebration_rounded,
      gradient: [Color(0xFFD4A017), Color(0xFFF0D060)],
    ),
  ];

  static const List<_SuggestedTopic> _suggestedTopics = [
    _SuggestedTopic(
      title: 'South Bank Parklands',
      subtitle: 'A cultural precinct by the river',
      icon: Icons.park_rounded,
    ),
    _SuggestedTopic(
      title: 'Story Bridge History',
      subtitle: 'Engineering marvel since 1940',
      icon: Icons.architecture_rounded,
    ),
    _SuggestedTopic(
      title: 'First Nations Heritage',
      subtitle: 'Turrbal and Jagera Country',
      icon: Icons.public_rounded,
    ),
  ];

  final PageController _heroPageController = PageController();
  Timer? _heroAutoScroll;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  bool _isLoading = true;
  String? _loadError;
  List<BrisbaneStory> _stories = const [];
  List<BrisbaneVoice> _voices = const [];
  String? _selectedCategory;
  int _heroPage = 0;
  final Set<String> _savedStoryIds = {};

  @override
  void initState() {
    super.initState();
    _firestore = widget.firestore ?? FirebaseFirestore.instance;
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _loadData();
  }

  @override
  void dispose() {
    _heroAutoScroll?.cancel();
    _heroPageController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final storiesSnap = await _firestore
          .collection('brisbane_stories')
          .where('approvalStatus', isEqualTo: 'approved')
          .get();

      final voicesSnap = await _firestore
          .collection('brisbane_voices')
          .where('approvalStatus', isEqualTo: 'approved')
          .get();

      if (!mounted) return;

      final stories = storiesSnap.docs.map(BrisbaneStory.fromDoc).toList()
        ..sort((a, b) {
          final aDate = a.publishedAt ?? DateTime(2000);
          final bDate = b.publishedAt ?? DateTime(2000);
          return bDate.compareTo(aDate);
        });

      setState(() {
        _stories = stories;
        _voices = voicesSnap.docs.map(BrisbaneVoice.fromDoc).toList();
        _isLoading = false;
      });

      _startHeroAutoScroll();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = 'Unable to load stories right now. Please try again.';
      });
    }
  }

  void _startHeroAutoScroll() {
    _heroAutoScroll?.cancel();
    final heroCount = _heroStories.length;
    if (heroCount <= 1) return;

    _heroAutoScroll = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_heroPageController.hasClients) return;
      final next = (_heroPage + 1) % heroCount;
      _heroPageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  List<BrisbaneStory> get _heroStories => _stories.take(5).toList();

  List<BrisbaneStory> get _filteredStories {
    if (_selectedCategory == null) return _stories;
    return _stories.where((s) => s.category == _selectedCategory).toList();
  }

  void _toggleSaved(String storyId) {
    setState(() {
      if (_savedStoryIds.contains(storyId)) {
        _savedStoryIds.remove(storyId);
      } else {
        _savedStoryIds.add(storyId);
      }
    });
  }

  void _shareStory(BrisbaneStory story) {
    SharePlus.instance.share(
      ShareParams(text: '${story.title} — ${story.description}'),
    );
  }

  void _openStoryDetail(BrisbaneStory story) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _StoryDetailScreen(story: story)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.background,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppPalette.ochre))
          : _loadError != null
              ? _buildErrorState()
              : RefreshIndicator(
                  color: AppPalette.ochre,
                  onRefresh: _loadData,
                  child: CustomScrollView(
                    slivers: [
                      _buildHeroBanner(),
                      SliverToBoxAdapter(child: _buildHeroCarousel()),
                      const SliverToBoxAdapter(child: SizedBox(height: 24)),
                      SliverToBoxAdapter(child: _buildCategoryRow()),
                      const SliverToBoxAdapter(child: SizedBox(height: 24)),
                      SliverToBoxAdapter(child: _buildFeaturedStories()),
                      const SliverToBoxAdapter(child: SizedBox(height: 28)),
                      SliverToBoxAdapter(child: _buildMapPreview()),
                      const SliverToBoxAdapter(child: SizedBox(height: 28)),
                      SliverToBoxAdapter(child: _buildVoicesSection()),
                      const SliverToBoxAdapter(child: SizedBox(height: 40)),
                    ],
                  ),
                ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 48, color: AppPalette.mutedText),
            const SizedBox(height: 12),
            Text(_loadError!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppPalette.mutedText)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppPalette.ochre,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(99)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  1. HERO BANNER — full-bleed with vignette gradient
  // ─────────────────────────────────────────────────────────

  Widget _buildHeroBanner() {
    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      backgroundColor: AppPalette.ochre,
      foregroundColor: Colors.white,
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: true,
        titlePadding: const EdgeInsets.only(bottom: 16),
        title: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Discover Brisbane's Stories",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.3,
                shadows: [Shadow(blurRadius: 10, color: Colors.black54)],
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Culture, history, and people',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.white,
                shadows: [Shadow(blurRadius: 8, color: Colors.black54)],
              ),
            ),
          ],
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: _heroBannerImage,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) =>
                  Container(color: AppPalette.deepBlue),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.4, 1.0],
                  colors: [
                    Colors.black.withAlpha(60),
                    Colors.transparent,
                    Colors.black.withAlpha(200),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  Trending stories carousel
  // ─────────────────────────────────────────────────────────

  Widget _buildHeroCarousel() {
    final heroes = _heroStories;
    if (heroes.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        const SizedBox(height: 20),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Icon(Icons.local_fire_department_rounded,
                  color: AppPalette.ochre, size: 22),
              SizedBox(width: 8),
              Text(
                'Trending Stories',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppPalette.charcoal,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 200,
          child: PageView.builder(
            controller: _heroPageController,
            itemCount: heroes.length,
            onPageChanged: (i) => setState(() => _heroPage = i),
            itemBuilder: (context, index) {
              final story = heroes[index];
              final imageUrl = story.imageUrl.trim().isEmpty
                  ? _fallbackImage
                  : story.imageUrl;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GestureDetector(
                  onTap: () => _openStoryDetail(story),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(40),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              color: AppPalette.surfaceAlt,
                              alignment: Alignment.center,
                              child: const CircularProgressIndicator(
                                  strokeWidth: 2, color: AppPalette.ochre),
                            ),
                            errorWidget: (_, __, ___) => Container(
                              color: AppPalette.surfaceAlt,
                              alignment: Alignment.center,
                              child: const Icon(
                                  Icons.image_not_supported_rounded,
                                  color: AppPalette.mutedText,
                                  size: 32),
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                stops: const [0.35, 1.0],
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withAlpha(210),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            top: 14,
                            left: 14,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppPalette.ochre.withAlpha(220),
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Text(
                                story.category
                                    .replaceAll('_', ' ')
                                    .toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 16,
                            right: 16,
                            bottom: 16,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  story.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 19,
                                    fontWeight: FontWeight.w800,
                                    height: 1.2,
                                    shadows: [
                                      Shadow(
                                          blurRadius: 10,
                                          color: Colors.black54)
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  story.description,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (heroes.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(heroes.length, (i) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  height: 7,
                  width: i == _heroPage ? 24 : 7,
                  decoration: BoxDecoration(
                    color:
                        i == _heroPage ? AppPalette.ochre : AppPalette.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────
  //  2. CATEGORIES — gradient circles with scale animation
  // ─────────────────────────────────────────────────────────

  Widget _buildCategoryRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Explore by Category',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppPalette.charcoal,
            ),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final cat = _categories[index];
              final selected = _selectedCategory == cat.id;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedCategory =
                        _selectedCategory == cat.id ? null : cat.id;
                  });
                },
                child: AnimatedScale(
                  scale: selected ? 1.08 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: selected
                                ? cat.gradient
                                : [
                                    AppPalette.surfaceAlt,
                                    AppPalette.surfaceAlt,
                                  ],
                          ),
                          boxShadow: selected
                              ? [
                                  BoxShadow(
                                    color: cat.gradient.first.withAlpha(80),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : [
                                  BoxShadow(
                                    color: Colors.black.withAlpha(15),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                          border: Border.all(
                            color: selected
                                ? Colors.white.withAlpha(80)
                                : AppPalette.border,
                            width: selected ? 2.5 : 1.5,
                          ),
                        ),
                        child: Icon(
                          cat.icon,
                          size: 26,
                          color: selected
                              ? Colors.white
                              : AppPalette.deepBlue.withAlpha(180),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        cat.label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight:
                              selected ? FontWeight.w800 : FontWeight.w600,
                          color: selected
                              ? cat.gradient.first
                              : AppPalette.charcoal,
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

  // ─────────────────────────────────────────────────────────
  //  3 & 4. FEATURED STORIES + empty-state suggestions
  // ─────────────────────────────────────────────────────────

  Widget _buildFeaturedStories() {
    final stories = _filteredStories;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              const Icon(Icons.auto_stories_rounded,
                  color: AppPalette.deepBlue, size: 20),
              const SizedBox(width: 8),
              Text(
                _selectedCategory != null ? 'Stories' : 'Featured Stories',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppPalette.charcoal,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (stories.isEmpty)
          _buildEmptySuggestions()
        else
          _buildStoryList(stories),
      ],
    );
  }

  Widget _buildEmptySuggestions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Explore popular Brisbane stories',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppPalette.mutedText,
            ),
          ),
        ),
        const SizedBox(height: 12),
        ..._suggestedTopics.map((topic) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
              child: Container(
                decoration: BoxDecoration(
                  color: AppPalette.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: AppPalette.border.withAlpha(120), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(10),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppPalette.ochre, Color(0xFFE8945A)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(topic.icon, color: Colors.white, size: 22),
                  ),
                  title: Text(
                    topic.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppPalette.charcoal,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    topic.subtitle,
                    style: const TextStyle(
                        color: AppPalette.mutedText, fontSize: 12),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded,
                      size: 14, color: AppPalette.mutedText),
                ),
              ),
            )),
      ],
    );
  }

  Widget _buildStoryList(List<BrisbaneStory> stories) {
    return Column(
      children: stories.map((story) => _buildStoryCard(story)).toList(),
    );
  }

  Widget _buildStoryCard(BrisbaneStory story) {
    final imageUrl =
        story.imageUrl.trim().isEmpty ? _fallbackImage : story.imageUrl;
    final isSaved = _savedStoryIds.contains(story.id);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
      child: GestureDetector(
        onTap: () => _openStoryDetail(story),
        child: Container(
          decoration: BoxDecoration(
            color: AppPalette.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(18),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(20)),
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        height: 180,
                        color: AppPalette.surfaceAlt,
                        alignment: Alignment.center,
                        child: const CircularProgressIndicator(
                            strokeWidth: 2, color: AppPalette.ochre),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        height: 180,
                        color: AppPalette.surfaceAlt,
                        alignment: Alignment.center,
                        child: const Icon(Icons.image_not_supported_rounded,
                            color: AppPalette.mutedText, size: 32),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(130),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        story.category.replaceAll('_', ' ').toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: GestureDetector(
                      onTap: () => _toggleSaved(story.id),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(230),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(30),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          isSaved
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          size: 18,
                          color:
                              isSaved ? AppPalette.ochre : AppPalette.mutedText,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      story.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppPalette.charcoal,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      story.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppPalette.mutedText,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppPalette.ochre, Color(0xFFE8945A)],
                            ),
                            borderRadius: BorderRadius.circular(99),
                            boxShadow: [
                              BoxShadow(
                                color: AppPalette.ochre.withAlpha(60),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _openStoryDetail(story),
                              borderRadius: BorderRadius.circular(99),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 18, vertical: 9),
                                child: Text(
                                  'Read More',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => _shareStory(story),
                          icon: const Icon(Icons.share_rounded, size: 20),
                          color: AppPalette.mutedText,
                          tooltip: 'Share',
                        ),
                      ],
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

  // ─────────────────────────────────────────────────────────
  //  5. MAP — alive with gradient, animated pins, river pattern
  // ─────────────────────────────────────────────────────────

  Widget _buildMapPreview() {
    final storiesWithLocation = _stories
        .where((s) => s.latitude != null && s.longitude != null)
        .toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  _StoriesMapScreen(stories: storiesWithLocation),
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(20),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Stack(
              children: [
                Container(
                  height: 190,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFE8F5E9), Color(0xFFC8E6C9)],
                    ),
                  ),
                  child: CustomPaint(painter: _MapPatternPainter()),
                ),
                Positioned(
                    top: 40, left: 60, child: _buildMapPin(AppPalette.ochre)),
                Positioned(
                    top: 55,
                    right: 80,
                    child: _buildMapPin(AppPalette.deepBlue)),
                Positioned(
                    top: 80, left: 140, child: _buildMapPin(AppPalette.gold)),
                Positioned(
                    bottom: 60,
                    right: 50,
                    child: _buildMapPin(const Color(0xFF6A1B9A))),
                Positioned(
                    bottom: 50,
                    left: 80,
                    child: _buildMapPin(AppPalette.ochre)),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          AppPalette.deepBlue.withAlpha(240),
                        ],
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.explore_rounded,
                            color: Colors.white, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Explore Cultural Locations',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                '${storiesWithLocation.length} locations on the map',
                                style: TextStyle(
                                  color: Colors.white.withAlpha(180),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppPalette.ochre,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.arrow_forward_rounded,
                              color: Colors.white, size: 18),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMapPin(Color color) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: child,
        );
      },
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: color.withAlpha(100),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Icon(Icons.location_on_rounded,
            color: Colors.white, size: 14),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  6. VOICES OF BRISBANE — accent strip + quote icon
  // ─────────────────────────────────────────────────────────

  Widget _buildVoicesSection() {
    if (_voices.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Icon(Icons.record_voice_over_rounded,
                  color: AppPalette.gold, size: 22),
              SizedBox(width: 8),
              Text(
                'Voices of Brisbane',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppPalette.charcoal,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Stories told by the people who live them',
            style: TextStyle(fontSize: 13, color: AppPalette.mutedText),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 200,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _voices.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, index) =>
                _buildVoiceCard(_voices[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildVoiceCard(BrisbaneVoice voice) {
    return Container(
      width: 230,
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(14),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 4,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppPalette.ochre, AppPalette.gold],
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border:
                            Border.all(color: AppPalette.ochre, width: 2),
                      ),
                      child: CircleAvatar(
                        radius: 22,
                        backgroundColor: AppPalette.surfaceAlt,
                        backgroundImage:
                            voice.profileImageUrl.trim().isNotEmpty
                                ? CachedNetworkImageProvider(
                                    voice.profileImageUrl)
                                : null,
                        child: voice.profileImageUrl.trim().isEmpty
                            ? const Icon(Icons.person_rounded,
                                color: AppPalette.mutedText, size: 22)
                            : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            voice.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppPalette.charcoal,
                            ),
                          ),
                          const Text(
                            'Brisbane Local',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppPalette.mutedText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Icon(Icons.format_quote_rounded,
                    color: AppPalette.ochre, size: 20),
                const SizedBox(height: 4),
                Text(
                  voice.quote,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: AppPalette.charcoal,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Map pattern painter — grid + river curve
// ─────────────────────────────────────────────────────────────

class _MapPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.green.withAlpha(25)
      ..strokeWidth = 1;

    for (double y = 0; y < size.height; y += 30) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    for (double x = 0; x < size.width; x += 30) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    final riverPaint = Paint()
      ..color = const Color(0xFF81C784).withAlpha(60)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(0, size.height * 0.6)
      ..cubicTo(
        size.width * 0.3,
        size.height * 0.3,
        size.width * 0.7,
        size.height * 0.7,
        size.width,
        size.height * 0.4,
      );
    canvas.drawPath(path, riverPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────
//  Story Detail Screen
// ─────────────────────────────────────────────────────────────

class _StoryDetailScreen extends StatelessWidget {
  final BrisbaneStory story;

  const _StoryDetailScreen({required this.story});

  static const String _fallbackImage =
      'https://images.unsplash.com/photo-1472653431158-6364773b2a56?auto=format&fit=crop&w=1400&q=80';

  /// Wraps the raw story content in a gentle storytelling intro and sign-off
  /// so the TTS narration feels like a guided tale rather than a text read-out.
  String _buildStorytellingText(BrisbaneStory s) {
    final body = s.content.isNotEmpty ? s.content : s.description;
    final category = s.category.replaceAll('_', ' ');
    final location =
        (s.locationName != null && s.locationName!.isNotEmpty)
            ? ', at ${s.locationName}'
            : '';
    return 'Here is a Brisbane $category story. '
        '${s.title}$location. '
        '... '
        '$body '
        '... '
        'And that is the story of ${s.title}. Thank you for listening.';
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl =
        story.imageUrl.trim().isEmpty ? _fallbackImage : story.imageUrl;

    return Scaffold(
      backgroundColor: AppPalette.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: AppPalette.ochre,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                story.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  shadows: [Shadow(blurRadius: 8, color: Colors.black54)],
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) =>
                        Container(color: AppPalette.surfaceAlt),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.0, 0.5, 1.0],
                        colors: [
                          Colors.black.withAlpha(40),
                          Colors.transparent,
                          Colors.black.withAlpha(180),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppPalette.ochre.withAlpha(25),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(
                          color: AppPalette.ochre.withAlpha(60), width: 1),
                    ),
                    child: Text(
                      story.category.replaceAll('_', ' ').toUpperCase(),
                      style: const TextStyle(
                        color: AppPalette.ochre,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (story.locationName != null &&
                    story.locationName!.isNotEmpty) ...[
                  Row(
                    children: [
                      const Icon(Icons.place_rounded,
                          size: 18, color: AppPalette.ochre),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          story.locationName!,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppPalette.mutedText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                Text(
                  story.description,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppPalette.charcoal,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                AiNarrationWidget(
                  narrationText: _buildStorytellingText(story),
                  helperText: 'Tap play to hear your AI tour guide tell this Brisbane story',
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Divider(color: AppPalette.border, height: 1),
                ),
                Text(
                  story.content.isNotEmpty ? story.content : story.description,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppPalette.charcoal,
                    height: 1.7,
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppPalette.deepBlue, Color(0xFF2A5298)],
                        ),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            SharePlus.instance.share(
                              ShareParams(
                                  text:
                                      '${story.title} — ${story.description}'),
                            );
                          },
                          borderRadius: BorderRadius.circular(99),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.share_rounded,
                                    size: 18, color: Colors.white),
                                SizedBox(width: 8),
                                Text(
                                  'Share Story',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Stories Map Screen
// ─────────────────────────────────────────────────────────────

class _StoriesMapScreen extends StatelessWidget {
  final List<BrisbaneStory> stories;

  const _StoriesMapScreen({required this.stories});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.background,
      appBar: AppBar(
        title: const Text('Cultural Map'),
        centerTitle: true,
      ),
      body: stories.isEmpty
          ? const Center(
              child: Text('No locations available.',
                  style: TextStyle(color: AppPalette.mutedText)),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: stories.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final story = stories[index];
                return Container(
                  decoration: BoxDecoration(
                    color: AppPalette.surface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(12),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    leading: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppPalette.ochre, Color(0xFFE8945A)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.location_on_rounded,
                          color: Colors.white, size: 22),
                    ),
                    title: Text(
                      story.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppPalette.charcoal,
                      ),
                    ),
                    subtitle: story.locationName != null
                        ? Text(story.locationName!,
                            style: const TextStyle(
                                color: AppPalette.mutedText, fontSize: 12))
                        : null,
                    trailing: const Icon(Icons.chevron_right_rounded,
                        color: AppPalette.mutedText),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              _StoryDetailScreen(story: story),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Helper models
// ─────────────────────────────────────────────────────────────

class _StoryCategory {
  final String id;
  final String label;
  final IconData icon;
  final List<Color> gradient;

  const _StoryCategory({
    required this.id,
    required this.label,
    required this.icon,
    required this.gradient,
  });
}

class _SuggestedTopic {
  final String title;
  final String subtitle;
  final IconData icon;

  const _SuggestedTopic({
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}
