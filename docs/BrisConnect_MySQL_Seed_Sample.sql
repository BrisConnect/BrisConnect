-- BrisConnect sample seed data for MySQL schema
-- This script assumes tables already exist from docs/BrisConnect_MySQL_Schema.sql.

START TRANSACTION;

-- Core users
INSERT INTO admins (email, username, role, active, created_at, updated_at)
VALUES
('admin@brisconnect.app', 'admin', 'super_admin', 1, NOW(3), NOW(3));

INSERT INTO local_users (
  email, username, name, approval_status, approved, approved_at, has_pin, pin,
  approval_notes, account_holder, profile_image_url, fcm_token, created_at, updated_at
)
VALUES (
  'local1@example.com', 'local1', 'Local Organizer', 'approved', 1, NOW(3), 0, NULL,
  'Initial seed approval', 'Local Organizer', NULL, NULL, NOW(3), NOW(3)
);

INSERT INTO visitor_users (
  email, username, name, profile_image_url, fcm_token, created_at, updated_at
)
VALUES (
  'visitor1@example.com', 'visitor1', 'Visitor One', NULL, NULL, NOW(3), NOW(3)
);

-- System metadata/config
INSERT INTO seed_metadata (
  id, version, initialized, started_by, initialized_at, last_updated, default_images
)
VALUES (
  'default', 1, 1, 'seed-script', NOW(3), NOW(3), JSON_OBJECT('event', 'default_event.png')
);

INSERT INTO counters (id, count_value, updated_at)
VALUES ('events', 1, NOW(3));

INSERT INTO app_config (id, payload_json, updated_at)
VALUES (
  'global',
  JSON_OBJECT('maintenanceMode', false, 'minSupportedVersion', '1.0.0'),
  NOW(3)
);

-- Domain content
INSERT INTO attractions (
  id, name, short_description, full_description, category,
  latitude, longitude, image_url, image_path, place_id,
  source, source_id, opening_hours, website, phone,
  distance_km, approval_status, approved_by_admin, approved_at, approved_rejected_at,
  status, is_approved, icon, added_by, added_by_name,
  created_at, updated_at
)
VALUES (
  'attr_0001', 'South Bank Parklands', 'Riverside destination',
  'Popular public space with dining and recreation.', 'landmarks',
  -27.4808, 153.0229, NULL, NULL, 'place_0001',
  'seed', 'manual_seed', JSON_OBJECT('openNow', true), 'https://example.com', '+61700000000',
  0.8, 'approved', 'admin@brisconnect.app', NOW(3), NOW(3),
  'approved', 1, 'park', 'local1@example.com', 'Local Organizer',
  NOW(3), NOW(3)
);

INSERT INTO attraction_details (
  attraction_id, average_rating, review_count, details_json, updated_at
)
VALUES (
  'attr_0001', 4.6, 120,
  JSON_OBJECT('bestTime', 'morning', 'familyFriendly', true),
  NOW(3)
);

INSERT INTO events (
  id, title, description, event_type, category,
  latitude, longitude, location_name,
  start_date, end_date, start_time, end_time,
  image_url, image_path,
  max_participants, participant_count,
  created_by_local_email, created_by_name,
  review_status, is_approved, approved_by_admin, approved_at,
  local_community, city, state, country,
  source, is_archived,
  created_at, updated_at
)
VALUES (
  'evt_0001', 'Community River Walk', 'Guided walk for visitors and locals.',
  'community', 'outdoors',
  -27.4705, 153.0260, 'Brisbane Riverwalk',
  DATE(NOW()), DATE_ADD(DATE(NOW()), INTERVAL 1 DAY), '08:00', '10:00',
  NULL, NULL,
  50, 1,
  'local1@example.com', 'Local Organizer',
  'approved', 1, 'admin@brisconnect.app', NOW(3),
  'South Brisbane', 'Brisbane', 'QLD', 'Australia',
  'local', 0,
  NOW(3), NOW(3)
);

INSERT INTO discover_items (
  id, title, description, image_url, image_path,
  section, item_type, category,
  latitude, longitude, location_name,
  event_id, attraction_id,
  created_by_local_email, created_by_name,
  source, source_id,
  start_date, end_date,
  published, approved,
  created_at, updated_at
)
VALUES (
  'dis_0001', 'Featured River Walk', 'Top community pick this week.', NULL, NULL,
  'featured', 'event', 'outdoors',
  -27.4705, 153.0260, 'Brisbane Riverwalk',
  'evt_0001', NULL,
  'local1@example.com', 'Local Organizer',
  'event', 'evt_0001',
  DATE(NOW()), DATE_ADD(DATE(NOW()), INTERVAL 1 DAY),
  1, 1,
  NOW(3), NOW(3)
);

-- Engagement and moderation
INSERT INTO event_reports (
  id, event_id, visitor_email, reason, details,
  status, action, action_by, action_at,
  created_at, updated_at
)
VALUES (
  'rep_0001', 'evt_0001', 'visitor1@example.com', 'other', 'Test moderation flow',
  'open', NULL, NULL, NULL,
  NOW(3), NOW(3)
);

INSERT INTO app_feedback (
  id, reference_id, reporter_email, feedback_type, message,
  status, reviewed_by, reviewed_at,
  created_at, updated_at
)
VALUES (
  'fb_0001', 'evt_0001', 'visitor1@example.com', 'event', 'Great event and easy to join.',
  'new', NULL, NULL,
  NOW(3), NOW(3)
);

INSERT INTO user_notifications (
  id, user_email, user_type, title, body,
  event_id, data_json, read_flag,
  created_at, updated_at
)
VALUES (
  'not_0001', 'visitor1@example.com', 'visitor', 'Event Approved', 'Your interested event is live now.',
  'evt_0001', JSON_OBJECT('screen', 'eventDetails', 'eventId', 'evt_0001'), 0,
  NOW(3), NOW(3)
);

-- Preference/junction examples
INSERT INTO local_user_interested_events (local_email, event_id, created_at)
VALUES ('local1@example.com', 'evt_0001', NOW(3));

INSERT INTO visitor_user_interested_events (visitor_email, event_id, created_at)
VALUES ('visitor1@example.com', 'evt_0001', NOW(3));

INSERT INTO visitor_user_saved_attractions (visitor_email, attraction_id, created_at)
VALUES ('visitor1@example.com', 'attr_0001', NOW(3));

INSERT INTO local_user_interest_categories (local_email, category_name, created_at)
VALUES ('local1@example.com', 'outdoors', NOW(3));

INSERT INTO visitor_user_interest_categories (visitor_email, category_name, created_at)
VALUES ('visitor1@example.com', 'landmarks', NOW(3));

-- Optional queue and content snapshots
INSERT INTO mail_queue (
  id, recipient_to, subject, body, status,
  payload_json, attempts, max_attempts, scheduled_at,
  created_at, updated_at
)
VALUES (
  'mail_0001', 'visitor1@example.com', 'Welcome to BrisConnect', 'Thanks for joining.', 'queued',
  JSON_OBJECT('template', 'welcome', 'locale', 'en-AU'), 0, 5, NOW(3),
  NOW(3), NOW(3)
);

INSERT INTO sms_queue (
  id, recipient_to, message, status,
  payload_json, attempts, max_attempts, scheduled_at,
  created_at, updated_at
)
VALUES (
  'sms_0001', '+61400000000', 'Your event starts soon.', 'queued',
  JSON_OBJECT('provider', 'twilio'), 0, 5, NOW(3),
  NOW(3), NOW(3)
);

INSERT INTO brisbane_stories (id, title, body, category, image_url, source, published_at, created_at, updated_at)
VALUES ('story_0001', 'A Day in South Bank', 'Community highlights for new visitors.', 'culture', NULL, 'seed', NOW(3), NOW(3), NOW(3));

INSERT INTO brisbane_voices (id, name, role, quote_text, image_url, source, published_at, created_at, updated_at)
VALUES ('voice_0001', 'Alex', 'Local Host', 'Brisbane feels like home to everyone.', NULL, 'seed', NOW(3), NOW(3), NOW(3));

INSERT INTO connectivity_probe (id, healthy, checked_at)
VALUES ('default', 1, NOW(3));

COMMIT;
