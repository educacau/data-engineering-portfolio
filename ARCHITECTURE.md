# Architecture Documentation

## System Overview

This Data Lakehouse platform implements a modern, scalable architecture for unified data processing, combining real-time streaming and batch analytics capabilities. The system processes 10TB+ of data daily across structured, semi-structured, and unstructured formats, serving analytics queries with sub-second latency.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          DATA SOURCES                                    │
│  REST APIs  │  Databases  │  File Systems  │  Message Queues  │  IoT    │
└──────────────────────────────┬──────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                      INGESTION LAYER                                     │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │  Apache NiFi Cluster (3 nodes)                                   │   │
│  │  • Automatic schema detection                                    │   │
│  │  • Data quality validation                                       │   │
│  │  • Routing and transformation                                    │   │
│  │  • HTTPS + authentication                                        │   │
│  └──────────────────────────────────────────────────────────────────┘   │
└───────────────────────────────┬─────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                      STREAMING LAYER                                     │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │  Apache Kafka + Schema Registry                                 │    │
│  │  • 100K+ events/second throughput                               │    │
│  │  • AVRO schema evolution                                        │    │
│  │  • SASL_SSL encryption                                          │    │
│  │  • Topics: orders, customers, products, events                  │    │
│  └─────────────────────────────────────────────────────────────────┘    │
└───────────────────────────────┬─────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                      PROCESSING LAYER                                    │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │  Apache Spark (Master + Workers)                                │    │
│  │  • Structured Streaming (micro-batch: 10s)                      │    │
│  │  • Batch processing for historical data                         │    │
│  │  • Parquet writer with ZSTD compression                         │    │
│  │  • Automatic partitioning by date                               │    │
│  └─────────────────────────────────────────────────────────────────┘    │
└───────────────────────────────┬─────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                      STORAGE LAYER                                       │
│  ┌─────────────────────┐        ┌────────────────────────────────┐      │
│  │   MinIO S3          │        │  PostgreSQL                    │      │
│  │   Object Storage    │◄───────┤  (Iceberg Catalog)             │      │
│  │   • Parquet files   │        │  • Table metadata              │      │
│  │   • ZSTD compressed │        │  • Schema versions             │      │
│  │   • Versioned       │        │  • Partition info              │      │
│  └─────────────────────┘        └────────────────────────────────┘      │
│                                                                           │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │  Apache Iceberg Tables                                          │    │
│  │  • ACID transactions                                            │    │
│  │  • Time travel (point-in-time queries)                          │    │
│  │  • Hidden partitioning                                          │    │
│  │  • Schema evolution                                             │    │
│  └─────────────────────────────────────────────────────────────────┘    │
└───────────────────────────────┬─────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                      QUERY LAYER                                         │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │  Trino (Distributed SQL Engine)                                 │    │
│  │  • Federated queries across all sources                         │    │
│  │  • Sub-second latency (p95 < 1s)                                │    │
│  │  • Cost-based optimizer                                         │    │
│  │  • Connectors: Iceberg, Delta, PostgreSQL, MySQL                │    │
│  └─────────────────────────────────────────────────────────────────┘    │
└───────────────────────────────┬─────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                      PRESENTATION LAYER                                  │
│  ┌────────────────────────┐      ┌──────────────────────────────────┐   │
│  │  Apache Superset       │      │  Jupyter Lab                     │   │
│  │  • Interactive         │      │  • Ad-hoc analysis               │   │
│  │    dashboards          │      │  • Python/SQL notebooks          │   │
│  │  • SQL Lab             │      │  • ML experimentation            │   │
│  │  • Alerts              │      │  • Data exploration              │   │
│  └────────────────────────┘      └──────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                      OBSERVABILITY LAYER                                 │
│  ┌─────────────────────┐  ┌─────────────────┐  ┌──────────────────┐    │
│  │  Prometheus         │  │  Grafana        │  │  Loki + Promtail │    │
│  │  • Metrics          │  │  • Dashboards   │  │  • Logs          │    │
│  │  • Alerts           │  │  • Alerting     │  │  • Aggregation   │    │
│  └─────────────────────┘  └─────────────────┘  └──────────────────┘    │
└─────────────────────────────────────────────────────────────────────────┘
```

## Component Specifications

### Ingestion Layer: Apache NiFi

**Purpose:** Unified data ingestion from heterogeneous sources

**Key Features:**
- Visual dataflow design (drag-and-drop)
- 300+ built-in processors
- Automatic backpressure handling
- Guaranteed delivery
- Data provenance tracking

**Configuration:**
- **Cluster:** 3 nodes (HA configuration)
- **Protocol:** HTTPS with TLS 1.3
- **Authentication:** LDAP integration
- **Throughput:** 100K records/second per node
- **Storage:** 1TB provenance repository

**Example Flow:**
```
[InvokeHTTP] → [EvaluateJSONPath] → [RouteOnAttribute]
    → [ValidateRecord] → [PublishKafka]
```

### Streaming Layer: Apache Kafka

**Purpose:** Real-time event streaming backbone

**Configuration:**
- **Brokers:** 1 (demo), 3+ (production)
- **Replication:** Factor 3 for durability
- **Partitions:** 3-12 per topic (based on volume)
- **Retention:** 7 days (configurable)
- **Compression:** ZSTD (60% reduction)
- **Security:** SASL_SSL with SCRAM-SHA-512

**Topics:**
| Topic | Partitions | Avg Msg Size | Daily Volume |
|-------|------------|--------------|--------------|
| orders | 12 | 2 KB | 10M messages |
| customers | 3 | 5 KB | 500K messages |
| products | 3 | 3 KB | 50K messages |
| events | 6 | 1 KB | 50M messages |

**Schema Registry:**
- **Format:** AVRO (schema evolution support)
- **Compatibility:** BACKWARD (safe schema changes)
- **Versioning:** Automatic version management

### Processing Layer: Apache Spark

**Purpose:** Unified batch and stream processing

**Configuration:**
- **Master:** 1 node (HA with ZooKeeper in production)
- **Workers:** 2-4 nodes (auto-scaling)
- **Memory:** 4GB per worker (demo), 32GB+ (production)
- **Cores:** 4 per worker
- **Parallelism:** 200 (default.parallelism)

**Streaming Jobs:**
```python
# Structured Streaming example
orders_stream = spark \
    .readStream \
    .format("kafka") \
    .option("kafka.bootstrap.servers", "kafka:9092") \
    .option("subscribe", "orders") \
    .load()

# Write to Iceberg with micro-batch
orders_stream \
    .writeStream \
    .format("iceberg") \
    .outputMode("append") \
    .trigger(processingTime="10 seconds") \
    .option("checkpointLocation", "/tmp/checkpoints") \
    .toTable("iceberg.db.orders")
```

**Optimizations:**
- **Dynamic partition pruning** (10x faster queries)
- **Adaptive query execution** (auto-tuning)
- **Columnar storage** (Parquet with ZSTD)
- **Predicate pushdown** to storage layer

### Storage Layer: Apache Iceberg

**Purpose:** ACID-compliant data lakehouse tables

**Key Features:**
- **ACID Transactions:** Serializable isolation
- **Time Travel:** Query historical snapshots
- **Schema Evolution:** Add/drop/rename columns without rewrites
- **Hidden Partitioning:** Users don't need partition awareness
- **Partition Evolution:** Change partitioning without data rewrites

**Table Format:**
```sql
CREATE TABLE iceberg.db.orders (
    order_id BIGINT,
    customer_id BIGINT,
    product_id INT,
    total_amount DECIMAL(10,2),
    order_date DATE,
    order_timestamp TIMESTAMP
)
PARTITIONED BY (month(order_date))
STORED AS PARQUET
TBLPROPERTIES (
    'format-version' = '2',
    'write.format.default' = 'parquet',
    'write.parquet.compression-codec' = 'zstd'
)
```

**Storage Hierarchy:**
```
s3://warehouse/iceberg/
├── db/
│   ├── orders/
│   │   ├── metadata/
│   │   │   ├── v1.metadata.json
│   │   │   ├── v2.metadata.json
│   │   │   └── snap-123.avro
│   │   └── data/
│   │       ├── order_date_month=2026-01/
│   │       │   ├── part-00000.parquet
│   │       │   └── part-00001.parquet
│   │       └── order_date_month=2026-02/
│   │           └── part-00000.parquet
```

**Performance:**
- **Compression Ratio:** 5:1 (ZSTD on Parquet)
- **Scan Efficiency:** 90%+ partition pruning
- **Snapshot Expiration:** 7 days (configurable)

### Query Layer: Trino

**Purpose:** Distributed SQL engine for interactive analytics

**Configuration:**
- **Coordinator:** 1 node
- **Workers:** 2-4 nodes (demo), 10+ (production)
- **Memory:** 4GB per worker (demo), 64GB+ (production)
- **Connectors:** Iceberg, Delta, PostgreSQL, MySQL, S3

**Query Optimization:**
- **Cost-based optimizer** (CBO)
- **Dynamic filtering** (broadcast joins)
- **Predicate pushdown** to storage
- **Columnar processing** (vectorized execution)

**Example Queries:**
```sql
-- Time travel (query historical snapshot)
SELECT * FROM iceberg.db.orders
FOR TIMESTAMP AS OF TIMESTAMP '2026-02-01 00:00:00';

-- Federated query (join across Iceberg and PostgreSQL)
SELECT o.order_id, o.total_amount, c.email
FROM iceberg.db.orders o
JOIN postgresql.public.customers c ON o.customer_id = c.id
WHERE o.order_date >= DATE '2026-02-01';

-- Analytical query with aggregation
SELECT
    date_trunc('hour', order_timestamp) as hour,
    region,
    COUNT(*) as order_count,
    SUM(total_amount) as revenue
FROM iceberg.db.orders
WHERE order_date = CURRENT_DATE
GROUP BY 1, 2
ORDER BY 1 DESC;
```

### Presentation Layer

#### Apache Superset

**Purpose:** Business intelligence and data visualization

**Features:**
- **SQL Lab:** Interactive SQL editor
- **Dashboards:** Drag-and-drop dashboard builder
- **Charts:** 40+ visualization types
- **Alerts:** Email/Slack alerts on threshold breach
- **Row-level security:** Data access control

**Configuration:**
- **Database:** PostgreSQL (metadata store)
- **Cache:** Redis (query result caching)
- **Authentication:** LDAP/OAuth integration
- **Celery:** Async query execution

#### Jupyter Lab

**Purpose:** Interactive data science and exploration

**Use Cases:**
- Ad-hoc analysis and exploration
- ML model development
- Data quality investigations
- Documentation with notebooks

**Kernels:**
- **Python 3.11** (pandas, numpy, scikit-learn)
- **PySpark** (distributed processing)
- **SQL** (direct Trino queries)

### Observability Layer

#### Metrics: Prometheus + Grafana

**Prometheus Exporters:**
- **Node Exporter:** System metrics (CPU, memory, disk)
- **JMX Exporter:** Java application metrics (NiFi, Kafka, Spark)
- **Kafka Exporter:** Kafka-specific metrics (lag, throughput)
- **Custom Exporters:** Application-level metrics

**Key Metrics:**
| Metric | Description | Alert Threshold |
|--------|-------------|-----------------|
| `kafka_consumer_lag` | Message backlog | > 10K messages |
| `trino_query_latency_p95` | Query performance | > 5 seconds |
| `nifi_flowfile_queue_size` | Backpressure indicator | > 100K files |
| `iceberg_table_size_bytes` | Storage growth | > 10TB |
| `spark_executor_failures` | Job stability | > 5 failures/hour |

**Grafana Dashboards:**
1. **System Overview:** Health status of all components
2. **Data Pipeline:** End-to-end data flow metrics
3. **Query Performance:** Trino query analytics
4. **Resource Utilization:** CPU, memory, disk, network

#### Logs: Loki + Promtail

**Log Collection:**
- **Promtail:** Scrapes logs from containers
- **Loki:** Log aggregation and indexing
- **Grafana:** Log querying and visualization

**Log Levels:**
- **ERROR:** Application errors requiring attention
- **WARN:** Warnings and degraded performance
- **INFO:** Normal operational messages
- **DEBUG:** Detailed troubleshooting information

## Network Architecture

### Network Segmentation

**Frontend Network** (External Access):
- NiFi UI (8081-8083)
- Superset (8088)
- Grafana (3000)
- Jupyter (8888)
- Trino UI (8090)

**Backend Network** (Internal Only):
- ZooKeeper (2181)
- Kafka brokers (9092)
- PostgreSQL (5432)
- MinIO API (9000)
- Redis (6379)

### Security

**Transport Encryption:**
- NiFi: HTTPS with TLS 1.3
- Kafka: SASL_SSL
- Trino: HTTPS (optional)
- Inter-service: mTLS (optional)

**Authentication:**
- NiFi: LDAP + client certificates
- Kafka: SCRAM-SHA-512
- Trino: LDAP/Kerberos
- Superset: OAuth 2.0

**Authorization:**
- Role-based access control (RBAC)
- Row-level security in Superset
- Kafka ACLs for topic access
- Iceberg table-level permissions

## Data Flow

### Ingestion Flow

```
1. Source System → REST API/JDBC/File → NiFi
2. NiFi → Data validation + transformation → Kafka topic
3. Kafka → Schema Registry (AVRO validation)
4. Spark Streaming → Consume from Kafka → Process
5. Spark → Write Parquet files → MinIO S3
6. Spark → Update Iceberg metadata → PostgreSQL
```

### Query Flow

```
1. User → Submit SQL query → Trino Coordinator
2. Trino → Parse & optimize query → Query plan
3. Trino → Fetch metadata → Iceberg catalog (PostgreSQL)
4. Trino → Read data files → MinIO S3 (parallel scan)
5. Trino → Execute query → Workers (distributed)
6. Trino → Return results → User (via Superset/Jupyter)
```

## Scalability

### Horizontal Scaling

**Compute Layer:**
- Add Spark workers for more processing capacity
- Add Trino workers for more query concurrency
- Add NiFi nodes for higher ingestion throughput

**Storage Layer:**
- MinIO scales linearly with nodes
- Iceberg metadata stored in PostgreSQL (vertically scalable)

### Performance Tuning

**Spark:**
- Increase parallelism for large datasets
- Tune shuffle partitions based on data volume
- Enable dynamic allocation for cost optimization

**Trino:**
- Increase worker memory for complex queries
- Use materialized views for frequent aggregations
- Partition tables by query patterns

**Iceberg:**
- Compact small files regularly
- Expire old snapshots to reduce metadata size
- Sort data within files for better pruning

## Disaster Recovery

**Backup Strategy:**
- **Iceberg tables:** S3 versioning + cross-region replication
- **Metadata:** PostgreSQL daily backups to S3
- **Kafka:** Topic mirroring to backup cluster (optional)

**Recovery Time Objectives (RTO):**
- **Data loss:** < 5 minutes (Kafka retention)
- **System recovery:** < 1 hour (automated failover)
- **Full rebuild:** < 4 hours (from backups)

**Recovery Point Objectives (RPO):**
- **Streaming data:** < 10 seconds (Spark checkpoints)
- **Batch data:** < 1 hour (incremental loads)

## Deployment

### Demo Mode (< 4GB RAM)

**Services:**
- NiFi (2 nodes, 1.5GB heap each)
- Kafka (1 broker, 512MB)
- Trino (1 coordinator, 1 worker)
- Superset (512MB)
- MinIO (256MB)
- PostgreSQL (512MB)

**Command:**
```bash
./demo.sh
```

### Production Mode (64GB+ RAM)

**Services:**
- NiFi cluster (3 nodes, 8GB heap each)
- Kafka cluster (3 brokers, 4GB each)
- Spark cluster (1 master, 4 workers, 16GB each)
- Trino cluster (1 coordinator, 8 workers, 32GB each)
- Full observability stack

**Command:**
```bash
docker compose -f docker/docker-compose.yml up -d
```

## Monitoring & Alerts

### Health Checks

All services expose health endpoints:
```bash
curl http://nifi:8081/nifi-api/system-diagnostics
curl http://superset:8088/health
curl http://trino:8090/v1/info
```

### Alerting Rules

**Critical Alerts** (PagerDuty):
- Service down > 5 minutes
- Data pipeline stopped > 10 minutes
- Query latency p95 > 10 seconds

**Warning Alerts** (Slack):
- Consumer lag > 100K messages
- Disk usage > 80%
- Error rate > 1%

## Future Enhancements

**Short-term (3 months):**
- Machine learning pipelines (MLflow integration)
- Real-time feature store
- Data quality monitoring (Great Expectations)

**Medium-term (6 months):**
- Multi-cluster federation
- CDC from transactional databases
- Advanced security (data masking, encryption at rest)

**Long-term (12 months):**
- Kubernetes deployment
- Multi-cloud support
- Auto-scaling based on workload
