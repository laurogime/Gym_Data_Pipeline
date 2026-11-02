-- M-002: Exercise Progression Investigation
-- Source: silver.exercise_entries
-- Grain: One row per workout_log and exercise
-- Measures: Maximum qualifying weight and corresponding repetitions
-- Policy: Sets 1 and 2 only; complete weight-repetition pairs required

WITH exercise_sets AS (
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
    WHERE
        workout_log IS NOT NULL
        AND exercise IS NOT NULL
        AND weight IS NOT NULL
        AND reps IS NOT NULL
),

ranked_sets AS (
    SELECT
        bronze_id,
        workout_log,
        exercise,
        set_number,
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
FROM ranked_sets
WHERE set_rank = 1;