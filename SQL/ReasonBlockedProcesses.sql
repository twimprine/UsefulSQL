/*
================================================================================
BLOCKED PROCESSES ANALYSIS SCRIPT
================================================================================

PURPOSE:
This script identifies and analyzes blocked processes in SQL Server, providing
detailed information about blocking chains, wait resources, and the specific
SQL statements involved in blocking scenarios.

DESCRIPTION:
The script uses a two-step approach to diagnose blocking:
1. sp_who2 provides a quick overview of all sessions including blocked ones
2. sys.dm_exec_requests provides detailed analysis of specific blocking scenarios

The script helps identify the root cause of blocking by showing both the 
blocking and blocked sessions along with their SQL text and wait information.

ORIGINAL DOCUMENTATION:
This script is designed to identify blocked processes in SQL Server.
It retrieves information about the blocking session, including the session ID, status, command, start time, wait type, wait resource, blocking session ID, percent complete*, and the SQL text of the request.

1 - Execute the `sp_who2` stored procedure to get a quick overview of all active sessions, including blocked processes.
2 - Use the `sys.dm_exec_requests` and `sys.dm_exec_sessions` dynamic management views to get detailed information about the specific session that is blocked.

* Note: Percent complete and estimated completion time may not be available for all commands.

OUTPUT COLUMNS:
- session_id: ID of the session experiencing blocking
- status: Current status of the request
- command: Type of command being executed
- start_time: When the request started
- wait_type: What the session is waiting for
- wait_resource: Specific resource being waited for
- blocking_session_id: Session ID causing the block
- percent_complete: Progress percentage (if available)
- estimated_completion_time: Expected completion time (if available)
- sql_text: The actual SQL statement being blocked

USAGE:
1. Execute sp_who2 to see all sessions and identify blocked ones
2. Look for sessions with non-zero 'BlkBy' values
3. Replace <BLOCKING ID FROM PRIOR QUERY> with actual session ID
4. Execute the detailed query to analyze the specific blocking scenario

BLOCKING ANALYSIS STEPS:
1. Identify blocking chains (who blocks whom)
2. Examine wait_type and wait_resource for root cause
3. Review SQL text of both blocking and blocked queries
4. Determine if blocking is expected or requires intervention

COMMON WAIT TYPES:
- LCK_M_*: Lock waits (exclusive, shared, etc.)
- PAGEIOLATCH_*: I/O waits
- PAGELATCH_*: Buffer latch waits
- RESOURCE_SEMAPHORE: Memory grant waits

USE CASES:
- Troubleshooting performance issues
- Identifying long-running transactions
- Analyzing application blocking patterns
- Real-time blocking monitoring
- Deadlock investigation

REQUIREMENTS:
- SQL Server 2005 or later
- VIEW SERVER STATE permission
- Access to DMVs and sp_who2

AUTHOR: Thomas Wimprine
CREATED: Various
LAST MODIFIED: 2025-06-04
================================================================================
*/

/* 

This script is designed to identify blocked processes in SQL Server.
It retrieves information about the blocking session, including the session ID, status, command, start time, wait_type, wait_resource, blocking_session_id, percent_complete*, and the SQL text of the request.

1 - Execute the `sp_who2` stored procedure to get a quick overview of all active sessions, including blocked processes.
2 - Use the `sys.dm_exec_requests` and `sys.dm_exec_sessions` dynamic management views to get detailed information about the specific session that is blocked.

* Note: Percent complete and estimated completion time may not be available for all commands.

*/


-- Step 1: Get overview of all sessions to identify blocked processes
-- Look for non-zero values in the 'BlkBy' column
EXEC sp_who2

-- Step 2: Get detailed information about a specific blocked session
-- Replace <BLOCKING ID FROM PRIOR QUERY> with the actual session_id from sp_who2 results
SELECT
    r.session_id,
    r.status,
    r.command,
    r.start_time,
    r.wait_type,
    r.wait_resource,
    r.blocking_session_id,
    r.percent_complete,
    r.estimated_completion_time,
    t.text AS sql_text
FROM sys.dm_exec_requests r
    JOIN sys.dm_exec_sessions s ON r.session_id = s.session_id
CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
WHERE r.session_id = 999; -- Replace 999 with actual session ID from sp_who2 results

/*
ENHANCED BLOCKING ANALYSIS:

1. COMPLETE BLOCKING CHAIN ANALYSIS:
-- Shows both blocking and blocked sessions with their SQL
WITH BlockingChain AS (
    SELECT 
        r.session_id,
        r.blocking_session_id,
        r.wait_type,
        r.wait_resource,
        r.wait_time,
        s.login_name,
        s.program_name,
        s.host_name,
        t.text AS sql_text,
        0 AS level
    FROM sys.dm_exec_requests r
        JOIN sys.dm_exec_sessions s ON r.session_id = s.session_id
        CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
    WHERE r.blocking_session_id = 0 
        AND EXISTS (SELECT 1 FROM sys.dm_exec_requests r2 WHERE r2.blocking_session_id = r.session_id)
    
    UNION ALL
    
    SELECT 
        r.session_id,
        r.blocking_session_id,
        r.wait_type,
        r.wait_resource,
        r.wait_time,
        s.login_name,
        s.program_name,
        s.host_name,
        t.text AS sql_text,
        bc.level + 1
    FROM sys.dm_exec_requests r
        JOIN sys.dm_exec_sessions s ON r.session_id = s.session_id
        CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
        JOIN BlockingChain bc ON r.blocking_session_id = bc.session_id
)
SELECT * FROM BlockingChain
ORDER BY level, session_id;

2. ACTIVE BLOCKING SESSIONS:
-- Shows only sessions currently involved in blocking
SELECT 
    r.session_id,
    r.blocking_session_id,
    r.wait_type,
    r.wait_resource,
    r.wait_time / 1000.0 AS wait_time_seconds,
    s.login_name,
    s.program_name,
    SUBSTRING(t.text, (r.statement_start_offset/2)+1,
        ((CASE r.statement_end_offset
          WHEN -1 THEN DATALENGTH(t.text)
          ELSE r.statement_end_offset
         END - r.statement_start_offset)/2)+1) AS current_statement
FROM sys.dm_exec_requests r
    JOIN sys.dm_exec_sessions s ON r.session_id = s.session_id
    CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
WHERE r.blocking_session_id <> 0
ORDER BY r.wait_time DESC;

3. KILL BLOCKING SESSION (use with caution):
-- KILL <session_id>; -- Uncomment and replace with actual session ID
*/
