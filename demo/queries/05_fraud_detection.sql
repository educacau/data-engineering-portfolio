-- Fraud Detection: Anomaly Patterns
-- Identify suspicious ordering patterns

-- High-value orders from new customers
WITH suspicious_orders AS (
    SELECT
        o.order_id,
        o.customer_id,
        c.first_name,
        c.last_name,
        c.email,
        o.total_amount,
        o.order_date,
        o.order_timestamp,
        o.payment_method,
        o.region,
        o.is_first_purchase,
        -- Flag conditions
        CASE WHEN o.total_amount > 1000 AND o.is_first_purchase THEN 1 ELSE 0 END as flag_high_value_new_customer,
        CASE WHEN o.quantity >= 10 THEN 1 ELSE 0 END as flag_bulk_order,
        CASE WHEN o.discount_amount / (o.total_amount + o.discount_amount) > 0.15 THEN 1 ELSE 0 END as flag_high_discount
    FROM iceberg.db.orders o
    JOIN iceberg.db.customers c ON o.customer_id = c.customer_id
    WHERE o.order_date >= CURRENT_DATE - INTERVAL '7' DAY
)
SELECT
    order_id,
    customer_id,
    first_name,
    last_name,
    email,
    total_amount,
    order_timestamp,
    payment_method,
    region,
    -- Risk score (sum of flags)
    (flag_high_value_new_customer + flag_bulk_order + flag_high_discount) as risk_score,
    -- Reasons
    CONCAT_WS(', ',
        CASE WHEN flag_high_value_new_customer = 1 THEN 'High-value first purchase' END,
        CASE WHEN flag_bulk_order = 1 THEN 'Bulk quantity' END,
        CASE WHEN flag_high_discount = 1 THEN 'Excessive discount' END
    ) as risk_factors
FROM suspicious_orders
WHERE (flag_high_value_new_customer + flag_bulk_order + flag_high_discount) >= 2
ORDER BY risk_score DESC, total_amount DESC
LIMIT 20;

-- Customer velocity analysis (multiple orders in short time)
-- SELECT
--     customer_id,
--     COUNT(*) as orders_last_hour,
--     SUM(total_amount) as total_amount,
--     MAX(order_timestamp) as last_order
-- FROM iceberg.db.orders
-- WHERE order_timestamp >= CURRENT_TIMESTAMP - INTERVAL '1' HOUR
-- GROUP BY customer_id
-- HAVING COUNT(*) >= 5
-- ORDER BY orders_last_hour DESC;
