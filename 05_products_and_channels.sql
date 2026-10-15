/* =====================================================================
   05 - PRODUCTS AND CHANNELS
   Business questions: Which products perform best? Which channels
   underperform? What is related to web purchases?
   Requires: 03_build_clean_tables.sql
   Dialect:  MySQL 8.0+
   ===================================================================== */

USE marketing;

/* ---------------------------------------------------------------------
   5.1 Product categories ranked by total spend
   Skills: RANK, share of total with a window SUM
   --------------------------------------------------------------------- */
SELECT
    RANK() OVER (ORDER BY SUM(amount) DESC)            AS spend_rank,
    product_category,
    SUM(amount)                                        AS total_spend,
    ROUND(100 * SUM(amount) / SUM(SUM(amount)) OVER (), 1) AS pct_of_spend,
    ROUND(AVG(amount), 1)                              AS avg_per_customer
FROM product_spend
GROUP BY product_category
ORDER BY spend_rank;

/* ---------------------------------------------------------------------
   5.2 Top 2 product categories in each country
   Skills: RANK with PARTITION BY
   --------------------------------------------------------------------- */
WITH country_category AS (
    SELECT
        c.country,
        ps.product_category,
        SUM(ps.amount) AS spend
    FROM product_spend ps
    JOIN customers c ON c.customer_id = ps.customer_id
    GROUP BY c.country, ps.product_category
),
ranked AS (
    SELECT
        country,
        product_category,
        spend,
        RANK() OVER (PARTITION BY country ORDER BY spend DESC) AS category_rank,
        ROUND(100 * spend / SUM(spend) OVER (PARTITION BY country), 1) AS pct_of_country_spend
    FROM country_category
)
SELECT country, category_rank, product_category, spend, pct_of_country_spend
FROM ranked
WHERE category_rank <= 2
ORDER BY country, category_rank;

/* ---------------------------------------------------------------------
   5.3 Channel mix: which channels carry the purchases?
   --------------------------------------------------------------------- */
SELECT
    channel,
    SUM(purchases)                                         AS total_purchases,
    ROUND(100 * SUM(purchases) / SUM(SUM(purchases)) OVER (), 1) AS pct_of_purchases,
    ROUND(AVG(purchases), 2)                               AS avg_per_customer
FROM channel_purchases
GROUP BY channel
ORDER BY total_purchases DESC;

/* ---------------------------------------------------------------------
   5.4 Channel mix by income quartile
   Skills: NTILE, conditional aggregation
   --------------------------------------------------------------------- */
WITH grouped AS (
    SELECT
        web_purchases, catalog_purchases, store_purchases, total_purchases,
        NTILE(4) OVER (ORDER BY income) AS income_quartile
    FROM customer_summary
    WHERE income IS NOT NULL AND total_purchases > 0
)
SELECT
    income_quartile,
    ROUND(100 * SUM(web_purchases)     / SUM(total_purchases), 1) AS web_pct,
    ROUND(100 * SUM(catalog_purchases) / SUM(total_purchases), 1) AS catalog_pct,
    ROUND(100 * SUM(store_purchases)   / SUM(total_purchases), 1) AS store_pct
FROM grouped
GROUP BY income_quartile
ORDER BY income_quartile;

/* ---------------------------------------------------------------------
   5.5 Website visits vs web purchases
   Question: Do customers who visit the site more actually buy there?
   Note: visits cover the last month; purchases cover the whole period,
         so this compares groups, not a per-visit conversion rate.
   --------------------------------------------------------------------- */
SELECT
    CASE
        WHEN web_visits_month <= 2 THEN '0-2 visits'
        WHEN web_visits_month <= 5 THEN '3-5 visits'
        WHEN web_visits_month <= 8 THEN '6-8 visits'
        ELSE '9+ visits'
    END                                AS web_visit_group,
    COUNT(*)                           AS customers,
    ROUND(AVG(web_purchases), 2)       AS avg_web_purchases,
    ROUND(AVG(store_purchases), 2)     AS avg_store_purchases,
    ROUND(AVG(total_spend), 0)         AS avg_total_spend
FROM customer_summary
GROUP BY web_visit_group
ORDER BY MIN(web_visits_month);

/* ---------------------------------------------------------------------
   5.6 What is related to the number of web purchases?
   Pearson correlation calculated by hand, since MySQL has no CORR().
   corr(x, y) = (E[xy] - E[x]E[y]) / (stddev(x) * stddev(y))
   --------------------------------------------------------------------- */
SELECT 'Total spend' AS factor,
       ROUND((AVG(web_purchases * total_spend) - AVG(web_purchases) * AVG(total_spend))
             / (STDDEV_POP(web_purchases) * STDDEV_POP(total_spend)), 3) AS corr_with_web_purchases
FROM customer_summary
UNION ALL
SELECT 'Income',
       ROUND((AVG(web_purchases * income) - AVG(web_purchases) * AVG(income))
             / (STDDEV_POP(web_purchases) * STDDEV_POP(income)), 3)
FROM customer_summary WHERE income IS NOT NULL
UNION ALL
SELECT 'Web visits last month',
       ROUND((AVG(web_purchases * web_visits_month) - AVG(web_purchases) * AVG(web_visits_month))
             / (STDDEV_POP(web_purchases) * STDDEV_POP(web_visits_month)), 3)
FROM customer_summary
UNION ALL
SELECT 'Discount purchases',
       ROUND((AVG(web_purchases * deal_purchases) - AVG(web_purchases) * AVG(deal_purchases))
             / (STDDEV_POP(web_purchases) * STDDEV_POP(deal_purchases)), 3)
FROM customer_summary
UNION ALL
SELECT 'Kids at home',
       ROUND((AVG(web_purchases * kids_home) - AVG(web_purchases) * AVG(kids_home))
             / (STDDEV_POP(web_purchases) * STDDEV_POP(kids_home)), 3)
FROM customer_summary
UNION ALL
SELECT 'Age',
       ROUND((AVG(web_purchases * age) - AVG(web_purchases) * AVG(age))
             / (STDDEV_POP(web_purchases) * STDDEV_POP(age)), 3)
FROM customer_summary WHERE age IS NOT NULL
ORDER BY corr_with_web_purchases DESC;
