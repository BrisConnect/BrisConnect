# Business Dashboard Activity Diagram

## User Story
**As a business owner, I want a single home screen summarizing my business's performance, so that I can understand how I'm doing without digging through multiple tabs.**

```mermaid
flowchart TD
    START([Business Owner Opens BrisConnect+]) --> AUTH{Authenticated?}
    AUTH -->|No| LOGIN[Redirect to Login Screen]
    LOGIN --> AUTH
    AUTH -->|Yes| ROLE{Business Owner Role?}
    ROLE -->|No| DENY[Access Denied]
    ROLE -->|Yes| LOAD[Dashboard Initiates Load]

    LOAD --> NET{Network Available?}
    NET -->|No| CACHE[Load Cached Metrics]
    NET -->|Yes| FETCH[Fetch Real-Time Metrics]

    FETCH --> VIEWS[Get Profile Views]
    FETCH --> SAVES[Get Saves Count]
    FETCH --> PROMOS[Get Active Promotions]
    FETCH --> EVENTS[Get Upcoming Events]

    VIEWS --> AGG[Aggregate Metrics]
    SAVES --> AGG
    PROMOS --> AGG
    EVENTS --> AGG

    CACHE --> AGG
    AGG --> CHANGES[Calculate Week-over-Week Changes]
    CHANGES --> FLAG{Significant Change?}
    FLAG -->|Yes| VISUAL_FLAG[Apply Up/Down Arrow with % Change]
    FLAG -->|No| NO_FLAG[Show Static Metric Value]

    VISUAL_FLAG --> RENDER[Render Dashboard Summary View]
    NO_FLAG --> RENDER

    RENDER --> PROMO_CHECK{Active Promotions > 0?}
    PROMO_CHECK -->|Yes| SHOW_PROMOS[Display Active Promotions Card]
    PROMO_CHECK -->|No| ENCOURAGE[Show Create Promotion Prompt]

    SHOW_PROMOS --> RESPONSIVE[Apply Responsive Layout]
    ENCOURAGE --> RESPONSIVE

    RESPONSIVE --> DEVICE{Screen Size?}
    DEVICE -->|Desktop| DESKTOP_LAYOUT[4-Column Analytics Grid]
    DEVICE -->|Tablet| TABLET_LAYOUT[3-Column Analytics Grid]
    DEVICE -->|Mobile| MOBILE_LAYOUT[2-Column / Stacked Layout]

    DESKTOP_LAYOUT --> ACCESS[Apply WCAG 2.1 AA Accessibility]
    TABLET_LAYOUT --> ACCESS
    MOBILE_LAYOUT --> ACCESS

    ACCESS --> CONTRAST[Ensure Color Contrast ≥ 4.5:1]
    ACCESS --> LABELS[Add Semantic Labels & Screen Reader Support]
    ACCESS --> FOCUS[Ensure Keyboard Focus Visibility]

    CONTRAST --> DISPLAY([Dashboard Visible to Business Owner])
    LABELS --> DISPLAY
    FOCUS --> DISPLAY

    DISPLAY --> TIMER{Time Since Last Refresh?}
    TIMER -->|> 5-15 min| REFRESH[Auto-Refresh Metrics]
    TIMER -->|< 5 min| CONTINUE[Continue Displaying Current Data]
    REFRESH --> FETCH
    CONTINUE --> INTERACT[Owner Interacts with Dashboard]

    INTERACT --> TAP_PROMO{Tap Create Promotion?}
    TAP_PROMO -->|Yes| CREATE_PROMO[Open Promotion Creation Flow]
    TAP_PROMO -->|No| TAP_METRIC{Tap Metric Card?}
    TAP_METRIC -->|Yes| DRILL_DOWN[Open Detailed Metric View]
    TAP_METRIC -->|No| END_SESSION([End Session])

    CREATE_PROMO --> END_SESSION
    DRILL_DOWN --> END_SESSION

    DENY --> END_SESSION

    style START fill:#2ECC71,stroke:#1E8449,color:#fff
    style DISPLAY fill:#3498DB,stroke:#21618C,color:#fff
    style END_SESSION fill:#E74C3C,stroke:#922B21,color:#fff
    style ACCESS fill:#9B59B6,stroke:#6C3483,color:#fff
```

## Activity Flow Description

| Step | Activity | Acceptance Criteria Coverage |
|------|----------|------------------------------|
| 1 | **Authentication Check** | Only authenticated business owners can access their dashboard |
| 2 | **Role Verification** | Business owner access control |
| 3 | **Network Detection** | Dashboard availability (99.9% uptime) / offline fallback |
| 4 | **Metric Aggregation** | Views, saves, active promotions, upcoming events in one summary |
| 5 | **Change Detection** | Visual flagging for significant week-over-week changes |
| 6 | **Promotion Prompt** | Encourage promotion creation when none active |
| 7 | **Responsive Layout** | Desktop, tablet, and mobile adaptation |
| 8 | **Accessibility Checks** | WCAG 2.1 AA compliance |
| 9 | **Auto-Refresh Loop** | Real-time updates or 5–15 minute refresh |
| 10 | **Interaction Handling** | Tap-to-drill-down and create-promotion flows |

## Performance Targets

- **Initial Load:** 2–3 seconds under normal network conditions
- **Metric Refresh:** < 1 second after initial load
- **Update Frequency:** Every 5–15 minutes (or real-time if available)
- **Availability Target:** 99.9% uptime

## Accessibility Checkpoints

- Color contrast ratio ≥ 4.5:1 for all text and UI elements
- All interactive elements have accessible labels
- Screen reader announcements for metric changes
- Keyboard navigable dashboard cards and buttons
- Focus indicators visible on all focusable elements
