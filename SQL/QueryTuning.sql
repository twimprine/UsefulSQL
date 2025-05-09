/*
    This script identifies potential bottlenecks in SQL Server by analyzing wait statistics.
    It filters out common wait types that are not indicative of performance issues.
    The results are ordered by the total wait time in milliseconds.
*/

/*
| Metric           | Meaning                                             | What to Look For                                   |
|------------------|-----------------------------------------------------|----------------------------------------------------|
| avg_cpu          | Avg CPU per execution (μs)                          | High = Expensive logic, bad execution plans        |
| avg_duration     | Avg duration per execution (μs)                     | High = Slowness; maybe blocking, I/O, memory issues|
| execution_count  | Low = one-off or ad hoc                             | High = called frequently; focus on high CPU & freq |
| statement_text   | The SQL being executed                              | Look for missing indexes, bad patterns, UDFs, etc. |
*/


SELECT TOP 10
    total_worker_time / execution_count AS avg_cpu,
    total_elapsed_time / execution_count AS avg_duration,
    execution_count,
    statement_text = SUBSTRING(qt.text, (qs.statement_start_offset/2)+1,
    ((CASE qs.statement_end_offset
      WHEN -1 THEN DATALENGTH(qt.text)
      ELSE qs.statement_end_offset
     END - qs.statement_start_offset)/2)+1)
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) qt
ORDER BY avg_cpu DESC;
