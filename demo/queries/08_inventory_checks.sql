-- Inventory Analysis: Product Demand and Stock Levels
-- Monitor product velocity and identify restocking needs

WITH product_velocity AS (
    SELECT
        p.product_id,
        p.product_name,
        p.category,
        p.subcategory,
        COUNT(DISTINCT o.order_id) as orders_last_30d,
        SUM(o.quantity) as units_sold_last_30d,
        AVG(o.quantity) as avg_quantity_per_order,
        -- Daily velocity
        ROUND(SUM(o.quantity) / 30.0, 2) as avg_daily_units,
        -- Revenue metrics
        SUM(o.total_amount) as revenue_last_30d,
        -- Pricing
        p.base_price,
        AVG(o.unit_price) as avg_selling_price,
        ROUND((AVG(o.unit_price) - p.base_price) / p.base_price * 100, 2) as avg_price_variance_pct
    FROM iceberg.db.products p
    LEFT JOIN iceberg.db.orders o ON p.product_id = o.product_id
        AND o.order_date >= CURRENT_DATE - INTERVAL '30' DAY
        AND o.status = 'completed'
    GROUP BY p.product_id, p.product_name, p.category, p.subcategory, p.base_price
)
SELECT
    product_id,
    product_name,
    category,
    subcategory,
    orders_last_30d,
    units_sold_last_30d,
    avg_daily_units,
    revenue_last_30d,
    base_price,
    avg_selling_price,
    avg_price_variance_pct,
    -- Velocity classification
    CASE
        WHEN avg_daily_units >= 10 THEN 'Fast-moving'
        WHEN avg_daily_units >= 3 THEN 'Medium-moving'
        WHEN avg_daily_units >= 1 THEN 'Slow-moving'
        ELSE 'Stagnant'
    END as velocity_class,
    -- Estimated days to stockout (assuming 100 units in stock)
    CASE
        WHEN avg_daily_units > 0 THEN ROUND(100 / avg_daily_units, 0)
        ELSE NULL
    END as estimated_days_to_stockout
FROM product_velocity
ORDER BY avg_daily_units DESC, revenue_last_30d DESC;

-- Dead stock analysis
-- SELECT
--     p.product_id,
--     p.product_name,
--     p.category,
--     MAX(o.order_date) as last_sale_date,
--     CURRENT_DATE - MAX(o.order_date) as days_since_last_sale
-- FROM iceberg.db.products p
-- LEFT JOIN iceberg.db.orders o ON p.product_id = o.product_id
--     AND o.status = 'completed'
-- GROUP BY p.product_id, p.product_name, p.category
-- HAVING MAX(o.order_date) < CURRENT_DATE - INTERVAL '90' DAY
--     OR MAX(o.order_date) IS NULL
-- ORDER BY days_since_last_sale DESC NULLS FIRST;
