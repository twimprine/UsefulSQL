/*
Metric                | Meaning
---------------------|--------------------------------------------------------------
num_of_reads/writes  | Total read/write ops since SQL Server started
io_stall_read/write  | Total time (ms) SQL spent waiting for reads/writes to complete
AvgReadLatencyMs     | Time per read = stall time / ops (high = slow storage)
AvgWriteLatencyMs    | Time per write = same idea
physical_name        | Path to file – helps identify which disk or mount is slow
*/


SELECT
    DB_NAME(vfs.database_id) AS [Database],
    vfs.file_id,
    vfs.num_of_reads,
    vfs.num_of_writes,
    vfs.io_stall_read_ms,
    vfs.io_stall_write_ms,
    vfs.io_stall_read_ms / NULLIF(vfs.num_of_reads, 0) AS [AvgReadLatencyMs],
    vfs.io_stall_write_ms / NULLIF(vfs.num_of_writes, 0) AS [AvgWriteLatencyMs],
    mf.physical_name
FROM sys.dm_io_virtual_file_stats(NULL, NULL) AS vfs
    JOIN sys.master_files AS mf
    ON vfs.database_id = mf.database_id
        AND vfs.file_id = mf.file_id
ORDER BY [AvgWriteLatencyMs] DESC;
