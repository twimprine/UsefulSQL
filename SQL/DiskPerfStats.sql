/*
================================================================================
DISK PERFORMANCE STATISTICS SCRIPT
================================================================================

PURPOSE:
This script analyzes disk I/O performance for all database files by examining
virtual file statistics. It helps identify storage bottlenecks and performance
issues by calculating average read/write latencies per database file.

DESCRIPTION:
The script queries sys.dm_io_virtual_file_stats to gather cumulative I/O 
statistics since SQL Server startup. It calculates average latencies and 
presents the data ordered by worst write performance, as write latency 
typically impacts user experience more severely.

METRICS EXPLAINED:
- num_of_reads/writes: Total I/O operations since SQL Server started
- io_stall_read/write_ms: Total time SQL Server waited for I/O completion
- AvgReadLatencyMs: Average milliseconds per read operation
- AvgWriteLatencyMs: Average milliseconds per write operation
- physical_name: File path (helps identify which storage device)

INTERPRETATION GUIDELINES:
- Read Latency: <10ms excellent, 10-20ms good, >20ms investigate
- Write Latency: <5ms excellent, 5-15ms acceptable, >15ms investigate
- High latency + high operation count = significant performance impact
- Compare across files to identify problematic storage devices

USAGE:
1. Execute script to get current I/O statistics
2. Focus on files with highest latencies and operation counts
3. Cross-reference physical_name with storage configuration
4. Use results to guide storage optimization efforts

IMPORTANT CONSIDERATIONS:
- Statistics are cumulative since last SQL Server restart
- Results may be skewed if server recently restarted
- Zero operation counts will show NULL for average latencies
- Temporary spikes may not be visible in cumulative averages

USE CASES:
- Storage performance troubleshooting
- Database file placement optimization
- Storage hardware evaluation
- Performance baseline establishment
- Capacity planning for storage upgrades

REQUIREMENTS:
- SQL Server 2005 or later
- VIEW SERVER STATE permission
- Access to sys.dm_io_virtual_file_stats DMV

AUTHOR: Thomas Wimprine
CREATED: Various
LAST MODIFIED: 2025-06-04
================================================================================
*/

/*
Metric                | Meaning
---------------------|--------------------------------------------------------------
num_of_reads/writes  | Total read/write ops since SQL Server started
io_stall_read/write  | Total time (ms) SQL spent waiting for reads/writes to complete
AvgReadLatencyMs     | Time per read = stall time / ops (high = slow storage)
AvgWriteLatencyMs    | Time per write = same idea
physical_name        | Path to file – helps identify which disk or mount is slow
*/

SELECT
    DB_NAME(vfs.database_id) AS [Database],
    vfs.file_id,
    vfs.num_of_reads,
    vfs.num_of_writes,
    vfs.io_stall_read_ms,
    vfs.io_stall_write_ms,
    -- Calculate average latencies (NULLIF prevents divide by zero)
    vfs.io_stall_read_ms / NULLIF(vfs.num_of_reads, 0) AS [AvgReadLatencyMs],
    vfs.io_stall_write_ms / NULLIF(vfs.num_of_writes, 0) AS [AvgWriteLatencyMs],
    mf.physical_name
FROM sys.dm_io_virtual_file_stats(NULL, NULL) AS vfs -- NULL = all databases, all files
    JOIN sys.master_files AS mf
    ON vfs.database_id = mf.database_id
        AND vfs.file_id = mf.file_id
-- Order by worst write performance first (writes typically more critical)
ORDER BY [AvgWriteLatencyMs] DESC;

/*
SAMPLE OUTPUT INTERPRETATION:
Database | AvgReadLatencyMs | AvgWriteLatencyMs | Action
---------|------------------|-------------------|--------
MyDB     | 25               | 35                | Investigate storage
TestDB   | 8                | 12                | Good performance
LogDB    | 15               | 45                | Consider log file placement

FOLLOW-UP QUERIES:
-- Check for recent high I/O activity
SELECT TOP 10 * FROM sys.dm_exec_requests 
WHERE wait_type LIKE '%IO%' ORDER BY total_elapsed_time DESC;

-- Identify files with highest total wait time
SELECT physical_name, io_stall_read_ms + io_stall_write_ms AS total_io_stall_ms
FROM sys.dm_io_virtual_file_stats(NULL, NULL) vfs
JOIN sys.master_files mf ON vfs.database_id = mf.database_id AND vfs.file_id = mf.file_id
ORDER BY total_io_stall_ms DESC;
*/
