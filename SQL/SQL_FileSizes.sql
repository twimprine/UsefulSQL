/*
================================================================================
SQL SERVER DATABASE FILE SIZES SCRIPT
================================================================================

PURPOSE:
This script provides a comprehensive overview of all database files across
all databases on the SQL Server instance, showing their logical names,
physical locations, types, and sizes in both MB and GB.

DESCRIPTION:
The script queries sys.master_files and sys.databases to retrieve information
about all database files including data files, log files, and any additional
filegroups. It calculates sizes in human-readable formats for capacity planning
and disk space management.

OUTPUT COLUMNS:
- database_name: Name of the database
- logical_name: Logical file name used in T-SQL commands
- physical_name: Full path to the physical file on disk
- type_desc: File type (ROWS = data, LOG = transaction log, FILESTREAM, etc.)
- size_mb: Current file size in megabytes
- size_gb: Current file size in gigabytes

FILE TYPES EXPLAINED:
- ROWS: Primary data files (.mdf) and secondary data files (.ndf)
- LOG: Transaction log files (.ldf)
- FILESTREAM: FILESTREAM data files (if used)
- FULLTEXT: Full-text catalog files (if used)

USAGE:
1. Execute script to get comprehensive file size overview
2. Use results for capacity planning and disk space monitoring
3. Identify large files that may need attention
4. Plan file growth and storage allocation

SIZE CALCULATIONS:
- SQL Server stores sizes in 8KB pages
- Formula: size_in_pages × 8KB ÷ 1024 = size_in_MB
- Formula: size_in_MB ÷ 1024 = size_in_GB

IMPORTANT CONSIDERATIONS:
- Shows allocated size, not actual used space within files
- Files may have auto-growth enabled beyond current size
- Consider both data and log file sizes for planning
- Monitor growth patterns over time

USE CASES:
- Disk space monitoring and planning
- Database file inventory
- Storage capacity analysis
- File placement optimization
- Backup size estimation

REQUIREMENTS:
- SQL Server 2005 or later
- VIEW ANY DATABASE permission or sysadmin role
- Access to sys.master_files and sys.databases

AUTHOR: Thomas Wimprine
CREATED: Various
LAST MODIFIED: 2025-06-04
================================================================================
*/


SELECT 
    db.name AS database_name,
    mf.name AS logical_name,
    mf.physical_name,
    mf.type_desc,
    CONVERT(DECIMAL(10,2), mf.size * 8.0 / 1024) AS size_mb,      -- Convert 8KB pages to MB
    CONVERT(DECIMAL(10,2), mf.size * 8.0 / 1024 / 1024) AS size_gb -- Convert MB to GB
FROM 
    sys.master_files mf
JOIN 
    sys.databases db ON db.database_id = mf.database_id
ORDER BY 
    db.name, mf.type_desc;

/*
ENHANCED FILE SIZE ANALYSIS:

1. DETAILED FILE INFORMATION WITH GROWTH SETTINGS:
SELECT 
    db.name AS database_name,
    mf.name AS logical_name,
    mf.physical_name,
    mf.type_desc,
    CONVERT(DECIMAL(10,2), mf.size * 8.0 / 1024) AS current_size_mb,
    CASE 
        WHEN mf.max_size = -1 THEN 'Unlimited'
        WHEN mf.max_size = 268435456 THEN 'Unlimited (2TB)'
        ELSE CONVERT(VARCHAR(20), CONVERT(DECIMAL(10,2), mf.max_size * 8.0 / 1024)) + ' MB'
    END AS max_size,
    CASE 
        WHEN mf.is_percent_growth = 1 THEN CONVERT(VARCHAR(10), mf.growth) + '%'
        ELSE CONVERT(VARCHAR(20), CONVERT(DECIMAL(10,2), mf.growth * 8.0 / 1024)) + ' MB'
    END AS growth_setting,
    db.state_desc AS database_state
FROM sys.master_files mf
    JOIN sys.databases db ON db.database_id = mf.database_id
ORDER BY db.name, mf.type_desc;

2. SUMMARY BY DATABASE:
SELECT 
    db.name AS database_name,
    COUNT(*) AS total_files,
    SUM(CASE WHEN mf.type_desc = 'ROWS' THEN 1 ELSE 0 END) AS data_files,
    SUM(CASE WHEN mf.type_desc = 'LOG' THEN 1 ELSE 0 END) AS log_files,
    CONVERT(DECIMAL(10,2), SUM(CASE WHEN mf.type_desc = 'ROWS' THEN mf.size * 8.0 / 1024 ELSE 0 END)) AS total_data_size_mb,
    CONVERT(DECIMAL(10,2), SUM(CASE WHEN mf.type_desc = 'LOG' THEN mf.size * 8.0 / 1024 ELSE 0 END)) AS total_log_size_mb,
    CONVERT(DECIMAL(10,2), SUM(mf.size * 8.0 / 1024)) AS total_database_size_mb
FROM sys.master_files mf
    JOIN sys.databases db ON db.database_id = mf.database_id
GROUP BY db.name
ORDER BY total_database_size_mb DESC;

3. LARGE FILES IDENTIFICATION:
SELECT 
    db.name AS database_name,
    mf.name AS logical_name,
    mf.type_desc,
    CONVERT(DECIMAL(10,2), mf.size * 8.0 / 1024) AS size_mb,
    mf.physical_name
FROM sys.master_files mf
    JOIN sys.databases db ON db.database_id = mf.database_id
WHERE mf.size * 8.0 / 1024 > 1000  -- Files larger than 1GB
ORDER BY mf.size DESC;

4. TOTAL STORAGE USAGE:
SELECT 
    'Total Storage Usage' AS summary,
    COUNT(*) AS total_files,
    CONVERT(DECIMAL(10,2), SUM(mf.size * 8.0 / 1024)) AS total_size_mb,
    CONVERT(DECIMAL(10,2), SUM(mf.size * 8.0 / 1024 / 1024)) AS total_size_gb
FROM sys.master_files mf
    JOIN sys.databases db ON db.database_id = mf.database_id;
*/
