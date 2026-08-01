# Test Cases & Implementation Mapping: Admin Platform Analytics

## User Story

**As an** Admin,  
**I want to** view platform analytics,  
**So that** I can understand user engagement and business performance.

## Test Case → Implementation Mapping

| ID | Acceptance Criteria | Test Case | Expected Result | Implementation Approach | Key Files / Components |
|----|---------------------|-----------|-----------------|------------------------|------------------------|
| A-001 | Admin can view total users, active users, and growth trends | Navigate to Analytics → Users tab | Dashboard displays total users, active users (e.g. last 7/30 days), and a growth-trend line chart | Aggregate `users` collection by `createdAt` for totals; compute active users from `sessions` or `events` collection by `lastActiveAt`; calculate MoM/WoW deltas in Cloud Function | `functions/analytics/users.ts`, `lib/admin/analytics/users_tab.dart` |
| A-002 | Admin can view most reviewed businesses and events | Navigate to Analytics → Businesses tab | List/table shows top businesses/events ranked by review count, with names and trend arrows | Aggregate `reviews` collection by `businessId`/`eventId`, join with `businesses`/`events`, sort descending, cache in `analytics_top_reviewed` | `functions/analytics/topReviewed.ts`, `lib/admin/analytics/businesses_tab.dart` |
| A-003 | Admin can view engagement metrics (reviews, photos, shares) | Navigate to Analytics → Engagement tab | Cards/charts show counts for reviews, photos, and shares within selected date range | Count documents from `reviews`, `photos`, `shares` collections filtered by date range; expose via analytics API | `functions/analytics/engagement.ts`, `lib/admin/analytics/engagement_tab.dart` |
| A-004 | Admin can filter analytics by date range | Select a custom date range (e.g. last 30 days) | All charts and metrics update to reflect the selected range | Date-range picker updates query params; Firestore queries use `startDate`/`endDate` filters; Cloud Function accepts date range and returns aggregated metrics | `lib/admin/widgets/date_range_picker.dart`, `functions/analytics/getMetrics.ts` |
| A-005 | Data is displayed in charts or dashboards | Open analytics dashboard | Charts (line, bar, pie) render correctly with axes, legends, and tooltips | Use `fl_chart` (Flutter) or `chart.js` (web admin); data formatted into chart series from analytics API response | `lib/admin/widgets/analytics_charts.dart`, `lib/admin/screens/analytics_dashboard.dart` |
| A-006 | Only Admin users can access platform analytics | Attempt to access `/admin/analytics` as non-admin user | Access denied; user redirected to unauthorised page | Firebase Auth custom claims check for `role === 'admin'`; Firestore Security Rules reject reads to `analytics/*` for non-admins; route guard on dashboard entry | `functions/auth/customClaims.ts`, `firestore.rules`, `lib/admin/guards/admin_guard.dart` |
| A-007 | Analytics data is protected through role-based access control | Call analytics API with a non-admin token | API returns 403 Forbidden | Cloud Functions verify `context.auth.token.admin === true` before returning analytics data | `functions/analytics/getMetrics.ts`, `functions/middleware/requireAdmin.ts` |
| A-008 | Charts are responsive and viewable on desktop, tablet, and mobile devices | Resize browser / rotate device | Charts and dashboard layout reflow without clipping or overflow | Use `LayoutBuilder` / `MediaQuery` in Flutter; CSS grid/flexbox with breakpoints on web; chart widgets wrap or scroll horizontally on narrow screens | `lib/admin/screens/analytics_dashboard.dart`, `web/admin/styles/analytics.css` |
| A-009 | Dashboards comply with WCAG 2.1 AA standards | Run accessibility scanner / manual keyboard test | Color contrast ≥ 4.5:1, all charts have accessible labels/alt text, keyboard navigable, focus indicators visible | Use high-contrast theme tokens, `Semantics` labels on Flutter charts, `aria-label` on web charts, ensure tab order through filters and metric cards | `lib/theme/admin_accessibility_theme.dart`, `web/admin/a11y/aria-labels.ts` |
| A-010 | Dashboard loads within acceptable time | Open analytics dashboard with default 30-day range | Initial data loads within 3 seconds under normal conditions | Pre-aggregate analytics in scheduled Cloud Function; cache results in Firestore `analytics/daily` documents; client reads cached aggregates instead of raw collections | `functions/analytics/aggregateDaily.ts` (scheduled), `lib/admin/services/analytics_cache.dart` |
| A-011 | Aggregated data does not expose individual user PII | Inspect API response and chart data | No user emails, names, or UIDs are returned; only counts and anonymised cohorts | Aggregation pipeline groups by date/metric only; exclude any UID or personal fields; store aggregates in separate collection with restricted access | `functions/analytics/aggregateDaily.ts`, Firestore `analytics_aggregates` collection rules |
| A-012 | Date-range edge cases handled correctly | Select future dates, invalid range (end < start), or very large range | UI shows validation error or clamps to valid range; no crash or timeout | Validate range client-side; server clamps `startDate` to earliest available data and caps query window; return clear error for invalid input | `lib/admin/widgets/date_range_picker.dart`, `functions/analytics/validators.ts` |
| A-013 | Empty-state messaging when no data exists | Open analytics for a new platform with zero events | Dashboard shows "No data available" placeholders instead of blank charts | Analytics service returns `null`/empty series; UI renders empty-state widget with accessible message | `lib/admin/widgets/empty_analytics_state.dart` |
| A-014 | Audit log records admin access to analytics | Admin opens analytics dashboard | Audit entry created with admin UID, timestamp, and accessed resource | On each analytics API call, write to `auditLogs` collection with admin ID, action `VIEW_ANALYTICS`, timestamp | `functions/audit/logAdminAction.ts`, `firestore.rules` for audit collection |

## Implementation Summary

| Layer | Responsibility | Suggested Tech / Location |
|-------|----------------|---------------------------|
| **Frontend** | Dashboard UI, charts, date filters, RBAC route guard | `lib/admin/screens/analytics_dashboard.dart`, `lib/admin/widgets/` |
| **API / Functions** | Aggregate data, enforce admin auth, return metrics | `functions/analytics/*.ts` |
| **Scheduled Jobs** | Pre-compute daily/weekly aggregates for performance | `functions/analytics/aggregateDaily.ts` (Cloud Scheduler) |
| **Database** | Raw event collections + pre-aggregated analytics docs | Firestore collections: `users`, `reviews`, `photos`, `shares`, `analytics_aggregates`, `auditLogs` |
| **Security** | Admin role checks, encrypted transit, audit logging | Firebase Auth custom claims, Firestore Security Rules, Cloud Functions `context.auth` |
| **Accessibility** | WCAG 2.1 AA compliance, responsive layout | Theme tokens, semantic labels, `MediaQuery`, keyboard navigation |
