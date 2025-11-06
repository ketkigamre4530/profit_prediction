-- 1️⃣ Create and select database
CREATE DATABASE banking_product_profitability;
USE banking_product_profitability;

-- 2️⃣ Create base product master table
CREATE TABLE products (
    product_id INT AUTO_INCREMENT PRIMARY KEY,
    product_code VARCHAR(50) UNIQUE,
    product_name VARCHAR(100),
    product_category VARCHAR(50)  -- 'Asset', 'Liability', 'Fee/Other'
);

-- 3️⃣ Create monthly metrics table
CREATE TABLE product_monthly_metrics (
    metric_id INT AUTO_INCREMENT PRIMARY KEY,
    product_id INT,
    report_month DATE,                -- first day of month
    revenue DECIMAL(18,2),
    cost DECIMAL(18,2),
    marketing_expense DECIMAL(18,2),
    customer_acquisition INT,
    active_customers INT,
    churn_count INT,
    interest_income DECIMAL(18,2),
    interest_expense DECIMAL(18,2),
    earning_assets DECIMAL(18,2),
    region VARCHAR(50),
    FOREIGN KEY (product_id) REFERENCES products(product_id)
);

-- 4️⃣ Insert products
INSERT INTO products (product_code, product_name, product_category) VALUES
('SAV001','Savings Account','Liability'),
('FD001','Fixed Deposit','Liability'),
('HL001','Home Loan','Asset'),
('PL001','Personal Loan','Asset'),
('CC001','Credit Card','Asset'),
('IN001','Insurance','Fee/Other');

-- 5️⃣ Insert sample monthly metrics
INSERT INTO product_monthly_metrics (product_id, report_month, revenue, cost, marketing_expense, customer_acquisition, active_customers, churn_count, interest_income, interest_expense, earning_assets, region)
VALUES
(1,'2024-01-01', 500000,120000,20000,500,10000,80,0,10000,5000000,'Mumbai'),
(1,'2024-02-01', 510000,125000,15000,450,10150,90,0,10500,5100000,'Mumbai'),
(2,'2024-01-01', 300000,50000,10000,200,3000,10,0,2000,3000000,'Pune'),
(3,'2024-01-01', 1200000,300000,30000,120,2000,30,70000,0,15000000,'Bangalore'),
(4,'2024-01-01', 400000,150000,25000,80,800,40,20000,0,3000000,'Delhi'),
(5,'2024-01-01', 600000,200000,50000,300,5000,120,0,0,0,'Mumbai'),
(6,'2024-01-01', 250000,60000,15000,50,700,15,0,0,0,'Mumbai'),
(1,'2024-03-01', 520000,128000,18000,480,10200,75,0,11000,5150000,'Mumbai'),
(2,'2024-02-01', 320000,52000,9000,230,3100,12,0,2100,3050000,'Pune'),
(3,'2024-02-01', 1250000,310000,28000,130,2100,25,72000,0,15200000,'Bangalore');

-- 6️⃣ Clean duplicates (if any)
CREATE TEMPORARY TABLE keep_metrics AS
SELECT MIN(metric_id) AS keep_id
FROM product_monthly_metrics
GROUP BY product_id, report_month, revenue, cost, marketing_expense, customer_acquisition, active_customers, churn_count, interest_income, interest_expense, earning_assets, region;

SET SQL_SAFE_UPDATES = 0;

DELETE pm
FROM product_monthly_metrics pm
LEFT JOIN keep_metrics k ON pm.metric_id = k.keep_id
WHERE k.keep_id IS NULL;

SET SQL_SAFE_UPDATES = 1;

DROP TEMPORARY TABLE keep_metrics;


-- 7️⃣ Create monthly KPI view
CREATE OR REPLACE VIEW vw_product_monthly_kpis AS
SELECT
    p.product_id,
    p.product_code,
    p.product_name,
    p.product_category,
    m.report_month,
    m.region,
    m.revenue,
    m.cost,
    m.marketing_expense,
    (m.revenue - m.cost - m.marketing_expense) AS profit,
    CASE WHEN m.revenue = 0 THEN NULL
         ELSE ROUND(((m.revenue - m.cost - m.marketing_expense) / m.revenue) * 100, 2)
    END AS profit_margin_pct,
    m.customer_acquisition,
    m.active_customers,
    m.churn_count,
    CASE WHEN m.active_customers = 0 THEN NULL
         ELSE ROUND((m.churn_count / m.active_customers) * 100, 2)
    END AS churn_rate_pct,
    CASE WHEN m.marketing_expense = 0 THEN NULL
         ELSE ROUND(((m.revenue - m.cost) / m.marketing_expense), 2)
    END AS marketing_roi,
    m.interest_income,
    m.interest_expense,
    m.earning_assets,
    CASE WHEN m.earning_assets = 0 THEN NULL
         ELSE ROUND(((m.interest_income - m.interest_expense) / m.earning_assets) * 100, 4)
    END AS net_interest_margin_pct
FROM products p
JOIN product_monthly_metrics m ON p.product_id = m.product_id;

-- 8️⃣ Create yearly summary view (corrected version)
CREATE OR REPLACE VIEW vw_product_yearly_summary AS
SELECT
    p.product_id,
    p.product_code,
    p.product_name,
    p.product_category,
    YEAR(m.report_month) AS year_num,
    SUM(m.revenue) AS total_revenue,
    SUM(m.cost) AS total_cost,
    SUM(m.marketing_expense) AS total_marketing,
    SUM(m.revenue - m.cost - m.marketing_expense) AS total_profit,
    CASE WHEN SUM(m.revenue) = 0 THEN NULL
         ELSE ROUND((SUM(m.revenue - m.cost - m.marketing_expense)/SUM(m.revenue))*100,2)
    END AS avg_profit_margin_pct,
    SUM(m.customer_acquisition) AS total_acquisitions,
    SUM(m.active_customers) AS total_active_customers,
    SUM(m.churn_count) AS total_churns,
    CASE WHEN SUM(m.active_customers)=0 THEN NULL
         ELSE ROUND((SUM(m.churn_count)/SUM(m.active_customers))*100,2)
    END AS avg_churn_rate_pct,
    CASE WHEN SUM(m.marketing_expense)=0 THEN NULL
         ELSE ROUND(((SUM(m.revenue)-SUM(m.cost))/SUM(m.marketing_expense)),2)
    END AS marketing_roi,
    SUM(m.interest_income) AS total_interest_income,
    SUM(m.interest_expense) AS total_interest_expense,
    SUM(m.earning_assets) AS total_earning_assets,
    CASE WHEN SUM(m.earning_assets)=0 THEN NULL
         ELSE ROUND(((SUM(m.interest_income)-SUM(m.interest_expense))/SUM(m.earning_assets))*100,4)
    END AS net_interest_margin_pct
FROM products p
JOIN product_monthly_metrics m ON p.product_id = m.product_id
GROUP BY p.product_id, p.product_code, p.product_name, p.product_category, YEAR(m.report_month);

-- 9️⃣ Test queries
-- a) Monthly KPIs
SELECT * FROM vw_product_monthly_kpis;

-- b) Yearly summary (aggregated view)
SELECT * FROM vw_product_yearly_summary ORDER BY year_num DESC, total_profit DESC;

SHOW DATABASES;
USE banking_product_profitability;
SHOW TABLES;
SELECT * FROM vw_product_yearly_summary;

SHOW VARIABLES LIKE 'secure_file_priv';
SELECT * FROM vw_product_monthly_kpis
INTO OUTFILE 'C:\\ProgramData\\MySQL\\MySQL Server 8.0\\Uploads/product_monthly_kpis.csv'
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"' 
LINES TERMINATED BY '\n';

-- Check for nulls / suspicious values
SELECT
  SUM(CASE WHEN revenue IS NULL THEN 1 ELSE 0 END) AS missing_revenue,
  SUM(CASE WHEN cost IS NULL THEN 1 ELSE 0 END) AS missing_cost,
  SUM(CASE WHEN marketing_expense < 0 THEN 1 ELSE 0 END) AS negative_marketing,
  COUNT(*) AS total_rows
FROM product_monthly_metrics;

-- Check month continuity per product (detect missing months)
SELECT product_id, MIN(report_month) AS first_month, MAX(report_month) AS last_month, COUNT(DISTINCT report_month) AS months_present
FROM product_monthly_metrics
GROUP BY product_id;

-- Create or replace a helper view with derived metrics (ARPU, profit per customer, retention proxy)
CREATE OR REPLACE VIEW vw_product_enriched AS
SELECT
  m.*,
  p.product_code, p.product_name, p.product_category,
  CASE WHEN m.active_customers = 0 THEN NULL ELSE ROUND(m.revenue / m.active_customers, 2) END AS arpu,
  CASE WHEN m.active_customers = 0 THEN NULL ELSE ROUND((m.revenue - m.cost - m.marketing_expense) / m.active_customers, 2) END AS profit_per_customer,
  CASE WHEN m.active_customers = 0 THEN NULL ELSE ROUND((m.active_customers - m.churn_count) * 1.0 / NULLIF(m.active_customers,0) * 100, 2) END AS retention_pct
FROM product_monthly_metrics m
JOIN products p ON p.product_id = m.product_id;

-- MySQL 8 window example for rolling 3-month averages
CREATE OR REPLACE VIEW vw_product_rolling AS
SELECT
  product_id, report_month,
  revenue, cost, marketing_expense, active_customers,
  ROUND(AVG(revenue) OVER (PARTITION BY product_id ORDER BY report_month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW),2) AS revenue_roll3,
  ROUND(AVG(marketing_expense) OVER (PARTITION BY product_id ORDER BY report_month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW),2) AS marketing_roll3,
  -- YoY revenue growth (requires monthly granularity)
  LAG(revenue, 12) OVER (PARTITION BY product_id ORDER BY report_month) AS revenue_prev_year,
  CASE WHEN LAG(revenue,12) OVER (PARTITION BY product_id ORDER BY report_month) IS NULL THEN NULL
       ELSE ROUND((revenue - LAG(revenue,12) OVER (PARTITION BY product_id ORDER BY report_month)) / LAG(revenue,12) OVER (PARTITION BY product_id ORDER BY report_month) * 100,2)
  END AS yoy_revenue_pct
FROM product_monthly_metrics;

SELECT product_id, product_name, year_num, total_revenue, total_cost, total_marketing, total_profit
FROM vw_product_yearly_summary
ORDER BY total_profit DESC
LIMIT 10;

SELECT 
    p.product_id,
    p.product_name,
    m.region,
    SUM(m.revenue) AS revenue,
    SUM(m.cost) AS cost,
    SUM(m.marketing_expense) AS marketing,
    CASE 
        WHEN SUM(m.marketing_expense) = 0 THEN NULL 
        ELSE ROUND((SUM(m.revenue) - SUM(m.cost)) / SUM(m.marketing_expense), 2) 
    END AS marketing_roi
FROM product_monthly_metrics m
JOIN products p ON p.product_id = m.product_id
GROUP BY p.product_id, p.product_name, m.region
ORDER BY marketing_roi DESC;

SELECT product_id, report_month, active_customers, churn_count, customer_acquisition
FROM product_monthly_metrics
ORDER BY product_id, report_month;




