# Activity Diagram: Business Owner Dashboard Home Screen

## User Story

**As a** Business Owner,  
**I want** a single home screen summarizing my business's performance,  
**So that** I can understand how I'm doing without digging through multiple tabs.

## Improved Acceptance Criteria

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

## Activity Diagram

```mermaid
flowchart TB
    Start([Business owner opens app]) --> Authenticate{Authenticated as business owner?}

    Authenticate -->|No| ShowAuthPrompt[Prompt sign-in]
    ShowAuthPrompt --> EndNoAccess([End])

    Authenticate -->|Yes| LoadDashboard[Request dashboard summary data]
    LoadDashboard --> FetchMetrics[Fetch views, saves, active promotions, upcoming events]

    FetchMetrics --> PerformanceCheck{Loaded within 2-3 seconds?}

    PerformanceCheck -->|No| OptimizeLoad[Optimize query / cache data]
    OptimizeLoad --> FetchMetrics

    PerformanceCheck -->|Yes| ComparePeriod[Compare current metrics to last week]
    ComparePeriod --> FlagChanges[Flag significant changes with arrows and % change]

    FlagChanges --> CheckPromotions{Active promotions exist?}

    CheckPromotions -->|Yes| DisplayPromotions[Display active promotions]
    CheckPromotions -->|No| ShowPrompt[Show prompt: "Create a promotion to attract more visitors"]

    DisplayPromotions --> CheckEvents{Upcoming events exist?}
    ShowPrompt --> CheckEvents

    CheckEvents -->|Yes| DisplayEvents[Display upcoming events]
    CheckEvents -->|No| ShowNoEvents[Show "No upcoming events" message]

    DisplayEvents --> RenderSummary[Render responsive summary view]
    ShowNoEvents --> RenderSummary

    RenderSummary --> RealTimeUpdate[Poll for metric updates]

    RealTimeUpdate --> UpdateCheck{New data available?}

    UpdateCheck -->|No| ContinuePolling[Continue polling every 5-15 minutes]
    ContinuePolling --> RealTimeUpdate

    UpdateCheck -->|Yes| RefreshDelay{Refresh within <1 second?}

    RefreshDelay -->|No| OptimizeRefresh[Optimize refresh pipeline]
    OptimizeRefresh --> RealTimeUpdate

    RefreshDelay -->|Yes| UpdateMetrics[Update metrics in dashboard]
    UpdateMetrics --> FlagChanges

    subgraph AccessibilityChecks ["Accessibility & Responsiveness"]
        ResponsiveCheck{Responsive on desktop, tablet, mobile?} -->|No| FixLayout[Adjust responsive layout]
        FixLayout --> ResponsiveCheck
        ResponsiveCheck -->|Yes| ContinueResponsive[Continue]
        WcagCheck{WCAG 2.1 AA compliant?} -->|No| FixAccessibility[Fix accessibility issues]
        FixAccessibility --> WcagCheck
        WcagCheck -->|Yes| ContinueWcag[Continue]
    end

    subgraph AvailabilityMonitoring ["Availability Monitoring"]
        UptimeCheck{Dashboard available ≥ 99.9%?} -->|No| EnableFallback[Enable cached dashboard fallback]
        EnableFallback --> AlertOps[Alert operations team]
        AlertOps --> UptimeCheck
        UptimeCheck -->|Yes| ContinueUptime[Continue monitoring]
    end
```

## Diagram Explanation

1. **Open app** — Business owner launches the app.
2. **Authentication check** — Only authenticated business owners can access the dashboard.
3. **Load dashboard** — The app requests summary data for the business.
4. **Fetch metrics** — Views, saves, active promotions, and upcoming events are retrieved.
5. **Performance check** — The dashboard must load within 2–3 seconds; otherwise queries are optimized.
6. **Compare to last week** — Current metrics are compared to the previous week.
7. **Flag changes** — Significant changes are shown with arrows and percentage differences.
8. **Active promotions check** — If none exist, a prompt encourages creating one.
9. **Upcoming events check** — Events are displayed, or a "no events" message is shown.
10. **Render summary view** — The dashboard is displayed in a responsive layout.
11. **Real-time updates** — The dashboard polls for new data every 5–15 minutes.
12. **Refresh delay check** — Updates must render in under 1 second.
13. **Update metrics** — New data refreshes the dashboard and re-flags changes.
14. **Accessibility and responsiveness** — The layout is verified for WCAG 2.1 AA and adapts to all screen sizes.
15. **Availability monitoring** — Dashboard uptime is monitored for 99.9%; cached fallback and alerting activate if it drops.
