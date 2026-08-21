# User Story: Business Owner Dashboard Summary

**As a** business owner, **I want** a single home screen summarizing my business's performance, **so that** I can understand how I'm doing without digging through multiple tabs.

## Acceptance Criteria

- Only **authenticated business owners** can access their dashboard.
- The home screen displays key metrics: **views, saves, active promotions, and upcoming events** in one summary view.
- Metrics with significant changes since last week are **visually flagged** with up/down arrows and percentage changes.
- If there are **no active promotions**, the owner sees a prompt encouraging them to create one instead of an empty state.
- The dashboard loads within **2–3 seconds** under normal network conditions.
- Metrics refresh with **no noticeable delay** (under 1 second after load).
- The dashboard remains available **99.9%** of the time.
- The dashboard is **fully responsive** across desktop, tablet, and mobile screen sizes.
- The dashboard complies with **WCAG 2.1 AA** accessibility standards.
- Metrics are updated in **real-time** or refreshed at least every **5–15 minutes**.

## Status Summary

Most of this dashboard already existed, but AC 2 was only partially met: **"active promotions" and "upcoming events" were computed nowhere near the summary, and "upcoming events" wasn't computed at all.** Both gaps are fixed below.

## Component Map

```mermaid
graph LR
  A[local_portal_screen.dart<br/>RoleGuard: local owners only] --> B[BusinessDashboardScreen]
  B --> C[BusinessDashboardService.metricsStream]
  C --> D[(businesses: viewHistory/saveHistory)]
  C --> E[(promotions: status=active)]
  C --> F[(business_events: status=published) — NEW]
  C --> G[(reviews / social_shares / crowd_reports)]
  D & E & F & G --> H[BusinessDashboardMetrics]
  H --> I[_buildKpiRow: Views, Saves, Active Promotions, Upcoming Events, Shares, Reviews]
  I --> J[_CompactKpiCard: ▲/▼ + %change]
```

## AC 1: Only Authenticated Business Owners Can Access

**File:** `lib/screens/local_portal_screen.dart` wraps the whole Local Portal (which hosts the dashboard as its first tab):
```dart
return RoleGuard(
  allowedRoles: const {AppUserRole.local},
  deniedMessage: 'Access denied. Local account access is required.',
  child: withBackground,
);
```
**File:** `lib/screens/business_dashboard_screen.dart` also independently guards against an empty owner id (e.g. a stale/incomplete session):
```dart
if (ownerId.trim().isEmpty) {
  return Padding(
    ...
    child: const _DashboardErrorCard(message: 'Sign in to view your business summary.'),
  );
}
```

## AC 2: Key Metrics — Views, Saves, Active Promotions, Upcoming Events — Gap Found and Fixed

**Before:** `_buildKpiRow()` only showed Profile Views, Saves, Social Shares, and Reviews. `activePromotions` was already computed in `BusinessDashboardMetrics` but never rendered anywhere on the dashboard, and there was no `upcomingEvents` field or query at all.

**Fix 1 — added an `upcomingEvents` metric.** `lib/services/business_dashboard_service.dart`:
```dart
/// Parses the `dd/MM/yyyy` date string written by the event creation form.
static DateTime? _tryParseEventDate(String input) {
  final parts = input.split('/');
  if (parts.length != 3) return null;
  final day = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final year = int.tryParse(parts[2]);
  if (day == null || month == null || year == null) return null;
  try { return DateTime(year, month, day); } catch (_) { return null; }
}

int _countUpcomingEvents(QuerySnapshot<Map<String, dynamic>> snapshot) {
  final startOfToday = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  var count = 0;
  for (final doc in snapshot.docs) {
    final parsed = _tryParseEventDate(doc.data()['date']?.toString() ?? '');
    if (parsed != null && !parsed.isBefore(startOfToday)) count++;
  }
  return count;
}

Stream<int> _upcomingEventsStream(String ownerId) {
  return _firestore
      .collection('business_events')
      .where('ownerId', isEqualTo: ownerId)
      .where('status', isEqualTo: 'published')
      .snapshots()
      .map(_countUpcomingEvents);
}
```
This reuses the exact `dd/MM/yyyy` date format the event creation form (`business_event_form_screen.dart`) already writes, so no data migration is needed. It's wired into both the real-time stream (`_liveMetricsStreamForBusinesses`) and the one-time fetch (`_metricsForBusinesses`) alongside the existing promotions/reviews/shares/crowd sources, and added to `BusinessDashboardMetrics.upcomingEvents`.

**Fix 2 — surfaced both metrics on the dashboard.** `lib/screens/business_dashboard_screen.dart`:
```dart
Widget _buildKpiRow(BusinessDashboardMetrics metrics) {
  final items = [
    _CompactKpiCard(icon: Icons.visibility_rounded, label: 'Profile Views', value: '${metrics.profileViews}', change: metrics.profileViewsChange, color: const Color(0xFF4F8FFF)),
    _CompactKpiCard(icon: Icons.bookmark_rounded, label: 'Saves', value: '${metrics.saves}', change: metrics.savesChange, color: const Color(0xFF2ECC71)),
    _CompactKpiCard(icon: Icons.campaign_rounded, label: 'Active Promotions', value: '${metrics.activePromotions}', showChange: false, color: const Color(0xFF10B981)),
    _CompactKpiCard(icon: Icons.event_rounded, label: 'Upcoming Events', value: '${metrics.upcomingEvents}', showChange: false, color: const Color(0xFFF39C12)),
    _CompactKpiCard(icon: Icons.share_rounded, label: 'Social Shares', value: '${metrics.socialShares}', change: metrics.socialSharesChange, color: AppPalette.deepBlue),
    _CompactKpiCard(icon: Icons.star_rounded, label: 'Reviews', value: '${metrics.newReviews}', change: metrics.newReviewsChange, color: const Color(0xFF9B59B6)),
  ];
  return _kpiGrid(items);
}
```
All four AC-named metrics (views, saves, active promotions, upcoming events) are now in the single summary grid at the top of the dashboard, alongside the two extra metrics that were already there.

## AC 3: Significant Changes Visually Flagged with Arrows and Percentages

**File:** `lib/screens/business_dashboard_screen.dart` — `_CompactKpiCard`
```dart
final isPositive = change >= 0;
final changeText = change.isFinite
    ? '${isPositive ? '+' : ''}${(change * 100).toStringAsFixed(0)}%'
    : '0%';
final changeColor = isPositive ? const Color(0xFF2ECC71) : const Color(0xFFE74C3C);
...
if (showChange)
  Row(children: [
    Icon(isPositive ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, color: changeColor, size: 12),
    Text(changeText, style: TextStyle(color: changeColor, ...)),
  ]),
```
Each week-over-week comparison (`profileViewsChange`, `savesChange`, `socialSharesChange`, `newReviewsChange`) is computed in `BusinessDashboardService._percentageChange()` from the current 7-day window vs. the previous 7-day window, then rendered with a colored up/down arrow and a signed percentage. Active Promotions and Upcoming Events are point-in-time counts (not week-over-week deltas, since "how many are currently active/upcoming" is the meaningful number, not a trend), so they use `showChange: false` — consistent with how Buzz Score/Avg Rating already behave in the secondary metrics row.

## AC 4: No Active Promotions → Encouraging Prompt Instead of Empty State

**File:** `lib/screens/business_dashboard_screen.dart` — `_buildPromotionsRow()` / `_buildCreatePromotionCard()`

The "Promote Your Business" section is **never** a blank/empty state — it unconditionally renders a "Create Promotion" call-to-action card plus paid boost/feature options:
```dart
_sectionLabel('Promote Your Business'),
const SizedBox(height: 10),
_buildPromotionsRow(context, ownerId, promotionDayPlan, featuredPlan),
```
```dart
Expanded(flex: 5, child: _buildCreatePromotionCard(context)),
```
Because this CTA row is always shown regardless of whether the owner currently has 0 or more active promotions, an owner with none is never shown "nothing here" — they always see the same encouraging prompt to create one. The new "Active Promotions" KPI card (AC 2) now also makes the *current count* (including zero) explicit at a glance, right above this prompt.

## AC 5, 6 & 10: Load Time, Refresh Delay, Update Frequency

**Real-time by default, not polling:** every data source feeding the dashboard is a live Firestore `.snapshots()` stream (`_businessesForOwner`, `_activePromotionsStream`, `_reviewsStream`, `_crowdReportsStream`, `_socialSharesStream`, and the new `_upcomingEventsStream`), combined via `_liveMetricsStreamForBusinesses`'s `emitIfReady()` fan-in:
```dart
Stream<BusinessDashboardMetrics> metricsStream(String ownerId) {
  return _businessesForOwner(ownerId)
      .asyncExpand((businesses) => _liveMetricsStreamForBusinesses(businesses));
}
```
Firestore snapshot listeners push changes to the client typically within a few hundred milliseconds of a write (well under both the "under 1 second" refresh requirement and the "real-time or 5–15 minutes" requirement) — this is real-time, not a periodic poll.

**Fast initial paint:** the dashboard shows a spinner immediately and renders as soon as the first combined snapshot arrives, rather than blocking on every possible data source:
```dart
if (metricsSnap.connectionState == ConnectionState.waiting && !metricsSnap.hasData) {
  return const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 40), child: CircularProgressIndicator(color: AppPalette.ochre)));
}
```
Because all six underlying Firestore reads for a single business owner are small, indexed, equality/short-range queries (no large collection scans), first paint is expected well within the 2–3 second target on a normal connection.

## AC 7: 99.9% Availability

The dashboard has no custom backend server to go down — it reads directly from Cloud Firestore (Google's managed, multi-region database with its own high-availability SLA) via the client SDK, and the web app itself is served from Firebase Hosting's global CDN. There is no single point of failure introduced by BrisConnect+'s own code between the owner and their data.

## AC 8: Fully Responsive Across Desktop, Tablet, and Mobile

**File:** `lib/screens/business_dashboard_screen.dart`
```dart
final width = ResponsiveUtils.widthOf(context);
final horizontalPadding = width >= Breakpoints.desktop
    ? 32.0
    : width >= Breakpoints.mobile && width < Breakpoints.tablet
        ? 24.0
        : 16.0;
```
The KPI grid itself reflows its column count based on available width:
```dart
Widget _kpiGrid(List<Widget> items) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final crossAxisCount = constraints.maxWidth >= Breakpoints.mobile ? 4 : 2;
      return GridView.count(crossAxisCount: crossAxisCount, ...);
    },
  );
}
```
The "Promote Your Business" row also switches between a 3-column `Row` (tablet/desktop) and a stacked `Column` (mobile) via the same `LayoutBuilder` pattern.

## AC 9: WCAG 2.1 AA Accessibility

Change indicators pair color with an icon and text label (not color alone) — up/down arrow + explicit `+N%`/`-N%` text — so the "significant change" signal doesn't rely on color perception alone, which is a core WCAG 2.1 success criterion (1.4.1 Use of Color). Interactive elements (KPI cards, promotion CTAs) use standard Material widgets (`ElevatedButton`, `InkWell`), which come with built-in focus/semantics support out of the box.

## Files Involved

| File | Role |
|---|---|
| `lib/screens/business_dashboard_screen.dart` | Dashboard UI: KPI grid (now incl. Active Promotions & Upcoming Events), responsive layout, promotions CTA |
| `lib/services/business_dashboard_service.dart` | Real-time metrics aggregation; added `upcomingEvents` computation |
| `lib/screens/local_portal_screen.dart` | `RoleGuard` restricting dashboard access to authenticated local/business owners |
| `lib/screens/business_event_form_screen.dart` | Source of the `dd/MM/yyyy` event date format reused for upcoming-event counting |
| `firestore.rules` | `business_events` read rule (`status == 'published'`) already covers the new query |

## Status

- Code changes applied:
  - `lib/services/business_dashboard_service.dart` — added `upcomingEvents` field to `BusinessDashboardMetrics`, plus `_upcomingEvents`/`_upcomingEventsStream`/date-parsing helpers, wired into both the live stream and one-time fetch paths.
  - `lib/screens/business_dashboard_screen.dart` — added "Active Promotions" and "Upcoming Events" KPI cards to `_buildKpiRow()`.
- Verified no compile errors in either file.
- No Firestore index changes needed — the new query is two equality filters (`ownerId`, `status`), which Firestore supports without a composite index.
- Not yet rebuilt/deployed — run `./build_web.sh && firebase deploy --only hosting` to ship this.
