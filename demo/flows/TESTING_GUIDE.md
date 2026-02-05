# Guia de Testes - NiFi Flow Templates

Guia passo a passo para testar cada um dos 5 flows de Data Engineering, com comandos práticos, validações e troubleshooting.

---

## 📋 Pré-requisitos Gerais

### 1. Verificar Serviços Ativos

```bash
# Verificar todos os containers
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Deve mostrar:
# - nifi-1 (ou nifi)
# - nifi-registry
# - kafka
# - trino
# - minio
# - postgres (para NiFi Registry)
```

### 2. Verificar Conectividade

```bash
# NiFi UI
curl -k https://localhost:8443/nifi

# NiFi Registry
curl http://localhost:18080/nifi-registry-api/buckets

# Kafka
docker exec kafka kafka-broker-api-versions --bootstrap-server localhost:9092

# Trino
docker exec trino trino --execute "SHOW CATALOGS"

# MinIO
curl http://localhost:9001
```

### 3. Importar Flows no NiFi

```bash
# 1. Acessar NiFi
https://localhost:8443/nifi
Username: nifi
Password: changeme123

# 2. Para cada flow (01 a 05):
#    - Menu ☰ → Upload Template
#    - Selecionar arquivo XML → Upload
#    - Arrastar ícone Template para canvas
#    - Selecionar template → Add
```

---

## 🧪 Teste 1: Ingest Orders Pipeline

### Objetivo
Validar ingestão de arquivos CSV para Kafka com validação de schema.

### Preparação

```bash
# 1. Criar diretórios
mkdir -p demo/data/orders/input
mkdir -p demo/data/orders/processed

# 2. Criar arquivo CSV de teste
cat > demo/data/orders/input/orders_001.csv << 'EOF'
order_id,customer_id,product_id,quantity,total_amount,order_date,status,region
ORD-001,CUST-101,PROD-A,2,150.00,2026-02-05,completed,North
ORD-002,CUST-102,PROD-B,1,75.50,2026-02-05,pending,South
ORD-003,CUST-103,PROD-C,3,225.75,2026-02-05,completed,East
ORD-004,CUST-104,PROD-D,1,99.99,2026-02-05,cancelled,West
ORD-005,CUST-105,PROD-A,5,375.00,2026-02-05,completed,North
EOF

# 3. Criar tópico Kafka
docker exec kafka kafka-topics --create \
  --bootstrap-server localhost:9092 \
  --topic orders-raw \
  --partitions 3 \
  --replication-factor 1 \
  --if-not-exists

# 4. Verificar tópico criado
docker exec kafka kafka-topics --list --bootstrap-server localhost:9092 | grep orders-raw
```

### Configuração do Flow

```bash
# 1. No NiFi, localize o Process Group "Ingest Orders Pipeline"
# 2. Entre no Process Group (duplo clique)
# 3. Verifique as configurações do ListFile:
#    - Input Directory: /data/orders/input (mapear volume se necessário)
#    - File Filter: orders_.*\.csv
#    - Minimum File Age: 10 sec

# 4. Configurar Controller Services necessários:
#    Menu ☰ → Controller Settings → Controller Services → +

# Adicionar JSONTreeReader:
#    - Name: JsonTreeReader
#    - Type: JsonTreeReader
#    - Schema Access Strategy: Infer Schema

# Adicionar JSONRecordSetWriter:
#    - Name: JsonRecordSetWriter
#    - Type: JsonRecordSetWriter
#    - Schema Write Strategy: Inherit Record Schema

# Adicionar CSVReader:
#    - Name: CSVReader
#    - Type: CSVReader
#    - Schema Access Strategy: Infer Schema
#    - Treat First Line as Header: true

# 5. Habilitar todos os Controller Services (⚡ Enable)
```

### Execução do Teste

```bash
# 1. No NiFi, iniciar o flow:
#    Clique direito no Process Group → Start

# 2. Aguardar processamento (30-60 segundos)

# 3. Verificar processamento no NiFi:
#    - ListFile: deve mostrar 1 arquivo processado (Out: 1)
#    - FetchFile: deve ter lido o arquivo (In: 1, Out: 1)
#    - ConvertRecord: deve ter convertido (In: 1, Out: 1)
#    - ValidateRecord: deve ter validado (Valid: 1)
#    - PublishKafkaRecord: deve ter publicado (Success: 1)

# 4. Verificar arquivo movido
ls -la demo/data/orders/processed/
# Deve conter: orders_001.csv
```

### Validação

```bash
# 1. Verificar mensagens no Kafka
docker exec kafka kafka-console-consumer \
  --bootstrap-server localhost:9092 \
  --topic orders-raw \
  --from-beginning \
  --max-messages 5

# Deve mostrar 5 mensagens JSON:
# {"order_id":"ORD-001","customer_id":"CUST-101",...}
# {"order_id":"ORD-002","customer_id":"CUST-102",...}
# ...

# 2. Verificar metadados das mensagens
docker exec kafka kafka-console-consumer \
  --bootstrap-server localhost:9092 \
  --topic orders-raw \
  --from-beginning \
  --max-messages 1 \
  --property print.key=true \
  --property print.timestamp=true

# 3. Contar total de mensagens
docker exec kafka kafka-run-class kafka.tools.GetOffsetShell \
  --broker-list localhost:9092 \
  --topic orders-raw

# Deve mostrar offset 5 (5 mensagens)
```

### Teste de Validação (Registros Inválidos)

```bash
# 1. Criar arquivo CSV com erros
cat > demo/data/orders/input/orders_invalid.csv << 'EOF'
order_id,customer_id,product_id,quantity,total_amount,order_date,status,region
ORD-006,,PROD-A,2,150.00,2026-02-05,completed,North
ORD-007,CUST-107,PROD-B,1,,2026-02-05,pending,South
EOF

# 2. Aguardar processamento (30 segundos)

# 3. Verificar logs do processador "Log Invalid Records"
#    No NiFi:
#    - Clique direito em "Log Invalid Records"
#    - View Data Provenance
#    - Deve mostrar 2 flowfiles com erros logados
```

### Troubleshooting

**Problema: ListFile não encontra arquivos**
```bash
# Verificar mapeamento de volume
docker inspect nifi-1 | grep -A 10 Mounts

# Deve conter mapeamento de /data/orders
# Se não, adicionar ao docker-compose.yml:
#   volumes:
#     - ./demo/data/orders:/data/orders
```

**Problema: PublishKafka falha com "Connection refused"**
```bash
# Verificar conectividade Kafka de dentro do container NiFi
docker exec nifi-1 nc -zv kafka 9092

# Se falhar, verificar se containers estão na mesma rede
docker network inspect data-lakehouse_backend
```

**Problema: ValidateRecord falha com "Schema not found"**
```bash
# Verificar se CSVReader está configurado com:
# - Schema Access Strategy: Infer Schema
# - Treat First Line as Header: true

# Ou criar schema manualmente no Schema Registry
```

---

## 🧪 Teste 2: Stream Processing Pipeline

### Objetivo
Validar processamento em tempo real: Kafka → Enriquecimento → Iceberg.

### Preparação

```bash
# 1. Certifique-se que Flow 01 está rodando (gerando dados)

# 2. Criar tabela Iceberg no Trino
docker exec -it trino trino --server localhost:8080 --catalog iceberg

# Executar SQL:
CREATE SCHEMA IF NOT EXISTS iceberg.lakehouse;

CREATE TABLE IF NOT EXISTS iceberg.lakehouse.orders_enriched (
    order_id VARCHAR,
    customer_id VARCHAR,
    product_id VARCHAR,
    quantity INTEGER,
    total_amount DOUBLE,
    order_date DATE,
    status VARCHAR,
    region VARCHAR,
    customer_name VARCHAR,
    customer_email VARCHAR,
    processing_timestamp TIMESTAMP,
    pipeline_version VARCHAR,
    order_date_year VARCHAR,
    order_date_month VARCHAR,
    is_high_value BOOLEAN
) WITH (
    format = 'PARQUET',
    partitioning = ARRAY['order_date_year', 'order_date_month'],
    location = 's3a://warehouse/lakehouse/orders_enriched/'
);

# Sair do Trino: \q
```

### Configuração do Flow

```bash
# 1. Configurar Controller Services:

# IcebergCatalogService:
#    - Type: IcebergRESTCatalogService
#    - Catalog URI: http://iceberg-rest:8181
#    - Warehouse Location: s3a://warehouse/

# ParquetReader:
#    - Type: ParquetReader
#    - Schema Access Strategy: Embedded Avro Schema

# ParquetRecordSetWriter:
#    - Type: ParquetRecordSetWriter
#    - Schema Write Strategy: Inherit Record Schema

# CustomerLookupService (Opcional - criar tabela customers primeiro):
#    - Type: DatabaseRecordLookupService
#    - Database Connection Pool: PostgreSQL Connection Pool
#    - Table Name: customers
#    - Lookup Key Column: customer_id

# 2. Habilitar todos os Controller Services
```

### Execução do Teste

```bash
# 1. Gerar dados de teste (usar Flow 01)
cat > demo/data/orders/input/orders_stream_test.csv << 'EOF'
order_id,customer_id,product_id,quantity,total_amount,order_date,status,region
ORD-101,CUST-201,PROD-A,2,1500.00,2026-02-05,completed,North
ORD-102,CUST-202,PROD-B,1,750.50,2026-02-05,pending,South
ORD-103,CUST-203,PROD-C,3,2257.75,2026-02-05,completed,East
EOF

# 2. Aguardar Flow 01 publicar no Kafka (30 segundos)

# 3. Iniciar Flow 02:
#    Clique direito no Process Group → Start

# 4. Monitorar processamento:
#    - ConsumeKafkaRecord: deve consumir mensagens (Out > 0)
#    - LookupRecord: deve enriquecer (Success > 0)
#    - PutIceberg: deve persistir (Success > 0)
```

### Validação

```bash
# 1. Verificar dados no Iceberg via Trino
docker exec -it trino trino --server localhost:8080 --catalog iceberg

SELECT
    order_id,
    customer_id,
    total_amount,
    is_high_value,
    processing_timestamp,
    order_date_year,
    order_date_month
FROM iceberg.lakehouse.orders_enriched
ORDER BY processing_timestamp DESC
LIMIT 10;

# Deve mostrar os 3 registros processados com:
# - is_high_value = true para ORD-101 e ORD-103 (> $1000)
# - order_date_year = '2026'
# - order_date_month = '02'
# - processing_timestamp preenchido

# 2. Verificar particionamento
SELECT
    order_date_year,
    order_date_month,
    COUNT(*) as record_count,
    SUM(total_amount) as total_revenue
FROM iceberg.lakehouse.orders_enriched
GROUP BY order_date_year, order_date_month;

# 3. Verificar arquivos no MinIO
# Acessar: http://localhost:9001
# Bucket: warehouse
# Path: lakehouse/orders_enriched/order_date_year=2026/order_date_month=02/
# Deve conter arquivos .parquet
```

### Teste de Performance

```bash
# 1. Gerar carga maior (1000 registros)
python << 'EOF'
import csv
import random
from datetime import datetime, timedelta

with open('demo/data/orders/input/orders_load_test.csv', 'w', newline='') as f:
    writer = csv.writer(f)
    writer.writerow(['order_id', 'customer_id', 'product_id', 'quantity', 'total_amount', 'order_date', 'status', 'region'])

    regions = ['North', 'South', 'East', 'West']
    statuses = ['completed', 'pending', 'cancelled']

    for i in range(1000):
        order_id = f'ORD-{10000+i}'
        customer_id = f'CUST-{random.randint(1000, 9999)}'
        product_id = f'PROD-{random.choice(["A", "B", "C", "D", "E"])}'
        quantity = random.randint(1, 10)
        total_amount = round(random.uniform(10, 5000), 2)
        order_date = (datetime.now() - timedelta(days=random.randint(0, 30))).strftime('%Y-%m-%d')
        status = random.choice(statuses)
        region = random.choice(regions)

        writer.writerow([order_id, customer_id, product_id, quantity, total_amount, order_date, status, region])

print("Gerados 1000 registros de teste")
EOF

# 2. Aguardar processamento completo (2-3 minutos)

# 3. Verificar throughput no NiFi
#    - Visualizar Statistics no canvas
#    - Verificar In/Out por segundo

# 4. Verificar total de registros no Iceberg
docker exec trino trino --execute "SELECT COUNT(*) FROM iceberg.lakehouse.orders_enriched"
# Deve mostrar >= 1000
```

### Troubleshooting

**Problema: ConsumeKafka não consome mensagens**
```bash
# Verificar consumer group
docker exec kafka kafka-consumer-groups \
  --bootstrap-server localhost:9092 \
  --group nifi-stream-processor \
  --describe

# Resetar offsets se necessário
docker exec kafka kafka-consumer-groups \
  --bootstrap-server localhost:9092 \
  --group nifi-stream-processor \
  --reset-offsets \
  --to-earliest \
  --topic orders-raw \
  --execute
```

**Problema: PutIceberg falha com "Table not found"**
```bash
# Verificar se tabela existe
docker exec trino trino --execute "SHOW TABLES FROM iceberg.lakehouse"

# Verificar se IcebergCatalogService está habilitado
# Verificar logs do NiFi:
docker logs nifi-1 | grep -i "iceberg\|catalog"
```

---

## 🧪 Teste 3: Data Quality Pipeline

### Objetivo
Validar regras de qualidade de dados e detecção de anomalias.

### Preparação

```bash
# 1. Certifique-se que Flow 02 já populou a tabela orders_enriched

# 2. Criar diretórios para violações
mkdir -p demo/data/quality-violations/null-checks
mkdir -p demo/data/quality-violations/range-checks
mkdir -p demo/data/quality-violations/anomalies

# 3. Criar tópico para métricas
docker exec kafka kafka-topics --create \
  --bootstrap-server localhost:9092 \
  --topic data-quality-metrics \
  --partitions 1 \
  --replication-factor 1 \
  --if-not-exists

# 4. Inserir dados de teste com violações
docker exec -it trino trino --server localhost:8080 --catalog iceberg

INSERT INTO iceberg.lakehouse.orders_enriched VALUES
-- Registro válido
('ORD-VALID', 'CUST-001', 'PROD-A', 1, 100.00, DATE '2026-02-05', 'completed', 'North', 'John Doe', 'john@example.com', TIMESTAMP '2026-02-05 12:00:00', 'v1.0', '2026', '02', false),
-- Null violation: customer_id NULL
('ORD-NULL-01', NULL, 'PROD-B', 1, 150.00, DATE '2026-02-05', 'completed', 'South', NULL, NULL, TIMESTAMP '2026-02-05 12:01:00', 'v1.0', '2026', '02', false),
-- Range violation: total_amount > 100000
('ORD-RANGE-01', 'CUST-002', 'PROD-C', 100, 150000.00, DATE '2026-02-05', 'completed', 'East', 'Jane Smith', 'jane@example.com', TIMESTAMP '2026-02-05 12:02:00', 'v1.0', '2026', '02', true),
-- Range violation: total_amount <= 0
('ORD-RANGE-02', 'CUST-003', 'PROD-D', 1, -50.00, DATE '2026-02-05', 'refunded', 'West', 'Bob Johnson', 'bob@example.com', TIMESTAMP '2026-02-05 12:03:00', 'v1.0', '2026', '02', false);

# Verificar inserção
SELECT order_id, customer_id, total_amount FROM iceberg.lakehouse.orders_enriched
WHERE order_id LIKE 'ORD-%'
ORDER BY processing_timestamp DESC
LIMIT 5;
```

### Configuração do Flow

```bash
# 1. Configurar Controller Services:

# TrinoConnectionPool:
#    - Type: DBCPConnectionPool
#    - Database Connection URL: jdbc:trino://trino:8080/iceberg
#    - Database Driver Class Name: io.trino.jdbc.TrinoDriver
#    - Database Driver Location: /opt/nifi/lib/trino-jdbc-*.jar

# 2. Habilitar Controller Services

# 3. Ajustar schedule do ExecuteSQL:
#    - Scheduling: 5 min (para teste, pode alterar para 1 min)
```

### Execução do Teste

```bash
# 1. Iniciar Flow 03:
#    Clique direito no Process Group → Start

# 2. Aguardar primeira execução (5 minutos ou 1 minuto se alterado)

# 3. Forçar execução imediata (opcional):
#    - Clique direito no processador "Query Recent Orders"
#    - Run Once

# 4. Monitorar execução:
#    - Query Recent Orders: deve executar query (Out > 0)
#    - Check Null Values: deve identificar violations
#    - Check Value Ranges: deve identificar violations
#    - Generate Quality Report: deve criar relatório (Success > 0)
#    - Publish Quality Metrics: deve publicar no Kafka (Success > 0)
```

### Validação

```bash
# 1. Verificar violações salvas em arquivos

# Null violations
ls -lh demo/data/quality-violations/null-checks/
cat demo/data/quality-violations/null-checks/* | head -20

# Range violations
ls -lh demo/data/quality-violations/range-checks/
cat demo/data/quality-violations/range-checks/* | head -20

# Anomalies
ls -lh demo/data/quality-violations/anomalies/
cat demo/data/quality-violations/anomalies/* | head -20

# 2. Verificar métricas no Kafka
docker exec kafka kafka-console-consumer \
  --bootstrap-server localhost:9092 \
  --topic data-quality-metrics \
  --from-beginning \
  --max-messages 5 | jq '.'

# Deve mostrar JSON com estrutura:
# {
#   "quality_checks": [
#     {
#       "order_id": "ORD-VALID",
#       "total_amount": 100.00,
#       "referential_integrity_passed": true
#     },
#     ...
#   ]
# }

# 3. Contar violações por tipo
echo "Null Violations:"
docker exec kafka kafka-console-consumer \
  --bootstrap-server localhost:9092 \
  --topic data-quality-metrics \
  --from-beginning \
  --timeout-ms 5000 | grep -c "null_violations" || echo 0

echo "Range Violations:"
docker exec kafka kafka-console-consumer \
  --bootstrap-server localhost:9092 \
  --topic data-quality-metrics \
  --from-beginning \
  --timeout-ms 5000 | grep -c "range_violations" || echo 0
```

### Teste de Regras Específicas

```bash
# 1. Teste Null Check: Inserir registro sem order_id
docker exec trino trino --execute "
INSERT INTO iceberg.lakehouse.orders_enriched VALUES
(NULL, 'CUST-999', 'PROD-Z', 1, 50.00, DATE '2026-02-05', 'completed', 'North', 'Test User', 'test@example.com', TIMESTAMP '2026-02-05 13:00:00', 'v1.0', '2026', '02', false)
"

# Aguardar execução do flow (1-5 min)
# Verificar se apareceu em null-checks/

# 2. Teste Range Check: Inserir pedido de $200,000
docker exec trino trino --execute "
INSERT INTO iceberg.lakehouse.orders_enriched VALUES
('ORD-HUGE', 'CUST-888', 'PROD-LUXURY', 100, 200000.00, DATE '2026-02-05', 'completed', 'North', 'Rich Person', 'rich@example.com', TIMESTAMP '2026-02-05 13:05:00', 'v1.0', '2026', '02', true)
"

# Aguardar execução
# Verificar se apareceu em range-checks/

# 3. Teste Anomaly Detection: Cliente inexistente
# (Este teste assume que CustomerLookupService está configurado)
docker exec trino trino --execute "
INSERT INTO iceberg.lakehouse.orders_enriched VALUES
('ORD-GHOST', 'CUST-NONEXISTENT', 'PROD-A', 1, 100.00, DATE '2026-02-05', 'completed', 'North', NULL, NULL, TIMESTAMP '2026-02-05 13:10:00', 'v1.0', '2026', '02', false)
"

# Aguardar execução
# Verificar se apareceu em anomalies/
```

### Métricas de Qualidade

```bash
# Calcular taxa de sucesso
docker exec -it trino trino --server localhost:8080 --catalog iceberg

SELECT
    COUNT(*) as total_records,
    COUNT(CASE WHEN customer_id IS NOT NULL AND order_id IS NOT NULL AND total_amount IS NOT NULL THEN 1 END) as passed_null_checks,
    COUNT(CASE WHEN total_amount > 0 AND total_amount < 100000 THEN 1 END) as passed_range_checks,
    ROUND(100.0 * COUNT(CASE WHEN customer_id IS NOT NULL AND order_id IS NOT NULL AND total_amount IS NOT NULL THEN 1 END) / COUNT(*), 2) as null_check_pass_rate,
    ROUND(100.0 * COUNT(CASE WHEN total_amount > 0 AND total_amount < 100000 THEN 1 END) / COUNT(*), 2) as range_check_pass_rate
FROM iceberg.lakehouse.orders_enriched
WHERE processing_timestamp >= CURRENT_TIMESTAMP - INTERVAL '1' HOUR;

# Resultado esperado:
# total_records | passed_null_checks | passed_range_checks | null_check_pass_rate | range_check_pass_rate
# -------------+--------------------+---------------------+---------------------+----------------------
#     1007     |        1005        |         1005        |        99.80        |         99.80
```

### Troubleshooting

**Problema: ExecuteSQL não retorna dados**
```bash
# Verificar query manualmente
docker exec trino trino --execute "
SELECT * FROM iceberg.lakehouse.orders_enriched
WHERE processing_timestamp >= CURRENT_TIMESTAMP - INTERVAL '1' HOUR
LIMIT 5
"

# Se retornar vazio, ajustar intervalo de tempo:
# processing_timestamp >= CURRENT_TIMESTAMP - INTERVAL '24' HOUR
```

**Problema: PutFile falha com "Permission denied"**
```bash
# Verificar permissões de diretórios
ls -la demo/data/quality-violations/

# Ajustar permissões
chmod -R 777 demo/data/quality-violations/

# Ou verificar mapeamento de volume no docker-compose.yml
```

---

## 🧪 Teste 4: Backup to S3 Pipeline

### Objetivo
Validar backup automático para MinIO S3 com compressão e retenção.

### Preparação

```bash
# 1. Criar bucket no MinIO
docker exec minio mc alias set local http://localhost:9000 minioadmin minioadmin
docker exec minio mc mb local/lakehouse-backups --ignore-existing

# Ou via Console Web:
# http://localhost:9001
# Username: minioadmin
# Password: minioadmin
# Criar bucket: lakehouse-backups

# 2. Verificar bucket criado
docker exec minio mc ls local/

# Deve mostrar: [DATE] lakehouse-backups/
```

### Configuração do Flow

```bash
# 1. Configurar Controller Services:

# AWSCredentialsProviderControllerService:
#    - Type: AWSCredentialsProviderControllerService
#    - Access Key ID: minioadmin
#    - Secret Access Key: minioadmin
#    - Region: us-east-1

# TrinoConnectionPool (se ainda não configurado):
#    - Database Connection URL: jdbc:trino://trino:8080/iceberg
#    - Database Driver Class Name: io.trino.jdbc.TrinoDriver

# ParquetRecordSetWriter (se ainda não configurado)

# 2. Habilitar Controller Services

# 3. Ajustar schedule para teste:
#    - Processador "Daily Backup Trigger"
#    - Scheduling Strategy: Timer Driven
#    - Run Schedule: 30 sec (em vez de CRON para teste)
```

### Execução do Teste

```bash
# 1. Iniciar Flow 04:
#    Clique direito no Process Group → Start

# 2. Aguardar execução (30-60 segundos)

# 3. Monitorar execução:
#    - Daily Backup Trigger: deve gerar trigger (Out: 1)
#    - Export Orders Table: deve exportar dados (Success: 1)
#    - Compress with Gzip: deve comprimir (Success: 1)
#    - Upload to MinIO S3: deve fazer upload (Success: 1)
#    - Log Backup Success: deve logar (Success: 1)

# 4. Verificar logs do "Log Backup Success"
#    - Clique direito → View Data Provenance
#    - Verificar atributos: backup.timestamp, s3.object.key, file.size
```

### Validação

```bash
# 1. Listar backups no MinIO
docker exec minio mc ls local/lakehouse-backups/backups/ --recursive

# Deve mostrar:
# [DATE] [SIZE] backups/2026-02-05/orders_enriched_2026-02-05_HHMMSS.parquet.gz

# 2. Verificar tamanho do arquivo
docker exec minio mc stat local/lakehouse-backups/backups/2026-02-05/orders_enriched_*.parquet.gz

# Deve mostrar:
# Name      : orders_enriched_2026-02-05_120000.parquet.gz
# Size      : [SIZE] KB
# ETag      : [ETAG]
# Type      : file
# Metadata  :
#   Content-Type: application/gzip

# 3. Download e verificar integridade
docker exec minio mc cp \
  local/lakehouse-backups/backups/2026-02-05/orders_enriched_*.parquet.gz \
  /tmp/backup_test.parquet.gz

# Descomprimir
docker exec minio gunzip /tmp/backup_test.parquet.gz

# Verificar arquivo Parquet
docker exec trino trino --execute "
SELECT * FROM parquet.parquet_files.read_parquet('/tmp/backup_test.parquet')
LIMIT 5
"

# 4. Verificar compressão (comparar tamanhos)
echo "Tamanho original (Iceberg):"
docker exec trino trino --execute "
SELECT COUNT(*) as record_count,
       ROUND(SUM(LENGTH(CAST(ROW(order_id, customer_id, total_amount) AS VARCHAR))) / 1024.0 / 1024.0, 2) as estimated_size_mb
FROM iceberg.lakehouse.orders_enriched
"

echo "Tamanho backup comprimido:"
docker exec minio mc stat local/lakehouse-backups/backups/2026-02-05/orders_enriched_*.parquet.gz | grep Size

# Calcular taxa de compressão (deve ser ~10:1 ou melhor)
```

### Teste de Cleanup (Retenção 30 dias)

```bash
# 1. Simular backup antigo (criando arquivo manualmente)
docker exec minio sh -c "
echo 'fake old backup' | mc pipe local/lakehouse-backups/backups/2026-01-01/orders_enriched_2026-01-01_020000.parquet.gz
"

# 2. Verificar backups antes da limpeza
docker exec minio mc ls local/lakehouse-backups/backups/ --recursive

# Deve mostrar 2 backups:
# - backups/2026-02-05/... (recente)
# - backups/2026-01-01/... (antigo, > 30 dias)

# 3. Configurar teste de cleanup:
#    - Processador "Weekly Cleanup Trigger"
#    - Alterar schedule para "30 sec" (teste)
#    - Processador "List Backups Older Than 30 Days"
#    - Alterar "min-age" para "1 day" (teste)

# 4. Iniciar cleanup (Run Once no "Weekly Cleanup Trigger")

# 5. Aguardar execução (30 segundos)

# 6. Verificar backups após limpeza
docker exec minio mc ls local/lakehouse-backups/backups/ --recursive

# Deve mostrar apenas:
# - backups/2026-02-05/... (recente mantido)
# (backup antigo de 2026-01-01 foi deletado)

# 7. Verificar logs do DeleteS3Object
#    - Deve mostrar 1 objeto deletado
```

### Teste de Recovery (Restauração)

```bash
# 1. Download do backup
mkdir -p /tmp/restore_test
docker exec minio mc cp \
  local/lakehouse-backups/backups/2026-02-05/orders_enriched_*.parquet.gz \
  /tmp/restore_test/

# 2. Descomprimir
gunzip /tmp/restore_test/orders_enriched_*.parquet.gz

# 3. Criar tabela temporária para restore
docker exec -it trino trino --server localhost:8080 --catalog iceberg

CREATE TABLE iceberg.lakehouse.orders_restored (
    order_id VARCHAR,
    customer_id VARCHAR,
    product_id VARCHAR,
    quantity INTEGER,
    total_amount DOUBLE,
    order_date DATE,
    status VARCHAR,
    region VARCHAR,
    customer_name VARCHAR,
    customer_email VARCHAR,
    processing_timestamp TIMESTAMP,
    pipeline_version VARCHAR,
    order_date_year VARCHAR,
    order_date_month VARCHAR,
    is_high_value BOOLEAN
) WITH (
    format = 'PARQUET',
    location = 's3a://warehouse/lakehouse/orders_restored/'
);

# 4. Copiar arquivo Parquet restaurado para MinIO
docker exec minio mc cp \
  /tmp/restore_test/orders_enriched_*.parquet \
  local/warehouse/lakehouse/orders_restored/

# 5. Verificar dados restaurados
SELECT COUNT(*) as restored_count
FROM iceberg.lakehouse.orders_restored;

# 6. Comparar com original
SELECT
    (SELECT COUNT(*) FROM iceberg.lakehouse.orders_enriched) as original_count,
    (SELECT COUNT(*) FROM iceberg.lakehouse.orders_restored) as restored_count,
    CASE
        WHEN (SELECT COUNT(*) FROM iceberg.lakehouse.orders_enriched) = (SELECT COUNT(*) FROM iceberg.lakehouse.orders_restored)
        THEN 'BACKUP VÁLIDO ✓'
        ELSE 'BACKUP COM DIFERENÇAS ✗'
    END as validation_result;
```

### Teste de CRON (Produção)

```bash
# 1. Restaurar configuração original:
#    - Processador "Daily Backup Trigger"
#    - Scheduling Strategy: CRON Driven
#    - Run Schedule: 0 2 * * * (2h AM todos os dias)

# 2. Processar "Weekly Cleanup Trigger"
#    - Scheduling Strategy: CRON Driven
#    - Run Schedule: 0 3 * * 0 (3h AM aos domingos)

# 3. Simular execução CRON (não aguardar 2h):
#    - Alterar temporariamente para próximo minuto:
#    - Exemplo: Se são 15:30, configurar para: 31 15 * * *
#    - Aguardar 1 minuto
#    - Verificar se executou
#    - Restaurar para 0 2 * * *

# 4. Verificar histórico de execuções
#    - Menu ☰ → Flow Configuration History
#    - Filtrar por "Backup"
#    - Deve mostrar execuções com timestamps
```

### Troubleshooting

**Problema: Upload to MinIO falha com "Access Denied"**
```bash
# Verificar credenciais MinIO
docker exec minio mc admin user list local

# Verificar se bucket tem permissões corretas
docker exec minio mc anonymous set download local/lakehouse-backups

# Testar upload manual
docker exec minio sh -c "
echo 'test' | mc pipe local/lakehouse-backups/test.txt
mc ls local/lakehouse-backups/
mc rm local/lakehouse-backups/test.txt
"
```

**Problema: CompressContent muito lento**
```bash
# Verificar tamanho dos dados
docker exec trino trino --execute "
SELECT COUNT(*) as record_count,
       ROUND(SUM(LENGTH(CAST(order_id AS VARCHAR)) +
                 LENGTH(CAST(customer_id AS VARCHAR)) +
                 LENGTH(CAST(total_amount AS VARCHAR))) / 1024.0 / 1024.0, 2) as estimated_size_mb
FROM iceberg.lakehouse.orders_enriched
"

# Se > 1GB, considerar:
# - Reduzir Compression Level de 9 para 6
# - Adicionar mais concurrent tasks no processador
# - Particionar dados antes de comprimir
```

---

## 🧪 Teste 5: Real-time Aggregation Pipeline

### Objetivo
Validar agregações em tempo real com janelas deslizantes de 5 minutos.

### Preparação

```bash
# 1. Criar tópico para agregações
docker exec kafka kafka-topics --create \
  --bootstrap-server localhost:9092 \
  --topic orders-aggregated-5min \
  --partitions 3 \
  --replication-factor 1 \
  --if-not-exists

# 2. Criar tabela para KPIs
docker exec -it trino trino --server localhost:8080 --catalog iceberg

CREATE TABLE IF NOT EXISTS iceberg.lakehouse.realtime_kpis (
    window_start TIMESTAMP,
    window_end TIMESTAMP,
    region VARCHAR,
    order_count BIGINT,
    total_revenue DOUBLE,
    avg_order_value DOUBLE,
    min_order_value DOUBLE,
    max_order_value DOUBLE,
    unique_customers BIGINT,
    computed_at TIMESTAMP,
    aggregation_type VARCHAR,
    pipeline_version VARCHAR
) WITH (
    format = 'PARQUET',
    location = 's3a://warehouse/lakehouse/realtime_kpis/'
);

# 3. Certifique-se que Flow 01 está rodando (gerando dados)
```

### Configuração do Flow

```bash
# 1. Configurar Controller Services (se ainda não configurados):
#    - JsonTreeReader
#    - JsonRecordSetWriter
#    - TrinoConnectionPool

# 2. Habilitar Controller Services

# 3. Configurar consumidor Kafka:
#    - Processador "Consume Orders Stream"
#    - Verificar group.id: nifi-realtime-aggregator
#    - Verificar auto.offset.reset: latest
```

### Execução do Teste

```bash
# 1. Gerar dados com volume para teste
cat > demo/data/orders/input/orders_aggregation_test.csv << 'EOF'
order_id,customer_id,product_id,quantity,total_amount,order_date,status,region
ORD-AGG-001,CUST-A01,PROD-X,2,150.00,2026-02-05,completed,North
ORD-AGG-002,CUST-A02,PROD-Y,1,75.50,2026-02-05,completed,North
ORD-AGG-003,CUST-A03,PROD-Z,3,225.75,2026-02-05,completed,North
ORD-AGG-004,CUST-B01,PROD-X,1,99.99,2026-02-05,completed,South
ORD-AGG-005,CUST-B02,PROD-Y,5,375.00,2026-02-05,completed,South
ORD-AGG-006,CUST-C01,PROD-Z,2,180.00,2026-02-05,completed,East
ORD-AGG-007,CUST-C02,PROD-X,1,50.00,2026-02-05,completed,East
ORD-AGG-008,CUST-D01,PROD-Y,4,320.00,2026-02-05,completed,West
ORD-AGG-009,CUST-D02,PROD-Z,1,95.00,2026-02-05,completed,West
ORD-AGG-010,CUST-A04,PROD-X,10,1000.00,2026-02-05,completed,North
EOF

# 2. Aguardar Flow 01 processar e publicar no Kafka (30 segundos)

# 3. Iniciar Flow 05:
#    Clique direito no Process Group → Start

# 4. Aguardar acumular janela completa (5 minutos)

# 5. Monitorar execução:
#    - Consume Orders Stream: deve consumir (Out > 0)
#    - Add Window Timestamp: deve adicionar timestamps (Success > 0)
#    - Partition by Window-Region: deve particionar (Success > 0)
#    - Calculate KPIs: deve agregar (aggregated > 0)
#    - Publish to Aggregated Topic: deve publicar (Success > 0)
#    - Write to Trino: deve persistir (Success > 0)
```

### Validação

```bash
# 1. Verificar agregações no Kafka
docker exec kafka kafka-console-consumer \
  --bootstrap-server localhost:9092 \
  --topic orders-aggregated-5min \
  --from-beginning \
  --max-messages 10 | jq '.'

# Deve mostrar JSON com estrutura:
# {
#   "window_start": "2026-02-05 19:25:00",
#   "window_end": "2026-02-05 19:30:00",
#   "region": "North",
#   "order_count": 4,
#   "total_revenue": 1425.00,
#   "avg_order_value": 356.25,
#   "min_order_value": 75.50,
#   "max_order_value": 1000.00,
#   "unique_customers": 4,
#   "computed_at": "2026-02-05 19:30:15",
#   "aggregation_type": "5min_sliding_window",
#   "pipeline_version": "v1.0"
# }

# 2. Verificar KPIs no Trino
docker exec -it trino trino --server localhost:8080 --catalog iceberg

SELECT
    window_start,
    window_end,
    region,
    order_count,
    ROUND(total_revenue, 2) as total_revenue,
    ROUND(avg_order_value, 2) as avg_order_value,
    unique_customers
FROM iceberg.lakehouse.realtime_kpis
ORDER BY window_start DESC, region
LIMIT 20;

# Resultado esperado (valores aproximados):
# window_start         | window_end           | region | order_count | total_revenue | avg_order_value | unique_customers
# --------------------+---------------------+--------+-------------+---------------+-----------------+-----------------
# 2026-02-05 19:25:00 | 2026-02-05 19:30:00 | North  |      4      |    1425.00    |     356.25      |        4
# 2026-02-05 19:25:00 | 2026-02-05 19:30:00 | South  |      2      |     474.99    |     237.50      |        2
# 2026-02-05 19:25:00 | 2026-02-05 19:30:00 | East   |      2      |     230.00    |     115.00      |        2
# 2026-02-05 19:25:00 | 2026-02-05 19:30:00 | West   |      2      |     415.00    |     207.50      |        2

# 3. Validar cálculos manualmente
docker exec trino trino --execute "
SELECT
    region,
    COUNT(*) as order_count_validation,
    SUM(total_amount) as total_revenue_validation,
    AVG(total_amount) as avg_order_value_validation,
    MIN(total_amount) as min_order_value_validation,
    MAX(total_amount) as max_order_value_validation,
    COUNT(DISTINCT customer_id) as unique_customers_validation
FROM iceberg.lakehouse.orders_enriched
WHERE processing_timestamp >= TIMESTAMP '2026-02-05 19:25:00'
  AND processing_timestamp < TIMESTAMP '2026-02-05 19:30:00'
GROUP BY region
ORDER BY region
"

# Comparar valores com tabela realtime_kpis
# Devem ser idênticos (ou muito próximos)
```

### Teste de Detecção de Anomalias

```bash
# 1. Gerar pedido de alto valor (> $50,000)
cat > demo/data/orders/input/orders_high_revenue.csv << 'EOF'
order_id,customer_id,product_id,quantity,total_amount,order_date,status,region
ORD-HIGH-001,CUST-VIP-001,PROD-LUXURY,1,75000.00,2026-02-05,completed,North
EOF

# Aguardar processamento (30 segundos)

# 2. Verificar se alert foi gerado
#    No NiFi:
#    - Processador "Alert: High Revenue Window"
#    - Clique direito → View Data Provenance
#    - Deve mostrar 1 flowfile com log de alerta

# Verificar logs do NiFi
docker logs nifi-1 | grep "HIGH_REVENUE_ALERT" | tail -5

# Deve mostrar:
# HIGH_REVENUE_ALERT: window_start=2026-02-05 19:30:00, region=North, total_revenue=75000.00

# 3. Gerar pedido de baixo valor (< $1,000)
cat > demo/data/orders/input/orders_low_revenue.csv << 'EOF'
order_id,customer_id,product_id,quantity,total_amount,order_date,status,region
ORD-LOW-001,CUST-001,PROD-SAMPLE,1,5.00,2026-02-05,completed,South
ORD-LOW-002,CUST-002,PROD-SAMPLE,1,3.50,2026-02-05,completed,South
EOF

# Aguardar processamento + janela completa (5+ minutos)

# 4. Verificar alert de baixa receita
docker logs nifi-1 | grep "LOW_REVENUE_ALERT" | tail -5

# Deve mostrar:
# LOW_REVENUE_ALERT: window_start=2026-02-05 19:35:00, region=South, total_revenue=8.50
```

### Teste de Performance (Carga Alta)

```bash
# 1. Gerar 10,000 pedidos em 10 minutos (16.7 pedidos/segundo)
python << 'EOF'
import csv
import random
from datetime import datetime

regions = ['North', 'South', 'East', 'West']
statuses = ['completed', 'pending', 'cancelled']

with open('demo/data/orders/input/orders_load_test_agg.csv', 'w', newline='') as f:
    writer = csv.writer(f)
    writer.writerow(['order_id', 'customer_id', 'product_id', 'quantity', 'total_amount', 'order_date', 'status', 'region'])

    for i in range(10000):
        order_id = f'ORD-LOAD-{i:06d}'
        customer_id = f'CUST-{random.randint(1, 1000):04d}'
        product_id = f'PROD-{random.choice(["A", "B", "C", "D", "E"])}'
        quantity = random.randint(1, 5)
        total_amount = round(random.uniform(10, 2000), 2)
        order_date = datetime.now().strftime('%Y-%m-%d')
        status = random.choices(statuses, weights=[80, 15, 5])[0]
        region = random.choices(regions, weights=[40, 30, 20, 10])[0]

        writer.writerow([order_id, customer_id, product_id, quantity, total_amount, order_date, status, region])

print("Gerados 10,000 pedidos para teste de carga")
EOF

# 2. Aguardar processamento completo (10-15 minutos)

# 3. Verificar throughput no Kafka
docker exec kafka kafka-consumer-groups \
  --bootstrap-server localhost:9092 \
  --group nifi-realtime-aggregator \
  --describe

# Verificar LAG (deve estar próximo de 0)

# 4. Contar agregações geradas
docker exec trino trino --execute "
SELECT
    COUNT(DISTINCT window_start) as total_windows,
    COUNT(*) as total_aggregations,
    MIN(window_start) as first_window,
    MAX(window_start) as last_window
FROM iceberg.lakehouse.realtime_kpis
"

# Deve mostrar ~10-15 janelas diferentes (10-15 minutos de dados)

# 5. Verificar latência de agregação
docker exec trino trino --execute "
SELECT
    window_end,
    computed_at,
    CAST(computed_at - window_end AS VARCHAR) as latency
FROM iceberg.lakehouse.realtime_kpis
ORDER BY computed_at DESC
LIMIT 10
"

# Latência deve ser < 30 segundos (tempo para completar janela + processamento)
```

### Validar Janelas Deslizantes

```bash
# 1. Verificar se janelas se sobrepõem (sliding windows)
docker exec trino trino --execute "
SELECT
    window_start,
    window_end,
    region,
    order_count
FROM iceberg.lakehouse.realtime_kpis
WHERE region = 'North'
ORDER BY window_start DESC
LIMIT 10
"

# Janelas devem avançar de 5 em 5 minutos:
# 19:25:00 - 19:30:00
# 19:30:00 - 19:35:00
# 19:35:00 - 19:40:00
# etc.

# 2. Verificar particionamento por região
docker exec trino trino --execute "
SELECT
    region,
    COUNT(DISTINCT window_start) as window_count,
    SUM(order_count) as total_orders,
    ROUND(SUM(total_revenue), 2) as total_revenue
FROM iceberg.lakehouse.realtime_kpis
GROUP BY region
ORDER BY total_revenue DESC
"

# Deve mostrar distribuição por região (North deve ter mais dados se weights=[40,30,20,10])
```

### Troubleshooting

**Problema: Calculate KPIs não gera output**
```bash
# Verificar se SQL de agregação está correto
# Testar query manualmente no Trino (substituir FLOWFILE por tabela real):
docker exec trino trino --execute "
SELECT
    '2026-02-05 19:25:00' as window_start,
    '2026-02-05 19:30:00' as window_end,
    region,
    COUNT(*) as order_count,
    SUM(total_amount) as total_revenue,
    AVG(total_amount) as avg_order_value,
    MIN(total_amount) as min_order_value,
    MAX(total_amount) as max_order_value,
    COUNT(DISTINCT customer_id) as unique_customers
FROM iceberg.lakehouse.orders_enriched
WHERE processing_timestamp >= TIMESTAMP '2026-02-05 19:25:00'
  AND processing_timestamp < TIMESTAMP '2026-02-05 19:30:00'
GROUP BY region
"

# Se query funciona manualmente, verificar configuração do QueryRecord
```

**Problema: Janelas com timestamps errados**
```bash
# Verificar Expression Language do "Add Window Timestamp"
# Testar cálculo de janela:
python << 'EOF'
from datetime import datetime

now = datetime.now()
timestamp_ms = int(now.timestamp() * 1000)
window_size_ms = 300000  # 5 minutos

window_start_ms = (timestamp_ms // window_size_ms) * window_size_ms
window_end_ms = window_start_ms + window_size_ms

window_start = datetime.fromtimestamp(window_start_ms / 1000)
window_end = datetime.fromtimestamp(window_end_ms / 1000)

print(f"Now: {now}")
print(f"Window Start: {window_start}")
print(f"Window End: {window_end}")
EOF

# Comparar com timestamps gerados no flow
```

---

## 📊 Relatório Final de Testes

Após executar todos os testes, compile um relatório com:

### Métricas de Sucesso

```bash
# Flow 01: Ingest Orders
echo "=== Flow 01: Ingest Orders Pipeline ==="
docker exec kafka kafka-run-class kafka.tools.GetOffsetShell \
  --broker-list localhost:9092 \
  --topic orders-raw | awk -F':' '{sum+=$3} END {print "Total Mensagens Kafka:", sum}'

# Flow 02: Stream Processing
echo "=== Flow 02: Stream Processing Pipeline ==="
docker exec trino trino --execute "
SELECT
    COUNT(*) as total_records,
    MIN(processing_timestamp) as first_processed,
    MAX(processing_timestamp) as last_processed
FROM iceberg.lakehouse.orders_enriched
"

# Flow 03: Data Quality
echo "=== Flow 03: Data Quality Pipeline ==="
ls -1 demo/data/quality-violations/*/* 2>/dev/null | wc -l | xargs echo "Violações Detectadas:"
docker exec kafka kafka-run-class kafka.tools.GetOffsetShell \
  --broker-list localhost:9092 \
  --topic data-quality-metrics | awk -F':' '{sum+=$3} END {print "Métricas Publicadas:", sum}'

# Flow 04: Backup to S3
echo "=== Flow 04: Backup to S3 Pipeline ==="
docker exec minio mc ls local/lakehouse-backups/backups/ --recursive | wc -l | xargs echo "Backups Criados:"
docker exec minio mc du local/lakehouse-backups/backups/ | awk '{print "Tamanho Total Backups:", $1}'

# Flow 05: Real-time Aggregation
echo "=== Flow 05: Real-time Aggregation Pipeline ==="
docker exec trino trino --execute "
SELECT
    COUNT(DISTINCT window_start) as total_windows,
    COUNT(*) as total_aggregations,
    COUNT(DISTINCT region) as regions_processed
FROM iceberg.lakehouse.realtime_kpis
"
```

### Checklist de Validação

```bash
# Criar checklist automático
cat > /tmp/test_validation.sh << 'BASH'
#!/bin/bash

echo "╔════════════════════════════════════════════════════╗"
echo "║  Validação de Testes - NiFi Flow Templates        ║"
echo "╚════════════════════════════════════════════════════╝"
echo ""

# Flow 01
kafka_count=$(docker exec kafka kafka-run-class kafka.tools.GetOffsetShell --broker-list localhost:9092 --topic orders-raw 2>/dev/null | awk -F':' '{sum+=$3} END {print sum}')
[[ $kafka_count -gt 0 ]] && echo "✅ Flow 01: $kafka_count mensagens no Kafka" || echo "❌ Flow 01: FALHOU"

# Flow 02
iceberg_count=$(docker exec trino trino --execute "SELECT COUNT(*) FROM iceberg.lakehouse.orders_enriched" 2>/dev/null | tail -1 | tr -d ' ')
[[ $iceberg_count -gt 0 ]] && echo "✅ Flow 02: $iceberg_count registros no Iceberg" || echo "❌ Flow 02: FALHOU"

# Flow 03
violations=$(ls -1 demo/data/quality-violations/*/* 2>/dev/null | wc -l)
[[ $violations -gt 0 ]] && echo "✅ Flow 03: $violations violações detectadas" || echo "❌ Flow 03: FALHOU"

# Flow 04
backups=$(docker exec minio mc ls local/lakehouse-backups/backups/ --recursive 2>/dev/null | wc -l)
[[ $backups -gt 0 ]] && echo "✅ Flow 04: $backups backups criados" || echo "❌ Flow 04: FALHOU"

# Flow 05
kpis=$(docker exec trino trino --execute "SELECT COUNT(*) FROM iceberg.lakehouse.realtime_kpis" 2>/dev/null | tail -1 | tr -d ' ')
[[ $kpis -gt 0 ]] && echo "✅ Flow 05: $kpis agregações calculadas" || echo "❌ Flow 05: FALHOU"

echo ""
echo "════════════════════════════════════════════════════"
BASH

chmod +x /tmp/test_validation.sh
/tmp/test_validation.sh
```

---

## 📚 Próximos Passos

Após completar os testes:

1. **Capturar Screenshots:**
   - Canvas de cada flow
   - Statistics (In/Out, Bytes)
   - Data Provenance de sucesso
   - Query results no Trino
   - Mensagens no Kafka

2. **Documentar Performance:**
   - Throughput médio (registros/segundo)
   - Latência p95
   - Utilização de recursos (CPU, memória)

3. **Versionar Flows no NiFi Registry:**
   - Commit com mensagens descritivas
   - Pelo menos 2-3 versões de cada flow

4. **Sincronizar com Repositório:**
   ```bash
   ./scripts/sync-flows.sh
   git add flows/ demo/flows/
   git commit -m "test: validate 5 production-ready NiFi flows"
   ```

---

**Desenvolvido como parte do Data Engineering Portfolio**
**Última atualização:** 2026-02-05
