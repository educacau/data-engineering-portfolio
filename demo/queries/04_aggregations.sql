-- Daily and Monthly Revenue Aggregations
-- Demonstrates partition pruning and aggregation performance

-- Daily revenue by region (last 30 days)
SELECT
    order_date,
    region,
    COUNT(DISTINCT order_id) as orders,
    COUNT(DISTINCT customer_id) as unique_customers,
    SUM(total_amount) as revenue,
    AVG(total_amount) as avg_order_value,
    SUM(discount_amount) as total_discounts,
    SUM(CASE WHEN is_first_purchase THEN 1 ELSE 0 END) as new_customers
FROM iceberg.db.orders
WHERE order_date >= CURRENT_DATE - INTERVAL '30' DAY
  AND status = 'completed'
GROUP BY order_date, region
ORDER BY order_date DESC, revenue DESC;

-- Monthly rollup with year-over-year comparison
-- WITH monthly_revenue AS (
--     SELECT
--         DATE_TRUNC('month', order_date) as month,
--         region,
--         SUM(total_amount) as revenue,
--         COUNT(*) as orders
--     FROM iceberg.db.orders
--     WHERE status = 'completed'
--       AND order_date >= CURRENT_DATE - INTERVAL '24' MONTH
--     GROUP BY DATE_TRUNC('month', order_date), region
-- )
-- SELECT
--     DATE_FORMAT(month, '%Y-%m') as month,
--     region,
--     revenue as current_revenue,
--     LAG(revenue, 12) OVER (PARTITION BY region ORDER BY month) as yoy_revenue,
--     ROUND((revenue - LAG(revenue, 12) OVER (PARTITION BY region ORDER BY month))
--         / LAG(revenue, 12) OVER (PARTITION BY region ORDER BY month) * 100, 2) as yoy_growth_pct
-- FROM monthly_revenue
-- WHERE month >= CURRENT_DATE - INTERVAL '12' MONTH
-- ORDER BY month DESC, region;
