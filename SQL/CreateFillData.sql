
-- Drop old schema and objects if re-running
IF EXISTS (SELECT *
FROM sys.schemas
WHERE name = 'test')
    EXEC('DROP SCHEMA test');
GO
CREATE SCHEMA test;
GO

-- Create parent table
CREATE TABLE test.Customers
(
    CustomerID INT IDENTITY PRIMARY KEY,
    FirstName NVARCHAR(50),
    LastName NVARCHAR(50),
    CreatedAt DATETIME DEFAULT GETDATE()
);
GO

-- Create child table
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

-- Create useful indexes
CREATE NONCLUSTERED INDEX IX_Orders_CustomerID ON test.Orders(CustomerID);
CREATE NONCLUSTERED INDEX IX_Orders_Amount ON test.Orders(Amount);
GO

-- Insert 50,000 customers
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

-- Insert 250,000 orders (5 per customer)
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

-- Cause fragmentation: update/delete/insert randomly
-- This modifies row size, page distribution, and fill factor
DECLARE @row INT = 0;
WHILE @row < 10000
BEGIN
    UPDATE TOP (1000) test.Orders
    SET Amount = Amount + 1.23
    WHERE OrderID % 3 = 0;

    DELETE TOP (500) FROM test.Orders WHERE OrderID % 17 = 0;

    INSERT INTO test.Orders
        (CustomerID, OrderDate, Amount, Status)
    SELECT TOP 1000
        CustomerID, DATEADD(DAY, -RAND()*365, GETDATE()), RAND()*300, 'A'
    FROM test.Orders
    ORDER BY NEWID();

    SET @row += 1000;
END
GO
