-- Create a temp table with some example words
DECLARE @words TABLE (word NVARCHAR(50));
INSERT INTO @words (word)
VALUES ('alpha'), ('bravo'), ('charlie'), ('delta'), ('echo'),
       ('foxtrot'), ('golf'), ('hotel'), ('india'), ('juliet'),
       ('kilo'), ('lima'), ('mike'), ('november'), ('oscar'),
       ('papa'), ('quebec'), ('romeo'), ('sierra'), ('tango'),
       ('uniform'), ('victor'), ('whiskey'), ('xray'), ('yankee'), ('zulu');

-- Variables for looping
DECLARE @i INT = 1;
DECLARE @word NVARCHAR(50);
DECLARE @dbName NVARCHAR(128);

-- Loop to create 8 databases
WHILE @i <= 10
BEGIN
    -- Get a random word from the list
    SELECT TOP 1 @word = word FROM @words ORDER BY NEWID();

    -- Prefix with something if you want
    SET @dbName = @word;

    -- Avoid duplicates if run multiple times
    IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = @dbName)
    BEGIN
        DECLARE @sql NVARCHAR(MAX) = 'CREATE DATABASE [' + @dbName + ']';
        EXEC sp_executesql @sql;
        PRINT 'Created database: ' + @dbName;
    END
    ELSE
    BEGIN
        PRINT 'Skipped duplicate: ' + @dbName;
    END

    SET @i += 1;
END
