# BrisConnect ERD (Strict v2 + Affiliation Extension)

This diagram models Firestore collections used by BrisConnect, including all
collections declared in `firestore.rules`.

```mermaid
erDiagram
    ADMINS {
        string email PK
        string username
        string name
        string role
        bool active
        string profileImageUrl
        datetime lastLoginAt
        datetime updatedAt
    }

    AFFILIATIONS {
        string id PK
        string name
        string type
        string suburb
        string status
        datetime createdAt
    }

    ADMIN_AFFILIATIONS {
        string adminEmail PK,FK
        string affiliationId PK,FK
        string accessScope
        datetime assignedAt
        string assignedByAdminEmail FK
    }

    LOCAL_USERS {
        string email PK
        string username
        string name
        string affiliationId FK
        string phone
        string suburb
        string role
        string accountType
        string approvalStatus
        string passwordHash
        string interestedEventIds
        string interestCategories
        bool notificationsEnabled
        bool useCurrentLocation
        int locationRadiusKm
        datetime createdAt
        datetime passwordUpdatedAt
    }

    VISITOR_USERS {
        string email PK
        string username
        string name
        string phone
        string role
        string passwordHash
        string interestedEventIds
        string savedAttractionIds
        string interestCategories
        string interestPriorities
        bool notificationsEnabled
        bool emailNotificationsEnabled
        bool useCurrentLocation
        int locationRadiusKm
        datetime createdAt
        datetime passwordUpdatedAt
    }

    EVENTS {
        string id PK
        string title
        string date
        string time
        string dateTime
        string category
        string location
        string venue
        string suburb
        string description
        string createdByLocalEmail FK
        string reviewStatus
        string approvalStatus
        string status
        bool isApproved
        int reportCount
        bool flaggedForAdminReview
        string source
        string sourceProvider
        string sourceUrl
        float latitude
        float longitude
        datetime createdAt
        datetime updatedAt
    }

    EVENT_REPORTS {
        string id PK
        string eventId FK
        string visitorEmail FK
        string reason
        string comments
        string status
        datetime createdAt
        datetime reviewedAt
    }

    APP_FEEDBACK {
        string id PK
        string referenceId
        string reporterRole
        string reporterEmail
        string reporterName
        string subject
        string category
        string severity
        string status
        bool consideredForFix
        int maintenanceWindowDays
        datetime resolutionDueAt
        datetime adminReplyAt
        bool replyReadByReporter
        string imageUrl
        string imageStoragePath
        datetime createdAt
        datetime updatedAt
    }

    USER_NOTIFICATIONS {
        string id PK
        string eventId FK
        string userEmail
        string userType
        string eventTitle
        string eventDateTime
        string eventLocation
        string scheduleType
        bool isRead
        datetime createdAt
    }

    ATTRACTIONS {
        string id PK
        string name
        string title
        string description
        string location
        float latitude
        float longitude
        string category
        string accessibilityDetails
        string webLink
        string imageUrl
        string imageStoragePath
        string audioUrl
        string audioStoragePath
        string approvalStatus
        bool isApproved
        datetime createdAt
        datetime updatedAt
    }

    ATTRACTION_DETAILS {
        string id PK
        string history
        string address
        string openingHours
        string specialSchedule
        string entryRequirements
        string ticketPrice
        string bookingLabel
        string bookingUrl
        float rating
        int reviewCount
        string facilities
        string amenities
        string accessibility
        string visitDuration
        string bestTimeToVisit
        string liveUpdate
        string nearbyAttractions
        string nearbyServices
        string languages
        string audioFeatures
    }

    DISCOVER_ITEMS {
        string id PK
        string title
        string section
        string category
        string location
        string venue
        string suburb
        string date
        string time
        string dateTime
        string description
        string approvalStatus
        string source
        string sourceProvider
        string sourcePlaceId
        string sourceUrl
        string createdByLocalEmail
        string imageUrl
        string audioUrl
        string videoUrl
        datetime updatedAt
    }

    BRISBANE_STORIES {
        string id PK
        string title
        string description
        string imageUrl
        string category
        string content
        float latitude
        float longitude
        string locationName
        string approvalStatus
        datetime publishedAt
        datetime createdAt
    }

    BRISBANE_VOICES {
        string id PK
        string name
        string quote
        string profileImageUrl
        string approvalStatus
        datetime createdAt
    }

    MAIL {
        string id PK
        string to
        string message
        string meta
        datetime createdAt
    }

    SMS_QUEUE {
        string id PK
        string to
        string message
        string meta
        datetime createdAt
    }

    COUNTERS {
        string id PK
        int count
    }

    CONFIG {
        string id PK
        string payload
    }

    SEED_METADATA {
        string id PK
        int version
        string sourceProvider
        int discoverItemCount
        int attractionCount
        int eventCount
        int writeCount
        datetime seededAt
        datetime lastSyncedAt
    }

    CONNECTIVITY_PROBE {
        string id PK
        string payload
    }

    ADMINS ||--o{ ADMIN_AFFILIATIONS : granted
    ADMINS ||--o{ ADMIN_AFFILIATIONS : assigned_by
    AFFILIATIONS ||--o{ ADMIN_AFFILIATIONS : maps
    AFFILIATIONS ||--o{ LOCAL_USERS : includes
    LOCAL_USERS ||--o{ EVENTS : submits
    VISITOR_USERS ||--o{ EVENT_REPORTS : files
    EVENTS ||--o{ EVENT_REPORTS : receives
    EVENTS ||--o{ USER_NOTIFICATIONS : triggers
    LOCAL_USERS ||--o{ USER_NOTIFICATIONS : receives
    VISITOR_USERS ||--o{ USER_NOTIFICATIONS : receives
    ATTRACTIONS ||--o| ATTRACTION_DETAILS : has_detail_profile
    ATTRACTIONS ||--o| DISCOVER_ITEMS : mirrored_as
    EVENTS ||--o| DISCOVER_ITEMS : published_as
    COUNTERS ||--o{ APP_FEEDBACK : issues_reference_ids
    LOCAL_USERS }o--o{ EVENTS : interested_in
    VISITOR_USERS }o--o{ EVENTS : interested_in
    VISITOR_USERS }o--o{ ATTRACTIONS : saves

```

## Notes

- Firestore document IDs are semantic in several collections: `admins`, `local_users`, and `visitor_users` use lowercase email as the document key.
- `CONNECTIVITY_PROBE` exists in security rules (`_connectivity_probe/{docId}`) and is read-only from clients.
- `event_reports.id` is a synthetic composite key: `eventId__visitorEmail`.
- `app_feedback.id` is the lowercase form of `referenceId` such as `fb-0001`; the increment source is `counters/app_feedback`.
- `discover_items` is a denormalized catalog. Approved `events` and approved `attractions` are mirrored into it for discovery screens.
- `user_notifications`, `mail`, and `sms_queue` use payload fields like `userEmail`, `eventId`, and `meta` rather than strict Firestore foreign keys, so those links are application-level references.
- `attraction_details` uses the same document ID as its parent attraction when detail data exists.
- `brisbane_stories` and `brisbane_voices` are curated content collections with no enforced foreign-key relationship to the transactional entities.
- `affiliations` and `admin_affiliations` are modeled as an ERD extension for database design and migration planning; they are not currently present in strict Firestore rules.

## Required vs Optional (As Implemented)

- Firestore is schemaless, so required/optional status comes from app write paths, not Firestore schema enforcement.
- Required-on-create fields from current code paths:
    - `local_users`: `name`, `email`, `phone`, `suburb`, `role`, `accountType`, `approvalStatus`, `passwordHash`
    - `visitor_users`: `name`, `email`, `role`, `passwordHash`
    - `events` (local submission and sync paths): `id`, `title`, plus status/source metadata depending on writer
    - `event_reports`: `id`, `eventId`, `visitorEmail`, `reason`, `status`
    - `app_feedback`: `id`, `referenceId`, `reporterRole`, `reporterEmail`, `subject`, `details`, `status`
- Frequently optional or source-dependent:
    - `events`: `venue`, `suburb`, `latitude`, `longitude`, media fields
    - `discover_items`: fields vary by section (`events`, `historical`, `food`)
    - `mail`, `sms_queue`, `config`: flexible payload objects