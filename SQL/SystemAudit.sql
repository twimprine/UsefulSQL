/*
================================================================================
SQL SERVER SYSTEM AUDIT SCRIPT
================================================================================

PURPOSE:
This comprehensive audit script gathers critical system and SQL Server 
configuration information for customer assessments, performance analysis,
and infrastructure planning. It provides a complete picture of the SQL Server
environment including hardware, configuration, and resource allocation.

DESCRIPTION:
The script is organized into sections that collect different types of audit
information:
1. SQL Server Instance Information
2. System Hardware Information  
3. Database Files and Storage
4. Memory Configuration and Usage
5. Security and Authentication
6. Performance and Wait Statistics
7. Database Configuration Summary

USAGE:
1. Execute this script against the SQL Server instance to audit
2. Results provide comprehensive system overview
3. Use output for capacity planning, optimization, and documentation
4. Save results for baseline comparisons and trend analysis

REQUIREMENTS:
- SQL Server 2008 R2 or later (some features require newer versions)
- VIEW SERVER STATE permission
- VIEW ANY DATABASE permission  
- Login must have appropriate system permissions

AUTHOR: Thomas Wimprine
CREATED: 2025-06-18
LAST MODIFIED: 2025-06-18
================================================================================
*/

PRINT '================================================================================'
PRINT 'SQL SERVER SYSTEM AUDIT - ' + CONVERT(VARCHAR, GETDATE(), 120)
PRINT '================================================================================'
PRINT ''

-- ============================================================================
-- SECTION 1: SQL SERVER INSTANCE INFORMATION
-- 
-- This section gathers basic information about the SQL Server installation,
-- including version, edition, service pack level, and key settings.
-- 
-- Key concepts:
-- - Instance: A single installation of SQL Server (can have multiple per server)
-- - Edition: Feature level (Express, Standard, Enterprise, Developer)
-- - Service Pack/CU: Updates and patches applied
-- - Collation: Rules for sorting and comparing text data
-- - Authentication Mode: Windows-only vs Windows + SQL logins
-- ============================================================================
PRINT '1. SQL SERVER INSTANCE INFORMATION'
PRINT 'Gathering SQL Server installation and configuration details...'
PRINT ''
PRINT '-----------------------------------'

SELECT 
    'SQL Server Instance Info' AS [Category],
    @@SERVERNAME AS [Server_Name],
    @@VERSION AS [Version_Info],
    SERVERPROPERTY('ProductVersion') AS [Product_Version],
    SERVERPROPERTY('ProductLevel') AS [Service_Pack],
    SERVERPROPERTY('Edition') AS [Edition],
    SERVERPROPERTY('EngineEdition') AS [Engine_Edition],
    SERVERPROPERTY('IsClustered') AS [Is_Clustered],
    SERVERPROPERTY('IsHadrEnabled') AS [Always_On_Enabled],
    SERVERPROPERTY('SqlCharSetName') AS [Character_Set],
    SERVERPROPERTY('Collation') AS [Collation],
    SQLSERVER_START_TIME AS [SQL_Start_Time]
FROM sys.dm_os_sys_info;

PRINT ''

-- ============================================================================
-- SECTION 1B: DETAILED INSTANCE DISCOVERY AND CONFIGURATION
-- ============================================================================
PRINT '1B. DETAILED INSTANCE DISCOVERY AND CONFIGURATION'
PRINT '------------------------------------------------'

-- Comprehensive Instance Information
SELECT 
    'Instance Details' AS [Category],
    'SQL Version' AS [Information_Type],
    SERVERPROPERTY('Edition') AS [Value],
    'Edition & Version' AS [Description]
UNION ALL
SELECT 
    'Instance Details' AS [Category],
    'SQL Version' AS [Information_Type],
    CAST(SERVERPROPERTY('ProductVersion') AS NVARCHAR(50)) + ' (' + CAST(SERVERPROPERTY('ProductLevel') AS NVARCHAR(50)) + ')' AS [Value],
    'Service Pack/CU Level' AS [Description]
UNION ALL
SELECT 
    'Instance Details' AS [Category],
    'Instance' AS [Information_Type],
    CASE 
        WHEN SERVERPROPERTY('InstanceName') IS NULL THEN @@SERVERNAME + ' (DEFAULT)'
        ELSE @@SERVERNAME + '\' + CAST(SERVERPROPERTY('InstanceName') AS NVARCHAR(50))
    END AS [Value],
    'Instance Name' AS [Description]
UNION ALL
SELECT 
    'Instance Details' AS [Category],
    'Instance' AS [Information_Type],
    CASE 
        WHEN SERVERPROPERTY('InstanceName') IS NULL THEN 'Default Instance'
        ELSE 'Named Instance: ' + CAST(SERVERPROPERTY('InstanceName') AS NVARCHAR(50))
    END AS [Value],
    'Default/Named Instance' AS [Description]
UNION ALL
SELECT 
    'Instance Details' AS [Category],
    'Authentication' AS [Information_Type],
    CASE SERVERPROPERTY('IsIntegratedSecurityOnly')
        WHEN 1 THEN 'Windows Authentication Only'
        WHEN 0 THEN 'Mixed Mode (SQL Server and Windows)'
    END AS [Value],
    'Windows/Mixed Mode' AS [Description];

-- SQL Server Service Information (requires xp_instance_regread)
DECLARE @SQLServerPort NVARCHAR(10);
DECLARE @SQLService NVARCHAR(100);
DECLARE @SQLAgentService NVARCHAR(100);

-- Get SQL Server Port
BEGIN TRY
    EXEC xp_instance_regread 
        N'HKEY_LOCAL_MACHINE', 
        N'SOFTWARE\Microsoft\Microsoft SQL Server\MSSQLServer\SuperSocketNetLib\Tcp\IpAll', 
        N'TcpPort', 
        @SQLServerPort OUTPUT;
    
    -- If dynamic port, get the dynamic port instead
    IF @SQLServerPort IS NULL OR @SQLServerPort = ''
    BEGIN
        EXEC xp_instance_regread 
            N'HKEY_LOCAL_MACHINE', 
            N'SOFTWARE\Microsoft\Microsoft SQL Server\MSSQLServer\SuperSocketNetLib\Tcp\IpAll', 
            N'TcpDynamicPorts', 
            @SQLServerPort OUTPUT;
        SET @SQLServerPort = ISNULL(@SQLServerPort, 'Unknown') + ' (Dynamic)';
    END
END TRY
BEGIN CATCH
    SET @SQLServerPort = 'Unable to determine';
END CATCH

-- Get SQL Server Service Account
BEGIN TRY
    EXEC xp_instance_regread 
        N'HKEY_LOCAL_MACHINE',
        N'SYSTEM\CurrentControlSet\Services\MSSQLServer',
        N'ObjectName',
        @SQLService OUTPUT;
END TRY
BEGIN CATCH
    SET @SQLService = 'Unable to determine';
END CATCH

-- Get SQL Agent Service Account  
BEGIN TRY
    EXEC xp_instance_regread 
        N'HKEY_LOCAL_MACHINE',
        N'SYSTEM\CurrentControlSet\Services\SQLServerAgent',
        N'ObjectName',
        @SQLAgentService OUTPUT;
END TRY
BEGIN CATCH
    SET @SQLAgentService = 'Unable to determine';
END CATCH

-- Display Service Information
SELECT 
    'Service Details' AS [Category],
    'Port' AS [Information_Type],
    ISNULL(@SQLServerPort, 'Unknown') AS [Value],
    'SQL Server Port' AS [Description]
UNION ALL
SELECT 
    'Service Details' AS [Category],
    'Service Account' AS [Information_Type],
    ISNULL(@SQLService, 'Unknown') AS [Value],
    'SQL Server Service Account' AS [Description]
UNION ALL
SELECT 
    'Service Details' AS [Category],
    'Service Account' AS [Information_Type],
    ISNULL(@SQLAgentService, 'Unknown') AS [Value],
    'SQL Agent Service Account' AS [Description];

-- Alternative method using WMI (if available) for service information
PRINT ''
PRINT 'Alternative Service Information (using sys.dm_server_services - SQL 2008 R2+):'

-- Service information from sys.dm_server_services (SQL 2008 R2+)
IF EXISTS (SELECT * FROM sys.system_objects WHERE name = 'dm_server_services')
BEGIN
    SELECT 
        'Service Status' AS [Category],
        servicename AS [Service_Name],
        service_account AS [Service_Account],
        startup_type_desc AS [Startup_Type],
        status_desc AS [Current_Status],
        process_id AS [Process_ID],
        last_startup_time AS [Last_Startup_Time]
    FROM sys.dm_server_services
    WHERE servicename LIKE 'SQL Server%' 
       OR servicename LIKE 'SQL Agent%'
       OR servicename LIKE '%Analysis Services%'
       OR servicename LIKE '%Integration Services%'
       OR servicename LIKE '%Reporting Services%';
END
ELSE
BEGIN
    SELECT 'Service Status' AS [Category], 'sys.dm_server_services not available in this SQL Server version' AS [Message];
END

-- Network Configuration
SELECT 
    'Network Configuration' AS [Category],
    'Current Connection' AS [Type],
    net_transport AS [Protocol_Name],
    auth_scheme AS [Authentication_Scheme],
    local_net_address AS [Local_IP_Address],
    local_tcp_port AS [Local_Port],
    client_net_address AS [Client_IP_Address]
FROM sys.dm_exec_connections 
WHERE session_id = @@SPID;

PRINT ''

-- ============================================================================
-- SECTION 2: SYSTEM HARDWARE INFORMATION
-- 
-- This section examines the physical server hardware that SQL Server is
-- running on, including CPU, memory, and storage characteristics.
-- 
-- Key concepts:
-- - Logical CPUs: Total processing threads (includes hyperthreading)
-- - Physical CPUs: Actual processor cores
-- - NUMA: Non-Uniform Memory Access (memory architecture on large servers)
-- - Socket Count: Number of physical processor chips
-- - Memory: Total RAM available to the operating system
-- ============================================================================
PRINT '2. SYSTEM HARDWARE INFORMATION'
PRINT 'Analyzing server hardware configuration...'
PRINT ''
PRINT '------------------------------'

-- CPU Information
SELECT 
    'CPU Information' AS [Category],
    cpu_count AS [Logical_CPU_Count],
    hyperthread_ratio AS [Hyperthread_Ratio],
    cpu_count / hyperthread_ratio AS [Physical_CPU_Count],
    max_workers_count AS [Max_Worker_Threads]
FROM sys.dm_os_sys_info;

-- System Memory Information (using sys.dm_os_sys_memory for memory details)
SELECT 
    'System Memory' AS [Category],
    total_physical_memory_kb / 1024 AS [Total_Physical_Memory_MB],
    total_physical_memory_kb / 1024 / 1024 AS [Total_Physical_Memory_GB],
    available_physical_memory_kb / 1024 AS [Available_Physical_Memory_MB],
    total_page_file_kb / 1024 AS [Total_Page_File_MB],
    available_page_file_kb / 1024 AS [Available_Page_File_MB],
    system_cache_kb / 1024 AS [System_Cache_MB],
    system_high_memory_signal_state AS [High_Memory_Signal],
    system_low_memory_signal_state AS [Low_Memory_Signal]
FROM sys.dm_os_sys_memory;

PRINT ''

-- Scheduler Information
SELECT 
    'CPU Scheduler Info' AS [Category],
    scheduler_id,
    cpu_id,
    status,
    is_online,
    current_tasks_count,
    runnable_tasks_count,
    current_workers_count,
    active_workers_count,
    work_queue_count,
    load_factor
FROM sys.dm_os_schedulers
WHERE status = 'VISIBLE ONLINE'
ORDER BY scheduler_id;

PRINT ''

-- ============================================================================
-- SECTION 3: DATABASE FILES AND STORAGE ANALYSIS
-- 
-- This section examines database files, their sizes, growth settings, and
-- storage configuration. Poor file configuration can cause performance issues.
-- 
-- Key concepts:
-- - Data Files (.mdf/.ndf): Contain database tables and indexes
-- - Log Files (.ldf): Contain transaction log records
-- - File Growth: How files expand when they run out of space
-- - Recovery Model: Determines backup and log handling behavior
-- - Physical Path: Where files are stored on disk
-- ============================================================================
PRINT '3. DATABASE FILES AND STORAGE ANALYSIS'
PRINT 'Analyzing database files and storage configuration...'
PRINT ''
PRINT '--------------------------------------'

-- Database File Information with Growth Settings
SELECT 
    'Database Files' AS [Category],
    db.name AS [Database_Name],
    mf.name AS [Logical_Name],
    mf.physical_name AS [Physical_Path],
    mf.type_desc AS [File_Type],
    CONVERT(DECIMAL(10,2), mf.size * 8.0 / 1024) AS [Current_Size_MB],
    CONVERT(DECIMAL(10,2), mf.size * 8.0 / 1024 / 1024) AS [Current_Size_GB],
    CASE 
        WHEN mf.max_size = -1 THEN 'Unlimited'
        WHEN mf.max_size = 268435456 THEN 'Unlimited (2TB)'
        ELSE CONVERT(VARCHAR(20), CONVERT(DECIMAL(10,2), mf.max_size * 8.0 / 1024)) + ' MB'
    END AS [Max_Size],
    CASE 
        WHEN mf.is_percent_growth = 1 THEN CONVERT(VARCHAR(10), mf.growth) + '%'
        ELSE CONVERT(VARCHAR(20), CONVERT(DECIMAL(10,2), mf.growth * 8.0 / 1024)) + ' MB'
    END AS [Growth_Setting],
    db.state_desc AS [Database_State],
    db.recovery_model_desc AS [Recovery_Model]
FROM sys.master_files mf
    JOIN sys.databases db ON db.database_id = mf.database_id
ORDER BY db.name, mf.type_desc;

PRINT ''

-- Storage Summary by Database
SELECT 
    'Storage Summary' AS [Category],
    db.name AS [Database_Name],
    COUNT(*) AS [Total_Files],
    SUM(CASE WHEN mf.type_desc = 'ROWS' THEN 1 ELSE 0 END) AS [Data_Files],
    SUM(CASE WHEN mf.type_desc = 'LOG' THEN 1 ELSE 0 END) AS [Log_Files],
    CONVERT(DECIMAL(10,2), SUM(CASE WHEN mf.type_desc = 'ROWS' THEN mf.size * 8.0 / 1024 ELSE 0 END)) AS [Total_Data_MB],
    CONVERT(DECIMAL(10,2), SUM(CASE WHEN mf.type_desc = 'LOG' THEN mf.size * 8.0 / 1024 ELSE 0 END)) AS [Total_Log_MB],
    CONVERT(DECIMAL(10,2), SUM(mf.size * 8.0 / 1024)) AS [Total_Size_MB],
    CONVERT(DECIMAL(10,2), SUM(mf.size * 8.0 / 1024 / 1024)) AS [Total_Size_GB]
FROM sys.master_files mf
    JOIN sys.databases db ON db.database_id = mf.database_id
GROUP BY db.name
ORDER BY [Total_Size_MB] DESC;

PRINT ''

-- ============================================================================
-- SECTION 4: MEMORY CONFIGURATION AND USAGE
-- ============================================================================
PRINT '4. MEMORY CONFIGURATION AND USAGE'
PRINT '---------------------------------'

-- SQL Server Memory Configuration
SELECT 
    'Memory Configuration' AS [Category],
    (SELECT CONVERT(INT, value_in_use) FROM sys.configurations WHERE name = 'min server memory (MB)') AS [Min_Server_Memory_MB],
    (SELECT CONVERT(INT, value_in_use) FROM sys.configurations WHERE name = 'max server memory (MB)') AS [Max_Server_Memory_MB];

PRINT ''

-- Memory Clerks (Top 10 consumers)
SELECT TOP 10
    'Top Memory Clerks' AS [Category],
    type AS [Clerk_Type],
    SUM(pages_kb) / 1024 AS [Memory_Used_MB],
    COUNT(*) AS [Clerk_Count]
FROM sys.dm_os_memory_clerks
WHERE pages_kb > 0
GROUP BY type
ORDER BY [Memory_Used_MB] DESC;

PRINT ''

-- ============================================================================
-- SECTION 5: SQL SERVER CONFIGURATION
-- ============================================================================
PRINT '5. SQL SERVER CONFIGURATION'
PRINT '----------------------------'

-- Key Configuration Settings
SELECT 
    'Configuration Settings' AS [Category],
    name AS [Setting_Name],
    value_in_use AS [Current_Value],
    value AS [Configured_Value],
    description AS [Description],
    is_dynamic AS [Is_Dynamic],
    is_advanced AS [Is_Advanced]
FROM sys.configurations
WHERE name IN (
    'max server memory (MB)',
    'min server memory (MB)',
    'max degree of parallelism',
    'cost threshold for parallelism',
    'optimize for ad hoc workloads',
    'backup compression default',
    'database mail xps',
    'remote admin connections',
    'show advanced options'
)
ORDER BY name;

PRINT ''

-- ============================================================================
-- SECTION 6: SECURITY AND AUTHENTICATION
-- ============================================================================
PRINT '6. SECURITY AND AUTHENTICATION' 
PRINT '------------------------------'

-- SQL Server Authentication Mode and Login Counts
SELECT 
    'Authentication Mode' AS [Category],
    CASE SERVERPROPERTY('IsIntegratedSecurityOnly')
        WHEN 1 THEN 'Windows Authentication Only'
        WHEN 0 THEN 'Mixed Mode (SQL Server and Windows)'
    END AS [Authentication_Mode],
    (SELECT COUNT(*) FROM sys.server_principals WHERE type IN ('S', 'U')) AS [Total_Logins],
    (SELECT COUNT(*) FROM sys.server_principals WHERE type = 'S') AS [SQL_Logins],
    (SELECT COUNT(*) FROM sys.server_principals WHERE type = 'U') AS [Windows_User_Logins],
    (SELECT COUNT(*) FROM sys.server_principals WHERE type = 'G') AS [Windows_Group_Logins];

-- Login Summary by Type
SELECT 
    'Login Summary' AS [Category],
    CASE type
        WHEN 'S' THEN 'SQL Server Login'
        WHEN 'U' THEN 'Windows User'
        WHEN 'G' THEN 'Windows Group'
        WHEN 'R' THEN 'Server Role'
        WHEN 'C' THEN 'Certificate'
        WHEN 'K' THEN 'Asymmetric Key'
    END AS [Login_Type],
    COUNT(*) AS [Count]
FROM sys.server_principals
WHERE type IN ('S', 'U', 'G')
GROUP BY type
ORDER BY [Count] DESC;

PRINT ''

-- ============================================================================
-- SECTION 7: PERFORMANCE AND WAIT STATISTICS
-- ============================================================================
PRINT '7. PERFORMANCE AND WAIT STATISTICS'
PRINT '----------------------------------'

-- Top Wait Types (excluding benign waits)
SELECT TOP 15
    'Top Wait Types' AS [Category],
    wait_type AS [Wait_Type],
    wait_time_ms AS [Total_Wait_Time_MS],
    waiting_tasks_count AS [Wait_Count],
    CASE 
        WHEN waiting_tasks_count = 0 THEN 0
        ELSE wait_time_ms / waiting_tasks_count 
    END AS [Avg_Wait_Time_MS],
    CAST(100.0 * wait_time_ms / SUM(wait_time_ms) OVER() AS DECIMAL(5,2)) AS [Wait_Percentage]
FROM sys.dm_os_wait_stats
WHERE wait_type NOT IN (
    'CLR_SEMAPHORE','LAZYWRITER_SLEEP','RESOURCE_QUEUE','SLEEP_TASK',
    'SLEEP_SYSTEMTASK','SQLTRACE_BUFFER_FLUSH','WAITFOR','LOGMGR_QUEUE',
    'REQUEST_FOR_DEADLOCK_SEARCH','XE_TIMER_EVENT','BROKER_TO_FLUSH','BROKER_TASK_STOP',
    'CLR_MANUAL_EVENT','CLR_AUTO_EVENT','DISPATCHER_QUEUE_SEMAPHORE','FT_IFTS_SCHEDULER_IDLE_WAIT',
    'XE_DISPATCHER_WAIT', 'XE_DISPATCHER_JOIN'
)
AND wait_time_ms > 100
ORDER BY wait_time_ms DESC;

PRINT ''

-- Disk I/O Performance by Database File
SELECT TOP 20
    'Disk I/O Performance' AS [Category],
    DB_NAME(vfs.database_id) AS [Database_Name],
    mf.physical_name AS [File_Path],
    mf.type_desc AS [File_Type],
    vfs.num_of_reads,
    vfs.num_of_writes,
    vfs.io_stall_read_ms / NULLIF(vfs.num_of_reads, 0) AS [Avg_Read_Latency_MS],
    vfs.io_stall_write_ms / NULLIF(vfs.num_of_writes, 0) AS [Avg_Write_Latency_MS],
    (vfs.io_stall_read_ms + vfs.io_stall_write_ms) AS [Total_IO_Stall_MS]
FROM sys.dm_io_virtual_file_stats(NULL, NULL) AS vfs
    JOIN sys.master_files AS mf ON vfs.database_id = mf.database_id AND vfs.file_id = mf.file_id
WHERE vfs.num_of_reads > 0 OR vfs.num_of_writes > 0
ORDER BY [Total_IO_Stall_MS] DESC;

PRINT ''

-- ============================================================================
-- SECTION 8: DATABASE SUMMARY
-- ============================================================================
PRINT '8. DATABASE SUMMARY'
PRINT '------------------'

-- Database Overview
SELECT 
    'Database Overview' AS [Category],
    name AS [Database_Name],
    database_id AS [Database_ID],
    create_date AS [Created_Date],
    collation_name AS [Collation],
    state_desc AS [State],
    recovery_model_desc AS [Recovery_Model],
    page_verify_option_desc AS [Page_Verify],
    is_auto_close_on AS [Auto_Close],
    is_auto_shrink_on AS [Auto_Shrink],
    is_auto_create_stats_on AS [Auto_Create_Stats],
    is_auto_update_stats_on AS [Auto_Update_Stats],
    compatibility_level AS [Compatibility_Level]
FROM sys.databases
WHERE database_id > 4  -- Exclude system databases
ORDER BY name;

PRINT ''

-- ============================================================================
-- SECTION 9: SYSTEM HEALTH SUMMARY
-- ============================================================================
PRINT '9. SYSTEM HEALTH SUMMARY'
PRINT '-----------------------'

-- Quick Health Check Summary
SELECT 
    'Health Check Summary' AS [Category],
    (SELECT COUNT(*) FROM sys.databases WHERE state_desc <> 'ONLINE' AND database_id > 4) AS [Offline_User_Databases],
    (SELECT COUNT(*) FROM sys.dm_exec_requests WHERE blocking_session_id <> 0) AS [Currently_Blocked_Sessions],
    (SELECT COUNT(*) FROM sys.dm_os_waiting_tasks WHERE wait_type NOT LIKE '%SLEEP%') AS [Current_Wait_Tasks],
    DATEDIFF(DAY, sqlserver_start_time, GETDATE()) AS [Days_Since_SQL_Restart],
    (SELECT COUNT(*) FROM sys.databases WHERE is_auto_shrink_on = 1 AND database_id > 4) AS [Databases_With_AutoShrink],
    (SELECT COUNT(*) FROM sys.databases WHERE recovery_model_desc = 'FULL' AND database_id > 4) AS [Databases_In_Full_Recovery]
FROM sys.dm_os_sys_info;

PRINT ''
PRINT '================================================================================'
PRINT 'AUDIT COMPLETE - ' + CONVERT(VARCHAR, GETDATE(), 120)
PRINT '================================================================================'

/*
FOLLOW-UP QUERIES FOR DETAILED ANALYSIS:

-- Check for recent errors in SQL Server Error Log
EXEC xp_readerrorlog 0, 1, N'Error', N'', NULL, NULL, 'DESC';

-- Check backup status for all databases
SELECT 
    d.name AS DatabaseName,
    d.recovery_model_desc,
    ISNULL(b.last_full_backup, 'Never') AS LastFullBackup,
    ISNULL(b.last_log_backup, 'Never') AS LastLogBackup,
    DATEDIFF(day, b.last_full_backup, GETDATE()) AS DaysSinceFullBackup
FROM sys.databases d
LEFT JOIN (
    SELECT 
        database_name,
        MAX(CASE WHEN type = 'D' THEN backup_finish_date END) AS last_full_backup,
        MAX(CASE WHEN type = 'L' THEN backup_finish_date END) AS last_log_backup
    FROM msdb.dbo.backupset
    WHERE backup_finish_date >= DATEADD(day, -30, GETDATE())
    GROUP BY database_name
) b ON d.name = b.database_name
WHERE d.database_id > 4
ORDER BY d.name;

-- Check for index fragmentation issues
SELECT TOP 10
    OBJECT_NAME(ips.object_id) AS TableName,
    si.name AS IndexName,
    ips.avg_fragmentation_in_percent,
    ips.page_count
FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') ips
    INNER JOIN sys.indexes si ON ips.object_id = si.object_id AND ips.index_id = si.index_id
WHERE ips.avg_fragmentation_in_percent > 30
    AND ips.page_count > 100
ORDER BY ips.avg_fragmentation_in_percent DESC;
*/
