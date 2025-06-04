/*
================================================================================
CREATE AND FILL TEST DATA SCRIPT
================================================================================

PURPOSE:
This script creates a complete test database schema with sample data for 
performance testing, index analysis, and query optimization demonstrations. 
It generates realistic data volumes and intentionally creates fragmentation 
for testing purposes.

DESCRIPTION:
The script performs the following operations:
1. Creates a test schema with Customers and Orders tables
2. Adds appropriate indexes for performance testing
3. Populates tables with substantial data (50,000 customers, 250,000+ orders)
4. Intentionally fragments the data through random updates/deletes/inserts
5. Provides a realistic test environment for performance analysis

DATA GENERATED:
- 50,000 customers with simple naming pattern
- ~250,000+ orders (5 per customer initially)
- Additional random orders through fragmentation process
- Mix of active ('A') and cancelled ('X') order statuses
- Random amounts between $1-$500 per order

USAGE:
1. Execute against any test/development database
2. Monitor execution time (may take several minutes for large datasets)
3. Use resulting data for index testing, query tuning, and performance analysis
4. Clean up using: DROP SCHEMA test CASCADE (or manual cleanup)

IMPORTANT CONSIDERATIONS:
- This will create substantial data - ensure adequate disk space
- Execution time can be significant for large datasets
- Intentionally creates fragmentation - not for production patterns
- Uses RAND() which may affect reproducibility
- Consider transaction log space requirements

USE CASES:
- Index fragmentation analysis
- Query performance testing
- Index suggestion testing
- Database tuning demonstrations
- Performance baseline establishment

REQUIREMENTS:
- SQL Server 2005 or later
- Database with sufficient space (several GB recommended)
- db_ddladmin and db_datawriter permissions minimum

AUTHOR: Thomas Wimprine
CREATED: Various
LAST MODIFIED: 2025-06-04
================================================================================
*/


-- Drop old schema and objects if re-running to ensure clean state
IF EXISTS (SELECT *
FROM sys.schemas
WHERE name = 'test')
    EXEC('DROP SCHEMA test');
GO
CREATE SCHEMA test;
GO

-- Create parent table for customer data
CREATE TABLE test.Customers
(
    CustomerID INT IDENTITY PRIMARY KEY,
    FirstName NVARCHAR(50),
    LastName NVARCHAR(50),
    CreatedAt DATETIME DEFAULT GETDATE()
);
GO

-- Create child table for order data with foreign key relationship
CREATE TABLE test.Orders
(
    OrderID INT IDENTITY PRIMARY KEY,
    CustomerID INT FOREIGN KEY REFERENCES test.Customers(CustomerID),
    OrderDate DATETIME DEFAULT GETDATE(),
    Amount DECIMAL(10,2),
    Status CHAR(1)
    -- A=Active, X=Cancelled
);
GO

-- Create useful indexes for performance testing
CREATE NONCLUSTERED INDEX IX_Orders_CustomerID ON test.Orders(CustomerID);
CREATE NONCLUSTERED INDEX IX_Orders_Amount ON test.Orders(Amount);
GO

-- Insert 50,000 customers with simple naming pattern
SET NOCOUNT ON;
DECLARE @i INT = 0;
WHILE @i < 50000
BEGIN
    INSERT INTO test.Customers
        (FirstName, LastName)
    VALUES
        (
            CONCAT('First', @i),
            CONCAT('Last', @i)
    );
    SET @i += 1;
END
GO

-- Insert 250,000 orders (5 per customer) with random amounts and statuses
SET NOCOUNT ON;
DECLARE @cid INT = 1;
WHILE @cid <= 50000
BEGIN
    INSERT INTO test.Orders
        (CustomerID, OrderDate, Amount, Status)
    VALUES
        (@cid, GETDATE(), RAND() * 500 + 1, 'A'),
        (@cid, GETDATE(), RAND() * 500 + 1, 'A'),
        (@cid, GETDATE(), RAND() * 500 + 1, 'X'),
        (@cid, GETDATE(), RAND() * 500 + 1, 'A'),
        (@cid, GETDATE(), RAND() * 500 + 1, 'A');
    SET @cid += 1;
END
GO

-- Cause intentional fragmentation: update/delete/insert randomly
-- This modifies row size, page distribution, and fill factor to simulate
-- real-world fragmentation patterns for testing purposes
DECLARE @row INT = 0;
WHILE @row < 10000
BEGIN
    -- Update existing records to change row sizes
    UPDATE TOP (1000) test.Orders
    SET Amount = Amount + 1.23
    WHERE OrderID % 3 = 0;

    -- Delete some records to create gaps in pages
    DELETE TOP (500) FROM test.Orders WHERE OrderID % 17 = 0;

    -- Insert new records to fill gaps and create mixed page usage
    INSERT INTO test.Orders
        (CustomerID, OrderDate, Amount, Status)
    SELECT TOP 1000
        CustomerID, DATEADD(DAY, -RAND()*365, GETDATE()), RAND()*300, 'A'
    FROM test.Orders
    ORDER BY NEWID();

    SET @row += 1000;
END
GO

/*
POST-EXECUTION VERIFICATION QUERIES:
-- Check record counts
SELECT 'Customers' as TableName, COUNT(*) as RecordCount FROM test.Customers
UNION ALL
SELECT 'Orders', COUNT(*) FROM test.Orders;

-- Check fragmentation levels
SELECT 
    OBJECT_NAME(ips.object_id) AS TableName,
    si.name AS IndexName,
    ips.avg_fragmentation_in_percent,
    ips.page_count
FROM sys.dm_db_index_physical_stats(DB_ID(), OBJECT_ID('test.Orders'), NULL, NULL, 'LIMITED') ips
INNER JOIN sys.indexes si ON ips.object_id = si.object_id AND ips.index_id = si.index_id
WHERE ips.avg_fragmentation_in_percent > 0;
*/
