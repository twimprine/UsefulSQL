/*
================================================================================
DATABASE INFORMATION AUDIT SCRIPT
================================================================================

PURPOSE:
This script provides comprehensive database information for audit purposes,
including database counts, sizes, recovery models, and critical database
identification. It's designed to give a complete overview of the database
landscape on a SQL Server instance.

DESCRIPTION:
The script analyzes all user databases and provides key metrics for capacity
planning, backup strategies, and database management. It excludes system
databases and focuses on user databases that require administrative attention.

OUTPUT SECTIONS:
1. Database Count Summary
2. Database Size Analysis
3. Recovery Model Distribution
4. Individual Database Details
5. Critical Database Identification

USAGE:
1. Execute this script against any SQL Server instance
2. Review results for database inventory and planning
3. Use for capacity planning and backup strategy
4. Identify databases requiring special attention

REQUIREMENTS:
- SQL Server 2005 or later
- VIEW ANY DATABASE permission
- Access to sys.databases and sys.master_files

AUTHOR: Thomas Wimprine
CREATED: 2025-06-18
LAST MODIFIED: 2025-06-18
================================================================================
*/

PRINT '================================================================================'
PRINT 'DATABASE INFORMATION AUDIT - ' + CONVERT(VARCHAR, GETDATE(), 120)
PRINT '================================================================================'
PRINT ''

-- ============================================================================
-- SECTION 1: DATABASE COUNT SUMMARY
-- 
-- This section provides an overview of databases on the SQL Server instance.
-- Understanding the database landscape helps with resource planning and
-- management strategy.
-- 
-- Key concepts:
-- - User Databases: Application databases (excludes system databases)
-- - System Databases: master, model, msdb, tempdb (SQL Server internals)
-- - Database State: Online, Offline, Restoring, etc.
-- - Recovery Model: How transaction logs are managed
-- ============================================================================
PRINT '1. DATABASE COUNT SUMMARY'
PRINT 'Analyzing database inventory and distribution...'
PRINT ''
PRINT '------------------------'

SELECT 
    'Database Count' AS [Category],
    'Total User Databases' AS [Information_Type],
    COUNT(*) AS [Value],
    'Total number of user databases (excluding system)' AS [Description]
FROM sys.databases 
WHERE database_id > 4;  -- Exclude system databases

PRINT ''

-- ============================================================================
-- SECTION 2: DATABASE SIZE ANALYSIS
-- ============================================================================
PRINT '2. DATABASE SIZE ANALYSIS'
PRINT '------------------------'

-- Total Data Size across all user databases
;WITH DatabaseSizes AS (
    SELECT 
        db.name AS DatabaseName,
        SUM(CASE WHEN mf.type_desc = 'ROWS' THEN mf.size * 8.0 / 1024 / 1024 ELSE 0 END) AS DataSizeGB,
        SUM(CASE WHEN mf.type_desc = 'LOG' THEN mf.size * 8.0 / 1024 / 1024 ELSE 0 END) AS LogSizeGB,
        SUM(mf.size * 8.0 / 1024 / 1024) AS TotalSizeGB
    FROM sys.master_files mf
        JOIN sys.databases db ON db.database_id = mf.database_id
    WHERE db.database_id > 4  -- Exclude system databases
    GROUP BY db.name
)
SELECT 
    'Database Size' AS [Category],
    'Total Data Size (GB)' AS [Information_Type],
    CAST(ROUND(SUM(DataSizeGB), 2) AS VARCHAR(20)) AS [Value],
    'Total size of all user database data files' AS [Description]
FROM DatabaseSizes

UNION ALL

SELECT 
    'Database Size' AS [Category],
    'Total Log Size (GB)' AS [Information_Type],
    CAST(ROUND(SUM(LogSizeGB), 2) AS VARCHAR(20)) AS [Value],
    'Total size of all user database log files' AS [Description]
FROM DatabaseSizes

UNION ALL

SELECT 
    'Database Size' AS [Category],
    'Total Database Size (GB)' AS [Information_Type],
    CAST(ROUND(SUM(TotalSizeGB), 2) AS VARCHAR(20)) AS [Value],
    'Total size of all user databases (data + log)' AS [Description]
FROM DatabaseSizes

UNION ALL

SELECT 
    'Database Size' AS [Category],
    'Largest Database Size' AS [Information_Type],
    DatabaseName + ' (' + CAST(ROUND(TotalSizeGB, 2) AS VARCHAR(20)) + ' GB)' AS [Value],
    'Largest database by total size' AS [Description]
FROM DatabaseSizes
WHERE TotalSizeGB = (SELECT MAX(TotalSizeGB) FROM DatabaseSizes);

PRINT ''

-- ============================================================================
-- SECTION 3: RECOVERY MODEL DISTRIBUTION
-- 
-- Recovery models determine how SQL Server handles transaction logs and
-- backups. This affects backup strategies and data recovery capabilities.
-- 
-- Key concepts:
-- - SIMPLE: Minimal logging, log auto-truncates, point-in-time recovery not available
-- - FULL: Complete logging, requires log backups, allows point-in-time recovery
-- - BULK_LOGGED: Reduced logging for bulk operations, limited point-in-time recovery
-- ============================================================================
PRINT '3. RECOVERY MODEL DISTRIBUTION'
PRINT 'Analyzing recovery model settings across databases...'
PRINT ''
PRINT '------------------------------'

SELECT 
    'Recovery Model' AS [Category],
    recovery_model_desc AS [Information_Type],
    COUNT(*) AS [Value],
    CASE recovery_model_desc
        WHEN 'SIMPLE' THEN 'Databases using Simple recovery model'
        WHEN 'FULL' THEN 'Databases using Full recovery model'
        WHEN 'BULK_LOGGED' THEN 'Databases using Bulk-logged recovery model'
    END AS [Description]
FROM sys.databases
WHERE database_id > 4  -- Exclude system databases
GROUP BY recovery_model_desc
ORDER BY [Value] DESC;

PRINT ''

-- ============================================================================
-- SECTION 4: INDIVIDUAL DATABASE DETAILS
-- ============================================================================
PRINT '4. INDIVIDUAL DATABASE DETAILS'
PRINT '------------------------------'

-- Detailed information for each user database
;WITH DatabaseDetails AS (
    SELECT 
        db.name AS DatabaseName,
        db.database_id,
        db.create_date,
        db.recovery_model_desc,
        db.state_desc,
        db.compatibility_level,
        SUM(CASE WHEN mf.type_desc = 'ROWS' THEN mf.size * 8.0 / 1024 / 1024 ELSE 0 END) AS DataSizeGB,
        SUM(CASE WHEN mf.type_desc = 'LOG' THEN mf.size * 8.0 / 1024 / 1024 ELSE 0 END) AS LogSizeGB,
        SUM(mf.size * 8.0 / 1024 / 1024) AS TotalSizeGB,
        COUNT(CASE WHEN mf.type_desc = 'ROWS' THEN 1 END) AS DataFileCount,
        COUNT(CASE WHEN mf.type_desc = 'LOG' THEN 1 END) AS LogFileCount
    FROM sys.databases db
        JOIN sys.master_files mf ON db.database_id = mf.database_id
    WHERE db.database_id > 4  -- Exclude system databases
    GROUP BY db.name, db.database_id, db.create_date, db.recovery_model_desc, 
             db.state_desc, db.compatibility_level
)
SELECT 
    'Individual Database' AS [Category],
    DatabaseName AS [Database_Name],
    CASE 
        WHEN TotalSizeGB >= 1000 THEN CAST(ROUND(TotalSizeGB/1000, 2) AS VARCHAR(20)) + ' TB'
        ELSE CAST(ROUND(TotalSizeGB, 2) AS VARCHAR(20)) + ' GB'
    END AS [Total_Size],
    CASE 
        WHEN DataSizeGB >= 1000 THEN CAST(ROUND(DataSizeGB/1000, 2) AS VARCHAR(20)) + ' TB'
        ELSE CAST(ROUND(DataSizeGB, 2) AS VARCHAR(20)) + ' GB'
    END AS [Data_Size],
    CASE 
        WHEN LogSizeGB >= 1000 THEN CAST(ROUND(LogSizeGB/1000, 2) AS VARCHAR(20)) + ' TB'
        ELSE CAST(ROUND(LogSizeGB, 2) AS VARCHAR(20)) + ' GB'
    END AS [Log_Size],
    recovery_model_desc AS [Recovery_Model],
    state_desc AS [State],
    compatibility_level AS [Compatibility_Level],
    CAST(DataFileCount AS VARCHAR(5)) + '/' + CAST(LogFileCount AS VARCHAR(5)) AS [Data_Log_Files],
    create_date AS [Created_Date]
FROM DatabaseDetails
ORDER BY TotalSizeGB DESC;

PRINT ''

-- ============================================================================
-- SECTION 5: CRITICAL DATABASE IDENTIFICATION
-- ============================================================================
PRINT '5. CRITICAL DATABASE IDENTIFICATION'
PRINT '-----------------------------------'

-- Identify potentially critical databases based on various criteria
;WITH CriticalDatabases AS (
    SELECT 
        db.name AS DatabaseName,
        SUM(mf.size * 8.0 / 1024 / 1024) AS TotalSizeGB,
        db.recovery_model_desc,
        db.state_desc,
        CASE 
            WHEN SUM(mf.size * 8.0 / 1024 / 1024) > 100 THEN 'Large Database (>100GB)'
            WHEN db.recovery_model_desc = 'FULL' THEN 'Full Recovery Model'
            WHEN db.name LIKE '%prod%' OR db.name LIKE '%production%' THEN 'Production Database (by name)'
            WHEN db.name LIKE '%erp%' OR db.name LIKE '%crm%' OR db.name LIKE '%hr%' THEN 'Business Critical (by name)'
            WHEN db.name NOT LIKE '%test%' AND db.name NOT LIKE '%dev%' AND db.name NOT LIKE '%temp%' THEN 'Potential Production Database'
            ELSE 'Standard Database'
        END AS CriticalityIndicator
    FROM sys.databases db
        JOIN sys.master_files mf ON db.database_id = mf.database_id
    WHERE db.database_id > 4  -- Exclude system databases
    GROUP BY db.name, db.recovery_model_desc, db.state_desc
),
CriticalCount AS (
    SELECT COUNT(*) AS CriticalDBCount
    FROM CriticalDatabases
    WHERE CriticalityIndicator IN (
        'Large Database (>100GB)', 
        'Production Database (by name)', 
        'Business Critical (by name)'
    )
)
SELECT 
    'Critical Databases' AS [Category],
    'Mission Critical DBs' AS [Information_Type],
    CriticalDBCount AS [Value],
    'Databases identified as potentially mission critical' AS [Description]
FROM CriticalCount;

-- Detailed breakdown of critical databases
;WITH CriticalDatabasesDetail AS (
    SELECT 
        db.name AS DatabaseName,
        SUM(mf.size * 8.0 / 1024 / 1024) AS TotalSizeGB,
        db.recovery_model_desc,
        db.state_desc,
        CASE 
            WHEN SUM(mf.size * 8.0 / 1024 / 1024) > 100 THEN 'Large Database (>100GB)'
            WHEN db.recovery_model_desc = 'FULL' THEN 'Full Recovery Model'
            WHEN db.name LIKE '%prod%' OR db.name LIKE '%production%' THEN 'Production Database (by name)'
            WHEN db.name LIKE '%erp%' OR db.name LIKE '%crm%' OR db.name LIKE '%hr%' THEN 'Business Critical (by name)'
            WHEN db.name NOT LIKE '%test%' AND db.name NOT LIKE '%dev%' AND db.name NOT LIKE '%temp%' THEN 'Potential Production Database'
            ELSE 'Standard Database'
        END AS CriticalityIndicator
    FROM sys.databases db
        JOIN sys.master_files mf ON db.database_id = mf.database_id
    WHERE db.database_id > 4  -- Exclude system databases
    GROUP BY db.name, db.recovery_model_desc, db.state_desc
)
SELECT 
    'Critical Database Details' AS [Category],
    DatabaseName AS [Database_Name],
    CASE 
        WHEN TotalSizeGB >= 1000 THEN CAST(ROUND(TotalSizeGB/1000, 2) AS VARCHAR(20)) + ' TB'
        ELSE CAST(ROUND(TotalSizeGB, 2) AS VARCHAR(20)) + ' GB'
    END AS [Size],
    recovery_model_desc AS [Recovery_Model],
    state_desc AS [State],
    CriticalityIndicator AS [Criticality_Reason]
FROM CriticalDatabasesDetail
WHERE CriticalityIndicator IN (
    'Large Database (>100GB)', 
    'Full Recovery Model',
    'Production Database (by name)', 
    'Business Critical (by name)',
    'Potential Production Database'
)
ORDER BY TotalSizeGB DESC;

PRINT ''

-- ============================================================================
-- SECTION 6: DATABASE RISK ASSESSMENT
-- ============================================================================
PRINT '6. DATABASE RISK ASSESSMENT'
PRINT '---------------------------'

-- Identify databases with potential configuration issues
SELECT 
    'Risk Assessment' AS [Category],
    'Auto Shrink Enabled' AS [Risk_Type],
    COUNT(*) AS [Count],
    'Databases with auto shrink enabled (performance risk)' AS [Description]
FROM sys.databases
WHERE is_auto_shrink_on = 1 AND database_id > 4

UNION ALL

SELECT 
    'Risk Assessment' AS [Category],
    'Auto Close Enabled' AS [Risk_Type],
    COUNT(*) AS [Count],
    'Databases with auto close enabled (performance risk)' AS [Description]
FROM sys.databases
WHERE is_auto_close_on = 1 AND database_id > 4

UNION ALL

SELECT 
    'Risk Assessment' AS [Category],
    'Page Verify None' AS [Risk_Type],
    COUNT(*) AS [Count],
    'Databases without page verification (corruption risk)' AS [Description]
FROM sys.databases
WHERE page_verify_option = 0 AND database_id > 4

UNION ALL

SELECT 
    'Risk Assessment' AS [Category],
    'Compatibility Issues' AS [Risk_Type],
    COUNT(*) AS [Count],
    'Databases with compatibility level < 130 (SQL 2016)' AS [Description]
FROM sys.databases
WHERE compatibility_level < 130 AND database_id > 4;

PRINT ''

-- ============================================================================
-- SECTION 7: BACKUP STRATEGY RECOMMENDATIONS
-- ============================================================================
PRINT '7. BACKUP STRATEGY RECOMMENDATIONS'
PRINT '----------------------------------'

-- Backup recommendations based on recovery model and size
SELECT 
    'Backup Strategy' AS [Category],
    DatabaseName AS [Database_Name],
    CASE 
        WHEN TotalSizeGB >= 1000 THEN CAST(ROUND(TotalSizeGB/1000, 2) AS VARCHAR(20)) + ' TB'
        ELSE CAST(ROUND(TotalSizeGB, 2) AS VARCHAR(20)) + ' GB'
    END AS [Size],
    recovery_model_desc AS [Recovery_Model],
    CASE 
        WHEN recovery_model_desc = 'SIMPLE' AND TotalSizeGB > 50 
            THEN 'Large Simple: Full + Differential backups recommended'
        WHEN recovery_model_desc = 'FULL' AND TotalSizeGB > 100 
            THEN 'Large Full: Full + Differential + Frequent Log backups'
        WHEN recovery_model_desc = 'FULL' AND TotalSizeGB <= 100 
            THEN 'Full: Full + Log backups every 15-30 minutes'
        WHEN recovery_model_desc = 'SIMPLE' AND TotalSizeGB <= 50 
            THEN 'Simple: Daily Full backups sufficient'
        WHEN recovery_model_desc = 'BULK_LOGGED' 
            THEN 'Bulk Logged: Full + Log backups, monitor bulk operations'
        ELSE 'Standard backup strategy'
    END AS [Backup_Recommendation]
FROM (
    SELECT 
        db.name AS DatabaseName,
        db.recovery_model_desc,
        SUM(mf.size * 8.0 / 1024 / 1024) AS TotalSizeGB
    FROM sys.databases db
        JOIN sys.master_files mf ON db.database_id = mf.database_id
    WHERE db.database_id > 4
    GROUP BY db.name, db.recovery_model_desc
) AS BackupAnalysis
ORDER BY TotalSizeGB DESC;

PRINT ''
PRINT '================================================================================'
PRINT 'DATABASE INFORMATION AUDIT COMPLETE - ' + CONVERT(VARCHAR, GETDATE(), 120)
PRINT '================================================================================'

/*
ADDITIONAL QUERIES FOR DETAILED ANALYSIS:

-- Growth settings analysis
SELECT 
    db.name AS DatabaseName,
    mf.name AS LogicalName,
    mf.type_desc AS FileType,
    CASE 
        WHEN mf.is_percent_growth = 1 THEN CAST(mf.growth AS VARCHAR(10)) + '%'
        ELSE CAST(mf.growth * 8 / 1024 AS VARCHAR(10)) + ' MB'
    END AS GrowthSetting,
    CASE 
        WHEN mf.max_size = -1 THEN 'Unlimited'
        ELSE CAST(mf.max_size * 8 / 1024 / 1024 AS VARCHAR(10)) + ' GB'
    END AS MaxSize
FROM sys.master_files mf
    JOIN sys.databases db ON mf.database_id = db.database_id
WHERE db.database_id > 4
ORDER BY db.name, mf.type_desc;

-- File placement analysis
SELECT 
    db.name AS DatabaseName,
    LEFT(mf.physical_name, 3) AS DriveLetter,
    mf.type_desc AS FileType,
    COUNT(*) AS FileCount,
    SUM(mf.size * 8.0 / 1024) AS TotalSizeMB
FROM sys.master_files mf
    JOIN sys.databases db ON mf.database_id = db.database_id
WHERE db.database_id > 4
GROUP BY db.name, LEFT(mf.physical_name, 3), mf.type_desc
ORDER BY db.name, mf.type_desc;
*/
