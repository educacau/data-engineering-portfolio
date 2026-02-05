-- Regional Performance Comparison
-- Analyze revenue, customer behavior, and product preferences by region

WITH regional_metrics AS (
    SELECT
        region,
        COUNT(DISTINCT order_id) as total_orders,
        COUNT(DISTINCT customer_id) as unique_customers,
        SUM(total_amount) as total_revenue,
        AVG(total_amount) as avg_order_value,
        SUM(discount_amount) as total_discounts,
        ROUND(SUM(discount_amount) / NULLIF(SUM(total_amount + discount_amount), 0) * 100, 2) as discount_rate_pct,
        -- Status breakdown
        COUNT(DISTINCT CASE WHEN status = 'completed' THEN order_id END) as completed_orders,
        COUNT(DISTINCT CASE WHEN status = 'cancelled' THEN order_id END) as cancelled_orders,
        ROUND(COUNT(CASE WHEN status = 'cancelled' THEN 1 END) * 100.0 / COUNT(*), 2) as cancellation_rate_pct,
        -- Payment preferences
        COUNT(CASE WHEN payment_method = 'credit_card' THEN 1 END) as credit_card_orders,
        COUNT(CASE WHEN payment_method = 'paypal' THEN 1 END) as paypal_orders,
        -- New vs. returning
        COUNT(CASE WHEN is_first_purchase THEN 1 END) as first_time_buyers,
        ROUND(COUNT(CASE WHEN is_first_purchase THEN 1 END) * 100.0 / COUNT(*), 2) as new_customer_pct
    FROM iceberg.db.orders
    WHERE order_date >= CURRENT_DATE - INTERVAL '30' DAY
    GROUP BY region
),
regional_products AS (
    SELECT
        o.region,
        p.category,
        COUNT(*) as category_orders,
        ROW_NUMBER() OVER (PARTITION BY o.region ORDER BY COUNT(*) DESC) as category_rank
    FROM iceberg.db.orders o
    JOIN iceberg.db.products p ON o.product_id = p.product_id
    WHERE o.order_date >= CURRENT_DATE - INTERVAL '30' DAY
      AND o.status = 'completed'
    GROUP BY o.region, p.category
)
SELECT
    m.region,
    m.total_orders,
    m.unique_customers,
    ROUND(m.total_orders * 1.0 / m.unique_customers, 2) as orders_per_customer,
    m.total_revenue,
    m.avg_order_value,
    m.discount_rate_pct,
    m.cancellation_rate_pct,
    m.new_customer_pct,
    -- Top category per region
    (SELECT category FROM regional_products rp WHERE rp.region = m.region AND category_rank = 1) as top_category,
    -- Payment method distribution
    ROUND(m.credit_card_orders * 100.0 / m.total_orders, 2) as credit_card_pct,
    ROUND(m.paypal_orders * 100.0 / m.total_orders, 2) as paypal_pct,
    -- Revenue share
    ROUND(m.total_revenue / SUM(m.total_revenue) OVER () * 100, 2) as pct_of_total_revenue,
    -- Performance rank
    RANK() OVER (ORDER BY m.total_revenue DESC) as revenue_rank
FROM regional_metrics m
ORDER BY m.total_revenue DESC;

-- Regional growth trends
-- SELECT
--     DATE_TRUNC('week', order_date) as week,
--     region,
--     SUM(total_amount) as weekly_revenue,
--     LAG(SUM(total_amount), 1) OVER (PARTITION BY region ORDER BY DATE_TRUNC('week', order_date)) as prev_week_revenue,
--     ROUND((SUM(total_amount) - LAG(SUM(total_amount), 1) OVER (PARTITION BY region ORDER BY DATE_TRUNC('week', order_date)))
--         / NULLIF(LAG(SUM(total_amount), 1) OVER (PARTITION BY region ORDER BY DATE_TRUNC('week', order_date)), 0) * 100, 2) as wow_growth_pct
-- FROM iceberg.db.orders
-- WHERE status = 'completed'
--   AND order_date >= CURRENT_DATE - INTERVAL '12' WEEK
-- GROUP BY DATE_TRUNC('week', order_date), region
-- ORDER BY week DESC, weekly_revenue DESC;
