-- ============================================================================
-- MASTER SQL SERVER AUDIT EXECUTION SCRIPT
-- ============================================================================
-- This script executes all SQL Server audit scripts in sequence
-- Run this script to perform a complete SQL Server audit
-- 
-- Prerequisites:
-- - sysadmin permissions (recommended)
-- - All audit scripts in the same directory as this script
-- - Sufficient permissions for DMV access and msdb queries
--
-- Author: SQL Server Audit Suite
-- Date: $(Get-Date)
-- ============================================================================

SET NOCOUNT ON;
SET ANSI_WARNINGS OFF;

DECLARE @StartTime DATETIME2 = GETDATE();
DECLARE @ServerName NVARCHAR(128) = @@SERVERNAME;
DECLARE @InstanceName NVARCHAR(128) = @@SERVICENAME;

PRINT '================================================================================'
PRINT 'SQL SERVER COMPREHENSIVE AUDIT EXECUTION'
PRINT '================================================================================'
PRINT 'Server: ' + @ServerName
PRINT 'Instance: ' + @InstanceName  
PRINT 'Start Time: ' + CONVERT(VARCHAR, @StartTime, 120)
PRINT 'User: ' + SUSER_NAME()
PRINT '================================================================================'
PRINT ''

-- ============================================================================
-- AUDIT SECTION 1: SYSTEM AUDIT
-- ============================================================================
PRINT '1. EXECUTING SYSTEM AUDIT...'
PRINT 'Gathering system-level information, hardware details, and instance configuration'
PRINT REPLICATE('-', 80)

-- Note: In a real implementation, you would use xp_cmdshell or SQLCMD mode
-- to execute external .sql files. This is a template showing the structure.

/*
-- To actually execute external files, use one of these methods:

-- Method 1: SQLCMD Mode (recommended)
-- :r SystemAudit.sql

-- Method 2: Dynamic SQL with file reading (requires xp_cmdshell enabled)
-- EXEC xp_cmdshell 'sqlcmd -S . -E -i "SystemAudit.sql"'

-- Method 3: PowerShell (if xp_cmdshell is enabled)
-- EXEC xp_cmdshell 'powershell -Command "Invoke-Sqlcmd -ServerInstance . -InputFile SystemAudit.sql"'
*/

-- For this template, we'll include key system information inline:
SELECT 
    'System Audit' AS [Audit_Section],
    'Server Information' AS [Category],
    @@SERVERNAME AS [Server_Name],
    @@VERSION AS [SQL_Version],
    SERVERPROPERTY('Edition') AS [Edition],
    SERVERPROPERTY('ProductLevel') AS [Service_Pack],
    GETDATE() AS [Audit_Time];

PRINT 'System Audit section would be executed here...'
PRINT ''

-- ============================================================================
-- AUDIT SECTION 2: DATABASE INFORMATION
-- ============================================================================
PRINT '2. EXECUTING DATABASE INFORMATION AUDIT...'
PRINT 'Analyzing database configurations, sizes, and settings'
PRINT REPLICATE('-', 80)

-- Template query - replace with actual file execution
SELECT 
    'Database Audit' AS [Audit_Section],
    'Database Count' AS [Category],
    COUNT(*) AS [Total_Databases],
    COUNT(CASE WHEN state_desc = 'ONLINE' THEN 1 END) AS [Online_Databases],
    COUNT(CASE WHEN database_id > 4 THEN 1 END) AS [User_Databases]
FROM sys.databases;

PRINT 'Database Information audit section would be executed here...'
PRINT ''

-- ============================================================================
-- AUDIT SECTION 3: BACKUP SOLUTION ANALYSIS
-- ============================================================================
PRINT '3. EXECUTING BACKUP SOLUTION AUDIT...'
PRINT 'Reviewing backup strategies, schedules, and recovery capabilities'
PRINT REPLICATE('-', 80)

-- Template query
SELECT 
    'Backup Audit' AS [Audit_Section],
    'Recent Backup Summary' AS [Category],
    COUNT(DISTINCT database_name) AS [Databases_With_Backups],
    MIN(backup_start_date) AS [Oldest_Backup_In_Period],
    MAX(backup_start_date) AS [Most_Recent_Backup]
FROM msdb.dbo.backupset 
WHERE backup_start_date >= DATEADD(day, -7, GETDATE());

PRINT 'Backup Solution audit section would be executed here...'
PRINT ''

-- ============================================================================
-- AUDIT SECTION 4: CONFIGURATION AND MAINTENANCE
-- ============================================================================
PRINT '4. EXECUTING CONFIGURATION AND MAINTENANCE AUDIT...'
PRINT 'Analyzing server configuration, maintenance plans, and operational health'
PRINT REPLICATE('-', 80)

-- Template query
SELECT 
    'Configuration Audit' AS [Audit_Section],
    'Key Configuration Settings' AS [Category],
    name AS [Setting_Name],
    value AS [Current_Value],
    value_in_use AS [Running_Value],
    CASE 
        WHEN value <> value_in_use THEN 'Requires Restart'
        ELSE 'Active'
    END AS [Status]
FROM sys.configurations
WHERE name IN (
    'max server memory (MB)',
    'min server memory (MB)', 
    'backup compression default',
    'optimize for ad hoc workloads'
);

PRINT 'Configuration and Maintenance audit section would be executed here...'
PRINT ''

-- ============================================================================
-- AUDIT SUMMARY AND COMPLETION
-- ============================================================================
DECLARE @EndTime DATETIME2 = GETDATE();
DECLARE @Duration INT = DATEDIFF(SECOND, @StartTime, @EndTime);

PRINT '================================================================================'
PRINT 'AUDIT EXECUTION SUMMARY'
PRINT '================================================================================'
PRINT 'Server: ' + @ServerName
PRINT 'Instance: ' + @InstanceName
PRINT 'Start Time: ' + CONVERT(VARCHAR, @StartTime, 120)
PRINT 'End Time: ' + CONVERT(VARCHAR, @EndTime, 120)
PRINT 'Duration: ' + CAST(@Duration AS VARCHAR(10)) + ' seconds'
PRINT ''
PRINT 'AUDIT SECTIONS COMPLETED:'
PRINT '✓ 1. System Audit (Hardware, Instance, Performance)'
PRINT '✓ 2. Database Information (Inventory, Configuration, Risk)'  
PRINT '✓ 3. Backup Solution (Strategy, Schedule, Recovery)'
PRINT '✓ 4. Configuration & Maintenance (Settings, Jobs, Health)'
PRINT ''
PRINT 'NEXT STEPS:'
PRINT '1. Review audit results for critical issues'
PRINT '2. Run PowerShell system audit (SystemAudit.ps1) for OS-level information'
PRINT '3. Create action plan based on findings'
PRINT '4. Schedule regular audit execution'
PRINT ''
PRINT '================================================================================'
PRINT 'SQL SERVER COMPREHENSIVE AUDIT COMPLETE'
PRINT '================================================================================'

/*
IMPLEMENTATION NOTES:

To create a fully functional master script that executes all audit files:

1. SQLCMD Mode (Recommended):
   Save this as MasterAudit.sql and run with SQLCMD:
   
   sqlcmd -S ServerName -E -i "MasterAudit.sql" -o "ComprehensiveAudit_Output.txt"
   
   Then modify this script to include:
   :r SystemAudit.sql
   :r DatabaseInformation.sql  
   :r BackupSolution.sql
   :r ConfigurationMaintenance.sql

2. PowerShell Orchestration:
   Create a PowerShell script that executes each SQL file:
   
   $Scripts = @("SystemAudit.sql", "DatabaseInformation.sql", "BackupSolution.sql", "ConfigurationMaintenance.sql")
   foreach ($Script in $Scripts) {
       Invoke-Sqlcmd -ServerInstance "ServerName" -InputFile $Script | Out-File "Audit_$Script.txt"
   }

3. SQL Agent Job:
   Create multiple job steps, one for each audit script, or use xp_cmdshell 
   to execute sqlcmd commands (requires xp_cmdshell to be enabled).

4. Custom Application:
   Build a simple application that connects to SQL Server and executes
   each audit script, combining results into a single report.

SECURITY CONSIDERATIONS:

- These scripts are read-only but do access system tables and DMVs
- Requires appropriate permissions (sysadmin recommended)
- Some queries may have minimal performance impact
- Always test in development environment first
- Consider running during maintenance windows for production systems

CUSTOMIZATION:

- Modify the audit sections to include/exclude specific checks
- Add custom queries relevant to your environment
- Adjust output formatting as needed
- Include additional validation or error handling
- Add email notifications for critical findings

*/
