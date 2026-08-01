# Activity Diagram: Business Owner Audience Analytics

## User Story

**As a** Business Owner,  
**I want to** see basic information about who is engaging with my business (e.g., time of day, repeat vs. new visitors),  
**So that** I can tailor promotions to my actual audience.

## Improved Acceptance Criteria

- Only **authenticated business owners** can access audience analytics.
- The Audience tab shows a breakdown of **new vs. returning viewers**.
- Owners can select a **date range** and see engagement broken down by **time of day** and **day of week**.
- If the data sample has **fewer than 20 interactions**, the app shows a warning that results may not be statistically meaningful.
- Data is updated at least every **15 minutes**.
- Customer data is **anonymized and aggregated** to ensure privacy compliance.
- The system supports **WCAG 2.1 AA** accessibility standards.
- Charts and tables are **responsive** across desktop, tablet, and mobile devices.

## Activity Diagram

```mermaid
flowchart TB
    Start([Business owner opens app]) --> Authenticate{Authenticated as business owner?}

    Authenticate -->|No| ShowAuthPrompt[Prompt sign-in]
    ShowAuthPrompt --> EndNoAccess([End])

    Authenticate -->|Yes| NavigateAudience[Navigate to Audience tab]
    NavigateAudience --> LoadAnalytics[Load audience analytics]

    LoadAnalytics --> Anonymize[Anonymize and aggregate customer data]
    Anonymize --> SelectRange[Select date range]

    SelectRange --> SampleCheck{At least 20 interactions?}

    SampleCheck -->|No| ShowSampleWarning[Show: "Results may not be statistically meaningful yet"]
    ShowSampleWarning --> EndSmallSample([End])

    SampleCheck -->|Yes| GenerateReport[Generate audience report]

    GenerateReport --> NewVsReturning[Show new vs. returning viewers breakdown]
    NewVsReturning --> TimeOfDay[Show engagement by time of day]
    TimeOfDay --> DayOfWeek[Show engagement by day of week]

    DayOfWeek --> RenderCharts[Render accessible charts and tables]
    RenderCharts --> UpdateCheck{15 minutes elapsed since last update?}

    UpdateCheck -->|No| ContinueViewing[Continue viewing current data]
    ContinueViewing --> RenderCharts

    UpdateCheck -->|Yes| RefreshData[Refresh analytics data]
    RefreshData --> Anonymize

    subgraph PrivacyCompliance ["Privacy Compliance"]
        CollectData[Collect interaction data] --> RemovePII[Remove personally identifiable information]
        RemovePII --> Aggregate[Aggregate by cohort and time slot]
        Aggregate --> StoreSecurely[Store securely with access controls]
    end

    subgraph AccessibilityChecks ["Accessibility & Responsiveness"]
        WcagCheck{WCAG 2.1 AA compliant?} -->|No| FixAccessibility[Fix chart labels, contrast, keyboard navigation]
        FixAccessibility --> WcagCheck
        WcagCheck -->|Yes| ContinueWcag[Continue]
        ResponsiveCheck{Responsive on desktop, tablet, mobile?} -->|No| FixLayout[Adjust responsive layout]
        FixLayout --> ResponsiveCheck
        ResponsiveCheck -->|Yes| ContinueResponsive[Continue]
    end
```

## Diagram Explanation

1. **Open app** — Business owner launches the app.
2. **Authentication check** — Only authenticated business owners can access audience analytics.
3. **Navigate to Audience tab** — Owner selects the audience analytics section.
4. **Load analytics** — Interaction data is retrieved for the business.
5. **Anonymize and aggregate** — Personal data is removed and grouped to protect privacy.
6. **Select date range** — Owner chooses the period to analyze.
7. **Sample size check** — If fewer than 20 interactions exist, a warning is shown instead of misleading precision.
8. **Generate report** — The audience report is created.
9. **New vs. returning viewers** — Breakdown of first-time and repeat visitors.
10. **Engagement by time of day** — Shows when visitors are most active.
11. **Engagement by day of week** — Shows weekly activity patterns.
12. **Render charts** — Accessible charts and tables are displayed.
13. **Update check** — Data refreshes at least every 15 minutes.
14. **Privacy compliance** — Raw interaction data is stripped of PII, aggregated, and stored securely.
15. **Accessibility and responsiveness** — Charts meet WCAG 2.1 AA and adapt to all screen sizes.
