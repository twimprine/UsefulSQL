/*
================================================================================
INDEX FRAGMENTATION ANALYSIS SCRIPT
================================================================================

PURPOSE:
This script identifies indexes with fragmentation levels above 10%, helping
prioritize index maintenance operations. Index fragmentation reduces performance
by causing additional I/O operations and inefficient page usage.

DESCRIPTION:
The script queries sys.dm_db_index_physical_stats to analyze fragmentation
across all user tables and indexes. It filters to show only indexes that
require attention (>10% fragmentation) and provides actionable information
for maintenance planning.

FRAGMENTATION IMPACT:
- 0-10%: Generally acceptable, no action needed
- 10-30%: Moderate fragmentation, consider REORGANIZE
- 30%+: High fragmentation, consider REBUILD
- Fragmentation increases I/O and reduces cache efficiency

OUTPUT COLUMNS:
- Schema: Database schema name
- Table: Table name containing the fragmented index
- Index: Name of the fragmented index
- avg_fragmentation_in_percent: Percentage of logical fragmentation

FRAGMENTATION TYPES:
- Logical: Pages not in correct order (affects scans)
- Extent: Related pages not stored together (affects I/O)
- Both types impact performance differently

USAGE:
1. Execute script to identify fragmented indexes
2. Prioritize by fragmentation percentage and table importance
3. Use results to plan index maintenance operations
4. Combine with FixIndexes.SQL for remediation

MAINTENANCE RECOMMENDATIONS:
- 10-30% fragmentation: ALTER INDEX ... REORGANIZE
- 30%+ fragmentation: ALTER INDEX ... REBUILD
- Consider maintenance windows for rebuild operations
- Monitor index usage before maintenance

IMPORTANT CONSIDERATIONS:
- Uses 'LIMITED' scan mode for faster execution
- Only shows indexes above 10% fragmentation threshold
- Small indexes (<1000 pages) may show high fragmentation but have minimal impact
- Fragmentation analysis can be resource-intensive on large databases

USE CASES:
- Regular index maintenance planning
- Performance troubleshooting
- Database health assessments
- Maintenance window planning
- Storage optimization

REQUIREMENTS:
- SQL Server 2005 or later
- VIEW DATABASE STATE permission
- Access to sys.dm_db_index_physical_stats

AUTHOR: Index Maintenance
CREATED: Various
LAST MODIFIED: 2025-06-04
================================================================================
*/

-- filepath: c:\Users\ThomasWimprine\OneDrive - In-Telecom Consulting\Repositories\UsefulSQL\SQL\IndexFragmentation.sql
SELECT 
  dbschemas.[name] AS 'Schema',
  dbtables.[name] AS 'Table',
  dbindexes.[name] AS 'Index',
  indexstats.avg_fragmentation_in_percent
FROM sys.dm_db_index_physical_stats (DB_ID(), NULL, NULL, NULL, 'LIMITED') indexstats
  INNER JOIN sys.tables dbtables ON dbtables.[object_id] = indexstats.[object_id]
  INNER JOIN sys.schemas dbschemas ON dbtables.[schema_id] = dbschemas.[schema_id]
  INNER JOIN sys.indexes dbindexes ON dbindexes.[object_id] = indexstats.[object_id]
    AND indexstats.index_id = dbindexes.index_id
WHERE indexstats.avg_fragmentation_in_percent > 10  -- Only show indexes needing attention
ORDER BY indexstats.avg_fragmentation_in_percent DESC;

/*
ENHANCED FRAGMENTATION ANALYSIS:
-- More detailed version with additional metrics and recommendations

SELECT 
    dbschemas.[name] AS 'Schema',
    dbtables.[name] AS 'Table',
    dbindexes.[name] AS 'Index',
    indexstats.avg_fragmentation_in_percent,
    indexstats.page_count,
    indexstats.avg_page_space_used_in_percent,
    indexstats.record_count,
    indexstats.fragment_count,
    CASE 
        WHEN indexstats.avg_fragmentation_in_percent < 10 THEN 'No Action'
        WHEN indexstats.avg_fragmentation_in_percent < 30 THEN 'REORGANIZE'
        ELSE 'REBUILD'
    END AS recommended_action,
    'ALTER INDEX [' + dbindexes.[name] + '] ON [' + dbschemas.[name] + '].[' + dbtables.[name] + '] ' +
    CASE 
        WHEN indexstats.avg_fragmentation_in_percent < 30 THEN 'REORGANIZE;'
        ELSE 'REBUILD;'
    END AS maintenance_command
FROM sys.dm_db_index_physical_stats (DB_ID(), NULL, NULL, NULL, 'LIMITED') indexstats
    INNER JOIN sys.tables dbtables ON dbtables.[object_id] = indexstats.[object_id]
    INNER JOIN sys.schemas dbschemas ON dbtables.[schema_id] = dbschemas.[schema_id]
    INNER JOIN sys.indexes dbindexes ON dbindexes.[object_id] = indexstats.[object_id]
        AND indexstats.index_id = dbindexes.index_id
WHERE indexstats.avg_fragmentation_in_percent > 10
    AND indexstats.page_count > 100  -- Exclude very small indexes
ORDER BY indexstats.avg_fragmentation_in_percent DESC;

DETAILED SCAN (slower but more accurate):
-- Change 'LIMITED' to 'DETAILED' for more accurate but slower analysis
-- FROM sys.dm_db_index_physical_stats (DB_ID(), NULL, NULL, NULL, 'DETAILED')
*/
