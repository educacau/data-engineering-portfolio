# Data Model Documentation

## Overview

The Data Lakehouse uses Apache Iceberg tables to store structured data with ACID transactions, schema evolution, and time travel capabilities. All tables use Parquet format with ZSTD compression for optimal storage efficiency.

## Schema Catalog

**Catalog Type:** PostgreSQL JDBC
**Warehouse Location:** `s3://warehouse/iceberg/`
**Format Version:** Iceberg V2
**Compression:** ZSTD (Level 3)

## Table Schemas

### orders

**Description:** E-commerce order transactions

**Schema:**
```sql
CREATE TABLE iceberg.db.orders (
    order_id BIGINT NOT NULL,
    customer_id BIGINT NOT NULL,
    product_id INTEGER NOT NULL,
    product_name VARCHAR,
    quantity INTEGER,
    unit_price DECIMAL(10, 2),
    total_amount DECIMAL(10, 2),
    discount_amount DECIMAL(10, 2),
    tax_amount DECIMAL(10, 2),
    order_date DATE,
    order_timestamp TIMESTAMP(6) WITH TIME ZONE,
    region VARCHAR,
    status VARCHAR,
    payment_method VARCHAR,
    shipping_cost DECIMAL(10, 2),
    is_first_purchase BOOLEAN
)
WITH (
    format = 'PARQUET',
    partitioning = ARRAY['month(order_date)'],
    sorted_by = ARRAY['order_timestamp'],
    format_version = 2
);
```

**Partitioning:** Monthly partitions by `order_date`
**Sort Order:** `order_timestamp` (for time-based queries)
**Primary Key:** `order_id` (enforced application-side)
**Typical Row Count:** 100M+ rows
**Size:** ~50GB compressed

**Sample Data:**
```sql
SELECT * FROM iceberg.db.orders LIMIT 3;
```
| order_id | customer_id | product_id | total_amount | order_date | status    |
|----------|-------------|------------|--------------|------------|-----------|
| 1        | 5432        | 12         | 156.78       | 2026-02-01 | completed |
| 2        | 8901        | 45         | 89.99        | 2026-02-01 | pending   |
| 3        | 5432        | 23         | 234.50       | 2026-02-02 | completed |

### customers

**Description:** Customer master data

**Schema:**
```sql
CREATE TABLE iceberg.db.customers (
    customer_id BIGINT NOT NULL,
    first_name VARCHAR,
    last_name VARCHAR,
    email VARCHAR,
    phone VARCHAR,
    registration_date TIMESTAMP(6) WITH TIME ZONE,
    region VARCHAR,
    lifetime_value DECIMAL(10, 2)
)
WITH (
    format = 'PARQUET',
    format_version = 2
);
```

**Partitioning:** None (dimension table, small size)
**Primary Key:** `customer_id`
**Typical Row Count:** 10M rows
**Size:** ~2GB compressed

### products

**Description:** Product catalog

**Schema:**
```sql
CREATE TABLE iceberg.db.products (
    product_id INTEGER NOT NULL,
    product_name VARCHAR,
    category VARCHAR,
    subcategory VARCHAR,
    base_price DECIMAL(10, 2),
    cost DECIMAL(10, 2),
    margin DECIMAL(5, 2)
)
WITH (
    format = 'PARQUET',
    format_version = 2
);
```

**Partitioning:** None (small reference table)
**Primary Key:** `product_id`
**Typical Row Count:** 50K rows
**Size:** ~10MB compressed

## Relationships

```
┌──────────────┐         ┌──────────────┐
│   customers  │         │   products   │
│              │         │              │
│ customer_id  │         │ product_id   │
└──────┬───────┘         └──────┬───────┘
       │                        │
       │                        │
       └────────┬───────┬───────┘
                │       │
                ▼       ▼
         ┌──────────────────┐
         │     orders        │
         │                   │
         │ customer_id (FK)  │
         │ product_id (FK)   │
         └───────────────────┘
```

## Data Types Reference

| SQL Type | Iceberg Type | Parquet Type | Description |
|----------|--------------|--------------|-------------|
| BIGINT | long | INT64 | 64-bit integer |
| INTEGER | int | INT32 | 32-bit integer |
| DECIMAL(p,s) | decimal(p,s) | FIXED_LEN_BYTE_ARRAY | Fixed precision decimal |
| VARCHAR | string | BYTE_ARRAY | Variable-length string |
| DATE | date | INT32 | Days since epoch |
| TIMESTAMP | timestamp | INT64 | Microseconds since epoch |
| BOOLEAN | boolean | BOOLEAN | True/false |

## Query Examples

### Basic Queries

```sql
-- Recent orders
SELECT * FROM iceberg.db.orders
WHERE order_date >= CURRENT_DATE - INTERVAL '7' DAY
ORDER BY order_timestamp DESC
LIMIT 100;

-- Customer order history
SELECT
    c.first_name,
    c.last_name,
    o.order_id,
    o.total_amount,
    o.order_date
FROM iceberg.db.orders o
JOIN iceberg.db.customers c ON o.customer_id = c.customer_id
WHERE c.customer_id = 12345
ORDER BY o.order_date DESC;
```

### Aggregations

```sql
-- Daily revenue by region
SELECT
    order_date,
    region,
    COUNT(*) as order_count,
    SUM(total_amount) as revenue,
    AVG(total_amount) as avg_order_value
FROM iceberg.db.orders
WHERE order_date >= DATE '2026-02-01'
GROUP BY order_date, region
ORDER BY order_date DESC, revenue DESC;

-- Top products
SELECT
    p.product_name,
    p.category,
    COUNT(*) as orders,
    SUM(o.quantity) as units_sold,
    SUM(o.total_amount) as revenue
FROM iceberg.db.orders o
JOIN iceberg.db.products p ON o.product_id = p.product_id
WHERE o.order_date >= CURRENT_DATE - INTERVAL '30' DAY
GROUP BY p.product_id, p.product_name, p.category
ORDER BY revenue DESC
LIMIT 10;
```

### Time Travel

```sql
-- Query historical snapshot
SELECT COUNT(*) as order_count
FROM iceberg.db.orders
FOR TIMESTAMP AS OF TIMESTAMP '2026-02-01 00:00:00';

-- Compare today vs. yesterday
WITH today AS (
    SELECT COUNT(*) as cnt FROM iceberg.db.orders
),
yesterday AS (
    SELECT COUNT(*) as cnt FROM iceberg.db.orders
    FOR TIMESTAMP AS OF TIMESTAMP '2026-02-03 00:00:00'
)
SELECT
    today.cnt as orders_today,
    yesterday.cnt as orders_yesterday,
    today.cnt - yesterday.cnt as new_orders
FROM today, yesterday;
```

## Schema Evolution

### Add Column (Non-Breaking)

```sql
-- Add new column (nullable, no default)
ALTER TABLE iceberg.db.orders
ADD COLUMN discount_code VARCHAR;

-- Add with default value
ALTER TABLE iceberg.db.orders
ADD COLUMN is_gift BOOLEAN DEFAULT FALSE;
```

### Rename Column (Non-Breaking)

```sql
ALTER TABLE iceberg.db.orders
RENAME COLUMN product_name TO item_name;
```

### Drop Column (Breaking)

```sql
ALTER TABLE iceberg.db.orders
DROP COLUMN discount_code;
```

## Partitioning Strategy

### orders Table

**Partition by month:**
```
s3://warehouse/iceberg/db/orders/data/
├── order_date_month=2026-01/
│   ├── 00000-0-data-00001.parquet
│   ├── 00000-0-data-00002.parquet
│   └── ...
├── order_date_month=2026-02/
│   ├── 00000-0-data-00001.parquet
│   └── ...
```

**Benefits:**
- Partition pruning for date-range queries
- Efficient compaction (monthly batches)
- Manageable partition count

**Trade-offs:**
- Daily queries scan full month partition
- Weekly reports benefit from monthly granularity

## Data Quality

### Constraints (Application-Enforced)

```sql
-- Primary key uniqueness
order_id IS NOT NULL AND UNIQUE

-- Foreign key integrity
customer_id IN (SELECT customer_id FROM customers)
product_id IN (SELECT product_id FROM products)

-- Business rules
total_amount = (unit_price * quantity) - discount_amount + tax_amount
quantity > 0
unit_price >= 0
```

### Expected Data Distributions

| Column | Distribution | Example |
|--------|--------------|---------|
| status | 80% completed, 10% pending, 8% cancelled, 2% refunded | |
| region | 40% North, 25% South, 20% East, 15% West | |
| order_date | Seasonal spike in Q4 (Nov-Dec) | |
| payment_method | 60% credit card, 25% debit, 10% PayPal, 5% other | |

## Performance Characteristics

### Query Performance (Typical)

| Query Type | Latency (p95) | Data Scanned |
|------------|---------------|--------------|
| Point lookup (by order_id) | 50ms | < 1 MB |
| Date range (1 day) | 200ms | ~ 100 MB |
| Full month aggregation | 800ms | ~ 3 GB |
| Join (orders + customers) | 1.2s | ~ 5 GB |
| Time travel query | 150ms | Same as regular |

### Storage Efficiency

| Format | Size (Uncompressed) | Size (ZSTD) | Ratio |
|--------|---------------------|-------------|-------|
| CSV | 200 GB | N/A | 1:1 |
| Parquet (Uncompressed) | 80 GB | N/A | 2.5:1 |
| Parquet + ZSTD | N/A | 40 GB | 5:1 |

## Maintenance Operations

### Compaction

```sql
-- Compact small files (recommended weekly)
CALL iceberg.system.rewrite_data_files(
    table => 'db.orders',
    strategy => 'binpack',
    options => map('target-file-size-bytes', '536870912')
);
```

### Snapshot Expiration

```sql
-- Remove snapshots older than 7 days
CALL iceberg.system.expire_snapshots(
    table => 'db.orders',
    older_than => TIMESTAMP '2026-01-28 00:00:00',
    retain_last => 5
);
```

### Orphan File Cleanup

```sql
-- Remove orphaned data files
CALL iceberg.system.remove_orphan_files(
    table => 'db.orders',
    older_than => TIMESTAMP '2026-01-28 00:00:00'
);
```

## Monitoring Queries

```sql
-- Table statistics
SELECT
    table_name,
    record_count,
    file_count,
    total_size_bytes / 1024 / 1024 / 1024 as size_gb
FROM iceberg.information_schema.tables
WHERE table_schema = 'db';

-- Snapshot history
SELECT
    snapshot_id,
    parent_id,
    operation,
    summary['added-records'] as added_records,
    summary['total-records'] as total_records,
    committed_at
FROM iceberg.db.orders.history
ORDER BY committed_at DESC
LIMIT 10;

-- Partition statistics
SELECT
    partition,
    record_count,
    file_count,
    total_size / 1024 / 1024 as size_mb
FROM iceberg.db.orders.partitions
ORDER BY partition DESC
LIMIT 12;
```
