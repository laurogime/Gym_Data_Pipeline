-- ============================================================
-- M-003: Gold Exercise Progression Validation
-- Target: gold.exercise_progression
-- Environment: Local development
-- ============================================================
--
-- IMPORTANT:
-- Execute each validation section according to its instructions.
-- Do not execute the entire file as one script.
--
-- VAL-013: Unchanged-source idempotency
-- VAL-014: Transaction rollback and failure recovery
-- VAL-015: Source-change refresh (INCOMPLETE)
--
-- ============================================================


-- ============================================================
-- VAL-013: Gold Exercise Progression Idempotency
-- Status: PASSED in previous execution
-- ============================================================
--
-- Execution order:
-- 1. Execute SECTION A to capture the current Gold dataset.
-- 2. Execute b_build_exercise_progression.sql again.
-- 3. Execute SECTION B to compare before and after.
--
-- IMPORTANT:
-- Use the same SQL Server session for all three operations.
-- Do not recapture the snapshot after the Gold refresh.
-- Do not run Sections A and B consecutively without the build.
-- ============================================================


-- SECTION A: Capture Gold dataset BEFORE rerun

DROP TABLE IF EXISTS #gold_before_rerun;

SELECT
    workout_log,
    exercise,
    max_weight,
    max_weight_reps
INTO #gold_before_rerun
FROM gold.exercise_progression;

SELECT
    COUNT(*) AS before_count
FROM #gold_before_rerun;


-- STOP HERE.
-- Execute b_build_exercise_progression.sql in the same session
-- before running SECTION B.


-- SECTION B: Validate Gold dataset AFTER rerun

-- Check 01: Compare record counts

SELECT
    (SELECT COUNT(*)
     FROM #gold_before_rerun) AS before_count,

    (SELECT COUNT(*)
     FROM gold.exercise_progression) AS after_count;


-- Check 02: Verify grain uniqueness

SELECT
    workout_log,
    exercise,
    COUNT(*) AS record_count
FROM gold.exercise_progression
GROUP BY
    workout_log,
    exercise
HAVING COUNT(*) > 1;


-- Check 03: Compare before and after datasets
-- Expected: Zero discrepancies

SELECT
    'BEFORE_ONLY' AS discrepancy,
    d.workout_log,
    d.exercise,
    d.max_weight,
    d.max_weight_reps
FROM (
    SELECT
        workout_log,
        exercise,
        max_weight,
        max_weight_reps
    FROM #gold_before_rerun

    EXCEPT

    SELECT
        workout_log,
        exercise,
        max_weight,
        max_weight_reps
    FROM gold.exercise_progression
) AS d

UNION ALL

SELECT
    'AFTER_ONLY' AS discrepancy,
    d.workout_log,
    d.exercise,
    d.max_weight,
    d.max_weight_reps
FROM (
    SELECT
        workout_log,
        exercise,
        max_weight,
        max_weight_reps
    FROM gold.exercise_progression

    EXCEPT

    SELECT
        workout_log,
        exercise,
        max_weight,
        max_weight_reps
    FROM #gold_before_rerun
) AS d;


-- ============================================================
-- VAL-014: Transaction Rollback and Failure Recovery
-- Status: PASSED in previous execution
-- Environment: Local development only
-- ============================================================
--
-- Purpose:
-- Simulate a partial Gold refresh followed by a failure.
-- Verify that ROLLBACK restores the original committed data.
--
-- Execute the complete VAL-014 section together.
-- Do not execute DELETE or INSERT independently.
-- ============================================================


-- Step 1: Require no active transaction

IF @@TRANCOUNT <> 0
    THROW 51013,
          'Close existing transactions before VAL-014.', 1;

SET XACT_ABORT ON;


-- Step 2: Capture the original Gold dataset

DROP TABLE IF EXISTS #gold_before_failure;

SELECT
    workout_log,
    exercise,
    max_weight,
    max_weight_reps
INTO #gold_before_failure
FROM gold.exercise_progression;


-- Step 3: Simulate a partial refresh and intentional failure

BEGIN TRY
    BEGIN TRANSACTION;

    DELETE FROM gold.exercise_progression;

    INSERT INTO gold.exercise_progression (
        workout_log,
        exercise,
        max_weight,
        max_weight_reps
    )
    SELECT TOP (200)
        workout_log,
        exercise,
        max_weight,
        max_weight_reps
    FROM #gold_before_failure
    ORDER BY
        workout_log,
        exercise;

    -- Inspect the temporarily incomplete dataset

    SELECT
        COUNT(*) AS rows_before_failure
    FROM gold.exercise_progression;

    -- Deliberately trigger an error before COMMIT

    THROW 51014,
          'Intentional failure for VAL-014.', 1;

    COMMIT TRANSACTION;

END TRY
BEGIN CATCH

    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    SELECT
        ERROR_NUMBER() AS error_number,
        ERROR_MESSAGE() AS error_message;

END CATCH;


-- Step 4: Verify the original record count

SELECT
    (SELECT COUNT(*)
     FROM #gold_before_failure) AS before_count,

    (SELECT COUNT(*)
     FROM gold.exercise_progression) AS after_count;


-- Step 5: Verify the original records were preserved
-- Expected: Zero discrepancies

SELECT
    'BEFORE_ONLY' AS discrepancy,
    d.workout_log,
    d.exercise,
    d.max_weight,
    d.max_weight_reps
FROM (
    SELECT
        workout_log,
        exercise,
        max_weight,
        max_weight_reps
    FROM #gold_before_failure

    EXCEPT

    SELECT
        workout_log,
        exercise,
        max_weight,
        max_weight_reps
    FROM gold.exercise_progression
) AS d

UNION ALL

SELECT
    'AFTER_ONLY' AS discrepancy,
    d.workout_log,
    d.exercise,
    d.max_weight,
    d.max_weight_reps
FROM (
    SELECT
        workout_log,
        exercise,
        max_weight,
        max_weight_reps
    FROM gold.exercise_progression

    EXCEPT

    SELECT
        workout_log,
        exercise,
        max_weight,
        max_weight_reps
    FROM #gold_before_failure
) AS d;


-- ============================================================
-- VAL-015: Source-Change Refresh
-- Status: INCOMPLETE
-- ============================================================
--
-- Step 1: Test data preparation -- completed
-- Step 2: Temporary Silver update and rollback -- completed
-- Step 3: Gold refresh propagation -- not validated
--
-- Previous attempt stopped with error 51022:
-- "Gold baseline does not match."
--
-- Next action:
-- Investigate the actual Gold baseline before continuing.
--
-- NOTE:
-- The following queries prepare test data and verify that
-- a temporary Silver update can be rolled back.
-- They do NOT establish source-change refresh correctness.
-- Execute each step separately in the same SQL session.
-- ============================================================


-- STEP 1: Prepare snapshot and select test record

IF @@TRANCOUNT <> 0
    THROW 51015,
          'An active transaction already exists.', 1;

DROP TABLE IF EXISTS #gold_before_source_change;
DROP TABLE IF EXISTS #source_change_target;


-- Capture current Gold results

SELECT
    workout_log,
    exercise,
    max_weight,
    max_weight_reps
INTO #gold_before_source_change
FROM gold.exercise_progression;


-- Select a qualifying Silver record

SELECT TOP (1)
    s.bronze_id,
    s.workout_log,
    s.exercise,
    s.set_1_weight AS original_weight,
    s.set_1_reps AS original_reps,
    g.max_weight AS original_gold_max_weight,
    CAST(g.max_weight AS DECIMAL(18,2)) + 1
        AS proposed_weight
INTO #source_change_target
FROM silver.exercise_entries AS s
INNER JOIN gold.exercise_progression AS g
    ON s.workout_log = g.workout_log
   AND s.exercise = g.exercise
WHERE
    s.set_1_weight IS NOT NULL
    AND s.set_1_reps IS NOT NULL
ORDER BY
    s.bronze_id;


-- Verify that a suitable record exists

IF NOT EXISTS (
    SELECT 1
    FROM #source_change_target
)
    THROW 51016,
          'No suitable Silver test record found.', 1;


-- Inspect the proposed test change

SELECT
    bronze_id,
    workout_log,
    exercise,
    original_weight,
    original_reps,
    original_gold_max_weight,
    proposed_weight
FROM #source_change_target;


-- Confirm Gold baseline record count

SELECT
    COUNT(*) AS gold_before_count
FROM #gold_before_source_change;


-- STEP 2: Temporary Silver update and rollback
-- Execute only after STEP 1 completes successfully.
-- No permanent changes should remain after this step.

SET XACT_ABORT ON;

IF @@TRANCOUNT <> 0
    THROW 51018,
          'Close existing transactions before VAL-015 Step 2.', 1;

BEGIN TRY
    BEGIN TRANSACTION;

    UPDATE s
    SET
        s.set_1_weight = t.proposed_weight
    FROM silver.exercise_entries AS s
    INNER JOIN #source_change_target AS t
        ON s.bronze_id = t.bronze_id;

    IF @@ROWCOUNT <> 1
        THROW 51017,
              'Expected exactly one updated record.', 1;


    -- Inspect the temporary Silver change

    SELECT
        s.bronze_id,
        s.workout_log,
        s.exercise,
        s.set_1_weight,
        s.set_1_reps
    FROM silver.exercise_entries AS s
    INNER JOIN #source_change_target AS t
        ON s.bronze_id = t.bronze_id;


    -- Restore the original Silver data

    ROLLBACK TRANSACTION;


    -- Verify restoration

    SELECT
        s.bronze_id,
        s.set_1_weight AS restored_weight,
        t.original_weight,
        CASE
            WHEN s.set_1_weight = t.original_weight
                THEN 'PASS'
            ELSE 'FAIL'
        END AS restoration_status
    FROM silver.exercise_entries AS s
    INNER JOIN #source_change_target AS t
        ON s.bronze_id = t.bronze_id;

END TRY
BEGIN CATCH

    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;

END CATCH;


-- ============================================================
-- VAL-015: Source-Change Refresh Validation
-- M-003: Gold Exercise Progression
-- Status: PASSED - Controlled Test (2026-11-03)
-- Environment: Local development only
--
-- Source: silver.exercise_entries
-- Target: gold.exercise_progression
--
-- Purpose:
-- Verify that changes to qualifying Silver measurements
-- are reflected in the recalculated Gold dataset.
-- Confirm that weight and repetitions remain correctly
-- paired and that rollback restores the original data.
--
-- Test scenario:
-- Original Gold: 49.50 kg x 10 reps
-- Modified Silver Set 1: 50.50 kg x 8 reps
-- Expected recalculated Gold: 50.50 kg x 8 reps
--
-- Execution:
-- Run the complete test block in one SQL Server session.
-- Do not execute UPDATE, DELETE, or INSERT independently.
--
-- Limitation:
-- This test uses a copy of the M-003 transformation logic.
-- It does not directly execute the standalone Gold build file.
-- ============================================================

IF @@TRANCOUNT <> 0
    THROW 51020, 'An active transaction exists.', 1;

SET XACT_ABORT ON;

DROP TABLE IF EXISTS #val015_gold_before;
DROP TABLE IF EXISTS #val015_gold_next;


-- Step 1: Verify the actual baseline

IF NOT EXISTS (
    SELECT 1
    FROM silver.exercise_entries AS s
    INNER JOIN gold.exercise_progression AS g
        ON s.workout_log = g.workout_log
       AND s.exercise = g.exercise
    WHERE s.bronze_id = 1
      AND s.workout_log = 'Pull Day 1'
      AND s.exercise = 'Pull-up Bar'
      AND s.set_1_weight = 49.50
      AND s.set_1_reps = 8
      AND s.set_2_weight = 49.50
      AND s.set_2_reps = 10
      AND g.max_weight = 49.50
      AND g.max_weight_reps = 10
)
    THROW 51021, 'Baseline does not match.', 1;


-- Step 2: Capture the original Gold dataset

SELECT
    workout_log,
    exercise,
    max_weight,
    max_weight_reps
INTO #val015_gold_before
FROM gold.exercise_progression;


BEGIN TRY
    BEGIN TRANSACTION;

    -- Step 3: Temporarily modify Silver

    UPDATE silver.exercise_entries
    SET set_1_weight = 50.50
    WHERE bronze_id = 1
      AND set_1_weight = 49.50;

    IF @@ROWCOUNT <> 1
        THROW 51022, 'Expected one Silver update.', 1;


    -- Step 4: Recalculate Gold using M-003 logic

    ;WITH exercise_sets AS (
        SELECT
            e.bronze_id,
            e.workout_log,
            e.exercise,
            s.set_number,
            s.weight,
            s.reps
        FROM silver.exercise_entries AS e
        CROSS APPLY (
            VALUES
                (1, e.set_1_weight, e.set_1_reps),
                (2, e.set_2_weight, e.set_2_reps)
        ) AS s(set_number, weight, reps)
    ),

    eligible_sets AS (
        SELECT
            bronze_id,
            workout_log,
            exercise,
            set_number,
            weight,
            reps
        FROM exercise_sets
        WHERE workout_log IS NOT NULL
          AND exercise IS NOT NULL
          AND weight IS NOT NULL
          AND reps IS NOT NULL
    ),

    ranked_sets AS (
        SELECT
            bronze_id,
            workout_log,
            exercise,
            weight,
            reps,
            ROW_NUMBER() OVER (
                PARTITION BY workout_log, exercise
                ORDER BY
                    weight DESC,
                    reps DESC,
                    bronze_id ASC,
                    set_number ASC
            ) AS set_rank
        FROM eligible_sets
    )

    SELECT
        workout_log,
        exercise,
        weight AS max_weight,
        reps AS max_weight_reps
    INTO #val015_gold_next
    FROM ranked_sets
    WHERE set_rank = 1;


    -- Step 5: Reject an empty replacement

    IF NOT EXISTS (
        SELECT 1 FROM #val015_gold_next
    )
        THROW 51023, 'Replacement Gold is empty.', 1;


    -- Step 6: Temporarily refresh Gold

    DELETE FROM gold.exercise_progression;

    INSERT INTO gold.exercise_progression (
        workout_log,
        exercise,
        max_weight,
        max_weight_reps
    )
    SELECT
        workout_log,
        exercise,
        max_weight,
        max_weight_reps
    FROM #val015_gold_next;


    -- Step 7: Inspect changed Silver and Gold

    SELECT
        s.set_1_weight AS silver_test_weight,
        s.set_1_reps AS silver_test_reps,
        g.max_weight AS gold_test_weight,
        g.max_weight_reps AS gold_test_reps
    FROM silver.exercise_entries AS s
    INNER JOIN gold.exercise_progression AS g
        ON s.workout_log = g.workout_log
       AND s.exercise = g.exercise
    WHERE s.bronze_id = 1;


    -- Step 8: Assert correct source-change propagation

    IF NOT EXISTS (
        SELECT 1
        FROM gold.exercise_progression
        WHERE workout_log = 'Pull Day 1'
          AND exercise = 'Pull-up Bar'
          AND max_weight = 50.50
          AND max_weight_reps = 8
    )
        THROW 51024,
              'Gold did not reflect the Silver change.', 1;

    IF (
        SELECT COUNT(*)
        FROM gold.exercise_progression
    ) <> (
        SELECT COUNT(*)
        FROM #val015_gold_before
    )
        THROW 51025, 'Gold record count changed.', 1;


    -- Step 9: Restore Silver and Gold

    ROLLBACK TRANSACTION;

END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;


-- Step 10: Verify original values were restored

SELECT
    s.set_1_weight AS restored_silver_weight,
    s.set_1_reps AS restored_silver_reps,
    g.max_weight AS restored_gold_weight,
    g.max_weight_reps AS restored_gold_reps
FROM silver.exercise_entries AS s
INNER JOIN gold.exercise_progression AS g
    ON s.workout_log = g.workout_log
   AND s.exercise = g.exercise
WHERE s.bronze_id = 1;


-- Step 11: Verify full Gold dataset restoration

SELECT
    (SELECT COUNT(*) FROM #val015_gold_before)
        AS before_count,
    (SELECT COUNT(*) FROM gold.exercise_progression)
        AS after_count;


-- Step 12: Check for remaining discrepancies

SELECT
    'BEFORE_ONLY' AS discrepancy,
    d.workout_log,
    d.exercise,
    d.max_weight,
    d.max_weight_reps
FROM (
    SELECT
        workout_log, exercise, max_weight, max_weight_reps
    FROM #val015_gold_before

    EXCEPT

    SELECT
        workout_log, exercise, max_weight, max_weight_reps
    FROM gold.exercise_progression
) AS d

UNION ALL

SELECT
    'AFTER_ONLY' AS discrepancy,
    d.workout_log,
    d.exercise,
    d.max_weight,
    d.max_weight_reps
FROM (
    SELECT
        workout_log, exercise, max_weight, max_weight_reps
    FROM gold.exercise_progression

    EXCEPT

    SELECT
        workout_log, exercise, max_weight, max_weight_reps
    FROM #val015_gold_before
) AS d;

-- ============================================================
-- END OF M-003 VALIDATION FILE
--
-- Validation Summary:
-- VAL-013: PASSED - Unchanged-source idempotency
-- VAL-014: PASSED - Controlled transaction rollback
-- VAL-015: PASSED - Controlled source-change refresh
--
-- M-003 Status:
-- Implemented with controlled validation completed.
-- Standalone source-change refresh behavior remains untested.
--
-- Last Updated: 2026-11-03
-- ============================================================