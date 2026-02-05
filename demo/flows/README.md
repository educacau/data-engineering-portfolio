# NiFi Flow Templates

This directory contains pre-built Apache NiFi data flow templates for the Data Lakehouse demo.

## Flow List

1. **ingest_orders.xml** - CSV to Kafka ingestion pipeline
2. **process_events.xml** - Kafka stream processing
3. **fraud_alerts.xml** - Real-time fraud detection
4. **data_quality.xml** - Validation and profiling
5. **backup_flow.xml** - S3 backup orchestration

## How to Export Flows

After creating flows in NiFi:

1. Open NiFi at http://localhost:8443/nifi
2. Right-click on process group
3. Select "Download flow definition"
4. Save XML file to this directory

## How to Import Flows

```bash
# Via NiFi UI
1. Open NiFi
2. Drag "Process Group" icon to canvas
3. Select "Import from Registry" or upload file
4. Configure controller services
5. Start flow

# Via NiFi CLI (requires nifi-toolkit)
nifi import-flow -u http://localhost:8443/nifi \
  -f ingest_orders.xml \
  -pg root
```

## Flow Descriptions (To be created in Phase 3)

### 1. Ingest Orders
- **Source**: Local CSV files (demo/data/output/)
- **Destination**: Kafka topic `orders`
- **Features**: Schema validation, error handling, monitoring
- **Throughput**: 10K records/sec

### 2. Process Events
- **Source**: Kafka topic `orders`
- **Destination**: Iceberg table `db.orders`
- **Features**: AVRO deserialization, partitioning, compaction
- **Latency**: < 100ms

### 3. Fraud Alerts
- **Source**: Kafka topic `orders`
- **Destination**: Kafka topic `fraud_alerts`
- **Features**: Rule engine, scoring, alerting
- **Detection**: High-value new customers, bulk orders

### 4. Data Quality
- **Source**: Iceberg tables
- **Destination**: PostgreSQL `data_quality` schema
- **Features**: Row counts, null checks, distribution analysis
- **Schedule**: Hourly

### 5. Backup Flow
- **Source**: MinIO bucket `warehouse`
- **Destination**: MinIO bucket `backups`
- **Features**: Incremental backup, retention policy, checksums
- **Schedule**: Daily at 2 AM
