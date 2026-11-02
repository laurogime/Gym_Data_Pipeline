-- Source: silver.exercise_entries
-- Target: gold.exercise_progression
-- Grain: One row per workout_log and exercise,
--        containing the maximum qualifying weight
--        and its corresponding repetitions
-- Policy: Sets 1 and 2 only
-- Load strategy: Transactional full refresh

-- Require execution outside an existing transaction
IF @@TRANCOUNT <> 0
    THROW 50003, 'Run this build outside an active transaction.', 1;

SET XACT_ABORT ON;

DROP TABLE IF EXISTS #exercise_progression_next;

BEGIN TRY
    BEGIN TRANSACTION;
    -- Step 1: Prepare the next Gold dataset
    ;WITH exercise_sets AS (
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
        WHERE workout_log IS NOT NULL
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
    INTO #exercise_progression_next
    FROM ranked_sets
    WHERE set_rank = 1;

    -- Step 2: Reject an empty replacement dataset
    IF NOT EXISTS (
        SELECT 1
        FROM #exercise_progression_next
    )
        THROW 50002, 'Replacement Gold dataset is empty.', 1;

    -- Step 3: Create Gold schema if needed
    IF SCHEMA_ID('gold') IS NULL
        EXEC('CREATE SCHEMA gold');

    -- Step 4: Create or refresh the Gold table
    IF OBJECT_ID('gold.exercise_progression', 'U') IS NULL
    BEGIN
        -- First execution
        SELECT
            workout_log,
            exercise,
            max_weight,
            max_weight_reps
        INTO gold.exercise_progression
        FROM #exercise_progression_next;
    END
    ELSE
    BEGIN
        -- Subsequent executions
        DELETE FROM gold.exercise_progression;

        INSERT INTO gold.exercise_progression (
            workout_log,
            exercise,
            max_weight,
            max_weight_reps
        )
        SELECT
            workout_log,
            exercise,
            max_weight,
            max_weight_reps
        FROM #exercise_progression_next;
    END;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
GO