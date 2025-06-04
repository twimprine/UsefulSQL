/*
================================================================================
GET TABLE INDEXES SCRIPT
================================================================================

PURPOSE:
This script retrieves comprehensive information about all indexes on a specific
table, including index structure, column composition, and properties. It's 
essential for understanding table indexing strategy and identifying optimization
opportunities.

DESCRIPTION:
The script queries system catalog views to show detailed index information:
- Index names and types (clustered, nonclustered, etc.)
- Key columns and their ordinal positions
- Included columns for covering indexes
- Index properties (primary key, unique constraints)

OUTPUT COLUMNS:
- IndexName: Name of the index
- IndexType: Type (CLUSTERED, NONCLUSTERED, etc.)
- is_primary_key: Whether this is the primary key
- is_unique: Whether index enforces uniqueness
- ColumnName: Column included in the index
- key_ordinal: Position in key (0 for included columns)
- is_included_column: Whether column is included vs key column

USAGE:
1. Replace 'TABLE_NAME' with the actual table name
2. Use schema-qualified name if not in default schema: 'schema.table'
3. Execute to see complete index structure
4. Use results to identify missing or redundant indexes

IMPORTANT CONSIDERATIONS:
- Replace TABLE_NAME placeholder before execution
- Results show both key columns and included columns
- key_ordinal 0 indicates included columns
- Use for index analysis and optimization planning

USE CASES:
- Index analysis and optimization
- Understanding existing index strategy
- Identifying redundant or missing indexes
- Documentation of table structure
- Performance troubleshooting

REQUIREMENTS:
- SQL Server 2005 or later
- SELECT permission on target table
- Access to system catalog views

AUTHOR: Thomas Wimprine
CREATED: Various
LAST MODIFIED: 2025-06-04
================================================================================
*/


SELECT
    i.name AS IndexName,
    i.type_desc AS IndexType,
    i.is_primary_key,
    i.is_unique,
    c.name AS ColumnName,
    ic.key_ordinal,
    ic.is_included_column
FROM sys.indexes AS i
    JOIN sys.index_columns AS ic
    ON i.object_id = ic.object_id AND i.index_id = ic.index_id
    JOIN sys.columns AS c
    ON ic.object_id = c.object_id AND ic.column_id = c.column_id
WHERE i.object_id = OBJECT_ID('TABLE_NAME') -- Replace TABLE_NAME with actual table name
ORDER BY i.name, ic.key_ordinal;

/*
EXAMPLE USAGE:
-- For a specific table (replace with your table name)
WHERE i.object_id = OBJECT_ID('dbo.Orders')

-- For schema-qualified table name
WHERE i.object_id = OBJECT_ID('sales.Orders')

ENHANCED VERSION WITH MORE DETAILS:
SELECT
    OBJECT_NAME(i.object_id) AS TableName,
    i.name AS IndexName,
    i.type_desc AS IndexType,
    i.is_primary_key,
    i.is_unique,
    i.is_disabled,
    i.fill_factor,
    c.name AS ColumnName,
    ic.key_ordinal,
    ic.is_included_column,
    ic.is_descending_key
FROM sys.indexes AS i
    JOIN sys.index_columns AS ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id
    JOIN sys.columns AS c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
WHERE i.object_id = OBJECT_ID('TABLE_NAME')
    AND i.type > 0  -- Exclude heap (type 0)
ORDER BY i.name, ic.key_ordinal;

INDEX USAGE STATISTICS:
-- Combine with usage stats to see which indexes are actually used
SELECT
    i.name AS IndexName,
    i.type_desc AS IndexType,
    ius.user_seeks,
    ius.user_scans,
    ius.user_lookups,
    ius.user_updates,
    ius.last_user_seek,
    ius.last_user_scan,
    ius.last_user_lookup
FROM sys.indexes i
LEFT JOIN sys.dm_db_index_usage_stats ius 
    ON i.object_id = ius.object_id AND i.index_id = ius.index_id
WHERE i.object_id = OBJECT_ID('TABLE_NAME')
ORDER BY ius.user_seeks + ius.user_scans + ius.user_lookups DESC;
*/
