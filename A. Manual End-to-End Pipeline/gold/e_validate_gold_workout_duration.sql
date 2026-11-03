-- VAL-016: Gold Workout Duration Grain Validation
-- Source: silver.exercise_entries
-- Target: gold.workout_duration
-- Expected grain: One row per non-NULL workout_log
-- Read-only validation

SELECT
    (
        SELECT COUNT(DISTINCT workout_log)
        FROM silver.exercise_entries
        WHERE workout_log IS NOT NULL
    ) AS silver_session_count,

    (
        SELECT COUNT(*)
        FROM gold.workout_duration
    ) AS gold_row_count,

    (
        SELECT COUNT(DISTINCT workout_log)
        FROM gold.workout_duration
    ) AS gold_distinct_sessions,

    (
        SELECT COUNT(*)
        FROM gold.workout_duration
        WHERE workout_log IS NULL
    ) AS gold_null_session_ids;


-- VAL-017: Workout Session Membership Validation
-- Expected: 0 missing and 0 unexpected sessions
-- Read-only validation

;WITH missing_in_gold AS (
    SELECT DISTINCT workout_log
    FROM silver.exercise_entries
    WHERE workout_log IS NOT NULL

    EXCEPT

    SELECT workout_log
    FROM gold.workout_duration
),

unexpected_in_gold AS (
    SELECT workout_log
    FROM gold.workout_duration

    EXCEPT

    SELECT DISTINCT workout_log
    FROM silver.exercise_entries
    WHERE workout_log IS NOT NULL
)

SELECT
    (SELECT COUNT(*) FROM missing_in_gold)
        AS missing_sessions,
    (SELECT COUNT(*) FROM unexpected_in_gold)
        AS unexpected_sessions;


-- VAL-018: Duration Calculation and Classification Accuracy
-- Independently reconstruct expected results from Silver
-- Expected: 0 missing or mismatched records
--           0 unexpected or mismatched records
-- Read-only validation

;WITH source_summary AS (
    SELECT
        workout_log,
        COUNT(*) AS total_entries,
        COUNT(today) AS timestamped_entries,
        MIN(today) AS first_timestamp,
        MAX(today) AS last_timestamp
    FROM silver.exercise_entries
    WHERE workout_log IS NOT NULL
    GROUP BY workout_log
),

reference_classification AS (
    SELECT
        *,
        CASE
            WHEN timestamped_entries < 2
                THEN 'INSUFFICIENT_DATA'
            WHEN DATEDIFF_BIG(
                MILLISECOND,
                first_timestamp,
                last_timestamp
            ) < 900000
                THEN 'SUSPECT_TIMESTAMP'
            WHEN DATEDIFF_BIG(
                MILLISECOND,
                first_timestamp,
                last_timestamp
            ) > 36000000
                THEN 'INVALID'
            ELSE 'VALID'
        END AS expected_status
    FROM source_summary
),

expected AS (
    SELECT
        workout_log,
        total_entries,
        timestamped_entries,
        first_timestamp,
        last_timestamp,
        CASE
            WHEN expected_status = 'VALID'
                THEN CAST(
                    DATEDIFF_BIG(
                        SECOND,
                        first_timestamp,
                        last_timestamp
                    ) / 60.0 AS DECIMAL(12,2)
                )
            ELSE CAST(NULL AS DECIMAL(12,2))
        END AS estimated_duration_minutes,
        expected_status AS duration_status
    FROM reference_classification
),

missing_or_mismatched AS (
    SELECT * FROM expected
    EXCEPT
    SELECT * FROM gold.workout_duration
),

unexpected_or_mismatched AS (
    SELECT * FROM gold.workout_duration
    EXCEPT
    SELECT * FROM expected
)

SELECT
    (SELECT COUNT(*) FROM missing_or_mismatched)
        AS missing_or_mismatched_rows,
    (SELECT COUNT(*) FROM unexpected_or_mismatched)
        AS unexpected_or_mismatched_rows;



-- VAL-019: Unchanged-Source Idempotency
-- Run before and after the Gold build.
-- Expected: Identical row counts and fingerprints.

SELECT
    (SELECT COUNT(*)
     FROM gold.workout_duration) AS total_rows,

    CONVERT(
        VARCHAR(64),
        HASHBYTES(
            'SHA2_256',
            (
                SELECT
                    workout_log,
                    total_entries,
                    timestamped_entries,
                    first_timestamp,
                    last_timestamp,
                    estimated_duration_minutes,
                    duration_status
                FROM gold.workout_duration
                ORDER BY workout_log
                FOR JSON PATH, INCLUDE_NULL_VALUES
            )
        ),
        2
    ) AS dataset_fingerprint;



-- VAL-020: Transaction Rollback and Failure Recovery
-- Target: gold.workout_duration
-- Controlled failure simulation
-- Expected: Original Gold dataset fully restored

SET NOCOUNT ON;
SET XACT_ABORT ON;

IF @@TRANCOUNT <> 0
    THROW 51030, 'An active transaction already exists.', 1;

DROP TABLE IF EXISTS #workout_duration_before;

-- Step 1: Capture the original Gold dataset.

SELECT
    workout_log,
    total_entries,
    timestamped_entries,
    first_timestamp,
    last_timestamp,
    estimated_duration_minutes,
    duration_status
INTO #workout_duration_before
FROM gold.workout_duration;

DECLARE @original_count INT =
    (SELECT COUNT(*) FROM #workout_duration_before);

DECLARE @inserted_rows INT = 0;
DECLARE @caught_error INT = NULL;

IF @original_count = 0
    THROW 51031, 'Cannot test rollback on an empty Gold table.', 1;


-- Step 2: Simulate an interrupted full refresh.

BEGIN TRY
    BEGIN TRANSACTION;

    DELETE FROM gold.workout_duration;

    INSERT INTO gold.workout_duration (
        workout_log,
        total_entries,
        timestamped_entries,
        first_timestamp,
        last_timestamp,
        estimated_duration_minutes,
        duration_status
    )
    SELECT TOP (20)
        workout_log,
        total_entries,
        timestamped_entries,
        first_timestamp,
        last_timestamp,
        estimated_duration_minutes,
        duration_status
    FROM #workout_duration_before
    ORDER BY workout_log;

    SET @inserted_rows = @@ROWCOUNT;

    -- Deliberately interrupt the partial refresh.
    THROW 51020, 'Simulated Gold refresh failure.', 1;

END TRY
BEGIN CATCH
    SET @caught_error = ERROR_NUMBER();

    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
END CATCH;

IF @caught_error <> 51020
    THROW 51032, 'Expected test failure was not observed.', 1;


-- Step 3: Compare the restored table with its snapshot.

;WITH missing_after_rollback AS (
    SELECT * FROM #workout_duration_before
    EXCEPT
    SELECT * FROM gold.workout_duration
),
unexpected_after_rollback AS (
    SELECT * FROM gold.workout_duration
    EXCEPT
    SELECT * FROM #workout_duration_before
)
SELECT
    @original_count AS original_rows,
    @inserted_rows AS simulated_inserted_rows,
    @caught_error AS caught_error,
    (SELECT COUNT(*) FROM gold.workout_duration)
        AS rows_after_rollback,
    (SELECT COUNT(*) FROM missing_after_rollback)
        AS missing_rows,
    (SELECT COUNT(*) FROM unexpected_after_rollback)
        AS unexpected_rows;