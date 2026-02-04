-- Iceberg Time Travel: Compare Today vs. Yesterday
-- Demonstrates Iceberg's time travel capability to query historical snapshots

-- Current state
WITH today_snapshot AS (
    SELECT
        COUNT(*) as order_count,
        SUM(total_amount) as revenue,
        AVG(total_amount) as avg_order_value
    FROM iceberg.db.orders
    WHERE status = 'completed'
),
-- Yesterday's state (24 hours ago)
yesterday_snapshot AS (
    SELECT
        COUNT(*) as order_count,
        SUM(total_amount) as revenue,
        AVG(total_amount) as avg_order_value
    FROM iceberg.db.orders
    FOR TIMESTAMP AS OF (CURRENT_TIMESTAMP - INTERVAL '24' HOUR)
    WHERE status = 'completed'
)
SELECT
    'Today' as snapshot,
    t.order_count,
    t.revenue,
    t.avg_order_value,
    t.order_count - y.order_count as orders_added,
    t.revenue - y.revenue as revenue_added,
    ROUND((t.revenue - y.revenue) / y.revenue * 100, 2) as revenue_growth_pct
FROM today_snapshot t, yesterday_snapshot y

UNION ALL

SELECT
    'Yesterday' as snapshot,
    order_count,
    revenue,
    avg_order_value,
    NULL as orders_added,
    NULL as revenue_added,
    NULL as revenue_growth_pct
FROM yesterday_snapshot;

-- View snapshot history
-- SELECT snapshot_id, committed_at, operation
-- FROM iceberg.db.orders.history
-- ORDER BY committed_at DESC
-- LIMIT 10;
