/*
Purpose:
    Create the Silver Exercise entries table.

Grain:
    One row per exercise from Bronze.

Design Decisions:
    - Preserve bronze_id for data lineage.
    - Convert raw text values into appropriate data types.
    - Preserve all three exercise sets.
    - Exclue unused Notion export columns.

Source:
    bronze.exercise_entries
*/

CREATE TABLE silver.exercise_entries (
    silver_id BIGINT IDENTITY(1, 1) PRIMARY KEY,
    bronze_id BIGINT,
    today DATE,
    workout_log NVARCHAR(250),
    exercise NVARCHAR(250),
    set_1_weight DECIMAL(6,2),
    set_1_reps INT,
    set_2_weight DECIMAL(6,2),
    set_2_reps INT,
    set_3_weight DECIMAL(6,2),
    set_3_reps INT
);

ALTER TABLE silver.exercise_entries
ALTER COLUMN today DATETIME2(3) NULL;