
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
-- END OF M-003 VALIDATION FILE
--
-- VAL-013: PASSED
-- VAL-014: PASSED
-- VAL-015: INCOMPLETE
--
-- Source-change refresh validation must be completed
-- before M-003 receives final validation approval.
-- ============================================================