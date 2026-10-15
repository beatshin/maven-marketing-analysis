/* =====================================================================
   04 - CUSTOMER PROFILE
   Business question: What does the average customer look like, and which
   customer groups spend the most?
   Requires: 03_build_clean_tables.sql
   Dialect:  MySQL 8.0+
   ===================================================================== */

USE marketing;

/* ---------------------------------------------------------------------
   4.1 The average customer
   --------------------------------------------------------------------- */
SELECT
    COUNT(*)                          AS customers,
    ROUND(AVG(age), 1)                AS avg_age,
    ROUND(AVG(income), 0)             AS avg_income,
    ROUND(AVG(kids_home + teens_home), 2) AS avg_children_at_home,
    ROUND(AVG(total_spend), 0)        AS avg_total_spend,
    ROUND(AVG(total_purchases), 1)    AS avg_purchases,
    ROUND(AVG(recency_days), 0)       AS avg_days_since_purchase
FROM customer_summary;

/* ---------------------------------------------------------------------
   4.2 Spend and response by education level
   Skills: GROUP BY, aggregation on a view
   --------------------------------------------------------------------- */
SELECT
    education,
    COUNT(*)                                   AS customers,
    ROUND(AVG(income), 0)                      AS avg_income,
    ROUND(AVG(total_spend), 0)                 AS avg_total_spend,
    ROUND(100 * AVG(accepted_last_campaign), 1) AS last_campaign_response_pct
FROM customer_summary
GROUP BY education
ORDER BY avg_total_spend DESC;

/* ---------------------------------------------------------------------
   4.3 Countries ranked by average spend (minimum 100 customers)
   Skills: CTE, RANK
   --------------------------------------------------------------------- */
WITH country_stats AS (
    SELECT
        country,
        COUNT(*)                   AS customers,
        ROUND(AVG(total_spend), 0) AS avg_total_spend,
        ROUND(SUM(total_spend), 0) AS total_spend
    FROM customer_summary
    GROUP BY country
    HAVING COUNT(*) >= 100
)
SELECT
    RANK() OVER (ORDER BY avg_total_spend DESC) AS spend_rank,
    country,
    customers,
    avg_total_spend,
    total_spend
FROM country_stats
ORDER BY spend_rank;

/* ---------------------------------------------------------------------
   4.4 Age groups: spend and campaign response
   Skills: CASE bucketing
   --------------------------------------------------------------------- */
SELECT
    CASE
        WHEN age IS NULL THEN 'Unknown'
        WHEN age < 35    THEN 'Under 35'
        WHEN age < 50    THEN '35-49'
        WHEN age < 65    THEN '50-64'
        ELSE '65+'
    END                                        AS age_group,
    COUNT(*)                                   AS customers,
    ROUND(AVG(total_spend), 0)                 AS avg_total_spend,
    ROUND(100 * AVG(accepted_last_campaign), 1) AS last_campaign_response_pct
FROM customer_summary
GROUP BY age_group
ORDER BY MIN(COALESCE(age, 999));

/* ---------------------------------------------------------------------
   4.5 Income quartiles: how much more do high earners spend?
   Skills: NTILE (customers with missing income are excluded)
   --------------------------------------------------------------------- */
WITH income_groups AS (
    SELECT
        customer_id, income, total_spend, web_visits_month, total_purchases,
        NTILE(4) OVER (ORDER BY income) AS income_quartile
    FROM customer_summary
    WHERE income IS NOT NULL
)
SELECT
    income_quartile,
    COUNT(*)                       AS customers,
    MIN(income)                    AS min_income,
    MAX(income)                    AS max_income,
    ROUND(AVG(total_spend), 0)     AS avg_total_spend,
    ROUND(AVG(total_purchases), 1) AS avg_purchases,
    ROUND(AVG(web_visits_month), 1) AS avg_web_visits_month
FROM income_groups
GROUP BY income_quartile
ORDER BY income_quartile;

/* ---------------------------------------------------------------------
   4.6 Household type: spend, wine spend and discount use
   Skills: JOIN to the long-format product table, CASE
   --------------------------------------------------------------------- */
SELECT
    CASE
        WHEN cs.kids_home + cs.teens_home = 0 THEN 'No children'
        WHEN cs.kids_home > 0 AND cs.teens_home > 0 THEN 'Kids and teens'
        WHEN cs.kids_home > 0 THEN 'Kids only'
        ELSE 'Teens only'
    END                                  AS household_type,
    COUNT(*)                             AS customers,
    ROUND(AVG(cs.total_spend), 0)        AS avg_total_spend,
    ROUND(AVG(ps.amount), 0)             AS avg_wine_spend,
    ROUND(AVG(cs.deal_purchases), 2)     AS avg_discount_purchases
FROM customer_summary cs
JOIN product_spend ps
  ON ps.customer_id = cs.customer_id
 AND ps.product_category = 'Wine'
GROUP BY household_type
ORDER BY avg_total_spend DESC;
