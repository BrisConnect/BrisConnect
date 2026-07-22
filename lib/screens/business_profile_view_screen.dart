import 'package:flutter/material.dart';
import 'package:brisconnect/models/business.dart';
import 'package:brisconnect/services/business_profile_service.dart';
import 'package:brisconnect/services/share/business_share_service.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:url_launcher/url_launcher.dart';

/// Screen to view a business profile
class BusinessProfileViewScreen extends StatefulWidget {
  final String businessId;
  final bool isOwnProfile;
  final BusinessProfileService? businessProfileService;
  final BusinessShareService? shareService;

  const BusinessProfileViewScreen({
    super.key,
    required this.businessId,
    this.isOwnProfile = false,
    this.businessProfileService,
    this.shareService,
  });

  @override
  State<BusinessProfileViewScreen> createState() => _BusinessProfileViewScreenState();
}

class _BusinessProfileViewScreenState extends State<BusinessProfileViewScreen> {
  late final BusinessProfileService _businessProfileService =
      widget.businessProfileService ?? BusinessProfileService();
  late final BusinessShareService _shareService =
      widget.shareService ?? BusinessShareService();
  bool _viewTracked = false;

  @override
  void initState() {
    super.initState();
    _trackView();
  }

  Future<void> _trackView() async {
    if (_viewTracked) return;
    _viewTracked = true;
    try {
      await _businessProfileService.incrementViewCount(widget.businessId);
    } catch (_) {
      // Silently fail so view tracking never blocks the user.
    }
  }

  Future<void> _shareToPlatform(String platform, String businessId, String businessName) async {
    final result = await _shareService.shareToPlatform(
      platform: platform,
      businessId: businessId,
      businessName: businessName,
    );

    if (!mounted) return;

    switch (result) {
      case ShareResult.copied:
        if (platform == 'instagram') {
          _showSnackBar(
            'Link copied! Open Instagram and paste it in your Story, Post caption, or DM.',
            backgroundColor: const Color(0xFFE1306C),
            durationSeconds: 4,
          );
        } else if (platform == 'tiktok') {
          _showSnackBar(
            'Link copied! Open TikTok and paste it in your bio or video description.',
            backgroundColor: const Color(0xFF010101),
            durationSeconds: 4,
          );
        } else {
          _showSnackBar('Link copied to clipboard!');
        }
      case ShareResult.shared:
        _showSnackBar('Shared to ${_shareService.platformLabel(platform)}!');
      case ShareResult.timedOut:
        _showSnackBar(
          'Share took too long. Link copied to clipboard so you can paste it manually.',
          durationSeconds: 4,
        );
      case ShareResult.failed:
        _showSnackBar('Could not complete share. Try again.');
    }
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

  void _showShareSheet(String businessId, String businessName) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1F2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Share $businessName',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              const Text(
                'Let your friends discover this business',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 20),
              // Facebook - direct share
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _shareButton(
                    icon: Icons.facebook,
                    label: 'Facebook',
                    color: const Color(0xFF1877F2),
                    onTap: () {
                      Navigator.pop(ctx);
                      _shareToPlatform('facebook', businessId, businessName);
                    },
                  ),
                  _shareButton(
                    icon: Icons.camera_alt,
                    label: 'Instagram',
                    color: const Color(0xFFE1306C),
                    badge: 'Copy link',
                    onTap: () {
                      Navigator.pop(ctx);
                      _shareToPlatform('instagram', businessId, businessName);
                    },
                  ),
                  _shareButton(
                    icon: Icons.music_note,
                    label: 'TikTok',
                    color: const Color(0xFF010101),
                    badge: 'Copy link',
                    onTap: () {
                      Navigator.pop(ctx);
                      _shareToPlatform('tiktok', businessId, businessName);
                    },
                  ),
                  _shareButton(
                    icon: Icons.share_rounded,
                    label: 'More',
                    color: const Color(0xFF7A8FA6),
                    onTap: () {
                      Navigator.pop(ctx);
                      _shareToPlatform('native', businessId, businessName);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Copy link row
              InkWell(
                onTap: () {
                  Navigator.pop(ctx);
                  _shareToPlatform('copy', businessId, businessName);
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2F3F),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.link_rounded, color: Color(0xFFFF7A1A), size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _shareService.buildBusinessUrl(businessId, businessName),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Copy',
                        style: TextStyle(
                          color: Color(0xFFFF7A1A),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _shareButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    String? badge,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              if (badge != null)
                Positioned(
                  top: -6,
                  right: -6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF7A1A),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badge,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    if (!url.startsWith('http')) {
      url = 'https://$url';
    }
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open $url')),
      );
    }
  }

  Future<void> _launchPhone(String phone) async {
    final url = 'tel:$phone';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open phone dialer')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Business Profile'),
        centerTitle: true,
        actions: [
          StreamBuilder<Business?>(
            stream: _businessProfileService.getBusinessProfileStream(widget.businessId),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data == null) return const SizedBox.shrink();
              final business = snapshot.data!;
              return IconButton(
                icon: const Icon(Icons.share_rounded),
                tooltip: 'Share this business',
                onPressed: () => _showShareSheet(business.id ?? widget.businessId, business.businessName),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<Business?>(
        stream: _businessProfileService.getBusinessProfileStream(widget.businessId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text('Business profile not found'));
          }

          final business = snapshot.data!;

          return SingleChildScrollView(
            child: Column(
              children: [
                // Cover Image
                if (business.coverImageUrl != null)
                  Image.network(
                    business.coverImageUrl!,
                    height: 250,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  )
                else
                  Container(
                    height: 250,
                    width: double.infinity,
                    color: AppPalette.background,
                    child: const Icon(Icons.image_not_supported_rounded, size: 48),
                  ),

                // Main Content
                Padding(
                  padding: EdgeInsets.all(isMobile ? 16 : 32),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Logo and Name Row
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Logo
                              if (business.logoUrl != null)
                                Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    image: DecorationImage(
                                      image: NetworkImage(business.logoUrl!),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                )
                              else
                                Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    color: AppPalette.background,
                                  ),
                                  child: const Icon(Icons.business_rounded, size: 48),
                                ),
                              const SizedBox(width: 16),

                              // Name and Category
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      business.businessName,
                                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    const SizedBox(height: 8),
                                    Chip(
                                      label: Text(business.category),
                                      backgroundColor: AppPalette.ochre.withValues(alpha: 0.2),
                                    ),
                                    if (business.isVerified)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.verified_rounded,
                                              color: Colors.green,
                                              size: 20,
                                            ),
                                            const SizedBox(width: 4),
                                            const Text(
                                              'Verified',
                                              style: TextStyle(color: Colors.green),
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
                          _buildSection(
                            title: 'About',
                            child: Text(business.description),
                          ),

                          const SizedBox(height: 20),

                          // Contact Information
                          _buildSection(
                            title: 'Contact Information',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildContactRow(
                                  icon: Icons.location_on_rounded,
                                  label: 'Address',
                                  value: business.address,
                                ),
                                const SizedBox(height: 12),
                                _buildContactRow(
                                  icon: Icons.phone_rounded,
                                  label: 'Phone',
                                  value: business.contactNumber,
                                  onTap: () => _launchPhone(business.contactNumber),
                                ),
                                if (business.website != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 12),
                                    child: _buildContactRow(
                                      icon: Icons.language_rounded,
                                      label: 'Website',
                                      value: business.website!,
                                      onTap: () => _launchUrl(business.website!),
                                    ),
                                  ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Business Hours
                          if (business.businessHours != null)
                            _buildSection(
                              title: 'Business Hours',
                              child: _buildBusinessHours(business.businessHours!),
                            ),

                          const SizedBox(height: 20),

                          // Social Media
                          if (business.socialMedia != null && business.socialMedia!.isNotEmpty)
                            _buildSection(
                              title: 'Follow Us',
                              child: _buildSocialMediaLinks(business.socialMedia!),
                            ),

                          const SizedBox(height: 24),

                          // Share This Business button (always visible)
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => _showShareSheet(business.id ?? widget.businessId, business.businessName),
                              icon: const Icon(Icons.share_rounded),
                              label: const Text('Share This Business'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF7A1A),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),

                          // Edit Button (if own profile)
                          if (widget.isOwnProfile)
                            SizedBox(
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
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }

  Widget _buildContactRow({
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppPalette.ochre),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelSmall),
                Text(value, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBusinessHours(BusinessHours hours) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ].map((day) {
        final dayHours = hours.getHoursForDay(day);
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(day),
              Text(dayHours?.getDisplayText() ?? 'Closed'),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSocialMediaLinks(Map<String, String> socialMedia) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: socialMedia.entries.map((entry) {
        return _buildSocialMediaButton(entry.key, entry.value);
      }).toList(),
    );
  }

  Widget _buildSocialMediaButton(String platform, String url) {
    IconData icon;
    switch (platform.toLowerCase()) {
      case 'facebook':
        icon = Icons.facebook;
        break;
      case 'instagram':
        icon = Icons.image;
        break;
      case 'twitter':
        icon = Icons.flutter_dash;
        break;
      case 'linkedin':
        icon = Icons.business;
        break;
      case 'tiktok':
        icon = Icons.music_note;
        break;
      case 'youtube':
        icon = Icons.play_circle;
        break;
      default:
        icon = Icons.link;
    }

    return OutlinedButton.icon(
      onPressed: () => _launchUrl(url),
      icon: Icon(icon),
      label: Text(platform),
    );
  }
}
