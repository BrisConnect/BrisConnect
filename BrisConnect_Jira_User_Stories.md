# BrisConnect — Jira User Stories

---

## STORY-1: Admin Secure Login

**Summary:** Admin Secure Login  
**Type:** Story  
**Labels:** `Admin`  
**Status:** Done  

**Description:**  
As an Admin, I want to log in securely so that I can manage platform operations.

**Acceptance Criteria:**  
- [ ] Admin login requires valid admin credentials.
- [ ] Invalid credentials show a clear error message.
- [ ] Successful login redirects the Admin to the admin dashboard.
- [ ] Non-admin users cannot access admin-only screens.
- [ ] Protected admin routes remain inaccessible without the correct role.

**Implementation Notes:**  
Implemented: Yes  
Files:  
- `lib/screens/admin_login_screen.dart` — Login UI with email/username fields, error display, and redirect to dashboard.  
- `lib/auth/admin_auth.dart` — AdminAuth class with Firebase login, error handling, and session persistence via `restoreSession()`.  
- `lib/widgets/role_guard.dart` — RoleGuard widget enforcing `AdminUserRole` on protected routes.

---

## STORY-2: Admin Dashboard Summary Metrics

**Summary:** Admin Dashboard Summary Metrics  
**Type:** Story  
**Labels:** `Admin`  
**Status:** Done  

**Description:**  
As an Admin, I want to see dashboard summary metrics so that I can monitor platform activity at a glance.

**Acceptance Criteria:**  
- [ ] The Admin dashboard displays total event counts.
- [ ] The Admin dashboard displays pending event counts.
- [ ] The Admin dashboard displays reported event counts.
- [ ] The Admin dashboard displays user-related counts, including Local, Visitor, and Admin totals.
- [ ] The dashboard updates these summaries from service-backed data streams.

**Implementation Notes:**  
Implemented: Yes  
Files:  
- `lib/screens/admin_dashboard_screen.dart` — Dashboard UI with summary metric cards and real-time stream listeners.  
- `lib/services/admin_dashboard_service.dart` — Service providing Firestore streams for total, pending, reported event counts and user role totals.

---

## STORY-3: Admin Review Local Account Requests

**Summary:** Admin Review Local Account Requests  
**Type:** Story  
**Labels:** `Admin`  
**Status:** Done  

**Description:**  
As an Admin, I want to review Local account requests so that only approved Local users can publish events.

**Acceptance Criteria:**  
- [ ] The system displays pending Local account requests for admin review.
- [ ] The Admin can approve a Local account.
- [ ] The Admin can reject a Local account.
- [ ] Account approval status is saved and enforced in the system.
- [ ] Pending or rejected Local users are restricted from full publishing access.

**Implementation Notes:**  
Implemented: Yes  
Files:  
- `lib/screens/admin_local_account_review_screen.dart` — List of pending requests with approve/reject actions, status saved to Firestore (`approvalStatus: 'approved'|'rejected'|'pending'`).  
- `lib/services/local_email_notification_service.dart` — Queues email notifications on approval or rejection.  
- `lib/services/sms_notification_service.dart` — Queues SMS via `queueLocalAccountReviewSms()`.

---

## STORY-4: Admin Moderate Submitted Events

**Summary:** Admin Moderate Submitted Events  
**Type:** Story  
**Labels:** `Admin`  
**Status:** Done  

**Description:**  
As an Admin, I want to moderate submitted events so that only approved events are publicly visible.

**Acceptance Criteria:**  
- [ ] The system displays pending, approved, and rejected event states.
- [ ] The Admin can approve an event.
- [ ] The Admin can reject an event.
- [ ] Event moderation updates are saved immediately.
- [ ] Public event listings reflect the latest approval status.

**Implementation Notes:**  
Implemented: Yes  
Files:  
- `lib/screens/admin_event_review_screen.dart` — Event review UI with state summary chips (Pending/Approved/Rejected), approve and reject actions.  
- `lib/services/admin_event_service.dart` — Persists `reviewStatus` field to Firestore events collection.

---

## STORY-5: Admin Manage Attraction Records

**Summary:** Admin Manage Attraction Records  
**Type:** Story  
**Labels:** `Admin`  
**Status:** Done  

**Description:**  
As an Admin, I want to manage attraction records so that attraction information stays accurate and up to date.

**Acceptance Criteria:**  
- [ ] The system allows the Admin to add a new attraction.
- [ ] The system allows the Admin to edit an existing attraction.
- [ ] The system allows the Admin to delete an attraction.
- [ ] Attraction records support media-related fields, including image and audio metadata.
- [ ] The Admin can view attraction items in a management list before taking actions.

**Implementation Notes:**  
Implemented: Yes  
Files:  
- `lib/screens/admin_attraction_management_screen.dart` — CRUD management list with add/edit/delete, image upload, audio guide upload via `_uploadAudioGuide()`, opening hours, and accessibility details.  
- `lib/services/admin_attraction_service.dart` — Firestore CRUD operations for attractions collection.  
- `lib/services/firebase_media_service.dart` — Handles image and audio file uploads to Firebase Storage.

---

## STORY-6: Local User Login

**Summary:** Local User Login  
**Type:** Story  
**Labels:** `Local`  
**Status:** Done  

**Description:**  
As a Local user, I want to log in to my account so that I can access local portal features.

**Acceptance Criteria:**  
- [ ] Local login requires valid local credentials.
- [ ] Invalid credentials are rejected with feedback.
- [ ] Successful login redirects the user to the local portal.
- [ ] Local-only routes are restricted from other user roles.
- [ ] Session state is restored correctly after login.

**Implementation Notes:**  
Implemented: Yes  
Files:  
- `lib/screens/local_login_screen.dart` — Email/password login form with error messages for invalid credentials and pending approval.  
- `lib/auth/local_auth.dart` — LocalAuth class with Firebase login, session persistence via `restoreSession()`.  
- `lib/widgets/role_guard.dart` — RoleGuard enforcing `LocalUserRole`.

---

## STORY-7: Local Account Approval Notifications

**Summary:** Local Account Approval Notifications  
**Type:** Story  
**Labels:** `Local`  
**Status:** Done  

**Description:**  
As a Local user, I want to receive account approval notifications so that I know when I can access publishing features.

**Acceptance Criteria:**  
- [ ] The system displays account status notifications for pending, approved, and rejected Local accounts.
- [ ] The Local user can open a Notifications screen to view these updates.
- [ ] Notification history is shown in the app.
- [ ] The messaging clearly explains the current account status.
- [ ] Account approval messages remain visible through the notification flow.

**Implementation Notes:**  
Implemented: Yes  
Files:  
- `lib/screens/local_notifications_screen.dart` — Status card showing approval status plus notification history section.  
- `lib/models/notification_record.dart` — NotificationRecord model with timestamp, message, type, and status.  
- `lib/services/notification_repository.dart` — Persisted records stored in Firestore `notifications` collection.

---

## STORY-8: Local Submit Event with Media

**Summary:** Local Submit Event with Media  
**Type:** Story  
**Labels:** `Local`  
**Status:** Done  

**Description:**  
As a Local user, I want to submit an event with media so that my community event can be reviewed for publication.

**Acceptance Criteria:**  
- [ ] The system provides an event submission form with required fields.
- [ ] The Local user can upload an event image during submission.
- [ ] Submitted events are stored with a review status.
- [ ] Unapproved events are not shown in the public visitor feed.
- [ ] The submission process completes without breaking when optional fields are empty.

**Implementation Notes:**  
Implemented: Yes  
Files:  
- `lib/screens/add_event_screen.dart` — Submission form with title, date, time, location, description fields. Image upload to Firebase Storage. Owner association via `LocalAuth.currentLocal.email`. Events saved with `reviewStatus: 'pending'`.  
- `lib/services/firebase_media_service.dart` — Image upload and download URL generation.

---

## STORY-9: Local Edit Own Submitted Events

**Summary:** Local Edit Own Submitted Events  
**Type:** Story  
**Labels:** `Local`  
**Status:** Done  

**Description:**  
As a Local user, I want to edit my own submitted events so that I can correct or update event information after submission.

**Acceptance Criteria:**  
- [ ] The system provides an Edit Event screen for Local users.
- [ ] A Local user can only edit events created by their own account.
- [ ] The user can update event details and replace the event image.
- [ ] Updated event information is saved successfully.
- [ ] The system prevents unauthenticated users from editing events.

**Implementation Notes:**  
Implemented: Yes  
Files:  
- `lib/screens/local_edit_event_screen.dart` — Edit form pre-filled with existing event data, owner verification restricting edits to original submitter.  
- `lib/services/local_event_service.dart` — Firestore update with ownership check.

---

## STORY-10: Local Event Review Notifications

**Summary:** Local Event Review Notifications  
**Type:** Story  
**Labels:** `Local`  
**Status:** Done  

**Description:**  
As a Local user, I want to receive event review notifications so that I know whether my submitted event was approved.

**Acceptance Criteria:**  
- [ ] The system displays event review notifications for pending, approved, and rejected submitted events.
- [ ] The Local user can view these updates in the Notifications screen.
- [ ] Notification history includes event review status entries.
- [ ] The review message clearly explains the current event status.
- [ ] The notification flow works alongside account approval notifications.

**Implementation Notes:**  
Implemented: Yes  
Files:  
- `lib/screens/local_notifications_screen.dart` — Notification history displaying event review status alongside account approval.  
- `lib/models/notification_record.dart` — NotificationRecord stores event review details.  
- `lib/services/local_email_notification_service.dart` — Email queued on event review completion.

---

## STORY-11: Local Manage Profile

**Summary:** Local Manage Profile  
**Type:** Story  
**Labels:** `Local`  
**Status:** Done  

**Description:**  
As a Local user, I want to manage my profile details so that my organizer information stays up to date.

**Acceptance Criteria:**  
- [ ] The Local user can update persisted profile information.
- [ ] Profile image upload or update is supported.
- [ ] Updated details are restored when the session is reloaded.
- [ ] Failed profile media actions are handled safely.
- [ ] Profile data remains available across normal app usage.

**Implementation Notes:**  
Implemented: Yes  
Files:  
- `lib/screens/local_portal_screen.dart` — Profile management UI with name, phone, email fields.  
- `lib/auth/local_auth.dart` — `updateProfile()` and `updateProfileImage()` persist to Firestore `local_users` collection. Image cached with Base64 and storage URLs. `profileVersion` notifier triggers UI rebuild.  
- `lib/screens/profile_camera_capture_screen.dart` — Camera/gallery image capture with permission handling.

---

## STORY-12: Visitor Login

**Summary:** Visitor Login  
**Type:** Story  
**Labels:** `Visitor`  
**Status:** Done  

**Description:**  
As a Visitor, I want to log in to my account so that I can access discovery and planning features.

**Acceptance Criteria:**  
- [ ] Visitor login requires valid visitor credentials.
- [ ] Invalid credentials are rejected with feedback.
- [ ] Successful login redirects the user to the visitor portal.
- [ ] Visitor-only routes are restricted from other user roles.
- [ ] Session state is restored correctly after login.

**Implementation Notes:**  
Implemented: Yes  
Files:  
- `lib/screens/visitor_login_screen.dart` — Email/password login with error messages.  
- `lib/auth/visitor_auth.dart` — VisitorAuth class with Firebase login and session persistence via `restoreSession()`.  
- `lib/widgets/role_guard.dart` — RoleGuard enforcing `VisitorUserRole`.

---

## STORY-13: Visitor Browse Approved Events Only

**Summary:** Visitor Browse Approved Events Only  
**Type:** Story  
**Labels:** `Visitor`  
**Status:** Done  

**Description:**  
As a Visitor, I want to browse only approved events so that I see trusted and moderated content.

**Acceptance Criteria:**  
- [ ] The system shows only approved events in visitor-facing event listings.
- [ ] Pending and rejected events are excluded.
- [ ] Event cards display normalized title, date, time, and location information.
- [ ] Malformed or incomplete event records do not crash the listing.
- [ ] Event data is presented consistently across discovery screens.

**Implementation Notes:**  
Implemented: Yes  
Files:  
- `lib/screens/visitor_portal_screen.dart` — Visitor portal with real-time stream of approved events via `_approvedEventsStream()`.  
- `lib/services/discover_data_service.dart` — Firestore query `where('reviewStatus', '==', 'approved')` filtering pending and rejected events.

---

## STORY-14: Visitor View Detailed Event Pages

**Summary:** Visitor View Detailed Event Pages  
**Type:** Story  
**Labels:** `Visitor`  
**Status:** Done  

**Description:**  
As a Visitor, I want to view detailed event pages so that I can decide whether to attend.

**Acceptance Criteria:**  
- [ ] The system displays title, date, time, location, and description on the event detail page.
- [ ] Optional rich content is shown when available.
- [ ] Missing optional data does not break the page layout.
- [ ] The user can navigate to and from the detail page correctly.
- [ ] Event detail content is consistent with the selected event.

**Implementation Notes:**  
Implemented: Yes  
Files:  
- `lib/screens/visitor_event_detail_screen.dart` — Full event detail with title, date, time, location, description, hero image, share, map, and save actions.  
- `lib/screens/event_detail_screen.dart` — Shared event detail layout with optional audio guide via `AudioGuideWidget` and web link support.

---

## STORY-15: Visitor Report Problematic Events

**Summary:** Visitor Report Problematic Events  
**Type:** Story  
**Labels:** `Visitor`  
**Status:** Done  

**Description:**  
As a Visitor, I want to report problematic events so that unsafe or inaccurate content can be reviewed.

**Acceptance Criteria:**  
- [ ] The system provides a report dialog with selectable reasons.
- [ ] The Visitor can submit additional report details.
- [ ] The same Visitor cannot submit duplicate reports for the same event.
- [ ] Reports are stored for admin review.
- [ ] Reported events appear in the admin reporting workflow.

**Implementation Notes:**  
Implemented: Yes  
Files:  
- `lib/widgets/report_event_dialog.dart` — Report dialog with reason dropdown (`ReportEventService.reportReasons`) and optional comments field.  
- `lib/services/report_event_service.dart` — `submitReport()` with duplicate check, stores in Firestore `event_reports` collection, tracks report count for admin dashboard.

---

## STORY-16: Visitor Save Events and Calendar View

**Summary:** Visitor Save Events and Calendar View  
**Type:** Story  
**Labels:** `Visitor`  
**Status:** Done  

**Description:**  
As a Visitor, I want to save events and view them in a calendar so that I can plan my schedule.

**Acceptance Criteria:**  
- [ ] Saved or interested events appear in the calendar feature.
- [ ] The calendar supports day view.
- [ ] The calendar supports week view.
- [ ] The calendar supports month view.
- [ ] Common event date and time formats are parsed correctly.

**Implementation Notes:**  
Implemented: Yes  
Files:  
- `lib/screens/visitor_saved_events_calendar_screen.dart` — Calendar with day, week, and month views displaying saved events.  
- `lib/auth/visitor_auth.dart` — `toggleInterestedEvent(id)` and `getInterestedEventIds()` persist to Firestore `interestedEventIds` array.

---

## STORY-17: Visitor View Attraction Details

**Summary:** Visitor View Attraction Details  
**Type:** Story  
**Labels:** `Visitor`  
**Status:** Done  

**Description:**  
As a Visitor, I want to view detailed attraction information so that I can learn about a place before visiting.

**Acceptance Criteria:**  
- [ ] The system displays attraction details on a dedicated attraction detail screen.
- [ ] The detail screen shows attraction information such as opening hours when available.
- [ ] The detail screen shows facilities and accessibility information when available.
- [ ] The screen handles missing attraction details without breaking the layout.
- [ ] The user can open the attraction detail screen from attraction discovery flows.

**Implementation Notes:**  
Implemented: Yes  
Files:  
- `lib/screens/attraction_detail_screen.dart` — Detail screen with name, category, description, opening hours, address, contact, history, facilities, accessibility, Google Maps integration, and audio guide.  
- `lib/services/attraction_detail_service.dart` — Fetches attraction data from Firestore.

---

## STORY-18: Visitor Accessibility Info for Attractions

**Summary:** Visitor Accessibility Info for Attractions  
**Type:** Story  
**Labels:** `Visitor`  
**Status:** Done  

**Description:**  
As a Visitor, I want to access attraction accessibility information so that I can decide whether a venue meets my needs.

**Acceptance Criteria:**  
- [ ] The system displays an Accessibility section for attractions.
- [ ] Accessibility details are shown as a list when provided by the Admin.
- [ ] A fallback message is shown when accessibility details are not yet available.
- [ ] Accessibility information is visible from the attraction detail page.
- [ ] The layout presents accessibility content clearly and consistently.

**Implementation Notes:**  
Implemented: Yes  
Files:  
- `lib/screens/attraction_detail_screen.dart` — "Facilities & Accessibility" section listing accessibility features; fallback: "Accessibility details not provided by admin yet."  
- `lib/services/approved_attraction_service.dart` — `accessibilityDetails` field in attraction data.  
- `lib/services/admin_attraction_service.dart` — Admin can manage accessibility details list.

---

## STORY-19: Visitor Manage Profile

**Summary:** Visitor Manage Profile  
**Type:** Story  
**Labels:** `Visitor`  
**Status:** Done  

**Description:**  
As a Visitor, I want to manage my profile details so that my personal information stays up to date.

**Acceptance Criteria:**  
- [ ] The Visitor can update profile fields such as name and phone number.
- [ ] Profile changes are saved successfully.
- [ ] Updated details are restored when the session is reloaded.
- [ ] Profile image handling is supported.
- [ ] Invalid profile updates are handled safely.

**Implementation Notes:**  
Implemented: Yes  
Files:  
- `lib/screens/visitor_settings_screen.dart` — Profile fields (name, phone, email) with image upload/update.  
- `lib/auth/visitor_auth.dart` — Persists to Firestore and SharedPreferences with session restoration across restarts.

---

## STORY-20: Event Audio Guides

**Summary:** Event Audio Guides  
**Type:** Story  
**Labels:** `Shared`  
**Status:** Done  

**Description:**  
As a User, I want to listen to event audio guides when available so that I can have a richer guided experience.

**Acceptance Criteria:**  
- [ ] The system displays an Audio Guide section when an event audio URL is available.
- [ ] Users can access audio guide playback from supported event detail screens.
- [ ] The UI safely handles event detail pages when no audio is available.
- [ ] Audio playback is available only when valid audio content exists.
- [ ] Event detail content remains usable regardless of audio availability.

**Implementation Notes:**  
Implemented: Yes  
Files:  
- `lib/widgets/audio_guide_widget.dart` — Reusable audio guide widget with playback controls and AI narration fallback.  
- `lib/screens/event_detail_screen.dart` — Integrates AudioGuideWidget with event title, description, date, location.  
- `lib/screens/visitor_event_detail_screen.dart` — Visitor event detail with audio guide.  
- `lib/screens/local_event_detail_screen.dart` — Local event detail with audio guide.

---

## STORY-21: Attraction Audio Guides

**Summary:** Attraction Audio Guides  
**Type:** Story  
**Labels:** `Shared`  
**Status:** Done  

**Description:**  
As a User, I want to listen to attraction audio guides so that I can have a richer guided experience.

**Acceptance Criteria:**  
- [ ] The system displays an Audio Guide section when an attraction audio URL is available.
- [ ] Users can access audio guide playback from the attraction detail screen.
- [ ] The UI safely handles attraction pages when no audio is available.
- [ ] Audio playback is available only when valid audio content exists.
- [ ] Attraction detail content remains usable regardless of audio availability.

**Implementation Notes:**  
Implemented: Yes  
Files:  
- `lib/widgets/audio_guide_widget.dart` — Shared audio guide widget.  
- `lib/screens/attraction_detail_screen.dart` — Audio guide section on attraction detail.  
- `lib/screens/admin_attraction_management_screen.dart` — Admin uploads audio guide to Firebase Storage path `attraction-media/{attractionId}/audio-guide.{ext}`.

---

## STORY-22: View Notification History

**Summary:** View Notification History  
**Type:** Story  
**Labels:** `Shared`  
**Status:** Done  

**Description:**  
As a User, I want to view notification history so that I can track alerts and reminders I have received.

**Acceptance Criteria:**  
- [ ] The system provides a notification screen for supported roles.
- [ ] Stored notification records are displayed in the app.
- [ ] The interface shows a clear empty state when no notifications exist.
- [ ] Notification entries include useful event or schedule context where available.
- [ ] Notification history loads consistently from persistent storage.

**Implementation Notes:**  
Implemented: Yes  
Files:  
- `lib/screens/local_notifications_screen.dart` — "Notification History" section for Local users.  
- `lib/screens/visitor_notifications_screen.dart` — Notification history for Visitor users.  
- `lib/models/notification_record.dart` — NotificationRecord model with timestamp, message, type, status.  
- `lib/services/notification_repository.dart` — Persisted records in Firestore `notifications` collection, sorted newest first.

---

## STORY-23: Manage Notification Settings

**Summary:** Manage Notification Settings  
**Type:** Story  
**Labels:** `Shared`  
**Status:** Done  

**Description:**  
As a User, I want to manage notification settings so that alerts match my preferences.

**Acceptance Criteria:**  
- [ ] The system allows users to update notification preferences.
- [ ] Preference changes are saved for future sessions.
- [ ] Settings behavior is consistent across supported roles.
- [ ] Removed options are no longer displayed in the settings UI.
- [ ] Updated settings are applied without causing errors in the screen.

**Implementation Notes:**  
Implemented: Yes  
Files:  
- `lib/screens/notification_settings_screen.dart` — Toggle notifications enabled/disabled, event reminders, reminder timing (e.g. 24h), event updates, nearby events, recommended events.  
- `lib/auth/local_auth.dart` — `setNotificationSettings()` for Local role.  
- `lib/auth/visitor_auth.dart` — `setNotificationSettings()` for Visitor role. Persisted to Firestore and SharedPreferences.

---

## STORY-24: Approved Attractions Map

**Summary:** Approved Attractions Map  
**Type:** Story  
**Labels:** `Shared`  
**Status:** Done  

**Description:**  
As a User, I want to view approved attractions on a dedicated map so that I can discover places spatially.

**Acceptance Criteria:**  
- [ ] The system provides a dedicated approved attractions map screen.
- [ ] Only approved attractions are shown on the map.
- [ ] The user can filter the displayed attractions.
- [ ] The user can tap a marker to view more details.
- [ ] The screen shows feedback about how many approved attractions are currently displayed.

**Implementation Notes:**  
Implemented: Yes  
Files:  
- `lib/screens/approved_attractions_map_screen.dart` — Google Maps with markers for approved attractions only, category filter chips, tap-to-detail, user location support.  
- `lib/services/approved_attraction_service.dart` — Fetches approved attractions from Firestore.

---

## STORY-25: Events and Attractions on Map

**Summary:** Events and Attractions on Map  
**Type:** Story  
**Labels:** `Shared`  
**Status:** Done  

**Description:**  
As a User, I want to explore events and attractions on a map so that I can find places geographically.

**Acceptance Criteria:**  
- [ ] The system displays a map with event and attraction markers.
- [ ] Markers are grouped or styled by category.
- [ ] The user can search for map results using relevant text.
- [ ] The user can filter map results by category.
- [ ] The map focuses results within the Brisbane area.

**Implementation Notes:**  
Implemented: Yes  
Files:  
- `lib/screens/map_explorer_screen.dart` — Unified map showing 6+ location types (events, attractions, stadiums, Olympic venues, cultural, food) with search, type filtering, and results sheet.  
- `lib/screens/map_events_screen.dart` — Map-focused event/attraction view with search debouncing and category filtering.  
- `lib/models/map_location.dart` — Shared location model for map markers.

---

## STORY-26: Live GPS Tracking on Map

**Summary:** Live GPS Tracking on Map  
**Type:** Story  
**Labels:** `Shared`  
**Status:** Done  

**Description:**  
As a User, I want live GPS tracking on the map so that I can orient myself while exploring.

**Acceptance Criteria:**  
- [ ] The system requests location permission before enabling tracking.
- [ ] The user's current position is shown on the map when permission is granted.
- [ ] The location marker updates as the user moves.
- [ ] The user can recenter or follow their current location.
- [ ] The map continues functioning even if location permission is denied.

**Implementation Notes:**  
Implemented: Yes  
Files:  
- `lib/screens/map_explorer_screen.dart` — GPS tracking with "Following GPS" toggle, recenter button, real-time position updates via geolocator.  
- `lib/screens/map_events_screen.dart` — GPS tracking with animation.  
- `lib/services/location_utilities.dart` — Location permission handling, services check, emulator-safe Brisbane centre fallback.

---

## STORY-27: Welcome Screen

**Summary:** Welcome Screen  
**Type:** Story  
**Labels:** `Shared`  
**Status:** Done  

**Description:**  
As a User, I want to see a welcome screen so that I can choose to log in or create an account.

**Acceptance Criteria:**  
- [ ] The system displays a branded welcome screen with the app logo on first launch.
- [ ] The welcome screen shows a "Log In" button and a "Create Account" button.
- [ ] Tapping "Log In" navigates to the Login Role Selection screen.
- [ ] Tapping "Create Account" navigates to the Register Role Selection screen.
- [ ] The screen displays branding elements consistent with the app theme.

**Implementation Notes:**  
Implemented: Yes  
Files:  
- `lib/screens/welcome_screen.dart` — Centred card with logo, decorative gradient circles, 3 theme chips (Events, Culture, Community), "Log In" → `LoginSelectionScreen`, "Create Account" → `RegisterSelectionScreen`. Brand palette: ochre, gold, deepBlue, charcoal.

---

## STORY-28: Login Role Selection

**Summary:** Login Role Selection  
**Type:** Story  
**Labels:** `Shared`  
**Status:** Done  

**Description:**  
As a User, I want to select my role before logging in so that I am directed to the correct login screen.

**Acceptance Criteria:**  
- [ ] The system displays three login options: Visitor, Local, and Admin.
- [ ] Each option shows a descriptive subtitle explaining the role.
- [ ] Tapping an option navigates to the corresponding role-specific login screen.
- [ ] The layout is responsive and centred on different screen sizes.

**Implementation Notes:**  
Implemented: Yes  
Files:  
- `lib/screens/login_selection_screen.dart` — Three `_LoginOptionCard` widgets: Visitor → `VisitorLoginScreen`, Local → `LocalLoginScreen`, Admin → `AdminLoginScreen`. Max width 460, centred column. Icons with brand colours (ochre, deepBlue, gold).

---

## STORY-29: Registration Role Selection

**Summary:** Registration Role Selection  
**Type:** Story  
**Labels:** `Shared`  
**Status:** Done  

**Description:**  
As a User, I want to select my role before registering so that I create the correct type of account.

**Acceptance Criteria:**  
- [ ] The system displays two registration options: Visitor and Local.
- [ ] Admin registration is not available through the registration screen.
- [ ] Each option shows a descriptive subtitle explaining the role.
- [ ] Tapping an option navigates to the corresponding role-specific registration screen.

**Implementation Notes:**  
Implemented: Yes  
Files:  
- `lib/screens/register_selection_screen.dart` — Two `_RegisterOptionCard` widgets: Visitor → `VisitorSignUpScreen`, Local → `LocalSignUpScreen`. No Admin registration option. Max width 460, centred column.

---

## STORY-30: Interest Categories Selection

**Summary:** Interest Categories Selection  
**Type:** Story  
**Labels:** `Shared`  
**Status:** Done  

**Description:**  
As a User, I want to select my interest categories so that I can receive personalised event recommendations.

**Acceptance Criteria:**  
- [ ] The system displays eight interest categories: Cultural, Music and Entertainment, Sports, Food and Dining, Nature and Outdoors, Historical and Attractions, Markets and Shopping, and Workshops and Community.
- [ ] The user can select multiple categories.
- [ ] Selected categories are saved and persisted across sessions.
- [ ] The feature works for both Local and Visitor users.
- [ ] A confirmation message is shown when categories are saved successfully.

**Implementation Notes:**  
Implemented: Yes  
Files:  
- `lib/screens/interest_categories_screen.dart` — 8 `FilterChip` widgets with icons and labels. Multi-select (0–8). Save calls `VisitorAuth.setInterestCategories()` or `LocalAuth.setInterestCategories()` depending on role. Categories persisted alphabetically sorted. Success snackbar: "Interest categories saved".

---

## STORY-31: Location Radius Settings

**Summary:** Location Radius Settings  
**Type:** Story  
**Labels:** `Shared`  
**Status:** Done  

**Description:**  
As a User, I want to configure location settings so that nearby recommendations match my preferred search radius.

**Acceptance Criteria:**  
- [ ] The system provides a toggle to enable or disable current location usage.
- [ ] The system provides radius options of 5, 10, 20, 50, and 100 kilometres.
- [ ] Settings are persisted across sessions for the logged-in user.
- [ ] The feature works for both Local and Visitor users.
- [ ] A message is shown if the user is not logged in.

**Implementation Notes:**  
Implemented: Yes  
Files:  
- `lib/screens/location_settings_screen.dart` — Toggle for `useCurrentLocation` with subtitle about nearby recommendations. Radius selector with 5 options (5, 10, 20, 50, 100 km). Persists via `LocalAuth.setLocationSettings()` or `VisitorAuth.setLocationSettings()`. Logged-out state: "Log in to configure location preferences".

---

## STORY-32: App Theme and Text Size

**Summary:** App Theme and Text Size  
**Type:** Story  
**Labels:** `Shared`  
**Status:** Done  

**Description:**  
As a User, I want to customise the app theme and text size so that the interface matches my visual preferences.

**Acceptance Criteria:**  
- [ ] The system provides theme options: System, Light, and Dark.
- [ ] The system provides a text scale slider ranging from 0.9 to 1.3.
- [ ] Theme changes are applied immediately across the app.
- [ ] Settings are persisted across sessions.
- [ ] The feature works for both Local and Visitor users.

**Implementation Notes:**  
Implemented: Yes  
Files:  
- `lib/screens/local_settings_screen.dart` — Theme selector (System/Light/Dark radio buttons), text scale slider (0.9–1.3), location permission toggle. Saves via `LocalAuth.setGeneralAppSettings()`.  
- `lib/screens/visitor_settings_screen.dart` — Same theme and text settings for Visitor role.  
- `lib/services/app_display_settings_controller.dart` — Singleton `ValueNotifier<AppDisplaySettings>` with `apply()` and `applyFromPersisted()`. Serialises: `themeFromString()`, `themeToString()`, `toThemeMode()`, `normalizeTextScale()`.

---

## STORY-33: Brisbane Stories Discovery

**Summary:** Brisbane Stories Discovery  
**Type:** Story  
**Labels:** `Shared`  
**Status:** Done  

**Description:**  
As a User, I want to browse Brisbane Stories so that I can discover cultural and historical narratives about Brisbane.

**Acceptance Criteria:**  
- [ ] The system displays approved Brisbane Stories from the content collection.
- [ ] Stories are organised into five categories: First Nations, Arts, Landmarks, Food, and Festivals.
- [ ] Each story shows a title, description, image, and category badge.
- [ ] The user can filter stories by category.
- [ ] Audio guide narration is available for each story.
- [ ] The user can share story content.
- [ ] Stories are sorted by publication date with newest first.

**Implementation Notes:**  
Implemented: Yes  
Files:  
- `lib/screens/brisbane_stories_screen.dart` — Hero banner with auto-scrolling `PageView` (pulse animation), 5 category buttons with gradient colours, suggested topics list, `AudioGuideWidget` integration, share capability. Loads `brisbane_stories` and `brisbane_voices` collections where `approvalStatus == 'approved'`. Sorted by `publishedAt` descending.  
- `lib/services/brisbane_stories_service.dart` — Firestore queries for stories and voice testimonials.

---

## STORY-34: Food Place Details

**Summary:** Food Place Details  
**Type:** Story  
**Labels:** `Shared`  
**Status:** Done  

**Description:**  
As a User, I want to view food place details so that I can discover dining options in Brisbane.

**Acceptance Criteria:**  
- [ ] The system displays food place details including title, description, location, and cuisine type.
- [ ] The detail screen shows ratings, price, and category information when available.
- [ ] The user can open the food place location in Google Maps.
- [ ] The user can share food place details.
- [ ] An audio narration is generated or provided for the food place.
- [ ] A placeholder image is shown when no image is available.

**Implementation Notes:**  
Implemented: Yes  
Files:  
- `lib/screens/food_detail_screen.dart` — Cached network image (height 230), share button exporting title + cuisine + location + description + webLink, "Open Map" button generating Google Maps query, rating as X.X/5, categories as horizontal chip list, badge display. Auto-generated narration combining title/badge/cuisine/location/dateTime/description/price/rating/categories or uses `aiAudio` verbatim. Fallback Unsplash placeholder.  
- `lib/models/food_place.dart` — Model with title, description, location, cuisine, imageUrl, categories, rating, badge, dateTime, price, mapQuery, webLink, aiAudio.

---

## STORY-35: Stadium and Venue Details

**Summary:** Stadium and Venue Details  
**Type:** Story  
**Labels:** `Shared`  
**Status:** Done  

**Description:**  
As a User, I want to view stadium and venue details so that I can learn about event venues before visiting.

**Acceptance Criteria:**  
- [ ] The system displays venue details including title, description, and location.
- [ ] The detail screen shows event dates, pricing, and category information when available.
- [ ] The location defaults to a placeholder label when not provided.
- [ ] Missing optional fields do not break the page layout.

**Implementation Notes:**  
Implemented: Yes  
Files:  
- `lib/screens/stadium_detail_screen.dart` — Title in AppBar, badge (deep blue), description, location (defaults "TBA"), conditional date/time and price lines, categories as chip wrap.  
- `lib/models/stadium_venue.dart` — Model with title, description, location, imageUrl, categories, badge, dateTime, price, mapQuery, webLink, aiAudio.

---

## STORY-36: Submit App Feedback

**Summary:** Submit App Feedback  
**Type:** Story  
**Labels:** `Shared`  
**Status:** Done  

**Description:**  
As a User, I want to submit app feedback so that I can report bugs or suggest improvements.

**Acceptance Criteria:**  
- [ ] The system provides a feedback form with subject and details fields.
- [ ] The form includes a category selection with options: Bug, Misleading Info, Usability, Performance, and Other.
- [ ] The form includes a severity selection with options: Low, Medium, High, and Critical.
- [ ] The subject field requires a minimum of five characters.
- [ ] Submitted feedback is stored with a pending triage status and a timestamp.
- [ ] The reporter's name, email, and role are captured automatically.

**Implementation Notes:**  
Implemented: Yes  
Files:  
- `lib/screens/feedback_form_screen.dart` — Form with `subject` (min 5 chars), `details` (required), `category` dropdown (bug, misleading_info, usability, performance, other), `severity` dropdown (low, medium, high, critical), optional `screenContext`, `appVersion` default "1.0.0". Auto-populates reporterRole, reporterName, reporterEmail. Stores with `status: 'pending_triage'`, `createdAt`, `updatedAt`, `resolutionDueAt` (now + 14 days).  
- `lib/services/app_feedback_service.dart` — Firestore `app_feedback` collection CRUD.

---

## STORY-37: Admin Manage All User Accounts

**Summary:** Admin Manage All User Accounts  
**Type:** Story  
**Labels:** `Admin`  
**Status:** Done  

**Description:**  
As an Admin, I want to manage all user accounts so that I can oversee platform membership across all roles.

**Acceptance Criteria:**  
- [ ] The system displays a unified list of all users across Visitor, Local, and Admin roles.
- [ ] The Admin can search users by email or name.
- [ ] The Admin can filter users by role: All, Visitor, Local, or Admin.
- [ ] The Admin can filter users by status: All, Active, Inactive, Pending, Approved, or Rejected.
- [ ] The Admin can deactivate a user account after confirmation.
- [ ] The Admin can reactivate a previously deactivated account.
- [ ] The Admin can approve or reject Local user accounts from this screen.
- [ ] Email and SMS notifications are sent on approval or rejection actions.

**Implementation Notes:**  
Implemented: Yes  
Files:  
- `lib/screens/admin_user_management_screen.dart` — Unified user list from 3 collections (visitor_users, local_users, admins), combined and sorted by name. Search by email/name (case-insensitive). Role and status filter chips. User info cards with action buttons. Deactivate shows confirmation dialog, sets `active: false` with `deactivatedAt` timestamp via transaction. Reactivate sets `active: true`. Approve/reject local queues email + SMS (best-effort).  
- `lib/services/admin_user_management_service.dart` — Firestore operations for user CRUD across all role collections.

---

## STORY-38: Admin Review Reported Events

**Summary:** Admin Review Reported Events  
**Type:** Story  
**Labels:** `Admin`  
**Status:** Done  

**Description:**  
As an Admin, I want to review reported events so that I can take action on user complaints about inappropriate content.

**Acceptance Criteria:**  
- [ ] The system displays reported events in a dedicated review screen.
- [ ] Reports can be filtered by status: Pending, Reviewing, Resolved, or Dismissed.
- [ ] Each report shows the reporter details, reason, and associated event information.
- [ ] The Admin can update the status of a report.
- [ ] An empty state message is shown when no reports match the selected status.
- [ ] This screen is separate from the event moderation workflow.

**Implementation Notes:**  
Implemented: Yes  
Files:  
- `lib/screens/admin_reported_events_screen.dart` — Dedicated report review screen (separate from event moderation). Filter chips for 4 statuses (pending, reviewing, resolved, dismissed). Stream-based filtering via `watchReportsByStatus(status)`. ReportCard widgets with status update capability. Empty state: "No pending reports".  
- `lib/services/report_event_service.dart` — `updateStatus()` for report lifecycle management.

---

## STORY-39: Admin Review App Feedback

**Summary:** Admin Review App Feedback  
**Type:** Story  
**Labels:** `Admin`  
**Status:** Done  

**Description:**  
As an Admin, I want to review app feedback submissions so that I can track and resolve user-reported issues.

**Acceptance Criteria:**  
- [ ] The system displays submitted feedback items with dual filtering by status and severity.
- [ ] Status filter options include: Pending Triage, In Progress, Resolved, and Will Not Fix.
- [ ] Severity filter options include: All, Critical, High, Medium, and Low.
- [ ] The Admin can update the status of a feedback item.
- [ ] Feedback items are sorted by newest first.
- [ ] A resolution due date is calculated automatically on submission.

**Implementation Notes:**  
Implemented: Yes  
Files:  
- `lib/screens/admin_feedback_review_screen.dart` — Dual filter: status FilterChips (pending_triage, in_progress, resolved, wont_fix) + severity filter (all, critical, high, medium, low). Status chips stream from Firestore `app_feedback` collection. Severity filtering applied client-side. Admin updates status via `updateFeedbackStatus(status, consideredForFix)`. `maintenanceWindowDays` default 14 days. Sorted by newest.  
- `lib/services/app_feedback_service.dart` — Firestore stream and status update operations.

---

## STORY-40: Admin SMS Broadcast

**Summary:** Admin SMS Broadcast  
**Type:** Story  
**Labels:** `Admin`  
**Status:** Done  

**Description:**  
As an Admin, I want to send SMS broadcasts so that I can communicate important announcements to platform users.

**Acceptance Criteria:**  
- [ ] The system provides a compose form with a message field and audience selection.
- [ ] Audience options include: Locals and Visitors, Locals Only, and Visitors Only.
- [ ] The Admin can restrict the broadcast to approved Local users only.
- [ ] The system queues SMS messages and reports the number of recipients.
- [ ] A confirmation message shows the number of recipients or indicates if no recipients were found.
- [ ] The message field is required and validated before sending.

**Implementation Notes:**  
Implemented: Yes  
Files:  
- `lib/screens/admin_sms_broadcast_screen.dart` — Compose form with message textarea and audience dropdown (both, locals, visitors). "Approved locals only" toggle (default true, disabled when audience is visitors only). Validates message not empty. Calls `smsService.queueAdminBroadcastSms(audience, message, approvedLocalsOnly)`. Snackbar shows "Queued SMS for X recipient(s)" or "No recipients found".  
- `lib/services/sms_notification_service.dart` — SMS queuing service.

---

## STORY-41: Admin Direct Event Editing

**Summary:** Admin Direct Event Editing  
**Type:** Story  
**Labels:** `Admin`  
**Status:** Done  

**Description:**  
As an Admin, I want to edit event details directly so that I can correct event information beyond approving or rejecting.

**Acceptance Criteria:**  
- [ ] The system provides an edit form pre-filled with the existing event data.
- [ ] The Admin can update the title, location, description, date, and category.
- [ ] The category selection includes: Culture, Music, Food, Sports, Community, Education, Family, and General.
- [ ] The Admin can replace or remove the event image.
- [ ] Updated event information is saved to the system.
- [ ] The date picker supports date selection within a range of one year in the past to three years in the future.

**Implementation Notes:**  
Implemented: Yes  
Files:  
- `lib/screens/admin_edit_event_screen.dart` — Pre-filled edit form with title (required), location (required), description (required), date picker (DD/MM/YYYY or "D Month YYYY", range: −1 to +3 years), category dropdown (8 options: Culture, Music, Food, Sports, Community, Education, Family, General). Image picker via `ImagePicker` (quality 82, max 1440×1440). Can clear existing image via checkbox. Upload via `firebaseMediaService.uploadEventImage()`. Saves via `AdminEventService.updateEvent()`.  
- `lib/services/admin_event_service.dart` — Firestore event update operations.

---

## STORY-42: Local User Registration

**Summary:** Local User Registration  
**Type:** Story  
**Labels:** `Local`  
**Status:** Done  

**Description:**  
As a Local user, I want to register for an account so that I can apply for publishing access on the platform.

**Acceptance Criteria:**  
- [ ] The system provides a registration form with fields for business name, email, password, phone number, and suburb.
- [ ] Phone numbers are converted to Australian E.164 format.
- [ ] Email validation is enforced.
- [ ] Successful registration redirects to the Local login screen with email pre-filled.
- [ ] An error message is shown if registration fails.
- [ ] The form indicates that registration is for a Local account without admin access.
- [ ] The submit button is disabled while the form is being processed.

**Implementation Notes:**  
Implemented: Yes  
Files:  
- `lib/screens/local_signup_screen.dart` — Registration form with `businessName` (required), `suburb` (optional), `email` (required, email format), `password` (required, obscurable), `phone` (required). Phone conversion: strips non-digits, removes leading 61/0, prepends +61 (e.g. "0412 345 678" → "+61412345678"). Calls `LocalAuth.register(name, email, password, phone, suburb)`. On success → `LocalLoginScreen` with email pre-filled. Error snackbar from `LocalAuth.lastErrorMessage`. Info banner: "Registering as a Local (no admin access)". Submit disabled during processing.  
- `lib/auth/local_auth.dart` — Firebase registration and Firestore user record creation.

---

## STORY-43: Visitor Registration

**Summary:** Visitor Registration  
**Type:** Story  
**Labels:** `Visitor`  
**Status:** Done  

**Description:**  
As a Visitor, I want to register for an account so that I can access discovery and planning features.

**Acceptance Criteria:**  
- [ ] The system provides a registration form with fields for name, email, password, and phone number.
- [ ] Phone numbers are converted to Australian E.164 format.
- [ ] Email validation is enforced.
- [ ] Successful registration redirects to the Visitor login screen with email pre-filled.
- [ ] An error message is shown if registration fails.
- [ ] The submit button is disabled while the form is being processed.

**Implementation Notes:**  
Implemented: Yes  
Files:  
- `lib/screens/visitor_signup_screen.dart` — Registration form with `name` (required), `email` (required, email format), `password` (required, obscurable), `phone` (required, +61 E.164 conversion). Calls `VisitorAuth.register(name, email, password, phone)`. On success → `VisitorLoginScreen` with email pre-filled. Error snackbar from `VisitorAuth.lastErrorMessage`. Submit disabled during processing.  
- `lib/auth/visitor_auth.dart` — Firebase registration and Firestore user record creation.

---

## STORY-44: Visitor Interested Events List

**Summary:** Visitor Interested Events List  
**Type:** Story  
**Labels:** `Visitor`  
**Status:** Done  

**Description:**  
As a Visitor, I want to view a list of my interested events so that I can review all the events I have saved.

**Acceptance Criteria:**  
- [ ] The system displays a list of events the Visitor has marked as interested.
- [ ] Only approved events are shown in the list.
- [ ] The Visitor can remove an event from the interested list.
- [ ] A confirmation message is shown when an event is removed.
- [ ] An empty state message is shown when no events are saved.
- [ ] A loading indicator is displayed while events are being fetched.

**Implementation Notes:**  
Implemented: Yes  
Files:  
- `lib/screens/visitor_interested_events_screen.dart` — Streams approved discover items via `discoverDataService.watchApprovedDiscoverItems()`, filters `section == 'events'` AND eventId in `VisitorAuth.getInterestedEventIds()`. "Remove from Interested" button calls `VisitorAuth.toggleInterestedEvent(eventId)` with snackbar. Not logged in: snackbar "Please log in as Visitor". Loading hint appears after 2 seconds. Centred empty message when no interested events.  
- `lib/services/discover_data_service.dart` — Firestore stream of approved discover items.

---

## STORY-45: Receive Real-Time User Notifications

**Summary:** Receive Real-Time User Notifications  
**Type:** Story  
**Labels:** `Shared`  
**Priority:** High  
**Story Points:** 8  
**Status:** Done  

**Description:**  
As a User, I want to receive real-time notifications so that I am immediately informed about important updates relevant to my role (e.g. account status changes, new reviews, event updates, or admin alerts) without needing to manually check the app.

**Acceptance Criteria:**  
- [ ] The system delivers a push notification to the user's device in real time when a relevant event occurs (e.g. account approval, new review, saved event reminder, admin alert).
- [ ] Notifications are role-aware, showing only content relevant to the signed-in user's role (Visitor, Local, Admin).
- [ ] Tapping a notification navigates the user directly to the relevant screen or content.
- [ ] Users can view a running notification history in-app even if they miss or dismiss the original push alert.
- [ ] Notification delivery respects the user's saved notification preference settings (e.g. a disabled category is never sent).
- [ ] An unread notification count is visible on the notification bell/icon and clears once viewed.

**Non-Functional Requirement:**  
- **Performance & Reliability:** Push notifications must be delivered to the recipient's device within 10 seconds of the triggering event under normal network conditions, with failed sends logged and retried at least once, so users receive timely and dependable alerts without noticeable delay.

**Implementation Notes:**  
Implemented: Yes  
Files:  
- `lib/services/fcm_service.dart` — Firebase Cloud Messaging integration; requests permission, retrieves/stores device tokens, handles foreground/background notification display.  
- `lib/services/visitor_notification_repository.dart`, `lib/services/owner_notification_repository.dart`, `lib/services/admin_notification_service.dart` — Role-specific Firestore-backed notification history and delivery.  
- `lib/widgets/visitor_notification_bell.dart`, `lib/widgets/owner_notification_bell.dart`, `lib/features/admin/dashboard/widgets/admin_notification_bell.dart` — In-app bell UI showing unread counts and navigation to notification screens.  
- `lib/screens/notification_settings_screen.dart` — User-configurable notification preferences respected by delivery logic.  
- `functions/owner_notifications.js`, `functions/admin_notifications.js` — Cloud Functions triggers that send push/email notifications on relevant Firestore events.

---

## STORY-46: 30-Day Free Trial for New Business Owners

**Summary:** 30-Day Free Trial for New Business Owners  
**Type:** Story  
**Labels:** `Local`, `Business`  
**Priority:** High  
**Story Points:** 5  
**Status:** Done  

**Description:**  
As a new Business Owner, I want to automatically receive a 30-day free trial of BrisConnect+ premium features when I create my business profile, so that I can experience the full value of the platform (AI tools, promotions, insights) before committing to a paid subscription.

**Acceptance Criteria:**  
- [ ] When a new Local/business owner account is created, the system automatically starts a 30-day free trial without requiring any manual action or payment details from the owner.
- [ ] During the trial, the owner has full access to premium features (AI Tools, Gemini Insights, AI Promotion Assistant, AI-gated photo/video upload on promotions) as if subscribed.
- [ ] The dashboard clearly displays the trial status and days remaining (e.g. "FREE TRIAL • N DAYS LEFT") so the owner always knows where they stand.
- [ ] The owner can subscribe at any time during the trial via a visible "Subscribe Now" call to action.
- [ ] When the 30-day trial period ends, premium feature access is automatically revoked and the owner is prompted to subscribe, without requiring the owner to open a specific screen for the expiry to take effect.
- [ ] An existing paid subscription is never overwritten or restarted by the free-trial logic (the trial only applies to genuinely new owners).

**Non-Functional Requirement:**  
- **Consistency:** Trial/subscription status must be evaluated identically everywhere premium access is gated (dashboard, promotion creation, etc.), so an owner can never see conflicting "trial active" and "subscription required" states across different screens at the same time.

**Implementation Notes:**  
Implemented: Yes  
Files:  
- `functions/payments.js` — `onLocalUserCreated` (Firestore trigger on `local_users/{ownerId}` creation) writes a `business_subscriptions/{ownerId}` doc with `status:'trialing'`, `isFreeTrial:true`, `trialStartedAt`, `trialEndsAt` (+30 days), skipping if a subscription already exists. `getSubscriptionStatus` (callable) treats an active trial as `active:true`. `expireFreeTrials` (scheduled, every 60 min) batch-flips expired trials to `trial_expired` so the dashboard's real-time listener reflects expiry automatically.  
- `firestore.indexes.json` — Composite index on `business_subscriptions` (`isFreeTrial`, `status`, `trialEndsAt`) supporting the scheduled expiry query.  
- `lib/screens/business_dashboard_screen.dart` — AI Tools card badge and dedicated `_buildFreeTrialCard` showing trial days remaining and a "Subscribe Now" CTA.  
- `lib/screens/schedule_promotion_screen.dart` — `_hasActiveSubscription` check via `StripePaymentService.getSubscriptionStatus` automatically honours the trial.

---

## STORY-47: Business Appears in Trending Feed Based on Buzz

**Summary:** Business Appears in Trending Feed Based on Buzz  
**Type:** Story  
**Labels:** `Local`, `Business`, `Visitor`  
**Priority:** Medium  
**Story Points:** 5  
**Status:** Done  

**Description:**  
As a Local Food Business owner, I want my business to appear in the Trending Feed when it receives enough Buzz, so that more visitors discover my business.

**Acceptance Criteria:**  
- [ ] Trending ranking is based on Buzz score.
- [ ] Trending list updates automatically.
- [ ] Business remains trending while meeting the threshold.
- [ ] Trending badge is displayed.
- [ ] Trending rankings are refreshed within 5 minutes of a Buzz score update.
- [ ] Trending Feed data is available 99% of the time.

**Implementation Notes:**  
Implemented: Yes  
Files: see Code Components table below.

### Code Components

| Acceptance Criteria | Component | File | Short Code |
|---|---|---|---|
| Trending ranking is based on Buzz score | `calculateBuzzScore()` — weighted 0-100 score from rating, reviews, views, buzz votes, shares | `functions/index.js` | ```js\nfunction calculateBuzzScore({ viewCount, reviewCount, averageRating, buzzRatings, shareCount }) {\n  const ratingScore = Math.min((averageRating \|\| 0) / 5, 1) * 30;\n  const reviewScore = Math.min(reviewCount \|\| 0, 50) * 0.8;\n  const viewScore = Math.min(viewCount \|\| 0, 500) * 0.04;\n  const buzzRatingScore = buzzRatings.length > 0\n    ? (buzzRatings.reduce((a, b) => a + b, 0) / buzzRatings.length) * 2\n    : 0;\n  const shareScore = Math.min(shareCount \|\| 0, 50) * 0.1;\n  return Math.round(ratingScore + reviewScore + viewScore + buzzRatingScore + shareScore);\n}\n``` |
| Business remains trending while meeting the threshold | `TRENDING_THRESHOLD` + `isTrending` flag written on every recalculation | `functions/index.js` | ```js\nconst TRENDING_THRESHOLD = 70;\n// inside recalculateBusinessBuzzScore():\nawait businessRef.update({\n  buzzScore,\n  isTrending: buzzScore >= TRENDING_THRESHOLD,\n  reviewCount,\n  rating: averageRating,\n  updatedAt: admin.firestore.FieldValue.serverTimestamp(),\n});\n``` |
| Trending rankings are refreshed within 5 minutes | `refreshTrendingScores` — scheduled recalculation for all verified businesses | `functions/index.js` | ```js\nexports.refreshTrendingScores = onSchedule(\n  { region: 'australia-southeast1', schedule: 'every 5 minutes', timeoutSeconds: 300 },\n  async () => {\n    const businessesSnap = await db.collection('businesses')\n      .where('isVerified', '==', true).get();\n    await Promise.all(\n      businessesSnap.docs.map((doc) => recalculateBusinessBuzzScore(doc.id))\n    );\n  },\n);\n``` |
| Trending list updates automatically / Trending Feed data is available 99% of the time | `getTrendingBusinessesStream()` — real-time Firestore listener backed by Firestore's managed availability | `lib/services/business_profile_service.dart` | ```dart\nStream<List<Business>> getTrendingBusinessesStream({int limit = 20}) {\n  return _firestore\n      .collection(_collection)\n      .where('isTrending', isEqualTo: true)\n      .where('isVerified', isEqualTo: true)\n      .where('isActive', isEqualTo: true)\n      .where('deletedAt', isNull: true)\n      .orderBy('buzzScore', descending: true)\n      .limit(limit)\n      .snapshots()\n      .map((snapshot) =>\n          snapshot.docs.map((doc) => Business.fromFirestore(doc)).toList());\n}\n``` |
| Trending list updates automatically | Composite index supporting the query above | `firestore.indexes.json` | ```json\n{ "fieldPath": "isTrending", "order": "ASCENDING" },\n{ "fieldPath": "isVerified", "order": "ASCENDING" },\n{ "fieldPath": "buzzScore", "order": "DESCENDING" }\n``` |
| Trending badge is displayed | `_buildBuzzPill()` — "🔥 N buzz" pill on the business profile | `lib/screens/business_profile_view_screen.dart` | ```dart\nWidget _buildBuzzPill(double buzzScore) {\n  return Container(\n    decoration: BoxDecoration(\n      color: AppPalette.ochre.withValues(alpha: 0.12),\n      borderRadius: BorderRadius.circular(99),\n    ),\n    child: Row(mainAxisSize: MainAxisSize.min, children: [\n      const Icon(Icons.local_fire_department_rounded, size: 13, color: AppPalette.ochre),\n      Text('${buzzScore.round()} buzz'),\n    ]),\n  );\n}\n``` |
| Trending badge is displayed | `FeaturedMarker.trending` — badge icon on map pins | `lib/widgets/map/map_marker_helper.dart` | ```dart\nif (pin.isPremium) return const MapPinIcon.featured(FeaturedMarker.premium);\nif (pin.isPopular) return const MapPinIcon.featured(FeaturedMarker.trending);\nif (pin.isVerified) return const MapPinIcon.featured(FeaturedMarker.verified);\n``` |
| Trending badge is displayed | Trending count badge on the dedicated feed screen | `lib/screens/top_restaurants_screen.dart` | ```dart\n_AnalyticsCard(\n  icon: Icons.restaurant_rounded,\n  label: 'Trending',\n  value: '${businesses.length}',\n  color: const Color(0xFF00D084),\n)\n``` |
| Trending ranking is based on Buzz score | `buzzScore`/`isTrending` fields on the client model | `lib/models/business.dart` | ```dart\nfinal double buzzScore; // Computed engagement score (0-100)\nfinal bool isTrending;  // True when buzzScore meets threshold\n``` |

---

## STORY-48: Visitor Reviews and Ratings Build Business Trust

**Summary:** Visitor Reviews and Ratings Build Business Trust  
**Type:** Story  
**Labels:** `Local`, `Business`, `Visitor`  
**Priority:** High  
**Story Points:** 5  
**Status:** Done (owner-side reporting partially implemented — see notes)  

**Description:**  
As a Local Food Business owner, I want visitors to leave reviews and ratings so that I can build trust with future customers.

**Acceptance Criteria:**  
- [ ] Visitors can rate from 1–5 stars.
- [ ] Visitors can leave comments.
- [ ] Average rating updates automatically.
- [ ] Reviews appear in chronological order.
- [ ] Business owner can report inappropriate reviews.
- [ ] Personal data is stored securely and complies with privacy regulations.
- [ ] Review system has 99.5% uptime.

**Implementation Notes:**  
Implemented: Mostly Yes — reporting is currently wired up on visitor-facing screens (`business_profile_view_screen.dart`, `reviews_display_widget.dart`), not yet exposed as an explicit action on the business owner's Vendor Reviews screen (`vendor_reviews_screen.dart`). See Code Components table below.

### Code Components

| Acceptance Criteria | Component | File | Short Code |
|---|---|---|---|
| Visitors can rate from 1–5 stars | `_validateInputs()` — rejects any rating outside 1-5 before it reaches Firestore | `lib/services/review_service.dart` | ```dart\nvoid _validateInputs({required int rating, required int buzzRating, required String comment}) {\n  if (rating < 1 \|\| rating > 5) {\n    throw Exception('Rating must be between 1 and 5');\n  }\n  ...\n}\n``` |
| Visitors can rate from 1–5 stars | 5-star tappable UI in the review submission sheet | `lib/widgets/submit_review_bottom_sheet.dart` | ```dart\nRow(\n  children: List.generate(5, (index) {\n    return GestureDetector(\n      onTap: () => setState(() => _rating = index + 1),\n      child: Icon(\n        index < _rating ? Icons.star_rounded : Icons.star_border_rounded,\n        color: AppPalette.ochre, size: 36,\n      ),\n    );\n  }),\n)\n``` |
| Visitors can leave comments / Visitors can rate from 1–5 stars | `createReview()` — persists rating + comment for a business | `lib/services/review_service.dart` | ```dart\nFuture<String> createReview({\n  required String businessId,\n  String? visitorId,\n  required String visitorName,\n  required int rating,\n  int buzzRating = 0,\n  required String comment,\n  List<String>? photos,\n}) async {\n  _validateInputs(rating: rating, buzzRating: buzzRating, comment: comment);\n  final docRef = await _reviewsCollection.add({\n    'businessId': businessId, 'rating': rating, 'comment': comment.trim(),\n    'createdAt': FieldValue.serverTimestamp(), 'visible': true, ...\n  });\n  await _updateBusinessReviewMetrics(businessId);\n  return docRef.id;\n}\n``` |
| Average rating updates automatically | `getAverageRatingStream()` — real-time recalculation as reviews change | `lib/services/review_service.dart` | ```dart\nStream<double> getAverageRatingStream(String businessId) {\n  return _reviewsCollection\n      .where('businessId', isEqualTo: businessId)\n      .where('visible', isEqualTo: true)\n      .snapshots()\n      .map((snapshot) {\n    if (snapshot.docs.isEmpty) return 0.0;\n    final total = snapshot.docs.fold<num>(0, (t, d) => t + (d['rating'] as int? ?? 0));\n    return total / snapshot.docs.length;\n  });\n}\n``` |
| Reviews appear in chronological order | `getBusinessReviewsStream()` — ordered newest-first, real-time | `lib/services/review_service.dart` | ```dart\nStream<List<Review>> getBusinessReviewsStream(String businessId, {int limit = _defaultPageSize}) {\n  return _visibleReviewsForBusiness(businessId)\n      .orderBy('createdAt', descending: true)\n      .limit(limit)\n      .snapshots()\n      .map((s) => s.docs.map((d) => Review.fromFirestore(d)).toList());\n}\n``` |
| Business owner can report inappropriate reviews | `reportReview()` — marks a review reported/hidden pending moderation | `lib/services/review_service.dart` | ```dart\nFuture<void> reportReview(String reviewId, String reportReason, {String? reporterId, String severity = 'medium'}) async {\n  await _reviewsCollection.doc(reviewId).update({\n    'isReported': true,\n    'reportReason': reportReason.trim(),\n    'reportedBy': reporterId ?? _currentUserIdOrAuth ?? '',\n    'visible': false,\n    'updatedAt': FieldValue.serverTimestamp(),\n  });\n}\n``` |
| Business owner can report inappropriate reviews | Current call sites are visitor-facing (owner UI not yet wired) | `lib/screens/business_profile_view_screen.dart`, `lib/widgets/reviews_display_widget.dart` | ```dart\nonReport: () => _reportReview(review) // visitor screen only\n``` |
| Personal data is stored securely and complies with privacy regulations | Firestore security rules — auth-bound create, shape/length validation, restricted update | `firestore.rules` | ```js\nallow create: if isSignedIn()\n  && request.resource.data.visitorId == request.auth.uid\n  && request.resource.data.comment.size() > 0 && request.resource.data.comment.size() <= 500\n  && request.resource.data.rating >= 1 && request.resource.data.rating <= 5;\nallow update: if isAdmin() \|\| (isSignedIn() && resource.data.visitorId == request.auth.uid && ...);\n``` |
| Personal data is stored securely and complies with privacy regulations | `Review` model — reviewer identity limited to name/id, no extra PII fields persisted | `lib/models/review.dart` | ```dart\nfinal String visitorId;\nfinal String visitorName;\nfinal String? visitorPhotoUrl; // only what's needed to display the review\n``` |
| Review system has 99.5% uptime | Real-time Firestore `.snapshots()` listeners (no custom backend to fail) + graceful loading/empty states | `lib/services/review_service.dart`, `lib/screens/vendor_reviews_screen.dart` | ```dart\n// StreamBuilder pattern used throughout: shows spinner while\n// ConnectionState.waiting, falls back to empty state on no data,\n// relies on Firestore's managed SLA rather than custom infra.\n```<br>See `_withRetry()` helper in `review_service.dart` for automatic retry on transient Firestore errors. |
