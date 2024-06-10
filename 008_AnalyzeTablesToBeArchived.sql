-- =============================@kisinamso==========================
-- == Please change all ENTER_DB_NAME with Ctrl+H shortkey        ==
-- ============================@kisinamso===========================
USE [ENTER_DB_NAME]
GO
CREATE PROCEDURE ManageAndCollectMetrics
@DatabaseName SYSNAME = NULL
AS
BEGIN
    BEGIN TRY
        -- 1. Create Table If Not Exists
        IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'TableMetrics')
        BEGIN
            CREATE TABLE [ENTER_DB_NAME].[dbo].[TableMetrics] (
                ID INT IDENTITY(1,1) PRIMARY KEY,
                DatabaseName NVARCHAR(128) COLLATE DATABASE_DEFAULT,
                SchemaName NVARCHAR(128) COLLATE DATABASE_DEFAULT,
                TableName NVARCHAR(128) COLLATE DATABASE_DEFAULT,
                RowCounts BIGINT,
                TotalSpaceKB BIGINT,
                CollectDateTime DATETIME DEFAULT GETDATE()
            );
        END

        IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'GrowthRates')
        BEGIN
            CREATE TABLE [ENTER_DB_NAME].[dbo].[GrowthRates] (
                ID INT IDENTITY(1,1) PRIMARY KEY,
                DatabaseName NVARCHAR(128) COLLATE DATABASE_DEFAULT,
                SchemaName NVARCHAR(128) COLLATE DATABASE_DEFAULT,
                TableName NVARCHAR(128) COLLATE DATABASE_DEFAULT,
                MetricType NVARCHAR(50) COLLATE DATABASE_DEFAULT,
                MonthlyGrowthRate FLOAT,
                YearlyGrowthRate FLOAT,
                CalculationDateTime DATETIME DEFAULT GETDATE()
            );
        END

        -- 2. Collecting Data
        DECLARE @DbName NVARCHAR(128)
        DECLARE @SQL NVARCHAR(MAX)

        DECLARE db_cursor CURSOR FOR
        SELECT name
        FROM sys.databases
        WHERE state_desc = 'ONLINE'  --Only Online Databases
        AND (@DatabaseName IS NULL AND name NOT IN('master','tempdb','model','msdb') --Skip the system databases
           OR @DatabaseName IS NOT NULL AND name = @DatabaseName); -- Or selected database
        OPEN db_cursor
        FETCH NEXT FROM db_cursor INTO @DbName

        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @SQL = '
                USE ' + QUOTENAME(@DbName) + ';
                INSERT INTO [ENTER_DB_NAME].[dbo].[TableMetrics] (DatabaseName, SchemaName, TableName, RowCounts, TotalSpaceKB)
                SELECT 
                    ''' + @DbName + ''', 
                    s.name COLLATE DATABASE_DEFAULT AS SchemaName, 
                    t.name COLLATE DATABASE_DEFAULT AS TableName, 
                    p.rows AS RowCounts, 
                    SUM(a.total_pages) * 8 AS TotalSpaceKB
                FROM 
                    sys.tables t
                INNER JOIN 
                    sys.schemas s ON t.schema_id = s.schema_id
                INNER JOIN      
                    sys.indexes i ON t.object_id = i.object_id
                INNER JOIN 
                    sys.partitions p ON i.object_id = p.object_id AND i.index_id = p.index_id
                INNER JOIN 
                    sys.allocation_units a ON p.partition_id = a.container_id
                WHERE 
                    t.is_ms_shipped = 0
                GROUP BY 
                    s.name, t.name, p.rows';

            EXEC sp_executesql @SQL
            FETCH NEXT FROM db_cursor INTO @DbName
        END

        CLOSE db_cursor
        DEALLOCATE db_cursor

-- 3. Calculate Incrase Rate
        DECLARE @StartDate DATETIME = DATEADD(MONTH, -1, GETDATE())
        DECLARE @StartDateYear DATETIME = DATEADD(YEAR, -1, GETDATE())

        -- Create Temp Tables
        IF OBJECT_ID('tempdb..#TempGrowthRates') IS NOT NULL
            DROP TABLE #TempGrowthRates;

        CREATE TABLE #TempGrowthRates (
            DatabaseName NVARCHAR(128) COLLATE DATABASE_DEFAULT,
            SchemaName NVARCHAR(128) COLLATE DATABASE_DEFAULT,
            TableName NVARCHAR(128) COLLATE DATABASE_DEFAULT,
            MetricType NVARCHAR(50) COLLATE DATABASE_DEFAULT,
            MonthlyGrowthRate FLOAT,
            YearlyGrowthRate FLOAT
        );

        -- Calculate incrase rate for RowCounts and insert into temp table
        INSERT INTO #TempGrowthRates (DatabaseName, SchemaName, TableName, MetricType, MonthlyGrowthRate, YearlyGrowthRate)
        SELECT 
            tm1.DatabaseName, 
            tm1.SchemaName, 
            tm1.TableName,
            'RowCounts' AS MetricType,
            CASE 
                WHEN tm2.RowCounts = 0 THEN NULL
                ELSE CAST(((tm1.RowCounts - tm2.RowCounts) * 1.0 / tm2.RowCounts) * 100 AS FLOAT)
            END AS MonthlyGrowthRate,
            CASE 
                WHEN tm3.RowCounts = 0 THEN NULL
                ELSE CAST(((tm1.RowCounts - tm3.RowCounts) * 1.0 / tm3.RowCounts) * 100 AS FLOAT)
            END AS YearlyGrowthRate
        FROM 
            TableMetrics tm1
        LEFT JOIN 
            TableMetrics tm2 ON tm1.DatabaseName = tm2.DatabaseName COLLATE DATABASE_DEFAULT 
                             AND tm1.SchemaName = tm2.SchemaName COLLATE DATABASE_DEFAULT 
                             AND tm1.TableName = tm2.TableName COLLATE DATABASE_DEFAULT 
                             AND CAST(tm2.CollectDateTime AS DATE) = CAST(@StartDate AS DATE)
        LEFT JOIN 
            TableMetrics tm3 ON tm1.DatabaseName = tm3.DatabaseName COLLATE DATABASE_DEFAULT 
                             AND tm1.SchemaName = tm3.SchemaName COLLATE DATABASE_DEFAULT 
                             AND tm1.TableName = tm3.TableName COLLATE DATABASE_DEFAULT 
                             AND CAST(tm3.CollectDateTime AS DATE) = CAST(@StartDateYear AS DATE)
        WHERE 
            CAST(tm1.CollectDateTime AS DATE) = CAST(GETDATE() AS DATE);

-- Calculate incrase rate for TotalSpaceKB and insert into temp table
        INSERT INTO #TempGrowthRates (DatabaseName, SchemaName, TableName, MetricType, MonthlyGrowthRate, YearlyGrowthRate)
        SELECT 
            tm1.DatabaseName, 
            tm1.SchemaName, 
            tm1.TableName,
            'TotalSpaceKB' AS MetricType,
            CASE 
                WHEN tm2.TotalSpaceKB = 0 THEN NULL
                ELSE CAST(((tm1.TotalSpaceKB - tm2.TotalSpaceKB) * 1.0 / tm2.TotalSpaceKB) * 100 AS FLOAT)
            END AS MonthlyGrowthRate,
            CASE 
                WHEN tm3.TotalSpaceKB = 0 THEN NULL
                ELSE CAST(((tm1.TotalSpaceKB - tm3.TotalSpaceKB) * 1.0 / tm3.TotalSpaceKB) * 100 AS FLOAT)
            END AS YearlyGrowthRate
        FROM 
            TableMetrics tm1
        LEFT JOIN 
            TableMetrics tm2 ON tm1.DatabaseName = tm2.DatabaseName COLLATE DATABASE_DEFAULT 
                             AND tm1.SchemaName = tm2.SchemaName COLLATE DATABASE_DEFAULT 
                             AND tm1.TableName = tm2.TableName COLLATE DATABASE_DEFAULT 
                             AND CAST(tm2.CollectDateTime AS DATE) = CAST(@StartDate AS DATE)
        LEFT JOIN 
            TableMetrics tm3 ON tm1.DatabaseName = tm3.DatabaseName COLLATE DATABASE_DEFAULT 
                             AND tm1.SchemaName = tm3.SchemaName COLLATE DATABASE_DEFAULT 
                             AND tm1.TableName = tm3.TableName COLLATE DATABASE_DEFAULT 
                             AND CAST(tm3.CollectDateTime AS DATE) = CAST(@StartDateYear AS DATE)
        WHERE 
            CAST(tm1.CollectDateTime AS DATE) = CAST(GETDATE() AS DATE);

     
MERGE INTO [ENTER_DB_NAME].[dbo].[GrowthRates] AS target
USING (
    SELECT 
        DatabaseName,
        SchemaName,
        TableName,
        MetricType,
        MAX(MonthlyGrowthRate) AS MonthlyGrowthRate,
        MAX(YearlyGrowthRate) AS YearlyGrowthRate,
        GETDATE() AS CalculationDateTime
    FROM #TempGrowthRates
    GROUP BY 
        DatabaseName,
        SchemaName,
        TableName,
        MetricType
) AS source
ON target.DatabaseName = source.DatabaseName COLLATE DATABASE_DEFAULT
   AND target.SchemaName = source.SchemaName COLLATE DATABASE_DEFAULT
   AND target.TableName = source.TableName COLLATE DATABASE_DEFAULT
   AND target.MetricType = source.MetricType COLLATE DATABASE_DEFAULT
WHEN MATCHED THEN
    UPDATE SET 
        target.MonthlyGrowthRate = source.MonthlyGrowthRate,
        target.YearlyGrowthRate = source.YearlyGrowthRate,
        target.CalculationDateTime = source.CalculationDateTime
WHEN NOT MATCHED BY TARGET THEN
    INSERT (DatabaseName, SchemaName, TableName, MetricType, MonthlyGrowthRate, YearlyGrowthRate, CalculationDateTime)
    VALUES (source.DatabaseName, source.SchemaName, source.TableName, source.MetricType, source.MonthlyGrowthRate, source.YearlyGrowthRate, source.CalculationDateTime);

    END TRY
    BEGIN CATCH
        -- Select error messages
        SELECT 
            ERROR_NUMBER() AS ErrorNumber,
            ERROR_MESSAGE() AS ErrorMessage;
    END CATCH
END
