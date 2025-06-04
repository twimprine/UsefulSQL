/*
================================================================================
CHANGE ALL DATABASES TO SIMPLE RECOVERY MODEL SCRIPT
================================================================================

PURPOSE:
This script changes the recovery model of all user databases from FULL or 
BULK_LOGGED to SIMPLE recovery model. It also performs full backups before 
and after the change, and shrinks transaction log files to reclaim disk space.

DESCRIPTION:
The script iterates through all user databases (excluding system databases) and:
1. Creates a full backup before making changes (safety precaution)
2. Changes the recovery model to SIMPLE if not already set
3. Shrinks the transaction log file to minimal size
4. Creates a final full backup after cleanup

USAGE:
1. Update the @BackupPathBase variable to your desired backup location
2. Ensure the backup directory exists and SQL Server has write permissions
3. Execute the script (preferably during maintenance window)
4. Monitor output for any errors or issues

IMPORTANT CONSIDERATIONS:
- SIMPLE recovery model means point-in-time recovery is not possible
- Only use this for development/test environments or when log shipping/mirroring is not needed
- Ensure adequate disk space for backups before running
- This will break log shipping chains if they exist
- Consider transaction log backup strategies before implementing

REQUIREMENTS:
- SQL Server 2005 or later
- sysadmin permissions
- Sufficient disk space for backups
- Write permissions to backup directory

RECOVERY MODELS EXPLAINED:
- FULL: Allows point-in-time recovery, requires log backups
- SIMPLE: Only full and differential backups, logs auto-truncate
- BULK_LOGGED: Hybrid model for bulk operations

AUTHOR: Thomas Wimprine
CREATED: Various
LAST MODIFIED: 2025-06-04
================================================================================
*/

-- Set the base backup directory - UPDATE THIS PATH AS NEEDED
DECLARE @BackupPathBase NVARCHAR(255) = 'S:\SQLBackups\'  -- Update as needed

-- Declare variables for cursor operations
DECLARE @DatabaseName NVARCHAR(128)
DECLARE @LogFileName NVARCHAR(128)
DECLARE @SQL NVARCHAR(MAX)
DECLARE @Timestamp NVARCHAR(20)

-- Generate timestamp string for backup file naming
-- Format: YYYY-MM-DD_HH-MM-SS
SET @Timestamp = REPLACE(CONVERT(NVARCHAR, GETDATE(), 120), ':', '-')
SET @Timestamp = REPLACE(@Timestamp, ' ', '_')

-- Create cursor for all user databases that are online
DECLARE db_cursor CURSOR FOR
SELECT name 
FROM sys.databases 
WHERE database_id > 4 -- Skip system databases (master, model, msdb, tempdb)
AND state_desc = 'ONLINE' -- Only process online databases

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
