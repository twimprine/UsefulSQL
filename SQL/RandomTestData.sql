-- Create a dummy table
CREATE TABLE test_data (
    id INT IDENTITY(1,1) PRIMARY KEY,
    random_guid UNIQUEIDENTIFIER,
    random_int INT,
    random_string NVARCHAR(100),
    random_date DATETIME
);

-- Insert 1000 rows of random data
DECLARE @i INT = 0;
WHILE @i < 10000
BEGIN
    INSERT INTO test_data (random_guid, random_int, random_string, random_date)
    VALUES (
        NEWID(),
        ABS(CHECKSUM(NEWID())) % 10000,  -- random int between 0-9999
        CHAR(65 + (ABS(CHECKSUM(NEWID())) % 26)) + CHAR(65 + (ABS(CHECKSUM(NEWID())) % 26)) + CHAR(65 + (ABS(CHECKSUM(NEWID())) % 26)),
        DATEADD(DAY, -1 * (ABS(CHECKSUM(NEWID())) % 1000), GETDATE())  -- random past date
    );

    SET @i += 1;
END

-- Optional: verify row count
SELECT COUNT(*) AS row_count FROM test_data;
