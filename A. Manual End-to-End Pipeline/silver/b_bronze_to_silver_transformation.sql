
/*
Purpose:
    Clean and standardize Bronze workout records for the Silver layer.

Source:
    bronze.exercise_entries

Target:
    silver.exercise_entries

Grain:
    One row per Bronze exercise entry.

Behavior:
    Insert new records only. Existing Silver records are not updated.
*/

SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    WITH cleaned AS (
        SELECT
            bronze_id,

            TRY_CONVERT(DATETIME2(3), today)
                AS workout_date,

            -- Remove appended Notion URLs while preserving workout names.
            CASE
                WHEN CHARINDEX(' (https://', workout_log) > 0
                    THEN TRIM(LEFT(
                        workout_log,
                        CHARINDEX(' (https://', workout_log) - 1
                    ))
                ELSE TRIM(workout_log)
            END AS workout_log,

            CASE
                WHEN CHARINDEX(' (https://', exercise) > 0
                    THEN TRIM(LEFT(
                        exercise,
                        CHARINDEX(' (https://', exercise) - 1
                    ))
                ELSE TRIM(exercise)
            END AS exercise,

            -- Blank numeric fields become NULL; invalid values also
            -- become NULL when TRY_CONVERT cannot parse them.
            TRY_CONVERT(
                DECIMAL(6,2),
                NULLIF(TRIM(set_1_weight), '')
            ) AS set_1_weight,

            TRY_CONVERT(
                INT,
                NULLIF(TRIM(set_1_reps), '')
            ) AS set_1_reps,

            TRY_CONVERT(
                DECIMAL(6,2),
                NULLIF(TRIM(set_2_weight), '')
            ) AS set_2_weight,

            TRY_CONVERT(
                INT,
                NULLIF(TRIM(set_2_reps), '')
            ) AS set_2_reps,

            TRY_CONVERT(
                DECIMAL(6,2),
                NULLIF(TRIM(set_3_weight), '')
            ) AS set_3_weight,

            TRY_CONVERT(
                INT,
                NULLIF(TRIM(set_3_reps), '')
            ) AS set_3_reps

        FROM bronze.exercise_entries
    ),
    standardized AS (
        SELECT
            bronze_id,
            workout_date,

            -- Normalize known naming inconsistencies after URL removal.
            CASE
                WHEN workout_log = 'Back Day 1'
                    THEN 'Pull Day 1'
                WHEN workout_log = 'Pull Day Day 10'
                    THEN 'Pull Day 10'
                WHEN workout_log = 'Push Day | 14'
                    THEN 'Push Day 14'
                ELSE workout_log
            END AS workout_log,

            exercise,
            set_1_weight,
            set_1_reps,
            set_2_weight,
            set_2_reps,
            set_3_weight,
            set_3_reps

        FROM cleaned
    )

    INSERT INTO silver.exercise_entries (
        bronze_id,
        today,
        workout_log,
        exercise,
        set_1_weight,
        set_1_reps,
        set_2_weight,
        set_2_reps,
        set_3_weight,
        set_3_reps
    )

    SELECT
        s.bronze_id,
        s.workout_date,
        s.workout_log,
        s.exercise,
        s.set_1_weight,
        s.set_1_reps,
        s.set_2_weight,
        s.set_2_reps,
        s.set_3_weight,
        s.set_3_reps

    FROM standardized AS s

    -- Prevent repeat inserts for Bronze records already loaded.
    -- This does not synchronize changes to existing Silver records.
    WHERE NOT EXISTS (
        SELECT 1
        FROM silver.exercise_entries AS ss
        WHERE ss.bronze_id = s.bronze_id
    );

    COMMIT TRANSACTION;

END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
