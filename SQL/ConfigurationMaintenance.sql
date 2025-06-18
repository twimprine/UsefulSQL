/*
================================================================================
CONFIGURATION AND MAINTENANCE AUDIT SCRIPT
================================================================================

PURPOSE:
This script analyzes SQL Server configuration settings, tempdb configuration,
monitoring tools, and maintenance plan status. It provides comprehensive
information about server configuration and operational maintenance practices.

DESCRIPTION:
The script examines memory configuration, tempdb setup, installed monitoring
solutions, and maintenance plan configurations to assess the overall health
and optimization of the SQL Server environment.

OUTPUT SECTIONS:
1. Memory Configuration Analysis
2. TempDB Configuration Analysis
3. Monitoring Tools Assessment
4. Maintenance Plan Status
5. Configuration Recommendations
6. Operational Health Summary

USAGE:
1. Execute this script against any SQL Server instance
2. Review results for configuration optimization opportunities
3. Use for maintenance planning and monitoring assessment
4. Identify configuration issues and improvement areas

REQUIREMENTS:
- SQL Server 2005 or later
- VIEW SERVER STATE permission
- Access to msdb database for maintenance plans
- sysadmin permissions for complete analysis

AUTHOR: Thomas Wimprine
CREATED: 2025-06-18
LAST MODIFIED: 2025-06-18
================================================================================
*/

PRINT '================================================================================'
PRINT 'CONFIGURATION AND MAINTENANCE AUDIT - ' + CONVERT(VARCHAR, GETDATE(), 120)
PRINT '================================================================================'
PRINT ''

-- ============================================================================
-- SECTION 1: MEMORY CONFIGURATION ANALYSIS
-- 
-- This section examines how SQL Server is configured to use system memory.
-- Memory settings are critical for database performance - too little memory
-- causes slow queries, too much can starve the operating system.
-- 
-- Key concepts:
-- - Max Server Memory: Maximum RAM SQL Server can use
-- - Min Server Memory: Minimum RAM SQL Server reserves
-- - Buffer Pool: Where SQL Server caches data pages in memory
-- - Target/Total Memory: Current memory allocation vs. configured limits
-- ============================================================================
PRINT '1. MEMORY CONFIGURATION ANALYSIS'
PRINT 'Analyzing SQL Server memory configuration and usage patterns...'
PRINT ''
PRINT '--------------------------------'

-- Memory configuration settings
;WITH MemoryInfo AS (
    SELECT 
        CONVERT(BIGINT, (SELECT value_in_use FROM sys.configurations WHERE name = 'max server memory (MB)')) AS MaxServerMemoryMB,
        CONVERT(BIGINT, (SELECT value_in_use FROM sys.configurations WHERE name = 'min server memory (MB)')) AS MinServerMemoryMB,
        total_physical_memory_kb / 1024 AS TotalPhysicalMemoryMB,
        available_physical_memory_kb / 1024 AS AvailablePhysicalMemoryMB
    FROM sys.dm_os_sys_memory
)
SELECT 
    'Memory Config' AS [Category],
    'Max Server Memory (MB)' AS [Information_Type],
    CASE 
        WHEN MaxServerMemoryMB = 2147483647 THEN 'Unlimited (default)'
        ELSE CAST(MaxServerMemoryMB AS VARCHAR(20))
    END AS [Value],
    CASE 
        WHEN MaxServerMemoryMB = 2147483647 THEN 'Default (unlimited) - should be configured'
        WHEN MaxServerMemoryMB > TotalPhysicalMemoryMB * 0.9 THEN 'Too high - may cause OS memory pressure'
        WHEN MaxServerMemoryMB < TotalPhysicalMemoryMB * 0.5 THEN 'Conservative - may limit SQL Server performance'
        ELSE 'Appropriately configured'
    END AS [Description]
FROM MemoryInfo

UNION ALL

SELECT 
    'Memory Config' AS [Category],
    'Min Server Memory (MB)' AS [Information_Type],
    CAST(MinServerMemoryMB AS VARCHAR(20)) AS [Value],
    CASE 
        WHEN MinServerMemoryMB = 0 THEN 'Default (0) - acceptable for most environments'
        WHEN MinServerMemoryMB > MaxServerMemoryMB * 0.5 THEN 'High - may reserve too much memory'
        ELSE 'Configured appropriately'
    END AS [Description]
FROM MemoryInfo

UNION ALL

SELECT 
    'Memory Config' AS [Category],
    'Total Physical Memory (MB)' AS [Information_Type],
    CAST(TotalPhysicalMemoryMB AS VARCHAR(20)) AS [Value],
    'Total physical memory available on server' AS [Description]
FROM MemoryInfo

UNION ALL

SELECT 
    'Memory Config' AS [Category],
    'Memory Utilization' AS [Information_Type],
    CAST(ROUND((TotalPhysicalMemoryMB - AvailablePhysicalMemoryMB) * 100.0 / TotalPhysicalMemoryMB, 1) AS VARCHAR(10)) + '%' AS [Value],
    'Current physical memory utilization' AS [Description]
FROM MemoryInfo;

-- Buffer pool usage
SELECT 
    'Memory Usage' AS [Category],
    'Buffer Pool Size (MB)' AS [Information_Type],
    CAST(COUNT(*) * 8 / 1024 AS VARCHAR(20)) AS [Value],
    'Current buffer pool memory usage' AS [Description]
FROM sys.dm_os_buffer_descriptors;

PRINT ''

-- ============================================================================
-- SECTION 2: TEMPDB CONFIGURATION ANALYSIS
-- 
-- TempDB is SQL Server's "scratch pad" - a temporary workspace for sorting,
-- joins, temporary tables, and other operations. Poor TempDB configuration
-- is a common cause of performance problems.
-- 
-- Key concepts:
-- - Data Files: Should equal the number of CPU cores (up to 8)
-- - File Sizes: All data files should be the same size
-- - Growth Settings: Should use fixed MB/GB, not percentage
-- - Location: Should be on fast storage, separate from user databases
-- ============================================================================
PRINT '2. TEMPDB CONFIGURATION ANALYSIS'
PRINT 'Analyzing TempDB configuration - the temporary workspace database...'
PRINT ''
PRINT '--------------------------------'

-- TempDB file count and configuration
;WITH TempDBInfo AS (
    SELECT 
        COUNT(*) AS TotalFiles,
        COUNT(CASE WHEN type_desc = 'ROWS' THEN 1 END) AS DataFiles,
        COUNT(CASE WHEN type_desc = 'LOG' THEN 1 END) AS LogFiles,
        MIN(CASE WHEN type_desc = 'ROWS' THEN size * 8 / 1024 END) AS MinDataFileSizeMB,
        MAX(CASE WHEN type_desc = 'ROWS' THEN size * 8 / 1024 END) AS MaxDataFileSizeMB,
        AVG(CASE WHEN type_desc = 'ROWS' THEN size * 8 / 1024 END) AS AvgDataFileSizeMB,
        SUM(CASE WHEN type_desc = 'ROWS' THEN size * 8 / 1024 ELSE 0 END) AS TotalDataSizeMB,
        SUM(CASE WHEN type_desc = 'LOG' THEN size * 8 / 1024 ELSE 0 END) AS TotalLogSizeMB
    FROM sys.master_files
    WHERE database_id = 2  -- TempDB
),
CPUInfo AS (
    SELECT cpu_count FROM sys.dm_os_sys_info
)
SELECT 
    'Tempdb' AS [Category],
    'Number of Files' AS [Information_Type],
    CAST(DataFiles AS VARCHAR(10)) AS [Value],
    CASE 
        WHEN DataFiles = 1 THEN 'Single file - consider multiple files for better performance'
        WHEN DataFiles > cpu_count THEN 'More files than CPUs - may be excessive'
        WHEN DataFiles = cpu_count OR DataFiles = cpu_count/2 THEN 'Good configuration (matches CPU count)'
        ELSE 'Consider aligning with CPU count (' + CAST(cpu_count AS VARCHAR(10)) + ' CPUs)'
    END AS [Description]
FROM TempDBInfo, CPUInfo

UNION ALL

SELECT 
    'Tempdb' AS [Category],
    'File Sizes' AS [Information_Type],
    'Min: ' + CAST(MinDataFileSizeMB AS VARCHAR(10)) + 'MB, Max: ' + CAST(MaxDataFileSizeMB AS VARCHAR(10)) + 'MB' AS [Value],
    CASE 
        WHEN MinDataFileSizeMB = MaxDataFileSizeMB THEN 'All files same size - good configuration'
        WHEN MaxDataFileSizeMB > MinDataFileSizeMB * 1.1 THEN 'File sizes vary - may cause hot spots'
        ELSE 'File sizes reasonably consistent'
    END AS [Description]
FROM TempDBInfo

UNION ALL

SELECT 
    'Tempdb' AS [Category],
    'Total Data Size (MB)' AS [Information_Type],
    CAST(TotalDataSizeMB AS VARCHAR(20)) AS [Value],
    'Total size of all tempdb data files' AS [Description]
FROM TempDBInfo

UNION ALL

SELECT 
    'Tempdb' AS [Category],
    'Log File Size (MB)' AS [Information_Type],
    CAST(TotalLogSizeMB AS VARCHAR(20)) AS [Value],
    'Size of tempdb transaction log file' AS [Description]
FROM TempDBInfo;

-- TempDB file details
SELECT 
    'TempDB File Details' AS [Category],
    name AS [File_Name],
    type_desc AS [File_Type],
    CAST(size * 8 / 1024 AS VARCHAR(10)) + ' MB' AS [Current_Size],
    CASE 
        WHEN max_size = -1 THEN 'Unlimited'
        WHEN max_size = 268435456 THEN 'Unlimited (2TB default)'
        ELSE CAST(max_size * 8 / 1024 AS VARCHAR(10)) + ' MB'
    END AS [Max_Size],
    CASE 
        WHEN is_percent_growth = 1 THEN CAST(growth AS VARCHAR(10)) + '%'
        ELSE CAST(growth * 8 / 1024 AS VARCHAR(10)) + ' MB'
    END AS [Growth_Setting],
    LEFT(physical_name, 50) AS [File_Path]
FROM sys.master_files
WHERE database_id = 2  -- TempDB
ORDER BY type_desc, file_id;

PRINT ''

-- ============================================================================
-- SECTION 3: MONITORING TOOLS ASSESSMENT
-- 
-- Monitoring tools help detect problems before they impact users. This section
-- checks for common monitoring solutions and configurations.
-- 
-- Key concepts:
-- - SQL Server Agent: Runs scheduled jobs, alerts, and maintenance tasks
-- - Jobs: Automated tasks like backups, maintenance, monitoring checks
-- - Alerts: Notifications when specific conditions occur
-- - Extended Events: Modern event tracking (replaces SQL Trace)
-- - Performance Counters: System metrics for monitoring tools
-- ============================================================================
PRINT '3. MONITORING TOOLS ASSESSMENT'
PRINT 'Checking for monitoring tools and configurations...'
PRINT ''
PRINT '------------------------------'

-- SQL Server Agent status
SELECT 
    'Monitoring' AS [Category],
    'SQL Server Agent' AS [Information_Type],
    CASE 
        WHEN SERVERPROPERTY('IsIntegratedSecurityOnly') = 1 
        THEN 'Windows Authentication (Agent should be running)'
        ELSE 'Mixed Mode (Agent should be running)'
    END AS [Value],
    'SQL Server Agent service for job scheduling and monitoring' AS [Description];

-- Check for common monitoring solutions through extended events, perfmon, etc.
-- SQL Server Agent Jobs (indication of monitoring)
;WITH MonitoringJobs AS (
    SELECT 
        COUNT(*) AS TotalJobs,
        COUNT(CASE WHEN j.enabled = 1 THEN 1 END) AS EnabledJobs,
        COUNT(CASE WHEN j.name LIKE '%monitor%' OR j.name LIKE '%alert%' OR j.name LIKE '%health%' THEN 1 END) AS MonitoringJobs,
        COUNT(CASE WHEN j.name LIKE '%backup%' THEN 1 END) AS BackupJobs,
        COUNT(CASE WHEN j.name LIKE '%maintenance%' OR j.name LIKE '%index%' OR j.name LIKE '%stats%' THEN 1 END) AS MaintenanceJobs
    FROM msdb.dbo.sysjobs j
)
SELECT 
    'Monitoring' AS [Category],
    'Monitoring Tools in Use' AS [Information_Type],
    CASE 
        WHEN TotalJobs = 0 THEN 'No SQL Agent jobs configured'
        WHEN MonitoringJobs > 0 THEN 'Custom monitoring jobs detected (' + CAST(MonitoringJobs AS VARCHAR(10)) + ' jobs)'
        WHEN EnabledJobs > 0 THEN 'SQL Agent jobs present but no obvious monitoring jobs'
        ELSE 'Limited monitoring detected'
    END AS [Value],
    'Total jobs: ' + CAST(TotalJobs AS VARCHAR(10)) + ', Enabled: ' + CAST(EnabledJobs AS VARCHAR(10)) AS [Description]
FROM MonitoringJobs;

-- Check for Database Mail (often used for monitoring alerts)
SELECT 
    'Monitoring' AS [Category],
    'Database Mail' AS [Information_Type],
    CASE 
        WHEN CONVERT(INT, (SELECT value_in_use FROM sys.configurations WHERE name = 'Database Mail XPs')) = 1 
        THEN 'Enabled'
        ELSE 'Disabled'
    END AS [Value],
    'Database Mail configuration for sending alerts and notifications' AS [Description];

-- Check for Extended Events sessions (modern monitoring)
IF EXISTS (SELECT * FROM sys.server_event_sessions WHERE name NOT LIKE 'system_%')
BEGIN
    SELECT 
        'Monitoring' AS [Category],
        'Extended Events' AS [Information_Type],
        CAST(COUNT(*) AS VARCHAR(10)) + ' custom sessions' AS [Value],
        'Extended Events sessions for advanced monitoring and troubleshooting' AS [Description]
    FROM sys.server_event_sessions 
    WHERE name NOT LIKE 'system_%';
END
ELSE
BEGIN
    SELECT 
        'Monitoring' AS [Category],
        'Extended Events' AS [Information_Type],
        'No custom sessions' AS [Value],
        'No custom Extended Events sessions detected' AS [Description];
END

-- Check for SQL Server Profiler traces (legacy monitoring)
SELECT 
    'Monitoring' AS [Category],
    'Profiler Traces' AS [Information_Type],
    CASE 
        WHEN COUNT(*) = 0 THEN 'None running'
        ELSE CAST(COUNT(*) AS VARCHAR(10)) + ' traces running'
    END AS [Value],
    'Server-side traces (consider migrating to Extended Events)' AS [Description]
FROM sys.traces
WHERE is_default = 0;

PRINT ''

-- ============================================================================
-- SECTION 4: MAINTENANCE PLAN STATUS
-- 
-- Maintenance plans automate routine database tasks like backups, index
-- rebuilding, and consistency checks. This section checks what maintenance
-- is configured and running.
-- 
-- Key concepts:
-- - Maintenance Plans: GUI-based automation tools in SQL Server
-- - Jobs: Scheduled tasks that run maintenance operations
-- - DBCC: Database consistency checker commands
-- - Index Maintenance: Rebuilding/reorganizing fragmented indexes
-- - Statistics Updates: Keeping query optimizer statistics current
-- ============================================================================
PRINT '4. MAINTENANCE PLAN STATUS'
PRINT 'Checking configured maintenance plans and jobs...'
PRINT ''
PRINT '-------------------------'

-- Maintenance Plans
IF EXISTS (SELECT * FROM msdb.dbo.sysmaintplan_plans)
BEGIN
    SELECT 
        'Maintenance' AS [Category],
        'Maintenance Plan Status' AS [Information_Type],
        CAST(COUNT(*) AS VARCHAR(10)) + ' plans configured' AS [Value],
        'SQL Server Maintenance Plans detected' AS [Description]
    FROM msdb.dbo.sysmaintplan_plans;
    
    -- Detailed maintenance plan information
    SELECT 
        'Maintenance Plan Details' AS [Category],
        name AS [Plan_Name],
        'Configured' AS [Status],
        id AS [Plan_ID]
    FROM msdb.dbo.sysmaintplan_plans
    ORDER BY name;
END
ELSE
BEGIN
    SELECT 
        'Maintenance' AS [Category],
        'Maintenance Plan Status' AS [Information_Type],
        'No maintenance plans' AS [Value],
        'No SQL Server Maintenance Plans configured' AS [Description];
END

-- Check for maintenance-related jobs
;WITH MaintenanceJobAnalysis AS (
    SELECT 
        COUNT(*) AS TotalMaintenanceJobs,
        COUNT(CASE WHEN j.enabled = 1 THEN 1 END) AS EnabledMaintenanceJobs,
        COUNT(CASE WHEN j.name LIKE '%backup%' THEN 1 END) AS BackupJobs,
        COUNT(CASE WHEN j.name LIKE '%index%' OR j.name LIKE '%reindex%' OR j.name LIKE '%defrag%' THEN 1 END) AS IndexJobs,
        COUNT(CASE WHEN j.name LIKE '%stats%' OR j.name LIKE '%statistics%' THEN 1 END) AS StatsJobs,
        COUNT(CASE WHEN j.name LIKE '%cleanup%' OR j.name LIKE '%purge%' THEN 1 END) AS CleanupJobs,
        COUNT(CASE WHEN j.name LIKE '%check%' OR j.name LIKE '%dbcc%' THEN 1 END) AS IntegrityJobs
    FROM msdb.dbo.sysjobs j
    WHERE j.name LIKE '%backup%' 
       OR j.name LIKE '%maintenance%'
       OR j.name LIKE '%index%'
       OR j.name LIKE '%stats%'
       OR j.name LIKE '%cleanup%'
       OR j.name LIKE '%check%'
       OR j.name LIKE '%dbcc%'
)
SELECT 
    'Maintenance' AS [Category],
    'Maintenance Jobs' AS [Information_Type],
    CASE 
        WHEN TotalMaintenanceJobs = 0 THEN 'No maintenance jobs detected'
        ELSE CAST(EnabledMaintenanceJobs AS VARCHAR(10)) + ' of ' + CAST(TotalMaintenanceJobs AS VARCHAR(10)) + ' enabled'
    END AS [Value],
    'Backup: ' + CAST(BackupJobs AS VARCHAR(5)) + 
    ', Index: ' + CAST(IndexJobs AS VARCHAR(5)) + 
    ', Stats: ' + CAST(StatsJobs AS VARCHAR(5)) + 
    ', Integrity: ' + CAST(IntegrityJobs AS VARCHAR(5)) AS [Description]
FROM MaintenanceJobAnalysis;

-- Recent job execution status
SELECT TOP 10
    'Recent Job Activity' AS [Category],
    j.name AS [Job_Name],
    CASE jh.run_status
        WHEN 0 THEN 'Failed'
        WHEN 1 THEN 'Succeeded'
        WHEN 2 THEN 'Retry'
        WHEN 3 THEN 'Canceled'
        WHEN 4 THEN 'In Progress'
        ELSE 'Unknown'
    END AS [Last_Run_Status],
    CASE 
        WHEN jh.run_date IS NOT NULL THEN 
            CAST(jh.run_date AS VARCHAR(8)) + ' ' + 
            STUFF(STUFF(RIGHT('000000' + CAST(jh.run_time AS VARCHAR(6)), 6), 5, 0, ':'), 3, 0, ':')
        ELSE 'Never'
    END AS [Last_Run_Time],
    CASE 
        WHEN jh.run_duration IS NOT NULL THEN
            CAST(jh.run_duration / 10000 AS VARCHAR(10)) + ':' + 
            RIGHT('00' + CAST((jh.run_duration % 10000) / 100 AS VARCHAR(2)), 2) + ':' + 
            RIGHT('00' + CAST(jh.run_duration % 100 AS VARCHAR(2)), 2)
        ELSE 'N/A'
    END AS [Duration]
FROM msdb.dbo.sysjobs j
    LEFT JOIN (
        SELECT 
            job_id,
            run_status,
            run_date,
            run_time,
            run_duration,
            ROW_NUMBER() OVER (PARTITION BY job_id ORDER BY run_date DESC, run_time DESC) AS rn
        FROM msdb.dbo.sysjobhistory
        WHERE step_id = 0  -- Overall job outcome
    ) jh ON j.job_id = jh.job_id AND jh.rn = 1
WHERE j.name LIKE '%backup%' 
   OR j.name LIKE '%maintenance%'
   OR j.name LIKE '%index%'
   OR j.name LIKE '%stats%'
   OR j.name LIKE '%cleanup%'
   OR j.name LIKE '%check%'
ORDER BY 
    CASE jh.run_status WHEN 0 THEN 1 ELSE 2 END,  -- Failed jobs first
    jh.run_date DESC, jh.run_time DESC;

PRINT ''

-- ============================================================================
-- SECTION 5: CONFIGURATION RECOMMENDATIONS
-- ============================================================================
PRINT '5. CONFIGURATION RECOMMENDATIONS'
PRINT '--------------------------------'

-- Configuration recommendations based on current settings
;WITH ConfigAnalysis AS (
    SELECT 
        CONVERT(BIGINT, (SELECT value_in_use FROM sys.configurations WHERE name = 'max server memory (MB)')) AS MaxServerMemoryMB,
        CONVERT(INT, (SELECT value_in_use FROM sys.configurations WHERE name = 'max degree of parallelism')) AS MAXDOP,
        CONVERT(INT, (SELECT value_in_use FROM sys.configurations WHERE name = 'cost threshold for parallelism')) AS CostThreshold,
        CONVERT(INT, (SELECT value_in_use FROM sys.configurations WHERE name = 'optimize for ad hoc workloads')) AS OptimizeAdhoc,
        CONVERT(INT, (SELECT value_in_use FROM sys.configurations WHERE name = 'backup compression default')) AS BackupCompression,
        (SELECT cpu_count FROM sys.dm_os_sys_info) AS CPUCount,
        (SELECT COUNT(*) FROM sys.master_files WHERE database_id = 2 AND type_desc = 'ROWS') AS TempDBFiles
)
SELECT 
    'Configuration Issues' AS [Category],
    'Max Server Memory' AS [Setting],
    CASE 
        WHEN MaxServerMemoryMB = 2147483647 THEN 'Not configured - should be set to appropriate value'
        ELSE 'Configured'
    END AS [Status],
    'Should be set to leave 2-4GB for OS depending on server role' AS [Recommendation]
FROM ConfigAnalysis
WHERE MaxServerMemoryMB = 2147483647

UNION ALL

SELECT 
    'Configuration Issues' AS [Category],
    'MAXDOP' AS [Setting],
    CASE 
        WHEN MAXDOP = 0 THEN 'Default (0) - may cause parallelism issues'
        WHEN MAXDOP > CPUCount THEN 'Higher than CPU count'
        ELSE 'Configured'
    END AS [Status],
    'Consider setting to ' + CAST(CASE WHEN CPUCount > 8 THEN 8 ELSE CPUCount END AS VARCHAR(10)) + ' based on ' + CAST(CPUCount AS VARCHAR(10)) + ' CPUs' AS [Recommendation]
FROM ConfigAnalysis
WHERE MAXDOP = 0 OR MAXDOP > CPUCount

UNION ALL

SELECT 
    'Configuration Issues' AS [Category],
    'TempDB Files' AS [Setting],
    CASE 
        WHEN TempDBFiles = 1 THEN 'Single file - performance bottleneck'
        WHEN TempDBFiles > CPUCount THEN 'More files than CPUs'
        ELSE 'Configured'
    END AS [Status],
    'Consider ' + CAST(CASE WHEN CPUCount > 8 THEN 8 ELSE CPUCount END AS VARCHAR(10)) + ' files based on ' + CAST(CPUCount AS VARCHAR(10)) + ' CPUs' AS [Recommendation]
FROM ConfigAnalysis
WHERE TempDBFiles <> CASE WHEN CPUCount > 8 THEN 8 ELSE CPUCount END

UNION ALL

SELECT 
    'Configuration Issues' AS [Category],
    'Backup Compression' AS [Setting],
    CASE 
        WHEN BackupCompression = 0 THEN 'Disabled - missing space savings'
        ELSE 'Enabled'
    END AS [Status],
    'Enable backup compression to reduce backup size and improve performance' AS [Recommendation]
FROM ConfigAnalysis
WHERE BackupCompression = 0;

PRINT ''

-- ============================================================================
-- SECTION 6: OPERATIONAL HEALTH SUMMARY
-- 
-- This section provides a high-level health check summary, highlighting
-- critical issues that need immediate attention and overall system status.
-- 
-- Key concepts:
-- - Health Score: Overall system health indicator
-- - Critical Issues: Problems that could cause outages or data loss
-- - Warnings: Configuration issues that may impact performance
-- - Recommendations: Priority actions to improve system health
-- ============================================================================
PRINT '6. OPERATIONAL HEALTH SUMMARY'
PRINT 'Generating overall health assessment...'
PRINT ''
PRINT '-----------------------------'

-- Overall health summary
;WITH HealthSummary AS (
    SELECT 
        (SELECT COUNT(*) FROM msdb.dbo.sysjobs WHERE enabled = 1) AS EnabledJobs,
        (SELECT COUNT(*) FROM msdb.dbo.sysjobs j 
         JOIN msdb.dbo.sysjobhistory jh ON j.job_id = jh.job_id 
         WHERE jh.run_status = 0 AND jh.run_date >= CONVERT(INT, CONVERT(VARCHAR(8), DATEADD(day, -1, GETDATE()), 112)) AND jh.step_id = 0) AS FailedJobsToday,
        (SELECT COUNT(*) FROM sys.databases WHERE state_desc <> 'ONLINE' AND database_id > 4) AS OfflineDatabases,
        (SELECT COUNT(*) FROM sys.dm_exec_requests WHERE blocking_session_id <> 0) AS BlockedSessions,
        CASE 
            WHEN CONVERT(BIGINT, (SELECT value_in_use FROM sys.configurations WHERE name = 'max server memory (MB)')) = 2147483647 THEN 1 
            ELSE 0 
        END AS MemoryNotConfigured,
        CASE 
            WHEN (SELECT COUNT(*) FROM sys.master_files WHERE database_id = 2 AND type_desc = 'ROWS') = 1 THEN 1 
            ELSE 0 
        END AS TempDBSingleFile
)
SELECT 
    'Operational Health' AS [Category],
    'Overall Status' AS [Information_Type],
    CASE 
        WHEN FailedJobsToday > 0 OR OfflineDatabases > 0 OR BlockedSessions > 5 THEN 'CRITICAL'
        WHEN MemoryNotConfigured = 1 OR TempDBSingleFile = 1 THEN 'WARNING'
        ELSE 'HEALTHY'
    END AS [Value],
    'Jobs: ' + CAST(EnabledJobs AS VARCHAR(10)) + 
    ', Failed Today: ' + CAST(FailedJobsToday AS VARCHAR(10)) + 
    ', Offline DBs: ' + CAST(OfflineDatabases AS VARCHAR(10)) AS [Description]
FROM HealthSummary;

PRINT ''
PRINT '================================================================================'
PRINT 'CONFIGURATION AND MAINTENANCE AUDIT COMPLETE - ' + CONVERT(VARCHAR, GETDATE(), 120)
PRINT '================================================================================'

/*
ADDITIONAL QUERIES FOR DETAILED ANALYSIS:

-- All configuration settings
SELECT 
    name,
    value,
    value_in_use,
    description,
    is_dynamic,
    is_advanced
FROM sys.configurations
WHERE value <> value_in_use OR is_advanced = 1
ORDER BY name;

-- TempDB usage and contention
SELECT 
    session_id,
    request_id,
    task_alloc_GB = task_alloc / 1024.0 / 1024.0,
    task_dealloc_GB = task_dealloc / 1024.0 / 1024.0,
    internal_objects_alloc_GB = internal_objects_alloc_page_count / 128.0 / 1024.0,
    internal_objects_dealloc_GB = internal_objects_dealloc_page_count / 128.0 / 1024.0
FROM (
    SELECT 
        session_id,
        request_id,
        SUM(user_objects_alloc_page_count * 8) AS task_alloc,
        SUM(user_objects_dealloc_page_count * 8) AS task_dealloc,
        SUM(internal_objects_alloc_page_count) AS internal_objects_alloc_page_count,
        SUM(internal_objects_dealloc_page_count) AS internal_objects_dealloc_page_count
    FROM sys.dm_db_task_space_usage
    GROUP BY session_id, request_id
) AS Usage
WHERE task_alloc > 0 OR internal_objects_alloc_page_count > 0
ORDER BY task_alloc DESC;
*/
