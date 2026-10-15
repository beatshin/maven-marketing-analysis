# Olist E-Commerce SQL Analysis

SQL analysis of about 100k orders from Olist, a Brazilian online marketplace, covering sales, customers, delivery performance, and sellers.

**Dialect:** MySQL 8.0 | **Tools:** MySQL Server, MySQL Workbench | **Period:** 2016 to 2018

---

## Dataset

Source: [Brazilian E-Commerce Public Dataset by Olist on Kaggle](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) (CSV files loaded into MySQL)

| Table | Description |
|---|---|
| `orders` | Order status and key timestamps |
| `order_items` | Products in each order, price, freight, seller |
| `order_payments` | Payment type, installments, value |
| `order_reviews` | Review scores and comments |
| `customers` | Customer location; `customer_unique_id` identifies real people |
| `products` | Product category and dimensions |
| `sellers` | Seller location |
| `product_category_name_translation` | Portuguese to English category names |

![Schema](images/schema_diagram.png)

## Business questions

1. How is revenue growing, and which categories drive it?
2. How many customers come back after their first purchase?
3. Where are deliveries late, and what does lateness cost in review scores?
4. How concentrated is revenue among sellers?

## Key findings

> Fill these in after running the queries. Replace the X values with your real numbers.

- **Growth:** Monthly revenue grew from X in Jan 2017 to Y in Aug 2018.
- **Categories:** The top 3 categories (A, B, C) account for X% of revenue.
- **Retention:** Only X% of customers placed a second order.
- **Delivery:** X% of orders arrived after the estimated date. Late orders averaged a review score of X vs Y for on-time orders.
- **Geography:** State Z had the highest late rate at X%.
- **Sellers:** The top 10% of sellers generate X% of revenue.

## Featured queries

### Late delivery vs review score ([05_delivery_analysis.sql](sql/05_delivery_analysis.sql))

```sql
WITH order_reviews_avg AS (
    SELECT order_id, AVG(review_score) AS review_score
    FROM order_reviews
    GROUP BY order_id
),
delivery AS (
    SELECT
        d.order_id,
        CASE
            WHEN DATE(d.order_delivered_customer_date) <= DATE(d.order_estimated_delivery_date) THEN 'on time'
            WHEN DATEDIFF(d.order_delivered_customer_date, d.order_estimated_delivery_date) <= 7 THEN '1-7 days late'
            ELSE '8+ days late'
        END AS delivery_status
    FROM delivered_orders d
    WHERE d.order_delivered_customer_date IS NOT NULL
)
SELECT delivery_status, COUNT(*) AS orders, ROUND(AVG(r.review_score), 2) AS avg_review_score
FROM delivery dl
JOIN order_reviews_avg r ON r.order_id = dl.order_id
GROUP BY delivery_status;
```

**Result:** _paste a small table or screenshot here_

### Cohort retention ([04_customer_analysis.sql](sql/04_customer_analysis.sql))

Tracks customers by first-purchase month and measures how many order again in months 0 to 6.

**Result:** _paste a small table or screenshot here_

## Recommendations

_Write 3 to 4 recommendations based on your findings, for example:_
1. Improve delivery estimates or logistics in the worst-performing states.
2. Introduce a post-purchase campaign to lift repeat purchases.
3. Review high-volume sellers with low review scores.

## Data quality notes

- Only `delivered` orders are used for revenue and delivery analysis.
- Revenue is `SUM(order_items.price)`; freight is analysed separately.
- `customer_unique_id` is used to identify customers, because `customer_id` is generated per order.
- Reviews are averaged per order because some orders have multiple reviews.
- 2016 data is sparse, so trend analysis starts in January 2017.

## Limitations

- Data covers 2016 to 2018 only, and the final months are incomplete.
- Customers are anonymised; no demographic data is available.
- Review scores are self-selected and may skew toward extreme experiences.

## How to reproduce

1. Install MySQL 8.0 or later (window functions and CTEs are required).
2. Download the CSV files from Kaggle and place them in `data/` (see [data/README.md](data/README.md)).
3. Run the scripts in order:

| File | Purpose |
|---|---|
| `sql/00_create_schema_and_load.sql` | Creates the `olist` database, tables and indexes, and loads the CSVs |
| `sql/01_data_exploration.sql` | Tables, row counts, date range, statuses |
| `sql/02_data_cleaning.sql` | Quality checks and the `delivered_orders` view |
| `sql/03_sales_analysis.sql` | Revenue trends, categories, AOV, payments |
| `sql/04_customer_analysis.sql` | Repeat rate, geography, RFM, cohorts |
| `sql/05_delivery_analysis.sql` | Delivery times, late rate, review impact |
| `sql/06_seller_analysis.sql` | Seller concentration and quality |

## Skills demonstrated

Schema design and bulk loading (`LOAD DATA`), multi-table JOINs, CTEs, window functions (`RANK`, `LAG`, `NTILE`, running totals), conditional aggregation, MySQL date functions, views, data quality checks.
