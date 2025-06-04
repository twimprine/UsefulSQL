/*
================================================================================
GET WAIT STATISTICS SCRIPT
================================================================================

PURPOSE:
This script retrieves SQL Server wait statistics to identify performance 
bottlenecks and resource contention issues. Wait statistics show where SQL 
Server spends time waiting for resources, helping pinpoint performance problems.

DESCRIPTION:
The script queries sys.dm_os_wait_stats DMV which contains cumulative wait 
statistics since SQL Server startup. Results are ordered by total wait time 
to highlight the most significant waits affecting server performance.

KEY WAIT TYPES TO MONITOR:
- PAGEIOLATCH_*: Disk I/O waits (storage performance issues)
- LCK_*: Lock waits (blocking/concurrency issues)
- CXPACKET: Parallelism waits (query tuning needed)
- SOS_SCHEDULER_YIELD: CPU pressure
- WRITELOG: Transaction log waits
- RESOURCE_SEMAPHORE: Memory pressure

INTERPRETATION:
- wait_time_ms: Total time spent waiting (higher = more impact)
- waiting_tasks_count: Number of waits (frequency)
- signal_wait_time_ms: Time waiting for CPU after resource became available
- max_wait_time_ms: Longest single wait

USAGE:
1. Execute script to get current wait statistics
2. Focus on top waits by wait_time_ms
3. Research specific wait types for root cause analysis
4. Use results to guide performance tuning efforts

IMPORTANT CONSIDERATIONS:
- Statistics are cumulative since last SQL Server restart
- Some wait types are normal and can be ignored (e.g., BROKER_*)
- Baseline wait stats before performance issues occur
- Clear wait stats periodically for better analysis: DBCC SQLPERF('sys.dm_os_wait_stats', CLEAR)

USE CASES:
- Performance troubleshooting
- Identifying resource bottlenecks
- Capacity planning
- Proactive monitoring
- Performance baseline establishment

REQUIREMENTS:
- SQL Server 2005 or later
- VIEW SERVER STATE permission
- Access to sys.dm_os_wait_stats DMV

AUTHOR: Thomas Wimprine
CREATED: Various
LAST MODIFIED: 2025-06-04
================================================================================
*/


-- Get all wait statistics ordered by total wait time (most impactful first)
SELECT * FROM sys.dm_os_wait_stats ORDER BY wait_time_ms DESC;

/*
ENHANCED WAIT STATS QUERY:
For more detailed analysis, use this enhanced version:

SELECT 
    wait_type,
    wait_time_ms,
    waiting_tasks_count,
    signal_wait_time_ms,
    wait_time_ms - signal_wait_time_ms AS resource_wait_time_ms,
    CASE 
        WHEN waiting_tasks_count = 0 THEN 0
        ELSE wait_time_ms / waiting_tasks_count 
    END AS avg_wait_time_ms,
    CAST(100.0 * wait_time_ms / SUM(wait_time_ms) OVER() AS DECIMAL(5,2)) AS wait_percentage
FROM sys.dm_os_wait_stats
WHERE wait_time_ms > 0
    AND wait_type NOT IN (  -- Filter out benign waits
        'BROKER_EVENTHANDLER', 'BROKER_RECEIVE_WAITFOR', 'BROKER_TASK_STOP',
        'BROKER_TO_FLUSH', 'BROKER_TRANSMITTER', 'CHECKPOINT_QUEUE',
        'CHKPT', 'CLR_AUTO_EVENT', 'CLR_MANUAL_EVENT', 'CLR_SEMAPHORE',
        'DBMIRROR_DBM_EVENT', 'DBMIRROR_EVENTS_QUEUE', 'DBMIRROR_WORKER_QUEUE',
        'DBMIRRORING_CMD', 'DIRTY_PAGE_POLL', 'DISPATCHER_QUEUE_SEMAPHORE',
        'EXECSYNC', 'FSAGENT', 'FT_IFTS_SCHEDULER_IDLE_WAIT', 'FT_IFTSHC_MUTEX',
        'HADR_CLUSAPI_CALL', 'HADR_FILESTREAM_IOMGR_IOCOMPLETION', 'HADR_LOGCAPTURE_WAIT',
        'HADR_NOTIFICATION_DEQUEUE', 'HADR_TIMER_TASK', 'HADR_WORK_QUEUE',
        'KSOURCE_WAKEUP', 'LAZYWRITER_SLEEP', 'LOGMGR_QUEUE', 'ONDEMAND_TASK_QUEUE',
        'PWAIT_ALL_COMPONENTS_INITIALIZED', 'QDS_PERSIST_TASK_MAIN_LOOP_SLEEP',
        'QDS_CLEANUP_STALE_QUERIES_TASK_MAIN_LOOP_SLEEP', 'REQUEST_FOR_DEADLOCK_SEARCH',
        'RESOURCE_QUEUE', 'SERVER_IDLE_CHECK', 'SLEEP_BPOOL_FLUSH', 'SLEEP_DBSTARTUP',
        'SLEEP_DCOMSTARTUP', 'SLEEP_MASTERDBREADY', 'SLEEP_MASTERMDREADY',
        'SLEEP_MASTERUPGRADED', 'SLEEP_MSDBSTARTUP', 'SLEEP_SYSTEMTASK', 'SLEEP_TASK',
        'SLEEP_TEMPDBSTARTUP', 'SNI_HTTP_ACCEPT', 'SP_SERVER_DIAGNOSTICS_SLEEP',
        'SQLTRACE_BUFFER_FLUSH', 'SQLTRACE_INCREMENTAL_FLUSH_SLEEP', 'SQLTRACE_WAIT_ENTRIES',
        'WAIT_FOR_RESULTS', 'WAITFOR', 'WAITFOR_TASKSHUTDOWN', 'WAIT_XTP_HOST_WAIT',
        'WAIT_XTP_OFFLINE_CKPT_NEW_LOG', 'WAIT_XTP_CKPT_CLOSE', 'XE_DISPATCHER_JOIN',
        'XE_DISPATCHER_WAIT', 'XE_TIMER_EVENT'
    )
ORDER BY wait_time_ms DESC;

CLEAR WAIT STATS (use for fresh analysis):
-- DBCC SQLPERF('sys.dm_os_wait_stats', CLEAR);
*/
