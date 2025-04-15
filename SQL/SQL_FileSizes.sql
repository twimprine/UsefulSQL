SELECT 
    db.name AS database_name,
    mf.name AS logical_name,
    mf.physical_name,
    mf.type_desc,
	CONVERT(DECIMAL(10,2), mf.size * 8.0 / 1024) AS size_mb,
    CONVERT(DECIMAL(10,2), mf.size * 8.0 / 1024 / 1024) AS size_gb
FROM 
    sys.master_files mf
JOIN 
    sys.databases db ON db.database_id = mf.database_id
ORDER BY 
    db.name, mf.type_desc;
