import 'package:flutter/material.dart';
import 'package:brisconnect/features/admin/dashboard/widgets/admin_layout.dart';
import 'package:brisconnect/models/business.dart';
import 'package:brisconnect/services/admin_dashboard_service.dart';
import 'package:brisconnect/theme/app_palette.dart';

/// Ranks businesses by review count so admins can see what's most engaged
/// with across the platform, satisfying the "most reviewed businesses"
/// platform-analytics requirement.
class TopReviewedBusinessesSection extends StatelessWidget {
  const TopReviewedBusinessesSection({
    super.key,
    this.service,
    this.limit = 5,
    this.onViewAll,
  });

  final AdminDashboardService? service;
  final int limit;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    final effectiveService = service ?? AdminDashboardService();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: 'Most Reviewed Businesses', onViewAll: onViewAll),
        const SizedBox(height: 12),
        AdminCard(
          child: StreamBuilder<List<Business>>(
            stream: effectiveService.topReviewedBusinesses(limit: limit),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: CircularProgressIndicator(color: AppPalette.ochre),
                  ),
                );
              }
              final businesses = snapshot.data!;
              if (businesses.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'No reviewed businesses yet',
                    style: TextStyle(color: AppPalette.mutedText),
                  ),
                );
              }
              return Column(
                children: [
                  for (var i = 0; i < businesses.length; i++)
                    _RankedBusinessTile(rank: i + 1, business: businesses[i]),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RankedBusinessTile extends StatelessWidget {
  const _RankedBusinessTile({required this.rank, required this.business});

  final int rank;
  final Business business;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          'Rank $rank: ${business.businessName}, ${business.reviewCount} reviews, '
          'average rating ${business.rating ?? 0}',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppPalette.ochre.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Text(
                '$rank',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppPalette.ochre,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    business.businessName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppPalette.charcoal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    business.category,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppPalette.mutedText,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 16),
                const SizedBox(width: 4),
                Text(
                  '${business.rating ?? 0}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 12),
                Text(
                  '${business.reviewCount} reviews',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppPalette.mutedText,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
