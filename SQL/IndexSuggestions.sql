/*
================================================================================
INDEX SUGGESTIONS SCRIPT
================================================================================

PURPOSE:
This script identifies missing indexes in the current database that could 
significantly improve query performance. It analyzes the SQL Server Dynamic 
Management Views (DMVs) to find index recommendations based on actual query 
execution patterns.

DESCRIPTION:
The script queries the missing index DMVs to find indexes that SQL Server 
recommends creating based on queries that have been executed. It calculates 
an "improvement measure" to prioritize which indexes would provide the most 
benefit and generates the actual CREATE INDEX statements ready for execution.

USAGE:
1. Execute this script against any SQL Server database
2. Review the results ordered by improvement_measure (highest impact first)
3. Evaluate the suggested indexes before implementing them
4. Copy and execute the create_index_statement for indexes you want to create

IMPORTANT CONSIDERATIONS:
- These are suggestions based on query patterns since last server restart
- Consider index maintenance overhead vs. performance benefits
- Review for duplicate or overlapping indexes
- Test in development environment before production implementation
- Monitor index usage after creation using sys.dm_db_index_usage_stats

COLUMNS RETURNED:
- improvement_measure: Calculated benefit score (higher = more beneficial)
- create_index_statement: Ready-to-execute CREATE INDEX statement

REQUIREMENTS:
- SQL Server 2005 or later
- Appropriate permissions to query system DMVs
- Database must have query activity to generate recommendations

AUTHOR: Thomas Wimprine
CREATED: Various
LAST MODIFIED: 2025-06-04
================================================================================
*/


SELECT
    -- Calculate improvement measure: combines cost, impact, and frequency
    -- Higher values indicate greater potential performance benefit
    migs.avg_total_user_cost * migs.avg_user_impact * (migs.user_seeks + migs.user_scans) AS improvement_measure,
    
    -- Generate CREATE INDEX statement with proper naming convention
    -- Format: IX_TableName_ColumnNames (without spaces and brackets)
    'CREATE INDEX [IX_' + OBJECT_NAME(mid.object_id) + '_' + REPLACE(REPLACE(REPLACE(ISNULL(mid.equality_columns,''), ', ', '_'), '[', ''), ']', '') + ']'
    + ' ON ' + mid.statement + ' (' + ISNULL (mid.equality_columns,'')
    + CASE WHEN mid.equality_columns IS NOT NULL AND mid.inequality_columns IS NOT NULL THEN ',' ELSE '' END
    + ISNULL (mid.inequality_columns, '') + ')' + ISNULL (' INCLUDE (' + mid.included_columns + ')', '') AS create_index_statement

FROM sys.dm_db_missing_index_groups mig
    -- Join to get statistics about missing index usage
    INNER JOIN sys.dm_db_missing_index_group_stats migs ON migs.group_handle = mig.index_group_handle
    -- Join to get detailed information about the missing index
    INNER JOIN sys.dm_db_missing_index_details mid ON mig.index_handle = mid.index_handle

-- Order by improvement measure to show most beneficial indexes first
ORDER BY improvement_measure DESC;

/*
SAMPLE OUTPUT INTERPRETATION:
improvement_measure | create_index_statement
150000.5           | CREATE INDEX [IX_Orders_CustomerID] ON [dbo].[Orders] (CustomerID)
75000.2            | CREATE INDEX [IX_Products_CategoryID] ON [dbo].[Products] (CategoryID) INCLUDE (ProductName, Price)

The first index would provide approximately twice the performance benefit of the second.
*/