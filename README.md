# AWS-ETL-Data-Pipeline-and-Analysis-for-Online-Sales-Data

## Overview
Excited to share my latest AWS project - an ETL data pipeline for analyzing online sales data! 🎉 This project  demonstrates how to efficiently process and analyze sales data using various AWS services.

## Architecture
Here's a high-level overview of the architecture:
1. **Data Source**: CSV files stored in Amazon S3.
2. **Data Catalog**: AWS Glue Crawler scans the data and updates the AWS Glue Data Catalog.
3. **ETL Processing**: AWS Glue Jobs perform the ETL (Extract, Transform, Load) operations.
4. **Transformed Data Storage**: The transformed data is stored back in Amazon S3.
5. **Data Warehousing**: Data is then moved to Amazon Redshift for high-performance querying.
6. **Data Exploration**: Amazon Redshift Query Editor v2.0 is used for data exploration and analysis.
7. **Security**: All components are within a secure VPC to ensure data security.
<img width="724" alt="Screenshot 2024-07-27 at 12 36 38 am" src="https://github.com/user-attachments/assets/5c30a8e5-204b-40dc-973b-2e3f925eba59">



## Features
- **Automated Data Ingestion**: Automatically ingest CSV files from S3.
- **Data Cataloging**: Use AWS Glue Crawler to catalog data.
- **ETL Processing**: Transform data using AWS Glue Jobs.
- **Data Storage**: Store transformed data in S3 and Redshift.
- **High-Performance Querying**: Utilize Amazon Redshift for efficient data querying.
- **Secure Environment**: All operations are performed within a secure VPC.

## Getting Started
### Prerequisites
- AWS Account
- IAM roles with necessary permissions for S3, Glue, and Redshift
- Amazon S3 bucket for storing raw and transformed data
- Amazon Redshift cluster

### Setup Instructions
1. **Upload CSV Files to S3**: Place your CSV files in the designated S3 bucket.
2. **Configure AWS Glue Crawler**: Set up a Glue Crawler to scan the S3 bucket and update the Glue Data Catalog.
3. **Create AWS Glue Jobs**: Define and run Glue Jobs to perform the ETL operations.
4. **Store Transformed Data**: Ensure the transformed data is stored back in S3.
5. **Load Data into Redshift**: Use Redshift COPY commands to load data from S3 into Redshift tables.
6. **Query Data**: Use Redshift Query Editor v2.0 to explore and analyze the data.

## Insights and Analysis
### 1. Average Revenue per Transaction for Each Product Category, by Region
**Why**: Helps identify valuable product categories in different regions, guiding inventory management, marketing strategies, and resource allocation.

**SQL Query**:
```sql
 SELECT 
    "region",
    "product category",
    ROUND(AVG("total revenue")) as avg_revenue_per_transaction
FROM 
    "dev"."public"."sales"
GROUP BY 
    "region", "product category"
ORDER BY 
    avg_revenue_per_transaction DESC;
```

### 2. Most Common Payment Method for High-Value Transactions, by Region
**Why**: Informs payment processing strategies, helps negotiate better rates with payment providers, and improves the checkout experience for valuable customers.

**SQL Query**:
```sql
-- 2. Most common payment method for high-value transactions, by region
WITH high_value_transactions AS (
    SELECT *
    FROM "dev"."public"."sales"
    WHERE "total revenue" > (SELECT PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY "total revenue") FROM "dev"."public"."sales")
)
SELECT 
    "region",
    "payment method",
    COUNT(*) as transaction_count
FROM 
    high_value_transactions
GROUP BY 
    "region", "payment method"
HAVING 
    COUNT(*) = (
        SELECT MAX(transaction_count)
        FROM (
            SELECT "region", "payment method", COUNT(*) as transaction_count
            FROM high_value_transactions
            GROUP BY "region", "payment method"
        )
        WHERE "region" = high_value_transactions."region"
    )
ORDER BY 
    "region";
```

### 3. Percentage Contribution of Each Product Category to Total Revenue, Month-over-Month
**Why**: Reveals shifts in product category performance over time, informing product development, marketing focus, and long-term business strategy.

**SQL Query**:
```sql
-- 3. Percentage contribution of each product category to total revenue, month-over-month:
WITH "monthly_revenue" AS (
    SELECT 
        DATE_TRUNC('month', "date"::date) AS "month",
        "product category",
        SUM("total revenue") AS "category_revenue"
    FROM 
        "dev"."public"."sales"
    GROUP BY 
        DATE_TRUNC('month', "date"::date), "product category"
),
"total_monthly_revenue" AS (
    SELECT 
        "month",
        SUM("category_revenue") AS "total_revenue"
    FROM 
        "monthly_revenue"
    GROUP BY 
        "month"
)
SELECT 
    "mr"."month",
    "mr"."product category",
    ROUND("mr"."category_revenue") AS "category_revenue",
    ROUND("tmr"."total_revenue") AS "total_revenue",
    ROUND(("mr"."category_revenue" / NULLIF("tmr"."total_revenue", 0)) * 100) AS "percentage_contribution",
    ROUND(("mr"."category_revenue" / NULLIF("tmr"."total_revenue", 0)) * 100 - 
    LAG(("mr"."category_revenue" / NULLIF("tmr"."total_revenue", 0)) * 100) OVER (PARTITION BY "mr"."product category" ORDER BY "mr"."month")) AS "month_over_month_change"
FROM 
    "monthly_revenue" "mr"
JOIN 
    "total_monthly_revenue" "tmr" ON "mr"."month" = "tmr"."month"
ORDER BY 
    "mr"."month", "percentage_contribution" DESC;
```

```sql
-- What is the trend of total revenue on a monthly basis or by product category ?
SELECT DATE_TRUNC('month', "date") AS month, round(SUM("total revenue")) AS "total_revenue", "product category"
FROM "dev"."public"."sales"
GROUP BY "month", "product category"
ORDER BY "month";
```

<img width="1032" alt="Screenshot 2024-07-27 at 12 35 59 am" src="https://github.com/user-attachments/assets/5bbe3656-7006-451f-923b-9ff8dffdc2a1">


### 4. Average Basket Size and Total Value for Transactions, by Payment Method
**Why**: Understands customer purchasing behavior across different payment methods, informing strategies for upselling, cross-selling, and optimizing payment options.

**SQL Query**:
```sql
-- Average basket size and total value for transactions by payment method:
SELECT 
    "payment method",
    ROUND(AVG("units sold")) as avg_basket_size,
    ROUND(AVG("total revenue")) as avg_basket_value
FROM 
    "dev"."public"."sales"
GROUP BY 
    "payment method"
ORDER BY 
    avg_basket_value DESC;
```

### 5. Average Time Between Purchases for Repeat Customers
**Why**: Helps develop targeted retention strategies, timing for follow-up marketing, and understanding product repurchase cycles.

**SQL Query**:
```sql
WITH customer_purchases AS (
    SELECT 
        "transaction id",
        "date",
        "product category",
        "region",
        LAG("date") OVER (PARTITION BY "transaction id" ORDER BY "date") as previous_purchase_date
    FROM 
        "dev"."public"."sales"
)
SELECT 
    "product category",
    "region",
    AVG(DATEDIFF(day, previous_purchase_date, "date")) as avg_days_between_purchases
FROM 
    customer_purchases
WHERE 
    previous_purchase_date IS NOT NULL
GROUP BY 
    "product category", "region"
ORDER BY 
    "product category", avg_days_between_purchases;
```

### 6. Top 5 Products by Revenue in Each Region and Their Market Share
**Why**: Identifies top-performing products in each region, helping focus marketing efforts, optimize inventory, and understand regional preferences.

**SQL Query**:
```sql
WITH product_revenue AS (
    SELECT 
        "region",
        "product name",
        "product category",
        ROUND(SUM("total revenue")) as product_revenue,
        ROUND(SUM(SUM("total revenue")) OVER (PARTITION BY "region", "product category")) as category_revenue,
        ROW_NUMBER() OVER (PARTITION BY "region" ORDER BY SUM("total revenue") DESC) as revenue_rank
    FROM 
        "dev"."public"."sales"
    GROUP BY 
        "region", "product name", "product category"
)
SELECT 
    "region",
    "product name",
    "product category",
    product_revenue,
    ROUND((product_revenue / category_revenue) * 100) as market_share_percentage
FROM 
    product_revenue
WHERE 
    revenue_rank <= 5
ORDER BY 
    "region", revenue_rank;
```

### 7. Impact of Promotions or Discounts on Total Revenue
**Why**: Evaluates the effectiveness of pricing strategies and promotions, informing decisions on discount levels and optimizing pricing for profitability.

**SQL Query**:
```sql
-- Impact of promotions or discounts on total revenue
WITH product_avg_price AS (
    SELECT 
        "product name",
        AVG("unit price") as avg_unit_price
    FROM 
        "dev"."public"."sales"
    GROUP BY 
        "product name"
)
SELECT 
    s."product name",
    s."unit price",
    pap.avg_unit_price,
    ROUND(((pap.avg_unit_price - s."unit price") / pap.avg_unit_price) * 100) as discount_percentage,
    s."total revenue",
    ROUND(AVG(s."total revenue") OVER (PARTITION BY s."product name")) as avg_product_revenue,
    s."total revenue" - AVG(s."total revenue") OVER (PARTITION BY s."product name") as revenue_difference
FROM 
    "dev"."public"."sales" s
JOIN 
    product_avg_price pap ON s."product name" = pap."product name"
WHERE 
    s."unit price" < pap.avg_unit_price
ORDER BY 
    discount_percentage DESC, revenue_difference DESC;
```

### 8. Customer Lifetime Value (CLV) for Different Customer Segments
**Why**: Informs customer segmentation, targeting high-value customers, and allocating marketing budgets, guiding expansion strategies and resource allocation.

**SQL Query**:
```sql
-- Customer lifetime value (CLV) for different customer segments
WITH customer_purchases AS (
    SELECT 
        "transaction id",
        "region",
        SUM("total revenue") as total_spend,
        COUNT(DISTINCT "date") as purchase_frequency,
        DATEDIFF(day, MIN("date"), MAX("date")) as customer_lifespan
    FROM 
        "dev"."public"."sales"
    GROUP BY 
        "transaction id", "region"
)
SELECT 
    "region",
    AVG(total_spend) as avg_customer_value,
    AVG(purchase_frequency) as avg_purchase_frequency,
    AVG(customer_lifespan) as avg_customer_lifespan,
    AVG(total_spend) * AVG(purchase_frequency) / NULLIF(AVG(customer_lifespan), 0) as estimated_daily_clv,
    (AVG(total_spend) * AVG(purchase_frequency) / NULLIF(AVG(customer_lifespan), 0)) * 365 as estimated_annual_clv
FROM 
    customer_purchases
GROUP BY 
    "region"
ORDER BY 
    estimated_annual_clv DESC;
```

## Future Improvements
- Redirecting transformed data directly to Redshift to optimize the ETL process.
- Scaling the project for other problems and different bigger datasets.

## Conclusion
This project has been a great learning experience, and I look forward to sharing more insights. 

## Contact
For any questions or feedback, feel free to reach out!

---

Thank you for checking out my project! If you found this useful, please give it a star ⭐ on GitHub!
