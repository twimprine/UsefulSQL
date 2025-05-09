-- Ensure optomizer has the latest statistics
-- and rebuild or reorganize indexes based on fragmentation levels
EXEC sp_updatestats;
GO
-- If fragmentation is below 30% and above 10%, use REORGANIZE
ALTER INDEX [IndexName] ON [TableName] REORGANIZE;

-- If fragmentation is above 30%, use REBUILD
ALTER INDEX [IndexName] ON [TableName] REBUILD WITH (ONLINE = ON);
