/*
================================================================================
FIX INDEXES SCRIPT - INDEX MAINTENANCE TEMPLATE
================================================================================

PURPOSE:
This script provides a template and guidelines for index maintenance operations
including updating statistics and rebuilding/reorganizing indexes based on
fragmentation levels. It serves as a reference for proper index maintenance.

DESCRIPTION:
The script demonstrates the recommended approach for index maintenance:
1. Update statistics to ensure the query optimizer has current information
2. Use REORGANIZE for moderate fragmentation (10-30%)
3. Use REBUILD for high fragmentation (>30%)

FRAGMENTATION THRESHOLDS:
- 0-10%: No action needed, index is healthy
- 10-30%: REORGANIZE (online operation, minimal impact)
- 30%+: REBUILD (more thorough, can be done online in Enterprise edition)

TEMPLATE USAGE:
1. Replace [IndexName] with actual index name
2. Replace [TableName] with actual table name  
3. Consider ONLINE = ON option based on SQL Server edition and availability requirements
4. Test in development before applying to production

IMPORTANT CONSIDERATIONS:
- REORGANIZE is always online and can run during business hours
- REBUILD can be offline unless ONLINE = ON is specified (Enterprise feature)
- sp_updatestats updates statistics for all tables in the database
- Consider maintenance windows for REBUILD operations
- Monitor for blocking during maintenance operations

AUTOMATION RECOMMENDATIONS:
- Use this as a template for maintenance plan scripts
- Consider Ola Hallengren's maintenance solution for production environments
- Implement fragmentation checking before deciding on REORGANIZE vs REBUILD
- Schedule during low-activity periods

REQUIREMENTS:
- SQL Server 2005 or later
- db_ddladmin permission minimum for index operations
- Enterprise edition for ONLINE = ON rebuild operations

AUTHOR: Thomas Wimprine
CREATED: Various
LAST MODIFIED: 2025-06-04
================================================================================
*/

-- Step 1: Ensure optimizer has the latest statistics for all tables in database
-- This helps the query optimizer make better execution plan decisions
EXEC sp_updatestats;
GO

-- Step 2a: If fragmentation is between 10-30%, use REORGANIZE (online operation)
-- REORGANIZE defragments the leaf level of clustered and nonclustered indexes
-- Replace [IndexName] and [TableName] with actual values
ALTER INDEX [IndexName] ON [TableName] REORGANIZE;

-- Step 2b: If fragmentation is above 30%, use REBUILD (more comprehensive)
-- REBUILD drops and recreates the index, removing all fragmentation
-- ONLINE = ON keeps the index available during rebuild (Enterprise edition only)
ALTER INDEX [IndexName] ON [TableName] REBUILD WITH (ONLINE = ON);

/*
FRAGMENTATION CHECKING QUERY:
Use this query to determine fragmentation levels before choosing REORGANIZE vs REBUILD:

SELECT 
    OBJECT_NAME(ips.object_id) AS TableName,
    si.name AS IndexName,
    ips.avg_fragmentation_in_percent,
    CASE 
        WHEN ips.avg_fragmentation_in_percent < 10 THEN 'No Action Needed'
        WHEN ips.avg_fragmentation_in_percent < 30 THEN 'REORGANIZE'
        ELSE 'REBUILD'
    END AS RecommendedAction
FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') ips
INNER JOIN sys.indexes si ON ips.object_id = si.object_id AND ips.index_id = si.index_id
WHERE ips.avg_fragmentation_in_percent > 10
ORDER BY ips.avg_fragmentation_in_percent DESC;

MAINTENANCE SCRIPT EXAMPLE:
-- Dynamic script that checks fragmentation and performs appropriate action
DECLARE @sql NVARCHAR(MAX) = '';
SELECT @sql = @sql + 
    CASE 
        WHEN avg_fragmentation_in_percent < 30 
        THEN 'ALTER INDEX [' + si.name + '] ON [' + OBJECT_NAME(ips.object_id) + '] REORGANIZE;' + CHAR(13)
        ELSE 'ALTER INDEX [' + si.name + '] ON [' + OBJECT_NAME(ips.object_id) + '] REBUILD;' + CHAR(13)
    END
FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') ips
INNER JOIN sys.indexes si ON ips.object_id = si.object_id AND ips.index_id = si.index_id
WHERE ips.avg_fragmentation_in_percent > 10;

EXEC sp_executesql @sql;
*/
