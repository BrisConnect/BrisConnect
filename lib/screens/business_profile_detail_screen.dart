import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:brisconnect/models/business.dart';
import 'package:brisconnect/screens/business_map_screen.dart';
import 'package:brisconnect/services/business_profile_service.dart';
import 'package:brisconnect/services/review_service.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/widgets/logo_app_bar_title.dart';
import 'package:brisconnect/widgets/submit_review_bottom_sheet.dart';
import 'package:brisconnect/widgets/reviews_display_widget.dart';

class BusinessProfileDetailScreen extends StatefulWidget {
  final String businessId;

  const BusinessProfileDetailScreen({
    super.key,
    required this.businessId,
  });

  @override
  State<BusinessProfileDetailScreen> createState() =>
      _BusinessProfileDetailScreenState();
}

class _BusinessProfileDetailScreenState
    extends State<BusinessProfileDetailScreen> {
  final _businessService = BusinessProfileService();
  final _reviewService = ReviewService();
  final _auth = FirebaseAuth.instance;
  Business? _business;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBusinessProfile();
  }

  Future<void> _loadBusinessProfile() async {
    try {
      final business = await _businessService.getBusinessProfile(widget.businessId);
      setState(() {
        _business = business;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading business profile: $e')),
        );
      }
    }
  }

  Future<void> _openDirections() async {
    if (_business?.lat == null || _business?.lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location data not available')),
      );
      return;
    }

    final mapsUrl =
        'https://www.google.com/maps/search/?api=1&query=${_business!.lat},${_business!.lng}';
    try {
      await launchUrl(
        Uri.parse(mapsUrl),
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open directions: $e')),
        );
      }
    }
  }

  Future<void> _openWebsite() async {
    if (_business?.website == null || _business!.website!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Website URL not available')),
      );
      return;
    }

    final url = _business!.website!;
    final fullUrl = url.startsWith('http') ? url : 'https://$url';
    try {
      await launchUrl(
        Uri.parse(fullUrl),
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open website: $e')),
        );
      }
    }
  }

  Future<void> _callBusiness() async {
    if (_business?.contactNumber == null || _business!.contactNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contact number not available')),
      );
      return;
    }

    final telUrl = 'tel:${_business!.contactNumber}';
    try {
      await launchUrl(Uri.parse(telUrl));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not initiate call: $e')),
        );
      }
    }
  }

  void _showReviewBottomSheet() async {
    final user = _auth.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to leave a recommendation')),
      );
      return;
    }

    // Check if user already reviewed
    final hasReviewed = await _reviewService.hasVisitorReviewedBusiness(
      widget.businessId,
      user.uid,
    );

    if (hasReviewed && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You have already recommended this business')),
      );
      return;
    }

    if (mounted) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (context) => SubmitReviewBottomSheet(
          businessId: widget.businessId,
          visitorId: user.uid,
          visitorName: user.displayName ?? 'Anonymous',
          onReviewSubmitted: (reviewId) {
            // Reviews auto-update via stream
          },
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.background,
      appBar: AppBar(
        title: const LogoAppBarTitle('Business Profile'),
        backgroundColor: AppPalette.ochre,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.rate_review_outlined),
            tooltip: 'Recommend this Business',
            onPressed: _showReviewBottomSheet,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _business == null
              ? Center(
                  child: Text(
                    'Business profile not found',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Cover image or background
                      Container(
                        width: double.infinity,
                        height: 200,
                        color: Colors.grey[300],
                        child: _business!.coverImageUrl != null
                            ? Image.network(
                                _business!.coverImageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: Colors.grey[300],
                                  child: const Center(
                                    child: Icon(Icons.business, size: 64),
                                  ),
                                ),
                              )
                            : Center(
                                child: Icon(
                                  Icons.business,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                              ),
                      ),

                      // Logo and info
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Logo
                                if (_business!.logoUrl != null)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(
                                      _business!.logoUrl!,
                                      width: 100,
                                      height: 100,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        width: 100,
                                        height: 100,
                                        decoration: BoxDecoration(
                                          color: Colors.grey[300],
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: const Icon(Icons.business),
                                      ),
                                    ),
                                  )
                                else
                                  Container(
                                    width: 100,
                                    height: 100,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[300],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.business, size: 40),
                                  ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _business!.businessName,
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppPalette.ochre.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          _business!.category,
                                          style: TextStyle(
                                            color: AppPalette.ochre,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      if (_business!.isVerified)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 8.0),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.verified,
                                                color: Colors.green[600],
                                                size: 18,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Verified',
                                                style: TextStyle(
                                                  color: Colors.green[600],
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),

                            // Description
                            Text(
                              'About',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _business!.description,
                              style: TextStyle(
                                color: Colors.grey[700],
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Contact Information
                            Text(
                              'Contact Information',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 12),
                            _InfoRow(
                              icon: Icons.location_on,
                              label: 'Address',
                              value: _business!.address,
                            ),
                            const SizedBox(height: 12),
                            _InfoRow(
                              icon: Icons.phone,
                              label: 'Phone',
                              value: _business!.contactNumber,
                            ),
                            if (_business!.website != null &&
                                _business!.website!.isNotEmpty)
                              Column(
                                children: [
                                  const SizedBox(height: 12),
                                  _InfoRow(
                                    icon: Icons.language,
                                    label: 'Website',
                                    value: _business!.website!,
                                  ),
                                ],
                              ),
                            const SizedBox(height: 24),

                            // Action Buttons
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _openDirections,
                                    icon: const Icon(Icons.directions),
                                    label: const Text('Directions'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppPalette.ochre,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _callBusiness,
                                    icon: const Icon(Icons.call),
                                    label: const Text('Call'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppPalette.ochre,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (_business!.website != null &&
                                _business!.website!.isNotEmpty)
                              Column(
                                children: [
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: _openWebsite,
                                      icon: const Icon(Icons.language),
                                      label: const Text('Visit Website'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppPalette.ochre,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => BusinessMapScreen(
                                        businesses: [_business!],
                                        focusedBusiness: _business,
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.map),
                                label: const Text('View on Map'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppPalette.ochre,
                                  side: const BorderSide(
                                    color: AppPalette.ochre,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),

                            // Reviews Section
                            ReviewsDisplayWidget(
                              businessId: widget.businessId,
                              currentVisitorId: _auth.currentUser?.uid,
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppPalette.ochre, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
