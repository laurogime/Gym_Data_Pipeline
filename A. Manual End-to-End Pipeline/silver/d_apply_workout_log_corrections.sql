SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @affected_rows INT;

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

        SET @affected_rows = @@ROWCOUNT;

        IF @affected_rows NOT IN (0, 21)
            THROW 50001, 'Unexpected number of updated records.', 1;

        COMMIT TRANSACTION;

END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;