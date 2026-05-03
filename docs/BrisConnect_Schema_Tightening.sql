-- BrisConnect schema tightening patch
-- Goal: remove duplicate status semantics, tighten foreign keys, and connect admin <-> affiliation
-- Target: MySQL 8+

USE brisconnect;

-- 1) Add affiliation model and admin-affiliation mapping
CREATE TABLE IF NOT EXISTS affiliations (
  id VARCHAR(64) PRIMARY KEY,
  name VARCHAR(180) NOT NULL,
  type ENUM('business','community','government','other') NOT NULL DEFAULT 'business',
  suburb VARCHAR(120) NULL,
  status ENUM('active','inactive') NOT NULL DEFAULT 'active',
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  UNIQUE KEY uq_affiliations_name (name)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS admin_affiliations (
  admin_email VARCHAR(255) NOT NULL,
  affiliation_id VARCHAR(64) NOT NULL,
  access_scope ENUM('global','affiliation_only') NOT NULL DEFAULT 'affiliation_only',
  assigned_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  assigned_by_admin_email VARCHAR(255) NULL,
  PRIMARY KEY (admin_email, affiliation_id),
  CONSTRAINT fk_admin_affiliations_admin
    FOREIGN KEY (admin_email) REFERENCES admins(email)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_admin_affiliations_affiliation
    FOREIGN KEY (affiliation_id) REFERENCES affiliations(id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_admin_affiliations_assigned_by
    FOREIGN KEY (assigned_by_admin_email) REFERENCES admins(email)
    ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB;

ALTER TABLE local_users
  ADD COLUMN IF NOT EXISTS affiliation_id VARCHAR(64) NULL,
  ADD KEY idx_local_users_affiliation (affiliation_id),
  ADD CONSTRAINT fk_local_users_affiliation
    FOREIGN KEY (affiliation_id) REFERENCES affiliations(id)
    ON DELETE SET NULL ON UPDATE CASCADE;

-- 2) Normalize moderation status fields (remove overlapping approval/review flags)
-- Current overlap in events/attractions: approval_status + review_status + status + is_approved
-- New source of truth: moderation_status
ALTER TABLE events
  ADD COLUMN IF NOT EXISTS moderation_status
    ENUM('draft','pending_review','approved','rejected','archived')
    NOT NULL DEFAULT 'pending_review',
  ADD KEY idx_events_moderation_status (moderation_status);

UPDATE events
SET moderation_status =
  CASE
    WHEN COALESCE(is_approved, 0) = 1 THEN 'approved'
    WHEN LOWER(COALESCE(approval_status, '')) = 'approved' THEN 'approved'
    WHEN LOWER(COALESCE(approval_status, '')) = 'rejected' THEN 'rejected'
    WHEN LOWER(COALESCE(review_status, '')) IN ('pending','pending_review','under_review') THEN 'pending_review'
    WHEN LOWER(COALESCE(status, '')) = 'archived' THEN 'archived'
    ELSE 'pending_review'
  END;

ALTER TABLE attractions
  ADD COLUMN IF NOT EXISTS moderation_status
    ENUM('draft','pending_review','approved','rejected','archived')
    NOT NULL DEFAULT 'pending_review',
  ADD KEY idx_attractions_moderation_status (moderation_status);

UPDATE attractions
SET moderation_status =
  CASE
    WHEN COALESCE(is_approved, 0) = 1 THEN 'approved'
    WHEN LOWER(COALESCE(approval_status, '')) = 'approved' THEN 'approved'
    WHEN LOWER(COALESCE(approval_status, '')) = 'rejected' THEN 'rejected'
    WHEN LOWER(COALESCE(review_status, '')) IN ('pending','pending_review','under_review') THEN 'pending_review'
    WHEN LOWER(COALESCE(status, '')) = 'archived' THEN 'archived'
    ELSE 'pending_review'
  END;

-- Optional cleanup after data migration verification:
-- ALTER TABLE events DROP COLUMN approval_status, DROP COLUMN review_status, DROP COLUMN status, DROP COLUMN is_approved;
-- ALTER TABLE attractions DROP COLUMN approval_status, DROP COLUMN review_status, DROP COLUMN status, DROP COLUMN is_approved;

-- 3) Tighten notification ownership (remove polymorphic user reference)
ALTER TABLE user_notifications
  ADD COLUMN IF NOT EXISTS visitor_email VARCHAR(255) NULL,
  ADD COLUMN IF NOT EXISTS local_email VARCHAR(255) NULL,
  ADD CONSTRAINT fk_user_notifications_visitor
    FOREIGN KEY (visitor_email) REFERENCES visitor_users(email)
    ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT fk_user_notifications_local
    FOREIGN KEY (local_email) REFERENCES local_users(email)
    ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT ck_user_notifications_exactly_one_owner
    CHECK (
      (visitor_email IS NOT NULL AND local_email IS NULL) OR
      (visitor_email IS NULL AND local_email IS NOT NULL)
    );

-- Backfill owner columns from legacy user_email + user_type
UPDATE user_notifications
SET visitor_email = CASE WHEN user_type = 'visitor' THEN user_email ELSE NULL END,
    local_email = CASE WHEN user_type = 'local' THEN user_email ELSE NULL END;

-- Optional cleanup after app code cutover:
-- ALTER TABLE user_notifications DROP COLUMN user_email, DROP COLUMN user_type;

-- 4) Prevent duplicate attraction name/title ambiguity
ALTER TABLE attractions
  ADD COLUMN IF NOT EXISTS display_title VARCHAR(255) NULL;

UPDATE attractions
SET display_title = COALESCE(NULLIF(TRIM(title), ''), NULLIF(TRIM(name), ''), 'Untitled Attraction')
WHERE display_title IS NULL;

-- Optional cleanup after code cutover:
-- ALTER TABLE attractions DROP COLUMN title, DROP COLUMN name;
-- ALTER TABLE attractions CHANGE display_title name VARCHAR(255) NOT NULL;
