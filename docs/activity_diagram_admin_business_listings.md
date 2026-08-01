# Activity Diagram: Admin — Manage Local Business Listings

## User Story

**As an** Admin,  
**I want to** manage local business listings,  
**So that** only valid and accurate businesses appear on BrisConnect+.

## Acceptance Criteria

- Admin can create, edit, or delete business listings
- Admin can verify business authenticity before publishing
- Admin can deactivate outdated or duplicate listings
- Changes are reflected immediately on digital cards and feeds
- Each business has a unique identifier linked to all related content
- Only users with Admin privileges can create, edit, verify, or delete business listings.
- No data loss occurs during listing updates.
- Deleted listings are archived for recovery for 30 days.
- Business management services maintain 99.9% uptime.
- Duplicate business records are automatically flagged for review.
- Business verification records are stored for auditing purposes.

## Activity Diagram

```mermaid
flowchart TB
    Start([Admin opens business management dashboard]) --> Authenticate{Authenticated user?}

    Authenticate -->|No| ShowAuthPrompt[Prompt sign-in]
    ShowAuthPrompt --> EndNoAccess([End])

    Authenticate -->|Yes| CheckAdminRole{User has Admin privileges?}
    CheckAdminRole -->|No| DenyAccess[Show access denied]
    DenyAccess --> EndNotAdmin([End])

    CheckAdminRole -->|Yes| LoadDashboard[Load business management dashboard]
    LoadDashboard --> ChooseAction{Management action?}

    ChooseAction -->|Create| CreateListing[Create new business listing]
    ChooseAction -->|Edit| SelectListing[Select existing listing]
    ChooseAction -->|Verify| SelectForVerification[Select listing to verify]
    ChooseAction -->|Deactivate| SelectForDeactivation[Select listing to deactivate]
    ChooseAction -->|Delete| SelectForDeletion[Select listing to delete]

    CreateListing --> ValidateInput[Validate required fields and format]
    ValidateInput --> CheckDuplicate{Duplicate detected?}
    CheckDuplicate -->|Yes| FlagDuplicate[Flag listing for review]
    FlagDuplicate --> ReviewDuplicate[Admin reviews duplicate flag]
    ReviewDuplicate --> ProceedDecision{Proceed or reject?}
    ProceedDecision -->|Reject| EndRejected([End])
    ProceedDecision -->|Proceed| AssignUniqueId[Assign unique business identifier]

    CheckDuplicate -->|No| AssignUniqueId
    SelectListing --> EditListing[Edit business details]
    EditListing --> PreserveHistory[Preserve previous version in history]

    AssignUniqueId --> LinkRelatedContent[Link related content to unique ID]
    PreserveHistory --> LinkRelatedContent

    SelectForVerification --> VerifyAuthenticity[Verify business authenticity]
    VerifyAuthenticity --> VerificationDecision{Authentic?}
    VerificationDecision -->|No| RejectVerification[Reject verification]
    RejectVerification --> EndVerificationRejected([End])
    VerificationDecision -->|Yes| PublishListing[Publish or approve listing]

    SelectForDeactivation --> DeactivateListing[Deactivate outdated or duplicate listing]
    DeactivateListing --> HideFromFeeds[Hide from digital cards and feeds]

    SelectForDeletion --> ArchiveListing[Archive listing]
    ArchiveListing --> SoftDelete[Mark as deleted but recoverable]
    SoftDelete --> HideFromFeeds

    PublishListing --> SaveListing[Save listing to database]
    HideFromFeeds --> SaveListing
    LinkRelatedContent --> SaveListing

    SaveListing --> UpdateRealtime[Push changes to cards and feeds in real time]
    UpdateRealtime --> LogAction[Record action in audit log]

    LogAction --> EndManagement([End])

    subgraph DataIntegrity ["Data Integrity"]
        BackupBeforeUpdate[Backup current listing before update] --> ApplyChanges[Apply changes atomically]
        ApplyChanges --> VerifyNoLoss{Data preserved?}
        VerifyNoLoss -->|No| Rollback[Rollback to backup]
        Rollback --> ApplyChanges
        VerifyNoLoss -->|Yes| ContinueIntegrity[Continue]
    end

    subgraph ArchivingAndRecovery ["Archiving & Recovery"]
        ArchiveDeleted[Archive deleted listing] --> SetRecoveryWindow{Within 30 days?}
        SetRecoveryWindow -->|Yes| AllowRestore[Allow admin restore]
        AllowRestore --> RestoreListing[Restore listing]
        SetRecoveryWindow -->|No| PermanentDelete[Permanently delete archive]
    end

    subgraph AvailabilityAndAudit ["Availability & Audit"]
        MonitorUptime[Monitor business management service uptime] --> UptimeCheck{Availability >= 99.9%?}
        UptimeCheck -->|No| Failover[Trigger failover / incident response]
        Failover --> MonitorUptime
        UptimeCheck -->|Yes| ContinueMonitoring[Continue monitoring]
        StoreVerificationRecord[Store verification record securely] --> RetainForAudit[Retain for auditing]
    end
```

## Diagram Explanation

1. **Open business management dashboard** — Admin navigates to the business listings section.
2. **Authentication check** — The user must be signed in.
3. **Admin privileges check** — Only users with Admin privileges can proceed; otherwise, access is denied.
4. **Load dashboard** — The business management dashboard is loaded.
5. **Choose action** — Admin selects create, edit, verify, deactivate, or delete.
6. **Create listing** — Admin enters business details; required fields and format are validated.
7. **Duplicate detection** — New listings are checked against existing records and flagged if duplicates are detected.
8. **Assign unique identifier** — Each business receives a unique ID used to link related content.
9. **Edit listing** — Existing details are updated while the previous version is preserved.
10. **Verify authenticity** — Admin reviews and verifies the business before publishing.
11. **Publish listing** — Verified businesses are published and visible on the platform.
12. **Deactivate listing** — Outdated or duplicate listings are deactivated and hidden from cards and feeds.
13. **Delete listing** — Listings are archived and soft-deleted, remaining recoverable for 30 days.
14. **Save and propagate** — Changes are saved and reflected immediately on digital cards and feeds.
15. **Record audit log** — All create, edit, verify, deactivate, and delete actions are logged.
16. **Data integrity** — Listing updates are backed up and applied atomically to prevent data loss.
17. **Archiving and recovery** — Deleted listings are archived and can be restored within 30 days.
18. **Availability and audit** — Services are monitored for 99.9% uptime, and verification records are retained for auditing.
