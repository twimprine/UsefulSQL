/*
================================================================================
RANDOM TEST DATA GENERATION SCRIPT
================================================================================

PURPOSE:
This script creates a test table and populates it with random data for testing,
development, and performance analysis purposes. It generates diverse data types
with random values to simulate real-world data patterns.

DESCRIPTION:
The script creates a simple test table with various data types and fills it
with 10,000 rows of randomly generated data. The data includes GUIDs, integers,
strings, and dates to provide a comprehensive test dataset.

TABLE STRUCTURE:
- id: Identity column (primary key)
- random_guid: Unique identifier for testing UUID scenarios
- random_int: Random integers between 0-9999
- random_string: Random 3-character uppercase strings
- random_date: Random dates from the past 1000 days

DATA GENERATION TECHNIQUES:
- NEWID(): Generates unique GUIDs
- CHECKSUM(NEWID()): Creates pseudo-random numbers
- CHAR() + ASCII math: Generates random letters A-Z
- DATEADD() with random offsets: Creates random historical dates

USAGE:
1. Execute script to create table and populate with test data
2. Modify loop counter (@i < 10000) to change row count
3. Adjust random value ranges as needed for specific tests
4. Use resulting data for query testing and performance analysis

CUSTOMIZATION OPTIONS:
- Change row count by modifying the WHILE loop condition
- Adjust random_int range by changing the modulo value (% 10000)
- Modify string length by adding more CHAR() expressions
- Change date range by adjusting DATEADD day offset (% 1000)

IMPORTANT CONSIDERATIONS:
- Table will be created in current database
- 10,000 rows may take a few seconds to insert
- Uses CHECKSUM(NEWID()) for repeatability within session
- Random data may not represent real-world data distributions

USE CASES:
- Performance testing with substantial data volumes
- Query development and testing
- Index behavior analysis
- Database load testing
- Development environment data provisioning

CLEANUP:
-- DROP TABLE test_data; -- Uncomment to remove test table

REQUIREMENTS:
- SQL Server 2005 or later
- CREATE TABLE permissions
- Sufficient database space for test data

AUTHOR: Test Data Generation
CREATED: Various
LAST MODIFIED: 2025-06-04
================================================================================
*/

-- filepath: c:\Users\ThomasWimprine\OneDrive - In-Telecom Consulting\Repositories\UsefulSQL\SQL\RandomTestData.sql
-- Create a test table with various data types for comprehensive testing
CREATE TABLE test_data (
    id INT IDENTITY(1,1) PRIMARY KEY,
    random_guid UNIQUEIDENTIFIER,
    random_int INT,
    random_string NVARCHAR(100),
    random_date DATETIME
);

-- Insert 10,000 rows of random data (adjust loop counter to change row count)
DECLARE @i INT = 0;
WHILE @i < 10000
BEGIN
    INSERT INTO test_data (random_guid, random_int, random_string, random_date)
    VALUES (
        NEWID(),                                                    -- Random GUID
        ABS(CHECKSUM(NEWID())) % 10000,                            -- Random int between 0-9999
        CHAR(65 + (ABS(CHECKSUM(NEWID())) % 26)) +                 -- Random 3-char string (A-Z)
        CHAR(65 + (ABS(CHECKSUM(NEWID())) % 26)) + 
        CHAR(65 + (ABS(CHECKSUM(NEWID())) % 26)),
        DATEADD(DAY, -1 * (ABS(CHECKSUM(NEWID())) % 1000), GETDATE()) -- Random past date (up to 1000 days ago)
    );

    SET @i += 1;
END

-- Verify the data was inserted successfully
SELECT COUNT(*) AS row_count FROM test_data;

/*
SAMPLE QUERIES FOR TESTING:
-- Test range queries
SELECT * FROM test_data WHERE random_int BETWEEN 1000 AND 2000;

-- Test date range queries  
SELECT * FROM test_data WHERE random_date >= DATEADD(month, -6, GETDATE());

-- Test string pattern matching
SELECT * FROM test_data WHERE random_string LIKE 'A%';

-- Test aggregations
SELECT 
    AVG(random_int) as avg_int,
    MIN(random_date) as earliest_date,
    MAX(random_date) as latest_date,
    COUNT(DISTINCT random_string) as unique_strings
FROM test_data;

PERFORMANCE TESTING:
-- Add indexes for performance testing
CREATE INDEX IX_test_data_random_int ON test_data(random_int);
CREATE INDEX IX_test_data_random_date ON test_data(random_date);
CREATE INDEX IX_test_data_random_string ON test_data(random_string);

-- Test index usage
SELECT * FROM test_data WHERE random_int = 5000;
SELECT * FROM test_data WHERE random_date = '2023-01-01';

CLEANUP:
-- Uncomment to remove test table when finished
-- DROP TABLE test_data;
*/
