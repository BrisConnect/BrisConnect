# Activity Diagram: Recommend Local Food Businesses

## User Story

**As a** Visitor,  
**I want to** leave a recommendation (rating + comment) on a local food business profile,  
**So that** other visitors can discover quality food experiences based on my feedback.

## Improved Acceptance Criteria

- Only authenticated visitors can submit recommendations.
- Recommendations are submitted from the business profile page.
- Each recommendation includes a **1–5 star rating** and an optional comment.
- A visitor can recommend a business **only once**; duplicate submissions are blocked.
- Recommendations are **permanently linked** to the correct business profile by ID.
- Recommendations appear publicly on the business profile in **chronological order**.
- The list of recommendations loads within **2 seconds** on a standard 4G connection.
- Users can **edit or delete** their own recommendations, but cannot modify others'.
- Spam and fake recommendations are filtered using **rate limiting** and automated content checks.
- The recommendation endpoint is monitored for **99.9% uptime**; cached data is served if live data is unavailable.
- The system scales to handle at least **10,000 concurrent visitors** during peak tourism periods.

## Activity Diagram

```mermaid
flowchart TB
    Start([Visitor opens app]) --> Browse[Browse food businesses]
    Browse --> ViewProfile[Open business profile]
    ViewProfile --> Authenticated{Visitor authenticated?}

    Authenticated -->|No| ShowAuthPrompt[Show sign-in / sign-up prompt]
    ShowAuthPrompt --> EndNoSubmit([End])

    Authenticated -->|Yes| TapRecommend[Tap "Recommend this business"]
    TapRecommend --> ExistingCheck{Already recommended this business?}

    ExistingCheck -->|Yes| ShowExisting[Show existing recommendation]
    ShowExisting --> EditOrCancel{Edit or cancel?}
    EditOrCancel -->|Edit| EnterRating
    EditOrCancel -->|Cancel| EndExisting([End])

    ExistingCheck -->|No| EnterRating[Enter 1-5 star rating]
    EnterRating --> AddComment[Add optional comment]
    AddComment --> ValidateInput{Valid rating and comment?}

    ValidateInput -->|No| ShowErrors[Show validation errors]
    ShowErrors --> EnterRating

    ValidateInput -->|Yes| LinkBusiness[Link recommendation to business profile ID]
    LinkBusiness --> SpamCheck{Pass spam and content checks?}

    SpamCheck -->|No| BlockSubmit[Block submission]
    BlockSubmit --> ShowSpamWarning[Show: "Recommendation could not be submitted"]
    ShowSpamWarning --> EndSpam([End])

    SpamCheck -->|Yes| SubmitRecommend[Submit recommendation]
    SubmitRecommend --> StoreSecurely[Store recommendation permanently]
    StoreSecurely --> UpdateProfile[Attach to business profile]

    UpdateProfile --> UpdateHistory[Update user's recommendation history]
    UpdateHistory --> LoadProfile[Reload business profile recommendations]

    LoadProfile --> PerformanceCheck{Load within 2 seconds?}
    PerformanceCheck -->|No| OptimizeQuery[Optimize query / cache data]
    OptimizeQuery --> LoadProfile

    PerformanceCheck -->|Yes| SortRecommendations[Sort recommendations chronologically]
    SortRecommendations --> DisplayRecommendations[Display recommendations to other users]
    DisplayRecommendations --> Confirm[Show: "Recommendation submitted"]
    Confirm --> EndSuccess([End])

    subgraph AuthorizationChecks ["Authorization & Integrity"]
        OwnerCheck{User owns recommendation?} -->|No| BlockEdit[Block edit or delete]
        OwnerCheck -->|Yes| AllowEdit[Allow edit or delete]
        BlockEdit --> LogViolation[Log unauthorized attempt]
    end

    subgraph AvailabilityMonitoring ["Availability Monitoring"]
        Monitor[Monitor recommendation feature uptime] --> UptimeCheck{Available ≥ 99.9%?}
        UptimeCheck -->|Yes| Continue[Continue monitoring]
        UptimeCheck -->|No| Fallback[Enable fallback / cached mode]
        Fallback --> AlertOps[Alert operations team]
        AlertOps --> Continue
    end

    subgraph ScalabilityMonitoring ["Scalability Monitoring"]
        TrafficCheck{Concurrent visitors > 10,000?} -->|Yes| ScaleResources[Auto-scale resources]
        ScaleResources --> ContinueScale[Continue monitoring]
        TrafficCheck -->|No| ContinueScale
    end
```

## Diagram Explanation

1. **Browse food businesses** — Visitor navigates the app to find businesses.
2. **Open business profile** — Visitor selects a specific business.
3. **Authentication check** — Only signed-in visitors can recommend.
4. **Existing recommendation check** — Prevents duplicate recommendations; allows editing an existing one.
5. **Enter rating and comment** — Visitor provides feedback.
6. **Validation** — Ensures the rating is valid and the comment meets content rules.
7. **Link to business profile** — Recommendation is permanently tied to the correct business by ID.
8. **Spam detection** — Rate limiting and content checks block fake or spam recommendations.
9. **Store securely** — Valid recommendation is saved to the database.
10. **Update profile and history** — The business profile and user's recommendation history are updated.
11. **Performance check** — Recommendations must load within 2 seconds; queries are optimized if not.
12. **Sort and display** — Recommendations appear in chronological order for other visitors.
13. **Confirmation** — Visitor sees a success message.
14. **Authorization checks** — Users can only edit or delete their own recommendations; unauthorized attempts are logged.
15. **Availability monitoring** — 99.9% uptime is monitored; fallback caching is used if live data fails.
16. **Scalability monitoring** — Resources auto-scale when concurrent visitors exceed 10,000, especially during peak tourism.
