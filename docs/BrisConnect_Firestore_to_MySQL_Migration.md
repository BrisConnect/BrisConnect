# BrisConnect Firestore to MySQL Migration Notes

## 1) Migration Goal

Move the current Firestore-backed data model to MySQL while preserving:

- Existing app behavior and permissions.
- Existing IDs and references where possible.
- Auditability (created/updated timestamps, moderation actions).
- Data quality for analytics and reporting.

## 2) Recommended Strategy (Phased)

1. Phase A: Prepare schema and staging
- Deploy `docs/BrisConnect_MySQL_Schema.sql` to a staging MySQL instance.
- Add a one-time `source_firestore_path` column in staging tables if you want row-level traceability during migration.
- Create read-only DB user for verification queries.

2. Phase B: Backfill historical data
- Export Firestore collections to JSON/CSV snapshots.
- Run ETL scripts collection-by-collection in dependency order.
- Re-run ETL idempotently until counts and checksums match.

3. Phase C: Dual-write window
- Update backend service layer to write to Firestore and MySQL.
- Keep reads on Firestore first.
- Monitor divergence using nightly reconciliation jobs.

4. Phase D: Read cutover
- Switch low-risk reads first (reference lists, public content).
- Switch transactional reads next (events, reports, notifications).
- Keep Firestore writes for a short fallback window.

5. Phase E: Final cutover and decommission
- Stop Firestore writes.
- Keep Firestore snapshots archived for compliance/rollback.
- Remove dual-write once stability KPIs are met.

## 3) Entity Migration Order

Use this order to satisfy foreign keys and avoid temporary null references:

1. `admins`
2. `local_users`, `visitor_users`
3. `attractions`
4. `events`
5. `attraction_details`, `discover_items`
6. `event_reports`, `app_feedback`, `user_notifications`
7. Junction tables:
   - `local_user_interested_events`
   - `visitor_user_interested_events`
   - `visitor_user_saved_attractions`
   - `local_user_interest_categories`
   - `visitor_user_interest_categories`
8. Supporting tables:
   - `seed_metadata`, `counters`, `app_config`
   - `mail_queue`, `sms_queue`
   - `brisbane_stories`, `brisbane_voices`, `connectivity_probe`

## 4) Firestore to MySQL Mapping Rules

## IDs and keys
- Firestore document IDs should be retained as primary keys in MySQL (`VARCHAR`).
- Collection/document paths should not be used as keys in final schema (only optional trace columns during migration).

## Timestamps
- Firestore `Timestamp` should map to `DATETIME(3)`.
- Preserve UTC on both write and read paths.

## Arrays
- Arrays used for relationships should become junction tables.
- Arrays of primitive metadata can remain in `JSON` if not query-critical.

## Maps/objects
- Flexible nested objects should map to `JSON` columns (for example details payloads).
- Frequently filtered fields should be promoted to first-class columns.

## Booleans/enums
- Firestore boolean fields map to `BOOLEAN`.
- Status strings should be normalized to controlled enum-like values in app validation.

## 5) ETL Implementation Pattern

Use a repeatable ETL pattern per collection:

1. Extract
- Pull full collection snapshot with document ID + payload.

2. Transform
- Apply type normalization.
- Split arrays into relational rows for junction tables.
- Coerce missing optional fields to `NULL`.

3. Load
- Use `INSERT ... ON DUPLICATE KEY UPDATE` for idempotency.
- Batch loads in consistent chunk sizes (for example 500 to 2000 rows).

4. Validate
- Row counts per collection/table.
- Field-level spot checks on critical entities.
- Referential integrity checks (orphan detection queries).

## 6) Index and Query Considerations

- Recreate Firestore composite query behavior with MySQL indexes.
- Existing known composite from Firestore:
  - `event_reports(status ASC, createdAt DESC)`
- Equivalent MySQL index recommendation:
  - `CREATE INDEX idx_event_reports_status_created_at ON event_reports(status, created_at DESC);`
- Add indexes gradually based on observed API query plans (`EXPLAIN`).

## 7) Data Quality and Reconciliation

Run these checks during dual-write:

1. Count parity
- Compare Firestore document counts vs MySQL row counts by domain.

2. Referential parity
- Verify every `event_reports.event_id` exists in `events.id`.
- Verify every notification `event_id` (when not null) exists in `events.id`.

3. Business parity
- Compare approved/rejected/open counts for moderation entities.
- Compare active upcoming events by date range.

4. Sample payload parity
- Randomly sample records and compare key fields and JSON payloads.

## 8) Security and Access Model Changes

- Firestore Rules are replaced by application-layer authorization + DB grants.
- Enforce role checks in service code (admin/local/visitor).
- Use least-privilege DB users:
  - app runtime user (CRUD on app tables)
  - migration user (bulk write during ETL)
  - read-only analytics user

## 9) Rollback Plan

If cutover issues occur:

1. Switch reads back to Firestore using feature flag.
2. Continue dual-write while fixes are applied.
3. Rebuild inconsistent tables from latest Firestore snapshot.
4. Repeat reconciliation before retrying cutover.

## 10) Cutover Readiness Checklist

- [ ] Schema applied successfully in staging and production.
- [ ] Backfill completed with parity checks passed.
- [ ] Dual-write enabled and stable for agreed soak period.
- [ ] No unresolved orphan/reference errors.
- [ ] API performance meets baseline SLO after read switch.
- [ ] Rollback switch tested and documented.

## 11) Attached ERD to Current Firestore Mapping Matrix

Status meanings:
- exact: Same concept and usable field exists in Firestore (same or compatible semantics).
- needs transform: Field exists but requires name, shape, or normalization change.
- missing: No current Firestore collection/field with equivalent semantics.

### ADMINS

| ERD Entity | ERD Field | Firestore Collection | Firestore Field/Path | Status | Notes |
|---|---|---|---|---|---|
| ADMINS | email | admins | document id and email | needs transform | Firestore key is doc id (lowercase email). |
| ADMINS | username | admins | username | exact | Same semantics. |
| ADMINS | role | admins | role | exact | Same semantics. |
| ADMINS | active | admins | active | exact | Same semantics. |
| ADMINS | created_at | admins | - | missing | Not part of current documented admin core fields. |

### ADMIN_AFFILIATIONS

| ERD Entity | ERD Field | Firestore Collection | Firestore Field/Path | Status | Notes |
|---|---|---|---|---|---|
| ADMIN_AFFILIATIONS | admin_email | - | - | missing | No admin_affiliations collection in rules/schema. |
| ADMIN_AFFILIATIONS | affiliation_id | - | - | missing | No affiliations model currently implemented. |
| ADMIN_AFFILIATIONS | access_scope | - | - | missing | Missing domain. |
| ADMIN_AFFILIATIONS | assigned_at | - | - | missing | Missing domain. |
| ADMIN_AFFILIATIONS | assigned_by_admin_email | - | - | missing | Missing domain. |

### AFFILIATIONS

| ERD Entity | ERD Field | Firestore Collection | Firestore Field/Path | Status | Notes |
|---|---|---|---|---|---|
| AFFILIATIONS | name | - | - | missing | No affiliations collection exists. |
| AFFILIATIONS | type | - | - | missing | Missing domain. |
| AFFILIATIONS | suburb | - | - | missing | Missing domain. |
| AFFILIATIONS | status | - | - | missing | Missing domain. |
| AFFILIATIONS | created_at | - | - | missing | Missing domain. |

### LOCAL_USERS

| ERD Entity | ERD Field | Firestore Collection | Firestore Field/Path | Status | Notes |
|---|---|---|---|---|---|
| LOCAL_USERS | email | local_users | document id and email | needs transform | Doc id is lowercase email; field also stored. |
| LOCAL_USERS | username | local_users | username | exact | Same semantics. |
| LOCAL_USERS | name | local_users | name | exact | Same semantics. |
| LOCAL_USERS | affiliation_id | local_users | - | missing | No affiliation link in current user model. |
| LOCAL_USERS | approval_status | local_users | approvalStatus | needs transform | snake_case to camelCase. |
| LOCAL_USERS | account_type | local_users | accountType | needs transform | snake_case to camelCase. |
| LOCAL_USERS | created_at | local_users | createdAt | needs transform | snake_case to camelCase timestamp. |

### EVENTS

| ERD Entity | ERD Field | Firestore Collection | Firestore Field/Path | Status | Notes |
|---|---|---|---|---|---|
| EVENTS | id | events | document id and id | needs transform | Firestore uses doc id; id may also be duplicated in payload. |
| EVENTS | title | events | title | exact | Same semantics. |
| EVENTS | description | events | description | exact | Same semantics. |
| EVENTS | location | events | location | exact | Same semantics. |
| EVENTS | created_by_local_email | events | createdByLocalEmail | needs transform | snake_case to camelCase. |
| EVENTS | review_status | events | reviewStatus | needs transform | snake_case to camelCase. |
| EVENTS | approval_status | events | approvalStatus | needs transform | snake_case to camelCase. |
| EVENTS | is_approved | events | isApproved | needs transform | snake_case to camelCase boolean. |
| EVENTS | created_at | events | createdAt | needs transform | snake_case to camelCase timestamp. |
| EVENTS | source | events | source | exact | Same semantics. |
| EVENTS | external_id | events | - | missing | No standard event-level external id field in current schema. |
| EVENTS | source_url | events | sourceUrl | needs transform | snake_case to camelCase. |
| EVENTS | synced_at | events | - | missing | No event-level sync timestamp; sync metadata is elsewhere. |

### FEEDBACK_RESPONSES

| ERD Entity | ERD Field | Firestore Collection | Firestore Field/Path | Status | Notes |
|---|---|---|---|---|---|
| FEEDBACK_RESPONSES | id | - | - | missing | No separate feedback_responses collection. |
| FEEDBACK_RESPONSES | feedback_id | app_feedback | id (doc id) | needs transform | Response data is embedded in app_feedback doc. |
| FEEDBACK_RESPONSES | admin_email | app_feedback | - | missing | Admin responder identity not modeled as dedicated field. |
| FEEDBACK_RESPONSES | response_text | app_feedback | adminReply | needs transform | Stored inline on app_feedback document. |
| FEEDBACK_RESPONSES | responded_at | app_feedback | adminReplyAt | needs transform | Stored inline on app_feedback document. |

### ATTRACTION_REVIEW_LOG

| ERD Entity | ERD Field | Firestore Collection | Firestore Field/Path | Status | Notes |
|---|---|---|---|---|---|
| ATTRACTION_REVIEW_LOG | id | - | - | missing | No dedicated attraction review log collection. |
| ATTRACTION_REVIEW_LOG | attraction_id | - | - | missing | Not logged in separate audit documents. |
| ATTRACTION_REVIEW_LOG | admin_email | - | - | missing | Not logged in separate audit documents. |
| ATTRACTION_REVIEW_LOG | action | - | - | missing | Not logged in separate audit documents. |
| ATTRACTION_REVIEW_LOG | notes | - | - | missing | Not logged in separate audit documents. |
| ATTRACTION_REVIEW_LOG | reviewed_at | - | - | missing | Not logged in separate audit documents. |

### LOCAL_ACCOUNT_REVIEW_LOG

| ERD Entity | ERD Field | Firestore Collection | Firestore Field/Path | Status | Notes |
|---|---|---|---|---|---|
| LOCAL_ACCOUNT_REVIEW_LOG | id | - | - | missing | No dedicated local account review log collection. |
| LOCAL_ACCOUNT_REVIEW_LOG | local_email | - | - | missing | Not logged in separate audit documents. |
| LOCAL_ACCOUNT_REVIEW_LOG | admin_email | - | - | missing | Not logged in separate audit documents. |
| LOCAL_ACCOUNT_REVIEW_LOG | action | - | - | missing | Not logged in separate audit documents. |
| LOCAL_ACCOUNT_REVIEW_LOG | notes | - | - | missing | Not logged in separate audit documents. |
| LOCAL_ACCOUNT_REVIEW_LOG | reviewed_at | - | - | missing | Not logged in separate audit documents. |

### EVENT_REVIEW_LOG

| ERD Entity | ERD Field | Firestore Collection | Firestore Field/Path | Status | Notes |
|---|---|---|---|---|---|
| EVENT_REVIEW_LOG | id | - | - | missing | No dedicated event review log collection. |
| EVENT_REVIEW_LOG | event_id | - | - | missing | Not logged in separate audit documents. |
| EVENT_REVIEW_LOG | admin_email | - | - | missing | Not logged in separate audit documents. |
| EVENT_REVIEW_LOG | action | - | - | missing | Not logged in separate audit documents. |
| EVENT_REVIEW_LOG | notes | - | - | missing | Not logged in separate audit documents. |
| EVENT_REVIEW_LOG | reviewed_at | - | - | missing | Not logged in separate audit documents. |

### APP_FEEDBACK

| ERD Entity | ERD Field | Firestore Collection | Firestore Field/Path | Status | Notes |
|---|---|---|---|---|---|
| APP_FEEDBACK | id | app_feedback | document id | exact | Same semantics (reference id lowercase as doc id). |
| APP_FEEDBACK | reporter_email | app_feedback | reporterEmail | needs transform | snake_case to camelCase. |
| APP_FEEDBACK | reporter_role | app_feedback | reporterRole | needs transform | snake_case to camelCase. |
| APP_FEEDBACK | status | app_feedback | status | exact | Same semantics. |
| APP_FEEDBACK | created_at | app_feedback | createdAt | needs transform | snake_case to camelCase timestamp. |

### ATTRACTIONS

| ERD Entity | ERD Field | Firestore Collection | Firestore Field/Path | Status | Notes |
|---|---|---|---|---|---|
| ATTRACTIONS | id | attractions | document id and id | needs transform | Firestore uses doc id as primary key. |
| ATTRACTIONS | name | attractions | name | exact | Same semantics. |
| ATTRACTIONS | review_status | attractions | reviewStatus | needs transform | snake_case to camelCase. |
| ATTRACTIONS | approval_status | attractions | approvalStatus | needs transform | snake_case to camelCase. |
| ATTRACTIONS | is_approved | attractions | isApproved | needs transform | snake_case to camelCase. |
| ATTRACTIONS | created_at | attractions | createdAt | needs transform | snake_case to camelCase timestamp. |

### ATTRACTION_DETAILS

| ERD Entity | ERD Field | Firestore Collection | Firestore Field/Path | Status | Notes |
|---|---|---|---|---|---|
| ATTRACTION_DETAILS | attraction_id | attraction_details | document id | needs transform | Relationship is via shared doc id, not explicit field. |
| ATTRACTION_DETAILS | address | attraction_details | address | exact | Same semantics. |
| ATTRACTION_DETAILS | rating | attraction_details | rating | exact | Same semantics. |
| ATTRACTION_DETAILS | review_count | attraction_details | reviewCount | needs transform | snake_case to camelCase. |

### USER_NOTIFICATIONS

| ERD Entity | ERD Field | Firestore Collection | Firestore Field/Path | Status | Notes |
|---|---|---|---|---|---|
| USER_NOTIFICATIONS | id | user_notifications | document id | exact | Same semantics. |
| USER_NOTIFICATIONS | event_id | user_notifications | eventId | needs transform | snake_case to camelCase. |
| USER_NOTIFICATIONS | user_email | user_notifications | userEmail | needs transform | snake_case to camelCase. |
| USER_NOTIFICATIONS | user_type | user_notifications | userType | needs transform | snake_case to camelCase. |
| USER_NOTIFICATIONS | is_read | user_notifications | isRead | needs transform | snake_case to camelCase. |
| USER_NOTIFICATIONS | created_at | user_notifications | createdAt | needs transform | snake_case to camelCase timestamp. |

### EVENT_REPORTS

| ERD Entity | ERD Field | Firestore Collection | Firestore Field/Path | Status | Notes |
|---|---|---|---|---|---|
| EVENT_REPORTS | id | event_reports | document id | exact | Same semantics (composite id pattern in current app). |
| EVENT_REPORTS | event_id | event_reports | eventId | needs transform | snake_case to camelCase. |
| EVENT_REPORTS | visitor_email | event_reports | visitorEmail | needs transform | snake_case to camelCase. |
| EVENT_REPORTS | status | event_reports | status | exact | Same semantics. |
| EVENT_REPORTS | created_at | event_reports | createdAt | needs transform | snake_case to camelCase timestamp. |

### VISITOR_USERS

| ERD Entity | ERD Field | Firestore Collection | Firestore Field/Path | Status | Notes |
|---|---|---|---|---|---|
| VISITOR_USERS | email | visitor_users | document id and email | needs transform | Doc id is lowercase email; field also stored. |
| VISITOR_USERS | username | visitor_users | username | exact | Same semantics. |
| VISITOR_USERS | name | visitor_users | name | exact | Same semantics. |
| VISITOR_USERS | created_at | visitor_users | createdAt | needs transform | snake_case to camelCase timestamp. |

### VISITOR_USER_INTERESTED_EVENTS

| ERD Entity | ERD Field | Firestore Collection | Firestore Field/Path | Status | Notes |
|---|---|---|---|---|---|
| VISITOR_USER_INTERESTED_EVENTS | visitor_email | visitor_users | document id/email | needs transform | Junction row derived from parent user document. |
| VISITOR_USER_INTERESTED_EVENTS | event_id | visitor_users | interestedEventIds[] | needs transform | Array expansion required to rows. |
| VISITOR_USER_INTERESTED_EVENTS | created_at | visitor_users | - | missing | No per-link timestamp in current array model. |

### VISITOR_USER_SAVED_ATTRACTIONS

| ERD Entity | ERD Field | Firestore Collection | Firestore Field/Path | Status | Notes |
|---|---|---|---|---|---|
| VISITOR_USER_SAVED_ATTRACTIONS | visitor_email | visitor_users | document id/email | needs transform | Junction row derived from parent user document. |
| VISITOR_USER_SAVED_ATTRACTIONS | attraction_id | visitor_users | savedAttractionIds[] | needs transform | Array expansion required to rows. |
| VISITOR_USER_SAVED_ATTRACTIONS | created_at | visitor_users | - | missing | No per-link timestamp in current array model. |

### LOCAL_USER_INTERESTED_EVENTS

| ERD Entity | ERD Field | Firestore Collection | Firestore Field/Path | Status | Notes |
|---|---|---|---|---|---|
| LOCAL_USER_INTERESTED_EVENTS | local_email | local_users | document id/email | needs transform | Junction row derived from parent user document. |
| LOCAL_USER_INTERESTED_EVENTS | event_id | local_users | interestedEventIds[] | needs transform | Array expansion required to rows. |
| LOCAL_USER_INTERESTED_EVENTS | created_at | local_users | - | missing | No per-link timestamp in current array model. |

## 12) Summary of Alignment for Attached ERD

- Exact: Core entities and several primary business fields (events, users, reports, notifications, attractions) are present.
- Needs transform: Most mapped fields require camelCase/snake_case conversion and some key strategy adaptation (doc id vs explicit id columns).
- Missing: Affiliation domain and dedicated moderation/audit log collections are not implemented in the current Firestore model.
