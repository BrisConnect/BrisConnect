# Activity Diagram: Business Owner — Dashboard Event Notifications

## User Story

**As a** business owner,  
**I want to** be notified about important dashboard events (e.g. a promotion is trending, an offer is about to expire),  
**So that** I don't have to keep checking the app manually.

## Acceptance Criteria

- Given a promotion's engagement spikes significantly, when this happens, then I receive a push notification within a reasonable time (e.g. 15 minutes).
- Given an active offer is within 24 hours of expiring, when the threshold is hit, then I receive a reminder notification with an option to extend it.
- Given I don't want certain alert types, when I go to notification settings, then I can toggle each alert category on/off individually.
- Push notifications are delivered within 15 minutes of the triggering event.
- Notification settings comply with WCAG 2.1 AA standards.
- Only authenticated business owners can access notification settings.
- Notification preferences are securely stored.
- Notification services are available 99.9% of the time.

## Activity Diagram

```mermaid
flowchart TB
    Start([Business owner opens app]) --> Authenticate{Authenticated as business owner?}

    Authenticate -->|No| ShowAuthPrompt[Prompt sign-in]
    ShowAuthPrompt --> EndNoAccess([End])

    Authenticate -->|Yes| DetectDashboardEvents[Detect dashboard events]

    DetectDashboardEvents --> EventType{Event type?}
    EventType -->|Engagement spike| EngagementSpike[Promotion engagement spikes significantly]
    EventType -->|Offer expiring| OfferExpiring[Offer within 24 hours of expiring]
    EventType -->|Settings change| OpenSettings[Open notification settings]

    EngagementSpike --> CheckTrendingEnabled{Trending alerts enabled?}
    CheckTrendingEnabled -->|No| EndTrendingDisabled([End])
    CheckTrendingEnabled -->|Yes| QueueTrendingNotification[Queue push notification: "Your promotion is trending"]

    OfferExpiring --> CheckExpiryEnabled{Expiry reminders enabled?}
    CheckExpiryEnabled -->|No| EndExpiryDisabled([End])
    CheckExpiryEnabled -->|Yes| QueueExpiryNotification[Queue push notification with extend option]

    QueueTrendingNotification --> DeliverWithin15Min[Deliver within 15 minutes]
    QueueExpiryNotification --> DeliverWithin15Min

    DeliverWithin15Min --> NotificationSent[Push notification sent]
    NotificationSent --> OwnerInteracts[Owner taps notification]

    OwnerInteracts --> ActionContext{Notification context?}
    ActionContext -->|Trending| OpenPromotion[Open promotion details]
    ActionContext -->|Expiring| OpenOfferExtend[Open offer with extend option]

    OpenSettings --> LoadPreferences[Load saved notification preferences]
    LoadPreferences --> RenderAccessibleSettings[Render settings with WCAG 2.1 AA compliance]
    RenderAccessibleSettings --> ToggleCategory[Owner toggles alert category on/off]
    ToggleCategory --> SaveSecurely[Save preferences securely]
    SaveSecurely --> EndSettings([End])

    subgraph NotificationDelivery ["Notification Delivery SLA"]
        TriggerReceived[Triggering event received] --> CheckWithin15Min{Sent within 15 minutes?}
        CheckWithin15Min -->|No| RetrySend[Retry / alert ops team]
        RetrySend --> CheckWithin15Min
        CheckWithin15Min -->|Yes| ConfirmDelivery[Confirm delivery]
    end

    subgraph ServiceAvailability ["Service Availability"]
        MonitorUptime[Monitor notification service uptime] --> UptimeCheck{Availability >= 99.9%?}
        UptimeCheck -->|No| EscalateIncident[Escalate incident / failover]
        EscalateIncident --> MonitorUptime
        UptimeCheck -->|Yes| ContinueMonitoring[Continue monitoring]
    end

    subgraph SecurityAndPrivacy ["Security & Privacy"]
        SettingsAccess{Authenticated owner?} -->|No| DenyAccess[Deny access]
        SettingsAccess -->|Yes| EncryptPreferences[Encrypt stored preferences]
        EncryptPreferences --> AuditAccess[Audit access logs]
    end
```

## Diagram Explanation

1. **Open app** — Business owner launches the app or background event-detection runs.
2. **Authentication check** — Only authenticated business owners can access notification settings and receive owner-targeted alerts.
3. **Detect dashboard events** — The system monitors for promotion engagement spikes, expiring offers, and settings changes.
4. **Event type branch** — Each event follows its own handling path.
5. **Engagement spike** — When a promotion's engagement spikes significantly, the system checks whether trending alerts are enabled.
6. **Offer expiring** — When an active offer is within 24 hours of expiring, the system checks whether expiry reminders are enabled.
7. **Settings change** — The owner navigates to notification settings.
8. **Preference gate** — If the relevant alert category is disabled, no notification is sent.
9. **Queue notification** — A push notification is queued, e.g. "Your promotion is trending" or an offer-expiry reminder with an extend option.
10. **Deliver within 15 minutes** — Notifications are sent within 15 minutes of the triggering event.
11. **Owner interaction** — Tapping a notification opens the relevant promotion details or offer-extension screen.
12. **Notification settings** — Preferences are loaded, rendered accessibly, toggled, and saved securely.
13. **Notification delivery SLA** — Delivery is tracked against the 15-minute target with retry/escalation if missed.
14. **Service availability** — Notification services are monitored to maintain 99.9% uptime, with failover on breach.
15. **Security and privacy** — Settings access is restricted, stored preferences are encrypted, and access is audited.
