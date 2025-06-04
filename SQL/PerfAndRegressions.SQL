/*
================================================================================
PERFORMANCE AND REGRESSIONS ANALYSIS SCRIPT
================================================================================

PURPOSE:
This script uses Query Store data to identify performance regressions and
analyze query execution patterns over time. Query Store provides historical
query performance data that helps identify when performance degraded.

DESCRIPTION:
The script joins Query Store catalog views to retrieve query text, execution
plans, and runtime statistics. This foundation can be extended to identify
specific performance regressions, plan changes, and execution patterns.

QUERY STORE COMPONENTS:
- sys.query_store_query_text: Actual SQL query text
- sys.query_store_query: Query metadata and fingerprints  
- sys.query_store_plan: Execution plans for queries
- sys.query_store_runtime_stats: Execution statistics over time

CURRENT SCRIPT STATUS:
This is a foundational query that needs to be extended for specific analysis.
See the enhanced versions below for practical regression detection.

USAGE:
1. Ensure Query Store is enabled on the database
2. Choose specific analysis from enhanced queries below
3. Modify time ranges and thresholds as needed
4. Use results to identify performance issues

IMPORTANT CONSIDERATIONS:
- Requires Query Store to be enabled and collecting data
- Query Store data retention affects historical analysis
- Large result sets possible - consider filtering criteria
- Query Store overhead is minimal but measurable

QUERY STORE SETUP:
-- Enable Query Store if not already enabled
ALTER DATABASE [YourDatabase] SET QUERY_STORE = ON;
ALTER DATABASE [YourDatabase] SET QUERY_STORE (OPERATION_MODE = READ_WRITE);

USE CASES:
- Performance regression analysis
- Query plan change detection
- Historical performance trending
- Query optimization validation
- Performance baseline establishment

REQUIREMENTS:
- SQL Server 2016 or later
- Query Store enabled on database
- db_datareader permission minimum
- Historical query execution data in Query Store

AUTHOR: Query Performance Analysis
CREATED: Various
LAST MODIFIED: 2025-06-04
================================================================================
*/

-- filepath: c:\Users\ThomasWimprine\OneDrive - In-Telecom Consulting\Repositories\UsefulSQL\SQL\PerfAndRegressions.SQL
-- Basic Query Store query joining fundamental tables
-- This is a foundation that should be extended for specific analysis
SELECT *
FROM sys.query_store_query_text qt
    JOIN sys.query_store_query q ON qt.query_text_id = q.query_text_id
    JOIN sys.query_store_plan p ON q.query_id = p.query_id;

/*
ENHANCED QUERIES FOR SPECIFIC ANALYSIS:

1. PERFORMANCE REGRESSIONS - Queries with increased duration:
SELECT 
    qt.query_sql_text,
    q.query_id,
    rs_recent.avg_duration / 1000.0 AS recent_avg_duration_ms,
    rs_baseline.avg_duration / 1000.0 AS baseline_avg_duration_ms,
    (rs_recent.avg_duration - rs_baseline.avg_duration) / 1000.0 AS duration_increase_ms,
    rs_recent.count_executions AS recent_executions,
    rs_baseline.count_executions AS baseline_executions
FROM sys.query_store_query_text qt
    JOIN sys.query_store_query q ON qt.query_text_id = q.query_text_id
    JOIN sys.query_store_plan p ON q.query_id = p.query_id
    JOIN sys.query_store_runtime_stats rs_recent ON p.plan_id = rs_recent.plan_id
    JOIN sys.query_store_runtime_stats rs_baseline ON p.plan_id = rs_baseline.plan_id
WHERE rs_recent.last_execution_time >= DATEADD(day, -1, GETDATE())  -- Recent: last day
    AND rs_baseline.last_execution_time < DATEADD(day, -7, GETDATE())  -- Baseline: week ago
    AND rs_recent.avg_duration > rs_baseline.avg_duration * 1.5  -- 50% slower
ORDER BY duration_increase_ms DESC;

2. PLAN CHANGES - Queries with multiple execution plans:
SELECT 
    qt.query_sql_text,
    q.query_id,
    COUNT(DISTINCT p.plan_id) AS plan_count,
    MIN(p.first_execution_time) AS first_plan_time,
    MAX(p.last_execution_time) AS last_plan_time
FROM sys.query_store_query_text qt
    JOIN sys.query_store_query q ON qt.query_text_id = q.query_text_id
    JOIN sys.query_store_plan p ON q.query_id = p.query_id
GROUP BY qt.query_sql_text, q.query_id
HAVING COUNT(DISTINCT p.plan_id) > 1
ORDER BY plan_count DESC;

3. TOP RESOURCE CONSUMERS - Most expensive queries by CPU:
SELECT TOP 20
    qt.query_sql_text,
    q.query_id,
    SUM(rs.count_executions) AS total_executions,
    SUM(rs.avg_cpu_time * rs.count_executions) / 1000.0 AS total_cpu_time_ms,
    AVG(rs.avg_cpu_time) / 1000.0 AS avg_cpu_time_ms,
    SUM(rs.avg_logical_io_reads * rs.count_executions) AS total_logical_reads
FROM sys.query_store_query_text qt
    JOIN sys.query_store_query q ON qt.query_text_id = q.query_text_id
    JOIN sys.query_store_plan p ON q.query_id = p.query_id
    JOIN sys.query_store_runtime_stats rs ON p.plan_id = rs.plan_id
WHERE rs.last_execution_time >= DATEADD(day, -7, GETDATE())
GROUP BY qt.query_sql_text, q.query_id
ORDER BY total_cpu_time_ms DESC;

4. QUERY STORE STATUS CHECK:
SELECT 
    desired_state_desc,
    actual_state_desc,
    readonly_reason,
    current_storage_size_mb,
    max_storage_size_mb
FROM sys.database_query_store_options;
*/
