USE [DB_NAME]
GO
CREATE PROCEDURE ShrinkAllLogFiles
    @DatabaseName SYSNAME = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- Create Log table if not exists
    IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'ShrinkLog') AND type in (N'U'))
    BEGIN
        CREATE TABLE ShrinkLog (
            ID INT IDENTITY(1,1) PRIMARY KEY,
            DatabaseName NVARCHAR(128),
            LogFileName NVARCHAR(128),
            ShrinkDate DATETIME,
            OriginalSizeMB INT,
            ShrunkSizeMB INT,
            Status NVARCHAR(50)
        );
    END

    DECLARE @SQL NVARCHAR(MAX);
    DECLARE @DBName NVARCHAR(128);
    DECLARE @LogFileName NVARCHAR(128);
    DECLARE @OriginalSizeMB INT;
    DECLARE @ShrunkSizeMB INT;
    DECLARE @Status NVARCHAR(50);

    -- Cursor for databases
    DECLARE db_cursor CURSOR FOR
    SELECT name
    FROM sys.databases
    WHERE state = 0 -- Only online databases
    AND (@DatabaseName IS NULL AND name NOT IN ('master', 'tempdb', 'model', 'msdb') --Skip the system databases
         OR @DatabaseName IS NOT NULL AND name = @DatabaseName); --Or selected database

    OPEN db_cursor;
    FETCH NEXT FROM db_cursor INTO @DBName;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        BEGIN TRY
            -- Log file name and original size
            SELECT @LogFileName = name,
                   @OriginalSizeMB = size * 8 / 1024
            FROM sys.master_files
            WHERE type = 1 AND database_id = DB_ID(@DBName);

            -- Shrink the file
            SET @SQL = 'USE ' + QUOTENAME(@DBName) + ';
                        DBCC SHRINKFILE (' + QUOTENAME(@LogFileName) + ', 1);';
            EXEC sp_executesql @SQL;

            -- Shrinked size
            SELECT @ShrunkSizeMB = size * 8 / 1024
            FROM sys.master_files
            WHERE type = 1 AND database_id = DB_ID(@DBName);

            SET @Status = 'Success';
        END TRY
        BEGIN CATCH
            SET @Status = 'Failure';
            SET @ShrunkSizeMB = NULL;
        END CATCH;

        -- Insert log 
        INSERT INTO ShrinkLog (DatabaseName, LogFileName, ShrinkDate, OriginalSizeMB, ShrunkSizeMB, Status)
        VALUES (@DBName, @LogFileName, GETDATE(), @OriginalSizeMB, @ShrunkSizeMB, @Status);

        FETCH NEXT FROM db_cursor INTO @DBName;
    END

    CLOSE db_cursor;
    DEALLOCATE db_cursor;
END;
