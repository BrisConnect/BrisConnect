import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:brisconnect/auth/local_auth.dart';
import 'package:brisconnect/models/ai_generated_post.dart';
import 'package:brisconnect/screens/ai_post_sheet.dart';
import 'package:brisconnect/screens/schedule_promotion_screen.dart';
import 'package:brisconnect/screens/subscription_plans_screen.dart';
import 'package:brisconnect/services/business_dashboard_service.dart';
import 'package:brisconnect/services/business_insights_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:brisconnect/services/stripe_payment_service.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/utils/checkout_window_export.dart';
import 'package:brisconnect/utils/responsive_utils.dart';
import 'package:brisconnect/widgets/business_dashboard_chef.dart';
import 'package:brisconnect/services/chef_message_service.dart';

/// Shared "3D" card decoration used across the dashboard: a subtle top-left
/// light bevel, a colored ambient glow, and a dark depth shadow so cards
/// appear to lift off the page rather than sit flat.
BoxDecoration dashboardCard3dDecoration({
  required Color borderColor,
  double borderWidth = 1.5,
  Color ambientColor = Colors.black,
  double ambientAlpha = 0.10,
  double radius = 20,
}) {
  return BoxDecoration(
    gradient: const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Colors.white, Color(0xFFF1F5F9)],
    ),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: borderColor, width: borderWidth),
    boxShadow: [
      BoxShadow(
        color: Colors.white.withValues(alpha: 0.9),
        offset: const Offset(-3, -3),
        blurRadius: 8,
      ),
      BoxShadow(
        color: ambientColor.withValues(alpha: ambientAlpha),
        offset: const Offset(0, 8),
        blurRadius: 24,
        spreadRadius: -4,
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.14),
        offset: const Offset(6, 12),
        blurRadius: 22,
        spreadRadius: -6,
      ),
    ],
  );
}

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
    final effectiveOwnerId =
        ownerId.trim().isEmpty ? user?.email ?? '' : ownerId;
    final width = ResponsiveUtils.widthOf(context);
    final horizontalPadding = width >= Breakpoints.desktop
        ? 32.0
        : width >= Breakpoints.mobile && width < Breakpoints.tablet
            ? 24.0
            : 16.0;

    return Scaffold(
      backgroundColor: const Color(0xFFEBF4FF),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _buildHeader(
                name,
                horizontalPadding: horizontalPadding,
              ),
            ),
            SliverToBoxAdapter(
              child: _buildDashboardBody(
                context,
                effectiveOwnerId,
                horizontalPadding: horizontalPadding,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────
  Widget _buildHeader(String name, {required double horizontalPadding}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= Breakpoints.desktop;
        return Padding(
          padding:
              EdgeInsets.fromLTRB(horizontalPadding, 20, horizontalPadding, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back,',
                      style: TextStyle(
                          color: AppPalette.charcoal,
                          fontSize: isDesktop ? 15 : 13),
                    ),
                    Text(
                      name,
                      style: TextStyle(
                        color: AppPalette.charcoal,
                        fontSize: isDesktop ? 28 : 22,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppPalette.ochre.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: AppPalette.ochre.withValues(alpha: 0.4)),
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
      },
    );
  }

  // ── Dashboard body (hybrid layout) ───────────────────────────────────
  Widget _buildDashboardBody(
    BuildContext context,
    String ownerId, {
    required double horizontalPadding,
  }) {
    if (ownerId.trim().isEmpty) {
      return Padding(
        padding:
            EdgeInsets.fromLTRB(horizontalPadding, 12, horizontalPadding, 0),
        child: const _DashboardErrorCard(
          message: 'Sign in to view your business summary.',
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(horizontalPadding, 16, horizontalPadding, 0),
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _subscriptionStream(ownerId),
        builder: (context, subscriptionSnap) {
          final subscriptionData = subscriptionSnap.data?.data();
          final status = subscriptionData?['status']?.toString() ?? 'none';
          final isActive = status == 'active' || status == 'trialing';

          return StreamBuilder<BusinessDashboardMetrics>(
            stream: BusinessDashboardService().metricsStream(ownerId),
            builder: (context, metricsSnap) {
              if (metricsSnap.connectionState == ConnectionState.waiting &&
                  !metricsSnap.hasData) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: CircularProgressIndicator(color: AppPalette.ochre),
                  ),
                );
              }

              if (metricsSnap.hasError) {
                return _DashboardErrorCard(
                  message: 'Unable to load analytics: ${metricsSnap.error}',
                );
              }

              final metrics =
                  metricsSnap.data ?? const BusinessDashboardMetrics();

              return StreamBuilder<BusinessDailyHistory>(
                stream: BusinessDashboardService().dailyHistoryStream(ownerId),
                builder: (context, historySnap) {
                  final history =
                      historySnap.data ?? const BusinessDailyHistory();

                  return StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _promotionPlansStream(),
                    builder: (context, plansSnap) {
                      final plans =
                          plansSnap.data ?? <Map<String, dynamic>>[];

                      // Prefer Firestore doc ID, then Stripe price ID, then
                      // the plan type as a stable fallback. The Cloud
                      // Function accepts any of these and resolves the plan.
                      Map<String, dynamic> findPlan(String type) {
                        final matched = plans.firstWhere(
                          (p) => p['type']?.toString().toLowerCase() == type,
                          orElse: () => <String, dynamic>{},
                        );
                        if (matched.isEmpty) return matched;
                        return {
                          ...matched,
                          'id': matched['id']?.toString() ??
                              matched['stripePriceId']?.toString() ??
                              type,
                        };
                      }

                      final promotionDayPlan = findPlan('promotionday');
                      final featuredPlan = findPlan('featured');

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionLabel('Overview'),
                          const SizedBox(height: 10),
                          _buildKpiRow(metrics),
                          const SizedBox(height: 24),
                          _buildAiAndSubscriptionRow(
                            context,
                            isActive,
                            subscriptionData,
                            metrics,
                            ownerId,
                          ),
                          const SizedBox(height: 24),
                          _sectionLabel('Promote Your Business'),
                          const SizedBox(height: 10),
                          _buildPromotionsRow(
                            context,
                            ownerId,
                            promotionDayPlan,
                            featuredPlan,
                          ),
                          const SizedBox(height: 24),
                          _sectionLabel('Performance Overview'),
                          const SizedBox(height: 10),
                          _PerformanceOverviewCard(history: history),
                          const SizedBox(height: 24),
                          _sectionLabel('More Metrics'),
                          const SizedBox(height: 10),
                          _buildSecondaryMetricsRow(metrics),
                        ],
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  // ── Row 1: compact KPI cards ─────────────────────────────────────────
  Widget _buildKpiRow(BusinessDashboardMetrics metrics) {
    final items = [
      _CompactKpiCard(
        icon: Icons.visibility_rounded,
        label: 'Profile Views',
        value: '${metrics.profileViews}',
        change: metrics.profileViewsChange,
        color: const Color(0xFF4F8FFF),
      ),
      _CompactKpiCard(
        icon: Icons.bookmark_rounded,
        label: 'Saves',
        value: '${metrics.saves}',
        change: metrics.savesChange,
        color: const Color(0xFF2ECC71),
      ),
      _CompactKpiCard(
        icon: Icons.campaign_rounded,
        label: 'Active Promotions',
        value: '${metrics.activePromotions}',
        showChange: false,
        color: const Color(0xFF10B981),
      ),
      _CompactKpiCard(
        icon: Icons.share_rounded,
        label: 'Social Shares',
        value: '${metrics.totalSocialShares}',
        change: metrics.socialSharesChange,
        color: AppPalette.deepBlue,
      ),
      _CompactKpiCard(
        icon: Icons.star_rounded,
        label: 'Reviews',
        value: '${metrics.totalReviews}',
        change: metrics.newReviewsChange,
        color: const Color(0xFF9B59B6),
      ),
    ];
    return _kpiGrid(items);
  }

  // ── Bottom: secondary metrics ─────────────────────────────────────────
  Widget _buildSecondaryMetricsRow(BusinessDashboardMetrics metrics) {
    final items = [
      _CompactKpiCard(
        icon: Icons.trending_up_rounded,
        label: 'Buzz Score',
        value: metrics.buzzScore.toStringAsFixed(1),
        color: const Color(0xFF3BD0EE),
        showChange: false,
      ),
      _CompactKpiCard(
        icon: Icons.how_to_vote_rounded,
        label: 'Buzz Votes',
        value: '${metrics.totalBuzzVotes}',
        color: const Color(0xFF3BD0EE),
        showChange: false,
      ),
      _CompactKpiCard(
        icon: Icons.thumb_up_rounded,
        label: 'Avg Rating',
        value: metrics.averageRating.toStringAsFixed(1),
        color: const Color(0xFF2ECC71),
        showChange: false,
      ),
      _CompactKpiCard(
        icon: Icons.people_rounded,
        label: metrics.crowdLevel != null
            ? 'Crowd: ${metrics.crowdLevel}'
            : 'Live Crowd',
        value: metrics.crowdLevel != null
            ? '${metrics.crowdReportCount} reports'
            : 'No reports',
        color: const Color(0xFFF39C12),
        showChange: false,
      ),
    ];
    return _kpiGrid(items);
  }

  Widget _kpiGrid(List<Widget> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount =
            constraints.maxWidth >= Breakpoints.mobile ? 4 : 2;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: items,
        );
      },
    );
  }

  // ── Row 2: AI Tools/Insights (⅔) + Subscription + Assistant (⅓) ──
  Widget _buildAiAndSubscriptionRow(
    BuildContext context,
    bool isActive,
    Map<String, dynamic>? subscriptionData,
    BusinessDashboardMetrics metrics,
    String ownerId,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= Breakpoints.desktop;
        if (isDesktop) {
          final businessName = LocalAuth.currentLocal?.name ?? 'Business';
          final chefMessage = ChefMessageService.getContextualMessage(metrics);
          
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left column: AI Tools + AI Insights (stacked, flex 2)
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAiToolsCard(context, isActive, subscriptionData),
                    const SizedBox(height: 16),
                    _buildAiInsightsCard(context, metrics),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Right column: Subscription + AI Assistant (stacked, flex 1)
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSubscriptionSlot(context, isActive, subscriptionData),
                    const SizedBox(height: 16),
                    // AI Assistant card with quick actions
                    AiAssistantCard(
                      businessName: businessName,
                      message: chefMessage,
                      onCreatePost: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          useSafeArea: true,
                          builder: (_) => const AiPostSheet(),
                        );
                      },
                      onViewInsights: () {
                        // Navigate to business insights or detailed analytics
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        }

        // Mobile/tablet layout: stack everything vertically
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAiToolsCard(context, isActive, subscriptionData),
            const SizedBox(height: 16),
            _buildAiInsightsCard(context, metrics),
            const SizedBox(height: 16),
            _buildSubscriptionSlot(context, isActive, subscriptionData),
          ],
        );
      },
    );
  }

  Widget _buildSubscriptionSlot(
    BuildContext context,
    bool isActive,
    Map<String, dynamic>? subscriptionData,
  ) {
    final isFreeTrial = subscriptionData?['isFreeTrial'] == true &&
        subscriptionData?['status'] == 'trialing';
    if (isFreeTrial) return _buildFreeTrialCard(context, subscriptionData);
    if (isActive) return _buildSubscriptionCard(context, subscriptionData);
    return _buildUpgradePromptCard(context);
  }

  Widget _buildFreeTrialCard(
    BuildContext context,
    Map<String, dynamic>? subscriptionData,
  ) {
    final trialEndsAt = subscriptionData?['trialEndsAt'];
    var daysLeft = 0;
    if (trialEndsAt is Timestamp) {
      daysLeft = trialEndsAt.toDate().difference(DateTime.now()).inDays + 1;
      if (daysLeft < 0) daysLeft = 0;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: dashboardCard3dDecoration(
        borderColor: AppPalette.deepBlue.withValues(alpha: 0.3),
        ambientColor: AppPalette.deepBlue,
        ambientAlpha: 0.12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Subscription',
            style: TextStyle(
              color: AppPalette.charcoal,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),
          Icon(Icons.workspace_premium_rounded,
              color: AppPalette.deepBlue.withValues(alpha: 0.85), size: 28),
          const SizedBox(height: 10),
          Text(
            'Free trial • $daysLeft day${daysLeft == 1 ? '' : 's'} left',
            style: const TextStyle(
              color: AppPalette.charcoal,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Enjoying AI tools and promotion features? Subscribe to keep access after your trial ends.',
            style: TextStyle(
              color: AppPalette.charcoal,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _openSubscriptionPlans(context),
              icon: const Icon(Icons.lock_open_rounded, size: 16),
              label: const Text('Subscribe Now'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppPalette.ochre,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpgradePromptCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: dashboardCard3dDecoration(
        borderColor: AppPalette.charcoal.withValues(alpha: 0.16),
        ambientColor: AppPalette.deepBlue,
        ambientAlpha: 0.10,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Subscription',
            style: TextStyle(
              color: AppPalette.charcoal,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),
          Icon(Icons.workspace_premium_rounded,
              color: AppPalette.ochre.withValues(alpha: 0.85), size: 28),
          const SizedBox(height: 10),
          const Text(
            'No active plan',
            style: TextStyle(
              color: AppPalette.charcoal,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Upgrade to unlock AI tools and premium insights.',
            style: TextStyle(
              color: AppPalette.charcoal,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _openSubscriptionPlans(context),
              icon: const Icon(Icons.lock_open_rounded, size: 16),
              label: const Text('Upgrade'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppPalette.ochre,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> _subscriptionStream(
    String ownerId,
  ) {
    return FirebaseFirestore.instance
        .collection('business_subscriptions')
        .doc(ownerId)
        .snapshots();
  }

  Stream<List<Map<String, dynamic>>> _promotionPlansStream() {
    return FirebaseFirestore.instance
        .collection('promotion_plans')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((d) => d.data()).toList());
  }

  Widget _buildAiToolsCard(
    BuildContext context,
    bool isActive,
    Map<String, dynamic>? subscriptionData,
  ) {
    final isFreeTrial = subscriptionData?['isFreeTrial'] == true &&
        subscriptionData?['status'] == 'trialing';
    final trialEndsAt = subscriptionData?['trialEndsAt'];
    int? trialDaysLeft;
    if (isFreeTrial && trialEndsAt is Timestamp) {
      trialDaysLeft =
          trialEndsAt.toDate().difference(DateTime.now()).inDays + 1;
      if (trialDaysLeft < 0) trialDaysLeft = 0;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: dashboardCard3dDecoration(
        borderColor: AppPalette.ochre.withValues(alpha: 0.4),
        borderWidth: 2,
        ambientColor: AppPalette.ochre,
        ambientAlpha: 0.12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isFreeTrial
                      ? AppPalette.deepBlue.withValues(alpha: 0.12)
                      : isActive
                          ? const Color(0xFFD1FAE5)
                          : AppPalette.ochre.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isFreeTrial
                      ? 'FREE TRIAL • ${trialDaysLeft ?? 0} DAYS LEFT'
                      : isActive
                          ? 'BRISCONNECT+ • ACTIVE'
                          : 'PREMIUM',
                  style: TextStyle(
                    color: isFreeTrial
                        ? AppPalette.deepBlue
                        : isActive
                            ? const Color(0xFF065F46)
                            : AppPalette.ochre,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded,
                  color: AppPalette.ochre.withValues(alpha: 0.9), size: 24),
              const SizedBox(width: 10),
              const Text(
                'AI Tools',
                style: TextStyle(
                  color: AppPalette.charcoal,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Create AI-powered content and optimise when you publish.',
            style: TextStyle(
              color: AppPalette.charcoal,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          _featureRow(
            icon: Icons.edit_note_rounded,
            label: 'AI Post Creator',
            locked: !isActive,
            onTap: isActive
                ? () => _openAIPostCreator(context)
                : null,
          ),
          const SizedBox(height: 12),
          _featureRow(
            icon: Icons.schedule_rounded,
            label: 'Best Time to Post',
            locked: !isActive,
          ),
          const SizedBox(height: 18),
          if (isActive)
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: () => _openBillingPortal(context),
                icon: const Icon(Icons.settings_rounded, size: 16),
                label: const Text('Manage Subscription'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppPalette.ochre,
                  side: BorderSide(color: AppPalette.ochre),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _openSubscriptionPlans(context),
                icon: const Icon(Icons.lock_open_rounded, size: 16),
                label: const Text('Upgrade to BrisConnect+'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppPalette.ochre,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAiInsightsCard(
    BuildContext context,
    BusinessDashboardMetrics metrics,
  ) {
    return _AiInsightsCard(
      metrics: metrics,
      businessName: LocalAuth.currentLocal?.name ?? 'your business',
    );
  }

  Widget _featureRow({
    required IconData icon,
    required String label,
    bool locked = false,
    VoidCallback? onTap,
  }) {
    final child = Row(
      children: [
        Icon(
          icon,
          color: locked
              ? AppPalette.mutedText.withValues(alpha: 0.5)
              : AppPalette.ochre,
          size: 18,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: locked ? AppPalette.mutedText : AppPalette.charcoal,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        if (locked)
          Icon(
            Icons.lock_rounded,
            color: AppPalette.mutedText.withValues(alpha: 0.5),
            size: 14,
          )
        else if (onTap != null)
          Icon(
            Icons.arrow_forward_ios_rounded,
            color: AppPalette.ochre.withValues(alpha: 0.6),
            size: 14,
          ),
      ],
    );

    if (onTap == null || locked) return child;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: child,
      ),
    );
  }

  Widget _buildSubscriptionCard(
    BuildContext context,
    Map<String, dynamic>? subscriptionData,
  ) {
    final planId = subscriptionData?['planId']?.toString() ?? '';

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: planId.isEmpty
          ? null
          : FirebaseFirestore.instance
              .collection('subscription_plans')
              .doc(planId)
              .get(),
      builder: (context, planSnap) {
        final planData = planSnap.data?.data();
        final priceCents = (planData?['priceCents'] as num?)?.toInt() ??
            (subscriptionData?['amountCents'] as num?)?.toInt() ??
            999;
        final interval =
            planData?['interval']?.toString().toLowerCase() ?? 'monthly';
        final planName = planData?['name']?.toString() ??
            subscriptionData?['planName']?.toString() ??
            'BrisConnect+ Premium';
        final nextBillingDate =
            _formatDate(subscriptionData?['currentPeriodEnd']);

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: dashboardCard3dDecoration(
            borderColor: AppPalette.charcoal.withValues(alpha: 0.16),
            ambientColor: AppPalette.deepBlue,
            ambientAlpha: 0.10,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Subscription',
                style: TextStyle(
                  color: AppPalette.charcoal,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF10B981),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Active',
                    style: TextStyle(
                      color: const Color(0xFF065F46),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                planName,
                style: const TextStyle(
                  color: AppPalette.charcoal,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_formatPrice(priceCents)} / ${interval == 'yearly' ? 'year' : 'month'}',
                style: const TextStyle(
                  color: AppPalette.charcoal,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Next billing date',
                style: TextStyle(
                  color: AppPalette.charcoal,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                nextBillingDate,
                style: const TextStyle(
                  color: AppPalette.charcoal,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _openBillingPortal(context),
                  icon: const Icon(Icons.settings_rounded, size: 16),
                  label: const Text('Manage Subscription'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppPalette.ochre,
                    side: BorderSide(color: AppPalette.ochre),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPromotionsRow(
    BuildContext context,
    String ownerId,
    Map<String, dynamic> promotionDayPlan,
    Map<String, dynamic> featuredPlan,
  ) {
    final promotionDayId = promotionDayPlan['id']?.toString() ??
        promotionDayPlan['stripePriceId']?.toString() ??
        '';
    final featuredId = featuredPlan['id']?.toString() ??
        featuredPlan['stripePriceId']?.toString() ??
        '';
    final promotionDayCents =
        (promotionDayPlan['priceCents'] as num?)?.toInt() ?? 499;
    final featuredCents =
        (featuredPlan['priceCents'] as num?)?.toInt() ?? 999;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= Breakpoints.tablet;
        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 5,
                child: _buildCreatePromotionCard(context),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 4,
                child: _buildPaidPromotionCard(
                  context: context,
                  ownerId: ownerId,
                  icon: Icons.rocket_launch_rounded,
                  iconColor: const Color(0xFF10B981),
                  iconBgColor: const Color(0xFFD1FAE5),
                  title: 'Boost this promotion',
                  subtitle: 'Get more visibility and attract more customers.',
                  price: '${_formatPrice(promotionDayCents)} / day',
                  planId: promotionDayId,
                  planName: 'Promotion Day',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 4,
                child: _buildPaidPromotionCard(
                  context: context,
                  ownerId: ownerId,
                  icon: Icons.diamond_rounded,
                  iconColor: AppPalette.deepBlue,
                  iconBgColor: const Color(0xFFDBEAFE),
                  title: 'Feature my business',
                  subtitle: 'Highlight your business on BrisConnect.',
                  price: _formatPrice(featuredCents),
                  planId: featuredId,
                  planName: 'Featured Listing',
                ),
              ),
            ],
          );
        }

        return Column(
          children: [
            _buildCreatePromotionCard(context),
            const SizedBox(height: 12),
            _buildPaidPromotionCard(
              context: context,
              ownerId: ownerId,
              icon: Icons.rocket_launch_rounded,
              iconColor: const Color(0xFF10B981),
              iconBgColor: const Color(0xFFD1FAE5),
              title: 'Boost this promotion',
              subtitle: 'Get more visibility and attract more customers.',
              price: '${_formatPrice(promotionDayCents)} / day',
              planId: promotionDayId,
              planName: 'Promotion Day',
            ),
            const SizedBox(height: 12),
            _buildPaidPromotionCard(
              context: context,
              ownerId: ownerId,
              icon: Icons.diamond_rounded,
              iconColor: AppPalette.deepBlue,
              iconBgColor: const Color(0xFFDBEAFE),
              title: 'Feature my business',
              subtitle: 'Highlight your business on BrisConnect.',
              price: _formatPrice(featuredCents),
              planId: featuredId,
              planName: 'Featured Listing',
            ),
          ],
        );
      },
    );
  }

  Widget _buildCreatePromotionCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: dashboardCard3dDecoration(
        borderColor: AppPalette.ochre.withValues(alpha: 0.4),
        borderWidth: 2,
        ambientColor: AppPalette.ochre,
        ambientAlpha: 0.14,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7F3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.local_offer_rounded,
              color: AppPalette.ochre,
              size: 22,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Create Promotion',
            style: TextStyle(
              color: AppPalette.charcoal,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Create a promotion for your business.',
            style: TextStyle(
              color: AppPalette.charcoal,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _openSchedulePromotion(context),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Create Promotion'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppPalette.ochre,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaidPromotionCard({
    required BuildContext context,
    required String ownerId,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String subtitle,
    required String price,
    required String planId,
    required String planName,
  }) {
    return InkWell(
      onTap: planId.isEmpty
          ? () => _showSnackBar(context, 'Plan is not available.')
          : () => _startPromotionCheckout(context, ownerId, planId, planName),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: dashboardCard3dDecoration(
          borderColor: AppPalette.charcoal.withValues(alpha: 0.16),
          ambientColor: AppPalette.deepBlue,
          ambientAlpha: 0.10,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppPalette.charcoal,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppPalette.charcoal,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    price,
                    style: TextStyle(
                      color: iconColor,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: AppPalette.mutedText.withValues(alpha: 0.5),
              size: 14,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startPromotionCheckout(
    BuildContext context,
    String ownerId,
    String planId,
    String planName,
  ) async {
    final checkoutWindow = kIsWeb ? openBlankCheckoutWindow() : null;
    if (kIsWeb && (checkoutWindow == null || !checkoutWindow.isOpen)) {
      _showSnackBar(
        context,
        'Could not open checkout. Please allow pop-ups for this site.',
      );
      return;
    }

    final opened = await StripePaymentService.startPromotionCheckout(
      ownerId: ownerId,
      planId: planId,
      promotionTitle: planName,
      checkoutWindow: checkoutWindow,
    );

    if (!opened) {
      checkoutWindow?.close();
      if (context.mounted) {
        _showSnackBar(
          context,
          StripePaymentService.lastErrorMessage ??
              'Could not open checkout. Please try again.',
        );
      }
    }
  }

  void _openBillingPortal(BuildContext context) async {
    final ownerId = LocalAuth.currentLocal?.email ?? '';
    if (ownerId.trim().isEmpty) return;

    // Open a blank window synchronously from the user tap so the browser
    // does not block the Stripe Customer Portal pop-up.
    final checkoutWindow = kIsWeb ? openBlankCheckoutWindow() : null;
    if (kIsWeb && (checkoutWindow == null || !checkoutWindow.isOpen)) {
      _showSnackBar(
        context,
        'Could not open portal. Please allow pop-ups for this site.',
      );
      return;
    }

    final opened = await StripePaymentService.openBillingPortal(
      ownerId: ownerId,
      checkoutWindow: checkoutWindow,
    );

    if (!opened && context.mounted) {
      checkoutWindow?.close();
      _showSnackBar(
        context,
        StripePaymentService.lastErrorMessage ??
            'Could not open billing portal.',
      );
    }
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppPalette.charcoal,
      ),
    );
  }

  String _formatDate(dynamic value) {
    DateTime? date;
    if (value is Timestamp) date = value.toDate();
    if (value is DateTime) date = value;
    if (value is int) {
      date = DateTime.fromMillisecondsSinceEpoch(value * 1000);
    }
    if (date == null) return '—';
    return '${date.day} ${_monthName(date.month)} ${date.year}';
  }

  String _monthName(int month) {
    const names = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return names[month - 1];
  }

  String _formatPrice(int cents) {
    return '\$${(cents / 100).toStringAsFixed(2)}';
  }

  void _openSchedulePromotion(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const SchedulePromotionScreen(),
      ),
    );
  }

  void _openAIPostCreator(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AiPostSheet(
        initialType: AiPostType.businessEvent,
      ),
    );
  }

  void _openSubscriptionPlans(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const SubscriptionPlansScreen(),
      ),
    );
  }

  Widget _sectionLabel(String text) => LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= Breakpoints.desktop;
          return Text(
            text,
            style: TextStyle(
              color: AppPalette.charcoal,
              fontSize: isDesktop ? 17 : 15,
              fontWeight: FontWeight.bold,
            ),
          );
        },
      );
}

// ── AI Insights Card ──────────────────────────────────────────────────
class _AiInsightsCard extends StatefulWidget {
  final BusinessDashboardMetrics metrics;
  final String businessName;

  const _AiInsightsCard({
    required this.metrics,
    required this.businessName,
  });

  @override
  State<_AiInsightsCard> createState() => _AiInsightsCardState();
}

class _AiInsightsCardState extends State<_AiInsightsCard> {
  List<Map<String, String>>? _suggestions;
  bool _loading = false;
  String? _error;

  Future<void> _loadSuggestions() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final suggestions = await BusinessInsightsService().getSuggestions(
        metrics: widget.metrics,
        businessName: widget.businessName,
      );
      if (mounted) {
        setState(() {
          _suggestions = suggestions;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: dashboardCard3dDecoration(
        borderColor: AppPalette.ochre.withValues(alpha: 0.4),
        borderWidth: 2,
        ambientColor: AppPalette.ochre,
        ambientAlpha: 0.12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded,
                  color: AppPalette.ochre.withValues(alpha: 0.9), size: 24),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Gemini Insights',
                  style: TextStyle(
                    color: AppPalette.charcoal,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (_suggestions != null)
                IconButton(
                  onPressed: _loading ? null : _loadSuggestions,
                  icon: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded,
                          color: AppPalette.ochre),
                  tooltip: 'Refresh suggestions',
                ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'AI-powered suggestions to improve your business performance.',
            style: TextStyle(
              color: AppPalette.charcoal,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: CircularProgressIndicator(color: AppPalette.ochre),
              ),
            )
          else if (_error != null)
            Text(
              'Could not load suggestions: $_error',
              style: const TextStyle(color: AppPalette.charcoal),
            )
          else if (_suggestions == null)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loadSuggestions,
                icon: const Icon(Icons.lightbulb_rounded, size: 18),
                label: const Text('Get Suggestions'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppPalette.ochre,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            )
          else
            Column(
              children: _suggestions!
                  .map(
                    (s) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.tips_and_updates_rounded,
                            color: AppPalette.ochre,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s['title'] ?? '',
                                  style: const TextStyle(
                                    color: AppPalette.charcoal,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                                if ((s['tip'] ?? '').isNotEmpty)
                                  Text(
                                    s['tip']!,
                                    style: const TextStyle(
                                      color: AppPalette.charcoal,
                                      fontSize: 13,
                                      height: 1.4,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}

// ── Compact KPI Card ───────────────────────────────────────────────────
class _CompactKpiCard extends StatelessWidget {
  const _CompactKpiCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.change = 0,
    this.showChange = true,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final double change;
  final bool showChange;

  @override
  Widget build(BuildContext context) {
    final isPositive = change >= 0;
    final changeText = change.isFinite
        ? '${isPositive ? '+' : ''}${(change * 100).toStringAsFixed(0)}%'
        : '0%';
    final changeColor =
        isPositive ? const Color(0xFF2ECC71) : const Color(0xFFE74C3C);
    final isDesktop = ResponsiveUtils.widthOf(context) >= Breakpoints.desktop;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: dashboardCard3dDecoration(
        borderColor: AppPalette.charcoal.withValues(alpha: 0.16),
        ambientColor: color,
        ambientAlpha: 0.10,
        radius: 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              if (showChange)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPositive
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_downward_rounded,
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
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              color: AppPalette.charcoal,
              fontSize: isDesktop ? 22 : 18,
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: AppPalette.charcoal,
              fontSize: 12,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ── Performance Overview chart ─────────────────────────────────────────
class _PerformanceOverviewCard extends StatelessWidget {
  const _PerformanceOverviewCard({required this.history});

  final BusinessDailyHistory history;

  static const List<(String label, Color color)> _series = [
    ('Views', Color(0xFF4F8FFF)),
    ('Saves', Color(0xFF2ECC71)),
    ('Shares', AppPalette.deepBlue),
    ('Reviews', Color(0xFF9B59B6)),
  ];

  @override
  Widget build(BuildContext context) {
    final hasData = history.labels.length >= 2;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: dashboardCard3dDecoration(
        borderColor: AppPalette.charcoal.withValues(alpha: 0.16),
        ambientColor: AppPalette.deepBlue,
        ambientAlpha: 0.10,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.show_chart_rounded,
                  color: AppPalette.deepBlue, size: 22),
              const SizedBox(width: 10),
              const Text(
                'Performance Overview',
                style: TextStyle(
                  color: AppPalette.charcoal,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Views, saves, shares and reviews over the last 7 days. '
            'Each trend is scaled independently so smaller metrics stay visible.',
            style: TextStyle(color: AppPalette.charcoal, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children:
                _series.map((s) => _legendDot(s.$1, s.$2)).toList(),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 300,
            child: hasData
                ? _buildChart()
                : const Center(
                    child: Text(
                      'Not enough data yet.',
                      style: TextStyle(color: AppPalette.charcoal),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _legendDot(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: AppPalette.charcoal,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // Each series gets its own horizontal band (with a gap) so flat/constant
  // series never collapse onto the same line and hide behind each other.
  static const double _bandHeight = 0.20;
  static const double _bandGap = 0.06;

  (double min, double max) _bandFor(int index) {
    final top = 1.0 - index * (_bandHeight + _bandGap);
    return (top - _bandHeight, top);
  }

  List<double> _normalize(List<num> values, double bandMin, double bandMax) {
    if (values.isEmpty) return const [];
    final doubles = values.map((v) => v.toDouble()).toList();
    final maxValue = doubles.reduce((a, b) => a > b ? a : b);
    final minValue = doubles.reduce((a, b) => a < b ? a : b);
    final mid = (bandMin + bandMax) / 2;
    if (maxValue == minValue) return List.filled(doubles.length, mid);
    return doubles
        .map((v) =>
            bandMin + ((v - minValue) / (maxValue - minValue)) * (bandMax - bandMin))
        .toList();
  }

  Widget _buildChart() {
    final rawSeries = [
      history.views,
      history.saves,
      history.shares,
      history.reviews,
    ];

    final lineBars = <LineChartBarData>[];
    for (var i = 0; i < _series.length; i++) {
      final band = _bandFor(i);
      final data = _normalize(rawSeries[i], band.$1, band.$2);
      if (data.isEmpty) continue;
      lineBars.add(
        LineChartBarData(
          spots: data
              .asMap()
              .entries
              .map((e) => FlSpot(e.key.toDouble(), e.value))
              .toList(),
          isCurved: true,
          curveSmoothness: 0.3,
          barWidth: 2.5,
          isStrokeCapRound: true,
          color: _series[i].$2,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
              radius: 3,
              color: _series[i].$2,
              strokeWidth: 2,
              strokeColor: Colors.white,
            ),
          ),
          belowBarData: BarAreaData(show: false),
        ),
      );
    }

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (history.labels.length - 1).toDouble(),
        minY: 0,
        maxY: 1,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (value, meta) {
                final index = value.round();
                if (index < 0 || index >= history.labels.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    history.labels[index],
                    style: const TextStyle(
                      color: AppPalette.charcoal,
                      fontSize: 11,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: lineBars,
      ),
    );
  }
}


class _DashboardErrorCard extends StatelessWidget {
  final String message;

  const _DashboardErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppPalette.surface,
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
              style: const TextStyle(color: AppPalette.charcoal, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
