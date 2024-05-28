USE [DB_NAME]
GO
CREATE PROCEDURE dbo.BackupDatabase
    @dbName NVARCHAR(128) = NULL, -- Database name (optional)
    @backupType NVARCHAR(10) = NULL -- Backup type (full, diff, trn)
AS
BEGIN
    -- Create BackupLog table if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'BackupLog')
    BEGIN
        CREATE TABLE dbo.BackupLog (
            LogID INT PRIMARY KEY IDENTITY(1,1),
            DatabaseName NVARCHAR(128),
            BackupType NVARCHAR(10),
            BackupPath NVARCHAR(256),
            BackupFileName NVARCHAR(256),
            BackupDateTime DATETIME
        );
    END

    DECLARE @backupPath NVARCHAR(256) -- Backup path
    DECLARE @fileName NVARCHAR(256) -- Backup file name
    DECLARE @dateTime NVARCHAR(20) -- Date/time
    DECLARE @isEndOfMonth BIT -- Is it the end of the month?
    DECLARE @isEndOfYear BIT -- Is it the end of the year?

    -- Calculate whether it's the end of the month and the end of the year
    SET @isEndOfMonth = CASE WHEN DAY(GETDATE()) = DAY(DATEADD(DAY, 0, EOMONTH(GETDATE()))) THEN 1 ELSE 0 END
    SET @isEndOfYear = CASE WHEN MONTH(GETDATE()) = 12 AND DAY(GETDATE()) = 31 THEN 1 ELSE 0 END

    -- Set backup paths
    IF @isEndOfMonth = 1
    BEGIN
        SET @backupPath = 'C:\YourBackupFolder\Monthly\' -- Monthly backup directory
    END
    ELSE IF @isEndOfYear = 1
    BEGIN
        SET @backupPath = 'C:\YourBackupFolder\Yearly\' -- Yearly backup directory
    END
    ELSE
    BEGIN
        SET @backupPath = 'C:\YourBackupFolder\Daily\' -- Daily backup directory
    END

    -- Get current date/time
    SET @dateTime = REPLACE(CONVERT(NVARCHAR, GETDATE(), 111), '/', '') + '_' + REPLACE(CONVERT(NVARCHAR, GETDATE(), 108), ':', '')

    -- If database name is not specified, backup all databases
    IF @dbName IS NULL
    BEGIN
        DECLARE db_cursor CURSOR FOR
        SELECT name FROM master.sys.databases WHERE state_desc = 'ONLINE' 

        OPEN db_cursor
        FETCH NEXT FROM db_cursor INTO @dbName

        WHILE @@FETCH_STATUS = 0
        BEGIN
            IF @backupType IS NULL OR @backupType = 'full' -- Full backup
            BEGIN
                SET @fileName = @dbName + 'Full' + @dateTime + '.bak'
                DECLARE @sql1 NVARCHAR(MAX)
                SET @sql1 = 'BACKUP DATABASE ' + QUOTENAME(@dbName) + ' TO DISK = ''' + @backupPath + @fileName + ''' -- WITH --You can add parameter to here'
                EXEC(@sql1)

                -- Log backup operation
                INSERT INTO dbo.BackupLog (DatabaseName, BackupType, BackupPath, BackupFileName, BackupDateTime)
                VALUES (@dbName, 'Full', @backupPath, @fileName, GETDATE())
            END
            ELSE IF @backupType = 'diff' -- Differential backup
            BEGIN
                SET @fileName = @dbName + 'Diff' + @dateTime + '.dif'
                DECLARE @sql2 NVARCHAR(MAX)
                SET @sql2 = 'BACKUP DATABASE ' + QUOTENAME(@dbName) + ' TO DISK = ''' + @backupPath + @fileName + ''' -- WITH --You can add parameter to here'
                EXEC(@sql2)

                -- Log backup operation
                INSERT INTO dbo.BackupLog (DatabaseName, BackupType, BackupPath, BackupFileName, BackupDateTime)
                VALUES (@dbName, 'Diff', @backupPath, @fileName, GETDATE())
            END
            ELSE IF @backupType = 'trn' -- Transaction log backup
            BEGIN
                SET @fileName = @dbName + 'Trn' + @dateTime + '.trn'
                DECLARE @sql3 NVARCHAR(MAX)
                SET @sql3 = 'BACKUP LOG ' + QUOTENAME(@dbName) + ' TO DISK = ''' + @backupPath + @fileName + ''' -- WITH --You can add parameter to here'
                EXEC(@sql3)

                -- Log backup operation
                INSERT INTO dbo.BackupLog (DatabaseName, BackupType, BackupPath, BackupFileName, BackupDateTime)
                VALUES (@dbName, 'Trn', @backupPath, @fileName, GETDATE())
            END

            FETCH NEXT FROM db_cursor INTO @dbName
        END

        CLOSE db_cursor
        DEALLOCATE db_cursor
    END
    ELSE
    BEGIN

IF @backupType IS NULL OR @backupType = 'full' -- Full backup
        BEGIN
            SET @fileName = @dbName + 'Full' + @dateTime + '.bak'
            DECLARE @sql4 NVARCHAR(MAX)
            SET @sql4 = 'BACKUP DATABASE ' + QUOTENAME(@dbName) + ' TO DISK = ''' + @backupPath + @fileName + ''' -- WITH --You can add parameter to here'
            EXEC(@sql4)

            -- Log backup operation
            INSERT INTO dbo.BackupLog (DatabaseName, BackupType, BackupPath, BackupFileName, BackupDateTime)
            VALUES (@dbName, 'Full', @backupPath, @fileName, GETDATE())
        END
        ELSE IF @backupType = 'diff' -- Differential backup
        BEGIN
            SET @fileName = @dbName + 'Diff' + @dateTime + '.dif'
            DECLARE @sql5 NVARCHAR(MAX)
            SET @sql5 = 'BACKUP DATABASE ' + QUOTENAME(@dbName) + ' TO DISK = ''' + @backupPath + @fileName + ''' -- WITH --You can add parameter to here'
            EXEC(@sql5)

            -- Log backup operation
            INSERT INTO dbo.BackupLog (DatabaseName, BackupType, BackupPath, BackupFileName, BackupDateTime)
            VALUES (@dbName, 'Diff', @backupPath, @fileName, GETDATE())
        END
        ELSE IF @backupType = 'trn' -- Transaction log backup
        BEGIN
            SET @fileName = @dbName + 'Trn' + @dateTime + '.trn'
            DECLARE @sql6 NVARCHAR(MAX)
            SET @sql6 = 'BACKUP LOG ' + QUOTENAME(@dbName) + ' TO DISK = ''' + @backupPath + @fileName + ''' -- WITH --You can add parameter to here'
            EXEC(@sql6)

            -- Log backup operation
            INSERT INTO dbo.BackupLog (DatabaseName, BackupType, BackupPath, BackupFileName, BackupDateTime)
            VALUES (@dbName, 'Trn', @backupPath, @fileName, GETDATE())
        END
    END
END
