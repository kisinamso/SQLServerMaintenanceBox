USE [DB_NAME]
GO
CREATE PROCEDURE dbo.IntegrityCheck
    @DatabaseName SYSNAME = NULL
AS
-- ============================@kisinamso===========================
-- == Create the Stored Procedure for Database Integrity Check    ==
-- == 1. Use a specific database or all databases to check their  ==
-- ==    integrity, based on the parameter `@DatabaseName`.       ==
-- == 2. If no database name is provided, exclude system databases==
-- ==    and check integrity for all other databases.             ==
-- ============================@kisinamso===========================
-- == Create IntegrityCheckLog Table if it Doesn't Exist          ==
-- == 1. Check if the `IntegrityCheckLog` table exists.           ==
-- == 2. If it doesn't exist, create the table to log integrity   ==
-- ==    check results, including LogID, DatabaseName, Status,    ==
-- ==    LogMessage, and LogDateTime.                             ==
-- ============================@kisinamso===========================
-- == Declare Variables                                           ==
-- == 1. Declare necessary variables for SQL commands,            ==
-- ==    log messages, and status indicators.                     ==
-- ============================@kisinamso===========================
-- == Check Integrity for All Databases                           ==
-- == 1. If no specific database is provided, iterate through all ==
-- ==    databases (excluding system databases) and run integrity ==
-- ==    checks on each.                                          ==
-- == 2. Log the integrity check operation and its result.        ==
-- ============================@kisinamso===========================
-- == Check Integrity for a Specific Database                     ==
-- == 1. If a specific database is provided, run integrity check  ==
-- ==    only for that database.                                  ==
-- == 2. Log the integrity check operation and its result.        ==
-- ============================@kisinamso===========================
-- == Clean Up                                                    ==
-- == 1. Close and deallocate the database cursor after all       ==
-- ==    databases (if applicable) have been processed.           ==
-- ============================@kisinamso===========================

BEGIN
    SET NOCOUNT ON;
    
    DECLARE @SQL NVARCHAR(MAX);
    DECLARE @LogMessage NVARCHAR(MAX);
    DECLARE @Status NVARCHAR(10);

    -- Create IntegrityCheckLog table if not exists
    IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'IntegrityCheckLog')
    BEGIN
        CREATE TABLE dbo.IntegrityCheckLog (
            [LogID] [INT] IDENTITY(1,1) PRIMARY KEY,
            [DatabaseName] [SYSNAME],
            [Status] [NVARCHAR](10),
            [LogMessage] [NVARCHAR](MAX),
            [LogDateTime] [DATETIME]
        );
    END

    IF @DatabaseName IS NULL
    BEGIN
        -- Exclude system databases
        DECLARE @DatabaseCursor CURSOR;
        SET @DatabaseCursor = CURSOR FOR
        SELECT name
        FROM sys.databases
        WHERE name NOT IN ('master', 'tempdb', 'model', 'msdb');

        DECLARE @DbName NVARCHAR(128);
        OPEN @DatabaseCursor;
        FETCH NEXT FROM @DatabaseCursor INTO @DbName;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @SQL = 'DBCC CHECKDB([' + @DbName + ']) WITH NO_INFOMSGS;';
            SET @LogMessage = 'Running DBCC CHECKDB on database: ' + @DbName;
            PRINT @LogMessage;
            BEGIN TRY
                EXEC sp_executesql @SQL;
                SET @Status = 'Success'; -- Success
            END TRY
            BEGIN CATCH
                SET @Status = 'Fail'; -- Fail
                SET @LogMessage = @LogMessage + ' Error: ' + ERROR_MESSAGE();
                PRINT @LogMessage;
            END CATCH

            INSERT INTO dbo.IntegrityCheckLog (DatabaseName, LogMessage, LogDateTime, [Status])
            VALUES (DB_NAME(), @LogMessage, GETDATE(), @Status);
            
            FETCH NEXT FROM @DatabaseCursor INTO @DbName;
        END

        CLOSE @DatabaseCursor;
        DEALLOCATE @DatabaseCursor;
    END
    ELSE
    BEGIN
        -- Check Integrity for defined database
        SET @SQL = 'DBCC CHECKDB([' + @DatabaseName + ']) WITH NO_INFOMSGS;';
        SET @LogMessage = 'Running DBCC CHECKDB on database: ' + @DatabaseName;
        PRINT @LogMessage;
        BEGIN TRY
            EXEC sp_executesql @SQL;
            SET @Status = 'Success'; -- Success
        END TRY
        BEGIN CATCH
            SET @Status = 'Fail'; -- Fail
            SET @LogMessage = @LogMessage + ' Error: ' + ERROR_MESSAGE();
            PRINT @LogMessage;
        END CATCH

        INSERT INTO dbo.IntegrityCheckLog (DatabaseName, LogMessage, LogDateTime, [Status])
        VALUES (DB_NAME(), @LogMessage, GETDATE(), @Status);
    END
END
GO
