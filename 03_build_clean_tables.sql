/* =====================================================================
   03 - BUILD CLEAN, NORMALIZED TABLES
   Goal:     Turn the single wide table into a small relational model so
             later queries use real joins.

             customers ──< product_spend
                  │──< channel_purchases
                  │──< campaign_responses
                  └──1 customer_activity
             customer_summary (view) joins them back together.
   Dialect:  MySQL 8.0+
   ===================================================================== */

USE marketing;

DROP VIEW IF EXISTS customer_summary;
DROP TABLE IF EXISTS campaign_responses, channel_purchases, product_spend,
                     customer_activity, customers;

-- ---------------------------------------------------------------------
-- customers: one row per customer, cleaned attributes
-- ---------------------------------------------------------------------
CREATE TABLE customers (
    customer_id     INT PRIMARY KEY,
    birth_year      SMALLINT NULL,
    age             SMALLINT NULL,          -- age in 2014 (data ends June 2014)
    education       VARCHAR(20),
    marital_status  VARCHAR(20),
    income          DECIMAL(10,2) NULL,
    kids_home       TINYINT,
    teens_home      TINYINT,
    enrollment_date DATE,
    country         VARCHAR(20)
);

INSERT INTO customers
SELECT
    ID,
    CASE WHEN Year_Birth < 1930 THEN NULL ELSE Year_Birth END,
    CASE WHEN Year_Birth < 1930 THEN NULL ELSE 2014 - Year_Birth END,
    Education,
    CASE Marital_Status
        WHEN 'Alone'  THEN 'Single'
        WHEN 'YOLO'   THEN 'Unknown'
        WHEN 'Absurd' THEN 'Unknown'
        ELSE Marital_Status
    END,
    CASE WHEN Income > 200000 THEN NULL ELSE Income END,
    Kidhome,
    Teenhome,
    Dt_Customer,
    Country
FROM marketing_raw;

-- ---------------------------------------------------------------------
-- customer_activity: one row per customer, behaviour metrics
-- ---------------------------------------------------------------------
CREATE TABLE customer_activity (
    customer_id      INT PRIMARY KEY,
    recency_days     SMALLINT,              -- days since last purchase
    web_visits_month INT,                   -- website visits in the last month
    deal_purchases   INT,                   -- purchases made with a discount
    complained       TINYINT,               -- complained in the last 2 years
    FOREIGN KEY (customer_id) REFERENCES customers (customer_id)
);

INSERT INTO customer_activity
SELECT ID, Recency, NumWebVisitsMonth, NumDealsPurchases, Complain
FROM marketing_raw;

-- ---------------------------------------------------------------------
-- product_spend: one row per customer per product category (long format)
-- ---------------------------------------------------------------------
CREATE TABLE product_spend (
    customer_id      INT NOT NULL,
    product_category VARCHAR(20) NOT NULL,
    amount           INT NOT NULL,          -- spend over the last 2 years
    PRIMARY KEY (customer_id, product_category),
    FOREIGN KEY (customer_id) REFERENCES customers (customer_id)
);

INSERT INTO product_spend
SELECT ID, 'Wine',   MntWines         FROM marketing_raw
UNION ALL SELECT ID, 'Fruit',  MntFruits        FROM marketing_raw
UNION ALL SELECT ID, 'Meat',   MntMeatProducts  FROM marketing_raw
UNION ALL SELECT ID, 'Fish',   MntFishProducts  FROM marketing_raw
UNION ALL SELECT ID, 'Sweets', MntSweetProducts FROM marketing_raw
UNION ALL SELECT ID, 'Gold',   MntGoldProds     FROM marketing_raw;

-- ---------------------------------------------------------------------
-- channel_purchases: one row per customer per purchase channel
-- ---------------------------------------------------------------------
CREATE TABLE channel_purchases (
    customer_id INT NOT NULL,
    channel     VARCHAR(10) NOT NULL,
    purchases   INT NOT NULL,
    PRIMARY KEY (customer_id, channel),
    FOREIGN KEY (customer_id) REFERENCES customers (customer_id)
);

INSERT INTO channel_purchases
SELECT ID, 'Web',     NumWebPurchases     FROM marketing_raw
UNION ALL SELECT ID, 'Catalog', NumCatalogPurchases FROM marketing_raw
UNION ALL SELECT ID, 'Store',   NumStorePurchases   FROM marketing_raw;

-- ---------------------------------------------------------------------
-- campaign_responses: one row per customer per campaign
-- campaign_no 1 to 5 are the earlier campaigns; 6 is the last campaign
-- ---------------------------------------------------------------------
CREATE TABLE campaign_responses (
    customer_id    INT NOT NULL,
    campaign_no    TINYINT NOT NULL,
    campaign_label VARCHAR(20) NOT NULL,
    accepted       TINYINT NOT NULL,
    PRIMARY KEY (customer_id, campaign_no),
    FOREIGN KEY (customer_id) REFERENCES customers (customer_id)
);

INSERT INTO campaign_responses
SELECT ID, 1, 'Campaign 1',    AcceptedCmp1 FROM marketing_raw
UNION ALL SELECT ID, 2, 'Campaign 2',    AcceptedCmp2 FROM marketing_raw
UNION ALL SELECT ID, 3, 'Campaign 3',    AcceptedCmp3 FROM marketing_raw
UNION ALL SELECT ID, 4, 'Campaign 4',    AcceptedCmp4 FROM marketing_raw
UNION ALL SELECT ID, 5, 'Campaign 5',    AcceptedCmp5 FROM marketing_raw
UNION ALL SELECT ID, 6, 'Last campaign', Response     FROM marketing_raw;

-- ---------------------------------------------------------------------
-- customer_summary: one row per customer with everything joined back
-- ---------------------------------------------------------------------
CREATE VIEW customer_summary AS
SELECT
    c.customer_id, c.age, c.education, c.marital_status, c.income,
    c.kids_home, c.teens_home, c.enrollment_date, c.country,
    a.recency_days, a.web_visits_month, a.deal_purchases, a.complained,
    s.total_spend,
    p.total_purchases, p.web_purchases, p.catalog_purchases, p.store_purchases,
    r.previous_campaigns_accepted, r.accepted_last_campaign
FROM customers c
JOIN customer_activity a ON a.customer_id = c.customer_id
JOIN (
    SELECT customer_id, SUM(amount) AS total_spend
    FROM product_spend
    GROUP BY customer_id
) s ON s.customer_id = c.customer_id
JOIN (
    SELECT
        customer_id,
        SUM(purchases) AS total_purchases,
        SUM(CASE WHEN channel = 'Web'     THEN purchases ELSE 0 END) AS web_purchases,
        SUM(CASE WHEN channel = 'Catalog' THEN purchases ELSE 0 END) AS catalog_purchases,
        SUM(CASE WHEN channel = 'Store'   THEN purchases ELSE 0 END) AS store_purchases
    FROM channel_purchases
    GROUP BY customer_id
) p ON p.customer_id = c.customer_id
JOIN (
    SELECT
        customer_id,
        SUM(CASE WHEN campaign_no <= 5 THEN accepted ELSE 0 END) AS previous_campaigns_accepted,
        SUM(CASE WHEN campaign_no = 6  THEN accepted ELSE 0 END) AS accepted_last_campaign
    FROM campaign_responses
    GROUP BY customer_id
) r ON r.customer_id = c.customer_id;

-- Sanity checks
SELECT 'customers' AS table_name, COUNT(*) AS row_count FROM customers
UNION ALL SELECT 'customer_activity',  COUNT(*) FROM customer_activity
UNION ALL SELECT 'product_spend',      COUNT(*) FROM product_spend
UNION ALL SELECT 'channel_purchases',  COUNT(*) FROM channel_purchases
UNION ALL SELECT 'campaign_responses', COUNT(*) FROM campaign_responses
UNION ALL SELECT 'customer_summary',   COUNT(*) FROM customer_summary;
