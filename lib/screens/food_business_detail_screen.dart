import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:brisconnect/auth/visitor_auth.dart';
import 'package:brisconnect/l10n/app_localizations.dart';
import 'package:brisconnect/mixins/locale_listener_mixin.dart';
import 'package:brisconnect/models/food_business.dart';
import 'package:brisconnect/services/business_dashboard_service.dart';
import 'package:brisconnect/services/food_business_service.dart';
import 'package:brisconnect/widgets/crowd_report_widget.dart';
import 'package:brisconnect/widgets/business_reviews_widget.dart';
import 'package:brisconnect/widgets/fallback_image.dart';
import 'package:brisconnect/widgets/visitor_photo_gallery_widget.dart';

class FoodBusinessDetailScreen extends StatefulWidget {
  final String businessId;

  const FoodBusinessDetailScreen({
    super.key,
    required this.businessId,
  });

  @override
  State<FoodBusinessDetailScreen> createState() =>
      _FoodBusinessDetailScreenState();
}

class _FoodBusinessDetailScreenState extends State<FoodBusinessDetailScreen>
    with LocaleListenerMixin<FoodBusinessDetailScreen> {
  final _businessService = FoodBusinessService();
  final _dashboardService = BusinessDashboardService();
  bool _viewTracked = false;

  @override
  void initState() {
    super.initState();
    setupLocaleListener();
    _trackViewOnLoad();
  }

  Future<void> _trackViewOnLoad() async {
    if (_viewTracked) return;
    _viewTracked = true;
    try {
      final business = await _businessService.getBusinessById(widget.businessId);
      if (business != null && mounted) {
        await _trackView(business);
      }
    } catch (_) {
      // Silently fail so analytics never block the UI.
    }
  }

  Future<void> _trackView(FoodBusiness business) async {
    try {
      final visitorId = FirebaseAuth.instance.currentUser?.uid ??
          VisitorAuth.currentVisitor?.email;
      await _dashboardService.recordProfileView(
        widget.businessId,
        visitorId: visitorId,
        ownerId: business.ownerId ?? business.email,
      );
    } catch (_) {
      // Silently fail so analytics never block the user.
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<FoodBusiness?>(
      future: _businessService.getBusinessById(widget.businessId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          final l10n = AppLocalizations.of(context)!;
          return Scaffold(
            appBar: AppBar(title: Text(l10n.foodBusinessDetails)),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError || snapshot.data == null) {
          final l10n = AppLocalizations.of(context)!;
          return Scaffold(
            appBar: AppBar(title: Text(l10n.foodBusinessDetails)),
            body: Center(
              child: Text('Error loading business: ${snapshot.error}'),
            ),
          );
        }

        final business = snapshot.data!;

        return Scaffold(
          appBar: AppBar(
            title: Text(business.name),
            elevation: 0,
          ),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Google Listing Badge
                if (business.isGoogleListing)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    color: const Color(0xFF4285F4).withValues(alpha: 0.1),
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
                // Hero Image
                if (business.imageUrl != null)
                  FallbackImage(
                    imageUrl: business.imageUrl,
                    height: 250,
                    width: double.infinity,
                    category: 'food',
                  )
                else
                  Container(
                    height: 250,
                    width: double.infinity,
                    color: Colors.grey[300],
                    child: const Icon(Icons.restaurant, size: 80),
                  ),
                // Business Header
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        business.name,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      // Cuisine Types
                      if (business.cuisineTypes != null &&
                          business.cuisineTypes!.isNotEmpty)
                        Wrap(
                          spacing: 8,
                          children: business.cuisineTypes!
                              .map(
                                (cuisine) => Chip(
                                  label: Text(cuisine),
                                ),
                              )
                              .toList(),
                        ),
                      const SizedBox(height: 12),
                      // Rating Summary
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber),
                          const SizedBox(width: 8),
                          Text(
                            business.averageRating?.toStringAsFixed(1) ?? 'N/A',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '(${business.reviewCount ?? 0} reviews)',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(),
                // Business Info Section
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'About',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(business.description),
                    ],
                  ),
                ),
                // Contact & Details
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.location_on),
                        title: const Text('Address'),
                        subtitle: Text(business.address),
                      ),
                      if (business.phone != null)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.phone),
                          title: const Text('Phone'),
                          subtitle: Text(business.phone!),
                          onTap: () async {
                            final url = Uri(scheme: 'tel', path: business.phone!);
                            if (await canLaunchUrl(url)) {
                              await launchUrl(url);
                            }
                          },
                        ),
                      if (business.website != null)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.language),
                          title: const Text('Website'),
                          subtitle: Text(business.website!),
                          onTap: () async {
                            final url = Uri.parse(business.website!);
                            if (await canLaunchUrl(url)) {
                              await launchUrl(url, mode: LaunchMode.externalApplication);
                            }
                          },
                        ),
                      if (business.operatingHours != null)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.schedule),
                          title: const Text('Operating Hours'),
                          subtitle: Text(business.operatingHours!),
                        ),
                      if (business.email != null)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.email),
                          title: const Text('Email'),
                          subtitle: Text(business.email!),
                          onTap: () async {
                            final url = Uri(
                              scheme: 'mailto',
                              path: business.email!,
                            );
                            if (await canLaunchUrl(url)) {
                              await launchUrl(url);
                            }
                          },
                        ),
                      if (business.facebookUrl != null)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.facebook),
                          title: const Text('Facebook'),
                          subtitle: Text(business.facebookUrl!),
                          onTap: () async {
                            final url = Uri.parse(business.facebookUrl!);
                            if (await canLaunchUrl(url)) {
                              await launchUrl(
                                url,
                                mode: LaunchMode.externalApplication,
                              );
                            }
                          },
                        ),
                      if (business.instagramUrl != null)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.camera_alt),
                          title: const Text('Instagram'),
                          subtitle: Text(business.instagramUrl!),
                          onTap: () async {
                            final url = Uri.parse(business.instagramUrl!);
                            if (await canLaunchUrl(url)) {
                              await launchUrl(
                                url,
                                mode: LaunchMode.externalApplication,
                              );
                            }
                          },
                        ),
                      if (business.onlineOrderUrl != null)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.shopping_bag),
                          title: const Text('Order Online'),
                          subtitle: Text(business.onlineOrderUrl!),
                          onTap: () async {
                            final url = Uri.parse(business.onlineOrderUrl!);
                            if (await canLaunchUrl(url)) {
                              await launchUrl(
                                url,
                                mode: LaunchMode.externalApplication,
                              );
                            }
                          },
                        ),
                    ],
                  ),
                ),
                const Divider(),
                // Visitor Photo Gallery
                VisitorPhotoGalleryWidget(businessId: widget.businessId),
                const SizedBox(height: 16),
                const Divider(),
                // Crowd Report Widget - only for BrisConnect businesses
                if ((widget.businessId as String? ?? '').isNotEmpty &&
                    !business.isGoogleListing) ...[
                  CrowdReportWidget(eventId: widget.businessId),
                  const SizedBox(height: 22),
                  const Divider(),
                ],
                // Reviews Section - only for BrisConnect businesses
                if (!business.isGoogleListing)
                  BusinessReviewsWidget(
                    businessId: widget.businessId,
                    currentAverageRating: business.averageRating,
                    currentReviewCount: business.reviewCount,
                  )
                else
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4285F4).withValues(alpha: 0.05),
                        border: Border.all(
                          color: const Color(0xFF4285F4).withValues(alpha: 0.3),
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Reviews are only available for BrisConnect-owned businesses. '
                        'This is a Google Listing imported from Google Places.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.blue.shade700,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }
}
