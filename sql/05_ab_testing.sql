-- ============================================================
-- 05_ab_testing.sql
-- Randomized A/B Test Group Assignment
--
-- Uses ROW_NUMBER() to assign sequential IDs, 
-- then modulo 2 to split into equal groups.
-- ============================================================

-- ═══════════════════════════════════════════════════════════
-- Version 1: Simple 50/50 split
-- ═══════════════════════════════════════════════════════════
SELECT 
    member_id,
    first_name,
    email,
    location_tag,
    
    ROW_NUMBER() OVER () AS row_num,
    
    -- Even rows → Group A, Odd rows → Group B
    CASE 
        WHEN ROW_NUMBER() OVER () % 2 = 0 THEN 'A'
        ELSE 'B'
    END AS ab_group

FROM audience
WHERE location_tag = 'Dallas-Fort Worth Metroplex'
ORDER BY member_id;

-- ═══════════════════════════════════════════════════════════
-- Version 2: Stratified A/B — Split within each location
-- Ensures each location has balanced A/B groups
-- ═══════════════════════════════════════════════════════════
SELECT 
    member_id,
    first_name,
    email,
    location_tag,
    
    -- PARTITION BY location_tag ensures equal split per region
    CASE 
        WHEN ROW_NUMBER() OVER (
            PARTITION BY location_tag 
            ORDER BY member_id
        ) % 2 = 0 THEN 'A'
        ELSE 'B'
    END AS ab_group

FROM audience
WHERE location_tag IS NOT NULL
ORDER BY location_tag, member_id;

-- ═══════════════════════════════════════════════════════════
-- Version 3: Function wrapper — reusable for any region
-- ═══════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION assign_ab_groups(region_name TEXT)
RETURNS TABLE(
    member_id TEXT, first_name TEXT, email TEXT,
    location_tag TEXT, ab_group TEXT
)
LANGUAGE SQL
AS $$
    SELECT 
        a.member_id, a.first_name, a.email, a.location_tag,
        CASE 
            WHEN ROW_NUMBER() OVER (
                PARTITION BY a.location_tag 
                ORDER BY a.member_id
            ) % 2 = 0 THEN 'A'
            ELSE 'B'
        END AS ab_group
    FROM audience a
    WHERE a.location_tag = region_name;
$$;

-- Usage: SELECT * FROM assign_ab_groups('Dallas-Fort Worth Metroplex');
