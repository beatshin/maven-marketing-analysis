/* =====================================================================
   00 - CREATE DATABASE AND LOAD THE RAW DATA
   Dialect:  MySQL 8.0+
   Before running: replace /path/to/ with the full path to this repo's
   data folder and make sure local_infile is enabled (see data/README.md).
   If you get "ERROR 3948 / 2068", enable local_infile on both the
   server and your client connection.
   ===================================================================== */

DROP DATABASE IF EXISTS marketing;
CREATE DATABASE marketing CHARACTER SET utf8mb4;
USE marketing;

-- Raw table: one row per customer, column names as in the source file.
-- It is never modified; all cleaning happens in 03_build_clean_tables.sql.
CREATE TABLE marketing_raw (
    ID                   INT PRIMARY KEY,
    Year_Birth           SMALLINT,
    Education            VARCHAR(20),
    Marital_Status       VARCHAR(20),
    Income               DECIMAL(10,2) NULL,
    Kidhome              TINYINT,
    Teenhome             TINYINT,
    Dt_Customer          DATE,
    Recency              SMALLINT,
    MntWines             INT,
    MntFruits            INT,
    MntMeatProducts      INT,
    MntFishProducts      INT,
    MntSweetProducts     INT,
    MntGoldProds         INT,
    NumDealsPurchases    INT,
    NumWebPurchases      INT,
    NumCatalogPurchases  INT,
    NumStorePurchases    INT,
    NumWebVisitsMonth    INT,
    AcceptedCmp3         TINYINT,
    AcceptedCmp4         TINYINT,
    AcceptedCmp5         TINYINT,
    AcceptedCmp1         TINYINT,
    AcceptedCmp2         TINYINT,
    Response             TINYINT,
    Complain             TINYINT,
    Country              VARCHAR(20)
);

-- The source header is " Income " (with spaces) and the file starts with a
-- byte-order mark; IGNORE 1 LINES skips the header so neither matters.
-- Blank incomes become NULL. The file uses Windows line endings (\r\n), so
-- lines are split on '\n' and the leftover '\r' is trimmed off the last
-- column. This works for both Windows and Unix line endings.
LOAD DATA LOCAL INFILE '/path/to/marketing_data.csv'
INTO TABLE marketing_raw
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(ID, Year_Birth, Education, Marital_Status, @income, Kidhome, Teenhome,
 Dt_Customer, Recency, MntWines, MntFruits, MntMeatProducts, MntFishProducts,
 MntSweetProducts, MntGoldProds, NumDealsPurchases, NumWebPurchases,
 NumCatalogPurchases, NumStorePurchases, NumWebVisitsMonth, AcceptedCmp3,
 AcceptedCmp4, AcceptedCmp5, AcceptedCmp1, AcceptedCmp2, Response, Complain,
 @country)
SET Income  = NULLIF(TRIM(@income), ''),
    Country = TRIM(TRAILING '\r' FROM @country);

-- Sanity check: expect 2240 rows
SELECT COUNT(*) AS rows_loaded FROM marketing_raw;
