# Architecture Diagrams - Apache NiFi Data Lakehouse

This document contains Mermaid diagrams that render automatically on GitHub, providing interactive visual representations of the system architecture.

> **Note:** These diagrams complement the ASCII diagrams in [ARCHITECTURE.md](../ARCHITECTURE.md)

---

## Table of Contents

1. [System Architecture Overview](#system-architecture-overview)
2. [Detailed Data Flow](#detailed-data-flow)
3. [Network Topology](#network-topology)
4. [Deployment Architecture](#deployment-architecture)
5. [Security Architecture](#security-architecture)
6. [Component Interactions](#component-interactions)

---

## System Architecture Overview

High-level view of all components and their relationships:

```mermaid
graph TB
    subgraph "Data Sources"
        CSV[CSV Files]
        JSON[JSON Streams]
        DB[External DBs]
        API[REST APIs]
    end

    subgraph "Ingestion Layer"
        NiFi[Apache NiFi<br/>3-node cluster<br/>HTTPS]
        Kafka[Apache Kafka<br/>Event Streaming<br/>100K msg/sec]
        SR[Schema Registry<br/>AVRO Schemas]
    end

    subgraph "Storage Layer"
        MinIO[MinIO S3<br/>Object Storage<br/>Parquet Files]
        PG[PostgreSQL<br/>Iceberg Catalog<br/>Metadata]
        Redis[Redis<br/>Cache Layer<br/>Sub-ms Latency]
    end

    subgraph "Processing Layer"
        Spark[Apache Spark<br/>Batch & Streaming<br/>Distributed]
        Iceberg[Apache Iceberg<br/>ACID Lakehouse<br/>Time Travel]
    end

    subgraph "Query Layer"
        Trino[Trino<br/>Federated SQL<br/>MPP Engine]
    end

    subgraph "Analytics Layer"
        Superset[Apache Superset<br/>BI Dashboards<br/>40+ Charts]
        Jupyter[Jupyter Lab<br/>Notebooks<br/>Python/SQL]
    end

    subgraph "Observability"
        Prom[Prometheus<br/>Metrics<br/>15s Interval]
        Grafana[Grafana<br/>Visualization<br/>Dashboards]
        Loki[Loki<br/>Log Aggregation<br/>LogQL]
    end

    CSV --> NiFi
    JSON --> NiFi
    DB --> NiFi
    API --> NiFi
    NiFi -->|Produce| Kafka
    Kafka --> SR
    Kafka -->|Consume| Spark
    Spark -->|Write| Iceberg
    Iceberg -->|Data| MinIO
    Iceberg -->|Metadata| PG
    Trino -->|Query| Iceberg
    Trino -->|Cache| Redis
    Superset -->|SQL| Trino
    Jupyter -->|SQL| Trino

    NiFi -.metrics.-> Prom
    Kafka -.metrics.-> Prom
    Trino -.metrics.-> Prom
    Spark -.metrics.-> Prom
    Prom --> Grafana
    NiFi -.logs.-> Loki
    Kafka -.logs.-> Loki
    Spark -.logs.-> Loki
    Loki --> Grafana

    style NiFi fill:#4A90E2,stroke:#2C5AA0,stroke-width:2px,color:#fff
    style Kafka fill:#231F20,stroke:#000,stroke-width:2px,color:#fff
    style Iceberg fill:#3A8DFF,stroke:#1E5A9F,stroke-width:2px,color:#fff
    style Trino fill:#DD00A1,stroke:#A00075,stroke-width:2px,color:#fff
    style Superset fill:#20A6C9,stroke:#167B94,stroke-width:2px,color:#fff
    style Spark fill:#E25A1C,stroke:#B84516,stroke-width:2px,color:#fff
    style MinIO fill:#C72C48,stroke:#951F35,stroke-width:2px,color:#fff
```

---

## Detailed Data Flow

End-to-end data pipeline from source to analytics:

```mermaid
flowchart LR
    subgraph "1. Ingestion"
        Source[Data Source<br/>CSV/JSON/DB]
        NiFi1[NiFi: GetFile]
        NiFi2[NiFi: ValidateRecord]
        NiFi3[NiFi: ConvertRecord]
        NiFi4[NiFi: PublishKafka]

        Source -->|Raw Data| NiFi1
        NiFi1 -->|Flowfile| NiFi2
        NiFi2 -->|Validated| NiFi3
        NiFi3 -->|AVRO| NiFi4
    end

    subgraph "2. Streaming"
        Kafka1[Kafka Topic<br/>orders]
        SR1[Schema Registry<br/>AVRO Schema]
        Spark1[Spark Streaming<br/>Micro-batch 10s]

        NiFi4 -->|Produce| Kafka1
        Kafka1 <-->|Validate| SR1
        Kafka1 -->|Consume| Spark1
    end

    subgraph "3. Lakehouse"
        Iceberg1[Iceberg Table<br/>orders]
        PG1[(PostgreSQL<br/>Catalog)]
        S3_1[(MinIO S3<br/>Parquet)]

        Spark1 -->|Write ACID| Iceberg1
        Iceberg1 -->|Metadata| PG1
        Iceberg1 -->|Data Files| S3_1
    end

    subgraph "4. Query & Analytics"
        Trino1[Trino Coordinator]
        Trino2[Trino Workers<br/>Distributed]
        Cache[Redis Cache]
        Dashboard[Superset<br/>Dashboard]
        Notebook[Jupyter<br/>Notebook]

        Iceberg1 -->|Read| Trino1
        Trino1 -->|Distribute| Trino2
        Trino2 -->|Results| Cache
        Trino1 -->|SQL Results| Dashboard
        Trino1 -->|SQL Results| Notebook
    end

    style Source fill:#FFE5B4,stroke:#FFB84D,stroke-width:2px
    style Iceberg1 fill:#3A8DFF,stroke:#1E5A9F,stroke-width:2px,color:#fff
    style Dashboard fill:#20A6C9,stroke:#167B94,stroke-width:2px,color:#fff
    style Notebook fill:#F37726,stroke:#C45E1C,stroke-width:2px,color:#fff
    style Kafka1 fill:#231F20,stroke:#000,stroke-width:2px,color:#fff
    style Spark1 fill:#E25A1C,stroke:#B84516,stroke-width:2px,color:#fff
```

---

## Network Topology

Network segmentation and service connectivity:

```mermaid
graph TB
    subgraph External["External Access (Host)"]
        User[User Browser]
        API_Client[API Clients]
    end

    subgraph Frontend["Frontend Network (bridge)"]
        direction TB
        NiFi_UI[NiFi UI<br/>:8443 HTTPS]
        Superset_UI[Superset<br/>:8088 HTTP]
        Jupyter_UI[Jupyter Lab<br/>:8888 HTTP]
        Trino_UI[Trino UI<br/>:8080 HTTP]
        MinIO_UI[MinIO Console<br/>:9001 HTTP]
        Grafana_UI[Grafana<br/>:3000 HTTP]
    end

    subgraph Backend["Backend Network (internal)"]
        direction TB
        ZK[Zookeeper<br/>:2181]
        Kafka_Broker[Kafka<br/>:9092]
        Schema_Reg[Schema Registry<br/>:8081]
        PostgreSQL_DB[PostgreSQL<br/>:5432]
        MinIO_API[MinIO API<br/>:9000]
        Redis_DB[Redis<br/>:6379]
        Trino_Coord[Trino Coordinator<br/>:8080]
        Spark_Master[Spark Master<br/>:7077]
        Prom_API[Prometheus<br/>:9090]
        Loki_API[Loki<br/>:3100]
    end

    User -->|HTTPS| NiFi_UI
    User -->|HTTP| Superset_UI
    User -->|HTTP| Jupyter_UI
    User -->|HTTP| Trino_UI
    User -->|HTTP| MinIO_UI
    User -->|HTTP| Grafana_UI
    API_Client -->|HTTP| MinIO_UI

    NiFi_UI -.Internal.-> Kafka_Broker
    NiFi_UI -.Internal.-> Schema_Reg
    Trino_Coord -.Internal.-> MinIO_API
    Trino_Coord -.Internal.-> PostgreSQL_DB
    Trino_Coord -.Internal.-> Redis_DB
    Superset_UI -.SQL.-> Trino_Coord
    Jupyter_UI -.SQL.-> Trino_Coord
    Kafka_Broker -.Metadata.-> ZK
    Spark_Master -.Read/Write.-> MinIO_API
    Spark_Master -.Metadata.-> PostgreSQL_DB

    Grafana_UI -.Query.-> Prom_API
    Grafana_UI -.Query.-> Loki_API

    style External fill:#90EE90,stroke:#228B22,stroke-width:2px
    style Frontend fill:#E8F4F8,stroke:#4A90E2,stroke-width:3px
    style Backend fill:#FFF4E6,stroke:#FF8C00,stroke-width:3px
    style User fill:#98FB98,stroke:#32CD32,stroke-width:2px
```

---

## Deployment Architecture

Docker container layout with resource allocation:

```mermaid
graph TB
    subgraph DockerHost["Docker Host (8 cores, 16GB RAM)"]
        subgraph Containers["Containers"]
            direction LR
            subgraph Coordination["Coordination (512MB)"]
                C1[Zookeeper<br/>256MB]
            end

            subgraph Messaging["Messaging (1.5GB)"]
                C2[Kafka<br/>1GB]
                C3[Schema Registry<br/>512MB]
            end

            subgraph Storage["Storage (1GB)"]
                C4[PostgreSQL<br/>256MB]
                C5[MinIO<br/>512MB]
                C6[Redis<br/>256MB]
            end

            subgraph Ingestion["Ingestion (6GB)"]
                C7[NiFi-1<br/>2GB]
                C8[NiFi-2<br/>2GB]
                C9[NiFi-3<br/>2GB]
            end

            subgraph Processing["Processing (3GB)"]
                C10[Spark Master<br/>1GB]
                C11[Spark Worker<br/>2GB]
            end

            subgraph Query["Query (2GB)"]
                C12[Trino<br/>2GB]
            end

            subgraph Analytics["Analytics (1.5GB)"]
                C13[Superset<br/>1GB]
                C14[Jupyter<br/>512MB]
            end

            subgraph Monitoring["Monitoring (1.3GB)"]
                C15[Prometheus<br/>512MB]
                C16[Grafana<br/>256MB]
                C17[Loki<br/>512MB]
            end
        end

        subgraph Volumes["Persistent Volumes"]
            V1[nifi-conf<br/>100MB]
            V2[nifi-logs<br/>1GB]
            V3[minio-data<br/>50GB]
            V4[postgres-data<br/>5GB]
            V5[superset-data<br/>1GB]
        end

        subgraph Networks["Docker Networks"]
            N1[frontend<br/>bridge<br/>External Access]
            N2[backend<br/>bridge<br/>Internal Only]
        end
    end

    Coordination --> N2
    Messaging --> N2
    Storage --> N2
    Ingestion --> N2
    Processing --> N2
    Query --> N2

    Ingestion --> N1
    Query --> N1
    Analytics --> N1
    Storage --> N1
    Monitoring --> N1

    C7 -.mount.-> V1
    C7 -.mount.-> V2
    C8 -.mount.-> V1
    C8 -.mount.-> V2
    C9 -.mount.-> V1
    C9 -.mount.-> V2
    C5 -.mount.-> V3
    C4 -.mount.-> V4
    C13 -.mount.-> V5

    style DockerHost fill:#F0F8FF,stroke:#4682B4,stroke-width:3px
    style Containers fill:#E8F4F8,stroke:#4A90E2,stroke-width:2px
    style Volumes fill:#FFF4E6,stroke:#FF8C00,stroke-width:2px
    style Networks fill:#F0FFF0,stroke:#228B22,stroke-width:2px
    style Coordination fill:#FFE5B4
    style Messaging fill:#FFD700
    style Storage fill:#98FB98
    style Ingestion fill:#87CEEB
    style Processing fill:#FFA07A
    style Query fill:#DDA0DD
    style Analytics fill:#F0E68C
    style Monitoring fill:#E0E0E0
```

---

## Security Architecture

Security layers and controls:

```mermaid
graph TB
    subgraph External["External Layer"]
        Internet[Internet/Users]
        VPN[VPN/Bastion]
    end

    subgraph Perimeter["Perimeter Security"]
        LB[Load Balancer<br/>TLS Termination]
        WAF[Web Application<br/>Firewall]
        FW[Firewall<br/>Port Filtering]
    end

    subgraph Application["Application Security"]
        subgraph Auth["Authentication"]
            LDAP[LDAP/AD<br/>User Directory]
            OAuth[OAuth 2.0<br/>SSO Provider]
            Certs[Client Certificates<br/>mTLS]
        end

        subgraph Authz["Authorization"]
            RBAC[Role-Based<br/>Access Control]
            ACL[Kafka ACLs<br/>Topic Permissions]
            RLS[Row-Level<br/>Security]
        end
    end

    subgraph Transport["Transport Security"]
        TLS_NiFi[NiFi HTTPS<br/>TLS 1.3]
        TLS_Kafka[Kafka SASL_SSL<br/>SCRAM-SHA-512]
        TLS_Trino[Trino HTTPS<br/>TLS 1.2+]
    end

    subgraph Data["Data Security"]
        Encrypt_Rest[Encryption<br/>at Rest<br/>AES-256]
        Encrypt_Transit[Encryption<br/>in Transit<br/>TLS]
        Masking[Data Masking<br/>PII Protection]
    end

    subgraph Audit["Audit & Compliance"]
        Logs[Centralized Logging<br/>Loki]
        Metrics[Metrics Collection<br/>Prometheus]
        Provenance[Data Lineage<br/>NiFi Provenance]
        Audit_Trail[Audit Trail<br/>PostgreSQL]
    end

    Internet --> VPN
    VPN --> LB
    LB --> WAF
    WAF --> FW

    FW --> TLS_NiFi
    FW --> TLS_Kafka
    FW --> TLS_Trino

    TLS_NiFi --> Auth
    TLS_Kafka --> Auth
    TLS_Trino --> Auth

    Auth --> Authz
    Authz --> Data

    Data --> Audit

    style External fill:#FF6B6B,stroke:#C92A2A,stroke-width:2px
    style Perimeter fill:#FFD93D,stroke:#F08C00,stroke-width:2px
    style Application fill:#6BCB77,stroke:#2D9F4B,stroke-width:2px
    style Transport fill:#4D96FF,stroke:#0066CC,stroke-width:2px
    style Data fill:#9D84B7,stroke:#6B4E8B,stroke-width:2px
    style Audit fill:#B8B8B8,stroke:#5E5E5E,stroke-width:2px
```

---

## Component Interactions

Sequence diagram showing a typical query flow:

```mermaid
sequenceDiagram
    actor User
    participant Superset
    participant Trino
    participant Redis
    participant Iceberg
    participant PostgreSQL as PostgreSQL<br/>(Catalog)
    participant MinIO as MinIO S3<br/>(Data)

    User->>Superset: Submit SQL Query
    Superset->>Trino: Forward Query

    Trino->>Redis: Check Cache
    alt Cache Hit
        Redis-->>Trino: Cached Results
        Trino-->>Superset: Return Results
    else Cache Miss
        Trino->>PostgreSQL: Fetch Table Metadata
        PostgreSQL-->>Trino: Schema, Partitions, Stats

        Trino->>Trino: Optimize Query<br/>(CBO, Predicate Pushdown)

        Trino->>MinIO: Read Parquet Files<br/>(Parallel Scan)
        MinIO-->>Trino: Data Blocks

        Trino->>Trino: Execute Query<br/>(Distributed Workers)

        Trino->>Redis: Cache Results<br/>(TTL: 5min)
        Trino-->>Superset: Return Results
    end

    Superset->>Superset: Render Visualization
    Superset-->>User: Display Dashboard

    Note over User,MinIO: Query Latency: p95 < 1 second
```

---

## Data Lifecycle

Data lifecycle from ingestion to archival:

```mermaid
stateDiagram-v2
    [*] --> Raw: Data Arrives
    Raw --> Validated: NiFi Schema Validation
    Validated --> Transformed: NiFi Transformation
    Transformed --> Streaming: Kafka Topic
    Streaming --> Processing: Spark Consumption
    Processing --> Bronze: Write to Iceberg<br/>(Raw Layer)
    Bronze --> Silver: Data Quality<br/>Cleaning & Enrichment
    Silver --> Gold: Business Logic<br/>Aggregations
    Gold --> Serving: Query Layer<br/>(Trino)
    Serving --> Archived: 90 Days Retention
    Archived --> [*]: Glacier Storage

    Bronze --> Quarantine: Schema Violation
    Silver --> Quarantine: Quality Check Fail
    Quarantine --> Manual_Review: Data Steward
    Manual_Review --> Silver: Corrected
    Manual_Review --> [*]: Discarded

    note right of Bronze
        Format: Parquet
        Compression: Zstd
        Partitioning: Daily
    end note

    note right of Gold
        Optimized for analytics
        Pre-aggregated metrics
        Partitioned by use case
    end note
```

---

## Scaling Strategy

Horizontal scaling architecture:

```mermaid
graph LR
    subgraph Current["Current Deployment (Demo)"]
        direction TB
        N1[NiFi: 1 node]
        K1[Kafka: 1 broker]
        T1[Trino: 1 coordinator<br/>+ 1 worker]
        S1[Spark: 1 worker]
    end

    subgraph Medium["Medium Scale (100K events/s)"]
        direction TB
        N2[NiFi: 3 nodes]
        K2[Kafka: 3 brokers<br/>+ 3 ZooKeepers]
        T2[Trino: 1 coordinator<br/>+ 4 workers]
        S2[Spark: 4 workers]
    end

    subgraph Large["Large Scale (1M events/s)"]
        direction TB
        N3[NiFi: 5 nodes<br/>+ Load Balancer]
        K3[Kafka: 5 brokers<br/>+ 5 ZooKeepers<br/>+ Kafka Streams]
        T3[Trino: 1 coordinator<br/>+ 10 workers<br/>+ Query Federation]
        S3[Spark: 10 workers<br/>+ Auto-scaling]
    end

    Current -->|Scale Up| Medium
    Medium -->|Scale Up| Large

    style Current fill:#FFE5B4,stroke:#FFB84D,stroke-width:2px
    style Medium fill:#87CEEB,stroke:#4682B4,stroke-width:2px
    style Large fill:#98FB98,stroke:#228B22,stroke-width:2px
```

---

## Disaster Recovery Architecture

Multi-region disaster recovery setup:

```mermaid
graph TB
    subgraph Primary["Primary Region (us-east-1)"]
        direction TB
        P_NiFi[NiFi Cluster]
        P_Kafka[Kafka Cluster]
        P_MinIO[MinIO Primary]
        P_PG[PostgreSQL Primary]
        P_Trino[Trino Cluster]
    end

    subgraph DR["DR Region (us-west-2)"]
        direction TB
        DR_NiFi[NiFi Cluster<br/>Standby]
        DR_Kafka[Kafka Cluster<br/>Mirror Maker]
        DR_MinIO[MinIO Replica<br/>Cross-Region Sync]
        DR_PG[PostgreSQL Standby<br/>Streaming Replication]
        DR_Trino[Trino Cluster<br/>Standby]
    end

    subgraph Backup["Backup Storage (Glacier)"]
        Glacier[S3 Glacier<br/>Long-term Archive<br/>90 Days Retention]
    end

    P_NiFi -.Replication.-> DR_NiFi
    P_Kafka -.MirrorMaker.-> DR_Kafka
    P_MinIO -.Sync.-> DR_MinIO
    P_PG -.Streaming.-> DR_PG
    P_Trino -.Config Sync.-> DR_Trino

    P_MinIO -.Backup.-> Glacier
    P_PG -.Backup.-> Glacier

    style Primary fill:#4CAF50,stroke:#2E7D32,stroke-width:2px,color:#fff
    style DR fill:#FF9800,stroke:#E65100,stroke-width:2px,color:#fff
    style Backup fill:#9E9E9E,stroke:#424242,stroke-width:2px,color:#fff
```

---

## Performance Optimization Flow

Query optimization and caching strategy:

```mermaid
flowchart TD
    Start([User Query]) --> Cache{Check Redis<br/>Cache}

    Cache -->|Hit| Return1[Return Cached<br/>Results]
    Cache -->|Miss| Optimize[Trino Query<br/>Optimization]

    Optimize --> CBO[Cost-Based<br/>Optimizer]
    CBO --> Pushdown[Predicate<br/>Pushdown]
    Pushdown --> Pruning[Partition<br/>Pruning]

    Pruning --> Check{Small Result Set?<br/>< 10MB}

    Check -->|Yes| Parallel1[Parallel Scan<br/>All Workers]
    Check -->|No| Parallel2[Distributed<br/>Hash Join]

    Parallel1 --> Execute[Execute Query]
    Parallel2 --> Execute

    Execute --> Store{Cacheable?<br/>Deterministic}

    Store -->|Yes| Cache_Store[Store in Redis<br/>TTL: 5min]
    Store -->|No| Return2[Return Results<br/>No Cache]

    Cache_Store --> Return3[Return Results]

    Return1 --> End([User Receives<br/>Results])
    Return2 --> End
    Return3 --> End

    style Start fill:#4CAF50,stroke:#2E7D32,stroke-width:2px,color:#fff
    style End fill:#2196F3,stroke:#0D47A1,stroke-width:2px,color:#fff
    style Cache fill:#FFE082,stroke:#F57F17,stroke-width:2px
    style Check fill:#FFE082,stroke:#F57F17,stroke-width:2px
    style Store fill:#FFE082,stroke:#F57F17,stroke-width:2px
```

---

## Additional Resources

- **Main Architecture Document:** [ARCHITECTURE.md](../ARCHITECTURE.md)
- **Architecture Decision Records:** [docs/adr/](./adr/)
- **Operations Runbook:** [docs/operations.md](./operations.md)
- **Network Security:** [docs/security.md](./security.md)

---

**Document Version:** 1.0
**Last Updated:** 2025-02-04
**Rendered Best On:** GitHub (Mermaid support)
