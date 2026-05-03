-- BrisConnect MySQL-style relational schema
-- Source model: Firestore collections and app write paths
-- Notes:
-- 1) Firestore is schemaless; this is a normalized SQL equivalent.
-- 2) Arrays are modeled with child tables.
-- 3) Flexible payload documents use JSON columns.

CREATE DATABASE IF NOT EXISTS brisconnect;
USE brisconnect;

CREATE TABLE admins (
  email VARCHAR(255) PRIMARY KEY,
  username VARCHAR(120) NULL,
  name VARCHAR(160) NULL,
  role VARCHAR(40) NOT NULL DEFAULT 'admin',
  active BOOLEAN NOT NULL DEFAULT TRUE,
  profile_image_url TEXT NULL,
  profile_image_storage_path TEXT NULL,
  last_login_at DATETIME NULL,
  updated_at DATETIME NULL,
  created_at DATETIME NULL
);

CREATE TABLE local_users (
  email VARCHAR(255) PRIMARY KEY,
  username VARCHAR(120) NULL,
  name VARCHAR(160) NOT NULL,
  phone VARCHAR(40) NULL,
  suburb VARCHAR(120) NULL,
  role VARCHAR(40) NOT NULL DEFAULT 'local',
  account_type VARCHAR(40) NOT NULL DEFAULT 'local',
  approval_status ENUM('pending','approved','rejected') NOT NULL DEFAULT 'pending',
  password_hash VARCHAR(255) NULL,
  notifications_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  event_reminders_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  reminder_timing VARCHAR(40) NOT NULL DEFAULT '24h',
  event_updates_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  nearby_events_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  recommended_events_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  use_current_location BOOLEAN NOT NULL DEFAULT TRUE,
  location_radius_km INT NOT NULL DEFAULT 20,
  location_access_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  theme_preference VARCHAR(40) NOT NULL DEFAULT 'system',
  text_scale_factor DECIMAL(4,2) NOT NULL DEFAULT 1.00,
  profile_image_base64 LONGTEXT NULL,
  profile_image_url TEXT NULL,
  profile_image_storage_path TEXT NULL,
  auth_fallback BOOLEAN NOT NULL DEFAULT FALSE,
  password_updated_at DATETIME NULL,
  created_at DATETIME NULL,
  updated_at DATETIME NULL
);

CREATE TABLE visitor_users (
  email VARCHAR(255) PRIMARY KEY,
  username VARCHAR(120) NULL,
  name VARCHAR(160) NOT NULL,
  phone VARCHAR(40) NULL,
  role VARCHAR(40) NOT NULL DEFAULT 'visitor',
  password_hash VARCHAR(255) NULL,
  notifications_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  event_reminders_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  reminder_timing VARCHAR(40) NOT NULL DEFAULT '24h',
  event_updates_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  nearby_events_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  recommended_events_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  email_notifications_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  use_current_location BOOLEAN NOT NULL DEFAULT TRUE,
  location_radius_km INT NOT NULL DEFAULT 20,
  location_access_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  theme_preference VARCHAR(40) NOT NULL DEFAULT 'system',
  text_scale_factor DECIMAL(4,2) NOT NULL DEFAULT 1.00,
  profile_image_base64 LONGTEXT NULL,
  profile_image_url TEXT NULL,
  profile_image_storage_path TEXT NULL,
  password_updated_at DATETIME NULL,
  created_at DATETIME NULL,
  updated_at DATETIME NULL
);

CREATE TABLE events (
  id VARCHAR(160) PRIMARY KEY,
  title VARCHAR(255) NOT NULL,
  event_date VARCHAR(60) NULL,
  event_time VARCHAR(60) NULL,
  date_time VARCHAR(120) NULL,
  category VARCHAR(80) NULL,
  location VARCHAR(255) NULL,
  venue VARCHAR(255) NULL,
  suburb VARCHAR(120) NULL,
  description TEXT NULL,
  created_by_local_email VARCHAR(255) NULL,
  review_status VARCHAR(40) NULL,
  approval_status VARCHAR(40) NULL,
  status VARCHAR(40) NULL,
  badge VARCHAR(40) NULL,
  is_approved BOOLEAN NOT NULL DEFAULT FALSE,
  report_count INT NOT NULL DEFAULT 0,
  flagged_for_admin_review BOOLEAN NOT NULL DEFAULT FALSE,
  last_reported_at DATETIME NULL,
  source VARCHAR(80) NULL,
  source_provider VARCHAR(120) NULL,
  source_url TEXT NULL,
  image_url TEXT NULL,
  image_storage_path TEXT NULL,
  video_url TEXT NULL,
  video_storage_path TEXT NULL,
  audio_url TEXT NULL,
  audio_storage_path TEXT NULL,
  ai_narration LONGTEXT NULL,
  latitude DECIMAL(10,7) NULL,
  longitude DECIMAL(10,7) NULL,
  created_at DATETIME NULL,
  updated_at DATETIME NULL,
  CONSTRAINT fk_events_local_user
    FOREIGN KEY (created_by_local_email) REFERENCES local_users(email)
    ON DELETE SET NULL
);

CREATE TABLE attractions (
  id VARCHAR(160) PRIMARY KEY,
  name VARCHAR(255) NULL,
  title VARCHAR(255) NULL,
  description TEXT NULL,
  location VARCHAR(255) NULL,
  latitude DECIMAL(10,7) NULL,
  longitude DECIMAL(10,7) NULL,
  category VARCHAR(80) NULL,
  web_link TEXT NULL,
  image_url TEXT NULL,
  image_storage_path TEXT NULL,
  audio_url TEXT NULL,
  audio_storage_path TEXT NULL,
  ai_narration LONGTEXT NULL,
  approval_status VARCHAR(40) NULL,
  review_status VARCHAR(40) NULL,
  status VARCHAR(40) NULL,
  is_approved BOOLEAN NOT NULL DEFAULT FALSE,
  source_provider VARCHAR(120) NULL,
  source_place_id VARCHAR(255) NULL,
  created_at DATETIME NULL,
  updated_at DATETIME NULL
);

CREATE TABLE attraction_accessibility_details (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  attraction_id VARCHAR(160) NOT NULL,
  detail_text VARCHAR(255) NOT NULL,
  CONSTRAINT fk_acc_detail_attraction
    FOREIGN KEY (attraction_id) REFERENCES attractions(id)
    ON DELETE CASCADE
);

CREATE TABLE attraction_details (
  attraction_id VARCHAR(160) PRIMARY KEY,
  history LONGTEXT NULL,
  address VARCHAR(255) NULL,
  special_schedule TEXT NULL,
  entry_requirements TEXT NULL,
  ticket_price VARCHAR(120) NULL,
  booking_label VARCHAR(120) NULL,
  booking_url TEXT NULL,
  media_json JSON NULL,
  virtual_tour_url TEXT NULL,
  rating DECIMAL(4,2) NULL,
  review_count INT NULL,
  rating_breakdown_json JSON NULL,
  reviews_json JSON NULL,
  phone VARCHAR(60) NULL,
  website TEXT NULL,
  email VARCHAR(255) NULL,
  facilities_json JSON NULL,
  amenities_json JSON NULL,
  accessibility_json JSON NULL,
  visit_duration VARCHAR(120) NULL,
  best_time_to_visit VARCHAR(255) NULL,
  live_update_json JSON NULL,
  nearby_attractions_json JSON NULL,
  nearby_services_json JSON NULL,
  languages_json JSON NULL,
  audio_features_json JSON NULL,
  personalised_suggestions_json JSON NULL,
  CONSTRAINT fk_attraction_details_attraction
    FOREIGN KEY (attraction_id) REFERENCES attractions(id)
    ON DELETE CASCADE
);

CREATE TABLE event_reports (
  id VARCHAR(255) PRIMARY KEY,
  event_id VARCHAR(160) NOT NULL,
  visitor_email VARCHAR(255) NOT NULL,
  reason VARCHAR(80) NOT NULL,
  comments TEXT NULL,
  status VARCHAR(40) NOT NULL DEFAULT 'pending',
  created_at DATETIME NULL,
  reviewed_at DATETIME NULL,
  CONSTRAINT fk_event_reports_event
    FOREIGN KEY (event_id) REFERENCES events(id)
    ON DELETE CASCADE,
  CONSTRAINT fk_event_reports_visitor
    FOREIGN KEY (visitor_email) REFERENCES visitor_users(email)
    ON DELETE CASCADE,
  INDEX idx_event_reports_status_created_at (status, created_at DESC)
);

CREATE TABLE app_feedback (
  id VARCHAR(160) PRIMARY KEY,
  reference_id VARCHAR(80) NOT NULL,
  reporter_role VARCHAR(40) NOT NULL,
  reporter_email VARCHAR(255) NOT NULL,
  reporter_name VARCHAR(160) NULL,
  subject VARCHAR(255) NOT NULL,
  details LONGTEXT NOT NULL,
  category VARCHAR(80) NULL,
  severity VARCHAR(40) NULL,
  status VARCHAR(40) NOT NULL DEFAULT 'pending_triage',
  considered_for_fix BOOLEAN NOT NULL DEFAULT TRUE,
  maintenance_window_days INT NOT NULL DEFAULT 14,
  resolution_due_at DATETIME NULL,
  admin_reply LONGTEXT NULL,
  admin_reply_at DATETIME NULL,
  reply_read_by_reporter BOOLEAN NOT NULL DEFAULT TRUE,
  image_url TEXT NULL,
  image_storage_path TEXT NULL,
  created_at DATETIME NULL,
  updated_at DATETIME NULL,
  UNIQUE KEY uk_app_feedback_reference_id (reference_id)
);

CREATE TABLE user_notifications (
  id VARCHAR(255) PRIMARY KEY,
  event_id VARCHAR(160) NULL,
  user_email VARCHAR(255) NOT NULL,
  user_type ENUM('visitor','local') NOT NULL,
  event_title VARCHAR(255) NULL,
  event_date_time VARCHAR(120) NULL,
  event_location VARCHAR(255) NULL,
  schedule_type VARCHAR(40) NOT NULL DEFAULT 'unknown',
  is_read BOOLEAN NOT NULL DEFAULT FALSE,
  created_at DATETIME NULL,
  CONSTRAINT fk_user_notifications_event
    FOREIGN KEY (event_id) REFERENCES events(id)
    ON DELETE SET NULL
);

CREATE TABLE mail_queue (
  id VARCHAR(255) PRIMARY KEY,
  recipient_to VARCHAR(255) NOT NULL,
  message_json JSON NOT NULL,
  meta_json JSON NULL,
  created_at DATETIME NULL
);

CREATE TABLE sms_queue (
  id VARCHAR(255) PRIMARY KEY,
  recipient_to VARCHAR(40) NOT NULL,
  message_text TEXT NOT NULL,
  meta_json JSON NULL,
  created_at DATETIME NULL
);

CREATE TABLE brisbane_stories (
  id VARCHAR(160) PRIMARY KEY,
  title VARCHAR(255) NOT NULL,
  description TEXT NULL,
  image_url TEXT NULL,
  category VARCHAR(80) NULL,
  content LONGTEXT NULL,
  latitude DECIMAL(10,7) NULL,
  longitude DECIMAL(10,7) NULL,
  location_name VARCHAR(255) NULL,
  approval_status VARCHAR(40) NULL,
  published_at DATETIME NULL,
  created_at DATETIME NULL
);

CREATE TABLE brisbane_voices (
  id VARCHAR(160) PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  quote_text LONGTEXT NULL,
  profile_image_url TEXT NULL,
  approval_status VARCHAR(40) NULL,
  created_at DATETIME NULL
);

CREATE TABLE discover_items (
  id VARCHAR(160) PRIMARY KEY,
  title VARCHAR(255) NOT NULL,
  section VARCHAR(80) NULL,
  category VARCHAR(80) NULL,
  location VARCHAR(255) NULL,
  venue VARCHAR(255) NULL,
  suburb VARCHAR(120) NULL,
  event_date VARCHAR(60) NULL,
  event_time VARCHAR(60) NULL,
  date_time VARCHAR(120) NULL,
  description TEXT NULL,
  approval_status VARCHAR(40) NULL,
  source VARCHAR(80) NULL,
  source_provider VARCHAR(120) NULL,
  source_place_id VARCHAR(255) NULL,
  source_url TEXT NULL,
  created_by_local_email VARCHAR(255) NULL,
  image_url TEXT NULL,
  image_storage_path TEXT NULL,
  video_url TEXT NULL,
  video_storage_path TEXT NULL,
  audio_url TEXT NULL,
  audio_storage_path TEXT NULL,
  ai_narration LONGTEXT NULL,
  updated_at DATETIME NULL,
  CONSTRAINT fk_discover_items_local_user
    FOREIGN KEY (created_by_local_email) REFERENCES local_users(email)
    ON DELETE SET NULL
);

CREATE TABLE seed_metadata (
  id VARCHAR(160) PRIMARY KEY,
  version INT NULL,
  source_provider VARCHAR(120) NULL,
  discover_item_count INT NULL,
  attraction_count INT NULL,
  event_count INT NULL,
  historical_count INT NULL,
  write_count INT NULL,
  seeded_at DATETIME NULL,
  last_synced_at DATETIME NULL
);

CREATE TABLE counters (
  id VARCHAR(160) PRIMARY KEY,
  count_value BIGINT NOT NULL DEFAULT 0
);

CREATE TABLE app_config (
  id VARCHAR(160) PRIMARY KEY,
  payload_json JSON NOT NULL
);

CREATE TABLE connectivity_probe (
  id VARCHAR(160) PRIMARY KEY,
  payload_json JSON NULL,
  checked_at DATETIME NULL
);

-- Many-to-many tables for interest and saved lists

CREATE TABLE local_user_interested_events (
  local_email VARCHAR(255) NOT NULL,
  event_id VARCHAR(160) NOT NULL,
  PRIMARY KEY (local_email, event_id),
  CONSTRAINT fk_luie_local
    FOREIGN KEY (local_email) REFERENCES local_users(email)
    ON DELETE CASCADE,
  CONSTRAINT fk_luie_event
    FOREIGN KEY (event_id) REFERENCES events(id)
    ON DELETE CASCADE
);

CREATE TABLE visitor_user_interested_events (
  visitor_email VARCHAR(255) NOT NULL,
  event_id VARCHAR(160) NOT NULL,
  PRIMARY KEY (visitor_email, event_id),
  CONSTRAINT fk_vuie_visitor
    FOREIGN KEY (visitor_email) REFERENCES visitor_users(email)
    ON DELETE CASCADE,
  CONSTRAINT fk_vuie_event
    FOREIGN KEY (event_id) REFERENCES events(id)
    ON DELETE CASCADE
);

CREATE TABLE visitor_user_saved_attractions (
  visitor_email VARCHAR(255) NOT NULL,
  attraction_id VARCHAR(160) NOT NULL,
  PRIMARY KEY (visitor_email, attraction_id),
  CONSTRAINT fk_vusa_visitor
    FOREIGN KEY (visitor_email) REFERENCES visitor_users(email)
    ON DELETE CASCADE,
  CONSTRAINT fk_vusa_attraction
    FOREIGN KEY (attraction_id) REFERENCES attractions(id)
    ON DELETE CASCADE
);

CREATE TABLE local_user_interest_categories (
  local_email VARCHAR(255) NOT NULL,
  category_name VARCHAR(120) NOT NULL,
  PRIMARY KEY (local_email, category_name),
  CONSTRAINT fk_luic_local
    FOREIGN KEY (local_email) REFERENCES local_users(email)
    ON DELETE CASCADE
);

CREATE TABLE visitor_user_interest_categories (
  visitor_email VARCHAR(255) NOT NULL,
  category_name VARCHAR(120) NOT NULL,
  PRIMARY KEY (visitor_email, category_name),
  CONSTRAINT fk_vuic_visitor
    FOREIGN KEY (visitor_email) REFERENCES visitor_users(email)
    ON DELETE CASCADE
);
