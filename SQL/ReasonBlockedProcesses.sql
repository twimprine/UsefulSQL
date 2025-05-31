/* 

This script is designed to identify blocked processes in SQL Server.
It retrieves information about the blocking session, including the session ID, status, command, start time, wait type, wait resource, blocking session ID, percent complete*, estimated completion time*, and the SQL text of the request.

1 - Execute the `sp_who2` stored procedure to get a quick overview of all active sessions, including blocked processes.
2 - Use the `sys.dm_exec_requests` and `sys.dm_exec_sessions` dynamic management views to get detailed information about the specific session that is blocked.

* Note: Percent complete and estimated completion time may not be available for all commands.

*/

EXEC sp_who2


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
WHERE r.session_id =<BLOCKING ID FROM PRIOR QUERY>;
