SELECT *
FROM sys.query_store_query_text qt
    JOIN sys.query_store_query q ON qt.query_text_id = q.query_text_id
    JOIN sys.query_store_plan p ON q.query_id = p.query_id
