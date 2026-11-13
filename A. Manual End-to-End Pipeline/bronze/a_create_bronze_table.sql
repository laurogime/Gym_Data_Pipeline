USE [GymDB_V1_Sample];

IF DB_NAME() <> N'GymDB_V1_Sample'
    THROW 50010, 'This script must run in GymDB_V1_Sample.', 1;

CREATE TABLE bronze.exercise_entries (
    bronze_id BIGINT IDENTITY(1, 1) PRIMARY KEY,
    workout_log NVARCHAR(1000),
    property NVARCHAR(100),
    today NVARCHAR(100),
    set_1_weight NVARCHAR(50),
    set_1_reps NVARCHAR(50),
    set_2_weight NVARCHAR(50),
    set_2_reps NVARCHAR(50),
    set_3_weight NVARCHAR(50),
    set_3_reps NVARCHAR(50),
    Completed NVARCHAR(10),
    treadmill_km NVARCHAR(50),
    exercise NVARCHAR(1000)
);

