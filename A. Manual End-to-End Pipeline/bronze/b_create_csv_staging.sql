USE GymDB;
GO

CREATE TABLE dbo.exercise_entries_stage (
    property NVARCHAR(100),
    set_1_reps NVARCHAR(50),
    set_2_reps NVARCHAR(50),
    set_3_reps NVARCHAR(50),
    set_1_weight NVARCHAR(50),
    set_2_weight NVARCHAR(50),
    set_3_weight NVARCHAR(50),
    completed NVARCHAR(10),
    today NVARCHAR(100),
    treadmill_km NVARCHAR(50),
    exercise NVARCHAR(1000),
    workout_log NVARCHAR(1000)
);

SELECT
    COLUMN_NAME,
    ORDINAL_POSITION,
    DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'dbo'
  AND TABLE_NAME = 'exercise_entries_stage'
ORDER BY ORDINAL_POSITION;