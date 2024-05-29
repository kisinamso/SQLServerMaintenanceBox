-- You can enter database name what would create object to where. My suggestions are DBA Database or maintenance database.
-- You can change schema name or stored procedures name.
-- This stored procedure works for maintenance for all indexes in a sql server. If you want to for specifed databases you can change from line 15-16.
USE [DB_NAME]
GO
CREATE PROCEDURE dbo.PerformIndexMaintenance
  @DatabaseName SYSNAME = NULL
AS
BEGIN

-- Please provide the list of all databases to be processed below.
-- Excludes system databases and selects all online databases.
DECLARE @databases TABLE (DatabaseName NVARCHAR(128));

-- Exclude system databases and select all online databases for processing.
INSERT INTO @databases
SELECT name 
FROM sys.databases
WHERE state = 0 -- Only online databases
AND (@DatabaseName IS NULL AND name NOT IN ('master', 'tempdb', 'model', 'msdb') --Skip the system databases
     OR @DatabaseName IS NOT NULL AND name = @DatabaseName); --Or selected database


-- Create a table to store maintenance results.
IF OBJECT_ID('dbo.IndexMaintenanceResults') IS NULL 
BEGIN
CREATE TABLE dbo.IndexMaintenanceResults (
    ID INT IDENTITY(1,1) PRIMARY KEY,
    DatabaseName NVARCHAR(128),
    TableName NVARCHAR(128),
    IndexName NVARCHAR(128),
    FragmentationPercent FLOAT,
    MaintenanceCommand NVARCHAR(MAX),
    ExecutionDate DATETIME DEFAULT GETDATE()
);
END

-- Analyze indexes in other databases and generate appropriate maintenance commands.
DECLARE @sql NVARCHAR(MAX) = '';

DECLARE @dbName NVARCHAR(128);
DECLARE dbCursor CURSOR LOCAL FAST_FORWARD FOR
SELECT DatabaseName FROM @databases;

OPEN dbCursor;
FETCH NEXT FROM dbCursor INTO @dbName;

WHILE @@FETCH_STATUS = 0 
BEGIN
    SET @sql = 
    'USE [' + @dbName + ']; ' +
    'INSERT INTO db_sys.dbo.IndexMaintenanceResults (DatabaseName, TableName, IndexName, FragmentationPercent, MaintenanceCommand) ' +
    'SELECT ' + QUOTENAME(@dbName, '''') + ' AS DatabaseName, ' +
    'OBJECT_NAME(ind.OBJECT_ID) AS TableName, ' +
    'ind.name AS IndexName, ' +
    'indexstats.avg_fragmentation_in_percent AS FragmentationPercent, ' +
    'CASE ' +
    'WHEN indexstats.avg_fragmentation_in_percent BETWEEN 5 AND 30 THEN ' +
    '    CASE ' +
    '        WHEN TYPE_NAME(col.user_type_id) IN (''xml'', ''geometry'', ''geography'', ''text'', ''ntext'', ''image'') ' +
    '            OR (col.max_length = -1 AND TYPE_NAME(col.user_type_id) IN (''varchar'', ''nvarchar'', ''varbinary'')) THEN ' +
    '            ''ALTER INDEX '' + QUOTENAME(ind.name) + '' ON '' + QUOTENAME(OBJECT_NAME(ind.OBJECT_ID)) + '' REORGANIZE;'' ' +
    '        ELSE ' +
    '            ''ALTER INDEX '' + QUOTENAME(ind.name) + '' ON '' + QUOTENAME(OBJECT_NAME(ind.OBJECT_ID)) + '' REORGANIZE WITH (ONLINE = ON);'' ' +
    '    END ' +
    'WHEN indexstats.avg_fragmentation_in_percent > 30 THEN ' +
    '    CASE ' +
    '        WHEN TYPE_NAME(col.user_type_id) IN (''xml'', ''geometry'', ''geography'', ''text'', ''ntext'', ''image'') ' +
    '            OR (col.max_length = -1 AND TYPE_NAME(col.user_type_id) IN (''varchar'', ''nvarchar'', ''varbinary'')) THEN ' +
    '            ''ALTER INDEX '' + QUOTENAME(ind.name) + '' ON '' + QUOTENAME(OBJECT_NAME(ind.OBJECT_ID)) + '' REBUILD;'' ' +
    '        ELSE ' +
    '            ''ALTER INDEX '' + QUOTENAME(ind.name) + '' ON '' + QUOTENAME(OBJECT_NAME(ind.OBJECT_ID)) + '' REBUILD WITH (ONLINE = ON);'' ' +
    '    END ' +
    'ELSE NULL ' +
    'END AS MaintenanceCommand ' +
    'FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, ''LIMITED'') indexstats ' +
    'INNER JOIN sys.indexes ind ON ind.object_id = indexstats.object_id AND ind.index_id = indexstats.index_id ' +
    'INNER JOIN sys.index_columns ic ON ind.object_id = ic.object_id AND ind.index_id = ic.index_id ' +
    'INNER JOIN sys.columns col ON col.object_id = ind.object_id AND ic.column_id = col.column_id ' +
    'WHERE indexstats.avg_fragmentation_in_percent >= 5 AND ind.name IS NOT NULL; ';

    EXEC sp_executesql @sql;

    FETCH NEXT FROM dbCursor INTO @dbName;
END

CLOSE dbCursor;
DEALLOCATE dbCursor;
END
