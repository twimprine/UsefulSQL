-- Set the base backup directory
DECLARE @BackupPathBase NVARCHAR(255) = 'S:\SQLBackups\'  -- Update as needed

DECLARE @DatabaseName NVARCHAR(128)
DECLARE @LogFileName NVARCHAR(128)
DECLARE @SQL NVARCHAR(MAX)
DECLARE @Timestamp NVARCHAR(20)

-- Get timestamp string
SET @Timestamp = REPLACE(CONVERT(NVARCHAR, GETDATE(), 120), ':', '-')
SET @Timestamp = REPLACE(@Timestamp, ' ', '_')  -- Format: YYYY-MM-DD_HH-MM-SS

DECLARE db_cursor CURSOR FOR
SELECT name 
FROM sys.databases 
WHERE database_id > 4 -- skip system DBs
AND state_desc = 'ONLINE'

OPEN db_cursor  
FETCH NEXT FROM db_cursor INTO @DatabaseName  

WHILE @@FETCH_STATUS = 0  
BEGIN  
    PRINT 'Processing database: ' + @DatabaseName

    -- 1. Full backup before changes (precautionary)
    SET @SQL = '
    BACKUP DATABASE [' + @DatabaseName + '] 
    TO DISK = N''' + @BackupPathBase + @DatabaseName + '_BeforeChange_' + @Timestamp + '.bak'' 
    WITH INIT, COMPRESSION;'
    EXEC(@SQL)

    -- 2. Set recovery model to SIMPLE (if not already)
    SET @SQL = '
    IF EXISTS (
        SELECT 1 FROM sys.databases 
        WHERE name = ''' + @DatabaseName + ''' 
        AND recovery_model_desc <> ''SIMPLE'')
    BEGIN
        ALTER DATABASE [' + @DatabaseName + '] SET RECOVERY SIMPLE;
    END'
    EXEC(@SQL)

    -- 3. Shrink transaction log file
    SELECT TOP 1 @LogFileName = mf.name
    FROM sys.master_files mf
    WHERE mf.database_id = DB_ID(@DatabaseName)
    AND mf.type_desc = 'LOG'

    SET @SQL = '
    USE [' + @DatabaseName + ']; 
    DBCC SHRINKFILE ([' + @LogFileName + '], 1);'
    EXEC(@SQL)

    -- 4. Final full backup (Post-cleanup)
    SET @SQL = '
    BACKUP DATABASE [' + @DatabaseName + '] 
    TO DISK = N''' + @BackupPathBase + @DatabaseName + '_Final_' + @Timestamp + '.bak'' 
    WITH INIT, COMPRESSION;'
    EXEC(@SQL)

    FETCH NEXT FROM db_cursor INTO @DatabaseName  
END  

CLOSE db_cursor  
DEALLOCATE db_cursor  
