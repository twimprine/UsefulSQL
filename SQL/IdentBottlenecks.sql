/*
Wait Type    | Meaning              | Impact | Cause
-------------|-----------------     |---------------------
WRITELOG     | Log write delay      | High   | Disk I/O bottleneck
PAGEIOLATCH_*| Data file slow reads | High   | Storage Latency
CXPACKET    | Parallelism Bottleneck         | Medium | CPU/Memory bottleneck, Query tuning, MAXDOP
SOS_SCHEDULER_YIELD | CPU bottleneck       | Medium | CPU/Memory bottleneck, Insufficient CPU, Execution plan
ASYNC_NETWORK_IO | Network delay        | Medium | Network latency, Large result set, Client app

*/

SELECT wait_type, wait_time_ms, signal_wait_time_ms, waiting_tasks_count
FROM sys.dm_os_wait_stats
WHERE wait_type NOT IN (
  'CLR_SEMAPHORE','LAZYWRITER_SLEEP','RESOURCE_QUEUE','SLEEP_TASK',
  'SLEEP_SYSTEMTASK','SQLTRACE_BUFFER_FLUSH','WAITFOR','LOGMGR_QUEUE',
  'REQUEST_FOR_DEADLOCK_SEARCH','XE_TIMER_EVENT','BROKER_TO_FLUSH','BROKER_TASK_STOP',
  'CLR_MANUAL_EVENT','CLR_AUTO_EVENT','DISPATCHER_QUEUE_SEMAPHORE','FT_IFTS_SCHEDULER_IDLE_WAIT',
  'XE_DISPATCHER_WAIT', 'XE_DISPATCHER_JOIN'
)
ORDER BY wait_time_ms DESC;
