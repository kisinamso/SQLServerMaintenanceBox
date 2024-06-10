-- =============================@kisinamso==========================
-- == Please change all ENTER_DB_NAME with Ctrl+H shortkey        ==
-- ============================@kisinamso===========================
USE [ENTER_DB_NAME]
GO
CREATE PROCEDURE dbo.PerformIndexMaintenance
  @DatabaseName SYSNAME = NULL
AS
-- ============================@kisinamso===========================
-- == Select the Database and Create the Stored Procedure         ==
-- == 1. Use a specific database and create the stored procedure  ==
-- ==    named `PerformIndexMaintenance`.                         ==
-- == 2. Define an optional parameter (`@DatabaseName`) that      ==
-- ==    can take a specific database name.                       ==
-- ============================@kisinamso===========================
-- == Create the Database List                                    ==
-- == 1. Exclude system databases and select all online user      ==
-- ==    databases, adding them to a temporary table named        ==
-- ==    `@databases`.                                            ==
-- == 2. If the `@DatabaseName` parameter is provided, select     ==
-- ==    only the specified database.                             ==
-- ============================@kisinamso===========================
-- == Create a Table for Maintenance Results                      ==
-- == 1. Create a table named `IndexMaintenanceResults`.          ==
-- == 2. This table will be created if it does not already        ==
-- ==    exist and will be used to store index maintenance        ==
-- ==    results.                                                 ==
-- ============================@kisinamso===========================
-- == Analyze Indexes and Generate Maintenance Commands           ==
-- == 1. Analyze indexes in other databases and generate          ==
-- ==    appropriate maintenance commands.                        ==
-- == 2. Insert maintenance commands and index information        ==
-- ==    into the `IndexMaintenanceResults` table.                ==
-- == 3. For each database, determine the status of indexes       ==
-- ==    and generate reorganize or rebuild commands.             ==
-- == 4. Execute the generated commands.                          ==
-- ============================@kisinamso===========================
BEGIN
    -- Please provide the list of all databases to be processed below.
    -- Excludes system databases and selects all online databases.
    DECLARE @databases TABLE (DatabaseName NVARCHAR(128));

    -- Exclude system databases and select all online databases for processing.
    INSERT INTO @databases
    SELECT name 
    FROM sys.databases
    WHERE state = 0 -- Only online databases
    AND (@DatabaseName IS NULL AND name NOT IN ('master', 'tempdb', 'model', 'msdb') -- Skip the system databases
         OR @DatabaseName IS NOT NULL AND name = @DatabaseName); -- Or selected database

    -- Create a table to store maintenance results.
    IF OBJECT_ID('dbo.IndexMaintenanceResults') IS NULL 
    BEGIN
        CREATE TABLE dbo.IndexMaintenanceResults (
            ID INT IDENTITY(1,1) PRIMARY KEY,
            DatabaseName SYSNAME,
            SchemaName SYSNAME,
            TableName SYSNAME,
            IndexName SYSNAME,
            FragmentationPercent FLOAT,
            MaintenanceCommand NVARCHAR(MAX),
            ExecutionDate DATETIME DEFAULT GETDATE(),
            ExecutionResult NVARCHAR(MAX) NULL 
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
        'DECLARE @commands TABLE (MaintenanceCommand NVARCHAR(MAX), SchemaName NVARCHAR(128), TableName NVARCHAR(128), IndexName NVARCHAR(128), FragmentationPercent FLOAT); ' +
        'INSERT INTO @commands (MaintenanceCommand, SchemaName, TableName, IndexName, FragmentationPercent) ' +
        'SELECT ' +
        'CASE ' +
        'WHEN indexstats.avg_fragmentation_in_percent BETWEEN 5 AND 30 THEN ' +
        '    CASE ' +
        '        WHEN TYPE_NAME(col.user_type_id) IN (''xml'', ''geometry'', ''geography'', ''text'', ''ntext'', ''image'') ' +
        '            OR (col.max_length = -1 AND TYPE_NAME(col.user_type_id) IN (''varchar'', ''nvarchar'', ''varbinary'')) THEN ' +
        '            ''ALTER INDEX '' + QUOTENAME(ind.name) + '' ON '' + QUOTENAME(OBJECT_SCHEMA_NAME(ind.OBJECT_ID)) + ''.'' + QUOTENAME(OBJECT_NAME(ind.OBJECT_ID)) + '' REORGANIZE;'' ' +
        '        ELSE ' +
        '            ''ALTER INDEX '' + QUOTENAME(ind.name) + '' ON '' + QUOTENAME(OBJECT_SCHEMA_NAME(ind.OBJECT_ID)) + ''.'' + QUOTENAME(OBJECT_NAME(ind.OBJECT_ID)) + '' REORGANIZE WITH (ONLINE = ON);'' ' +
        '    END ' +
        'WHEN indexstats.avg_fragmentation_in_percent &gt; 30 THEN ' +
        '    CASE ' +
        '        WHEN TYPE_NAME(col.user_type_id) IN (''xml'', ''geometry'', ''geography'', ''text'', ''ntext'', ''image'') ' +
        '            OR (col.max_length = -1 AND TYPE_NAME(col.user_type_id) IN (''varchar'', ''nvarchar'', ''varbinary'')) THEN ' +
        '            ''ALTER INDEX '' + QUOTENAME(ind.name) + '' ON '' + QUOTENAME(OBJECT_SCHEMA_NAME(ind.OBJECT_ID)) + ''.'' + QUOTENAME(OBJECT_NAME(ind.OBJECT_ID)) + '' REBUILD;'' ' +
        '        ELSE ' +
        '            ''ALTER INDEX '' + QUOTENAME(ind.name) + '' ON '' + QUOTENAME(OBJECT_SCHEMA_NAME(ind.OBJECT_ID)) + ''.'' + QUOTENAME(OBJECT_NAME(ind.OBJECT_ID)) + '' REBUILD WITH (ONLINE = ON);'' ' +
        '    END ' +
        'ELSE NULL ' +
        'END AS MaintenanceCommand, ' +
        'OBJECT_SCHEMA_NAME(ind.OBJECT_ID) AS SchemaName, ' +
        'OBJECT_NAME(ind.OBJECT_ID) AS TableName, ' +
        'ind.name AS IndexName, ' +
        'indexstats.avg_fragmentation_in_percent AS FragmentationPercent ' +
        'FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, ''LIMITED'') indexstats ' +
        'INNER JOIN sys.indexes ind ON ind.object_id = indexstats.object_id AND ind.index_id = indexstats.index_id ' +
        'INNER JOIN sys.index_columns ic ON ind.object_id = ic.object_id AND ind.index_id = ic.index_id ' +
        'INNER JOIN sys.columns col ON col.object_id = ind.object_id AND ic.column_id = col.column_id ' +
        'WHERE indexstats.avg_fragmentation_in_percent &gt;= 5 AND ind.name IS NOT NULL; ' +

        'DECLARE @command NVARCHAR(MAX), @schema NVARCHAR(128), @table NVARCHAR(128), @index NVARCHAR(128), @frag FLOAT; ' +
        'DECLARE commandCursor CURSOR LOCAL FAST_FORWARD FOR ' +
        'SELECT MaintenanceCommand, SchemaName, TableName, IndexName, FragmentationPercent FROM @commands; ' +

        'OPEN commandCursor; ' +
        'FETCH NEXT FROM commandCursor INTO @command, @schema, @table, @index, @frag; ' +

        'WHILE @@FETCH_STATUS = 0 ' +
        'BEGIN ' +
        '    BEGIN TRY ' +
        '        EXEC sp_executesql @command; ' +
        '        INSERT INTO [ENTER_DB_NAME].[dbo].[IndexMaintenanceResults] (DatabaseName, SchemaName, TableName, IndexName, FragmentationPercent, MaintenanceCommand, ExecutionResult) ' +
        '        VALUES (' + QUOTENAME(@dbName, '''') + ', @schema, @table, @index, @frag, @command, ''Success''); ' +
        '    END TRY ' +
        '    BEGIN CATCH ' +
        '        INSERT INTO [ENTER_DB_NAME].[dbo].[IndexMaintenanceResults] (DatabaseName, SchemaName, TableName, IndexName, FragmentationPercent, MaintenanceCommand, ExecutionResult) ' +
        '        VALUES (' + QUOTENAME(@dbName, '''') + ', @schema, @table, @index, @frag, @command, ERROR_MESSAGE()); ' +
        '    END CATCH; ' +

        '    FETCH NEXT FROM commandCursor INTO @command, @schema, @table, @index, @frag; ' +
        'END; ' +

        'CLOSE commandCursor; ' +
        'DEALLOCATE commandCursor;';

        -- Execute the generated maintenance commands
        EXEC sp_executesql @sql;

        FETCH NEXT FROM dbCursor INTO @dbName;
    END

    CLOSE dbCursor;
    DEALLOCATE dbCursor;
END
GO<
CLOSE dbCursor;
DEALLOCATE dbCursor;
END
