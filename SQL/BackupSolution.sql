/*
================================================================================
BACKUP SOLUTION AUDIT SCRIPT
================================================================================

PURPOSE:
This script analyzes the current backup configuration and strategy for all
databases on a SQL Server instance. It provides comprehensive information
about backup frequencies, locations, retention policies, and identifies
potential gaps in backup coverage.

DESCRIPTION:
The script examines backup history from msdb database to determine current
backup practices and provides recommendations for backup strategy improvements.
It analyzes full, differential, and transaction log backup patterns to assess
the overall backup health of the SQL Server environment.

OUTPUT SECTIONS:
1. Backup Solution Summary
2. Backup Location Analysis
3. Backup Frequency Analysis
4. Database Backup Status
5. Backup Retention Analysis
6. Backup Configuration Recommendations

USAGE:
1. Execute this script against any SQL Server instance
2. Review results for backup strategy assessment
3. Use for compliance verification and improvement planning
4. Identify databases with inadequate backup coverage

REQUIREMENTS:
- SQL Server 2005 or later
- Access to msdb database
- VIEW ANY DATABASE permission
- sysadmin or backup operator permissions

AUTHOR: Thomas Wimprine
CREATED: 2025-06-18
LAST MODIFIED: 2025-06-18
================================================================================
*/

PRINT '================================================================================'
PRINT 'BACKUP SOLUTION AUDIT - ' + CONVERT(VARCHAR, GETDATE(), 120)
PRINT '================================================================================'
PRINT ''

-- ============================================================================
-- SECTION 1: BACKUP SOLUTION SUMMARY
-- 
-- This section provides an overview of the backup infrastructure and recent
-- backup activity across all databases.
-- 
-- Key concepts:
-- - Full Backup: Complete copy of database (foundation for all recovery)
-- - Differential Backup: Changes since last full backup
-- - Transaction Log Backup: Continuous log of database changes (FULL recovery model)
-- - Backup Media: Where backups are stored (disk, tape, network)
-- - RTO/RPO: Recovery Time/Point Objectives (how fast/how much data loss acceptable)
-- ============================================================================
PRINT '1. BACKUP SOLUTION SUMMARY'
PRINT 'Analyzing backup methods and recent activity...'
PRINT ''
PRINT '-------------------------'

-- Primary backup method analysis
;WITH BackupMethods AS (
    SELECT 
        CASE 
            WHEN physical_device_name LIKE '\\%' THEN 'Network Share'
            WHEN physical_device_name LIKE '%:\%' AND physical_device_name NOT LIKE 'C:\%' THEN 'Local Drive (Non-System)'
            WHEN physical_device_name LIKE 'C:\%' THEN 'Local Drive (System)'
            WHEN physical_device_name LIKE 'https://%' OR physical_device_name LIKE 'URL=%' THEN 'Cloud/URL'
            WHEN device_type = 2 THEN 'Tape Device'
            WHEN device_type = 102 THEN 'Virtual Device'
            ELSE 'Other/Unknown'
        END AS BackupMethod,
        COUNT(*) AS BackupCount
    FROM msdb.dbo.backupset bs
        JOIN msdb.dbo.backupmediafamily bmf ON bs.media_set_id = bmf.media_set_id
    WHERE bs.backup_finish_date >= DATEADD(day, -30, GETDATE())  -- Last 30 days
    GROUP BY 
        CASE 
            WHEN physical_device_name LIKE '\\%' THEN 'Network Share'
            WHEN physical_device_name LIKE '%:\%' AND physical_device_name NOT LIKE 'C:\%' THEN 'Local Drive (Non-System)'
            WHEN physical_device_name LIKE 'C:\%' THEN 'Local Drive (System)'
            WHEN physical_device_name LIKE 'https://%' OR physical_device_name LIKE 'URL=%' THEN 'Cloud/URL'
            WHEN device_type = 2 THEN 'Tape Device'
            WHEN device_type = 102 THEN 'Virtual Device'
            ELSE 'Other/Unknown'
        END
)
SELECT 
    'Backup Solution' AS [Category],
    'Primary Backup Method' AS [Information_Type],
    BackupMethod AS [Value],
    CAST(BackupCount AS VARCHAR(10)) + ' backups in last 30 days' AS [Description]
FROM BackupMethods
WHERE BackupCount = (SELECT MAX(BackupCount) FROM BackupMethods);

PRINT ''

-- ============================================================================
-- SECTION 2: BACKUP LOCATION ANALYSIS
-- ============================================================================
PRINT '2. BACKUP LOCATION ANALYSIS'
PRINT '---------------------------'

-- Backup location distribution
SELECT 
    'Backup Location' AS [Category],
    CASE 
        WHEN physical_device_name LIKE '\\%' THEN 'Network/UNC Path'
        WHEN physical_device_name LIKE '%:\%' AND physical_device_name NOT LIKE 'C:\%' THEN 'Local Drive (Non-System)'
        WHEN physical_device_name LIKE 'C:\%' THEN 'Local Drive (System)'
        WHEN physical_device_name LIKE 'https://%' OR physical_device_name LIKE 'URL=%' THEN 'Cloud/URL'
        WHEN device_type = 2 THEN 'Tape Device'
        WHEN device_type = 102 THEN 'Virtual Device'
        ELSE 'Other/Unknown'
    END AS [Information_Type],
    COUNT(DISTINCT bs.database_name) AS [Value],
    'Databases using this backup location type' AS [Description]
FROM msdb.dbo.backupset bs
    JOIN msdb.dbo.backupmediafamily bmf ON bs.media_set_id = bmf.media_set_id
WHERE bs.backup_finish_date >= DATEADD(day, -30, GETDATE())
    AND bs.database_name NOT IN ('master', 'model', 'msdb', 'tempdb')  -- Exclude system databases
GROUP BY 
    CASE 
        WHEN physical_device_name LIKE '\\%' THEN 'Network/UNC Path'
        WHEN physical_device_name LIKE '%:\%' AND physical_device_name NOT LIKE 'C:\%' THEN 'Local Drive (Non-System)'
        WHEN physical_device_name LIKE 'C:\%' THEN 'Local Drive (System)'
        WHEN physical_device_name LIKE 'https://%' OR physical_device_name LIKE 'URL=%' THEN 'Cloud/URL'
        WHEN device_type = 2 THEN 'Tape Device'
        WHEN device_type = 102 THEN 'Virtual Device'
        ELSE 'Other/Unknown'
    END
ORDER BY [Value] DESC;

-- Common backup paths
SELECT TOP 10
    'Common Backup Paths' AS [Category],
    LEFT(physical_device_name, 50) AS [Backup_Path],
    COUNT(*) AS [Usage_Count],
    COUNT(DISTINCT bs.database_name) AS [Database_Count]
FROM msdb.dbo.backupset bs
    JOIN msdb.dbo.backupmediafamily bmf ON bs.media_set_id = bmf.media_set_id
WHERE bs.backup_finish_date >= DATEADD(day, -30, GETDATE())
GROUP BY LEFT(physical_device_name, 50)
ORDER BY [Usage_Count] DESC;

PRINT ''

-- ============================================================================
-- SECTION 3: BACKUP FREQUENCY ANALYSIS
-- 
-- This section analyzes how often different types of backups are performed.
-- Backup frequency directly impacts data recovery capabilities and compliance.
-- 
-- Key concepts:
-- - Full Backup Frequency: How often complete database copies are made
-- - Differential Frequency: How often changed data is backed up
-- - Log Backup Frequency: How often transaction logs are backed up (affects data loss)
-- - Backup Windows: Time periods when backups can run without impact
-- ============================================================================
PRINT '3. BACKUP FREQUENCY ANALYSIS'
PRINT 'Analyzing backup frequency patterns...'
PRINT ''
PRINT '----------------------------'

-- Full backup frequency
SELECT 
    'Full Backup' AS [Category],
    'Frequency' AS [Information_Type],
    CASE 
        WHEN AVG(CAST(DaysBetweenBackups AS FLOAT)) <= 1 THEN 'Daily or more frequent'
        WHEN AVG(CAST(DaysBetweenBackups AS FLOAT)) <= 7 THEN 'Weekly (' + CAST(ROUND(AVG(CAST(DaysBetweenBackups AS FLOAT)), 1) AS VARCHAR(10)) + ' days avg)'
        WHEN AVG(CAST(DaysBetweenBackups AS FLOAT)) <= 30 THEN 'Monthly (' + CAST(ROUND(AVG(CAST(DaysBetweenBackups AS FLOAT)), 1) AS VARCHAR(10)) + ' days avg)'
        ELSE 'Infrequent (' + CAST(ROUND(AVG(CAST(DaysBetweenBackups AS FLOAT)), 1) AS VARCHAR(10)) + ' days avg)'
    END AS [Value],
    'Average frequency of full backups across user databases' AS [Description]
FROM (
    SELECT 
        database_name,
        DATEDIFF(day, 
            LAG(backup_finish_date) OVER (PARTITION BY database_name ORDER BY backup_finish_date),
            backup_finish_date
        ) AS DaysBetweenBackups
    FROM msdb.dbo.backupset
    WHERE type = 'D'  -- Full backups
        AND backup_finish_date >= DATEADD(day, -90, GETDATE())
        AND database_name NOT IN ('master', 'model', 'msdb', 'tempdb')
) AS FullBackupGaps
WHERE DaysBetweenBackups IS NOT NULL;

-- Differential backup frequency
SELECT 
    'Differential' AS [Category],
    'Frequency' AS [Information_Type],
    CASE 
        WHEN COUNT(*) = 0 THEN 'Not Used'
        WHEN AVG(CAST(DaysBetweenBackups AS FLOAT)) <= 1 THEN 'Daily or more frequent'
        WHEN AVG(CAST(DaysBetweenBackups AS FLOAT)) <= 7 THEN 'Weekly (' + CAST(ROUND(AVG(CAST(DaysBetweenBackups AS FLOAT)), 1) AS VARCHAR(10)) + ' days avg)'
        ELSE 'Infrequent (' + CAST(ROUND(AVG(CAST(DaysBetweenBackups AS FLOAT)), 1) AS VARCHAR(10)) + ' days avg)'
    END AS [Value],
    CASE 
        WHEN COUNT(*) = 0 THEN 'No differential backups found in last 90 days'
        ELSE 'Average frequency of differential backups'
    END AS [Description]
FROM (
    SELECT 
        database_name,
        DATEDIFF(day, 
            LAG(backup_finish_date) OVER (PARTITION BY database_name ORDER BY backup_finish_date),
            backup_finish_date
        ) AS DaysBetweenBackups
    FROM msdb.dbo.backupset
    WHERE type = 'I'  -- Differential backups
        AND backup_finish_date >= DATEADD(day, -90, GETDATE())
        AND database_name NOT IN ('master', 'model', 'msdb', 'tempdb')
) AS DiffBackupGaps
WHERE DaysBetweenBackups IS NOT NULL;

-- Transaction log backup frequency
SELECT 
    'Transaction Log' AS [Category],
    'Frequency' AS [Information_Type],
    CASE 
        WHEN COUNT(*) = 0 THEN 'Not Used'
        WHEN AVG(CAST(MinutesBetweenBackups AS FLOAT)) <= 15 THEN 'Every 15 minutes or less'
        WHEN AVG(CAST(MinutesBetweenBackups AS FLOAT)) <= 60 THEN 'Hourly (' + CAST(ROUND(AVG(CAST(MinutesBetweenBackups AS FLOAT)), 0) AS VARCHAR(10)) + ' min avg)'
        WHEN AVG(CAST(MinutesBetweenBackups AS FLOAT)) <= 1440 THEN 'Daily (' + CAST(ROUND(AVG(CAST(MinutesBetweenBackups AS FLOAT))/60, 1) AS VARCHAR(10)) + ' hours avg)'
        ELSE 'Infrequent (' + CAST(ROUND(AVG(CAST(MinutesBetweenBackups AS FLOAT))/60, 1) AS VARCHAR(10)) + ' hours avg)'
    END AS [Value],
    CASE 
        WHEN COUNT(*) = 0 THEN 'No transaction log backups found'
        ELSE 'Average frequency of transaction log backups'
    END AS [Description]
FROM (
    SELECT 
        database_name,
        DATEDIFF(minute, 
            LAG(backup_finish_date) OVER (PARTITION BY database_name ORDER BY backup_finish_date),
            backup_finish_date
        ) AS MinutesBetweenBackups
    FROM msdb.dbo.backupset
    WHERE type = 'L'  -- Log backups
        AND backup_finish_date >= DATEADD(day, -7, GETDATE())  -- Last week only for log frequency
        AND database_name NOT IN ('master', 'model', 'msdb', 'tempdb')
) AS LogBackupGaps
WHERE MinutesBetweenBackups IS NOT NULL;

PRINT ''

-- ============================================================================
-- SECTION 4: DATABASE BACKUP STATUS
-- ============================================================================
PRINT '4. DATABASE BACKUP STATUS'
PRINT '------------------------'

-- Individual database backup summary
;WITH BackupSummary AS (
    SELECT 
        d.name AS DatabaseName,
        d.recovery_model_desc,
        MAX(CASE WHEN bs.type = 'D' THEN bs.backup_finish_date END) AS LastFullBackup,
        MAX(CASE WHEN bs.type = 'I' THEN bs.backup_finish_date END) AS LastDiffBackup,
        MAX(CASE WHEN bs.type = 'L' THEN bs.backup_finish_date END) AS LastLogBackup,
        DATEDIFF(day, MAX(CASE WHEN bs.type = 'D' THEN bs.backup_finish_date END), GETDATE()) AS DaysSinceFullBackup,
        DATEDIFF(hour, MAX(CASE WHEN bs.type = 'L' THEN bs.backup_finish_date END), GETDATE()) AS HoursSinceLogBackup
    FROM sys.databases d
        LEFT JOIN msdb.dbo.backupset bs ON d.name = bs.database_name
    WHERE d.database_id > 4  -- Exclude system databases
    GROUP BY d.name, d.recovery_model_desc
)
SELECT 
    'Database Backup Status' AS [Category],
    DatabaseName AS [Database_Name],
    recovery_model_desc AS [Recovery_Model],
    CASE 
        WHEN LastFullBackup IS NULL THEN 'NEVER'
        WHEN DaysSinceFullBackup = 0 THEN 'Today'
        WHEN DaysSinceFullBackup = 1 THEN 'Yesterday'
        ELSE CAST(DaysSinceFullBackup AS VARCHAR(10)) + ' days ago'
    END AS [Last_Full_Backup],
    CASE 
        WHEN LastDiffBackup IS NULL THEN 'Never'
        ELSE CAST(DATEDIFF(day, LastDiffBackup, GETDATE()) AS VARCHAR(10)) + ' days ago'
    END AS [Last_Diff_Backup],
    CASE 
        WHEN recovery_model_desc = 'SIMPLE' THEN 'N/A (Simple Recovery)'
        WHEN LastLogBackup IS NULL THEN 'NEVER'
        WHEN HoursSinceLogBackup = 0 THEN 'This hour'
        WHEN HoursSinceLogBackup <= 24 THEN CAST(HoursSinceLogBackup AS VARCHAR(10)) + ' hours ago'
        ELSE CAST(HoursSinceLogBackup/24 AS VARCHAR(10)) + ' days ago'
    END AS [Last_Log_Backup],
    CASE 
        WHEN LastFullBackup IS NULL THEN 'CRITICAL: No backups found'
        WHEN DaysSinceFullBackup > 7 THEN 'WARNING: Full backup overdue'
        WHEN recovery_model_desc = 'FULL' AND LastLogBackup IS NULL THEN 'WARNING: No log backups'
        WHEN recovery_model_desc = 'FULL' AND HoursSinceLogBackup > 60 THEN 'CAUTION: Log backup overdue'
        ELSE 'OK'
    END AS [Backup_Status]
FROM BackupSummary
ORDER BY 
    CASE 
        WHEN LastFullBackup IS NULL THEN 1
        WHEN DaysSinceFullBackup > 7 THEN 2
        WHEN recovery_model_desc = 'FULL' AND LastLogBackup IS NULL THEN 3
        ELSE 4
    END,
    DaysSinceFullBackup DESC;

PRINT ''

-- ============================================================================
-- SECTION 5: BACKUP RETENTION ANALYSIS
-- ============================================================================
PRINT '5. BACKUP RETENTION ANALYSIS'
PRINT '----------------------------'

-- Backup retention analysis
SELECT 
    'Retention' AS [Category],
    'Backup Retention Period' AS [Information_Type],
    CASE 
        WHEN MIN(DATEDIFF(day, backup_start_date, GETDATE())) <= 7 THEN 'Short Term (1 week or less)'
        WHEN MIN(DATEDIFF(day, backup_start_date, GETDATE())) <= 30 THEN 'Medium Term (' + CAST(MIN(DATEDIFF(day, backup_start_date, GETDATE())) AS VARCHAR(10)) + ' days)'
        WHEN MIN(DATEDIFF(day, backup_start_date, GETDATE())) <= 90 THEN 'Long Term (' + CAST(MIN(DATEDIFF(day, backup_start_date, GETDATE())) AS VARCHAR(10)) + ' days)'
        ELSE 'Extended Term (' + CAST(MIN(DATEDIFF(day, backup_start_date, GETDATE())) AS VARCHAR(10)) + ' days)'
    END AS [Value],
    'Oldest backup found in msdb indicates retention period' AS [Description]
FROM msdb.dbo.backupset
WHERE database_name NOT IN ('master', 'model', 'msdb', 'tempdb');

-- Backup retention by type
SELECT 
    'Retention Details' AS [Category],
    CASE type
        WHEN 'D' THEN 'Full Backup Retention'
        WHEN 'I' THEN 'Differential Backup Retention'
        WHEN 'L' THEN 'Log Backup Retention'
        ELSE 'Other Backup Retention'
    END AS [Backup_Type],
    MIN(DATEDIFF(day, backup_start_date, GETDATE())) AS [Oldest_Backup_Days],
    MAX(DATEDIFF(day, backup_start_date, GETDATE())) AS [Newest_Backup_Days],
    COUNT(*) AS [Total_Backup_Records]
FROM msdb.dbo.backupset
WHERE database_name NOT IN ('master', 'model', 'msdb', 'tempdb')
GROUP BY type
ORDER BY [Oldest_Backup_Days];

PRINT ''

-- ============================================================================
-- SECTION 6: BACKUP CONFIGURATION RECOMMENDATIONS
-- ============================================================================
PRINT '6. BACKUP CONFIGURATION RECOMMENDATIONS'
PRINT '---------------------------------------'

-- Backup recommendations
;WITH BackupIssues AS (
    SELECT 
        d.name AS DatabaseName,
        d.recovery_model_desc,
        MAX(CASE WHEN bs.type = 'D' THEN bs.backup_finish_date END) AS LastFullBackup,
        MAX(CASE WHEN bs.type = 'L' THEN bs.backup_finish_date END) AS LastLogBackup,
        CASE 
            WHEN MAX(CASE WHEN bs.type = 'D' THEN bs.backup_finish_date END) IS NULL THEN 'No backups configured'
            WHEN DATEDIFF(day, MAX(CASE WHEN bs.type = 'D' THEN bs.backup_finish_date END), GETDATE()) > 7 THEN 'Full backup frequency too low'
            WHEN d.recovery_model_desc = 'FULL' AND MAX(CASE WHEN bs.type = 'L' THEN bs.backup_finish_date END) IS NULL THEN 'Missing log backups for FULL recovery'
            WHEN d.recovery_model_desc = 'FULL' AND DATEDIFF(hour, MAX(CASE WHEN bs.type = 'L' THEN bs.backup_finish_date END), GETDATE()) > 60 THEN 'Log backup frequency too low'
            ELSE 'Backup configuration acceptable'
        END AS Issue,
        CASE 
            WHEN MAX(CASE WHEN bs.type = 'D' THEN bs.backup_finish_date END) IS NULL THEN 'Implement daily full backups immediately'
            WHEN DATEDIFF(day, MAX(CASE WHEN bs.type = 'D' THEN bs.backup_finish_date END), GETDATE()) > 7 THEN 'Increase full backup frequency to daily'
            WHEN d.recovery_model_desc = 'FULL' AND MAX(CASE WHEN bs.type = 'L' THEN bs.backup_finish_date END) IS NULL THEN 'Implement transaction log backups every 15-30 minutes'
            WHEN d.recovery_model_desc = 'FULL' AND DATEDIFF(hour, MAX(CASE WHEN bs.type = 'L' THEN bs.backup_finish_date END), GETDATE()) > 60 THEN 'Increase log backup frequency to every 15-30 minutes'
            ELSE 'Continue current backup schedule'
        END AS Recommendation
    FROM sys.databases d
        LEFT JOIN msdb.dbo.backupset bs ON d.name = bs.database_name
    WHERE d.database_id > 4
    GROUP BY d.name, d.recovery_model_desc
)
SELECT 
    'Backup Recommendations' AS [Category],
    DatabaseName AS [Database_Name],
    recovery_model_desc AS [Recovery_Model],
    Issue AS [Current_Issue],
    Recommendation AS [Recommended_Action]
FROM BackupIssues
WHERE Issue <> 'Backup configuration acceptable'
ORDER BY 
    CASE 
        WHEN Issue = 'No backups configured' THEN 1
        WHEN Issue = 'Missing log backups for FULL recovery' THEN 2
        WHEN Issue = 'Full backup frequency too low' THEN 3
        ELSE 4
    END;

PRINT ''
PRINT '================================================================================'
PRINT 'BACKUP SOLUTION AUDIT COMPLETE - ' + CONVERT(VARCHAR, GETDATE(), 120)
PRINT '================================================================================'

/*
ADDITIONAL QUERIES FOR DETAILED ANALYSIS:

-- Backup size trends
SELECT 
    database_name,
    type,
    AVG(backup_size / 1024.0 / 1024.0) AS AvgBackupSizeMB,
    AVG(compressed_backup_size / 1024.0 / 1024.0) AS AvgCompressedSizeMB,
    AVG(CASE WHEN backup_size > 0 THEN (backup_size - compressed_backup_size) * 100.0 / backup_size ELSE 0 END) AS CompressionRatio
FROM msdb.dbo.backupset
WHERE backup_finish_date >= DATEADD(day, -30, GETDATE())
    AND database_name NOT IN ('master', 'model', 'msdb', 'tempdb')
GROUP BY database_name, type
ORDER BY database_name, type;

-- Backup device usage
SELECT 
    bmf.physical_device_name,
    COUNT(DISTINCT bs.database_name) AS DatabaseCount,
    COUNT(*) AS BackupCount,
    MIN(bs.backup_start_date) AS FirstBackup,
    MAX(bs.backup_finish_date) AS LastBackup
FROM msdb.dbo.backupset bs
    JOIN msdb.dbo.backupmediafamily bmf ON bs.media_set_id = bmf.media_set_id
WHERE bs.backup_finish_date >= DATEADD(day, -90, GETDATE())
GROUP BY bmf.physical_device_name
ORDER BY BackupCount DESC;
*/
