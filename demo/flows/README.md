# NiFi Flow Templates - Portfolio Demo

Conjunto completo de **5 flows de Data Engineering** prontos para importação no Apache NiFi, demonstrando padrões profissionais de pipelines de dados.

## 📦 Flows Disponíveis

### 1. Ingest Orders Pipeline
**Arquivo:** `01-ingest-orders-pipeline.xml`

**Propósito:** Ingestão de pedidos de e-commerce de arquivos CSV para Kafka com validação.

**Arquitetura:**
```
[CSV Files] → ListFile → FetchFile → ConvertRecord (CSV→JSON)
           → ValidateRecord → UpdateAttribute → PublishKafka
           ↳ [Invalid] → LogAttribute
```

**Funcionalidades:**
- ✅ Monitora diretório `/data/orders` a cada 30 segundos
- ✅ Move arquivos processados para `/data/orders/processed`
- ✅ Converte CSV para JSON com validação de schema
- ✅ Adiciona metadados de ingestão (timestamp, source_system, data_version)
- ✅ Publica no tópico Kafka `orders-raw` com compressão Snappy
- ✅ Registros inválidos são logados para análise

**Tópico Kafka:** `orders-raw`

---

### 2. Stream Processing Pipeline
**Arquivo:** `02-stream-processing-pipeline.xml`

**Propósito:** Processamento em tempo real de pedidos do Kafka com enriquecimento e persistência no Iceberg.

**Arquitetura:**
```
[Kafka] → ConsumeKafka → LookupRecord (Customer Enrichment)
       → UpdateRecord (Metadata) → UpdateRecord (Derived Fields)
       → ConvertRecord (Parquet) → PutIceberg
       ↳ [Errors] → LogAttribute
```

**Funcionalidades:**
- ✅ Consome do tópico `orders-raw` (consumer group: `nifi-stream-processor`)
- ✅ Enriquece com dados do cliente via LookupService
- ✅ Adiciona metadados de processamento (processing_timestamp, pipeline_version)
- ✅ Calcula campos derivados (order_date_year, order_date_month, is_high_value)
- ✅ Converte para formato Parquet
- ✅ Persiste na tabela Iceberg `lakehouse.orders_enriched`

**Tabela Iceberg:** `lakehouse.orders_enriched`

---

### 3. Data Quality Pipeline
**Arquivo:** `03-data-quality-pipeline.xml`

**Propósito:** Validação contínua de qualidade de dados com múltiplas regras e detecção de anomalias.

**Arquitetura:**
```
[Iceberg] → ExecuteSQL (Query Recent Orders)
         → QueryRecord (Null Checks) → QueryRecord (Range Checks)
         → LookupRecord (Integrity Checks) → QueryRecord (Anomaly Detection)
         → JoltTransform (Quality Report) → PublishKafka
         ↳ [Violations] → PutFile (Categorized)
```

**Funcionalidades:**
- ✅ Executa a cada 5 minutos
- ✅ Valida registros da última hora
- ✅ **Regras de qualidade:**
  - Null checks: order_id, customer_id, total_amount
  - Range checks: total_amount > 0 AND < 100000
  - Referential integrity: customer_id existe na tabela customers
  - Anomaly detection: customer_exists IS NULL
- ✅ Salva violações em diretórios separados
- ✅ Publica métricas de qualidade no tópico `data-quality-metrics`

**Tópico Kafka:** `data-quality-metrics`

---

### 4. Backup to S3 Pipeline
**Arquivo:** `04-backup-to-s3-pipeline.xml`

**Propósito:** Backup diário automático da tabela Iceberg para storage S3 (MinIO) com retenção de 30 dias.

**Arquitetura:**
```
[Daily Trigger: 2 AM] → GenerateFlowFile → UpdateAttribute (Metadata)
                      → ExecuteSQL (Export) → CompressContent (Gzip)
                      → UpdateAttribute (S3 Path) → PutS3Object
                      → LogAttribute (Success)

[Weekly Cleanup: Sunday 3 AM] → GenerateFlowFile → ListS3 (Old Backups)
                                → DeleteS3Object (>30 days)
```

**Funcionalidades:**
- ✅ **Backup diário:** Executa às 2h AM (CRON: `0 2 * * *`)
- ✅ Exporta tabela completa `lakehouse.orders_enriched` para Parquet
- ✅ Compressão Gzip (nível 9) para otimizar storage
- ✅ Upload para MinIO S3: `s3://lakehouse-backups/backups/YYYY-MM-DD/`
- ✅ **Limpeza automática:** Remove backups > 30 dias aos domingos 3h AM

**Bucket S3:** `lakehouse-backups`

---

### 5. Real-time Aggregation Pipeline
**Arquivo:** `05-realtime-aggregation-pipeline.xml`

**Propósito:** Agregações em tempo real com janelas deslizantes de 5 minutos para KPIs de negócio.

**Arquitetura:**
```
[Kafka] → ConsumeKafka → UpdateRecord (Window Timestamps)
       → PartitionRecord (Window-Region) → QueryRecord (Aggregations)
       → UpdateRecord (Metadata) → PublishKafka + PutDatabaseRecord
       → RouteOnAttribute (Anomaly Detection)
       ↳ [High Revenue] → LogAttribute (Alert)
       ↳ [Low Revenue] → LogAttribute (Alert)
```

**Funcionalidades:**
- ✅ Consome do tópico `orders-raw` (consumer group: `nifi-realtime-aggregator`)
- ✅ Janelas deslizantes de 5 minutos
- ✅ **KPIs calculados:** order_count, total_revenue, avg_order_value, unique_customers
- ✅ Publica agregações no tópico `orders-aggregated-5min`
- ✅ Persiste na tabela Trino `lakehouse.realtime_kpis`
- ✅ **Detecção de anomalias:** High/Low Revenue Alerts

**Tópicos Kafka:** `orders-aggregated-5min`
**Tabela Trino:** `lakehouse.realtime_kpis`

---

## 🚀 Como Criar os Flows (Abordagem Simplificada)

**📖 Guia Recomendado:** [`BUILD_FROM_SCRATCH.md`](./BUILD_FROM_SCRATCH.md)

**⚠️ MUDANÇA DE ABORDAGEM:**
- ✅ **Novo:** Criar flows diretamente no NiFi Canvas (10 min cada)
- ✅ **Versionar** automaticamente no Registry via "Start version control"
- ❌ **Antigo:** Tentar importar XMLs (problemas de compatibilidade)

### Passo 1: Importar Flows para o Registry

Execute o script de importação automatizado:

```bash
./scripts/import-flows.sh
```

O script irá:
- ✅ Criar bucket `demo-flows` no Registry
- ✅ Importar todos os 5 flows XML convertidos
- ✅ Validar cada importação

### Passo 2: Conectar NiFi ao Registry

1. **Acesse o NiFi:**
   ```
   https://localhost:8443/nifi
   Username: nifi
   Password: changeme123
   ```

2. **Adicionar Registry Client:**
   - Menu (☰) → **Controller Settings** → **Registry Clients** → **+**
   - **Name:** Local Registry
   - **URL:** `http://nifi-registry:18080`
   - **Add** → **Apply**

### Passo 3: Importar Flows do Registry

1. **Importar Flow:**
   - Clique direito no canvas → **Version → Import from Registry**
   - **Registry:** Local Registry
   - **Bucket:** demo-flows
   - **Flow:** Selecione um dos 5 flows → **Import**

2. **Repetir para os outros 4 flows**

## ⚙️ Pré-requisitos

### Serviços Necessários

| Flow | Dependências |
|------|--------------|
| **01 - Ingest Orders** | Kafka, Schema Registry, Diretório `/data/orders` |
| **02 - Stream Processing** | Kafka, Iceberg, MinIO, Trino |
| **03 - Data Quality** | Trino, Iceberg, Kafka |
| **04 - Backup to S3** | Trino, MinIO S3, Iceberg |
| **05 - Realtime Aggregation** | Kafka, Trino, Iceberg |

### Criar Tópicos Kafka

```bash
docker exec kafka kafka-topics --create --bootstrap-server localhost:9092 --topic orders-raw --partitions 3
docker exec kafka kafka-topics --create --bootstrap-server localhost:9092 --topic data-quality-metrics --partitions 1
docker exec kafka kafka-topics --create --bootstrap-server localhost:9092 --topic orders-aggregated-5min --partitions 3
```

## 📊 Próximos Passos

1. Importar e versionar todos os 5 flows no NiFi Registry
2. Sincronizar com repositório: `./scripts/sync-flows.sh`
3. Capturar screenshots dos flows em execução
4. Documentar performance (throughput, latência)

---

**Desenvolvido como parte do Data Engineering Portfolio**
