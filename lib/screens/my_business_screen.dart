import 'package:flutter/material.dart';
import 'package:brisconnect/models/business.dart';
import 'package:brisconnect/screens/business_events_management_screen.dart';
import 'package:brisconnect/services/business_profile_service.dart';
import 'package:brisconnect/theme/app_palette.dart';

/// Dashboard screen for business owners to manage their profile
class MyBusinessScreen extends StatefulWidget {
  final String userId;

  const MyBusinessScreen({
    super.key,
    required this.userId,
  });

  @override
  State<MyBusinessScreen> createState() => _MyBusinessScreenState();
}

class _MyBusinessScreenState extends State<MyBusinessScreen> {
  final _businessProfileService = BusinessProfileService();

  Future<void> _deleteBusiness(String businessId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Business'),
        content: const Text('Are you sure you want to delete this business profile? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      try {
        await _businessProfileService.deleteBusinessProfile(businessId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Business profile deleted')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Businesses'),
        centerTitle: true,
      ),
      body: StreamBuilder<List<Business>>(
        stream: _businessProfileService.getUserBusinessProfilesStream(widget.userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data == null) {
            return _buildEmptyState();
          }

          final businesses = snapshot.data!;

          if (businesses.isEmpty) {
            return _buildEmptyState();
          }

          return SingleChildScrollView(
            padding: EdgeInsets.all(isMobile ? 16 : 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Businesses',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 20),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: isMobile ? 1 : 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: isMobile ? 1 : 1.2,
                      ),
                      itemCount: businesses.length,
                      itemBuilder: (context, index) {
                        final business = businesses[index];
                        return _buildBusinessCard(business, isMobile);
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.business_rounded,
            size: 64,
            color: AppPalette.mutedText,
          ),
          const SizedBox(height: 16),
          Text(
            'No businesses yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppPalette.mutedText,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first business profile to get started',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppPalette.mutedText,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pushNamed(
                '/business/create',
                arguments: widget.userId,
              );
            },
            icon: const Icon(Icons.add_rounded),
            label: const Text('Create Business Profile'),
          ),
        ],
      ),
    );
  }

  Widget _buildBusinessCard(Business business, bool isMobile) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cover Image
          Container(
            width: double.infinity,
            height: 150,
            decoration: BoxDecoration(
              color: AppPalette.background,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: business.coverImageUrl != null
                ? Image.network(
                    business.coverImageUrl!,
                    fit: BoxFit.cover,
                  )
                : const Icon(Icons.image_not_supported_rounded),
          ),

          // Business Info
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Logo
                      if (business.logoUrl != null)
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            image: DecorationImage(
                              image: NetworkImage(business.logoUrl!),
                              fit: BoxFit.cover,
                            ),
                          ),
                        )
                      else
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: AppPalette.background,
                          ),
                          child: const Icon(Icons.business_rounded, size: 24),
                        ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              business.businessName,
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Chip(
                              label: Text(
                                business.category,
                                style: const TextStyle(fontSize: 11),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              backgroundColor: AppPalette.ochre.withValues(alpha: 0.2),
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Status
                  Row(
                    children: [
                      if (business.isVerified)
                        Chip(
                          label: const Text(
                            'Verified',
                            style: TextStyle(fontSize: 11, color: Colors.green),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          backgroundColor: Colors.green.withValues(alpha: 0.1),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        )
                      else
                        Chip(
                          label: const Text(
                            'Pending Verification',
                            style: TextStyle(fontSize: 11, color: Colors.orange),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          backgroundColor: Colors.orange.withValues(alpha: 0.1),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                    ],
                  ),

                  const Spacer(),

                  // Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pushNamed(
                              '/business/view',
                              arguments: business.id,
                            );
                          },
                          icon: const Icon(Icons.visibility_rounded, size: 18),
                          label: const Text('View'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pushNamed(
                              '/business/edit',
                              arguments: business,
                            );
                          },
                          icon: const Icon(Icons.edit_rounded, size: 18),
                          label: const Text('Edit'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                      if (business.category == 'Restaurant & Cafe')
                        ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        BusinessEventsManagementScreen(
                                          business: business,
                                        ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.event_rounded, size: 18),
                              label: const Text('Events'),
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                foregroundColor: AppPalette.ochre,
                                side: const BorderSide(
                                  color: AppPalette.ochre,
                                ),
                              ),
                            ),
                          ),
                        ],
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => _deleteBusiness(business.id!),
                        icon: const Icon(Icons.delete_rounded,
                            size: 18, color: Colors.red),
                        label: const Text('Delete',
                            style: TextStyle(color: Colors.red)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
