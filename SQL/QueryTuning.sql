/*
================================================================================
QUERY TUNING ANALYSIS SCRIPT
================================================================================

PURPOSE:
This script identifies high-CPU queries and performance bottlenecks by analyzing
query execution statistics. It helps pinpoint queries that consume the most
CPU resources and may benefit from optimization efforts.

DESCRIPTION:
The script queries sys.dm_exec_query_stats to find queries with the highest
average CPU usage per execution. It provides metrics to help prioritize
query tuning efforts based on CPU consumption and execution frequency.

ORIGINAL DOCUMENTATION:
This script identifies potential bottlenecks in SQL Server by analyzing wait statistics.
It filters out common wait types that are not indicative of performance issues.
The results are ordered by the total wait time in milliseconds.

METRICS EXPLANATION:
| Metric           | Meaning                                             | What to Look For                                   |
|------------------|-----------------------------------------------------|----------------------------------------------------|
| avg_cpu          | Avg CPU per execution (μs)                          | High = Expensive logic, bad execution plans        |
| avg_duration     | Avg duration per execution (μs)                     | High = Slowness; maybe blocking, I/O, memory issues|
| execution_count  | Low = one-off or ad hoc                             | High = called frequently; focus on high CPU & freq |
| statement_text   | The SQL being executed                              | Look for missing indexes, bad patterns, UDFs, etc. |

ANALYSIS APPROACH:
1. Focus on queries with high avg_cpu AND high execution_count
2. High avg_cpu with low execution_count may be ad-hoc queries
3. High execution_count with moderate avg_cpu may benefit from small optimizations
4. Look for patterns: missing indexes, table scans, UDF usage

USAGE:
1. Execute script to identify top CPU-consuming queries
2. Analyze the statement_text for optimization opportunities
3. Use execution plans to understand query behavior
4. Focus on frequently executed expensive queries first

OPTIMIZATION TECHNIQUES:
- Add missing indexes for high I/O queries
- Rewrite queries to eliminate unnecessary operations
- Replace scalar UDFs with inline functions or JOINs
- Optimize WHERE clauses and JOIN conditions
- Consider query plan forcing for regression cases

IMPORTANT CONSIDERATIONS:
- Statistics are since last SQL Server restart
- avg_cpu in microseconds (divide by 1000 for milliseconds)
- Large result sets may indicate SELECT * or missing WHERE clauses
- Consider both frequency and individual cost

USE CASES:
- Query performance tuning
- CPU bottleneck identification
- Performance regression analysis
- Optimization priority assessment
- Database health monitoring

REQUIREMENTS:
- SQL Server 2005 or later
- VIEW SERVER STATE permission
- Access to sys.dm_exec_query_stats DMV

AUTHOR: Query Performance Analysis
CREATED: Various
LAST MODIFIED: 2025-06-04
================================================================================
*/

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

-- filepath: c:\Users\ThomasWimprine\OneDrive - In-Telecom Consulting\Repositories\UsefulSQL\SQL\QueryTuning.sql
-- Find top 10 queries by average CPU consumption per execution
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

/*
ADDITIONAL ANALYSIS QUERIES:

1. TOP QUERIES BY TOTAL CPU (frequency × cost):
SELECT TOP 10
    total_worker_time AS total_cpu_time,
    total_worker_time / execution_count AS avg_cpu,
    execution_count,
    total_elapsed_time / execution_count AS avg_duration,
    SUBSTRING(qt.text, (qs.statement_start_offset/2)+1,
        ((CASE qs.statement_end_offset
          WHEN -1 THEN DATALENGTH(qt.text)
          ELSE qs.statement_end_offset
         END - qs.statement_start_offset)/2)+1) AS statement_text
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) qt
WHERE execution_count > 100  -- Focus on frequently executed queries
ORDER BY total_worker_time DESC;

2. TOP QUERIES BY LOGICAL READS (I/O intensive):
SELECT TOP 10
    total_logical_reads / execution_count AS avg_logical_reads,
    total_logical_reads,
    execution_count,
    total_worker_time / execution_count AS avg_cpu,
    SUBSTRING(qt.text, (qs.statement_start_offset/2)+1,
        ((CASE qs.statement_end_offset
          WHEN -1 THEN DATALENGTH(qt.text)
          ELSE qs.statement_end_offset
         END - qs.statement_start_offset)/2)+1) AS statement_text
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) qt
ORDER BY avg_logical_reads DESC;

3. RECENTLY EXECUTED EXPENSIVE QUERIES:
SELECT TOP 10
    total_worker_time / execution_count AS avg_cpu,
    execution_count,
    last_execution_time,
    SUBSTRING(qt.text, (qs.statement_start_offset/2)+1,
        ((CASE qs.statement_end_offset
          WHEN -1 THEN DATALENGTH(qt.text)
          ELSE qs.statement_end_offset
         END - qs.statement_start_offset)/2)+1) AS statement_text
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) qt
WHERE last_execution_time >= DATEADD(hour, -1, GETDATE())
ORDER BY avg_cpu DESC;
*/
