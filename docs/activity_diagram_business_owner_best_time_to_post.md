# Activity Diagram: Business Owner — Best Time to Post

## User Story

**As a** local food business owner,  
**I want to** know when my customers are most active in the app,  
**So that** I can time my promotions for maximum impact.

## Acceptance Criteria

- Given I have at least 2 weeks of promotion history, when I open "Best Time to Post," then the dashboard suggests optimal days/times based on my own historical engagement.
- Given I schedule a promotion outside the suggested window, when I confirm, then the app gives a soft warning (not a block) noting it may get less visibility.
- “Best Time to Post” insights are generated within 3–5 seconds of opening the dashboard.
- System only generates recommendations when at least 14 days of engagement data is available.
- Recommendations are based on statistically significant engagement patterns (not random variation).
- System prioritises peak engagement periods with highest conversion rates.
- System supports increasing historical data without degrading recommendation speed or accuracy.
- System provides a brief explanation of why a time is recommended (e.g. “highest engagement on Fridays 6–8pm”).
- Customer engagement data is anonymised and aggregated before analysis.

## Activity Diagram

```mermaid
flowchart TB
    Start([Business owner opens app]) --> Authenticate{Authenticated as business owner?}

    Authenticate -->|No| ShowAuthPrompt[Prompt sign-in]
    ShowAuthPrompt --> EndNoAccess([End])

    Authenticate -->|Yes| NavigateBestTime[Navigate to Best Time to Post]
    NavigateBestTime --> LoadDashboard[Open dashboard]

    LoadDashboard --> CheckData{At least 14 days of engagement data?}
    CheckData -->|No| ShowInsufficientData[Show: "Not enough data yet. Keep using promotions for 14+ days."]
    ShowInsufficientData --> EndInsufficient([End])

    CheckData -->|Yes| Anonymize[Anonymise and aggregate customer engagement data]
    Anonymize --> StartTimer[Start 3-5 second insight timer]

    StartTimer --> AnalyzePatterns[Analyse historical engagement patterns]
    AnalyzePatterns --> StatisticalCheck{Patterns statistically significant?}

    StatisticalCheck -->|No| ShowLowConfidence[Show: "Trends are still emerging; results may change as more data is collected"]
    ShowLowConfidence --> EndLowConfidence([End])

    StatisticalCheck -->|Yes| RankPeaks[Rank peak engagement periods by conversion rate]
    RankPeaks --> GenerateRecommendations[Generate Best Time to Post recommendations]

    GenerateRecommendations --> AddExplanation[Attach brief explanation for each recommendation]
    AddExplanation --> RenderDashboard[Render dashboard with suggested days/times]

    RenderDashboard --> UserSelectsTime[Owner selects promotion day/time]
    UserSelectsTime --> CheckSuggested{Selected time within suggested window?}

    CheckSuggested -->|Yes| ConfirmSchedule[Confirm scheduling]
    ConfirmSchedule --> EndScheduled([End])

    CheckSuggested -->|No| ShowSoftWarning[Show soft warning: "This time may get less visibility"]
    ShowSoftWarning --> OwnerConfirms{Owner confirms anyway?}

    OwnerConfirms -->|Yes| ConfirmSchedule
    OwnerConfirms -->|No| ReturnToDashboard[Return to dashboard to select another time]
    ReturnToDashboard --> RenderDashboard

    subgraph PerformanceAndScalability ["Performance & Scalability"]
        TimerCheck{Insights ready within 3-5 seconds?} -->|No| OptimizeQuery[Optimise query / pre-aggregate data]
        OptimizeQuery --> TimerCheck
        TimerCheck -->|Yes| ContinuePerformance[Continue]
        ScaleCheck{Increasing data volume?} -->|Yes| UseIncrementalAggregation[Use incremental aggregation]
        UseIncrementalAggregation --> ScaleCheck
        ScaleCheck -->|No| ContinueScalability[Continue]
    end

    subgraph PrivacyCompliance ["Privacy Compliance"]
        CollectData[Collect engagement data] --> RemovePII[Remove personally identifiable information]
        RemovePII --> Aggregate[Aggregate by cohort and time slot]
        Aggregate --> StoreSecurely[Store securely with access controls]
    end
```

## Diagram Explanation

1. **Open app** — Business owner launches the app.
2. **Authentication check** — Only authenticated business owners can access the "Best Time to Post" feature.
3. **Navigate to Best Time to Post** — Owner selects the dashboard.
4. **Data availability check** — The system verifies at least 14 days of engagement data exist; otherwise, it shows an insufficient-data message.
5. **Anonymise and aggregate** — Customer engagement data is stripped of PII and grouped to protect privacy.
6. **Performance timer** — Insight generation begins with a 3–5 second target.
7. **Analyse patterns** — Historical engagement is analysed to detect recurring activity peaks.
8. **Statistical significance check** — Recommendations are only produced when patterns are statistically significant, not random noise.
9. **Rank by conversion** — Peak periods are prioritised by the highest conversion rates.
10. **Generate recommendations** — Optimal days and times are calculated.
11. **Attach explanations** — Each recommendation includes a brief rationale, e.g. "highest engagement on Fridays 6–8pm".
12. **Render dashboard** — Suggested windows are displayed to the owner.
13. **Select promotion time** — Owner picks a day/time for the promotion.
14. **Suggested-window check** — If outside the recommended window, a soft warning is shown but not blocking.
15. **Confirm scheduling** — The promotion is scheduled.
16. **Performance and scalability** — Insight generation stays within 3–5 seconds and remains efficient as data grows.
17. **Privacy compliance** — Raw engagement data is anonymised, aggregated, and stored securely.
