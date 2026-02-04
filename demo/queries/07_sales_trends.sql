-- Sales Trends: Seasonal Patterns and Growth Analysis
-- Analyze revenue trends, seasonality, and growth metrics

-- Weekly revenue trends with moving averages
WITH weekly_sales AS (
    SELECT
        DATE_TRUNC('week', order_date) as week_start,
        COUNT(DISTINCT order_id) as orders,
        COUNT(DISTINCT customer_id) as customers,
        SUM(total_amount) as revenue,
        AVG(total_amount) as avg_order_value,
        SUM(discount_amount) as discounts
    FROM iceberg.db.orders
    WHERE status = 'completed'
      AND order_date >= CURRENT_DATE - INTERVAL '6' MONTH
    GROUP BY DATE_TRUNC('week', order_date)
)
SELECT
    DATE_FORMAT(week_start, '%Y-%m-%d') as week,
    orders,
    customers,
    revenue,
    avg_order_value,
    -- Week-over-week growth
    LAG(revenue, 1) OVER (ORDER BY week_start) as prev_week_revenue,
    ROUND((revenue - LAG(revenue, 1) OVER (ORDER BY week_start))
        / NULLIF(LAG(revenue, 1) OVER (ORDER BY week_start), 0) * 100, 2) as wow_growth_pct,
    -- 4-week moving average
    ROUND(AVG(revenue) OVER (ORDER BY week_start ROWS BETWEEN 3 PRECEDING AND CURRENT ROW), 2) as revenue_4wk_ma,
    -- Discount rate
    ROUND(discounts / NULLIF(revenue + discounts, 0) * 100, 2) as discount_rate_pct
FROM weekly_sales
ORDER BY week_start DESC;

-- Seasonal comparison: Q4 vs. other quarters
-- WITH quarterly_sales AS (
--     SELECT
--         YEAR(order_date) as year,
--         QUARTER(order_date) as quarter,
--         SUM(total_amount) as revenue,
--         COUNT(*) as orders,
--         AVG(total_amount) as avg_order_value
--     FROM iceberg.db.orders
--     WHERE status = 'completed'
--       AND order_date >= CURRENT_DATE - INTERVAL '2' YEAR
--     GROUP BY YEAR(order_date), QUARTER(order_date)
-- )
-- SELECT
--     year,
--     quarter,
--     revenue,
--     orders,
--     avg_order_value,
--     -- Q4 holiday spike
--     CASE WHEN quarter = 4 THEN 'Q4 (Holiday Season)' ELSE 'Other' END as season_type,
--     ROUND(revenue / SUM(revenue) OVER (PARTITION BY year) * 100, 2) as pct_of_annual_revenue
-- FROM quarterly_sales
-- ORDER BY year DESC, quarter DESC;
