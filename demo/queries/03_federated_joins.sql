-- Federated Query: Customer 360 View
-- Demonstrates joining Iceberg tables with cross-catalog queries

SELECT
    c.customer_id,
    c.first_name,
    c.last_name,
    c.email,
    c.region,
    c.registration_date,
    COUNT(DISTINCT o.order_id) as total_orders,
    SUM(o.total_amount) as total_spent,
    AVG(o.total_amount) as avg_order_value,
    MAX(o.order_date) as last_order_date,
    MIN(o.order_date) as first_order_date,
    COUNT(DISTINCT CASE WHEN o.status = 'completed' THEN o.order_id END) as completed_orders,
    COUNT(DISTINCT CASE WHEN o.status = 'cancelled' THEN o.order_id END) as cancelled_orders,
    COUNT(DISTINCT p.category) as categories_purchased,
    -- Customer lifetime value vs. actual spend
    c.lifetime_value,
    ROUND((SUM(o.total_amount) / c.lifetime_value) * 100, 2) as ltv_realization_pct
FROM iceberg.db.customers c
LEFT JOIN iceberg.db.orders o ON c.customer_id = o.customer_id
LEFT JOIN iceberg.db.products p ON o.product_id = p.product_id
WHERE c.customer_id IN (
    -- Top 10 customers by order count
    SELECT customer_id
    FROM iceberg.db.orders
    WHERE status = 'completed'
    GROUP BY customer_id
    ORDER BY COUNT(*) DESC
    LIMIT 10
)
GROUP BY
    c.customer_id,
    c.first_name,
    c.last_name,
    c.email,
    c.region,
    c.registration_date,
    c.lifetime_value
ORDER BY total_spent DESC;
