import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:brisconnect/auth/visitor_auth.dart';
import 'package:brisconnect/l10n/app_localizations.dart';
import 'package:brisconnect/mixins/locale_listener_mixin.dart';
import 'package:brisconnect/services/business_dashboard_service.dart';
import 'package:brisconnect/services/share/content_share_service.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/widgets/audio_guide_widget.dart';
import 'package:brisconnect/widgets/business_reviews_widget.dart';
import 'package:brisconnect/widgets/crowd_report_widget.dart';
import 'package:brisconnect/widgets/fallback_image.dart';
import 'package:brisconnect/utils/responsive_utils.dart';
import 'package:brisconnect/widgets/logo_app_bar_title.dart';
import 'package:brisconnect/widgets/share_bottom_sheet.dart';

class FoodDetailScreen extends StatefulWidget {
  const FoodDetailScreen({
    super.key,
    required this.id,
    required this.title,
    required this.description,
    required this.location,
    required this.cuisine,
    required this.imageUrl,
    required this.categories,
    this.rating,
    this.badge,
    this.dateTime,
    this.price,
    this.mapQuery,
    this.webLink,
    this.phone,
    this.email,
    this.openingHours,
    this.facebookUrl,
    this.instagramUrl,
    this.onlineOrderUrl,
    this.aiAudio,
    this.shareService,
    this.menu = const [],
    this.photoGallery = const [],
    this.isGoogleListing = false,
    this.sourceProvider,
  });

  final String id;
  final String title;
  final String description;
  final String location;
  final String cuisine;
  final String imageUrl;
  final List<String> categories;
  final double? rating;
  final String? badge;
  final String? dateTime;
  final String? price;
  final String? mapQuery;
  final String? webLink;
  final String? phone;
  final String? email;
  final String? openingHours;
  final String? facebookUrl;
  final String? instagramUrl;
  final String? onlineOrderUrl;
  final String? aiAudio;
  final ContentShareService? shareService;
  final List<Map<String, dynamic>> menu;
  final List<String> photoGallery;
  final bool isGoogleListing;
  final String? sourceProvider;

  @override
  State<FoodDetailScreen> createState() => _FoodDetailScreenState();
}

class _FoodDetailScreenState extends State<FoodDetailScreen>
    with LocaleListenerMixin<FoodDetailScreen> {
  bool _viewTracked = false;

  @override
  @override
  void initState() {
    super.initState();
    setupLocaleListener();
    _trackView();
  }

  Future<void> _trackView() async {
    if (_viewTracked) return;
    _viewTracked = true;
    try {
      final visitorId = FirebaseAuth.instance.currentUser?.uid ??
          VisitorAuth.currentVisitor?.email;
      await BusinessDashboardService().recordProfileView(
        widget.id,
        visitorId: visitorId,
        ownerId: widget.email,
      );
    } catch (_) {
      // Analytics should never block the UI.
    }
  }

  String get id => widget.id;
  String get title => widget.title;
  String get description => widget.description;
  String get location => widget.location;
  String get cuisine => widget.cuisine;
  String get imageUrl => widget.imageUrl;
  List<String> get categories => widget.categories;
  double? get rating => widget.rating;
  String? get badge => widget.badge;
  String? get dateTime => widget.dateTime;
  String? get price => widget.price;
  String? get mapQuery => widget.mapQuery;
  String? get webLink => widget.webLink;
  String? get phone => widget.phone;
  String? get email => widget.email;
  String? get openingHours => widget.openingHours;
  String? get facebookUrl => widget.facebookUrl;
  String? get instagramUrl => widget.instagramUrl;
  String? get onlineOrderUrl => widget.onlineOrderUrl;
  String? get aiAudio => widget.aiAudio;
  ContentShareService? get shareService => widget.shareService;
  List<Map<String, dynamic>> get menu => widget.menu;
  List<String> get photoGallery => widget.photoGallery;
  bool get isExternalGoogleListing =>
      widget.isGoogleListing || widget.sourceProvider == 'google_places';

  String _buildRichDescription(AppLocalizations l10n) {
    if (description.trim().length > 80 &&
        !description.trim().toLowerCase().startsWith('contemporary') &&
        !description.trim().toLowerCase().startsWith('premium') &&
        !description.trim().toLowerCase().startsWith('restaurant') &&
        !description.trim().toLowerCase().startsWith('cafe')) {
      return description.trim();
    }
    final cuisineLabel = cuisine.trim().isNotEmpty
        ? cuisine.trim()
        : l10n.foodExperienceFallback;
    final parts = <String>[
      l10n.foodDescriptionIntro(title, cuisineLabel, location),
      if (rating != null && rating! > 0)
        l10n.foodDescriptionRating(rating!.toStringAsFixed(1)),
      if (categories.isNotEmpty)
        l10n.foodDescriptionCategories(categories.take(3).join(', ')),
      if ((price ?? '').trim().isNotEmpty)
        l10n.foodDescriptionPrice(price!.trim()),
      l10n.foodDescriptionOutro(title),
    ];
    return parts.where((s) => s.trim().isNotEmpty).join(' ');
  }

  static final _socialHosts = {
    'facebook.com',
    'fb.com',
    'instagram.com',
    'instagr.am',
    'twitter.com',
    'x.com',
    'tiktok.com',
  };

  bool _isSocialMediaUrl(String rawUrl) {
    final uri = Uri.tryParse(rawUrl.trim().toLowerCase());
    if (uri == null || uri.host.isEmpty) return true;
    return _socialHosts
        .any((host) => uri.host == host || uri.host.endsWith('.$host'));
  }

  bool get _canOrderOnline {
    final url = (onlineOrderUrl ?? '').trim();
    if (url.isEmpty) return false;
    return !_isSocialMediaUrl(url);
  }

  String _buildNarrationText(AppLocalizations l10n) {
    if ((aiAudio ?? '').trim().isNotEmpty) return aiAudio!.trim();
    final parts = <String>[
      l10n.foodNarrationWelcome(title),
      if ((badge ?? '').trim().isNotEmpty)
        l10n.foodNarrationBadge(badge!.trim().toLowerCase()),
      if (cuisine.trim().isNotEmpty) l10n.foodNarrationCuisine(cuisine),
      if (location.trim().isNotEmpty) l10n.foodNarrationLocation(location),
      if ((dateTime ?? '').trim().isNotEmpty)
        l10n.foodNarrationDateTime(dateTime!.trim()),
      if (description.trim().isNotEmpty)
        l10n.foodNarrationDescription(description.trim()),
      if ((price ?? '').trim().isNotEmpty)
        price!.toLowerCase().contains('free')
            ? l10n.foodNarrationPriceFree
            : l10n.foodNarrationPrice(price!.trim()),
      if (rating != null && rating! > 0)
        l10n.foodNarrationRating(rating!.toStringAsFixed(1)),
      if (categories.isNotEmpty)
        l10n.foodNarrationCategories(categories.join(', ')),
    ];
    return '${parts.where((part) => part.trim().isNotEmpty).join('. ')}.';
  }

  Future<void> _openLink(BuildContext context, String rawUrl) async {
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null) return;
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.thisLinkUnavailable)),
      );
    }
  }

  Future<void> _callPhone(BuildContext context, String rawNumber) async {
    final uri = Uri(scheme: 'tel', path: rawNumber.trim());
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (context.mounted) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.unableToCallNumber)),
      );
    }
  }

  Future<void> _sendEmail(BuildContext context, String rawEmail) async {
    final uri = Uri(scheme: 'mailto', path: rawEmail.trim());
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (context.mounted) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.unableToSendEmail)),
      );
    }
  }

  Future<void> _openMap(BuildContext context) async {
    final query =
        (mapQuery ?? '').trim().isNotEmpty ? mapQuery!.trim() : location;
    if (query.trim().isEmpty) return;
    await _openLink(
      context,
      'https://maps.google.com/?q=${Uri.encodeComponent(query)}',
    );
  }

  Future<void> _share(BuildContext context) async {
    if (id.trim().isEmpty) {
      if (context.mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.foodSpotCannotBeShared),
          ),
        );
      }
      return;
    }

    await showShareBottomSheet(
      context: context,
      shareService: shareService,
      type: ShareContentType.food,
      id: id.trim(),
      title: title,
      description: description,
      location: location,
      dateTime: dateTime,
      imageUrl: imageUrl.trim().isNotEmpty ? imageUrl.trim() : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final narrationText = _buildNarrationText(l10n);

    return Scaffold(
      backgroundColor: AppPalette.background,
      appBar: AppBar(
        title: LogoAppBarTitle(l10n.foodBusinessDetails),
        actions: [
          IconButton(
            tooltip: 'Share',
            onPressed: () => _share(context),
            icon: const Icon(Icons.share_rounded),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = ResponsiveUtils.isDesktop(context);
          final maxContentWidth = isDesktop ? 1120.0 : double.infinity;
          final horizontalPadding = isDesktop ? 32.0 : 16.0;

          final mainColumn = <Widget>[
            _buildAboutSection(context, l10n),
            const SizedBox(height: 24),
            if (photoGallery.isNotEmpty) ...[
              _buildGallerySection(l10n),
              const SizedBox(height: 24),
            ],
            if (menu.isNotEmpty && !isExternalGoogleListing) ...[
              _buildMenuSection(l10n),
              const SizedBox(height: 24),
            ],
            if (narrationText.isNotEmpty) ...[
              _buildAudioGuideSection(narrationText, l10n),
              const SizedBox(height: 24),
            ],
            // Google Listing Badge
            if (isExternalGoogleListing)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: const Color(0xFF4285F4).withValues(alpha: 0.1),
                margin: const EdgeInsets.only(bottom: 24),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: Color(0xFF4285F4),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Google Listing • Reviews and reports disabled for external listings',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade700,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            // Crowd Report - only for BrisConnect businesses
            if (!isExternalGoogleListing) ...[
              _buildCrowdReportSection(),
              const SizedBox(height: 24),
            ],
            // Reviews - only for BrisConnect businesses
            if (!isExternalGoogleListing)
              _buildReviewsSection(),
          ];

          final sidebarColumn = <Widget>[
            if (categories.isNotEmpty) ...[
              _buildHighlightsSection(l10n),
              const SizedBox(height: 24),
            ],
            _buildContactActionsSection(context, l10n),
            const SizedBox(height: 24),
            if ((openingHours ?? '').trim().isNotEmpty)
              _buildOpeningHoursSection(l10n),
          ];

          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxContentWidth),
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: FallbackImage(
                      imageUrl: imageUrl,
                      height: ResponsiveUtils.isDesktop(context) ? 360 : 260,
                      width: double.infinity,
                      category: 'food',
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        24,
                        horizontalPadding,
                        40,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeaderSection(context),
                          const SizedBox(height: 20),
                          const Divider(color: AppPalette.border),
                          const SizedBox(height: 24),
                          if (isDesktop)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: mainColumn,
                                  ),
                                ),
                                const SizedBox(width: 24),
                                Expanded(
                                  flex: 1,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: sidebarColumn,
                                  ),
                                ),
                              ],
                            )
                          else
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ...sidebarColumn,
                                const SizedBox(height: 24),
                                ...mainColumn,
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeaderSection(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if ((badge ?? '').trim().isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppPalette.ochre,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    badge!.trim(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppPalette.charcoal,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  if (cuisine.trim().isNotEmpty)
                    _FoodInfoRow(
                      icon: Icons.restaurant_menu_rounded,
                      iconColor: AppPalette.ochre,
                      text: cuisine,
                    ),
                  if (location.trim().isNotEmpty)
                    _FoodInfoRow(
                      icon: Icons.place_rounded,
                      iconColor: AppPalette.deepBlue,
                      text: location,
                    ),
                  if ((dateTime ?? '').trim().isNotEmpty)
                    _FoodInfoRow(
                      icon: Icons.schedule_rounded,
                      iconColor: AppPalette.deepBlue,
                      text: dateTime!.trim(),
                    ),
                  if ((price ?? '').trim().isNotEmpty)
                    _FoodInfoRow(
                      icon: Icons.sell_rounded,
                      iconColor: AppPalette.ochre,
                      text: price!.trim(),
                    ),
                  // Star rating hidden for Google Listings
                  if (rating != null && rating! > 0 && !isExternalGoogleListing)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: AppPalette.gold,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          rating!.toStringAsFixed(1),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppPalette.charcoal,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAboutSection(BuildContext context, AppLocalizations l10n) {
    return _ContentSection(
      title: l10n.aboutThisFoodExperience,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _buildRichDescription(l10n),
            style: const TextStyle(
              color: AppPalette.charcoal,
              height: 1.6,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 16),
          if (_canOrderOnline)
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _ActionChip(
                  icon: Icons.shopping_bag_rounded,
                  label: 'Order Online',
                  onTap: () => _openLink(context, onlineOrderUrl!.trim()),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildHighlightsSection(AppLocalizations l10n) {
    return _ContentSection(
      title: l10n.highlights,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: categories
            .map(
              (category) => Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppPalette.surfaceAlt,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppPalette.border),
                ),
                child: Text(
                  category,
                  style: const TextStyle(
                    color: AppPalette.charcoal,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }

  Widget _buildContactActionsSection(BuildContext context, AppLocalizations l10n) {
    final contactActions = <Widget>[
      if ((phone ?? '').trim().isNotEmpty)
        _ActionChip(
          icon: Icons.phone_rounded,
          label: l10n.call,
          onTap: () => _callPhone(context, phone!.trim()),
        ),
      if ((email ?? '').trim().isNotEmpty)
        _ActionChip(
          icon: Icons.email_rounded,
          label: l10n.email,
          onTap: () => _sendEmail(context, email!.trim()),
        ),
      if ((webLink ?? '').trim().isNotEmpty)
        _ActionChip(
          icon: Icons.open_in_browser_rounded,
          label: l10n.website,
          onTap: () => _openLink(context, webLink!.trim()),
        ),
      if ((facebookUrl ?? '').trim().isNotEmpty)
        _ActionChip(
          icon: Icons.facebook,
          label: 'Facebook',
          onTap: () => _openLink(context, facebookUrl!.trim()),
        ),
      if ((instagramUrl ?? '').trim().isNotEmpty)
        _ActionChip(
          icon: Icons.camera_alt_rounded,
          label: 'Instagram',
          onTap: () => _openLink(context, instagramUrl!.trim()),
        ),
      if ((onlineOrderUrl ?? '').trim().isNotEmpty)
        _ActionChip(
          icon: Icons.shopping_bag_rounded,
          label: l10n.orderOnline,
          onTap: () => _openLink(context, onlineOrderUrl!.trim()),
        ),
      _ActionChip(
        icon: Icons.map_rounded,
        label: l10n.viewOnMap,
        onTap: () => _openMap(context),
      ),
    ];

    if (contactActions.isEmpty) return const SizedBox.shrink();

    return _ContentSection(
      title: l10n.contactAndLinks,
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: contactActions,
      ),
    );
  }

  Widget _buildGallerySection(AppLocalizations l10n) {
    return _ContentSection(
      title: l10n.gallery,
      child: _PhotoGallery(images: photoGallery),
    );
  }

  Widget _buildOpeningHoursSection(AppLocalizations l10n) {
    return _ContentSection(
      title: l10n.openingHours,
      child: Text(
        openingHours!.trim(),
        style: const TextStyle(
          color: AppPalette.charcoal,
          height: 1.6,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildMenuSection(AppLocalizations l10n) {
    return _ContentSection(
      title: l10n.menu,
      child: _MenuSection(menu: menu),
    );
  }

  Widget _buildAudioGuideSection(String narrationText, AppLocalizations l10n) {
    return _ContentSection(
      title: l10n.foodDiscoveryGuide,
      child: AiNarrationWidget(
        narrationText: narrationText,
        helperText: l10n.foodDiscoveryGuideHelper,
      ),
    );
  }

  Widget _buildCrowdReportSection() {
    return CrowdReportWidget(eventId: id);
  }

  Widget _buildReviewsSection() {
    return BusinessReviewsWidget(
      businessId: id,
      currentAverageRating: rating,
      isGoogleListing: isExternalGoogleListing,
    );
  }
}

class _MenuSection extends StatelessWidget {
  const _MenuSection({required this.menu});

  final List<Map<String, dynamic>> menu;

  Map<String, List<Map<String, dynamic>>> _groupByCategory(String fallback) {
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final item in menu) {
      final category =
          ((item['category'] ?? fallback) as String).trim().isNotEmpty
              ? (item['category'] as String).trim()
              : fallback;
      groups.putIfAbsent(category, () => []).add(item);
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final groups = _groupByCategory(l10n.menuFallback);
    final categories = groups.keys.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: categories.expand((category) {
        final items = groups[category]!;
        return [
          if (categories.length > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 8, top: 4),
              child: Text(
                category,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppPalette.charcoal,
                ),
              ),
            ),
          ...items.map((item) {
            final name = (item['name'] as String? ?? '').trim();
            final price = (item['price'] as String? ?? '').trim();
            final description = (item['description'] as String? ?? '').trim();
            final tags = (item['tags'] as List?)?.map((t) => '$t').toList() ??
                <String>[];
            if (name.isEmpty) return const SizedBox.shrink();
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppPalette.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppPalette.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppPalette.charcoal,
                          ),
                        ),
                      ),
                      if (price.isNotEmpty)
                        Text(
                          price,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppPalette.ochre,
                          ),
                        ),
                    ],
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: AppPalette.mutedText,
                      ),
                    ),
                  ],
                  if (tags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: tags
                          .where((tag) => tag.trim().isNotEmpty)
                          .map(
                            (tag) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppPalette.surfaceAlt,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                tag.trim(),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppPalette.charcoal,
                                ),
                              ),
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ],
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
        ];
      }).toList(growable: false),
    );
  }
}

class _PhotoGallery extends StatelessWidget {
  const _PhotoGallery({required this.images});

  final List<String> images;

  @override
  Widget build(BuildContext context) {
    final displayImages = images.where((url) => url.trim().isNotEmpty).toList();
    if (displayImages.isEmpty) return const SizedBox.shrink();

    final isDesktop = ResponsiveUtils.isDesktop(context);

    return SizedBox(
      height: isDesktop ? 220 : 170,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: displayImages.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final url = displayImages[index];
          return GestureDetector(
            onTap: () => _openFullscreen(context, index, displayImages),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: FallbackImage(
                imageUrl: url,
                width: isDesktop ? 300 : 220,
                height: isDesktop ? 220 : 170,
                category: 'food',
              ),
            ),
          );
        },
      ),
    );
  }

  void _openFullscreen(
    BuildContext context,
    int initialIndex,
    List<String> displayImages,
  ) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            PageView.builder(
              controller: PageController(initialPage: initialIndex),
              itemCount: displayImages.length,
              itemBuilder: (_, index) => InteractiveViewer(
                minScale: 0.8,
                maxScale: 3.0,
                child: Center(
                  child: FallbackImage(
                    imageUrl: displayImages[index],
                    width: double.infinity,
                    height: double.infinity,
                    category: 'food',
                  ),
                ),
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18, color: Colors.white),
      label: Text(label),
      labelStyle: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
      backgroundColor: AppPalette.ochre,
      side: BorderSide.none,
      onPressed: onTap,
    );
  }
}

class _FoodInfoRow extends StatelessWidget {
  const _FoodInfoRow({
    required this.icon,
    required this.iconColor,
    required this.text,
  });

  final IconData icon;
  final Color iconColor;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: AppPalette.charcoal,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _FoodSectionHeader extends StatelessWidget {
  const _FoodSectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: AppPalette.deepBlue,
        letterSpacing: 0.2,
      ),
    );
  }
}

class _ContentSection extends StatelessWidget {
  const _ContentSection({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppPalette.ochre.withValues(alpha: 0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 26,
            offset: const Offset(0, 10),
            spreadRadius: -2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FoodSectionHeader(title: title),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
