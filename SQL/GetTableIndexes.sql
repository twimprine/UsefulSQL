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
WHERE i.object_id = OBJECT_ID('TABLE_NAME')
ORDER BY i.name, ic.key_ordinal;
