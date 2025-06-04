/*
================================================================================
REORGANIZE INDEXES SCRIPT
================================================================================

PURPOSE:
This script automatically identifies and maintains fragmented indexes by 
reorganizing or rebuilding them based on their fragmentation levels. It uses
a cursor-based approach to process all indexes requiring maintenance.

DESCRIPTION:
The script analyzes index fragmentation across all tables and automatically
performs maintenance operations:
- REORGANIZE for moderate fragmentation (10-30%)
- REBUILD for high fragmentation (>30%) when enabled

The cursor iterates through all indexes in the database and checks their fragmentation levels. If the
fragmentation is above 10%, it will either reorganize or rebuild the index based on the level of fragmentation.

MAINTENANCE STRATEGY:
- 10-30% fragmentation: REORGANIZE (online operation, minimal blocking)
- 30%+ fragmentation: REBUILD (more thorough, requires Enterprise for ONLINE)
- Skips disabled indexes and heaps
- Only processes CLUSTERED and NONCLUSTERED indexes

CURRENT CONFIGURATION:
- Only performs REORGANIZE operations (safe for all editions)
- REBUILD operations are commented out (uncomment for Enterprise edition)
- Prints commands before execution for transparency
- Uses 'LIMITED' scan mode for faster fragmentation analysis

USAGE:
1. Review the script configuration and thresholds
2. Uncomment REBUILD section if using Enterprise edition
3. Execute during maintenance windows for best performance
4. Monitor output for any errors or issues

ENTERPRISE EDITION FEATURES:
- REBUILD with ONLINE = ON (minimizes blocking)
- MAXDOP control for parallel processing
- Can rebuild during business hours with minimal impact

IMPORTANT CONSIDERATIONS:
- REORGANIZE is always online but may be slower for high fragmentation
- REBUILD is more thorough but can block access (unless ONLINE = ON)
- Consider maintenance windows and system load
- Monitor transaction log space during operations

USE CASES:
- Automated index maintenance
- Performance optimization
- Database health maintenance
- Scheduled maintenance tasks

REQUIREMENTS:
- SQL Server 2005 or later
- db_ddladmin permission for index operations
- Sufficient transaction log space for operations
- Enterprise edition for ONLINE rebuild operations

AUTHOR: Thomas Wimprine
CREATED: Various
LAST MODIFIED: 2025-06-04
================================================================================
*/

/*
    This script identifies potential bottlenecks in SQL Server by analyzing wait statistics.
    It filters out common wait types that are not indicative of performance issues.
    
    The cursor iterates through all indexes in the database and checks their fragmentation levels. If the
    fragmentation is above 10%, it will either reorganize or rebuild the index based on the level of fragmentation.
*/



-- Declare variables for cursor operations
DECLARE @TableName NVARCHAR(128);
DECLARE @IndexName NVARCHAR(128);
DECLARE @SchemaName NVARCHAR(128);
DECLARE @Frag FLOAT;
DECLARE @sql NVARCHAR(MAX);

-- Create cursor to iterate through all fragmented indexes
DECLARE cur CURSOR FOR
SELECT
    s.name AS SchemaName,
    t.name AS TableName,
    i.name AS IndexName,
    ips.avg_fragmentation_in_percent
FROM sys.dm_db_index_physical_stats (DB_ID(), NULL, NULL, NULL, 'LIMITED') AS ips
    JOIN sys.indexes AS i ON ips.object_id = i.object_id AND ips.index_id = i.index_id
    JOIN sys.tables AS t ON i.object_id = t.object_id
    JOIN sys.schemas AS s ON t.schema_id = s.schema_id
WHERE 
    ips.avg_fragmentation_in_percent > 10               -- Only indexes needing maintenance
    AND i.name IS NOT NULL                              -- Exclude heaps
    AND i.type_desc IN ('CLUSTERED', 'NONCLUSTERED')   -- Only standard indexes
    AND i.is_disabled = 0;                              -- Skip disabled indexes

OPEN cur;

FETCH NEXT FROM cur INTO @SchemaName, @TableName, @IndexName, @Frag;

-- Process each fragmented index
WHILE @@FETCH_STATUS = 0
BEGIN
    -- ENTERPRISE EDITION OPTIONS (uncomment for Enterprise edition with online rebuilds)
    -- IF @Frag > 30
        -- SET @sql = N'ALTER INDEX [' + @IndexName + N'] ON [' + @SchemaName + N'].[' + @TableName + N'] REBUILD WITH (MAXDOP = 4, ONLINE = ON);';
    -- ELSE
        
    -- CURRENT CONFIGURATION: REORGANIZE only (safe for all editions)
    SET @sql = N'ALTER INDEX [' + @IndexName + N'] ON [' + @SchemaName + N'].[' + @TableName + N'] REORGANIZE;';

    PRINT @sql; -- Show what command will be executed
    EXEC sp_executesql @sql; -- Execute the maintenance command

    FETCH NEXT FROM cur INTO @SchemaName, @TableName, @IndexName, @Frag;
END

CLOSE cur;
DEALLOCATE cur;

/*
ENHANCED VERSION WITH REBUILD LOGIC:
-- Uncomment and modify as needed for Enterprise edition

WHILE @@FETCH_STATUS = 0
BEGIN
    IF @Frag > 30
    BEGIN
        -- High fragmentation: REBUILD (Enterprise edition with ONLINE = ON)
        SET @sql = N'ALTER INDEX [' + @IndexName + N'] ON [' + @SchemaName + N'].[' + @TableName + N'] REBUILD WITH (MAXDOP = 4, ONLINE = ON);';
        PRINT 'REBUILDING (High fragmentation ' + CAST(@Frag AS NVARCHAR(10)) + '%): ' + @sql;
    END
    ELSE
    BEGIN
        -- Moderate fragmentation: REORGANIZE
        SET @sql = N'ALTER INDEX [' + @IndexName + N'] ON [' + @SchemaName + N'].[' + @TableName + N'] REORGANIZE;';
        PRINT 'REORGANIZING (Moderate fragmentation ' + CAST(@Frag AS NVARCHAR(10)) + '%): ' + @sql;
    END
    
    EXEC sp_executesql @sql;
    FETCH NEXT FROM cur INTO @SchemaName, @TableName, @IndexName, @Frag;
END

MONITORING QUERIES:
-- Check progress of long-running index operations
SELECT 
    session_id,
    command,
    percent_complete,
    estimated_completion_time,
    start_time
FROM sys.dm_exec_requests 
WHERE command LIKE '%INDEX%';

-- Check current fragmentation levels
SELECT TOP 10
    OBJECT_NAME(ips.object_id) AS TableName,
    i.name AS IndexName,
    ips.avg_fragmentation_in_percent
FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') ips
    JOIN sys.indexes i ON ips.object_id = i.object_id AND ips.index_id = i.index_id
WHERE ips.avg_fragmentation_in_percent > 10
ORDER BY ips.avg_fragmentation_in_percent DESC;
*/
