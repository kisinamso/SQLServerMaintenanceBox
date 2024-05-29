USE [DB_NAME]
GO
CREATE PROCEDURE dbo.IntegrityCheck
    @DatabaseName SYSNAME = NULL
AS
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
