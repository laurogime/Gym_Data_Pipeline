/*
Purpose:
    Transform Bronze workout records into Silver.

Source:
    bronze.exercise_entries

Target:
    silver.exercise_entries

Grain:
    One row per Bronze exercise entry.
*/

SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    WITH cleaned AS (
        SELECT
            bronze_id,

            TRY_CONVERT(DATETIME2(3), today)
                AS workout_date,

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
        c.bronze_id,
        c.workout_date,
        c.workout_log,
        c.exercise,
        c.set_1_weight,
        c.set_1_reps,
        c.set_2_weight,
        c.set_2_reps,
        c.set_3_weight,
        c.set_3_reps

    FROM cleaned AS c
    WHERE NOT EXISTS (
        SELECT 1
        FROM silver.exercise_entries AS s
        WHERE s.bronze_id = c.bronze_id
    );

    COMMIT TRANSACTION;

END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;