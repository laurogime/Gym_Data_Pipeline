-- M-003: Gold Workout Duration Build
-- Source: silver.exercise_entries
-- Target: gold.workout_duration
-- Grain: One row per non-NULL workout_log
-- Business rules: ADR-002 (amended 2026-11-03)
-- Strategy: Transactional full refresh

USE [GymDB_V1_Sample];

IF DB_NAME() <> N'GymDB_V1_Sample'
    THROW 50010, 'This script must run in GymDB_V1_Sample.', 1;

SET NOCOUNT ON;

-- Reject execution inside an existing transaction.
IF @@TRANCOUNT <> 0
    THROW 50020,
        'Workout duration build requires no active transaction.',
        1;

SET XACT_ABORT ON;

IF SCHEMA_ID('gold') IS NULL
    THROW 50021, 'Gold schema does not exist.', 1;

DROP TABLE IF EXISTS #workout_duration_next;


-- Step 1: Prepare replacement dataset.

;WITH session_timestamps AS (
    SELECT
        e.workout_log,
        COUNT(*) AS total_entries,
        COUNT(e.today) AS timestamped_entries,
        MIN(e.today) AS first_timestamp,
        MAX(e.today) AS last_timestamp
    FROM silver.exercise_entries AS e
    WHERE e.workout_log IS NOT NULL
    GROUP BY e.workout_log
),

session_classification AS (
    SELECT
        workout_log,
        total_entries,
        timestamped_entries,
        first_timestamp,
        last_timestamp,
        CASE
            WHEN timestamped_entries < 2
                THEN 'INSUFFICIENT_DATA'

            WHEN last_timestamp <
                 DATEADD(MINUTE, 15, first_timestamp)
                THEN 'SUSPECT_TIMESTAMP'

            WHEN last_timestamp >
                 DATEADD(HOUR, 10, first_timestamp)
                THEN 'INVALID'

            ELSE 'VALID'
        END AS duration_status
    FROM session_timestamps
)

SELECT
    workout_log,
    total_entries,
    timestamped_entries,
    first_timestamp,
    last_timestamp,
    CASE
        WHEN duration_status = 'VALID'
            THEN CAST(
                DATEDIFF_BIG(
                    SECOND,
                    first_timestamp,
                    last_timestamp
                ) / 60.0 AS DECIMAL(12,2)
            )
        ELSE NULL
    END AS estimated_duration_minutes,
    duration_status
INTO #workout_duration_next
FROM session_classification;


-- Step 2: Validate replacement dataset.

IF NOT EXISTS (
    SELECT 1
    FROM #workout_duration_next
)
    THROW 50022,
        'Workout duration replacement dataset is empty.',
        1;

IF EXISTS (
    SELECT 1
    FROM #workout_duration_next
    GROUP BY workout_log
    HAVING COUNT(*) > 1
)
    THROW 50023,
        'Duplicate workout sessions detected.',
        1;

IF EXISTS (
    SELECT 1
    FROM #workout_duration_next
    WHERE
        (duration_status = 'VALID'
         AND estimated_duration_minutes IS NULL)
        OR
        (duration_status <> 'VALID'
         AND estimated_duration_minutes IS NOT NULL)
)
    THROW 50024,
        'Invalid relationship between duration and status.',
        1;


-- Step 3: Refresh Gold transactionally.

BEGIN TRY
    BEGIN TRANSACTION;

    -- Create target on first execution.
    -- Dynamic SQL allows the following refresh to
    -- compile even when the table initially does not exist.

    IF OBJECT_ID('gold.workout_duration', 'U') IS NULL
    BEGIN
        EXEC sys.sp_executesql N'
            SELECT TOP (0)
                workout_log,
                total_entries,
                timestamped_entries,
                first_timestamp,
                last_timestamp,
                estimated_duration_minutes,
                duration_status
            INTO gold.workout_duration
            FROM #workout_duration_next;
        ';
    END;

    -- Replace the previous Gold contents.

    EXEC sys.sp_executesql N'
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
        SELECT
            workout_log,
            total_entries,
            timestamped_entries,
            first_timestamp,
            last_timestamp,
            estimated_duration_minutes,
            duration_status
        FROM #workout_duration_next;
    ';

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;


-- Step 4: Display persisted results.

SELECT
    duration_status,
    COUNT(*) AS session_count
FROM gold.workout_duration
GROUP BY duration_status
ORDER BY duration_status;