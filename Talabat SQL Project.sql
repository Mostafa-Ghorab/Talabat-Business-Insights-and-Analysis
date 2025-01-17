create database [Talabaty]

-- Use the newly created database
USE Talabaty;
GO

-- Select all records from the table
SELECT * FROM dbo.Talabaty; 
SELECT * FROM dbo.Talabaty_view;
GO

-- Ensure duplicate rows based on `order_id` are removed
WITH CTE AS (
    SELECT 
        order_id,
        ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY order_time) AS RowNum
    FROM 
        dbo.Talabaty
)
DELETE FROM CTE
WHERE RowNum > 1;
GO

-- Add new columns for date and time if they don't already exist
IF COL_LENGTH('dbo.Talabaty', 'order_date') IS NULL
BEGIN
    ALTER TABLE dbo.Talabaty
    ADD order_date DATE, order_time_only TIME;
END;
GO

-- Populate the new columns with split date and time from `order_time`
UPDATE dbo.Talabaty
SET 
    order_date = CAST(order_time AS DATE),   
    order_time_only = CAST(order_time AS TIME);  
GO

-- Drop the old `order_time` column if it exists
IF COL_LENGTH('dbo.Talabaty', 'order_time') IS NOT NULL
BEGIN
    ALTER TABLE dbo.Talabaty
    DROP COLUMN order_time;
END;
GO

-- Rename `order_time_only` to `order_time` for consistency
IF COL_LENGTH('dbo.Talabaty', 'order_time_only') IS NOT NULL
BEGIN
    EXEC sp_rename 'dbo.Talabaty.order_time_only', 'order_time', 'COLUMN';
END;
GO

-- Create or replace a view for `Talabaty`
IF OBJECT_ID('dbo.Talabaty_view', 'V') IS NOT NULL
    DROP VIEW dbo.Talabaty_view;
GO
CREATE OR ALTER VIEW dbo.Talabaty_view AS
SELECT 
    [order_id],
    [order_date], -- This column exists in your table
    [analytical_customer_id],
    [is_acquisition],
    [is_successful],
    [reason],
    [sub_reason],
    [owner],
    [delivery_arrangement],
    [gmv_amount_lc],
    [basket_amount_lc],
    [delivery_fee_amount_lc],
    [Payment_Method],
    [actual_delivery_time],
    [promised_delivery_time],
    [order_delay],
    [dropoff_distance_manhattan],
    [platform],
    [vertical_class],
    [vertical],
    [is_affordable_freedelivery],
    [is_affordable_item],
    [is_affordable_gem],
    [is_affordable_restaurant],
    [is_affordable_voucher],
    [is_affordable],
    [affordability_amt_total],
    [City]
FROM 
    dbo.Talabaty;
GO

-- Select data from the view
SELECT * FROM dbo.Talabaty_view;
GO

-- Analytical queries

-- Successful and failed orders
SELECT 
    CASE 
        WHEN is_successful = 1 THEN 'Successful' 
        ELSE 'Failed' 
    END AS order_status, 
    COUNT(*) AS order_count
FROM dbo.Talabaty
GROUP BY is_successful;
GO

-- Total revenue by month and year
SELECT 
    YEAR(order_date) AS year, 
    MONTH(order_date) AS month,
    SUM(CAST(gmv_amount_lc AS DECIMAL(18,2))) AS total_revenue
FROM dbo.Talabaty
WHERE ISNUMERIC(gmv_amount_lc) = 1 
GROUP BY YEAR(order_date), MONTH(order_date)
ORDER BY year, month;
GO

-- Total revenue by city
SELECT City, 
       SUM(CAST(gmv_amount_lc AS DECIMAL(18, 2))) AS total_revenue
FROM dbo.Talabaty
WHERE ISNUMERIC(gmv_amount_lc) = 1
GROUP BY City
ORDER BY total_revenue DESC;
GO

-- Delayed orders and average delay (exclude extreme delays)
SELECT City, 
       COUNT(*) AS delayed_orders,
       AVG(CAST(DATEDIFF(MINUTE, promised_delivery_time, actual_delivery_time) AS BIGINT)) AS avg_delay_minutes
FROM dbo.Talabaty
WHERE actual_delivery_time > promised_delivery_time
  AND DATEDIFF(MINUTE, promised_delivery_time, actual_delivery_time) BETWEEN 1 AND 1440 -- Between 1 minute and 1 day
GROUP BY City
ORDER BY avg_delay_minutes DESC;
GO

-- Revenue and order count by vertical
SELECT vertical,
       COUNT(*) AS total_orders,
       SUM(CAST(gmv_amount_lc AS DECIMAL(18, 2))) AS total_revenue
FROM dbo.Talabaty
WHERE ISNUMERIC(gmv_amount_lc) = 1
GROUP BY vertical
ORDER BY total_revenue DESC;
GO

-- Discount analysis
SELECT 
       SUM(CAST(affordability_amt_total AS DECIMAL(18, 2))) AS total_discounts,
       COUNT(*) AS orders_with_discount,
       SUM(CAST(gmv_amount_lc AS DECIMAL(18, 2))) AS total_revenue_with_discount
FROM dbo.Talabaty
WHERE ISNUMERIC(affordability_amt_total) = 1 
  AND CAST(affordability_amt_total AS DECIMAL(18, 2)) > 0;
GO

-- Orders by customer type (new vs returning)
SELECT 
    CASE 
        WHEN is_acquisition = 1 THEN 'New Customer'
        WHEN is_acquisition = 0 THEN 'Returning Customer'
        ELSE 'Unknown' 
    END AS customer_type,
    COUNT(*) AS total_orders,
    SUM(CAST(gmv_amount_lc AS DECIMAL(18, 2))) AS total_revenue
FROM dbo.Talabaty
WHERE ISNUMERIC(gmv_amount_lc) = 1
GROUP BY is_acquisition;
GO

-- Cities with highest average delays
SELECT City,
       COUNT(*) AS total_orders,
       AVG(CAST(DATEDIFF(MINUTE, promised_delivery_time, actual_delivery_time) AS BIGINT)) AS avg_delay_minutes
FROM dbo.Talabaty
WHERE actual_delivery_time > promised_delivery_time
GROUP BY City
ORDER BY avg_delay_minutes DESC;
GO

-- Average delivery fee and total delivery revenue
SELECT 
       AVG(CAST(delivery_fee_amount_lc AS DECIMAL(18, 2))) AS avg_delivery_fee,
       SUM(CAST(delivery_fee_amount_lc AS DECIMAL(18, 2))) AS total_delivery_revenue
FROM dbo.Talabaty
WHERE ISNUMERIC(delivery_fee_amount_lc) = 1;
GO

-- Top customers by revenue
SELECT TOP 10 analytical_customer_id,
       SUM(CAST(gmv_amount_lc AS DECIMAL(18, 2))) AS total_revenue,
       COUNT(*) AS total_orders
FROM dbo.Talabaty
WHERE ISNUMERIC(gmv_amount_lc) = 1
GROUP BY analytical_customer_id
ORDER BY total_revenue DESC;
GO

-- Revenue Growth by Month 
SELECT 
    YEAR(order_date) AS year, 
    MONTH(order_date) AS month,
    SUM(CAST(gmv_amount_lc AS DECIMAL(18, 2))) AS total_revenue
FROM dbo.Talabaty
WHERE ISNUMERIC(gmv_amount_lc) = 1
GROUP BY YEAR(order_date), MONTH(order_date)
ORDER BY year, month;
GO
