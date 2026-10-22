
/*
Purpose:
    Investigate inconsistent workout_log names in Silver
    before applying the standardization rules.

Source:
    silver.exercise_entries

Behavior:
    Read-only investigation. No data modifications.
*/

USE GymDB;
GO

-- CHECK 01: Inspect distinct workout-log names.
SELECT DISTINCT
    workout_log
FROM silver.exercise_entries
WHERE workout_log IS NOT NULL
ORDER BY workout_log ASC;


-- CHECK 02: Count records with identified naming issues.
SELECT
    workout_log,
    COUNT(*) AS record_count
FROM silver.exercise_entries
WHERE workout_log IN (
    'Back Day 1',
    'Pull Day Day 10',
    'Push Day | 14'
)
GROUP BY workout_log
ORDER BY workout_log ASC;


-- CHECK 03: Test naming corrections without persisting changes.
BEGIN TRANSACTION;

UPDATE silver.exercise_entries
SET workout_log =
    CASE
        WHEN workout_log = 'Back Day 1'
            THEN 'Pull Day 1'
        WHEN workout_log = 'Pull Day Day 10'
            THEN 'Pull Day 10'
        WHEN workout_log = 'Push Day | 14'
            THEN 'Push Day 14'
        ELSE workout_log
    END
WHERE workout_log IN (
    'Back Day 1',
    'Pull Day Day 10',
    'Push Day | 14'
);

SELECT @@ROWCOUNT AS affected_rows;

SELECT
    workout_log,
    COUNT(*) AS record_count
FROM silver.exercise_entries
WHERE workout_log IN (
    'Pull Day 1',
    'Pull Day 10',
    'Push Day 14'
)
GROUP BY workout_log
ORDER BY workout_log;

ROLLBACK TRANSACTION;


-- CHECK 04: Verify original names were restored.
SELECT
    workout_log,
    COUNT(*) AS record_count
FROM silver.exercise_entries
WHERE workout_log IN (
    'Back Day 1',
    'Pull Day Day 10',
    'Push Day | 14'
)
GROUP BY workout_log
ORDER BY workout_log;

-- CHECK 05: Verify standardized workout-log names.
SELECT
    workout_log,
    COUNT(*) AS record_count
FROM silver.exercise_entries
WHERE workout_log IN (
    'Back Day 1',
    'Pull Day Day 10',
    'Push Day | 14',
    'Pull Day 1',
    'Pull Day 10',
    'Push Day 14'
)
GROUP BY workout_log
ORDER BY workout_log;

-- CHECK 06: Confirm Silver row count after correction.
SELECT
    COUNT(*) AS silver_record_count
FROM silver.exercise_entries;