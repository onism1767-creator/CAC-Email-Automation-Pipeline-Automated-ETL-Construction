-- ============================================================
-- 07_dashboard_queries.sql
-- Analytics queries powering the Operator Dashboard
-- These feed the 5 KPI cards + funnel + tables
-- ============================================================

-- ═══════════════════════════════════════════════════════════
-- KPI 1: Total T1 Data Ingested
-- ═══════════════════════════════════════════════════════════
SELECT COUNT(*) AS t1_ingested FROM audience;

-- ═══════════════════════════════════════════════════════════
-- KPI 2: Qualified Contacts (meets all 4 filter criteria)
-- ═══════════════════════════════════════════════════════════
SELECT COUNT(*) AS qualified
FROM audience
WHERE email IS NOT NULL
  AND first_name IS NOT NULL
  AND is_chinese = 1
  AND location_tag IS NOT NULL;

-- ═══════════════════════════════════════════════════════════
-- KPI 3: Active in Flow (synced to Mailchimp)
-- ═══════════════════════════════════════════════════════════
SELECT COUNT(*) AS active_in_flow
FROM mailchimp_sync
WHERE journey_status IN ('onboarding_sent', 'weekly_active');

-- ═══════════════════════════════════════════════════════════
-- KPI 4: Average Open Rate (Onboarding)
-- ═══════════════════════════════════════════════════════════
SELECT 
    ROUND(
        100.0 * COUNT(CASE WHEN event_type = 'open' THEN 1 END) 
        / NULLIF(COUNT(CASE WHEN event_type = 'delivered' THEN 1 END), 0), 
        1
    ) AS onboarding_open_rate
FROM email_events
WHERE campaign_id LIKE 'onboarding%';

-- ═══════════════════════════════════════════════════════════
-- KPI 5: Average Click-Through Rate (Weekly)
-- ═══════════════════════════════════════════════════════════
SELECT 
    ROUND(
        100.0 * COUNT(CASE WHEN event_type = 'click' THEN 1 END) 
        / NULLIF(COUNT(CASE WHEN event_type = 'delivered' THEN 1 END), 0), 
        1
    ) AS weekly_ctr
FROM email_events
WHERE campaign_id LIKE 'weekly%';

-- ═══════════════════════════════════════════════════════════
-- Pipeline Funnel
-- ═══════════════════════════════════════════════════════════
SELECT 
    '01 T1 Ingested'  AS stage, COUNT(*) AS count FROM audience
UNION ALL
SELECT 
    '02 Tagged', COUNT(*) FROM audience 
    WHERE location_tag IS NOT NULL
UNION ALL
SELECT 
    '03 Qualified', COUNT(*) FROM audience 
    WHERE is_chinese = 1 AND email IS NOT NULL 
      AND first_name IS NOT NULL AND location_tag IS NOT NULL
UNION ALL
SELECT 
    '04 Entered Flow', COUNT(*) FROM mailchimp_sync
    WHERE journey_status IS NOT NULL;

-- ═══════════════════════════════════════════════════════════
-- Per-Location Breakdown
-- ═══════════════════════════════════════════════════════════
SELECT 
    location_tag,
    COUNT(*) AS qualified,
    COUNT(CASE WHEN ms.member_id IS NOT NULL THEN 1 END) AS in_flow,
    ROUND(AVG(CASE WHEN ee.event_type = 'open' THEN 1.0 ELSE 0 END) * 100, 1) AS open_rate,
    COUNT(DISTINCT inv.car_id) AS inventory_count
FROM audience a
LEFT JOIN mailchimp_sync ms ON a.member_id = ms.member_id
LEFT JOIN email_events ee ON a.member_id = ee.member_id
LEFT JOIN inventory inv ON a.location_tag = inv.shop_location
WHERE a.is_chinese = 1 
  AND a.location_tag IS NOT NULL
GROUP BY a.location_tag
ORDER BY qualified DESC;

-- ═══════════════════════════════════════════════════════════
-- Alert: Low Inventory Check
-- ═══════════════════════════════════════════════════════════
SELECT 
    shop_location,
    COUNT(*) AS car_count,
    CASE 
        WHEN COUNT(*) < 20 THEN 'CRITICAL'
        WHEN COUNT(*) < 50 THEN 'WARNING'
        ELSE 'OK'
    END AS alert_level
FROM inventory
GROUP BY shop_location
HAVING COUNT(*) < 50;

-- ═══════════════════════════════════════════════════════════
-- Alert: Low Engagement Check
-- ═══════════════════════════════════════════════════════════
SELECT 
    a.location_tag,
    ROUND(AVG(CASE WHEN ee.event_type = 'open' THEN 1.0 ELSE 0 END) * 100, 1) AS open_rate,
    CASE 
        WHEN AVG(CASE WHEN ee.event_type = 'open' THEN 1.0 ELSE 0 END) < 0.25 
        THEN 'WARNING: Below 25%'
        ELSE 'OK'
    END AS alert
FROM audience a
JOIN email_events ee ON a.member_id = ee.member_id
WHERE a.location_tag IS NOT NULL
GROUP BY a.location_tag;
