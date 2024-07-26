-- 1. Average revenue per transaction for each product category, by region:
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

-- What is the average number of units sold per transaction by product category?
SELECT "product category", ROUND(AVG("units sold")) AS average_units_sold
FROM "dev"."public"."sales"
GROUP BY "product category"
ORDER BY "average_units_sold" DESC;

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

-- Which payment methods are most frequently used?
SELECT "payment method", COUNT(*) AS frequency
FROM "dev"."public"."sales"
GROUP BY "payment method"
ORDER BY "frequency" DESC;

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


-- 4. What is the trend of total revenue on a monthly basis or by product category ?
SELECT DATE_TRUNC('month', "date") AS month, round(SUM("total revenue")) AS "total_revenue", "product category"
FROM "dev"."public"."sales"
GROUP BY "month", "product category"
ORDER BY "month";


-- 5. Average basket size and total value for transactions by payment method:
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


-- 6. Average time between purchases for repeat customers
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
    "product category", avg_days_between_purchases;-- Average time between purchases for repeat customers
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




-- 7. Impact of promotions or discounts on total revenue
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



--  8.Customer lifetime value (CLV) for different customer segments
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
