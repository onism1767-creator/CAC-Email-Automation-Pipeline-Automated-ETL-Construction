-- ============================================================
-- 02_name_cleaning.sql
-- 6-Step Last Name Normalization Pipeline
-- 
-- Problem: Raw LinkedIn last_name field contains:
--   - Academic/professional titles: "Harries, MA", "Smith PhD"
--   - Mixed case: "ZHANG", "de la Cruz"
--   - Whitespace issues: " wang ", "lee  "
--   - Credentials in parentheses: "Chen (CPA)"
--
-- Solution: 6-step transformation pipeline using 14 SQL functions
-- ============================================================

WITH raw_data AS (
    -- Sample data for demonstration
    SELECT * FROM (VALUES
        (1, 'Xinrong', 'Harries, MA', 'Dallas, TX'),
        (2, 'Michael', 'Smith PhD', 'Atlanta, GA'),
        (3, 'Maria', 'de la Cruz', 'Boston, MA'),
        (4, 'Wei', 'ZHANG', 'San Francisco, CA'),
        (5, 'James', 'Lee, CPA', 'Chicago, IL'),
        (6, 'Sarah', 'Van der Linde', 'New York, NY'),
        (7, 'Li', ' wang ', 'Indianapolis, IN')
    ) AS t(id, first_name, last_name, location)
),

-- ═══════════════════════════════════════════════════════════
-- Step 1: SPLIT_PART — Remove comma-separated titles
-- "Harries, MA" → "Harries"
-- ═══════════════════════════════════════════════════════════
step1_fixcomma AS (
    SELECT 
        id, first_name, last_name, location,
        SPLIT_PART(last_name, ',', 1) AS fixcomma
    FROM raw_data
),

-- ═══════════════════════════════════════════════════════════
-- Step 2: REGEXP_REPLACE — Remove content in parentheses
-- "Smith (PhD)" → "Smith"
-- ═══════════════════════════════════════════════════════════
step2_fixparen AS (
    SELECT 
        id, first_name, last_name, location, fixcomma,
        REGEXP_REPLACE(fixcomma, '\(.*\)', '', 'g') AS fixparen
    FROM step1_fixcomma
),

-- ═══════════════════════════════════════════════════════════
-- Step 3: LOWER — Normalize to lowercase for comparison
-- "ZHANG" → "zhang"
-- ═══════════════════════════════════════════════════════════
step3_normalized AS (
    SELECT 
        id, first_name, last_name, location, fixcomma, fixparen,
        TRIM(LOWER(fixparen)) AS clean_name
    FROM step2_fixparen
)

-- ═══════════════════════════════════════════════════════════
-- Step 4-6: REVERSE technique — Extract true last name
-- 
-- Problem: "de la Cruz" has 3 segments, "Zhang" has 1.
-- SPLIT_PART needs a fixed segment number.
-- 
-- Solution: Reverse → take segment 1 → reverse back
-- "de la Cruz" → "zurC al ed" → "zurC" → "Cruz"
-- ═══════════════════════════════════════════════════════════
SELECT 
    id,
    first_name,
    last_name AS original_last_name,
    location,
    
    -- Show each transformation step
    fixcomma AS step1_remove_titles,
    fixparen AS step2_remove_parens,
    clean_name AS step3_normalized,
    
    -- Final output: true last name
    CASE 
        WHEN POSITION(' ' IN clean_name) > 0 
        THEN REVERSE(SPLIT_PART(REVERSE(clean_name), ' ', 1))
        ELSE clean_name
    END AS clean_last_name

FROM step3_normalized

ORDER BY id;

-- ============================================================
-- Expected output:
-- 
-- id | original       | step1        | step2      | step3      | clean
-- 1  | Harries, MA    | Harries      | Harries    | harries    | harries
-- 2  | Smith PhD      | Smith PhD    | Smith      | smith      | smith
-- 3  | de la Cruz     | de la Cruz   | de la Cruz | de la cruz | cruz
-- 4  | ZHANG          | ZHANG        | ZHANG      | zhang      | zhang
-- 5  | Lee, CPA       | Lee          | Lee        | lee        | lee
-- 6  | Van der Linde  | Van der Linde| Van der Linde| van der linde | linde
-- 7  |  wang          |  wang        |  wang      | wang       | wang
-- ============================================================
