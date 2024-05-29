  -- ============================@kisinamso=========================
-- == Please change all ENTER_DB_NAME with Ctrl+H shortkey        ==
-- ============================@kisinamso===========================
USE [ENTER_DB_NAME]
GO

CREATE PROCEDURE [dbo].[UpdateStatisticsAndLog]
AS
-- ============================@kisinamso===========================
-- == Use the specified database and create the stored procedure  ==
-- == 1. Replace [ENTER_DB_NAME] with the actual database name.   ==
-- == 2. Create the stored procedure named `UpdateStatisticsAndLog`. ==
-- ============================@kisinamso===========================
-- == Create Log Table if it Doesn't Exist                         ==
-- == 1. Check if the `StatisticsUpdateLog` table exists.          ==
-- == 2. If it doesn't exist, create the table to log statistics   ==
-- ==    updates, including LogID, DatabaseName, SchemaName,       ==
-- ==    TableName, StatisticName, UpdateDate, Status, and         ==
-- ==    ErrorMessage.                                             ==
-- ============================@kisinamso============================
-- == Cursor to Iterate Over All Non-System Databases              ==
-- == 1. Declare a cursor to select all non-system databases.      ==
-- == 2. Iterate through each database using the cursor.           ==
-- ============================@kisinamso============================
-- == Generate and Execute SQL for Each Database                   ==
-- == 1. For each database, generate a SQL script to update        ==
-- ==    statistics on each table.                                 ==
-- == 2. Use another cursor to iterate through all tables and      ==
-- ==    statistics within the current database.                   ==
-- ============================@kisinamso============================
-- == Update Statistics for Each Table                             ==
-- == 1. Generate the UPDATE STATISTICS command for each table     ==
-- ==    and statistic.                                            ==
-- == 2. Use TRY...CATCH to execute the command and log the result.==
-- ============================@kisinamso============================
-- == Log Success or Failure                                       ==
-- == 1. If the statistics update succeeds, log the success.       ==
-- == 2. If the statistics update fails, log the error message.    ==
-- ============================@kisinamso============================
-- == Clean Up                                                     ==
-- == 1. Close and deallocate the table cursor after processing    ==
-- ==    each database.                                            ==
-- == 2. Close and deallocate the database cursor after all        ==
-- ==    databases have been processed.                            ==
-- ============================@kisinamso============================

BEGIN
    SET NOCOUNT ON;

    -- Log table create (if not exists)
    IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[StatisticsUpdateLog]') AND type in (N'U'))
    BEGIN
        CREATE TABLE [dbo].[StatisticsUpdateLog](
            [LogID] [int] IDENTITY(1,1) NOT NULL,
            [DatabaseName] [sysname] NOT NULL,
            [SchemaName] [sysname] NOT NULL,
            [TableName] [sysname] NOT NULL,
            [StatisticName] [sysname] NOT NULL,
            [UpdateDate] [datetime] NOT NULL,
            [Status] [varchar](10) NOT NULL,
            [ErrorMessage] [nvarchar](max) NULL,
            CONSTRAINT [PK_StatisticsUpdateLog] PRIMARY KEY CLUSTERED ([LogID] ASC)
        );
    END;

    -- Cursor to iterate over all non-system databases
    DECLARE db_cursor CURSOR FOR
    SELECT name
    FROM sys.databases
    WHERE name = 'db_sys';  -- Skip system databases

    DECLARE     @dbName sysname            
    OPEN db_cursor;
    FETCH NEXT FROM db_cursor INTO @dbName;
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        DECLARE @sql NVARCHAR(MAX);
        SET @sql = 'USE [' + @dbName + ']; 
                    DECLARE @schemaName sysname
                              ,@tableName sysname
                              ,@statName sysname
                    DECLARE table_cursor CURSOR FOR
                    SELECT s.name AS SchemaName, t.name AS TableName, st.name AS StatisticName
                    FROM sys.tables t
                    JOIN sys.schemas s ON t.schema_id = s.schema_id
                    JOIN sys.stats st ON st.object_id = t.object_id
                    WHERE t.type = ''U'' AND st.name IS NOT NULL;

                    OPEN table_cursor;
                    FETCH NEXT FROM table_cursor INTO @schemaName, @tableName, @statName;

                    WHILE @@FETCH_STATUS = 0
                    BEGIN
                        DECLARE @updateSql NVARCHAR(MAX);
                        SET @updateSql = ''UPDATE STATISTICS ['' + @schemaName + ''].['' + @tableName + ''] ['' + @statName + ''] WITH FULLSCAN;'';

                        BEGIN TRY
                            EXEC sp_executesql @updateSql;                             
                            INSERT INTO [ENTER_DB_NAME].[dbo].[StatisticsUpdateLog] (DatabaseName, SchemaName, TableName, StatisticName, UpdateDate, Status)
                            VALUES (DB_NAME(), @schemaName, @tableName, @statName, GETDATE(), ''Success'');
                        END TRY
                        BEGIN CATCH
                            INSERT INTO [ENTER_DB_NAME].[dbo].[StatisticsUpdateLog] (DatabaseName, SchemaName, TableName, StatisticName, UpdateDate, Status, ErrorMessage)
                            VALUES (DB_NAME(), @schemaName, @tableName, @statName, GETDATE(), ''Fail'', ERROR_MESSAGE());
                        END CATCH;

                        FETCH NEXT FROM table_cursor INTO @schemaName, @tableName, @statName;
                    END;

                    CLOSE table_cursor;
                    DEALLOCATE table_cursor;';

        EXEC sp_executesql @sql;

        FETCH NEXT FROM db_cursor INTO @dbName;
    END;

    CLOSE db_cursor;
    DEALLOCATE db_cursor;
END;
