/*
================================================================================
CREATE RANDOM TEST DATABASES SCRIPT
================================================================================

PURPOSE:
This script creates multiple test databases with randomly selected names from
a predefined word list. It's useful for creating multiple test environments,
development databases, or demonstration databases quickly.

DESCRIPTION:
The script uses a table variable containing NATO phonetic alphabet words to
randomly generate database names. It creates up to 10 databases (configurable)
with unique names, skipping any that already exist to prevent conflicts.

FEATURES:
- Uses NATO phonetic alphabet for professional, memorable names
- Prevents duplicate database creation
- Configurable number of databases to create
- Provides clear feedback on creation status
- Safe to run multiple times

USAGE:
1. Review the word list and modify if desired
2. Adjust the loop counter (@i <= 10) to create more/fewer databases
3. Execute the script
4. Monitor output for creation status

CUSTOMIZATION OPTIONS:
- Change @word prefix/suffix by modifying SET @dbName = @word
- Add more words to the @words table for variety
- Modify loop count for different numbers of databases
- Add database-specific settings (collation, file paths, etc.)

IMPORTANT CONSIDERATIONS:
- Creates databases with default settings
- Uses default file locations (consider disk space)
- No specific security or configuration settings applied
- Databases will be empty (no schema or data)

USE CASES:
- Development environment setup
- Testing scenarios requiring multiple databases
- Training/demonstration environments
- Quick database provisioning for prototyping

REQUIREMENTS:
- SQL Server 2005 or later
- sysadmin or dbcreator permissions
- Sufficient disk space for multiple databases

AUTHOR: Thomas Wimprine
CREATED: Various
LAST MODIFIED: 2025-06-04
================================================================================
*/


-- Create a temp table with NATO phonetic alphabet words for database names
DECLARE @words TABLE (word NVARCHAR(50));
INSERT INTO @words (word)
VALUES ('alpha'), ('bravo'), ('charlie'), ('delta'), ('echo'),
       ('foxtrot'), ('golf'), ('hotel'), ('india'), ('juliet'),
       ('kilo'), ('lima'), ('mike'), ('november'), ('oscar'),
       ('papa'), ('quebec'), ('romeo'), ('sierra'), ('tango'),
       ('uniform'), ('victor'), ('whiskey'), ('xray'), ('yankee'), ('zulu');

-- Variables for database creation loop
DECLARE @i INT = 1;
DECLARE @word NVARCHAR(50);
DECLARE @dbName NVARCHAR(128);

-- Loop to create databases (adjust @i <= 10 to change number of databases)
WHILE @i <= 10
BEGIN
    -- Get a random word from the NATO phonetic alphabet list
    SELECT TOP 1 @word = word FROM @words ORDER BY NEWID();

    -- Set database name (customize prefix/suffix here if desired)
    SET @dbName = @word;

    -- Check if database already exists to avoid duplicates
    IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = @dbName)
    BEGIN
        -- Create the database with default settings
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

/*
POST-EXECUTION VERIFICATION:
-- List all newly created databases
SELECT name, create_date, collation_name
FROM sys.databases 
WHERE create_date >= DATEADD(MINUTE, -5, GETDATE())
ORDER BY create_date DESC;

CLEANUP SCRIPT (if needed):
-- Uncomment and modify to drop test databases
-- DROP DATABASE IF EXISTS [alpha];
-- DROP DATABASE IF EXISTS [bravo];
-- (continue for each database created)
*/
