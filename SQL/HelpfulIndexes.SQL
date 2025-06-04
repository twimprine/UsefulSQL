/*
================================================================================
HELPFUL INDEXES ANALYSIS SCRIPT
================================================================================

PURPOSE:
This script identifies missing indexes that could provide significant performance
improvements by analyzing SQL Server's missing index recommendations. It focuses
on the most beneficial indexes based on calculated improvement measures.

DESCRIPTION:
The script queries the missing index Dynamic Management Views (DMVs) to find
index recommendations based on actual query execution patterns. It calculates
an improvement measure and shows the specific columns that should be included
in each recommended index.

OUTPUT COLUMNS:
- improvement_measure: Calculated benefit score (cost × impact × frequency)
- TableName: Full table name including schema
- equality_columns: Columns that should be key columns (WHERE col = value)
- inequality_columns: Columns for range operations (WHERE col > value)
- included_columns: Columns that should be included for covering

IMPROVEMENT MEASURE CALCULATION:
avg_total_user_cost × avg_user_impact × (user_seeks + user_scans)
- Higher values indicate greater potential performance benefit
- Combines query cost, performance impact, and frequency of use

USAGE:
1. Execute script to get missing index recommendations
2. Focus on highest improvement_measure values first
3. Analyze column recommendations for index design
4. Create indexes manually or use IndexSuggestions.sql for CREATE statements

IMPORTANT CONSIDERATIONS:
- Recommendations based on queries since last server restart
- Consider existing indexes to avoid duplicates
- Evaluate maintenance overhead vs. performance gains
- Test in development before production implementation

DIFFERENCE FROM IndexSuggestions.sql:
- This script shows raw column recommendations
- IndexSuggestions.sql generates ready-to-execute CREATE INDEX statements
- Use this for analysis, IndexSuggestions.sql for implementation

USE CASES:
- Quick index opportunity identification
- Performance tuning analysis
- Index strategy planning
- Database optimization assessments

REQUIREMENTS:
- SQL Server 2005 or later
- VIEW SERVER STATE permission
- Database with query activity for recommendations

AUTHOR: Index Optimization
CREATED: Various
LAST MODIFIED: 2025-06-04
================================================================================
*/

-- filepath: c:\Users\ThomasWimprine\OneDrive - In-Telecom Consulting\Repositories\UsefulSQL\SQL\HelpfulIndexes.SQL
SELECT
    -- Calculate improvement measure: combines cost, impact, and usage frequency
    migs.avg_total_user_cost * migs.avg_user_impact * (migs.user_seeks + migs.user_scans) AS improvement_measure,
    mid.statement AS TableName,
    mid.equality_columns,    -- Columns for WHERE col = value (should be key columns)
    mid.inequality_columns,  -- Columns for WHERE col > value (should be key columns after equality)
    mid.included_columns     -- Columns for covering index (should be INCLUDE columns)
FROM sys.dm_db_missing_index_groups mig
    JOIN sys.dm_db_missing_index_group_stats migs ON mig.index_group_handle = migs.group_handle
    JOIN sys.dm_db_missing_index_details mid ON mig.index_handle = mid.index_handle
ORDER BY improvement_measure DESC;

/*
COLUMN INTERPRETATION:
- equality_columns: Use as key columns first in index
- inequality_columns: Use as key columns after equality columns
- included_columns: Use in INCLUDE clause for covering indexes

EXAMPLE INDEX CREATION FROM RESULTS:
If results show:
- equality_columns: [CustomerID], [OrderDate]
- inequality_columns: [Amount]
- included_columns: [ProductName], [Quantity]

Create index as:
CREATE INDEX IX_Orders_CustomerID_OrderDate_Amount 
ON Orders (CustomerID, OrderDate, Amount) 
INCLUDE (ProductName, Quantity);

ADDITIONAL ANALYSIS QUERIES:
-- Get more detailed statistics
SELECT 
    migs.avg_total_user_cost,
    migs.avg_user_impact,
    migs.user_seeks,
    migs.user_scans,
    migs.last_user_seek,
    migs.last_user_scan,
    mid.statement AS TableName,
    mid.equality_columns,
    mid.inequality_columns,
    mid.included_columns
FROM sys.dm_db_missing_index_groups mig
    JOIN sys.dm_db_missing_index_group_stats migs ON mig.index_group_handle = migs.group_handle
    JOIN sys.dm_db_missing_index_details mid ON mig.index_handle = mid.index_handle
WHERE migs.avg_total_user_cost * migs.avg_user_impact * (migs.user_seeks + migs.user_scans) > 10000
ORDER BY migs.avg_total_user_cost * migs.avg_user_impact * (migs.user_seeks + migs.user_scans) DESC;
*/
