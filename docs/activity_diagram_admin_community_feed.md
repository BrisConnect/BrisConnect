# Activity Diagram: Admin — Control Community Feed

## User Story

**As an** Admin,  
**I want to** control the community feed,  
**So that** I can ensure relevant and safe content is displayed.

## Acceptance Criteria

- Admin can pin or highlight posts in the feed
- Admin can remove spam or irrelevant content
- Admin can filter feed by content type (reviews, photos, recommendations)
- Feed updates reflect moderation actions instantly
- System prevents banned content from reappearing

## Activity Diagram

```mermaid
flowchart TB
    Start([Admin opens community feed dashboard]) --> Authenticate{Authenticated user?}

    Authenticate -->|No| ShowAuthPrompt[Prompt sign-in]
    ShowAuthPrompt --> EndNoAccess([End])

    Authenticate -->|Yes| CheckAdminRole{User has Admin role?}
    CheckAdminRole -->|No| DenyAccess[Show access denied]
    DenyAccess --> EndNotAdmin([End])

    CheckAdminRole -->|Yes| LoadFeedDashboard[Load community feed dashboard]
    LoadFeedDashboard --> SelectContentFilter[Select content type filter]

    SelectContentFilter --> FetchFeedItems[Fetch feed items by type]
    FetchFeedItems --> DisplayFeed[Display filtered feed]

    DisplayFeed --> AdminAction{Admin action?}
    AdminAction -->|Pin / highlight| PinPost[Pin or highlight post]
    AdminAction -->|Remove content| RemoveContent[Remove spam or irrelevant post]
    AdminAction -->|Ban content| BanContent[Mark content as banned]
    AdminAction -->|Adjust filter| SelectContentFilter

    PinPost --> UpdateFeedRank[Update feed ranking and visibility]
    RemoveContent --> UpdateFeedRank
    BanContent --> AddToBannedList[Add content hash / ID to banned list]

    AddToBannedList --> ContentReappearsCheck{Same or matching content uploaded?}
    ContentReappearsCheck -->|Yes| BlockReupload[Block content from appearing]
    ContentReappearsCheck -->|No| ContinueMonitoring[Continue monitoring]

    BlockReupload --> UpdateFeedRank
    ContinueMonitoring --> UpdateFeedRank
    UpdateFeedRank --> PushRealtimeUpdate[Push real-time update to feed clients]

    PushRealtimeUpdate --> UpdateAuditLog[Record moderation action in audit log]
    UpdateAuditLog --> EndFeedManagement([End])

    subgraph FeedFiltering ["Feed Filtering"]
        FilterByType[Filter by reviews, photos, or recommendations] --> ApplySortOrder[Apply sort: pinned first, then recency / relevance]
        ApplySortOrder --> Pagination[Paginate results]
    end

    subgraph BannedContentPrevention ["Banned Content Prevention"]
        ScanUpload[Scan new upload against banned list] --> MatchCheck{Match found?}
        MatchCheck -->|Yes| AutoReject[Auto-reject and log attempt]
        MatchCheck -->|No| AllowToFeed[Allow into moderation queue or feed]
        AutoReject --> AlertAdmin[Alert admin of reupload attempt]
    end

    subgraph RealTimeSync ["Real-Time Feed Sync"]
        ModerationEvent[Moderation event occurs] --> BroadcastChange[Broadcast change via pub/sub or WebSocket]
        BroadcastChange --> ClientRefresh[Connected clients refresh feed item]
        ClientRefresh --> VerifyVisibility{Content visibility correct?}
        VerifyVisibility -->|No| ReapplyState[Reapply moderation state]
        ReapplyState --> BroadcastChange
        VerifyVisibility -->|Yes| ContinueSync[Continue]
    end
```

## Diagram Explanation

1. **Open community feed dashboard** — Admin navigates to the feed management section.
2. **Authentication check** — The user must be signed in.
3. **Admin role check** — Only users with an Admin role can proceed; otherwise, access is denied.
4. **Load dashboard** — The community feed dashboard is loaded.
5. **Select content filter** — Admin filters the feed by reviews, photos, or recommendations.
6. **Fetch feed items** — The system retrieves feed items matching the selected filter.
7. **Display feed** — Filtered feed items are shown to the admin.
8. **Admin action** — Admin chooses to pin/highlight, remove, ban content, or adjust the filter.
9. **Pin or highlight post** — Post is promoted in feed ranking and visually highlighted.
10. **Remove content** — Spam or irrelevant post is hidden from the feed.
11. **Ban content** — Content is added to a banned list to prevent reappearance.
12. **Reupload prevention** — New uploads are scanned against the banned list and blocked if they match.
13. **Update feed ranking** — Feed order and visibility are recalculated based on moderation actions.
14. **Push real-time update** — Changes are broadcast to all connected clients immediately.
15. **Record audit log** — Every moderation action is logged for accountability.
16. **Feed filtering** — Subgraph showing content-type filtering, sorting, and pagination logic.
17. **Banned content prevention** — Subgraph showing automated scanning and blocking of matching reuploads.
18. **Real-time sync** — Subgraph ensuring moderation state is consistently applied across all clients.
