import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:brisconnect/auth/local_auth.dart';
import 'package:brisconnect/screens/ai_post_sheet.dart';
import 'package:brisconnect/screens/schedule_promotion_screen.dart';
import 'package:brisconnect/services/best_time_to_post_service.dart';
import 'package:brisconnect/services/business_dashboard_service.dart';
import 'package:brisconnect/theme/app_palette.dart';

/// Screen 1 of the Local portal — Business Dashboard.
/// Shows analytics, AI post creation, promotions and notifications.
class BusinessDashboardScreen extends StatelessWidget {
  /// Identifier for the business owner (defaults to the signed-in local email).
  final String ownerId;

  const BusinessDashboardScreen({super.key, this.ownerId = ''});

  @override
  Widget build(BuildContext context) {
    final user = LocalAuth.currentLocal;
    final name = user?.name ?? 'Business Owner';
    final effectiveOwnerId = ownerId.trim().isEmpty ? user?.email ?? '' : ownerId;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(name)),
            SliverToBoxAdapter(
              child: _buildAnalyticsGrid(context, effectiveOwnerId),
            ),
            SliverToBoxAdapter(child: _buildAIPostSection(context)),
            SliverToBoxAdapter(
              child: _buildBestTimeToPostSection(context, effectiveOwnerId),
            ),
            SliverToBoxAdapter(
              child: _buildPromotionsSection(context, effectiveOwnerId),
            ),
            SliverToBoxAdapter(
              child: _buildNotificationsSection(context, user?.email),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────
  Widget _buildHeader(String name) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back,',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 13),
                ),
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppPalette.ochre.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: AppPalette.ochre.withValues(alpha: 0.4)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified_rounded,
                    color: AppPalette.ochre, size: 14),
                SizedBox(width: 4),
                Text('Local Business',
                    style: TextStyle(
                        color: AppPalette.ochre,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Analytics ───────────────────────────────────────────────────────
  Widget _buildAnalyticsGrid(BuildContext context, String ownerId) {
    if (ownerId.trim().isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: _DashboardErrorCard(
          message: 'Sign in to view your business summary.',
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('Analytics'),
          const SizedBox(height: 10),
          StreamBuilder<BusinessDashboardMetrics>(
            stream: BusinessDashboardService().metricsStream(ownerId),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting &&
                  !snap.hasData) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: CircularProgressIndicator(color: AppPalette.ochre),
                  ),
                );
              }

              if (snap.hasError) {
                return _DashboardErrorCard(
                  message: 'Unable to load analytics: ${snap.error}',
                );
              }

              final metrics = snap.data ?? const BusinessDashboardMetrics();

              return LayoutBuilder(
                builder: (context, constraints) {
                  final crossAxisCount = constraints.maxWidth > 600 ? 3 : 2;
                  return GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.05,
                    children: [
                      _AnalyticCard(
                        icon: Icons.visibility_rounded,
                        label: 'Profile Views',
                        value: '${metrics.profileViews}',
                        change: metrics.profileViewsChange,
                        color: const Color(0xFF4F8FFF),
                      ),
                      _AnalyticCard(
                        icon: Icons.bookmark_rounded,
                        label: 'Saves',
                        value: '${metrics.saves}',
                        change: metrics.savesChange,
                        color: const Color(0xFF2ECC71),
                      ),
                      _AnalyticCard(
                        icon: Icons.star_rounded,
                        label: 'New Reviews',
                        value: '${metrics.newReviews}',
                        change: metrics.newReviewsChange,
                        color: const Color(0xFF9B59B6),
                      ),
                      _AnalyticCard(
                        icon: Icons.local_offer_rounded,
                        label: 'Active Promotions',
                        value: '${metrics.activePromotions}',
                        change: metrics.activePromotionsChange,
                        color: AppPalette.ochre,
                      ),
                      _AnalyticCard(
                        icon: Icons.event_rounded,
                        label: 'Upcoming Events',
                        value: '${metrics.upcomingEvents}',
                        change: metrics.upcomingEventsChange,
                        color: const Color(0xFFE74C3C),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  // ── AI Post Creation ────────────────────────────────────────────────
  Widget _buildAIPostSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('AI Post Creation'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF1C1C2E),
                  AppPalette.ochre.withValues(alpha: 0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: AppPalette.ochre.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppPalette.ochre.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.auto_awesome_rounded,
                          color: AppPalette.ochre, size: 20),
                    ),
                    const SizedBox(width: 10),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Generate a Post',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15)),
                        Text('Let AI write your event or promo post',
                            style: TextStyle(
                                color: Color(0xFF8B8FA8), fontSize: 12)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _QuickPostChip(
                          label: '📅 New Event', context: context),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _QuickPostChip(
                          label: '🎉 Promotion', context: context),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _QuickPostChip(
                          label: '📣 Announcement', context: context),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Best Time to Post ───────────────────────────────────────────────
  Widget _buildBestTimeToPostSection(BuildContext context, String ownerId) {
    if (ownerId.trim().isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('Best Time to Post'),
          const SizedBox(height: 10),
          FutureBuilder<BestTimeToPostResult>(
            future: BestTimeToPostService().getRecommendations(ownerId),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting &&
                  !snap.hasData) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: CircularProgressIndicator(color: AppPalette.ochre),
                  ),
                );
              }

              if (snap.hasError) {
                return _DashboardErrorCard(
                  message: 'Unable to load recommendations: ${snap.error}',
                );
              }

              final result = snap.data ?? BestTimeToPostResult.insufficient;

              if (!result.hasEnoughData) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C2E),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppPalette.ochre.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.schedule_rounded,
                            color: AppPalette.ochre, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Not enough data yet',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              result.insufficientDataReason ??
                                  'Keep engaging customers to unlock posting-time insights.',
                              style: const TextStyle(
                                  color: Color(0xFF8B8FA8), fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }

              final recs = result.recommendations;
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C2E),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppPalette.ochre.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...recs.asMap().entries.map((entry) {
                      final index = entry.key;
                      final rec = entry.value;
                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: index == recs.length - 1 ? 0 : 12,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color:
                                    AppPalette.ochre.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  '#${index + 1}',
                                  style: const TextStyle(
                                    color: AppPalette.ochre,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${rec.dayLabel}s ${rec.timeRangeLabel}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    rec.explanation,
                                    style: const TextStyle(
                                      color: Color(0xFF8B8FA8),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _openSchedulePromotion(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppPalette.ochre,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('Schedule a Promotion'),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _openSchedulePromotion(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const SchedulePromotionScreen(),
      ),
    );
  }

  // ── Promotions ──────────────────────────────────────────────────────
  Widget _buildPromotionsSection(BuildContext context, String ownerId) {
    if (ownerId.trim().isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('Promotions'),
          const SizedBox(height: 10),
          StreamBuilder<BusinessDashboardMetrics>(
            stream: BusinessDashboardService().metricsStream(ownerId),
            builder: (context, snap) {
              final metrics = snap.data;
              final hasPromotions = (metrics?.activePromotions ?? 0) > 0;

              if (!hasPromotions) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C2E),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A2A3E),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.local_offer_rounded,
                            color: Color(0xFF4F8FFF), size: 22),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('No active promotions',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14)),
                            SizedBox(height: 2),
                            Text(
                                'Create a promotion to attract more customers',
                                style: TextStyle(
                                    color: Color(0xFF8B8FA8), fontSize: 12)),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded,
                          color: Color(0xFF8B8FA8), size: 14),
                    ],
                  ),
                );
              }

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C2E),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppPalette.ochre.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppPalette.ochre.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.local_offer_rounded,
                          color: AppPalette.ochre, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${metrics!.activePromotions} active promotion${metrics.activePromotions == 1 ? '' : 's'}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Keep them fresh to maximise reach.',
                            style: TextStyle(
                                color: Color(0xFF8B8FA8), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded,
                        color: Color(0xFF8B8FA8), size: 14),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Notifications ───────────────────────────────────────────────────
  Widget _buildNotificationsSection(BuildContext context, String? email) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('Recent Notifications'),
          const SizedBox(height: 10),
          StreamBuilder<QuerySnapshot>(
            stream: email == null
                ? const Stream.empty()
                : FirebaseFirestore.instance
                    .collection('user_notifications')
                    .where('recipientEmail', isEqualTo: email)
                    .orderBy('createdAt', descending: true)
                    .limit(5)
                    .snapshots(),
            builder: (context, snap) {
              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C2E),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.notifications_none_rounded,
                          color: Color(0xFF8B8FA8), size: 22),
                      SizedBox(width: 12),
                      Text('No notifications yet',
                          style: TextStyle(
                              color: Color(0xFF8B8FA8), fontSize: 14)),
                    ],
                  ),
                );
              }
              return Column(
                children: docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return _NotificationTile(data: data);
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.bold,
        ),
      );
}

// ── Analytic Card ─────────────────────────────────────────────────────
class _AnalyticCard extends StatelessWidget {
  const _AnalyticCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.change = 0,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final double change;

  @override
  Widget build(BuildContext context) {
    final isPositive = change >= 0;
    final changeText = change.isFinite
        ? '${isPositive ? '+' : ''}${(change * 100).toStringAsFixed(0)}%'
        : '0%';
    final changeColor = isPositive ? const Color(0xFF2ECC71) : const Color(0xFFE74C3C);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 20),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isPositive ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                    color: changeColor,
                    size: 12,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    changeText,
                    style: TextStyle(
                      color: changeColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                    color: color, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                    color: Color(0xFF8B8FA8), fontSize: 11),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Error Card ────────────────────────────────────────────────────────
class _DashboardErrorCard extends StatelessWidget {
  final String message;

  const _DashboardErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: Color(0xFFE74C3C), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Color(0xFF8B8FA8), fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Quick Post Chip ───────────────────────────────────────────────────
class _QuickPostChip extends StatelessWidget {
  const _QuickPostChip({required this.label, required this.context});
  final String label;
  final BuildContext context;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => AiPostSheet(initialType: label),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A3E),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Center(
          child: Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
              textAlign: TextAlign.center),
        ),
      ),
    );
  }
}

// ── Notification Tile ─────────────────────────────────────────────────
class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final title = (data['title'] as String?) ?? 'Notification';
    final body = (data['body'] as String?) ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C2E),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 5, right: 10),
            decoration: const BoxDecoration(
                color: AppPalette.ochre, shape: BoxShape.circle),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
                if (body.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(body,
                      style: const TextStyle(
                          color: Color(0xFF8B8FA8), fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
