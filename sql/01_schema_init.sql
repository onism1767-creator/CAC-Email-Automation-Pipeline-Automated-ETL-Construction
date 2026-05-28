-- ============================================================
-- 01_schema_init.sql
-- Database Schema: Auto Dealer Marketing Pipeline
-- PostgreSQL 15+
-- ============================================================

-- Clean slate
DROP TABLE IF EXISTS email_events;
DROP TABLE IF EXISTS mailchimp_sync;
DROP TABLE IF EXISTS audience;
DROP TABLE IF EXISTS inventory;

-- ============================================================
-- Table 1: audience — Qualified contacts for email marketing
-- ============================================================
CREATE TABLE audience (
    member_id     TEXT PRIMARY KEY,          -- LinkedIn unique ID (dedup key)
    email         TEXT NOT NULL,             -- → Mailchimp EMAIL merge field
    first_name    TEXT NOT NULL,             -- → Mailchimp FNAME merge field
    last_name     TEXT,                      -- → Mailchimp LNAME merge field
    full_name     TEXT,                      -- Display name
    location_raw  TEXT,                      -- Original LinkedIn location string
    is_chinese    INTEGER DEFAULT 0,         -- 1 = Chinese-speaking (AI-detected)
    location_tag  TEXT,                      -- Assigned dealership tag (e.g., "CAC-Dallas")
    std_location  TEXT,                      -- Standardized city name → Mailchimp STD_LOC
    profile_url   TEXT,                      -- → Mailchimp LK_URL merge field
    ab_group      CHAR(1),                   -- A/B test group assignment
    ingested_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_audience_tag ON audience(location_tag);
CREATE INDEX idx_audience_chinese ON audience(is_chinese) WHERE is_chinese = 1;
CREATE INDEX idx_audience_email ON audience(email) WHERE email IS NOT NULL;

-- ============================================================
-- Table 2: inventory — Weekly vehicle stock data
-- ============================================================
CREATE TABLE inventory (
    car_id         TEXT PRIMARY KEY,         -- Vehicle unique identifier
    year           INTEGER,                  -- Manufacturing year
    make           TEXT,                     -- Brand (e.g., "Lexus")
    model          TEXT,                     -- Model name
    trim           TEXT,                     -- Trim level / package
    mileage        INTEGER,                  -- Odometer reading (miles)
    price          DECIMAL(10,2),            -- Listed sale price
    photo_url      TEXT,                     -- Primary photo URL
    product_url    TEXT,                     -- Detail page link
    shop_location  TEXT NOT NULL,            -- Normalized location tag
    scraped_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_inventory_shop ON inventory(shop_location);
CREATE INDEX idx_inventory_price ON inventory(price);

-- ============================================================
-- Table 3: mailchimp_sync — Track which contacts are synced
-- ============================================================
CREATE TABLE mailchimp_sync (
    member_id      TEXT PRIMARY KEY,
    mc_member_id   TEXT,                     -- Mailchimp-assigned ID
    synced_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    journey_status TEXT                      -- 'onboarding_sent', 'weekly_active', etc.
);

-- ============================================================
-- Table 4: email_events — Email performance tracking
-- ============================================================
CREATE TABLE email_events (
    event_id    TEXT PRIMARY KEY,
    member_id   TEXT REFERENCES audience(member_id),
    campaign_id TEXT,
    event_type  TEXT,                        -- 'sent'|'delivered'|'open'|'click'|'unsub'
    event_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_events_member ON email_events(member_id);
CREATE INDEX idx_events_type ON email_events(event_type);
