/* =====================================================================
   01 - DATA EXPLORATION
   Goal:     Understand the size, categories and ranges of the raw data.
   Dialect:  MySQL 8.0+
   ===================================================================== */

USE marketing;

-- 1.1 Size and enrollment date range
SELECT
    COUNT(*)         AS customers,
    MIN(Dt_Customer) AS first_enrollment,
    MAX(Dt_Customer) AS last_enrollment
FROM marketing_raw;

-- 1.2 Category values and their counts
SELECT 'Education' AS dimension, Education AS value, COUNT(*) AS customers
FROM marketing_raw GROUP BY Education
UNION ALL
SELECT 'Marital_Status', Marital_Status, COUNT(*)
FROM marketing_raw GROUP BY Marital_Status
UNION ALL
SELECT 'Country', Country, COUNT(*)
FROM marketing_raw GROUP BY Country
ORDER BY dimension, customers DESC;

-- 1.3 Ranges of the main numeric columns
SELECT
    MIN(Year_Birth)  AS min_birth_year,  MAX(Year_Birth)  AS max_birth_year,
    MIN(Income)      AS min_income,      MAX(Income)      AS max_income,
    ROUND(AVG(Income), 0) AS avg_income,
    MIN(Recency)     AS min_recency,     MAX(Recency)     AS max_recency,
    MAX(NumWebVisitsMonth) AS max_web_visits
FROM marketing_raw;

-- 1.4 Total acceptances per campaign (raw flags)
SELECT
    SUM(AcceptedCmp1) AS cmp1, SUM(AcceptedCmp2) AS cmp2,
    SUM(AcceptedCmp3) AS cmp3, SUM(AcceptedCmp4) AS cmp4,
    SUM(AcceptedCmp5) AS cmp5, SUM(Response)     AS last_campaign,
    SUM(Complain)     AS complaints
FROM marketing_raw;
