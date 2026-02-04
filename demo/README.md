# Demo Mode

One-command demonstration of the Apache NiFi Data Lakehouse with synthetic data.

## Quick Start

```bash
./demo.sh
```

This will:
1. Validate prerequisites (Docker, RAM, ports)
2. Generate synthetic e-commerce data
3. Start all services via Docker Compose
4. Wait for health checks
5. Display access URLs

Expected startup time: **< 5 minutes**

## Manual Data Generation

Generate custom datasets:

```bash
# Install dependencies
pip install -r demo/data/requirements.txt

# Generate 100K orders (default)
python demo/data/generate.py

# Generate 1M orders with Parquet output
python demo/data/generate.py --volume 1000000 --format parquet --output demo/data/output

# Options:
#   --volume N      Number of order records (default: 100000)
#   --output DIR    Output directory (default: demo/data/output)
#   --format FMT    csv | parquet | jsonl (default: csv)
#   --seed N        Random seed (default: 42)
```

## Generated Data

### Products (50 records)
- 5 categories: Electronics, Clothing, Home, Books, Sports
- Realistic pricing tiers (60% low, 30% mid, 10% high)

### Customers (10,000 records)
- Regional distribution: 40% North, 25% South, 20% East, 15% West
- Registration dates spanning 5 years

### Orders (100K-1M records)
- Seasonal patterns (Q4 spike for holidays)
- Status distribution: 80% completed, 10% pending, 8% cancelled, 2% refunded
- Payment methods: 60% credit card, 25% debit, 10% PayPal, 5% bank transfer
- First purchase tracking

## Data Model

Follows the Iceberg schema documented in `docs/data-model.md`:

**orders**
- Partitioned by month(order_date)
- Sorted by order_timestamp
- Foreign keys: customer_id, product_id

**customers**
- Dimension table (no partitioning)
- Primary key: customer_id

**products**
- Reference table
- Primary key: product_id

## Service Access URLs

After running `./demo.sh`, access:

| Service | URL | Credentials |
|---------|-----|-------------|
| **Apache NiFi** | http://localhost:8443/nifi | nifi / changeme123 |
| **Apache Superset** | http://localhost:8088 | admin / admin |
| **Jupyter Lab** | http://localhost:8888 | Token in startup logs |
| **Trino UI** | http://localhost:8080 | trino / (no password) |
| **MinIO Console** | http://localhost:9001 | minio / changeme123 |
| **Grafana** | http://localhost:3000 | admin / admin |

## Sample Queries

Located in `demo/queries/`:
- `01_top_products.sql` - Best-selling products analysis
- `02_time_travel.sql` - Iceberg time travel queries
- `03_federated_joins.sql` - Cross-catalog queries
- `04_aggregations.sql` - Daily/monthly rollups
- `05_fraud_detection.sql` - Anomaly detection
- `06_customer_360.sql` - Customer lifetime value
- `07_sales_trends.sql` - Revenue trends
- `08_inventory_checks.sql` - Stock level monitoring
- `09_regional_comparisons.sql` - Regional performance
- `10_performance_metrics.sql` - System benchmarks

## Dashboards

Pre-configured Superset dashboards in `demo/dashboards/`:
- Sales Overview
- Fraud Detection
- Executive Summary
- Product Performance
- Regional Analysis

## NiFi Flows

Pre-built data pipelines in `demo/flows/`:
- `ingest_orders.xml` - CSV to Kafka ingestion
- `process_events.xml` - Stream processing
- `fraud_alerts.xml` - Real-time fraud detection
- `data_quality.xml` - Validation and profiling
- `backup_flow.xml` - S3 backup orchestration

## Troubleshooting

### Port Conflicts
```bash
# Check if ports are in use
netstat -ano | findstr "8443 8088 8888 8080"

# Stop conflicting services or modify docker-compose.yml
```

### Memory Issues
```bash
# Check Docker memory allocation (requires 4GB minimum)
docker info | grep "Total Memory"

# Increase Docker Desktop memory in Settings > Resources
```

### Slow Startup
- First run downloads ~5GB of Docker images
- Subsequent runs: < 5 minutes
- SSD recommended for optimal performance

### Service Health Check Failed
```bash
# Check service logs
docker compose logs nifi
docker compose logs trino

# Restart specific service
docker compose restart nifi
```

## Cleanup

```bash
# Stop services but keep data
docker compose down

# Stop services and remove volumes (deletes all data)
docker compose down -v

# Remove generated data files
rm -rf demo/data/output/
```

## Development

To modify data distributions:
1. Edit `demo/data/generate.py`
2. Adjust weights in `REGION_WEIGHTS`, `STATUS_WEIGHTS`, etc.
3. Regenerate data: `python demo/data/generate.py`

To add custom queries:
1. Create SQL file in `demo/queries/`
2. Test in Trino UI or Jupyter
3. Document expected results

## Performance Targets

| Metric | Target | Actual |
|--------|--------|--------|
| Demo startup | < 5 min | TBD |
| Data generation (100K) | < 30 sec | TBD |
| Memory footprint | < 4 GB | TBD |
| Query latency (p95) | < 1 sec | TBD |

Run `./scripts/benchmark.sh` to measure actual performance.
