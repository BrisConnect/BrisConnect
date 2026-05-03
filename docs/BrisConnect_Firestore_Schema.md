# BrisConnect Firestore Schema

This document provides the full Firestore schema currently used by BrisConnect.
It is based on security rules and implemented write/read paths in the codebase.

## 1) admins

- Document path: admins/{emailLowercase}
- Purpose: Admin identity and role metadata
- Common fields:
  - email: string
  - username: string
  - name: string
  - role: string (admin)
  - active: boolean
  - profileImageUrl: string
  - profileImageStoragePath: string
  - lastLoginAt: timestamp
  - updatedAt: timestamp

## 2) local_users

- Document path: local_users/{emailLowercase}
- Purpose: Local user account, profile, preferences, and approval state
- Common fields:
  - name: string
  - email: string
  - username: string
  - role: string (local)
  - accountType: string (local)
  - phone: string
  - suburb: string
  - approvalStatus: string (pending, approved, rejected)
  - passwordHash: string
  - passwordUpdatedAt: timestamp
  - interestedEventIds: array<string>
  - interestCategories: array<string>
  - notificationsEnabled: boolean
  - eventRemindersEnabled: boolean
  - reminderTiming: string
  - eventUpdatesEnabled: boolean
  - nearbyEventsEnabled: boolean
  - recommendedEventsEnabled: boolean
  - useCurrentLocation: boolean
  - locationRadiusKm: number
  - locationAccessEnabled: boolean
  - themePreference: string
  - textScaleFactor: number
  - profileImageBase64: string|null
  - profileImageUrl: string|null
  - profileImageStoragePath: string|null
  - authFallback: boolean
  - createdAt: timestamp
  - updatedAt: timestamp

## 3) visitor_users

- Document path: visitor_users/{emailLowercase}
- Purpose: Visitor account, profile, interests, and preferences
- Common fields:
  - name: string
  - email: string
  - username: string
  - role: string (visitor)
  - phone: string
  - passwordHash: string
  - passwordUpdatedAt: timestamp
  - interestedEventIds: array<string>
  - savedAttractionIds: array<string>
  - interestCategories: array<string>
  - interestPriorities: array<string>
  - notificationsEnabled: boolean
  - eventRemindersEnabled: boolean
  - reminderTiming: string
  - eventUpdatesEnabled: boolean
  - nearbyEventsEnabled: boolean
  - recommendedEventsEnabled: boolean
  - emailNotificationsEnabled: boolean
  - useCurrentLocation: boolean
  - locationRadiusKm: number
  - locationAccessEnabled: boolean
  - themePreference: string
  - textScaleFactor: number
  - profileImageBase64: string|null
  - profileImageUrl: string|null
  - profileImageStoragePath: string|null
  - createdAt: timestamp
  - updatedAt: timestamp

## 4) events

- Document path: events/{eventId}
- Purpose: Event catalog (seeded, imported, and local-submitted events)
- Common fields:
  - id: string
  - title: string
  - date: string
  - time: string
  - dateTime: string
  - category: string
  - location: string
  - venue: string
  - suburb: string
  - description: string
  - createdByLocalEmail: string
  - reviewStatus: string
  - approvalStatus: string
  - status: string
  - badge: string
  - isApproved: boolean
  - reportCount: number
  - flaggedForAdminReview: boolean
  - lastReportedAt: timestamp
  - source: string
  - sourceProvider: string
  - sourceUrl: string
  - imageUrl: string
  - imageStoragePath: string
  - videoUrl: string
  - videoStoragePath: string
  - audioUrl: string
  - audioStoragePath: string
  - aiNarration: string
  - latitude: number
  - longitude: number
  - createdAt: timestamp
  - updatedAt: timestamp

## 5) attractions

- Document path: attractions/{attractionId}
- Purpose: Approved attractions and admin-managed attraction records
- Common fields:
  - id: string
  - name: string
  - title: string
  - description: string
  - location: string
  - latitude: number
  - longitude: number
  - category: string
  - accessibilityDetails: array<string>
  - webLink: string
  - imageUrl: string
  - imageStoragePath: string
  - audioUrl: string
  - audioStoragePath: string
  - aiNarration: string
  - approvalStatus: string
  - reviewStatus: string
  - status: string
  - isApproved: boolean
  - sourceProvider: string
  - sourcePlaceId: string
  - createdAt: timestamp
  - updatedAt: timestamp

## 6) attraction_details

- Document path: attraction_details/{attractionId}
- Purpose: Extended detail page content for attractions
- Common fields:
  - history: string
  - address: string
  - openingHours: array<string>
  - specialSchedule: string
  - entryRequirements: string
  - ticketPrice: string
  - bookingLabel: string
  - bookingUrl: string
  - media: array<object>
  - virtualTourUrl: string
  - rating: number
  - reviewCount: number
  - ratingBreakdown: object
  - reviews: array<object>
  - phone: string
  - website: string
  - email: string
  - facilities: array<string>
  - amenities: array<string>
  - accessibility: array<string>
  - visitDuration: string
  - bestTimeToVisit: string
  - liveUpdate: object
  - nearbyAttractions: array<string>
  - nearbyServices: array<string>
  - languages: array<string>
  - audioFeatures: array<string>
  - personalisedSuggestions: array<string>

## 7) event_reports

- Document path: event_reports/{eventId__visitorEmailEncoded}
- Purpose: Visitor reports against events
- Common fields:
  - eventId: string
  - visitorEmail: string
  - reason: string
  - comments: string|null
  - status: string (pending, reviewing, resolved, dismissed)
  - createdAt: timestamp
  - reviewedAt: timestamp|null

## 8) app_feedback

- Document path: app_feedback/{referenceIdLowercase}
- Purpose: User app feedback and admin response workflow
- Common fields:
  - referenceId: string (for example FB-0001)
  - reporterRole: string
  - reporterEmail: string
  - reporterName: string
  - subject: string
  - details: string
  - category: string
  - severity: string
  - status: string (pending_triage, in_progress, resolved, wont_fix)
  - consideredForFix: boolean
  - maintenanceWindowDays: number
  - resolutionDueAt: timestamp
  - adminReply: string|null
  - adminReplyAt: timestamp|null
  - replyReadByReporter: boolean
  - imageUrl: string|null
  - imageStoragePath: string|null
  - createdAt: timestamp
  - updatedAt: timestamp

## 9) user_notifications

- Document path: user_notifications/{notificationId}
- Purpose: In-app notification records for users
- Common fields:
  - eventId: string
  - userEmail: string
  - userType: string (visitor, local)
  - eventTitle: string
  - eventDateTime: string
  - eventLocation: string
  - scheduleType: string (event_time, fallback, unknown)
  - isRead: boolean
  - createdAt: timestamp

## 10) mail

- Document path: mail/{queueId}
- Purpose: Outbound email queue consumed by Firebase extension/worker
- Common fields:
  - to: string
  - message: object
  - meta: object
  - createdAt: timestamp

## 11) sms_queue

- Document path: sms_queue/{queueId}
- Purpose: Outbound SMS queue
- Common fields:
  - to: string
  - message: string
  - meta: object
  - createdAt: timestamp

## 12) brisbane_stories

- Document path: brisbane_stories/{storySlug}
- Purpose: Curated story content
- Common fields:
  - title: string
  - description: string
  - imageUrl: string
  - category: string
  - content: string
  - latitude: number
  - longitude: number
  - locationName: string
  - approvalStatus: string
  - publishedAt: timestamp
  - createdAt: timestamp

## 13) brisbane_voices

- Document path: brisbane_voices/{voiceSlug}
- Purpose: Curated voices/quotes
- Common fields:
  - name: string
  - quote: string
  - profileImageUrl: string
  - approvalStatus: string
  - createdAt: timestamp

## 14) discover_items

- Document path: discover_items/{discoverItemId}
- Purpose: Unified discovery feed (events, historical, food, stadium/venues)
- Common fields:
  - id: string
  - title: string
  - section: string
  - category: string
  - location: string
  - venue: string
  - suburb: string
  - date: string
  - time: string
  - dateTime: string
  - description: string
  - approvalStatus: string
  - source: string
  - sourceProvider: string
  - sourcePlaceId: string
  - sourceUrl: string
  - createdByLocalEmail: string
  - imageUrl: string
  - imageStoragePath: string
  - videoUrl: string
  - videoStoragePath: string
  - audioUrl: string
  - audioStoragePath: string
  - aiNarration: string
  - updatedAt: timestamp

## 15) seed_metadata

- Document path: seed_metadata/{seedName}
- Purpose: Seed/sync bookkeeping
- Common fields:
  - version: number
  - sourceProvider: string
  - discoverItemCount: number
  - attractionCount: number
  - eventCount: number
  - historicalCount: number
  - writeCount: number
  - seededAt: timestamp
  - lastSyncedAt: timestamp

## 16) counters

- Document path: counters/{counterName}
- Purpose: Incremental counters for human-readable IDs
- Common fields:
  - count: number

## 17) config

- Document path: config/{configKey}
- Purpose: Admin-managed app configuration
- Common fields:
  - payload: object (shape varies by config key)

## 18) _connectivity_probe

- Document path: _connectivity_probe/{probeId}
- Purpose: Connectivity probe for online/offline UX handling
- Common fields:
  - payload: object

## Firestore Indexes

- Composite index:
  - Collection: event_reports
  - Fields:
    - status ascending
    - createdAt descending

## Access Model Summary

- Signed-in users can read most business collections.
- Admin users can write admin-controlled collections.
- Users can create and update their own profile documents keyed by email.
- Event updates/deletes are restricted to event owner or admin.
