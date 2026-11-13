USE [GymDB_V1_Sample];

IF DB_NAME() <> N'GymDB_V1_Sample'
    THROW 50010, 'This script must run in GymDB_V1_Sample.', 1;

SET XACT_ABORT ON;

BEGIN TRANSACTION;

IF EXISTS (
    SELECT 1
    FROM bronze.exercise_entries
)
BEGIN
    THROW 50001, 'Bronze table is not empty. Load cancelled.', 1;
END;

INSERT INTO bronze.exercise_entries (
    workout_log,
    property,
    today,
    set_1_weight,
    set_1_reps,
    set_2_weight,
    set_2_reps,
    set_3_weight,
    set_3_reps,
    completed,
    treadmill_km,
    exercise
)
SELECT
    workout_log,
    property,
    today,
    set_1_weight,
    set_1_reps,
    set_2_weight,
    set_2_reps,
    set_3_weight,
    set_3_reps,
    completed,
    treadmill_km,
    exercise
FROM dbo.exercise_entries_stage;

COMMIT TRANSACTION;