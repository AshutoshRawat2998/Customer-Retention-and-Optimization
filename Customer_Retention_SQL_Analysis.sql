USE EcommerceDB








-- Module 1: High-Level Executive KPIs
SELECT 
    COUNT(customer_id) AS Total_Customer_Base,
    
    -- Cast to FLOAT/DECIMAL to avoid integer division truncation
    ROUND(CAST(SUM(CASE WHEN churn = 1 THEN 1 ELSE 0 END) AS FLOAT) / COUNT(customer_id) * 100, 2) AS Baseline_Churn_Rate_Pct,
    
    -- Derived metrics from explicit arithmetic
    SUM(CAST(total_orders AS BIGINT) * CAST(avg_order_value AS BIGINT)) AS Total_Revenue_Generated,
    
    ROUND(AVG(CAST(tenure_months AS FLOAT)), 2) AS Avg_Customer_Tenure_Months,
    ROUND(AVG(CAST(support_tickets AS FLOAT)), 2) AS Avg_Support_Tickets_Per_Customer
FROM dbo.customer_churn;



-- Query 2A: Geographic Cohort Risk Analysis
SELECT 
    city,
    COUNT(customer_id) AS Customer_Count,
    SUM(CAST(total_orders AS BIGINT) * CAST(avg_order_value AS BIGINT)) AS Total_Revenue,
    ROUND(CAST(SUM(CASE WHEN churn = 1 THEN 1 ELSE 0 END) AS FLOAT) / COUNT(customer_id) * 100, 2) AS Churn_Rate_Pct
FROM dbo.customer_churn
GROUP BY city
ORDER BY Churn_Rate_Pct DESC;

-- Query 2B: Dynamic Age Segmentation Risk Analysis
WITH SegmentedAgeData AS (
    SELECT 
        CAST(churn AS INT) AS Is_Churned,
        CASE 
            WHEN age <= 25 THEN '18-25'
            WHEN age <= 35 THEN '26-35'
            WHEN age <= 50 THEN '36-50'
            ELSE '51+' 
        END AS Age_Bucket -- Simplified logic checks sequentially from left-to-right
    FROM dbo.customer_churn
    WHERE age >= 18 -- Filters out bad data early if it exists
)
SELECT 
    Age_Bucket,
    COUNT(1) AS Customer_Count,
    ROUND((SUM(Is_Churned) * 100.0) / COUNT(1), 2) AS Churn_Rate_Pct
FROM SegmentedAgeData
GROUP BY Age_Bucket
ORDER BY Age_Bucket ASC;







-- Query 3A: Customer Support Friction Impact Analysis
SELECT 
    CASE 
        WHEN support_tickets = 0 THEN '0 Tickets'
        WHEN support_tickets BETWEEN 1 AND 5 THEN '1-5 Tickets'
        WHEN support_tickets BETWEEN 6 AND 15 THEN '6-15 Tickets'
        WHEN support_tickets BETWEEN 16 AND 30 THEN '16-30 Tickets'
        WHEN support_tickets > 30 THEN '31+'
    END AS Support_Ticket_Bucket,
    COUNT(customer_id) AS Customer_Count,
    ROUND(CAST(SUM(CASE WHEN churn = 1 THEN 1 ELSE 0 END) AS FLOAT) / COUNT(customer_id) * 100, 2) AS Churn_Rate_Pct
FROM dbo.customer_churn
GROUP BY 
    CASE 
        WHEN support_tickets = 0 THEN '0 Tickets'
        WHEN support_tickets BETWEEN 1 AND 5 THEN '1-5 Tickets'
        WHEN support_tickets BETWEEN 6 AND 15 THEN '6-15 Tickets'
        WHEN support_tickets BETWEEN 16 AND 30 THEN '16-30 Tickets'
        WHEN support_tickets > 30 THEN '31+'
    END
ORDER BY MIN(support_tickets) ASC; -- Ensures mathematical logical ordering in output

-- Query 3B: Inactivity/Recency Risk Banding
SELECT 
    CASE 
        WHEN last_purchase_days_ago BETWEEN 0 AND 30 THEN '0-30 Days'
        WHEN last_purchase_days_ago BETWEEN 31 AND 90 THEN '31-90 Days'
        WHEN last_purchase_days_ago BETWEEN 91 AND 180 THEN '91-180 Days'
        WHEN last_purchase_days_ago BETWEEN 181 AND 365 THEN '181-365 Days'
        WHEN last_purchase_days_ago > 365 THEN '365+ Days'
    END AS Recency_Band,
    COUNT(customer_id) AS Customer_Count,
    ROUND(CAST(SUM(CASE WHEN churn = 1 THEN 1 ELSE 0 END) AS FLOAT) / COUNT(customer_id) * 100, 2) AS Churn_Rate_Pct
FROM dbo.customer_churn
GROUP BY 
    CASE 
        WHEN last_purchase_days_ago BETWEEN 0 AND 30 THEN '0-30 Days'
        WHEN last_purchase_days_ago BETWEEN 31 AND 90 THEN '31-90 Days'
        WHEN last_purchase_days_ago BETWEEN 91 AND 180 THEN '91-180 Days'
        WHEN last_purchase_days_ago BETWEEN 181 AND 365 THEN '181-365 Days'
        WHEN last_purchase_days_ago > 365 THEN '365+ Days'
    END
ORDER BY MIN(last_purchase_days_ago) ASC;




-- Query 4A: Product Subscription Tier Value & Attrition Profiling
SELECT 
    subscription_type,
    COUNT(customer_id) AS Total_Volume,
    ROUND(AVG(CAST(total_orders AS FLOAT) * CAST(avg_order_value AS FLOAT)), 2) AS Avg_Total_Spending,
    ROUND(AVG(CAST(tenure_months AS FLOAT)), 2) AS Avg_Tenure_Months,
    ROUND(CAST(SUM(CASE WHEN churn = 1 THEN 1 ELSE 0 END) AS FLOAT) / COUNT(customer_id) * 100, 2) AS Tier_Churn_Rate_Pct
FROM dbo.customer_churn
GROUP BY subscription_type
ORDER BY Tier_Churn_Rate_Pct DESC;

-- Query 4B: "High Value-High Risk" Marketing Target Extraction
WITH RankedSpenders AS (
    SELECT 
        customer_id,
        age,
        gender,
        city,
        tenure_months,
        subscription_type,
        last_purchase_days_ago,
        support_tickets,
        (CAST(total_orders AS BIGINT) * CAST(avg_order_value AS BIGINT)) AS Total_Spend,
        churn,
        -- Calculate financial percentile across the whole customer database
        PERCENT_RANK() OVER (ORDER BY (CAST(total_orders AS BIGINT) * CAST(avg_order_value AS BIGINT)) ASC) AS Spend_Percentile
    FROM dbo.customer_churn
)
SELECT 
    customer_id,
    age,
    gender,
    city,
    subscription_type,
    tenure_months,
    Total_Spend,
    last_purchase_days_ago,
    support_tickets
FROM RankedSpenders
WHERE Spend_Percentile >= 0.75             -- Top 25% of spenders
  AND last_purchase_days_ago > 180         -- Inactive for more than half a year
  AND churn = 0                             -- Has not yet off-boarded / canceled
ORDER BY Total_Spend DESC, last_purchase_days_ago DESC;




