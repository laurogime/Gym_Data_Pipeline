
/*
Purpose:
    Check dependencies and establish a row-count baseline
    before modifying silver.exercise_entries.

Source:
    SQL Server system catalogs
    silver.exercise_entries

Behavior:
    Read-only investigation. No data modifications.
*/

USE GymDB;
GO

-- CHECK 01: Foreign keys referencing Silver.
SELECT
    fk.name AS foreign_key_name,
    OBJECT_SCHEMA_NAME(fk.parent_object_id) AS referencing_schema,
    OBJECT_NAME(fk.parent_object_id) AS referencing_table
FROM sys.foreign_keys AS fk
WHERE fk.referenced_object_id =
    OBJECT_ID('silver.exercise_entries');


-- CHECK 02: SQL objects referencing Silver.
SELECT
    OBJECT_SCHEMA_NAME(d.referencing_id) AS referencing_schema,
    OBJECT_NAME(d.referencing_id) AS referencing_object,
    o.type_desc AS object_type
FROM sys.sql_expression_dependencies AS d
INNER JOIN sys.objects AS o
    ON d.referencing_id = o.object_id
WHERE d.referenced_id =
    OBJECT_ID('silver.exercise_entries');


-- CHECK 03: Silver record count before correction.
SELECT
    COUNT(*) AS silver_record_count
FROM silver.exercise_entries;
