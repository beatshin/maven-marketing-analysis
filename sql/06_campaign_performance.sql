/* =====================================================================
   06 - CAMPAIGN PERFORMANCE
   Business questions: Which campaign was most successful? Who responds?
   Requires: 03_build_clean_tables.sql
   Note: every customer has a flag for every campaign, so acceptance rate
         here means accepted / all customers.
   Dialect:  MySQL 8.0+
   ===================================================================== */

USE marketing;

/* ---------------------------------------------------------------------
   6.1 Acceptance rate by campaign
   Skills: RANK, aggregate on the long-format table
   --------------------------------------------------------------------- */
SELECT
    RANK() OVER (ORDER BY AVG(accepted) DESC) AS success_rank,
    campaign_label,
    SUM(accepted)                             AS acceptances,
    ROUND(100 * AVG(accepted), 1)             AS acceptance_rate_pct
FROM campaign_responses
GROUP BY campaign_no, campaign_label
ORDER BY campaign_no;

/* ---------------------------------------------------------------------
   6.2 Acceptance by country (minimum 100 customers)
   Skills: conditional AVG across the campaign table
   --------------------------------------------------------------------- */
SELECT
    c.country,
    COUNT(DISTINCT c.customer_id)                                    AS customers,
    ROUND(100 * AVG(CASE WHEN r.campaign_no = 6  THEN r.accepted END), 1) AS last_campaign_pct,
    ROUND(100 * AVG(CASE WHEN r.campaign_no <= 5 THEN r.accepted END), 1) AS earlier_campaigns_pct
FROM customers c
JOIN campaign_responses r ON r.customer_id = c.customer_id
GROUP BY c.country
HAVING COUNT(DISTINCT c.customer_id) >= 100
ORDER BY last_campaign_pct DESC;

/* ---------------------------------------------------------------------
   6.3 Do customers who accepted earlier campaigns respond again?
   --------------------------------------------------------------------- */
SELECT
    previous_campaigns_accepted                 AS earlier_campaigns_accepted,
    COUNT(*)                                    AS customers,
    ROUND(AVG(total_spend), 0)                  AS avg_total_spend,
    ROUND(100 * AVG(accepted_last_campaign), 1) AS last_campaign_response_pct
FROM customer_summary
GROUP BY previous_campaigns_accepted
ORDER BY previous_campaigns_accepted;

/* ---------------------------------------------------------------------
   6.4 Profile of responders vs non-responders (last campaign)
   --------------------------------------------------------------------- */
SELECT
    CASE WHEN accepted_last_campaign = 1 THEN 'Accepted' ELSE 'Did not accept' END AS last_campaign,
    COUNT(*)                              AS customers,
    ROUND(AVG(income), 0)                 AS avg_income,
    ROUND(AVG(total_spend), 0)            AS avg_total_spend,
    ROUND(AVG(recency_days), 1)           AS avg_days_since_purchase,
    ROUND(AVG(kids_home + teens_home), 2) AS avg_children_at_home,
    ROUND(AVG(deal_purchases), 2)         AS avg_discount_purchases
FROM customer_summary
GROUP BY last_campaign;

/* ---------------------------------------------------------------------
   6.5 Does recent activity predict response?
   --------------------------------------------------------------------- */
SELECT
    CASE
        WHEN recency_days < 25 THEN '0-24 days'
        WHEN recency_days < 50 THEN '25-49 days'
        WHEN recency_days < 75 THEN '50-74 days'
        ELSE '75-99 days'
    END                                         AS days_since_last_purchase,
    COUNT(*)                                    AS customers,
    ROUND(100 * AVG(accepted_last_campaign), 1) AS last_campaign_response_pct
FROM customer_summary
GROUP BY days_since_last_purchase
ORDER BY MIN(recency_days);
