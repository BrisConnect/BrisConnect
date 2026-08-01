# Activity Diagram: Admin — Review User Reports

## User Story

**As an** Admin,  
**I want to** review user reports,  
**So that** I can maintain trust and safety in the community.

## Acceptance Criteria

- Admin can view all user-submitted reports
- Reports are categorised (spam, inappropriate content, fake review, etc.)
- Admin can take action: dismiss, warn user, remove content, or suspend account
- Report resolution status is updated in real time
- Users are notified when their report is resolved
- Only authenticated Admins can access report management tools.
- All report actions are logged for auditing purposes.
- Reports load within 3 seconds.
- Status updates are reflected within 5 seconds.
- Admins can filter reports by category, status, date, and severity.
- User notifications are delivered successfully 99% of the time.

## Activity Diagram

```mermaid
flowchart TB
    Start([Admin opens report management dashboard]) --> Authenticate{Authenticated user?}

    Authenticate -->|No| ShowAuthPrompt[Prompt sign-in]
    ShowAuthPrompt --> EndNoAccess([End])

    Authenticate -->|Yes| CheckAdminRole{User has Admin role?}
    CheckAdminRole -->|No| DenyAccess[Show access denied]
    DenyAccess --> EndNotAdmin([End])

    CheckAdminRole -->|Yes| LoadDashboard[Load report management dashboard]
    LoadDashboard --> StartLoadTimer[Start 3-second load timer]

    StartLoadTimer --> FetchReports[Fetch all user-submitted reports]
    FetchReports --> ApplyFilters[Apply filters: category, status, date, severity]
    ApplyFilters --> DisplayQueue[Display reports queue]
    DisplayQueue --> LoadCheck{Reports loaded within 3 seconds?}
    LoadCheck -->|No| OptimiseLoad[Optimise query / paginate / cache]
    OptimiseLoad --> StartLoadTimer
    LoadCheck -->|Yes| SelectReport[Admin selects a report]

    SelectReport --> ViewDetails[View report details and category]
    ViewDetails --> DecideAction{Moderation action?}

    DecideAction -->|Dismiss| DismissReport[Dismiss report]
    DecideAction -->|Warn user| IssueWarning[Issue warning to reported user]
    DecideAction -->|Remove content| RemoveContent[Remove reported content]
    DecideAction -->|Suspend account| SuspendAccount[Suspend reported user account]

    DismissReport --> UpdateStatus[Update report resolution status]
    IssueWarning --> UpdateStatus
    RemoveContent --> UpdateStatus
    SuspendAccount --> UpdateStatus

    UpdateStatus --> StatusCheck{Status updated within 5 seconds?}
    StatusCheck -->|No| RetryUpdate[Retry status update]
    RetryUpdate --> UpdateStatus
    StatusCheck -->|Yes| NotifyReporter[Notify reporting user of resolution]

    NotifyReporter --> DeliveryCheck{Notification delivered?}
    DeliveryCheck -->|No| RetryNotification[Retry notification]
    RetryNotification --> DeliveryCheck
    DeliveryCheck -->|Yes| LogAction[Log action in audit log]

    LogAction --> EndManagement([End])

    subgraph AuditAndCompliance ["Audit & Compliance"]
        RecordAction[Record admin ID, action, reason, timestamp] --> SecureStore[Store audit log securely]
        SecureStore --> ImmutableCheck{Log tampered?}
        ImmutableCheck -->|Yes| AlertSecurity[Alert security team]
        ImmutableCheck -->|No| ContinueAudit[Continue]
    end

    subgraph NotificationReliability ["Notification Reliability"]
        TrackDelivery[Track notification delivery] --> SuccessRate{Success rate >= 99%?}
        SuccessRate -->|No| InvestigateFailures[Investigate delivery failures]
        InvestigateFailures --> TrackDelivery
        SuccessRate -->|Yes| ContinueMonitoring[Continue monitoring]
    end
```

## Diagram Explanation

1. **Open report management dashboard** — Admin navigates to the user reports section.
2. **Authentication check** — The user must be signed in.
3. **Admin role check** — Only users with an Admin role can proceed; otherwise, access is denied.
4. **Load dashboard** — The report management dashboard is loaded.
5. **Load timer** — Reports must load within 3 seconds.
6. **Fetch reports** — The system retrieves all user-submitted reports.
7. **Apply filters** — Admins can filter reports by category, status, date, and severity.
8. **Display queue** — Filtered reports are shown in the queue.
9. **Load performance check** — If reports fail to load within 3 seconds, the query is optimised and retried.
10. **Select report** — Admin selects a report to review.
11. **View details** — Admin sees the report content and its category, such as spam, inappropriate content, or fake review.
12. **Moderation action** — Admin chooses to dismiss, warn the user, remove content, or suspend the account.
13. **Update status** — The report resolution status is updated in real time.
14. **Status timing check** — Status updates must be reflected within 5 seconds; otherwise, the update is retried.
15. **Notify reporter** — The user who submitted the report is notified of the resolution.
16. **Delivery check** — Notifications are retried until delivered successfully.
17. **Log action** — Every report action is recorded in the audit log.
18. **Audit and compliance** — Audit logs are stored securely and checked for tampering.
19. **Notification reliability** — Delivery success rate is monitored to maintain 99% reliability.
