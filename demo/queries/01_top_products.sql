-- Top 10 Products by Revenue
-- Query the orders table joined with products to find best sellers

SELECT
    p.product_name,
    p.category,
    p.subcategory,
    COUNT(DISTINCT o.order_id) as total_orders,
    SUM(o.quantity) as units_sold,
    SUM(o.total_amount) as total_revenue,
    AVG(o.total_amount) as avg_order_value,
    SUM(o.discount_amount) as total_discounts
FROM iceberg.db.orders o
JOIN iceberg.db.products p ON o.product_id = p.product_id
WHERE o.status = 'completed'
  AND o.order_date >= CURRENT_DATE - INTERVAL '30' DAY
GROUP BY p.product_id, p.product_name, p.category, p.subcategory
ORDER BY total_revenue DESC
LIMIT 10;
