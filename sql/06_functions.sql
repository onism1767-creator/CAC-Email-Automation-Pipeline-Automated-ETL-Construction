-- ============================================================
-- 06_functions.sql
-- PostgreSQL Functions + Dynamic SQL
-- 
-- Why functions? The pipeline needs to:
-- 1. Run the same logic weekly on new data batches
-- 2. Accept variable table names (weekly batches use dated names)
-- 3. Be callable from orchestration scripts
-- ============================================================

-- ═══════════════════════════════════════════════════════════
-- Function 1: Simple — Get last day of any month
-- Demonstrates basic FUNCTION structure
-- ═══════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION get_last_day_of_month(input_date DATE)
RETURNS DATE
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN (DATE_TRUNC('month', input_date) + INTERVAL '1 month' 
            - INTERVAL '1 day')::DATE;
END;
$$;

-- Example: SELECT get_last_day_of_month('2024-02-07'); → 2024-02-29

-- ═══════════════════════════════════════════════════════════
-- Function 2: Returns table — Get Chinese contacts after date
-- Accepts variable table name via Dynamic SQL
-- ═══════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION get_chinese_since(
    table_name TEXT,
    since_date DATE
)
RETURNS TABLE(
    member_id TEXT, first_name TEXT, last_name TEXT,
    email TEXT, location_raw TEXT, is_chinese INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    sql_text TEXT;
BEGIN
    -- Build SQL dynamically — table name is variable
    sql_text := 'SELECT member_id, first_name, last_name, email, 
                        location_raw, is_chinese 
                 FROM ' || quote_ident(table_name) || '
                 WHERE is_chinese = 1 
                   AND ingested_at > ''' || since_date || '''';
    
    RETURN QUERY EXECUTE sql_text;
END;
$$;

-- Usage: SELECT * FROM get_chinese_since('weekly_batch_2024_06', '2024-05-01');

-- ═══════════════════════════════════════════════════════════
-- Function 3: Full pipeline — Export qualified audience by region
-- Wraps M1+M3 logic into a single callable function
-- ═══════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION export_region_audience(region_name TEXT)
RETURNS TABLE(
    member_id TEXT, first_name TEXT, last_name TEXT,
    email TEXT, location_raw TEXT, location_tag TEXT, ab_group TEXT
)
LANGUAGE plpgsql
AS $$
BEGIN
    DROP TABLE IF EXISTS temp_region_export;
    
    CREATE TEMP TABLE temp_region_export AS
    SELECT 
        a.member_id, a.first_name, a.last_name,
        a.email, a.location_raw, a.location_tag,
        CASE 
            WHEN ROW_NUMBER() OVER (
                PARTITION BY a.location_tag 
                ORDER BY a.member_id
            ) % 2 = 0 THEN 'A'
            ELSE 'B'
        END AS ab_group
    FROM audience a
    WHERE a.location_tag = region_name
      AND a.is_chinese = 1
      AND a.email IS NOT NULL
      AND a.first_name IS NOT NULL;
    
    RETURN QUERY SELECT * FROM temp_region_export;
END;
$$;

-- Usage: SELECT * FROM export_region_audience('Dallas-Fort Worth Metroplex');
--        SELECT * FROM export_region_audience('Greater Boston');
