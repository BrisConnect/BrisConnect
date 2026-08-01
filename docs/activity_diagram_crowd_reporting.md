# Activity Diagram: Report Crowd Levels at Food Events

## User Story

**As a** Visitor,  
**I want to** report crowd levels at local food events,  
**So that** other visitors can make informed decisions.

## Improved Acceptance Criteria

- Signed-in visitors within the event geofence can select **Low**, **Moderate**, or **High**.
- Each report is timestamped and location-verified.
- The same user cannot submit another report within **30 minutes**.
- The crowd indicator is calculated from reports received within the last **2 hours**, with more recent reports weighted higher.
- Outliers are ignored when at least **5 reports** exist within the window.
- The current crowd status is displayed on the food event page and refreshes automatically.
- Clear feedback appears after submission: **"Report submitted successfully"**.
- Crowd reporting feature is available **99.9%** during published event hours; a cached indicator is served if live data is unavailable.

## Activity Diagram

```mermaid
flowchart TB
    Start([Signed-in visitor at food event]) --> OpenEvent[Open food event page]
    OpenEvent --> DisplayCrowd[Display current crowd status]

    DisplayCrowd --> TapReport[Tap "Report crowd level"]
    TapReport --> GeoCheck{Within event geofence?}

    GeoCheck -->|No| BlockRemote[Block report from remote location]
    BlockRemote --> ShowGeoError[Show: "You must be near the event to report"]
    ShowGeoError --> EndGeo([End])

    GeoCheck -->|Yes| SelectLevel[Select Low, Moderate, or High]
    SelectLevel --> Submit[Submit crowd report]

    Submit --> Timestamp[Attach timestamp and location]
    Timestamp --> DuplicateCheck{Reported within last 30 minutes?}

    DuplicateCheck -->|Yes| RejectDuplicate[Reject duplicate report]
    RejectDuplicate --> ShowDuplicate[Show: "You can report again in 30 minutes"]
    ShowDuplicate --> EndDup([End])

    DuplicateCheck -->|No| Validate{Valid crowd level?}
    Validate -->|No| ShowValidationError[Show validation error]
    ShowValidationError --> SelectLevel

    Validate -->|Yes| Store[Store report]
    Store --> FilterWindow[Consider reports from last 2 hours]
    FilterWindow --> Weight[Weight recent reports higher]

    Weight --> MinimumReports{At least 5 reports?}
    MinimumReports -->|Yes| OutlierCheck[Ignore outlier reports]
    MinimumReports -->|No| SkipOutlier[Skip outlier logic]

    OutlierCheck --> Aggregate[Aggregate into weighted average]
    SkipOutlier --> Aggregate

    Aggregate --> ConsistencyCheck{Calculation consistent?}
    ConsistencyCheck -->|No| Recalc[Recalculate with stable algorithm]
    Recalc --> FilterWindow

    ConsistencyCheck -->|Yes| MapToIndicator[Map result to Low, Moderate, or High]
    MapToIndicator --> UpdateDisplay[Update crowd status on event page]
    UpdateDisplay --> Confirm[Show: "Report submitted successfully"]
    Confirm --> EndSuccess([End])

    subgraph AvailabilityMonitoring ["Availability Monitoring"]
        Monitor[Monitor reporting feature uptime] --> UptimeCheck{Available ≥ 99.9% during event?}
        UptimeCheck -->|Yes| Continue[Continue monitoring]
        UptimeCheck -->|No| Fallback[Enable cached crowd status fallback]
        Fallback --> AlertOps[Alert operations team]
        AlertOps --> Continue
    end
```

## Diagram Explanation

1. **Open food event page** — The visitor navigates to the event details.
2. **Display current crowd status** — The latest aggregated crowd level is shown.
3. **Tap "Report crowd level"** — Visitor initiates a new report.
4. **Geofence check** — Only visitors physically near the event can report, preventing spam from remote users.
5. **Select crowd level** — Visitor chooses **Low**, **Moderate**, or **High**.
6. **Timestamp and location** — Metadata is attached to the report.
7. **Duplicate check** — Prevents the same user from submitting multiple reports within 30 minutes.
8. **Validation** — Ensures a valid selection was made.
9. **Report storage** — Valid reports are saved.
10. **Time-window filtering** — Only reports from the last 2 hours are considered.
11. **Weighting** — More recent reports contribute more to the final indicator.
12. **Outlier handling** — When 5 or more reports exist, outliers are excluded for accuracy.
13. **Aggregation** — Reports are combined into a consistent weighted average.
14. **Map to indicator** — The numeric result is mapped back to Low, Moderate, or High.
15. **Update display** — The event page refreshes with the new crowd status.
16. **Confirmation** — Visitor sees "Report submitted successfully".
17. **Availability monitoring** — Uptime is monitored during event hours; a cached fallback is used and operations are alerted if availability drops below 99.9%.
