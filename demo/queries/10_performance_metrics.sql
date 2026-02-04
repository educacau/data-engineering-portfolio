-- Performance Benchmarking Queries
-- Validate p95 latency < 1 second requirement

-- Simple SELECT (point lookup by order_id)
-- Expected: < 50ms
SELECT *
FROM iceberg.db.orders
WHERE order_id = 12345;

-- Date range scan (1 day of data)
-- Expected: < 200ms (tests partition pruning)
SELECT
    COUNT(*) as order_count,
    SUM(total_amount) as daily_revenue,
    AVG(total_amount) as avg_order_value
FROM iceberg.db.orders
WHERE order_date = CURRENT_DATE - INTERVAL '1' DAY;

-- Aggregation (monthly rollup)
-- Expected: < 800ms
SELECT
    DATE_TRUNC('month', order_date) as month,
    region,
    status,
    COUNT(*) as orders,
    SUM(total_amount) as revenue,
    AVG(total_amount) as avg_order_value
FROM iceberg.db.orders
WHERE order_date >= CURRENT_DATE - INTERVAL '12' MONTH
GROUP BY DATE_TRUNC('month', order_date), region, status
ORDER BY month DESC, revenue DESC;

-- JOIN query (orders + customers)
-- Expected: < 1.2s
SELECT
    c.region,
    c.customer_id,
    c.first_name,
    c.last_name,
    COUNT(o.order_id) as order_count,
    SUM(o.total_amount) as total_spent,
    MAX(o.order_date) as last_order_date
FROM iceberg.db.customers c
JOIN iceberg.db.orders o ON c.customer_id = o.customer_id
WHERE o.status = 'completed'
  AND o.order_date >= CURRENT_DATE - INTERVAL '30' DAY
GROUP BY c.region, c.customer_id, c.first_name, c.last_name
HAVING COUNT(o.order_id) >= 3
ORDER BY total_spent DESC
LIMIT 50;

-- Complex analytical query (window functions + CTEs)
-- Expected: < 2s
WITH customer_cohorts AS (
    SELECT
        customer_id,
        DATE_TRUNC('month', MIN(order_date)) as cohort_month,
        DATE_TRUNC('month', order_date) as order_month,
        SUM(total_amount) as cohort_revenue
    FROM iceberg.db.orders
    WHERE status = 'completed'
      AND order_date >= CURRENT_DATE - INTERVAL '6' MONTH
    GROUP BY customer_id, DATE_TRUNC('month', order_date)
)
SELECT
    DATE_FORMAT(cohort_month, '%Y-%m') as cohort,
    DATE_FORMAT(order_month, '%Y-%m') as order_month,
    COUNT(DISTINCT customer_id) as active_customers,
    SUM(cohort_revenue) as revenue,
    ROUND(AVG(cohort_revenue), 2) as avg_revenue_per_customer,
    -- Months since cohort start
    MONTH(order_month) - MONTH(cohort_month) +
        (YEAR(order_month) - YEAR(cohort_month)) * 12 as months_since_cohort
FROM customer_cohorts
GROUP BY cohort_month, order_month
ORDER BY cohort_month DESC, order_month DESC;

-- Table statistics (metadata query)
-- Expected: < 100ms
SELECT
    'orders' as table_name,
    COUNT(*) as record_count,
    COUNT(DISTINCT customer_id) as unique_customers,
    COUNT(DISTINCT product_id) as unique_products,
    MIN(order_date) as earliest_order,
    MAX(order_date) as latest_order,
    SUM(total_amount) as total_revenue
FROM iceberg.db.orders

UNION ALL

SELECT
    'customers' as table_name,
    COUNT(*) as record_count,
    NULL as unique_customers,
    NULL as unique_products,
    MIN(registration_date) as earliest_date,
    MAX(registration_date) as latest_date,
    SUM(lifetime_value) as total_ltv
FROM iceberg.db.customers

UNION ALL

SELECT
    'products' as table_name,
    COUNT(*) as record_count,
    COUNT(DISTINCT category) as unique_categories,
    NULL as unique_products,
    NULL as earliest_date,
    NULL as latest_date,
    SUM(base_price) as total_catalog_value
FROM iceberg.db.products;
