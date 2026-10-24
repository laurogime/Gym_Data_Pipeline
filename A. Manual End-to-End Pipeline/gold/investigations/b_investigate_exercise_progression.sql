
-- M-002: Exercise Progression Investigation
-- Objective: Identify the maximum weight from Sets 1 and 2
-- and retrieve the corresponding repetitions.

SELECT
    workout_log,
    exercise,

    -- Maximum weight between the two sets
    GREATEST(set_1_weight, set_2_weight) AS max_weight,

    -- Repetitions associated with the maximum weight
    CASE
        WHEN set_1_weight = set_2_weight
            THEN GREATEST(set_1_reps, set_2_reps)

        WHEN set_1_weight > set_2_weight
            THEN set_1_reps

        WHEN set_1_weight < set_2_weight
            THEN set_2_reps
    END AS max_weight_reps

FROM silver.exercise_entries;
