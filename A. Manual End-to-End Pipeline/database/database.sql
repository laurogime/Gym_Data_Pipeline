USE [master];

IF DB_ID(N'GymDB_V1_Sample') IS NULL
    EXEC(N'CREATE DATABASE [GymDB_V1_Sample];');
GO

USE [GymDB_V1_Sample];

IF DB_NAME() <> N'GymDB_V1_Sample'
    THROW 50001, 'This setup must run in GymDB_V1_Sample.', 1;

IF SCHEMA_ID(N'bronze') IS NULL
    EXEC(N'CREATE SCHEMA bronze AUTHORIZATION dbo;');

IF SCHEMA_ID(N'silver') IS NULL
    EXEC(N'CREATE SCHEMA silver AUTHORIZATION dbo;');

IF SCHEMA_ID(N'gold') IS NULL
    EXEC(N'CREATE SCHEMA gold AUTHORIZATION dbo;');

SELECT DB_NAME() AS database_name, name AS schema_name
FROM sys.schemas
WHERE name IN (N'bronze', N'silver', N'gold')
ORDER BY name;