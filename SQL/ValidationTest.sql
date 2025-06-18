/*
================================================================================
SQL AUDIT SCRIPTS VALIDATION TEST
================================================================================

PURPOSE:
This script performs basic validation tests to ensure the audit scripts
will execute successfully on the target SQL Server environment.

DESCRIPTION:
This validation script tests key components and permissions required by
the main audit scripts. It checks for:
- Basic SQL syntax compatibility
- Required system permissions
- Availability of system objects and DMVs
- Access to msdb database for job and backup information

USAGE:
Run this script before executing the main audit scripts to identify
any potential compatibility or permission issues.

KEY CONCEPTS FOR NON-DBAs:
- Dynamic Management Views (DMVs): Built-in views that provide system information
- System Objects: Built-in tables and views that store SQL Server metadata
- Permissions: Security rights needed to access specific information
- msdb Database: System database that stores SQL Server Agent and backup information

REQUIREMENTS:
- SQL Server 2005 or later
- Basic SELECT permissions on system views
- Access to msdb database

AUTHOR: Thomas Wimprine
CREATED: 2025-06-18
LAST MODIFIED: 2025-06-18
================================================================================
*/

-- SQL Syntax Validation Script for Audit Scripts
-- This script performs basic syntax validation and permission checks

PRINT '================================================================================'
PRINT 'SQL AUDIT SCRIPTS VALIDATION TEST - ' + CONVERT(VARCHAR, GETDATE(), 120)
PRINT '================================================================================'
PRINT 'Testing compatibility and permissions for audit scripts...'
PRINT ''

-- Test 1: Basic SELECT query and SQL Server version check
BEGIN TRY
    DECLARE @SQLVersion VARCHAR(100) = @@VERSION
    SELECT 'Test 1: Basic SELECT & Version Check' AS Test_Name, 'PASSED' AS Result, 
           'SQL Server detected: ' + LEFT(@SQLVersion, 50) + '...' AS Details
END TRY
BEGIN CATCH
    SELECT 'Test 1: Basic SELECT & Version Check' AS Test_Name, 'FAILED: ' + ERROR_MESSAGE() AS Result, '' AS Details
END CATCH

-- Test 2: Memory Configuration Access (sys.configurations)
BEGIN TRY
    IF EXISTS (SELECT 1 FROM sys.configurations WHERE name = 'max server memory (MB)')
        SELECT 'Test 2: Memory Config Access' AS Test_Name, 'PASSED' AS Result,
               'Can access sys.configurations for memory settings' AS Details
    ELSE
        SELECT 'Test 2: Memory Config Access' AS Test_Name, 'WARNING' AS Result,
               'max server memory config not found - may be older SQL version' AS Details
END TRY
BEGIN CATCH
    SELECT 'Test 2: Memory Config Access' AS Test_Name, 'FAILED: ' + ERROR_MESSAGE() AS Result, 
           'Cannot access sys.configurations - may need VIEW SERVER STATE permission' AS Details
END CATCH

-- Test 3: TempDB Files Access (sys.master_files)
BEGIN TRY
    IF EXISTS (SELECT 1 FROM sys.master_files WHERE database_id = 2)
        SELECT 'Test 3: TempDB Files Access' AS Test_Name, 'PASSED' AS Result,
               'Can access sys.master_files for database file information' AS Details
    ELSE
        SELECT 'Test 3: TempDB Files Access' AS Test_Name, 'WARNING' AS Result,
               'TempDB files not found - unusual configuration' AS Details
END TRY
BEGIN CATCH
    SELECT 'Test 3: TempDB Files Access' AS Test_Name, 'FAILED: ' + ERROR_MESSAGE() AS Result,
           'Cannot access sys.master_files - may need VIEW ANY DATABASE permission' AS Details
END CATCH

-- Test 4: SQL Agent Jobs Access (msdb database)
BEGIN TRY
    IF EXISTS (SELECT 1 FROM msdb.dbo.sysjobs)
        SELECT 'Test 4: SQL Agent Jobs Access' AS Test_Name, 'PASSED' AS Result,
               'Can access msdb.dbo.sysjobs for job information' AS Details
    ELSE
        SELECT 'Test 4: SQL Agent Jobs Access' AS Test_Name, 'WARNING' AS Result,
               'No SQL Agent jobs found - may be Express edition or jobs not configured' AS Details
END TRY
BEGIN CATCH
    SELECT 'Test 4: SQL Agent Jobs Access' AS Test_Name, 'FAILED: ' + ERROR_MESSAGE() AS Result,
           'Cannot access msdb.dbo.sysjobs - may need permissions on msdb database' AS Details
END CATCH

-- Test 5: Buffer Pool Access (Dynamic Management Views)
BEGIN TRY
    IF EXISTS (SELECT TOP 1 1 FROM sys.dm_os_buffer_descriptors)
        SELECT 'Test 5: Buffer Pool Query' AS Test_Name, 'PASSED' AS Result
    ELSE
        SELECT 'Test 5: Buffer Pool Query' AS Test_Name, 'WARNING: No buffer descriptors found' AS Result
END TRY
BEGIN CATCH
    SELECT 'Test 5: Buffer Pool Query' AS Test_Name, 'FAILED: ' + ERROR_MESSAGE() AS Result
END CATCH

-- Test 6: Database States Query
BEGIN TRY
    IF EXISTS (SELECT 1 FROM sys.databases WHERE database_id > 4)
        SELECT 'Test 6: Database States Query' AS Test_Name, 'PASSED' AS Result
    ELSE
        SELECT 'Test 6: Database States Query' AS Test_Name, 'WARNING: Only system databases found' AS Result
END TRY
BEGIN CATCH
    SELECT 'Test 6: Database States Query' AS Test_Name, 'FAILED: ' + ERROR_MESSAGE() AS Result
END CATCH

PRINT ''
PRINT 'SQL Syntax Validation Complete'
