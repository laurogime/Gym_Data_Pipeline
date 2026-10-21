
/*
===============================================================================
Investigation : Workout Session Integrity
Milestone     : M-001 - Workout Session Modeling
Source        : silver.exercise_entries
Database      : GymDB

Objective:
    Assess whether workout_log can reliably identify individual
    workout sessions for Gold-layer duration calculations.

Scope:
    1. Identify workout logs associated with multiple calendar dates.
    2. Inspect the exercise records associated with those logs.
    3. Identify records with missing session identifiers or timestamps.

Important:
    Multiple calendar dates do not automatically indicate invalid data.
    A workout session may legitimately cross midnight.

Expected behavior:
    Investigation only. No source data will be modified.
===============================================================================
*/

USE GymDB;
GO

SET NOCOUNT ON;


-- =============================================================================
-- CHECK 01: Workout Logs Associated with Multiple Calendar Dates
-- =============================================================================

SELECT
    workout_log,
    COUNT(DISTINCT CAST(today AS DATE)) AS distinct_date_count,
    MIN(today) AS earliest_timestamp,
    MAX(today) AS latest_timestamp
FROM silver.exercise_entries
WHERE workout_log IS NOT NULL
GROUP BY workout_log
HAVING COUNT(DISTINCT CAST(today AS DATE)) > 1
ORDER BY workout_log;


-- =============================================================================
-- CHECK 02: Individual Records for Flagged Workout Logs
-- =============================================================================

WITH flagged_logs AS (
    SELECT
        workout_log
    FROM silver.exercise_entries
    WHERE workout_log IS NOT NULL
    GROUP BY workout_log
    HAVING COUNT(DISTINCT CAST(today AS DATE)) > 1
)

SELECT
    s.silver_id,
    s.workout_log,
    s.exercise,
    s.today
FROM silver.exercise_entries AS s
INNER JOIN flagged_logs AS f
    ON s.workout_log = f.workout_log
ORDER BY
    s.workout_log,
    s.today,
    s.silver_id;


-- =============================================================================
-- CHECK 03: Missing Session Identifiers or Timestamps
-- =============================================================================

SELECT
    silver_id,
    bronze_id,
    workout_log,
    exercise,
    today
FROM silver.exercise_entries
WHERE workout_log IS NULL
   OR today IS NULL
ORDER BY silver_id;
