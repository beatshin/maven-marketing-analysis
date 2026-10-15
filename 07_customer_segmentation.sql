/* =====================================================================
   07 - CUSTOMER SEGMENTATION
   Business question: Which customers are the most valuable, and how
   concentrated is spend?
   Requires: 03_build_clean_tables.sql
   Dialect:  MySQL 8.0+
   ===================================================================== */

USE marketing;

/* ---------------------------------------------------------------------
   7.1 RFM segmentation
   Recency = days since last purchase, Frequency = number of purchases,
   Monetary = total spend. Each is scored 1 to 4 with NTILE (4 = best).
   Note: NTILE splits tied values arbitrarily, so scores near ties can
   vary slightly between runs.
   Skills: multiple CTEs, NTILE, CASE segmentation
   --------------------------------------------------------------------- */
WITH scored AS (
    SELECT
        customer_id,
        total_spend,
        accepted_last_campaign,
        NTILE(4) OVER (ORDER BY recency_days DESC) AS r_score,
        NTILE(4) OVER (ORDER BY total_purchases)   AS f_score,
        NTILE(4) OVER (ORDER BY total_spend)       AS m_score
    FROM customer_summary
),
segmented AS (
    SELECT
        *,
        CASE
            WHEN r_score >= 3 AND f_score >= 3 AND m_score >= 3 THEN '1 Champions'
            WHEN r_score <= 2 AND f_score >= 3 AND m_score >= 3 THEN '2 At-risk high value'
            WHEN r_score >= 3 AND m_score <= 2                  THEN '3 Recent, low spend'
            WHEN r_score <= 2 AND m_score <= 2                  THEN '4 Low engagement'
            ELSE '5 Core'
        END AS segment
    FROM scored
)
SELECT
    segment,
    COUNT(*)                                    AS customers,
    ROUND(AVG(total_spend), 0)                  AS avg_total_spend,
    ROUND(100 * SUM(total_spend) / SUM(SUM(total_spend)) OVER (), 1) AS pct_of_total_spend,
    ROUND(100 * AVG(accepted_last_campaign), 1) AS last_campaign_response_pct
FROM segmented
GROUP BY segment
ORDER BY segment;

/* ---------------------------------------------------------------------
   7.2 How concentrated is spend? (spend quintiles, 1 = top 20%)
   Skills: NTILE, window SUM for share of total
   --------------------------------------------------------------------- */
WITH ranked AS (
    SELECT
        customer_id,
        total_spend,
        NTILE(5) OVER (ORDER BY total_spend DESC) AS spend_quintile
    FROM customer_summary
)
SELECT
    spend_quintile,
    COUNT(*)                                                       AS customers,
    MIN(total_spend)                                               AS min_spend,
    MAX(total_spend)                                               AS max_spend,
    ROUND(100 * SUM(total_spend) / SUM(SUM(total_spend)) OVER (), 1) AS pct_of_total_spend
FROM ranked
GROUP BY spend_quintile
ORDER BY spend_quintile;

/* ---------------------------------------------------------------------
   7.3 Who are the top 10% of customers by spend?
   --------------------------------------------------------------------- */
WITH ranked AS (
    SELECT
        *,
        NTILE(10) OVER (ORDER BY total_spend DESC) AS spend_decile
    FROM customer_summary
)
SELECT
    CASE WHEN spend_decile = 1 THEN 'Top 10%' ELSE 'Other 90%' END AS customer_group,
    COUNT(*)                                    AS customers,
    ROUND(AVG(income), 0)                       AS avg_income,
    ROUND(AVG(age), 1)                          AS avg_age,
    ROUND(AVG(kids_home + teens_home), 2)       AS avg_children_at_home,
    ROUND(AVG(catalog_purchases), 2)            AS avg_catalog_purchases,
    ROUND(AVG(web_visits_month), 1)             AS avg_web_visits_month,
    ROUND(100 * AVG(accepted_last_campaign), 1) AS last_campaign_response_pct
FROM ranked
GROUP BY customer_group
ORDER BY customer_group DESC;
