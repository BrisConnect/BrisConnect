import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:brisconnect/auth/visitor_auth.dart';
import 'package:brisconnect/models/business.dart';
import 'package:brisconnect/models/menu_item.dart';
import 'package:brisconnect/models/review.dart';
import 'package:brisconnect/services/business_dashboard_service.dart';
import 'package:brisconnect/services/business_profile_service.dart';
import 'package:brisconnect/services/review_service.dart';
import 'package:brisconnect/services/share/content_share_service.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/widgets/audio_guide_widget.dart';
import 'package:brisconnect/widgets/crowd_report_widget.dart';
import 'package:brisconnect/widgets/share_bottom_sheet.dart';
import 'package:brisconnect/widgets/submit_review_bottom_sheet.dart';
import 'package:url_launcher/url_launcher.dart';

/// Screen to view a business profile
///
/// Refactored to feel like a modern commercial food discovery app
/// (Google Maps / Yelp / OpenTable) while keeping BrisConnect+ branding.
class BusinessProfileViewScreen extends StatefulWidget {
  final String businessId;
  final bool isOwnProfile;
  final BusinessProfileService? businessProfileService;

  const BusinessProfileViewScreen({
    super.key,
    required this.businessId,
    this.isOwnProfile = false,
    this.businessProfileService,
  });

  @override
  State<BusinessProfileViewScreen> createState() =>
      _BusinessProfileViewScreenState();
}

class _BusinessProfileViewScreenState extends State<BusinessProfileViewScreen> {
  late final BusinessProfileService _businessProfileService =
      widget.businessProfileService ?? BusinessProfileService();
  late final BusinessDashboardService _dashboardService =
      BusinessDashboardService();
  late final ReviewService _reviewService = ReviewService();
  final ScrollController _scrollController = ScrollController();
  bool _viewTracked = false;

  @override
  void initState() {
    super.initState();
    _trackView();
    VisitorAuth.savedAttractionsVersion.addListener(_onSavedChanged);
  }

  @override
  void dispose() {
    VisitorAuth.savedAttractionsVersion.removeListener(_onSavedChanged);
    _scrollController.dispose();
    super.dispose();
  }

  void _onSavedChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _trackView() async {
    if (_viewTracked) return;
    _viewTracked = true;
    try {
      final visitorId = FirebaseAuth.instance.currentUser?.uid ??
          VisitorAuth.currentVisitor?.email;
      await _dashboardService.recordProfileView(
        widget.businessId,
        visitorId: visitorId,
      );
    } catch (_) {}
  }

  void _showSnackBar(
    String message, {
    Color? backgroundColor,
    int durationSeconds = 2,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: backgroundColor ?? Colors.green[700],
        duration: Duration(seconds: durationSeconds),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showShareSheet(Business business) {
    showShareBottomSheet(
      context: context,
      type: ShareContentType.business,
      id: business.id ?? widget.businessId,
      title: business.businessName,
      description: 'Check out ${business.businessName} on BrisConnect+!',
      imageUrl: business.coverImageUrl ?? business.logoUrl,
      businessId: business.id ?? widget.businessId,
      businessName: business.businessName,
    );
  }

  Future<void> _launchUrl(String url) async {
    if (!url.startsWith('http')) {
      url = 'https://$url';
    }
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open $url')),
      );
    }
  }

  Future<void> _launchPhone(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open phone dialer')),
      );
    }
  }

  Future<void> _openDirections(Business business) async {
    if (business.lat == null || business.lng == null) return;
    final url =
        'https://www.google.com/maps/dir/?api=1&destination=${business.lat},${business.lng}';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open directions')),
      );
    }
  }

  Future<void> _toggleSaved(Business business) async {
    final businessId = business.id ?? widget.businessId;
    final wasSaved = VisitorAuth.isBusinessSaved(businessId);
    setState(() {});

    final didUpdate = VisitorAuth.toggleSavedBusiness(businessId);
    if (!didUpdate) {
      _showSnackBar('Please log in as a Visitor to save businesses.');
      return;
    }

    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    final isSaved = VisitorAuth.isBusinessSaved(businessId);
    _showSnackBar(
      isSaved
          ? '${business.businessName} saved to Saved Businesses.'
          : '${business.businessName} removed from Saved Businesses.',
    );
    if (isSaved == wasSaved) setState(() {});
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 768;
    final isTablet = width >= 768 && width < 1200;

    return Scaffold(
      backgroundColor: const Color(0xFFEFF4FA),
      body: StreamBuilder<Business?>(
        stream:
            _businessProfileService.getBusinessProfileStream(widget.businessId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text('Business profile not found'));
          }
          final business = snapshot.data!;

          return CustomScrollView(
            controller: _scrollController,
            slivers: [
              _buildSliverAppBar(business, isMobile),
              SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1600),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 16 : 40,
                        vertical: isMobile ? 16 : 32,
                      ),
                      child: isMobile
                          ? _buildMobileLayout(business)
                          : isTablet
                              ? _buildTabletLayout(business)
                              : _buildDesktopLayout(business),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Layouts
  // -------------------------------------------------------------------------
  Widget _buildMobileLayout(Business business) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeaderCard(business, isMobile: true),
        const SizedBox(height: 16),
        _buildActionBar(business),
        const SizedBox(height: 20),
        _buildAboutCard(business),
        const SizedBox(height: 16),
        _buildGalleryCard(business),
        const SizedBox(height: 16),
        if (_hasMenu(business)) _buildMenuCard(business),
        if (_hasMenu(business)) const SizedBox(height: 16),
        _buildAudioGuideCard(business),
        const SizedBox(height: 16),
        _buildCrowdCard(business),
        const SizedBox(height: 16),
        _buildReviewsCard(business),
        const SizedBox(height: 16),
        if (widget.isOwnProfile) ...[
          _buildMenuManagementButton(business),
          const SizedBox(height: 8),
          _buildEditButton(business),
        ],
      ],
    );
  }

  Widget _buildTabletLayout(Business business) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeaderCard(business, isMobile: false),
        const SizedBox(height: 24),
        _buildActionBar(business),
        const SizedBox(height: 28),
        _buildAboutCard(business),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildGalleryCard(business)),
            const SizedBox(width: 20),
            Expanded(child: _buildCrowdCard(business)),
          ],
        ),
        const SizedBox(height: 20),
        if (_hasMenu(business)) _buildMenuCard(business),
        if (_hasMenu(business)) const SizedBox(height: 20),
        _buildAudioGuideCard(business),
        const SizedBox(height: 20),
        _buildReviewsCard(business),
        const SizedBox(height: 20),
        if (widget.isOwnProfile) ...[
          _buildMenuManagementButton(business),
          const SizedBox(height: 8),
          _buildEditButton(business),
        ],
      ],
    );
  }

  Widget _buildDesktopLayout(Business business) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main column
        Expanded(
          flex: 7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderCard(business, isMobile: false),
              const SizedBox(height: 24),
              _buildActionBar(business),
              const SizedBox(height: 28),
              _buildGalleryCard(business),
              const SizedBox(height: 24),
              if (_hasMenu(business)) _buildMenuCard(business),
              if (_hasMenu(business)) const SizedBox(height: 24),
              _buildAudioGuideCard(business),
              const SizedBox(height: 24),
              _buildReviewsCard(business),
            ],
          ),
        ),
        const SizedBox(width: 32),
        // Sidebar
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAboutCard(business),
              const SizedBox(height: 20),
              _buildCrowdCard(business),
              const SizedBox(height: 20),
              if (widget.isOwnProfile) ...[
                _buildMenuManagementButton(business),
                const SizedBox(height: 8),
                _buildEditButton(business),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // App bar
  // -------------------------------------------------------------------------
  SliverAppBar _buildSliverAppBar(Business business, bool isMobile) {
    return SliverAppBar(
      floating: true,
      pinned: true,
      backgroundColor: AppPalette.background,
      surfaceTintColor: Colors.transparent,
      title: Text(
        business.businessName,
        style: const TextStyle(
          color: AppPalette.charcoal,
          fontWeight: FontWeight.w800,
          fontSize: 18,
        ),
      ),
      centerTitle: true,
      actions: [
        _buildIconAction(
          icon: VisitorAuth.isBusinessSaved(
            business.id ?? widget.businessId,
          )
              ? Icons.bookmark_rounded
              : Icons.bookmark_outline_rounded,
          tooltip: 'Save',
          onTap: () => _toggleSaved(business),
        ),
        _buildIconAction(
          icon: Icons.share_rounded,
          tooltip: 'Share',
          onTap: () => _showShareSheet(business),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildIconAction({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return IconButton(
      icon: Icon(icon, color: AppPalette.charcoal),
      tooltip: tooltip,
      onPressed: onTap,
    );
  }

  // -------------------------------------------------------------------------
  // Header card
  // -------------------------------------------------------------------------
  Widget _buildHeaderCard(Business business, {required bool isMobile}) {
    final status = _openStatusForBusiness(business);
    final (label, color) = status ?? ('', Colors.grey);

    return _ContentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo + name row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Hero(
                tag: 'business-logo-${business.id}',
                child: _buildCircularLogo(business),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            business.businessName,
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: AppPalette.charcoal,
                                  height: 1.1,
                                ),
                          ),
                        ),
                        if (business.isVerified)
                          _VerifiedBadge(
                              margin: const EdgeInsets.only(left: 10)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildRatingRow(business),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _CategoryChip(category: business.category),
                        if (business.priceRange != null)
                          _CategoryChip(
                            category: business.priceRange!,
                            isPrice: true,
                          ),
                        _OpenStatusChip(label: label, color: color),
                      ],
                    ),
                    if (status != null && status.$1 == 'Open now')
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          _closingMessage(business),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppPalette.mutedText,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCircularLogo(Business business) {
    final size = MediaQuery.of(context).size.width < 768 ? 80.0 : 110.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppPalette.surfaceAlt,
        border: Border.all(color: Colors.white, width: 4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipOval(
        child: business.logoUrl != null
            ? CachedNetworkImage(
                imageUrl: business.logoUrl!,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  color: AppPalette.surfaceAlt,
                  child: const Icon(Icons.business_rounded,
                      color: AppPalette.mutedText),
                ),
                errorWidget: (_, __, ___) => const Icon(
                  Icons.business_rounded,
                  color: AppPalette.mutedText,
                ),
              )
            : const Icon(
                Icons.business_rounded,
                color: AppPalette.mutedText,
              ),
      ),
    );
  }

  Widget _buildRatingRow(Business business) {
    return StreamBuilder<double>(
      stream: _reviewService.getAverageRatingStream(widget.businessId),
      initialData:
          (business.rating ?? 0) > 0 ? (business.rating!.toDouble()) : 0.0,
      builder: (context, ratingSnapshot) {
        return StreamBuilder<int>(
          stream: _reviewService.getReviewCountStream(widget.businessId),
          initialData: business.reviewCount,
          builder: (context, countSnapshot) {
            final avg = ratingSnapshot.data ?? 0.0;
            final count = countSnapshot.data ?? 0;
            return Row(
              children: [
                const Icon(Icons.star_rounded,
                    color: Color(0xFFF59E0B), size: 22),
                const SizedBox(width: 4),
                Text(
                  avg > 0 ? avg.toStringAsFixed(1) : '0.0',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppPalette.charcoal,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '($count reviews)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppPalette.mutedText,
                  ),
                ),
                if (business.buzzScore > 0) ...[
                  const SizedBox(width: 12),
                  _buildBuzzPill(business.buzzScore),
                ],
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildBuzzPill(double buzzScore) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppPalette.ochre.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.local_fire_department_rounded,
              size: 13, color: AppPalette.ochre),
          const SizedBox(width: 3),
          Text(
            '${buzzScore.round()} buzz',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppPalette.ochre,
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Action bar
  // -------------------------------------------------------------------------
  Widget _buildActionBar(Business business) {
    final hasWebsite = business.website != null && business.website!.isNotEmpty;
    final canNavigate = business.lat != null && business.lng != null;
    final businessId = business.id ?? widget.businessId;
    final isSaved = VisitorAuth.isBusinessSaved(businessId);

    final actions = <Widget>[
      _ActionPill(
        icon: Icons.directions_rounded,
        label: 'Directions',
        color: AppPalette.deepBlue,
        onTap: canNavigate ? () => _openDirections(business) : null,
      ),
      _ActionPill(
        icon: Icons.phone_rounded,
        label: 'Call',
        color: AppPalette.deepBlue,
        onTap: business.contactNumber.isNotEmpty
            ? () => _launchPhone(business.contactNumber)
            : null,
      ),
      if (hasWebsite)
        _ActionPill(
          icon: Icons.language_rounded,
          label: 'Website',
          color: AppPalette.deepBlue,
          onTap: () => _launchUrl(business.website!),
        ),
      _ActionPill(
        icon: isSaved ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
        label: isSaved ? 'Saved' : 'Save',
        color: const Color(0xFF2A2F3F),
        onTap: () => _toggleSaved(business),
      ),
      _ActionPill(
        icon: Icons.share_rounded,
        label: 'Share',
        color: AppPalette.ochre,
        onTap: () => _showShareSheet(business),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final useWrap = constraints.maxWidth >= 600;
        final spacing = 10.0;
        if (useWrap) {
          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            alignment: WrapAlignment.center,
            children: actions,
          );
        }
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children:
                actions.expand((w) => [w, SizedBox(width: spacing)]).toList()
                  ..removeLast(),
          ),
        );
      },
    );
  }

  // -------------------------------------------------------------------------
  // About
  // -------------------------------------------------------------------------
  Widget _buildAboutCard(Business business) {
    final hasDescription = business.description.trim().isNotEmpty;
    return _SectionCard(
      icon: Icons.info_outline_rounded,
      iconColor: AppPalette.deepBlue,
      title: 'About',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasDescription) ...[
            Text(
              business.description,
              style: const TextStyle(
                fontSize: 15,
                height: 1.6,
                color: AppPalette.charcoal,
              ),
            ),
            const SizedBox(height: 24),
          ],
          _buildDetailsGrid(business),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Details grid (replaces separate Contact / Hours / Social cards)
  // -------------------------------------------------------------------------
  Widget _buildDetailsGrid(Business business) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 400) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAddressTile(business),
              const SizedBox(height: 14),
              _buildHoursTile(business),
              const SizedBox(height: 14),
              _buildPhoneTile(business),
              const SizedBox(height: 14),
              _buildPriceRangeTile(business),
              const SizedBox(height: 14),
              _buildWebsiteTile(business),
              const SizedBox(height: 14),
              _buildFeaturesTile(business),
              const SizedBox(height: 14),
              _buildDirectionsTile(business),
              const SizedBox(height: 14),
              _buildSocialTile(business),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildLeftColumn(business)),
            const SizedBox(width: 16),
            Expanded(child: _buildRightColumn(business)),
          ],
        );
      },
    );
  }

  Widget _buildLeftColumn(Business business) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAddressTile(business),
        const SizedBox(height: 14),
        _buildPhoneTile(business),
        const SizedBox(height: 14),
        _buildWebsiteTile(business),
        const SizedBox(height: 14),
        _buildDirectionsTile(business),
      ],
    );
  }

  Widget _buildRightColumn(Business business) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHoursTile(business),
        const SizedBox(height: 14),
        _buildPriceRangeTile(business),
        const SizedBox(height: 14),
        _buildFeaturesTile(business),
        const SizedBox(height: 14),
        _buildSocialTile(business),
      ],
    );
  }

  Widget _buildAddressTile(Business business) {
    final canNavigate = business.lat != null && business.lng != null;
    return _DetailTile(
      icon: Icons.location_on_rounded,
      iconColor: const Color(0xFFEF4444),
      label: 'Address',
      value: business.address,
      onTap: canNavigate ? () => _openDirections(business) : null,
    );
  }

  Widget _buildPhoneTile(Business business) {
    return _DetailTile(
      icon: Icons.phone_rounded,
      iconColor: const Color(0xFF22C55E),
      label: 'Phone',
      value: business.contactNumber.isNotEmpty
          ? business.contactNumber
          : 'Not provided',
      onTap: business.contactNumber.isNotEmpty
          ? () => _launchPhone(business.contactNumber)
          : null,
    );
  }

  Widget _buildWebsiteTile(Business business) {
    final hasWebsite = business.website != null && business.website!.isNotEmpty;
    return _DetailTile(
      icon: Icons.language_rounded,
      iconColor: AppPalette.deepBlue,
      label: 'Website',
      value: hasWebsite ? business.website! : 'Not provided',
      onTap: hasWebsite ? () => _launchUrl(business.website!) : null,
    );
  }

  Widget _buildDirectionsTile(Business business) {
    final canNavigate = business.lat != null && business.lng != null;
    return _DetailTile(
      icon: Icons.directions_rounded,
      iconColor: AppPalette.deepBlue,
      label: 'Directions',
      value: canNavigate ? 'Get directions' : 'Not available',
      onTap: canNavigate ? () => _openDirections(business) : null,
    );
  }

  Widget _buildHoursTile(Business business) {
    final hours = business.businessHours;
    final status = _openStatusForBusiness(business);
    final now = DateTime.now();
    final todayName = DateFormat('EEEE').format(now);
    final todayHours = hours?.getHoursForDay(todayName);
    final hasHours = hours != null;

    String value;
    Color iconColor = const Color(0xFF8B5CF6);
    if (status != null) {
      final (label, color) = status;
      value = '$label · ${todayHours?.getDisplayText() ?? 'Closed'}';
      iconColor = color;
    } else if (todayHours != null) {
      value = todayHours.getDisplayText();
    } else {
      value = 'Not provided';
    }

    return _DetailTile(
      icon: Icons.access_time_filled_rounded,
      iconColor: iconColor,
      label: 'Opening Hours',
      value: value,
      onTap: hasHours ? () => _showFullHoursDialog(business) : null,
      trailing: hasHours
          ? const Icon(Icons.chevron_right_rounded,
              size: 16, color: AppPalette.mutedText)
          : null,
    );
  }

  Widget _buildPriceRangeTile(Business business) {
    final hasPrice =
        business.priceRange != null && business.priceRange!.isNotEmpty;
    return _DetailTile(
      icon: Icons.attach_money_rounded,
      iconColor: const Color(0xFF8B5CF6),
      label: 'Price Range',
      value: hasPrice ? business.priceRange! : 'Not set',
    );
  }

  Widget _buildFeaturesTile(Business business) {
    return _DetailTile(
      icon: Icons.local_offer_rounded,
      iconColor: AppPalette.ochre,
      label: 'Features',
      value: business.category.isNotEmpty ? business.category : 'Not set',
    );
  }

  Widget _buildSocialTile(Business business) {
    final social = business.socialMedia;
    final hasSocial = social != null && social.isNotEmpty;
    return _DetailTile(
      icon: Icons.thumb_up_alt_rounded,
      iconColor: const Color(0xFFE1306C),
      label: 'Social Media',
      value: hasSocial
          ? social.entries.map((e) => _capitalize(e.key)).join(', ')
          : 'Not listed',
      onTap: hasSocial ? () => _launchUrl(social.values.first) : null,
      trailing: hasSocial
          ? const Icon(Icons.chevron_right_rounded,
              size: 16, color: AppPalette.mutedText)
          : null,
    );
  }

  void _showFullHoursDialog(Business business) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Opening Hours'),
        content: SizedBox(
          width: 320,
          child: _buildHoursList(business),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildHoursList(Business business) {
    final hours = business.businessHours;
    final now = DateTime.now();
    final todayName = DateFormat('EEEE').format(now);
    if (hours == null) return const Text('Not provided');
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...[
          'Monday',
          'Tuesday',
          'Wednesday',
          'Thursday',
          'Friday',
          'Saturday',
          'Sunday',
        ].map((day) {
          final dayHours = hours.getHoursForDay(day);
          final isToday = day == todayName;
          return _HoursRow(
            day: day,
            hours: dayHours,
            isToday: isToday,
          );
        }),
      ],
    );
  }

  String _capitalize(String value) {
    if (value.isEmpty) return value;
    return '${value[0].toUpperCase()}${value.substring(1)}';
  }

  // -------------------------------------------------------------------------
  // Gallery
  // -------------------------------------------------------------------------
  Widget _buildGalleryCard(Business business) {
    final photos = business.photos ?? [];
    if (photos.isEmpty) {
      return _SectionCard(
        icon: Icons.photo_camera_rounded,
        iconColor: const Color(0xFF06B6D4),
        title: 'Visitor Photos',
        child: const _EmptyState(
          message: 'No visitor photos yet. Be the first to share a snap!',
          icon: Icons.photo_camera_outlined,
        ),
      );
    }

    final displayed = photos.take(6).toList();
    return _SectionCard(
      icon: Icons.photo_camera_rounded,
      iconColor: const Color(0xFF06B6D4),
      title: 'Visitor Photos',
      trailing: photos.length > 6
          ? TextButton.icon(
              onPressed: () => _openPhotoGallery(business.photos!),
              icon: const Icon(Icons.photo_library_outlined, size: 18),
              label: const Text('View All'),
              style: TextButton.styleFrom(
                foregroundColor: AppPalette.deepBlue,
                textStyle: const TextStyle(fontWeight: FontWeight.w800),
              ),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth > 500 ? 3 : 2;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1,
                ),
                itemCount: displayed.length,
                itemBuilder: (context, index) {
                  return Hero(
                    tag: 'gallery-photo-${business.id}-$index',
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Material(
                          color: AppPalette.surfaceAlt,
                          child: InkWell(
                            onTap: () => _openPhotoLightbox(photos, index),
                            child: CachedNetworkImage(
                              imageUrl: displayed[index],
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(
                                color: AppPalette.surfaceAlt,
                              ),
                              errorWidget: (_, __, ___) => Container(
                                color: AppPalette.surfaceAlt,
                                child: const Icon(
                                    Icons.image_not_supported_rounded,
                                    color: AppPalette.mutedText),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
          if (photos.length <= 6) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _openPhotoGallery(business.photos!),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('View All Photos'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppPalette.deepBlue,
                  side: BorderSide(
                      color: AppPalette.deepBlue.withValues(alpha: 0.25)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  textStyle: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _openPhotoGallery(List<String> photos) {
    _openPhotoLightbox(photos, 0);
  }

  void _openPhotoLightbox(List<String> photos, int initialIndex) {
    showDialog(
      context: context,
      builder: (_) => Dialog.fullscreen(
        backgroundColor: Colors.black.withValues(alpha: 0.96),
        child: Stack(
          children: [
            PageView.builder(
              controller: PageController(initialPage: initialIndex),
              itemCount: photos.length,
              itemBuilder: (context, index) {
                return InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 3,
                  child: Center(
                    child: CachedNetworkImage(
                      imageUrl: photos[index],
                      fit: BoxFit.contain,
                      errorWidget: (_, __, ___) => const Icon(
                        Icons.image_not_supported_rounded,
                        color: Colors.white,
                        size: 64,
                      ),
                    ),
                  ),
                );
              },
            ),
            Positioned(
              top: 16,
              right: 16,
              child: SafeArea(
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Menu
  // -------------------------------------------------------------------------
  bool _hasMenu(Business business) {
    return (business.menuItems != null && business.menuItems!.isNotEmpty) ||
        (business.menuItemsModel != null &&
            business.menuItemsModel!.isNotEmpty);
  }

  List<MenuItem> _menuItems(Business business) {
    if (business.menuItemsModel != null &&
        business.menuItemsModel!.isNotEmpty) {
      return business.menuItemsModel!;
    }
    if (business.menuItems != null) {
      return business.menuItems!
          .where((s) => s.trim().isNotEmpty)
          .map((s) => MenuItem(name: s))
          .toList();
    }
    return [];
  }

  Widget _buildMenuCard(Business business) {
    final items = _menuItems(business);
    return _SectionCard(
      icon: Icons.restaurant_menu_rounded,
      iconColor: AppPalette.ochre,
      title: 'Menu',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 24),
            itemBuilder: (context, index) {
              return _MenuItemTile(item: items[index]);
            },
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Audio guide
  // -------------------------------------------------------------------------
  Widget _buildAudioGuideCard(Business business) {
    final narration = business.audioGuideNarration ?? business.description;
    final helper = business.audioGuideUrl != null
        ? 'Listen to the Food Discovery Guide for ${business.businessName}.'
        : 'Hear what makes ${business.businessName} special.';

    return _SectionCard(
      icon: Icons.record_voice_over_rounded,
      iconColor: const Color(0xFF10B981),
      title: 'Food Discovery Guide',
      child: AiNarrationWidget(
        narrationText: narration,
        helperText: helper,
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Crowd
  // -------------------------------------------------------------------------
  Widget _buildCrowdCard(Business business) {
    // Google Listings don't support crowd reports
    if (business.isGoogleListing) {
      return const SizedBox.shrink();
    }
    
    return _SectionCard(
      icon: Icons.people_alt_rounded,
      iconColor: AppPalette.ochre,
      title: 'Crowd Level',
      child: CrowdReportWidget(
        eventId: business.id ?? widget.businessId,
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Reviews
  // -------------------------------------------------------------------------
  Future<void> _showReviewBottomSheet(Business business) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnackBar('Please sign in to leave a recommendation');
      return;
    }

    final hasReviewed = await _reviewService.hasVisitorReviewedBusiness(
      widget.businessId,
      user.uid,
    );
    if (hasReviewed && mounted) {
      _showSnackBar('You have already recommended this business');
      return;
    }

    if (mounted) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppPalette.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => SubmitReviewBottomSheet(
          businessId: widget.businessId,
          visitorId: user.uid,
          visitorName: user.displayName ?? 'Anonymous',
          onReviewSubmitted: (_) {
            // Reviews auto-update via stream.
          },
        ),
      );
    }
  }

  Widget _buildReviewsCard(Business business) {
    // Google Listings don't support reviews
    if (business.isGoogleListing) {
      return const SizedBox.shrink();
    }
    
    return _SectionCard(
      icon: Icons.rate_review_rounded,
      iconColor: const Color(0xFFF59E0B),
      title: 'Ratings & Reviews',
      trailing: TextButton.icon(
        onPressed: () => _showReviewBottomSheet(business),
        icon: const Icon(Icons.edit_rounded, size: 18),
        label: const Text('Write a Review'),
        style: TextButton.styleFrom(
          foregroundColor: AppPalette.ochre,
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      child: StreamBuilder<List<Review>>(
        stream: _reviewService.getBusinessReviewsStream(
          widget.businessId,
          limit: 10,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            );
          }
          final reviews = snapshot.data ?? [];
          if (reviews.isEmpty) {
            return Column(
              children: [
                const _EmptyState(
                  message:
                      'No reviews yet. Be the first to share your experience!',
                  icon: Icons.rate_review_outlined,
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _showReviewBottomSheet(business),
                    icon: const Icon(Icons.edit_rounded, size: 18),
                    label: const Text('Write a Review'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppPalette.ochre,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      textStyle: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            );
          }

          final displayed = reviews.take(5).toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildReviewSummary(business, reviews.length),
              const SizedBox(height: 16),
              ...displayed.asMap().entries.expand((entry) {
                final review = entry.value;
                final isLast = entry.key == displayed.length - 1;
                return [
                  _ReviewCard(
                    review: review,
                    businessName: business.businessName,
                    onHelpful: () => _markHelpful(review),
                    onReport: () => _reportReview(review),
                  ),
                  if (!isLast) const Divider(height: 24),
                ];
              }),
              if (reviews.length > 5) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _showReviewBottomSheet(business),
                    icon: const Icon(Icons.reviews_outlined),
                    label: const Text('See All Reviews'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppPalette.deepBlue,
                      side: BorderSide(
                          color: AppPalette.deepBlue.withValues(alpha: 0.25)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      textStyle: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildReviewSummary(Business business, int totalReviews) {
    return StreamBuilder<double>(
      stream: _reviewService.getAverageRatingStream(widget.businessId),
      initialData:
          (business.rating ?? 0) > 0 ? business.rating!.toDouble() : 0.0,
      builder: (context, ratingSnapshot) {
        final avg = ratingSnapshot.data ?? 0.0;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7ED),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppPalette.ochre.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppPalette.ochre.withValues(alpha: 0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      avg > 0 ? avg.toStringAsFixed(1) : '0.0',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: AppPalette.charcoal,
                      ),
                    ),
                    const Icon(Icons.star_rounded,
                        color: Color(0xFFF59E0B), size: 14),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      avg > 0 ? 'Excellent' : 'No rating yet',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: AppPalette.charcoal,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$totalReviews review${totalReviews == 1 ? '' : 's'}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppPalette.mutedText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (business.buzzScore > 0) ...[
                      const SizedBox(height: 4),
                      _buildBuzzPill(business.buzzScore),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _markHelpful(Review review) async {
    final user = FirebaseAuth.instance.currentUser;
    final ok = await _reviewService.markHelpful(
      review.id,
      visitorId: user?.uid,
    );
    if (ok && mounted) {
      _showSnackBar('Marked as helpful');
    } else if (mounted) {
      _showSnackBar(
        'Already marked helpful or not signed in.',
        backgroundColor: Colors.orange[700],
      );
    }
  }

  Future<void> _reportReview(Review review) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnackBar('Please sign in to report.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Report Review'),
        content: const Text('Are you sure you want to report this review?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Report', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      try {
        await _reviewService.reportReview(
          review.id,
          'Inappropriate content',
          reporterId: user.uid,
        );
        if (mounted) _showSnackBar('Review reported. Thank you.');
      } catch (e) {
        if (mounted) _showSnackBar('Could not report review.');
      }
    }
  }

  // -------------------------------------------------------------------------
  // Edit
  // -------------------------------------------------------------------------
  Widget _buildEditButton(Business business) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.of(context).pushNamed(
            '/business/edit',
            arguments: business,
          );
        },
        icon: const Icon(Icons.edit_rounded),
        label: const Text('Edit Profile'),
      ),
    );
  }

  Widget _buildMenuManagementButton(Business business) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.of(context).pushNamed(
            '/business/menu',
            arguments: business,
          );
        },
        icon: const Icon(Icons.restaurant_menu_rounded),
        label: const Text('Manage Menu'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppPalette.ochre,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------
  (String, Color)? _openStatusForBusiness(Business business) {
    final hours = business.businessHours;
    if (hours == null) return null;

    final now = DateTime.now();
    final dayName = DateFormat('EEEE').format(now);
    final dayHours = hours.getHoursForDay(dayName);
    if (dayHours == null) return null;

    if (dayHours.isClosed) {
      return ('Closed', const Color(0xFFEF4444));
    }

    final openTime = dayHours.openTime;
    final closeTime = dayHours.closeTime;
    if (openTime == null || closeTime == null) return null;

    final currentMinutes = now.hour * 60 + now.minute;
    final openParts = openTime.split(':');
    final closeParts = closeTime.split(':');
    final openMinutes = int.parse(openParts[0]) * 60 + int.parse(openParts[1]);
    final closeMinutes =
        int.parse(closeParts[0]) * 60 + int.parse(closeParts[1]);

    final isOpen =
        currentMinutes >= openMinutes && currentMinutes < closeMinutes;
    return isOpen
        ? ('Open now', const Color(0xFF10B981))
        : ('Closed', const Color(0xFFEF4444));
  }

  String _closingMessage(Business business) {
    final hours = business.businessHours;
    if (hours == null) return '';
    final now = DateTime.now();
    final dayName = DateFormat('EEEE').format(now);
    final dayHours = hours.getHoursForDay(dayName);
    if (dayHours == null || dayHours.isClosed) return '';

    final closeTime = dayHours.closeTime;
    if (closeTime == null) return '';

    final parts = closeTime.split(':');
    final closeMinutes = int.parse(parts[0]) * 60 + int.parse(parts[1]);
    final currentMinutes = now.hour * 60 + now.minute;
    final remaining = closeMinutes - currentMinutes;

    if (remaining <= 0) return '';
    if (remaining < 60) {
      return 'Closes in $remaining minutes';
    }
    final h = remaining ~/ 60;
    final m = remaining % 60;
    return 'Closes in ${h}h ${m}m';
  }
}

// =============================================================================
// Stateless helper widgets
// =============================================================================

class _ContentCard extends StatelessWidget {
  final Widget child;

  const _ContentCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppPalette.deepBlue.withValues(alpha: 0.12),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget child;
  final Widget? trailing;

  const _SectionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return _ContentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: AppPalette.charcoal,
                        height: 1.2,
                      ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const Padding(
            padding: EdgeInsets.only(top: 12, bottom: 12),
            child: Divider(height: 1),
          ),
          child,
        ],
      ),
    );
  }
}

class _VerifiedBadge extends StatelessWidget {
  final EdgeInsets? margin;

  const _VerifiedBadge({this.margin});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? EdgeInsets.zero,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 16),
          SizedBox(width: 4),
          Text(
            'Verified',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Color(0xFF10B981),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String category;
  final bool isPrice;

  const _CategoryChip({required this.category, this.isPrice = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isPrice
            ? const Color(0xFF8B5CF6).withValues(alpha: 0.12)
            : AppPalette.ochre.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        category,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: isPrice ? const Color(0xFF8B5CF6) : AppPalette.ochre,
        ),
      ),
    );
  }
}

class _OpenStatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _OpenStatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            label == 'Open now'
                ? Icons.access_time_filled_rounded
                : Icons.access_time_rounded,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _ActionPill({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Material(
      color: disabled ? AppPalette.surfaceAlt : AppPalette.surface,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color:
                  disabled ? AppPalette.border : color.withValues(alpha: 0.25),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: disabled ? AppPalette.mutedText : color,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: disabled ? AppPalette.mutedText : color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _DetailTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppPalette.mutedText,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppPalette.charcoal,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );

    if (onTap == null) return content;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: content,
      ),
    );
  }
}

class _HoursRow extends StatelessWidget {
  final String day;
  final DayHours? hours;
  final bool isToday;

  const _HoursRow({
    required this.day,
    required this.hours,
    required this.isToday,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: isToday
          ? BoxDecoration(
              color: AppPalette.deepBlue.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
            )
          : null,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            day,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
              color: AppPalette.charcoal,
            ),
          ),
          Text(
            hours?.getDisplayText() ?? 'Closed',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: hours?.isClosed == true
                  ? AppPalette.mutedText
                  : AppPalette.charcoal,
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuItemTile extends StatelessWidget {
  final MenuItem item;

  const _MenuItemTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (item.imageUrl != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(
              imageUrl: item.imageUrl!,
              width: 72,
              height: 72,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                width: 72,
                height: 72,
                color: AppPalette.surfaceAlt,
              ),
              errorWidget: (_, __, ___) => Container(
                width: 72,
                height: 72,
                color: AppPalette.surfaceAlt,
                child: const Icon(Icons.fastfood_rounded,
                    color: AppPalette.mutedText),
              ),
            ),
          )
        else
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppPalette.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
            ),
            child:
                const Icon(Icons.fastfood_rounded, color: AppPalette.mutedText),
          ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppPalette.charcoal,
                      ),
                    ),
                  ),
                  if (item.formattedPrice.isNotEmpty)
                    Text(
                      item.formattedPrice,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: AppPalette.ochre,
                      ),
                    ),
                ],
              ),
              if (item.description != null && item.description!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  item.description!,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: AppPalette.mutedText,
                  ),
                ),
              ],
              if (item.tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: item.tags.map((tag) => _MenuTag(tag: tag)).toList(),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MenuTag extends StatelessWidget {
  final String tag;

  const _MenuTag({required this.tag});

  @override
  Widget build(BuildContext context) {
    final (color, bg) = _tagStyle(tag);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        tag,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }

  (Color, Color) _tagStyle(String tag) {
    switch (tag.toLowerCase()) {
      case 'popular':
      case 'chef recommendation':
        return (
          const Color(0xFFEA580C),
          const Color(0xFFFFF7ED),
        );
      case 'vegetarian':
      case 'vegan':
        return (
          const Color(0xFF16A34A),
          const Color(0xFFF0FDF4),
        );
      case 'gluten free':
      case 'gluten-free':
        return (
          const Color(0xFF2563EB),
          const Color(0xFFEFF6FF),
        );
      case 'spicy':
        return (
          const Color(0xFFDC2626),
          const Color(0xFFFEF2F2),
        );
      default:
        return (
          const Color(0xFF7C3AED),
          const Color(0xFFF5F3FF),
        );
    }
  }
}

class _ReviewCard extends StatelessWidget {
  final Review review;
  final String? businessName;
  final VoidCallback? onHelpful;
  final VoidCallback? onReport;

  const _ReviewCard({
    required this.review,
    this.businessName,
    this.onHelpful,
    this.onReport,
  });

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('d MMM yyyy').format(review.createdAt);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipOval(
              child: review.visitorPhotoUrl != null
                  ? CachedNetworkImage(
                      imageUrl: review.visitorPhotoUrl!,
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _defaultAvatar(),
                    )
                  : _defaultAvatar(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    review.visitorName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      color: AppPalette.charcoal,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    date,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppPalette.mutedText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star_rounded,
                      color: Color(0xFFF59E0B), size: 16),
                  const SizedBox(width: 3),
                  Text(
                    '${review.rating}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color: AppPalette.charcoal,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (review.buzzRating > 0) ...[
          const SizedBox(height: 10),
          _buildBuzzPill(review.buzzRating),
        ],
        const SizedBox(height: 12),
        Text(
          review.comment,
          style: const TextStyle(
            fontSize: 14,
            height: 1.55,
            color: AppPalette.charcoal,
          ),
        ),
        if (review.photos.isNotEmpty) ...[
          const SizedBox(height: 14),
          SizedBox(
            height: 88,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: review.photos.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                return Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: review.photos[index],
                      width: 88,
                      height: 88,
                      fit: BoxFit.cover,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
        if ((review.reply ?? '').isNotEmpty) ...[
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppPalette.deepBlue.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border(
                left: BorderSide(color: AppPalette.deepBlue, width: 3),
                top: BorderSide(
                    color: AppPalette.deepBlue.withValues(alpha: 0.15)),
                right: BorderSide(
                    color: AppPalette.deepBlue.withValues(alpha: 0.15)),
                bottom: BorderSide(
                    color: AppPalette.deepBlue.withValues(alpha: 0.15)),
              ),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppPalette.deepBlue.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.storefront_rounded,
                              color: AppPalette.deepBlue, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            (businessName?.trim().isNotEmpty ?? false)
                                ? businessName!.trim()
                                : 'Business reply',
                            style: const TextStyle(
                                color: AppPalette.deepBlue,
                                fontWeight: FontWeight.w700,
                                fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    if (review.replyAt != null) ...[
                      const Spacer(),
                      Text(
                        DateFormat('d MMM yyyy').format(review.replyAt!),
                        style: const TextStyle(
                            color: AppPalette.mutedText, fontSize: 11),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  review.reply!,
                  style: const TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: AppPalette.charcoal),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        Row(
          children: [
            _ReviewAction(
              icon: Icons.thumb_up_alt_outlined,
              label: 'Helpful (${review.helpfulCount})',
              onTap: onHelpful,
            ),
            const SizedBox(width: 20),
            _ReviewAction(
              icon: Icons.flag_outlined,
              label: 'Report',
              onTap: onReport,
            ),
          ],
        ),
      ],
    );
  }

  Widget _defaultAvatar() {
    return CircleAvatar(
      radius: 22,
      backgroundColor: AppPalette.ochre.withValues(alpha: 0.12),
      child: Text(
        review.visitorName.isNotEmpty
            ? review.visitorName[0].toUpperCase()
            : '?',
        style: const TextStyle(
          color: AppPalette.ochre,
          fontWeight: FontWeight.w900,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _buildBuzzPill(int buzz) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppPalette.ochre.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.local_fire_department_rounded,
              size: 12, color: AppPalette.ochre),
          const SizedBox(width: 4),
          Text(
            'Buzz $buzz/5',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppPalette.ochre,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ReviewAction({
    required this.icon,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: AppPalette.mutedText),
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppPalette.mutedText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  final IconData? icon;

  const _EmptyState({required this.message, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppPalette.deepBlue.withValues(alpha: 0.12),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon,
                size: 32, color: AppPalette.mutedText.withValues(alpha: 0.6)),
            const SizedBox(height: 10),
          ],
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppPalette.mutedText,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
