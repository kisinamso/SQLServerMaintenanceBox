USE [DB_NAME]
GO
CREATE PROCEDURE ShrinkAllLogFiles
    @DatabaseName SYSNAME = NULL
AS
  -- ============================@kisinamso=========================
-- == Select the Database and Create the Stored Procedure         ==
-- == 1. Use a specific database and create the stored procedure  ==
-- ==    named `ShrinkAllLogFiles`.                               ==
-- == 2. Define an optional parameter for the database name       ==
-- ==    (`@DatabaseName`).                                       ==
-- ============================@kisinamso===========================
-- == Create ShrinkLog Table if it Doesn't Exist                  ==
-- == 1. Check if the `ShrinkLog` table exists.                   ==
-- == 2. If it doesn't exist, create the table to store shrink    ==
-- ==    logs, including ID, DatabaseName, LogFileName,           ==
-- ==    ShrinkDate, OriginalSizeMB, ShrunkSizeMB, and Status.    ==
-- ============================@kisinamso===========================
-- == Declare Variables                                           ==
-- == 1. Declare necessary variables for SQL commands, database   ==
-- ==    names, log file names, sizes, and status.                ==
-- ============================@kisinamso===========================
-- == Cursor to Iterate Over All Online Databases                 ==
-- == 1. Declare a cursor to select all online databases,         ==
-- ==    excluding system databases unless specified.             ==
-- == 2. Iterate through each database using the cursor.          ==
-- ============================@kisinamso===========================
-- == Shrink Log Files                                            ==
-- == 1. For each database, determine the log file name and       ==
-- ==    original size.                                           ==
-- == 2. Generate and execute the DBCC SHRINKFILE command to      ==
-- ==    shrink the log file.                                     ==
-- ============================@kisinamso===========================
-- == Log the Shrink Operation                                    ==
-- == 1. After shrinking the log file, determine the shrunk size. ==
-- == 2. Use TRY...CATCH to log the operation's success or failure==
-- ==    along with the relevant details.                         ==
-- ============================@kisinamso===========================
-- == Clean Up                                                    ==
-- == 1. Close and deallocate the database cursor after all       ==
-- ==    databases have been processed.                           ==
-- ============================@kisinamso===========================
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
