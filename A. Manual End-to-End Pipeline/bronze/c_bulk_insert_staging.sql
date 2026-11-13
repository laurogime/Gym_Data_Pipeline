USE [GymDB_V1_Sample];

IF DB_NAME() <> N'GymDB_V1_Sample'
    THROW 50001, 'Run this loader in GymDB_V1_Sample.', 1;

IF EXISTS (SELECT 1 FROM dbo.exercise_entries_stage)
    THROW 50002, 'Staging already contains rows. Load cancelled.', 1;

-- For a local run, replace the placeholder with the absolute path
-- to data/sample/exercise_entries_demo.csv in your clone.
BULK INSERT dbo.exercise_entries_stage
FROM 'PASTE_DEMO_CSV_PATH_HERE'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDQUOTE = '"',
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0A',
    CODEPAGE = '65001',
    TABLOCK
);

SELECT COUNT(*) AS staging_rows
FROM dbo.exercise_entries_stage;