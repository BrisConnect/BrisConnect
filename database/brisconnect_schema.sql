-- ============================================================================
-- BrisConnect+ Full Database Schema (Firestore → PostgreSQL compatible SQL)
-- ============================================================================
-- This file maps every Firestore collection referenced in the BrisConnect
-- Flutter app and Cloud Functions into a normalized relational schema.
--
-- Conventions:
--   - Primary keys are UUID/SERIAL unless a Firestore doc ID is semantic
--     (e.g. admins.email, local_users.email).
--   - JSONB is used for flexible maps/history objects that Firestore stores
--     as nested maps (socialMedia, viewHistory, businessHours, etc.).
--   - TIMESTAMP WITH TIME ZONE is used for all date/time fields.
--   - Soft deletes use deleted_at / deleted_by columns.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. AUTH / USERS
-- ----------------------------------------------------------------------------

CREATE TABLE admins (
    email              VARCHAR(255) PRIMARY KEY,
    username           VARCHAR(255) NOT NULL,
    name               VARCHAR(255),
    role               VARCHAR(50)  NOT NULL DEFAULT 'admin',
    active             BOOLEAN      NOT NULL DEFAULT TRUE,
    profile_image_url  TEXT,
    last_login_at      TIMESTAMPTZ,
    updated_at         TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE local_users (
    email                       VARCHAR(255) PRIMARY KEY,
    username                    VARCHAR(255) NOT NULL,
    name                        VARCHAR(255) NOT NULL,
    phone                       VARCHAR(50),
    suburb                      VARCHAR(255),
    role                        VARCHAR(50)  NOT NULL DEFAULT 'local',
    account_type                VARCHAR(50)  NOT NULL DEFAULT 'local',
    approval_status             VARCHAR(50)  NOT NULL DEFAULT 'pending',
    password_hash               TEXT         NOT NULL,
    interested_event_ids        TEXT[]       DEFAULT '{}',
    interest_categories         TEXT[]       DEFAULT '{}',
    notifications_enabled       BOOLEAN      NOT NULL DEFAULT TRUE,
    event_reminders_enabled     BOOLEAN      NOT NULL DEFAULT TRUE,
    reminder_timing             VARCHAR(50)  NOT NULL DEFAULT '24h',
    event_updates_enabled       BOOLEAN      NOT NULL DEFAULT TRUE,
    nearby_events_enabled       BOOLEAN      NOT NULL DEFAULT TRUE,
    recommended_events_enabled  BOOLEAN      NOT NULL DEFAULT TRUE,
    use_current_location        BOOLEAN      NOT NULL DEFAULT TRUE,
    location_radius_km          INT          NOT NULL DEFAULT 20,
    location_access_enabled     BOOLEAN      NOT NULL DEFAULT TRUE,
    theme_preference            VARCHAR(50)  NOT NULL DEFAULT 'system',
    text_scale_factor           DECIMAL(3,2) NOT NULL DEFAULT 1.00,
    profile_image_base64        TEXT,
    profile_image_url           TEXT,
    profile_image_storage_path  TEXT,
    notify_trending_promotion   BOOLEAN      NOT NULL DEFAULT TRUE,
    notify_offer_expiry         BOOLEAN      NOT NULL DEFAULT TRUE,
    notify_new_review           BOOLEAN      NOT NULL DEFAULT TRUE,
    notify_business_updates     BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at                  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    password_updated_at         TIMESTAMPTZ,
    updated_at                  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE visitor_users (
    email                       VARCHAR(255) PRIMARY KEY,
    username                    VARCHAR(255) NOT NULL,
    name                        VARCHAR(255) NOT NULL,
    phone                       VARCHAR(50),
    role                        VARCHAR(50)  NOT NULL DEFAULT 'visitor',
    password_hash               TEXT         NOT NULL,
    interested_event_ids        TEXT[]       DEFAULT '{}',
    saved_attraction_ids        TEXT[]       DEFAULT '{}',
    saved_business_ids          TEXT[]       DEFAULT '{}',
    interest_categories         TEXT[]       DEFAULT '{}',
    interest_priorities         TEXT[]       DEFAULT '{}',
    notifications_enabled       BOOLEAN      NOT NULL DEFAULT TRUE,
    event_reminders_enabled     BOOLEAN      NOT NULL DEFAULT TRUE,
    reminder_timing             VARCHAR(50)  NOT NULL DEFAULT '24h',
    event_updates_enabled       BOOLEAN      NOT NULL DEFAULT TRUE,
    nearby_events_enabled       BOOLEAN      NOT NULL DEFAULT TRUE,
    recommended_events_enabled  BOOLEAN      NOT NULL DEFAULT TRUE,
    email_notifications_enabled BOOLEAN      NOT NULL DEFAULT TRUE,
    use_current_location        BOOLEAN      NOT NULL DEFAULT TRUE,
    location_radius_km          INT          NOT NULL DEFAULT 20,
    location_access_enabled     BOOLEAN      NOT NULL DEFAULT TRUE,
    theme_preference            VARCHAR(50)  NOT NULL DEFAULT 'system',
    text_scale_factor           DECIMAL(3,2) NOT NULL DEFAULT 1.00,
    language                    VARCHAR(10)  NOT NULL DEFAULT 'en',
    profile_image_base64        TEXT,
    profile_image_url           TEXT,
    profile_image_storage_path  TEXT,
    created_at                  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    password_updated_at         TIMESTAMPTZ,
    updated_at                  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- FCM push tokens (subcollection of local_users in Firestore)
CREATE TABLE local_user_fcm_tokens (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    local_user_email VARCHAR(255) NOT NULL REFERENCES local_users(email) ON DELETE CASCADE,
    token           TEXT         NOT NULL,
    platform        VARCHAR(50),
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE(local_user_email, token)
);

-- In-app notifications for business owners (subcollection of local_users)
CREATE TABLE local_user_notifications (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    local_user_email VARCHAR(255) NOT NULL REFERENCES local_users(email) ON DELETE CASCADE,
    title           VARCHAR(500) NOT NULL,
    body            TEXT,
    type            VARCHAR(100),
    read            BOOLEAN      NOT NULL DEFAULT FALSE,
    data            JSONB,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- ----------------------------------------------------------------------------
-- 2. BUSINESSES
-- ----------------------------------------------------------------------------

CREATE TABLE businesses (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id                VARCHAR(255) NOT NULL REFERENCES local_users(email) ON DELETE CASCADE,
    business_name           VARCHAR(500) NOT NULL,
    category                VARCHAR(255) NOT NULL,
    description             TEXT,
    address                 TEXT,
    lat                     DECIMAL(10, 8),
    lng                     DECIMAL(11, 8),
    contact_number          VARCHAR(100),
    website                 TEXT,
    social_media            JSONB,
    logo_url                TEXT,
    cover_image_url         TEXT,
    business_hours          JSONB,
    price_range             VARCHAR(50),
    audio_guide_url         TEXT,
    audio_guide_narration   TEXT,
    photos                  TEXT[],
    is_verified             BOOLEAN      NOT NULL DEFAULT FALSE,
    rating                  INT,
    average_rating          DECIMAL(3, 2),
    buzz_rating             DECIMAL(3, 2),
    buzz_score              DECIMAL(5, 2) NOT NULL DEFAULT 0.00,
    is_trending             BOOLEAN      NOT NULL DEFAULT FALSE,
    view_count              INT          NOT NULL DEFAULT 0,
    saved_count             INT          NOT NULL DEFAULT 0,
    review_count            INT          NOT NULL DEFAULT 0,
    view_history            JSONB        DEFAULT '{}',
    save_history            JSONB        DEFAULT '{}',
    is_active               BOOLEAN      NOT NULL DEFAULT TRUE,
    deleted_at              TIMESTAMPTZ,
    deleted_by              VARCHAR(255),
    duplicate_of            UUID         REFERENCES businesses(id),
    created_at              TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_businesses_owner ON businesses(owner_id);
CREATE INDEX idx_businesses_category ON businesses(category);
CREATE INDEX idx_businesses_active_deleted ON businesses(is_active, deleted_at);

CREATE TABLE business_menu_items (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id   UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    name          VARCHAR(500) NOT NULL,
    description   TEXT,
    price         DECIMAL(10, 2),
    image_url     TEXT,
    tags          TEXT[],
    sort_order    INT NOT NULL DEFAULT 0,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Soft-deleted business archive (mirrors businesses)
CREATE TABLE business_archive (
    id            UUID PRIMARY KEY,
    payload       JSONB NOT NULL,
    archived_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    archived_by   VARCHAR(255)
);

-- Admin verification audit log
CREATE TABLE business_verification_log (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id  UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    admin_email  VARCHAR(255) NOT NULL REFERENCES admins(email),
    action       VARCHAR(100) NOT NULL,
    reason       TEXT,
    verified_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Legacy seeded food/drink businesses (imported/demo data)
CREATE TABLE food_businesses (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name            VARCHAR(500) NOT NULL,
    description     TEXT,
    address         TEXT,
    phone           VARCHAR(100),
    website         TEXT,
    cuisine_types   TEXT[],
    image_url       TEXT,
    latitude        DECIMAL(10, 8),
    longitude       DECIMAL(11, 8),
    average_rating  DECIMAL(3, 2),
    review_count    INT DEFAULT 0,
    operating_hours TEXT,
    email           VARCHAR(255),
    facebook_url    TEXT,
    instagram_url   TEXT,
    online_order_url TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ----------------------------------------------------------------------------
-- 3. ATTRACTIONS & DISCOVER
-- ----------------------------------------------------------------------------

CREATE TABLE attractions (
    id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name                 VARCHAR(500) NOT NULL,
    title                VARCHAR(500),
    description          TEXT,
    location             TEXT,
    latitude             DECIMAL(10, 8),
    longitude            DECIMAL(11, 8),
    category             VARCHAR(255),
    accessibility_details TEXT,
    web_link             TEXT,
    image_url            TEXT,
    image_storage_path   TEXT,
    audio_url            TEXT,
    audio_storage_path   TEXT,
    approval_status      VARCHAR(50) NOT NULL DEFAULT 'pending',
    is_approved          BOOLEAN     NOT NULL DEFAULT FALSE,
    created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE attraction_details (
    attraction_id       UUID PRIMARY KEY REFERENCES attractions(id) ON DELETE CASCADE,
    history             TEXT,
    address             TEXT,
    opening_hours       TEXT,
    special_schedule    TEXT,
    entry_requirements  TEXT,
    ticket_price        VARCHAR(255),
    booking_label       VARCHAR(255),
    booking_url         TEXT,
    rating              DECIMAL(3, 2),
    review_count        INT DEFAULT 0,
    facilities          TEXT,
    amenities           TEXT,
    accessibility       TEXT,
    visit_duration      VARCHAR(255),
    best_time_to_visit  TEXT,
    live_update         TEXT,
    nearby_attractions  TEXT,
    nearby_services     TEXT,
    languages           TEXT,
    audio_features      TEXT
);

-- Approved attractions web view (denormalized)
CREATE TABLE approved_attractions (
    id          UUID PRIMARY KEY REFERENCES attractions(id),
    payload     JSONB NOT NULL,
    approved_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Denormalized discover catalog
CREATE TABLE discover_items (
    id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title              VARCHAR(500) NOT NULL,
    section            VARCHAR(100),
    category           VARCHAR(255),
    location           TEXT,
    venue              VARCHAR(500),
    suburb             VARCHAR(255),
    event_date         VARCHAR(50),
    event_time         VARCHAR(50),
    date_time          TIMESTAMPTZ,
    description        TEXT,
    approval_status    VARCHAR(50)  NOT NULL DEFAULT 'pending',
    source             VARCHAR(100),
    source_provider    VARCHAR(255),
    source_place_id    VARCHAR(255),
    source_url         TEXT,
    created_by_local_email VARCHAR(255) REFERENCES local_users(email),
    image_url          TEXT,
    audio_url          TEXT,
    video_url          TEXT,
    updated_at         TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_discover_items_section ON discover_items(section);
CREATE INDEX idx_discover_items_category ON discover_items(category);

-- ----------------------------------------------------------------------------
-- 4. EVENTS
-- ----------------------------------------------------------------------------

CREATE TABLE events (
    id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title                 VARCHAR(500) NOT NULL,
    event_date            VARCHAR(50),
    event_time            VARCHAR(50),
    date_time             TIMESTAMPTZ,
    category              VARCHAR(255),
    location              TEXT,
    venue                 VARCHAR(500),
    suburb                VARCHAR(255),
    description           TEXT,
    created_by_local_email VARCHAR(255) REFERENCES local_users(email),
    review_status         VARCHAR(50),
    approval_status       VARCHAR(50) NOT NULL DEFAULT 'pending',
    status                VARCHAR(50) NOT NULL DEFAULT 'pending',
    is_approved           BOOLEAN     NOT NULL DEFAULT FALSE,
    report_count          INT         NOT NULL DEFAULT 0,
    flagged_for_admin_review BOOLEAN  NOT NULL DEFAULT FALSE,
    source                VARCHAR(100),
    source_provider       VARCHAR(255),
    source_url            TEXT,
    latitude              DECIMAL(10, 8),
    longitude             DECIMAL(11, 8),
    created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_events_created_by ON events(created_by_local_email);
CREATE INDEX idx_events_status ON events(status);
CREATE INDEX idx_events_category ON events(category);

-- Many-to-many: locals and visitors interested in events
CREATE TABLE event_interests (
    event_id    UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    user_email  VARCHAR(255) NOT NULL,
    user_type   VARCHAR(50)  NOT NULL CHECK (user_type IN ('local', 'visitor')),
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    PRIMARY KEY (event_id, user_email, user_type)
);

-- ----------------------------------------------------------------------------
-- 5. BUSINESS EVENTS & PROMOTIONS
-- ----------------------------------------------------------------------------

CREATE TABLE business_events (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id       UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    owner_id          VARCHAR(255) NOT NULL REFERENCES local_users(email),
    owner_email       VARCHAR(255) NOT NULL,
    title             VARCHAR(500) NOT NULL,
    event_date        VARCHAR(50)  NOT NULL,
    event_time        VARCHAR(50)  NOT NULL,
    location          TEXT         NOT NULL,
    description       TEXT,
    image_url         TEXT,
    image_storage_path TEXT,
    status            VARCHAR(50)  NOT NULL DEFAULT 'published',
    created_at        TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at        TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_business_events_business ON business_events(business_id);
CREATE INDEX idx_business_events_status ON business_events(status);

CREATE TABLE promotions (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id   UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    owner_id      VARCHAR(255) NOT NULL REFERENCES local_users(email),
    title         VARCHAR(500) NOT NULL,
    description   TEXT,
    scheduled_at  TIMESTAMPTZ,
    end_at        TIMESTAMPTZ,
    end_date      DATE,
    is_active     BOOLEAN      NOT NULL DEFAULT FALSE,
    status        VARCHAR(50)  NOT NULL DEFAULT 'draft',
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_promotions_business ON promotions(business_id);
CREATE INDEX idx_promotions_owner ON promotions(owner_id);
CREATE INDEX idx_promotions_status ON promotions(status);

-- AI-generated posts (drafts and published)
CREATE TABLE ai_generated_posts (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id       UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    business_name     VARCHAR(500),
    owner_id          VARCHAR(255) NOT NULL REFERENCES local_users(email),
    post_type         VARCHAR(100) NOT NULL,
    title             VARCHAR(500) NOT NULL,
    description       TEXT,
    price             VARCHAR(255),
    discount          VARCHAR(255),
    event_date        TIMESTAMPTZ,
    location          TEXT,
    generated_content TEXT         NOT NULL,
    image_url         TEXT,
    status            VARCHAR(50)  NOT NULL DEFAULT 'draft',
    created_at        TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at        TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_ai_generated_posts_owner ON ai_generated_posts(owner_id);
CREATE INDEX idx_ai_generated_posts_status ON ai_generated_posts(status);

-- ----------------------------------------------------------------------------
-- 6. REVIEWS & RECOMMENDATIONS
-- ----------------------------------------------------------------------------

CREATE TABLE reviews (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id     UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    visitor_id      VARCHAR(255) NOT NULL,
    visitor_name    VARCHAR(500) NOT NULL DEFAULT 'Anonymous',
    visitor_photo_url TEXT,
    rating          INT          NOT NULL CHECK (rating BETWEEN 1 AND 5),
    buzz_rating     INT          NOT NULL DEFAULT 0 CHECK (buzz_rating BETWEEN 0 AND 5),
    comment         TEXT         NOT NULL,
    photos          TEXT[],
    helpful_count   INT          NOT NULL DEFAULT 0,
    visible         BOOLEAN      NOT NULL DEFAULT TRUE,
    is_reported     BOOLEAN      NOT NULL DEFAULT FALSE,
    report_reason   TEXT,
    reported_by     VARCHAR(255),
    severity        VARCHAR(50)  NOT NULL DEFAULT 'medium',
    is_flagged      BOOLEAN      NOT NULL DEFAULT FALSE,
    deleted_at      TIMESTAMPTZ,
    deleted_by      VARCHAR(255),
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_reviews_business ON reviews(business_id);
CREATE INDEX idx_reviews_visitor ON reviews(visitor_id);
CREATE INDEX idx_reviews_visible ON reviews(visible, deleted_at);

CREATE TABLE review_reports (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    review_id   UUID NOT NULL REFERENCES reviews(id) ON DELETE CASCADE,
    reporter_email VARCHAR(255) NOT NULL,
    reason      TEXT,
    comments    TEXT,
    status      VARCHAR(50) NOT NULL DEFAULT 'open',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    reviewed_at TIMESTAMPTZ
);

CREATE INDEX idx_review_reports_review ON review_reports(review_id);
CREATE INDEX idx_review_reports_status ON review_reports(status);

-- Nested reviews subcollection under businesses (legacy / dev)
CREATE TABLE business_nested_reviews (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    visitor_id  VARCHAR(255),
    comment     TEXT,
    rating      INT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ----------------------------------------------------------------------------
-- 7. SOCIAL & ENGAGEMENT
-- ----------------------------------------------------------------------------

CREATE TABLE social_shares (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    visitor_id     VARCHAR(255) NOT NULL,
    visitor_name   VARCHAR(500),
    business_id    UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    business_name  VARCHAR(500),
    content_id     VARCHAR(255) NOT NULL,
    content_type   VARCHAR(100) NOT NULL,
    platform       VARCHAR(100) NOT NULL,
    share_kind     VARCHAR(100) NOT NULL,
    title          VARCHAR(500) NOT NULL,
    description    TEXT,
    image_url      TEXT,
    share_url      TEXT,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_social_shares_business ON social_shares(business_id);
CREATE INDEX idx_social_shares_visitor ON social_shares(visitor_id);
CREATE INDEX idx_social_shares_created ON social_shares(created_at DESC);

CREATE TABLE post_engagements (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_type   VARCHAR(100) NOT NULL,
    post_id     VARCHAR(255) NOT NULL,
    action      VARCHAR(50)  NOT NULL CHECK (action IN ('like', 'save', 'buzzVote')),
    visitor_id  VARCHAR(255) NOT NULL,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE(post_type, post_id, action, visitor_id)
);

CREATE INDEX idx_post_engagements_post ON post_engagements(post_type, post_id);
CREATE INDEX idx_post_engagements_visitor ON post_engagements(visitor_id);

CREATE TABLE post_comments (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_type    VARCHAR(100) NOT NULL,
    post_id      VARCHAR(255) NOT NULL,
    visitor_id   VARCHAR(255) NOT NULL,
    visitor_name VARCHAR(500) NOT NULL,
    text         TEXT         NOT NULL,
    created_at   TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_post_comments_post ON post_comments(post_type, post_id);

CREATE TABLE audience_interactions (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id   UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    owner_id      VARCHAR(255) NOT NULL,
    visitor_hash  VARCHAR(255) NOT NULL,
    type          VARCHAR(100) NOT NULL,
    timestamp     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_audience_interactions_business ON audience_interactions(business_id);
CREATE INDEX idx_audience_interactions_owner ON audience_interactions(owner_id);

CREATE TABLE visitor_photos (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id   UUID REFERENCES businesses(id) ON DELETE CASCADE,
    event_id      UUID REFERENCES events(id) ON DELETE CASCADE,
    visitor_id    VARCHAR(255) NOT NULL,
    visitor_name  VARCHAR(500) NOT NULL DEFAULT 'Anonymous',
    image_url     TEXT         NOT NULL,
    storage_path  TEXT         NOT NULL,
    mime_type     VARCHAR(100) NOT NULL DEFAULT 'image/jpeg',
    file_size     INT          NOT NULL DEFAULT 0,
    caption       TEXT,
    status        VARCHAR(50)  NOT NULL DEFAULT 'pending',
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ
);

CREATE INDEX idx_visitor_photos_business ON visitor_photos(business_id);
CREATE INDEX idx_visitor_photos_event ON visitor_photos(event_id);

-- ----------------------------------------------------------------------------
-- 8. REPORTS & FEEDBACK
-- ----------------------------------------------------------------------------

CREATE TABLE event_reports (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id        UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    visitor_email   VARCHAR(255) NOT NULL,
    reason          TEXT         NOT NULL,
    comments        TEXT,
    status          VARCHAR(50)  NOT NULL DEFAULT 'open',
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    reviewed_at     TIMESTAMPTZ
);

CREATE INDEX idx_event_reports_event ON event_reports(event_id);
CREATE INDEX idx_event_reports_status ON event_reports(status);

CREATE TABLE app_feedback (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reference_id            VARCHAR(255) NOT NULL UNIQUE,
    reporter_role           VARCHAR(100) NOT NULL,
    reporter_email          VARCHAR(255) NOT NULL,
    reporter_name           VARCHAR(500),
    subject                 VARCHAR(500) NOT NULL,
    details                 TEXT         NOT NULL,
    category                VARCHAR(255),
    severity                VARCHAR(50),
    status                  VARCHAR(50) NOT NULL DEFAULT 'open',
    considered_for_fix      BOOLEAN      NOT NULL DEFAULT FALSE,
    maintenance_window_days INT,
    resolution_due_at       TIMESTAMPTZ,
    admin_reply_at          TIMESTAMPTZ,
    reply_read_by_reporter  BOOLEAN      NOT NULL DEFAULT FALSE,
    image_url               TEXT,
    image_storage_path      TEXT,
    created_at              TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_app_feedback_status ON app_feedback(status);
CREATE INDEX idx_app_feedback_reporter ON app_feedback(reporter_email);

CREATE TABLE moderation_audit_log (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_email  VARCHAR(255) NOT NULL REFERENCES admins(email),
    content_type VARCHAR(100) NOT NULL,
    content_id   VARCHAR(255) NOT NULL,
    decision     VARCHAR(255) NOT NULL,
    reason       TEXT,
    created_at   TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_moderation_audit_content ON moderation_audit_log(content_type, content_id);

CREATE TABLE crowd_reports (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id   UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    level      VARCHAR(100) NOT NULL,
    weight     INT          NOT NULL,
    timestamp  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_crowd_reports_event ON crowd_reports(event_id);

-- ----------------------------------------------------------------------------
-- 9. NOTIFICATIONS & MESSAGING QUEUES
-- ----------------------------------------------------------------------------

CREATE TABLE user_notifications (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_email      VARCHAR(255) NOT NULL,
    user_type       VARCHAR(50)  NOT NULL,
    event_id        UUID REFERENCES events(id) ON DELETE CASCADE,
    event_title     VARCHAR(500),
    event_date_time VARCHAR(255),
    event_location  TEXT,
    schedule_type   VARCHAR(100),
    is_read         BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_user_notifications_user ON user_notifications(user_email, user_type);
CREATE INDEX idx_user_notifications_read ON user_notifications(is_read);

CREATE TABLE mail_queue (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    recipient  VARCHAR(255) NOT NULL,
    subject    VARCHAR(500),
    body       TEXT,
    message    JSONB,
    meta       JSONB,
    status     VARCHAR(50) NOT NULL DEFAULT 'pending',
    sent_at    TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_mail_queue_status ON mail_queue(status);

CREATE TABLE sms_queue (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    recipient  VARCHAR(255) NOT NULL,
    body       TEXT,
    message    JSONB,
    meta       JSONB,
    status     VARCHAR(50) NOT NULL DEFAULT 'pending',
    sent_at    TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_sms_queue_status ON sms_queue(status);

CREATE TABLE notification_health_checks (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    check_type  VARCHAR(100) NOT NULL,
    result      JSONB NOT NULL,
    status      VARCHAR(50),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ----------------------------------------------------------------------------
-- 10. PAYMENTS & SUBSCRIPTIONS
-- ----------------------------------------------------------------------------

CREATE TABLE subscription_plans (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name            VARCHAR(500) NOT NULL,
    plan_type       VARCHAR(100) NOT NULL,
    description     TEXT,
    price_cents     INT          NOT NULL,
    duration_days   INT          NOT NULL,
    features        TEXT[],
    stripe_product_id VARCHAR(255),
    stripe_price_id   VARCHAR(255),
    is_active       BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_subscription_plans_active ON subscription_plans(is_active);

CREATE TABLE business_subscriptions (
    id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id             VARCHAR(255) NOT NULL REFERENCES local_users(email) ON DELETE CASCADE,
    stripe_subscription_id VARCHAR(255),
    status               VARCHAR(100) NOT NULL DEFAULT 'incomplete',
    current_period_start TIMESTAMPTZ,
    current_period_end   TIMESTAMPTZ,
    plan_id              UUID REFERENCES subscription_plans(id),
    cancel_at_period_end BOOLEAN NOT NULL DEFAULT FALSE,
    created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_business_subscriptions_owner ON business_subscriptions(owner_id);
CREATE INDEX idx_business_subscriptions_status ON business_subscriptions(status);

CREATE TABLE promotion_plans (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name            VARCHAR(500) NOT NULL,
    plan_type       VARCHAR(100) NOT NULL,
    description     TEXT,
    price_cents     INT          NOT NULL,
    duration_days   INT          NOT NULL,
    features        TEXT[],
    stripe_product_id VARCHAR(255),
    stripe_price_id   VARCHAR(255),
    is_active       BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE business_payments (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id          VARCHAR(255) NOT NULL REFERENCES local_users(email),
    type              VARCHAR(100) NOT NULL,
    status            VARCHAR(100) NOT NULL,
    amount_cents      INT,
    currency          VARCHAR(10)  NOT NULL DEFAULT 'aud',
    stripe_payment_intent_id VARCHAR(255),
    stripe_checkout_session_id VARCHAR(255),
    stripe_subscription_id VARCHAR(255),
    plan_id           UUID REFERENCES subscription_plans(id),
    promotion_plan_id UUID REFERENCES promotion_plans(id),
    paid_at           TIMESTAMPTZ,
    expires_at        TIMESTAMPTZ,
    payload           JSONB,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_business_payments_owner ON business_payments(owner_id);
CREATE INDEX idx_business_payments_status ON business_payments(status);
CREATE INDEX idx_business_payments_type ON business_payments(type);

CREATE TABLE admin_activity (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_email VARCHAR(255) NOT NULL REFERENCES admins(email),
    action      VARCHAR(255) NOT NULL,
    target_type VARCHAR(100),
    target_id   VARCHAR(255),
    details     JSONB,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_admin_activity_admin ON admin_activity(admin_email);

-- ----------------------------------------------------------------------------
-- 11. CURATED CONTENT
-- ----------------------------------------------------------------------------

CREATE TABLE brisbane_stories (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title         VARCHAR(500) NOT NULL,
    description   TEXT,
    image_url     TEXT,
    category      VARCHAR(255),
    content       TEXT,
    latitude      DECIMAL(10, 8),
    longitude     DECIMAL(11, 8),
    location_name VARCHAR(500),
    approval_status VARCHAR(50) NOT NULL DEFAULT 'pending',
    published_at  TIMESTAMPTZ,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_brisbane_stories_status ON brisbane_stories(approval_status);

CREATE TABLE brisbane_voices (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name             VARCHAR(500) NOT NULL,
    quote            TEXT         NOT NULL,
    profile_image_url TEXT,
    approval_status  VARCHAR(50)  NOT NULL DEFAULT 'pending',
    created_at       TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- ----------------------------------------------------------------------------
-- 12. SYSTEM / CONFIG
-- ----------------------------------------------------------------------------

CREATE TABLE config (
    id      VARCHAR(255) PRIMARY KEY,
    payload JSONB NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE event_categories (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name        VARCHAR(255) NOT NULL UNIQUE,
    label       VARCHAR(255),
    color       VARCHAR(50),
    icon        VARCHAR(100),
    sort_order  INT NOT NULL DEFAULT 0,
    is_active   BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE counters (
    id    VARCHAR(255) PRIMARY KEY,
    count BIGINT NOT NULL DEFAULT 0
);

CREATE TABLE seed_metadata (
    id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    version               INT NOT NULL,
    source_provider       VARCHAR(255),
    discover_item_count   INT DEFAULT 0,
    attraction_count      INT DEFAULT 0,
    event_count           INT DEFAULT 0,
    write_count           INT DEFAULT 0,
    seeded_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_synced_at        TIMESTAMPTZ
);

CREATE TABLE connectivity_probe (
    id      VARCHAR(255) PRIMARY KEY,
    payload JSONB,
    checked_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================================
-- END OF SCHEMA
-- ============================================================================
