/* =====================================================================
   02 - DATA QUALITY CHECKS
   Goal:     Answer "are there nulls or outliers, and how will I handle
             them?" before any analysis.
   Dialect:  MySQL 8.0+
   ===================================================================== */

USE marketing;

-- 2.1 NULLs in the main columns
SELECT
    SUM(Income IS NULL)         AS null_income,
    SUM(Education IS NULL)      AS null_education,
    SUM(Marital_Status IS NULL) AS null_marital_status,
    SUM(Dt_Customer IS NULL)    AS null_enrollment_date,
    SUM(Country IS NULL)        AS null_country
FROM marketing_raw;

-- 2.2 Duplicate customer IDs (should return no rows)
SELECT ID, COUNT(*) AS n
FROM marketing_raw
GROUP BY ID
HAVING COUNT(*) > 1;

-- 2.3 Income outliers: the highest incomes ...
SELECT ID, Income
FROM marketing_raw
WHERE Income IS NOT NULL
ORDER BY Income DESC
LIMIT 5;

-- ... and the IQR fences (quartiles via PERCENT_RANK)
WITH ranked AS (
    SELECT Income, PERCENT_RANK() OVER (ORDER BY Income) AS pr
    FROM marketing_raw
    WHERE Income IS NOT NULL
),
quartiles AS (
    SELECT
        MIN(CASE WHEN pr >= 0.25 THEN Income END) AS q1,
        MIN(CASE WHEN pr >= 0.75 THEN Income END) AS q3
    FROM ranked
)
SELECT
    q1,
    q3,
    q3 + 1.5 * (q3 - q1) AS upper_fence,
    (SELECT COUNT(*) FROM marketing_raw WHERE Income > q3 + 1.5 * (q3 - q1)) AS incomes_above_fence
FROM quartiles;

-- 2.4 Implausible birth years
SELECT ID, Year_Birth
FROM marketing_raw
WHERE Year_Birth < 1930
ORDER BY Year_Birth;

-- 2.5 Marital status values (look for odd categories)
SELECT Marital_Status, COUNT(*) AS customers
FROM marketing_raw
GROUP BY Marital_Status
ORDER BY customers DESC;

-- 2.6 Customers with no purchases in any channel
SELECT COUNT(*) AS customers_with_no_purchases
FROM marketing_raw
WHERE NumWebPurchases + NumCatalogPurchases + NumStorePurchases = 0;

-- 2.7 Do discount purchases ever exceed total purchases?
SELECT COUNT(*) AS deals_exceed_total
FROM marketing_raw
WHERE NumDealsPurchases > NumWebPurchases + NumCatalogPurchases + NumStorePurchases;

-- 2.8 Countries with very few customers
SELECT Country, COUNT(*) AS customers
FROM marketing_raw
GROUP BY Country
HAVING COUNT(*) < 50;

/* ---------------------------------------------------------------------
   DECISIONS (applied in 03_build_clean_tables.sql)
   - Missing income: kept as NULL, not imputed. Income-based analysis
     excludes these customers; everything else keeps them.
   - Income above 200,000: treated as an error and set to NULL (a single
     value, far above the next highest).
   - Birth year before 1930: set to NULL (implausible ages).
   - Marital status: 'Alone' mapped to 'Single'; 'YOLO' and 'Absurd'
     mapped to 'Unknown' because they are not real categories.
   - Customers with no purchases are kept but excluded from ratios that
     divide by purchase counts.
   - A few customers have more discount purchases than total purchases,
     so discount purchases are treated as a separate count, not a share
     of total purchases.
   - Countries with very few customers are excluded from country
     comparisons using a minimum-sample filter.
   --------------------------------------------------------------------- */
