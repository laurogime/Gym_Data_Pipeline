USE GymDB;
GO

BULK INSERT dbo.exercise_entries_stage
FROM 'C:\Users\Lauro Gime\Documents\Projects\SQL_Server_Express\data\Exercise Entries 375f436bf70d800b83f0d6970a4a89e0.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDQUOTE = '"',
    FIELDTERMINATOR = ',',
    CODEPAGE = '65001',
    TABLOCK
);