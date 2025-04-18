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
WHERE indexstats.avg_fragmentation_in_percent > 10;
