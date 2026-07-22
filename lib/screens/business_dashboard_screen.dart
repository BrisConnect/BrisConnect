import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:brisconnect/auth/local_auth.dart';
import 'package:brisconnect/screens/ai_post_sheet.dart';
import 'package:brisconnect/theme/app_palette.dart';

/// Screen 1 of the Local portal — Business Dashboard.
/// Shows analytics, AI post creation, promotions and notifications.
class BusinessDashboardScreen extends StatelessWidget {
  const BusinessDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = LocalAuth.currentLocal;
    final name = user?.name ?? 'Business Owner';

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(name)),
            SliverToBoxAdapter(child: _buildAnalyticsRow(context, user?.email)),
            SliverToBoxAdapter(child: _buildAIPostSection(context)),
            SliverToBoxAdapter(child: _buildPromotionsSection(context)),
            SliverToBoxAdapter(child: _buildNotificationsSection(context, user?.email)),
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
  Widget _buildAnalyticsRow(BuildContext context, String? email) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('Analytics'),
          const SizedBox(height: 10),
          StreamBuilder<QuerySnapshot>(
            stream: email == null
                ? const Stream.empty()
                : FirebaseFirestore.instance
                    .collection('events')
                    .where('createdByLocalEmail', isEqualTo: email)
                    .snapshots(),
            builder: (context, snap) {
              final count = snap.data?.docs.length ?? 0;
              return Row(
                children: [
                  _AnalyticCard(
                    icon: Icons.event_rounded,
                    label: 'Events Posted',
                    value: '$count',
                    color: AppPalette.ochre,
                  ),
                  const SizedBox(width: 10),
                  _AnalyticCard(
                    icon: Icons.visibility_rounded,
                    label: 'Profile Views',
                    value: '—',
                    color: const Color(0xFF4F8FFF),
                  ),
                  const SizedBox(width: 10),
                  _AnalyticCard(
                    icon: Icons.star_rounded,
                    label: 'Reviews',
                    value: '—',
                    color: const Color(0xFF9B59B6),
                  ),
                ],
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

  // ── Promotions ──────────────────────────────────────────────────────
  Widget _buildPromotionsSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _sectionLabel('Promotions'),
              TextButton(
                onPressed: () {},
                child: const Text('+ New',
                    style: TextStyle(
                        color: AppPalette.ochre,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
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
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C2E),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(
                    color: color,
                    fontSize: 22,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    color: Color(0xFF8B8FA8), fontSize: 11),
                overflow: TextOverflow.ellipsis),
          ],
        ),
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
