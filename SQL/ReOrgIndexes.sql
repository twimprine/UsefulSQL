/*
    This script identifies potential bottlenecks in SQL Server by analyzing wait statistics.
    It filters out common wait types that are not indicative of performance issues.
    
    The cursor iterates through all indexes in the database and checks their fragmentation levels. If the
    fragmentation is above 10%, it will either reorganize or rebuild the index based on the level of fragmentation.
*/



DECLARE @TableName NVARCHAR(128);
DECLARE @IndexName NVARCHAR(128);
DECLARE @SchemaName NVARCHAR(128);
DECLARE @Frag FLOAT;
DECLARE @sql NVARCHAR(MAX);

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
    ips.avg_fragmentation_in_percent > 10
    AND i.name IS NOT NULL
    AND i.type_desc IN ('CLUSTERED', 'NONCLUSTERED')
    AND i.is_disabled = 0;

OPEN cur;

FETCH NEXT FROM cur INTO @SchemaName, @TableName, @IndexName, @Frag;

WHILE @@FETCH_STATUS = 0
BEGIN
    -- If using Enterprise Edition, you can use REBUILD with MAXDOP and ONLINE options 
    -- uncomment the following lines to use them

    -- IF @Frag > 30
        -- SET @sql = N'ALTER INDEX [' + @IndexName + N'] ON [' + @SchemaName + N'].[' + @TableName + N'] REBUILD WITH (MAXDOP = 4, ONLINE = ON);';
    -- ELSE
        SET @sql = N'ALTER INDEX [' + @IndexName + N'] ON [' + @SchemaName + N'].[' + @TableName + N'] REORGANIZE;';

    PRINT @sql;
    -- Optional: see what it’s doing
    EXEC sp_executesql @sql;

    FETCH NEXT FROM cur INTO @SchemaName, @TableName, @IndexName, @Frag;
END

CLOSE cur;
DEALLOCATE cur;
