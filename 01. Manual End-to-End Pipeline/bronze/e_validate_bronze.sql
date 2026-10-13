USE GymDB;
GO

SELECT
    (SELECT COUNT(*)
     FROM dbo.exercise_entries_stage) AS staging_rows,

    (SELECT COUNT(*)
     FROM bronze.exercise_entries) AS bronze_rows,

    (SELECT COUNT(DISTINCT bronze_id)
     FROM bronze.exercise_entries) AS unique_bronze_ids;

WITH staging_counts AS (
    SELECT
        workout_log, property, today,
        set_1_weight, set_1_reps,
        set_2_weight, set_2_reps,
        set_3_weight, set_3_reps,
        completed, treadmill_km, exercise,
        COUNT_BIG(*) AS row_count
    FROM dbo.exercise_entries_stage
    GROUP BY
        workout_log, property, today,
        set_1_weight, set_1_reps,
        set_2_weight, set_2_reps,
        set_3_weight, set_3_reps,
        completed, treadmill_km, exercise
),
bronze_counts AS (
    SELECT
        workout_log, property, today,
        set_1_weight, set_1_reps,
        set_2_weight, set_2_reps,
        set_3_weight, set_3_reps,
        completed, treadmill_km, exercise,
        COUNT_BIG(*) AS row_count
    FROM bronze.exercise_entries
    GROUP BY
        workout_log, property, today,
        set_1_weight, set_1_reps,
        set_2_weight, set_2_reps,
        set_3_weight, set_3_reps,
        completed, treadmill_km, exercise
)
SELECT *
FROM staging_counts

EXCEPT

SELECT *
FROM bronze_counts;