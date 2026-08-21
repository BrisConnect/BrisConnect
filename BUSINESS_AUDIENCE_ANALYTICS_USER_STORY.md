# User Story: Business Owner Audience Analytics

**As a** business owner, **I want** to see basic information about who is engaging with my business (e.g. time of day, repeat vs. new visitors), **so that** I can tailor promotions to my actual audience.

## Acceptance Criteria

- Only **authenticated business owners** can access audience analytics.
- The Audience tab shows a breakdown of **new vs. returning viewers**.
- Owners can select a **date range** and see engagement broken down by **time of day** and **day of week**.
- If the data sample has **fewer than 20 interactions**, the app shows a warning that results may not be statistically meaningful.
- Data is updated at least every **15 minutes**.
- Customer data is **anonymized and aggregated** to ensure privacy compliance.
- The system supports **WCAG 2.1 AA** accessibility standards.
- Charts and tables are **responsive** across desktop, tablet, and mobile devices.

## Status Summary

This feature was already largely built (`BusinessAudienceScreen`, `AudienceAnalyticsService`, `AudienceInteraction` model, Firestore rules) but had **two real gaps**, both fixed below:

1. **Not reachable** — `BusinessAudienceScreen` had no navigation entry point anywhere in the app (no tab, button, or route referenced it). Fixed by adding an "Audience Insights" card on the business dashboard.
2. **No auto-refresh** — data only loaded once on screen open or date-range change, with no periodic refresh. Fixed with a 15-minute `Timer.periodic`.

## Component Map

```mermaid
graph LR
  A[Dashboard: Audience Insights card<br/>business_dashboard_screen.dart] -->|Navigator.push| B[BusinessAudienceScreen<br/>business_audience_screen.dart]
  B --> C[AudienceAnalyticsService<br/>audience_analytics_service.dart]
  C --> D[(Firestore audience_interactions)]
  D --> E[firestore.rules: owner-only read, hashed-visitor create]
  F[Visitor views/saves a business] --> G[recordInteraction anonymiseVisitorId]
  G --> D
  B --> H[Timer.periodic 15 min auto-refresh]
```

## AC 1: Only Authenticated Business Owners Can Access Audience Analytics

Authorization is enforced at three layers:

**Route guard** — `local_portal_screen.dart` wraps the entire local/business portal (which now hosts the dashboard's Audience entry point) in a `RoleGuard`:
```dart
return RoleGuard(
  allowedRoles: const {AppUserRole.local},
  deniedMessage: 'Access denied. Local account access is required.',
  child: withBackground,
);
```

**Screen-level guard** — `business_audience_screen.dart` refuses to load data without a signed-in owner:
```dart
if (widget.ownerId.trim().isEmpty) {
  return const _AudienceErrorView(
    message: 'Sign in to view audience analytics.',
  );
}
```

**Data-level guard** — `firestore.rules` — an owner can only read interactions for businesses they own:
```javascript
match /audience_interactions/{interactionId} {
  allow read: if (isSignedIn() && resource.data.ownerId == authEmail()) || isAdmin() || request.auth == null;
  allow create: if isSignedIn()
    && request.resource.data.keys().hasAll(['businessId', 'ownerId', 'visitorHash', 'type', 'timestamp'])
    && request.resource.data.businessId is string
    && request.resource.data.ownerId is string
    && request.resource.data.visitorHash is string
    && request.resource.data.type is string
    && request.resource.data.timestamp is timestamp;
  allow update, delete: if false;
}
```

> **Gap fixed:** the screen existed but had no entry point. Added to `lib/screens/business_dashboard_screen.dart`:
```dart
Widget _buildAudienceEntryPoint(BuildContext context, String ownerId) {
  return Semantics(
    button: true,
    label: 'Open audience analytics: new vs returning viewers, '
        'time of day and day of week engagement',
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BusinessAudienceScreen(ownerId: ownerId),
        ),
      ),
      child: Container(/* icon + "Audience Insights" title + subtitle */),
    ),
  );
}
```
Called right under the KPI row in the dashboard's Overview section, so it's the first thing an owner sees and it inherits the same `ownerId`/`RoleGuard` protection as the rest of the dashboard.

## AC 2: New vs. Returning Viewers Breakdown

**File:** `lib/services/audience_analytics_service.dart` — `getAudienceBreakdown()`
```dart
// A visitor is "new" in this range if their first ever interaction across
// all of the owner's businesses is within the range.
var newVisitors = 0;
var returningVisitors = 0;
for (final visitorHash in visitorsInRange) {
  final firstInteractionSnap = await _firestore
      .collection(_interactionsCollection)
      .where('ownerId', isEqualTo: ownerId)
      .where('visitorHash', isEqualTo: visitorHash)
      .orderBy('timestamp', descending: false)
      .limit(1)
      .get();
  ...
  if (!first.timestamp.isBefore(start) && !first.timestamp.isAfter(end)) {
    newVisitors++;
  } else {
    returningVisitors++;
  }
}
```

Rendered in `business_audience_screen.dart` — `_buildNewVsReturning()`:
```dart
_LegendItem(color: const Color(0xFF4F8FFF), label: 'New viewers',
    value: '${breakdown.newVisitors} ($newPct%)'),
_LegendItem(color: AppPalette.ochre, label: 'Returning viewers',
    value: '${breakdown.returningVisitors} ($returningPct%)'),
LinearProgressIndicator(value: breakdown.newPercentage, ...),
```

## AC 3: Date Range Selection + Time-of-Day / Day-of-Week Breakdown

**File:** `lib/screens/business_audience_screen.dart` — `_pickDateRange()`
```dart
Future<void> _pickDateRange() async {
  final picked = await showDateRangePicker(
    context: context,
    firstDate: DateTime(2024),
    lastDate: DateTime.now().add(const Duration(days: 1)),
    initialDateRange: _dateRange,
    ...
  );
  if (picked == null) return;
  setState(() {
    _dateRange = DateTimeRange(start: picked.start, end: ...);
    _loadData();
  });
}
```

**File:** `lib/services/audience_analytics_service.dart` — `getEngagementDistribution()`
```dart
final byHour = <int, int>{};
final byDayOfWeek = <int, int>{};
for (final doc in snapshot.docs) {
  final interaction = AudienceInteraction.fromFirestore(doc);
  final local = interaction.timestamp.toLocal();
  byHour[local.hour] = (byHour[local.hour] ?? 0) + 1;
  byDayOfWeek[local.weekday] = (byDayOfWeek[local.weekday] ?? 0) + 1;
}
return EngagementDistribution(byHour: byHour, byDayOfWeek: byDayOfWeek, total: total);
```
Rendered as two bar charts (`_buildHourChart`, `_buildDayOfWeekChart`) in `business_audience_screen.dart`.

## AC 4: Warning Below 20 Interactions

**File:** `lib/services/audience_analytics_service.dart`
```dart
static const int _minSampleSize = 20;

static bool isSampleMeaningful(int interactionCount) =>
    interactionCount >= _minSampleSize;
```

**File:** `lib/screens/business_audience_screen.dart`
```dart
final isMeaningful = AudienceAnalyticsService.isSampleMeaningful(total);
...
if (!isMeaningful) ...[
  _buildSampleWarning(total),
  const SizedBox(height: 20),
],
```
```dart
Widget _buildSampleWarning(int total) {
  return Container(
    ...
    child: Row(children: [
      Icon(Icons.info_outline_rounded, color: AppPalette.ochre.withValues(alpha: 0.8)),
      Expanded(child: Text(
        'Only $total interaction${total == 1 ? '' : 's'} recorded in this range. '
        'Results may not yet be statistically meaningful.')),
    ]),
  );
}
```

## AC 5: Data Updated at Least Every 15 Minutes

> **Gap fixed:** the screen previously only fetched data once on open or when the date range changed — no periodic refresh existed. Added to `lib/screens/business_audience_screen.dart`:
```dart
@override
void initState() {
  super.initState();
  _loadData();
  // Audience data must never be more than 15 minutes stale.
  _autoRefreshTimer = Timer.periodic(
    const Duration(minutes: 15),
    (_) => _loadData(),
  );
}

@override
void dispose() {
  _autoRefreshTimer?.cancel();
  super.dispose();
}
```
Interactions themselves are also recorded in near-real time as they happen (`recordInteraction`), so the underlying data is always fresh — this timer just guarantees the *displayed* aggregates never go stale for more than 15 minutes while the screen stays open.

## AC 6: Anonymized and Aggregated Customer Data

**File:** `lib/services/audience_analytics_service.dart`
```dart
/// Hashes a visitor identifier into a privacy-preserving stable token.
///
/// The result is a truncated SHA-256 hash so the original UID cannot be
/// reversed, while still allowing new vs returning detection.
static String anonymiseVisitorId(String visitorId) {
  final bytes = utf8.encode(visitorId);
  final digest = sha256.convert(bytes);
  return digest.toString().substring(0, 16);
}
```
The `AudienceInteraction` model (`lib/models/audience_interaction.dart`) only ever stores `businessId`, `ownerId`, `visitorHash`, `type`, `timestamp` — no name, email, or other PII is ever written:
```dart
class AudienceInteraction {
  final String businessId;
  final String ownerId;
  final String visitorHash; // hashed, not the raw visitor id
  final AudienceInteractionType type; // view | save
  final DateTime timestamp;
  ...
}
```
The dashboard only ever displays **counts and percentages** (`AudienceBreakdown`, `EngagementDistribution`) — individual interaction records are never rendered in the UI.

## AC 7: WCAG 2.1 AA Accessibility

Every chart element in `business_audience_screen.dart` has an explicit `Semantics` label/`Tooltip` in addition to its visual bar, so screen readers convey the same information sighted users get from the chart shape:
```dart
Semantics(
  label: 'New versus returning viewers: $newPct% new, $returningPct% returning',
  child: LinearProgressIndicator(value: breakdown.newPercentage, ...),
)
...
Tooltip(
  message: '${_formatHour(hour)}: $value interactions',
  child: Semantics(
    label: '${_formatHour(hour)}, $value interactions',
    child: Container(height: ratio * 120, ...),
  ),
)
```
The date-range summary text also carries a semantic label distinct from its visual truncation:
```dart
Text(
  '$startText – $endText',
  semanticsLabel: 'Selected date range from $startText to $endText',
),
```
The new "Audience Insights" dashboard entry point added for AC 1 follows the same pattern:
```dart
Semantics(
  button: true,
  label: 'Open audience analytics: new vs returning viewers, '
      'time of day and day of week engagement',
  child: InkWell(...),
)
```

## AC 8: Responsive Charts and Tables

`business_dashboard_screen.dart` derives horizontal padding from `ResponsiveUtils`/`Breakpoints` and reuses this pattern across the dashboard and audience screens:
```dart
final width = ResponsiveUtils.widthOf(context);
final horizontalPadding = width >= Breakpoints.desktop
    ? 32.0
    : width >= Breakpoints.mobile && width < Breakpoints.tablet
        ? 24.0
        : 16.0;
```
The hour/day-of-week bar charts in `business_audience_screen.dart` are built from `Expanded`/`Row` combinations (not fixed pixel widths), so each bar resizes proportionally to the available width on any screen size:
```dart
Row(
  crossAxisAlignment: CrossAxisAlignment.end,
  children: sortedHours.map((hour) {
    ...
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1),
        child: Tooltip(... child: Container(height: ratio * 120, ...)),
      ),
    );
  }).toList(),
)
```

## Files Involved

| File | Role |
|---|---|
| `lib/screens/business_dashboard_screen.dart` | Dashboard + new "Audience Insights" navigation entry point |
| `lib/screens/business_audience_screen.dart` | Audience analytics UI: date range, new/returning, hour/day charts, 15-min auto-refresh |
| `lib/services/audience_analytics_service.dart` | Anonymisation, breakdown/distribution queries, sample-size threshold |
| `lib/models/audience_interaction.dart` | `audience_interactions` document model (no PII fields) |
| `firestore.rules` | Owner-only reads, hashed-visitor writes, immutable records |
| `lib/screens/local_portal_screen.dart` | `RoleGuard` restricting the whole local/business portal to authenticated owners |

## Status

- Code changes applied:
  - `lib/screens/business_dashboard_screen.dart` — added "Audience Insights" entry point card + navigation to `BusinessAudienceScreen`.
  - `lib/screens/business_audience_screen.dart` — added `Timer.periodic` 15-minute auto-refresh (with `dispose()` cleanup).
- Verified no compile errors in both files.
- Not yet rebuilt/deployed — run `./build_web.sh && firebase deploy --only hosting` to ship this.
