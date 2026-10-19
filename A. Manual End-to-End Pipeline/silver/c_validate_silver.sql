
/*
Purpose:
    Validate record counts, uniqueness, and data lineage
    between the Bronze and Silver layers.

Source: bronze.exercise_entries
Target: silver.exercise_entries
*/

-- 1. Record Count Validation
-- Compare total records between Bronze and Silver.
-- Expected: Both layers contain 532 records.

SELECT
    'Bronze' AS layer,
    COUNT(*) AS total_records
FROM bronze.exercise_entries

UNION ALL

SELECT
    'Silver' AS layer,
    COUNT(*) AS total_records
FROM silver.exercise_entries;


-- 2. Duplicate Record Validation
-- Identify duplicate bronze_id values in Silver.
-- Expected: Zero rows returned.

SELECT
    bronze_id,
    COUNT(*) AS occurrence_count
FROM silver.exercise_entries
GROUP BY bronze_id
HAVING COUNT(*) > 1;


-- 3. Data Lineage Validation
-- Identify Bronze records missing from Silver.
-- Expected: Zero rows returned.

SELECT
    b.bronze_id
FROM bronze.exercise_entries AS b
LEFT JOIN silver.exercise_entries AS s
    ON b.bronze_id = s.bronze_id
WHERE s.bronze_id IS NULL;


-- 4. Weight Conversion Validation
-- Identify nonempty Bronze weights that became NULL in Silver.
-- Expected: Zero rows if all nonempty weights converted successfully.

SELECT
    b.bronze_id,
    b.set_1_weight AS bronze_weight,
    s.set_1_weight AS silver_weight
FROM bronze.exercise_entries AS b
JOIN silver.exercise_entries AS s
    ON b.bronze_id = s.bronze_id
WHERE NULLIF(TRIM(b.set_1_weight), '') IS NOT NULL
  AND s.set_1_weight IS NULL;


-- 5. Numeric Conversion Validation
-- Detect missing or incorrect conversions across all three sets.
-- Expected: Zero rows.

SELECT
    b.bronze_id,
    v.column_name,
    v.bronze_value,
    v.silver_value
FROM bronze.exercise_entries AS b
JOIN silver.exercise_entries AS s
    ON b.bronze_id = s.bronze_id
CROSS APPLY (VALUES
    ('set_1_weight', b.set_1_weight,
        CONVERT(NVARCHAR(100), s.set_1_weight)),
    ('set_1_reps', b.set_1_reps,
        CONVERT(NVARCHAR(100), s.set_1_reps)),
    ('set_2_weight', b.set_2_weight,
        CONVERT(NVARCHAR(100), s.set_2_weight)),
    ('set_2_reps', b.set_2_reps,
        CONVERT(NVARCHAR(100), s.set_2_reps)),
    ('set_3_weight', b.set_3_weight,
        CONVERT(NVARCHAR(100), s.set_3_weight)),
    ('set_3_reps', b.set_3_reps,
        CONVERT(NVARCHAR(100), s.set_3_reps))
) AS v(column_name, bronze_value, silver_value)
WHERE NULLIF(TRIM(v.bronze_value), '') IS NOT NULL
  AND v.silver_value IS NULL;


-- 6. Numeric Accuracy Validation
-- Compare converted Bronze values against Silver values.
-- Expected: Zero rows.

SELECT
    b.bronze_id,
    b.set_1_weight AS bronze_weight,
    s.set_1_weight AS silver_weight
FROM bronze.exercise_entries AS b
JOIN silver.exercise_entries AS s
    ON b.bronze_id = s.bronze_id
WHERE TRY_CONVERT(
          DECIMAL(6,2),
          NULLIF(TRIM(b.set_1_weight), '')
      ) <> s.set_1_weight;


-- 7. Complete Numeric Accuracy Validation
-- Compare all six numeric fields between Bronze and Silver.
-- Expected: Zero rows.

SELECT
    b.bronze_id
FROM bronze.exercise_entries AS b
JOIN silver.exercise_entries AS s
    ON b.bronze_id = s.bronze_id
WHERE
    EXISTS (
        SELECT
            TRY_CONVERT(DECIMAL(6,2), NULLIF(TRIM(b.set_1_weight), '')),
            TRY_CONVERT(INT, NULLIF(TRIM(b.set_1_reps), '')),
            TRY_CONVERT(DECIMAL(6,2), NULLIF(TRIM(b.set_2_weight), '')),
            TRY_CONVERT(INT, NULLIF(TRIM(b.set_2_reps), '')),
            TRY_CONVERT(DECIMAL(6,2), NULLIF(TRIM(b.set_3_weight), '')),
            TRY_CONVERT(INT, NULLIF(TRIM(b.set_3_reps), ''))

        EXCEPT

        SELECT
            s.set_1_weight,
            s.set_1_reps,
            s.set_2_weight,
            s.set_2_reps,
            s.set_3_weight,
            s.set_3_reps
    );


-- 8. Date Conversion Validation
-- Compare Bronze timestamps with Silver timestamps.
-- Expected: Zero rows.

SELECT
    b.bronze_id,
    b.today AS bronze_date,
    s.today AS silver_date
FROM bronze.exercise_entries AS b
JOIN silver.exercise_entries AS s
    ON b.bronze_id = s.bronze_id
WHERE EXISTS (
    SELECT TRY_CONVERT(DATETIME2(3), b.today)
    EXCEPT
    SELECT s.today
);


-- 9. NOTION LINK CLEANING VALIDATION
-- Verify Silver exercise and workout names match
-- the expected cleaned Bronze values.
-- Expected: Zero rows.

WITH cleaned_names AS (
    SELECT
        bronze_id,

        CASE
            WHEN CHARINDEX(' (https://', exercise) > 0
            THEN TRIM(
                LEFT(
                    exercise,
                    CHARINDEX(' (https://', exercise) - 1
                )
            )
            ELSE TRIM(exercise)
        END AS expected_exercise,

        CASE
            WHEN CHARINDEX(' (https://', workout_log) > 0
            THEN TRIM(
                LEFT(
                    workout_log,
                    CHARINDEX(' (https://', workout_log) - 1
                )
            )
            ELSE TRIM(workout_log)
        END AS expected_workout_log

    FROM bronze.exercise_entries
)
SELECT
    c.bronze_id,
    c.expected_exercise,
    s.exercise AS silver_exercise,
    c.expected_workout_log,
    s.workout_log AS silver_workout_log
FROM cleaned_names AS c
JOIN silver.exercise_entries AS s
    ON c.bronze_id = s.bronze_id
WHERE EXISTS (
    SELECT
        c.expected_exercise,
        c.expected_workout_log
    EXCEPT
    SELECT
        s.exercise,
        s.workout_log
);


-- 10A. MISSING REQUIRED VALUES
-- Identify missing workout dates, exercise names,
-- or workout names.
-- Review returned rows before deciding whether to reject them.

SELECT
    silver_id,
    bronze_id,
    today,
    workout_log,
    exercise
FROM silver.exercise_entries
WHERE today IS NULL
   OR NULLIF(TRIM(exercise), '') IS NULL
   OR NULLIF(TRIM(workout_log), '') IS NULL;

-- Investigate incomplete Silver records.
-- Determine whether missing values originated in Bronze.

SELECT
    b.bronze_id,
    b.workout_log AS bronze_workout,
    b.exercise AS bronze_exercise,
    s.workout_log AS silver_workout,
    s.exercise AS silver_exercise
FROM bronze.exercise_entries AS b
JOIN silver.exercise_entries AS s
    ON b.bronze_id = s.bronze_id
WHERE b.bronze_id IN (321, 334, 335)
ORDER BY b.bronze_id;


-- 10B. INVALID SOURCE DATES
-- Identify nonempty Bronze dates that cannot be converted.
-- Expected: Zero rows.

SELECT
    bronze_id,
    today AS original_date
FROM bronze.exercise_entries
WHERE NULLIF(TRIM(today), '') IS NOT NULL
  AND TRY_CONVERT(DATETIME2(3), today) IS NULL;


-- 10C. NEGATIVE WEIGHTS OR REPETITIONS
-- Identify negative workout measurements.
-- Expected: Zero rows.

SELECT
    silver_id,
    bronze_id,
    set_1_weight,
    set_1_reps,
    set_2_weight,
    set_2_reps,
    set_3_weight,
    set_3_reps
FROM silver.exercise_entries
WHERE set_1_weight < 0
   OR set_1_reps < 0
   OR set_2_weight < 0
   OR set_2_reps < 0
   OR set_3_weight < 0
   OR set_3_reps < 0;


-- 11. IDEMPOTENCY VALIDATION
-- Run b_bronze_to_silver_transformation.sql again FIRST.
-- Then execute the following checks.
--
-- Expected:
--     Silver record count remains 532.
--     Zero duplicate bronze_id values.


-- 11A. Check record count after rerunning transformation.

SELECT
    COUNT(*) AS silver_record_count
FROM silver.exercise_entries;


-- 11B. Check duplicates after rerunning transformation.

SELECT
    bronze_id,
    COUNT(*) AS occurrence_count
FROM silver.exercise_entries
GROUP BY bronze_id
HAVING COUNT(*) > 1;