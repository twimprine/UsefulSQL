/*
================================================================================
IDENTIFY BOTTLENECKS SCRIPT
================================================================================

PURPOSE:
This script identifies SQL Server performance bottlenecks by analyzing wait
statistics and filtering out benign wait types. It focuses on waits that
indicate real performance issues requiring attention.

DESCRIPTION:
The script queries sys.dm_os_wait_stats while excluding common background
wait types that don't indicate performance problems. It provides a reference
table of critical wait types and their meanings to help with diagnosis.

CRITICAL WAIT TYPES REFERENCE:
Wait Type            | Meaning                    | Impact | Typical Causes
---------------------|----------------------------|--------|----------------------------------
WRITELOG             | Log write delays           | High   | Slow transaction log storage
PAGEIOLATCH_*        | Data file read delays      | High   | Slow data file storage
CXPACKET             | Parallelism bottleneck     | Medium | CPU pressure, poor query plans
SOS_SCHEDULER_YIELD  | CPU bottleneck             | Medium | Insufficient CPU resources
ASYNC_NETWORK_IO     | Network delays             | Medium | Network latency, large result sets
LCK_*                | Lock waits                 | High   | Blocking, poor indexing
RESOURCE_SEMAPHORE   | Memory pressure            | High   | Insufficient memory grants
PAGEIOLATCH_SH/EX    | Page latch contention      | Medium | Hot pages, poor indexing

OUTPUT COLUMNS:
- wait_type: Type of wait encountered
- wait_time_ms: Total time spent waiting (cumulative)
- signal_wait_time_ms: Time waiting for CPU after resource available
- waiting_tasks_count: Number of tasks that waited

INTERPRETATION:
- High wait_time_ms indicates significant impact on performance
- High waiting_tasks_count indicates frequent occurrence
- Focus on top waits by wait_time_ms for biggest impact

USAGE:
1. Execute script to see current bottlenecks
2. Focus on highest wait_time_ms values
3. Use wait type reference to understand root causes
4. Implement appropriate solutions based on wait types

IMPORTANT CONSIDERATIONS:
- Statistics are cumulative since SQL Server restart
- Excludes benign background waits for clearer analysis
- Some waits are normal in small amounts
- Clear wait stats for fresh analysis if needed

FOLLOW-UP ACTIONS BY WAIT TYPE:
- WRITELOG: Optimize transaction log storage, reduce transaction sizes
- PAGEIOLATCH_*: Optimize data file storage, add indexes
- CXPACKET: Tune MAXDOP, optimize queries, check CPU capacity
- SOS_SCHEDULER_YIELD: Add CPU resources, optimize queries
- ASYNC_NETWORK_IO: Optimize network, reduce result set sizes

REQUIREMENTS:
- SQL Server 2005 or later
- VIEW SERVER STATE permission
- Access to sys.dm_os_wait_stats DMV

AUTHOR: Performance Diagnostics
CREATED: Various
LAST MODIFIED: 2025-06-04
================================================================================
*/

/*
Wait Type    | Meaning              | Impact | Cause
-------------|-----------------     |---------------------
WRITELOG     | Log write delay      | High   | Disk I/O bottleneck
PAGEIOLATCH_*| Data file slow reads | High   | Storage Latency
CXPACKET    | Parallelism Bottleneck         | Medium | CPU/Memory bottleneck, Query tuning, MAXDOP
SOS_SCHEDULER_YIELD | CPU bottleneck       | Medium | CPU/Memory bottleneck, Insufficient CPU, Execution plan
ASYNC_NETWORK_IO | Network delay        | Medium | Network latency, Large result set, Client app

*/

-- filepath: c:\Users\ThomasWimprine\OneDrive - In-Telecom Consulting\Repositories\UsefulSQL\SQL\IdentBottlenecks.sql
SELECT wait_type, wait_time_ms, signal_wait_time_ms, waiting_tasks_count
FROM sys.dm_os_wait_stats
WHERE wait_type NOT IN (
  -- Exclude benign/background wait types that don't indicate performance issues
  'CLR_SEMAPHORE','LAZYWRITER_SLEEP','RESOURCE_QUEUE','SLEEP_TASK',
  'SLEEP_SYSTEMTASK','SQLTRACE_BUFFER_FLUSH','WAITFOR','LOGMGR_QUEUE',
  'REQUEST_FOR_DEADLOCK_SEARCH','XE_TIMER_EVENT','BROKER_TO_FLUSH','BROKER_TASK_STOP',
  'CLR_MANUAL_EVENT','CLR_AUTO_EVENT','DISPATCHER_QUEUE_SEMAPHORE','FT_IFTS_SCHEDULER_IDLE_WAIT',
  'XE_DISPATCHER_WAIT', 'XE_DISPATCHER_JOIN'
)
ORDER BY wait_time_ms DESC;

/*
ENHANCED BOTTLENECK ANALYSIS:
-- Include percentage calculations and filtering for significant waits

SELECT 
    wait_type,
    wait_time_ms,
    signal_wait_time_ms,
    wait_time_ms - signal_wait_time_ms AS resource_wait_time_ms,
    waiting_tasks_count,
    CASE 
        WHEN waiting_tasks_count = 0 THEN 0
        ELSE wait_time_ms / waiting_tasks_count 
    END AS avg_wait_time_ms,
    CAST(100.0 * wait_time_ms / SUM(wait_time_ms) OVER() AS DECIMAL(5,2)) AS wait_percentage
FROM sys.dm_os_wait_stats
WHERE wait_time_ms > 1000  -- Only show waits > 1 second total
    AND wait_type NOT IN (
        'CLR_SEMAPHORE','LAZYWRITER_SLEEP','RESOURCE_QUEUE','SLEEP_TASK',
        'SLEEP_SYSTEMTASK','SQLTRACE_BUFFER_FLUSH','WAITFOR','LOGMGR_QUEUE',
        'REQUEST_FOR_DEADLOCK_SEARCH','XE_TIMER_EVENT','BROKER_TO_FLUSH','BROKER_TASK_STOP',
        'CLR_MANUAL_EVENT','CLR_AUTO_EVENT','DISPATCHER_QUEUE_SEMAPHORE','FT_IFTS_SCHEDULER_IDLE_WAIT',
        'XE_DISPATCHER_WAIT', 'XE_DISPATCHER_JOIN'
    )
ORDER BY wait_time_ms DESC;

CLEAR WAIT STATISTICS (for fresh analysis):
-- Uncomment to reset wait statistics
-- DBCC SQLPERF('sys.dm_os_wait_stats', CLEAR);
*/
