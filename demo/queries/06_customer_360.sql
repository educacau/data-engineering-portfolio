-- Customer 360: Comprehensive Customer Profile
-- Build a complete view of customer behavior and preferences

WITH customer_metrics AS (
    SELECT
        o.customer_id,
        COUNT(DISTINCT o.order_id) as total_orders,
        COUNT(DISTINCT CASE WHEN o.status = 'completed' THEN o.order_id END) as completed_orders,
        COUNT(DISTINCT CASE WHEN o.status = 'cancelled' THEN o.order_id END) as cancelled_orders,
        COUNT(DISTINCT CASE WHEN o.status = 'refunded' THEN o.order_id END) as refunded_orders,
        SUM(CASE WHEN o.status = 'completed' THEN o.total_amount ELSE 0 END) as total_revenue,
        AVG(CASE WHEN o.status = 'completed' THEN o.total_amount END) as avg_order_value,
        MIN(o.order_date) as first_order_date,
        MAX(o.order_date) as last_order_date,
        COUNT(DISTINCT o.product_id) as unique_products,
        MAX(o.order_date) - MIN(o.order_date) as customer_tenure_days,
        -- Recency, Frequency, Monetary (RFM) components
        CURRENT_DATE - MAX(o.order_date) as recency_days,
        COUNT(DISTINCT o.order_id) as frequency,
        SUM(CASE WHEN o.status = 'completed' THEN o.total_amount ELSE 0 END) as monetary
    FROM iceberg.db.orders o
    GROUP BY o.customer_id
),
customer_preferences AS (
    SELECT
        o.customer_id,
        -- Most purchased category
        (SELECT p.category
         FROM iceberg.db.orders o2
         JOIN iceberg.db.products p ON o2.product_id = p.product_id
         WHERE o2.customer_id = o.customer_id
           AND o2.status = 'completed'
         GROUP BY p.category
         ORDER BY COUNT(*) DESC
         LIMIT 1) as favorite_category,
        -- Preferred payment method
        (SELECT payment_method
         FROM iceberg.db.orders o3
         WHERE o3.customer_id = o.customer_id
         GROUP BY payment_method
         ORDER BY COUNT(*) DESC
         LIMIT 1) as preferred_payment
    FROM iceberg.db.orders o
    GROUP BY o.customer_id
)
SELECT
    c.customer_id,
    c.first_name,
    c.last_name,
    c.email,
    c.region,
    c.registration_date,
    m.total_orders,
    m.completed_orders,
    m.cancelled_orders,
    ROUND(m.cancelled_orders * 100.0 / NULLIF(m.total_orders, 0), 2) as cancellation_rate_pct,
    m.total_revenue,
    m.avg_order_value,
    m.first_order_date,
    m.last_order_date,
    m.recency_days,
    m.unique_products,
    p.favorite_category,
    p.preferred_payment,
    -- Customer segment based on RFM
    CASE
        WHEN m.recency_days <= 30 AND m.frequency >= 5 AND m.monetary >= 1000 THEN 'Champions'
        WHEN m.recency_days <= 60 AND m.frequency >= 3 THEN 'Loyal Customers'
        WHEN m.recency_days <= 30 AND m.frequency < 3 THEN 'Promising'
        WHEN m.recency_days > 90 AND m.frequency >= 3 THEN 'At Risk'
        WHEN m.recency_days > 180 THEN 'Hibernating'
        ELSE 'Regular'
    END as customer_segment,
    -- Lifetime value comparison
    c.lifetime_value as predicted_ltv,
    m.total_revenue as actual_ltv,
    ROUND((m.total_revenue / NULLIF(c.lifetime_value, 0)) * 100, 2) as ltv_realization_pct
FROM iceberg.db.customers c
JOIN customer_metrics m ON c.customer_id = m.customer_id
LEFT JOIN customer_preferences p ON c.customer_id = p.customer_id
WHERE m.total_orders > 0
ORDER BY m.total_revenue DESC
LIMIT 100;
