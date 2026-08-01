# Activity Diagram: Community Activity Feed

## User Story

**As a** Visitor,  
**I want to** view a community activity feed,  
**So that** I can see reviews, photos, and recommendations shared by other users.

## Improved Acceptance Criteria

- The feed displays recent **reviews**, **photos**, and **recommendations** from community members.
- The feed updates automatically when new **approved** content is submitted.
- Users can filter feed content by **category** in 1–2 clicks.
- Each feed item links back to its original **event** or **business**.
- Empty feed states are handled with a helpful message.
- New approved content appears within **5–10 seconds**.
- The feed supports a high volume of posts without performance degradation.
- The system handles traffic spikes during **festivals, food markets, and major events**.
- Feed content remains **consistent across users** with no missing or duplicated posts.
- Only **approved/valid content** is shown through spam filtering and moderation.
- Harmful or inappropriate content is blocked by moderation controls.
- The feed works across **mobile, tablet, and desktop** with a responsive layout.
- Feed content and filters are intuitive and require no training.

## Activity Diagram

```mermaid
flowchart TB
    Start([Visitor opens community feed]) --> LoadFeed[Load recent reviews, photos, and recommendations]
    LoadFeed --> ApplyDefaultFilter[Apply default filter: all categories]

    ApplyDefaultFilter --> RenderFeed[Render feed items]
    RenderFeed --> DisplayFeed[Display feed with business/event links]

    DisplayFeed --> FilterAction{User applies filter?}

    FilterAction -->|Yes| SelectCategory[Select category filter in 1-2 clicks]
    SelectCategory --> ValidateFilter{Valid filter selection?}
    ValidateFilter -->|No| ShowFilterError[Show filter error]
    ShowFilterError --> SelectCategory
    ValidateFilter -->|Yes| FetchFiltered[Fetch filtered feed content]
    FetchFiltered --> RenderFeed

    FilterAction -->|No| ScrollFeed[Scroll feed]

    ScrollFeed --> NewContentCheck{New approved content available?}
    NewContentCheck -->|Yes| FetchNew[Fetch new content within 5-10 seconds]
    FetchNew --> ModerationCheck{Content passes moderation?}

    ModerationCheck -->|No| RejectContent[Reject or quarantine content]
    RejectContent --> NotifyModerator[Notify moderation team]
    NotifyModerator --> ScrollFeed

    ModerationCheck -->|Yes| DeduplicateCheck{Duplicate of existing post?}
    DeduplicateCheck -->|Yes| ScrollFeed
    DeduplicateCheck -->|No| AppendContent[Append to feed with animation]
    AppendContent --> RenderFeed

    NewContentCheck -->|No| EmptyCheck{Feed empty?}
    EmptyCheck -->|Yes| ShowEmptyState[Show: "No activity yet—be the first to post!"]
    ShowEmptyState --> EndEmpty([End])
    EmptyCheck -->|No| ScrollFeed

    subgraph ModerationPipeline ["Moderation Pipeline"]
        SubmitPost[User submits post] --> SpamCheck{Spam or inappropriate?}
        SpamCheck -->|Yes| AutoReject[Auto-reject]
        SpamCheck -->|No| ManualReview{Requires manual review?}
        ManualReview -->|Yes| QueueReview[Queue for moderator]
        ManualReview -->|No| ApproveContent[Approve and publish]
        QueueReview --> ModeratorDecision{Approved?}
        ModeratorDecision -->|Yes| ApproveContent
        ModeratorDecision -->|No| RejectContentMod[Reject content]
    end

    subgraph ConsistencyMonitoring ["Consistency Monitoring"]
        SyncCheck{Feed consistent across clients?} -->|No| Reconcile[Reconcile missing or duplicated posts]
        Reconcile --> SyncCheck
        SyncCheck -->|Yes| ContinueSync[Continue monitoring]
    end

    subgraph PerformanceMonitoring ["Performance Monitoring"]
        LoadTimeCheck{Feed loads within target?} -->|No| Optimize[Optimize queries / pagination]
        Optimize --> LoadTimeCheck
        LoadTimeCheck -->|Yes| ContinuePerf[Continue monitoring]
    end

    subgraph ScalabilityMonitoring ["Scalability Monitoring"]
        TrafficCheck{High post volume or event spike?} -->|Yes| ScaleResources[Auto-scale feed service]
        ScaleResources --> ContinueScale[Continue monitoring]
        TrafficCheck -->|No| ContinueScale
    end
```

## Diagram Explanation

1. **Open community feed** — Visitor navigates to the activity feed.
2. **Load feed** — Recent reviews, photos, and recommendations are loaded.
3. **Default filter** — All categories are shown by default.
4. **Render feed** — Items are displayed with links back to events or businesses.
5. **Apply category filter** — Visitors can filter in 1–2 clicks; invalid selections show an error.
6. **Scroll feed** — Visitor browses the feed.
7. **New content check** — The system polls for new approved content every 5–10 seconds.
8. **Moderation check** — New content must pass spam/inappropriateness checks.
9. **Deduplication check** — Duplicates are prevented.
10. **Append content** — New content appears in the feed with a smooth update.
11. **Empty state** — If no content exists, a helpful message is shown.
12. **Moderation pipeline** — Submitted posts are auto-checked and optionally queued for manual review.
13. **Consistency monitoring** — Ensures all users see the same feed without missing or duplicated posts.
14. **Performance monitoring** — Keeps feed load times fast through pagination and query optimization.
15. **Scalability monitoring** — Auto-scales during high-traffic events like festivals or food markets.
16. **Responsive layout** — The feed adapts to mobile, tablet, and desktop screen sizes.
