# 10 Production-Ready NiFi Flows

**Baseados nos dados reais:** `orders.csv`, `customers.csv`, `products.csv`

**Tempo total:** ~2 horas (12 min por flow)

---

## 🎯 Flow 01: CSV Orders Ingestion

**Objetivo:** Ingerir pedidos de CSV para Kafka com validação

**Tempo:** 12 min

### Processors:

1. **ListFile**
   - Input Directory: `/data/orders` (ou `./demo/data/output`)
   - File Filter: `orders.*\.csv`
   - Listing Strategy: Tracking Timestamps

2. **FetchFile**
   - File to Fetch: `${absolute.path}/${filename}`
   - Move Destination: `./demo/data/processed`

3. **SplitRecord**
   - Record Reader: CSVReader
   - Record Writer: JsonRecordSetWriter
   - Records Per Split: 100

4. **ValidateRecord**
   - Record Reader: JsonTreeReader
   - Record Writer: JsonRecordSetWriter
   - Schema: Inline (order_id, customer_id, total_amount required)

5. **UpdateAttribute**
   - ingestion_time: `${now()}`
   - source_file: `${filename}`

6. **LogAttribute** (Valid)
   - Log Level: info

7. **LogAttribute** (Invalid)
   - Log Level: warn

### Connections:
```
ListFile → FetchFile [success]
FetchFile → SplitRecord [success]
SplitRecord → ValidateRecord [splits]
ValidateRecord → UpdateAttribute [valid]
ValidateRecord → LogAttribute(Invalid) [invalid]
UpdateAttribute → LogAttribute(Valid) [success]
```

---

## 🔄 Flow 02: Customer Enrichment

**Objetivo:** Enriquecer pedidos com dados de clientes

**Tempo:** 12 min

### Processors:

1. **ListFile** (orders.csv)

2. **FetchFile**

3. **ConvertRecord**
   - CSV → JSON

4. **LookupRecord**
   - Record Reader: JsonTreeReader
   - Record Writer: JsonRecordSetWriter
   - Lookup Service: SimpleCsvFileLookupService
     - CSV File: `./demo/data/output/customers.csv`
     - Lookup Key Column: customer_id
   - Result RecordPath: `/customer_name`
   - Lookup Key: `/customer_id`

5. **EvaluateJsonPath**
   - customer_name: `$.customer_name`
   - order_id: `$.order_id`
   - total_amount: `$.total_amount`

6. **UpdateAttribute**
   - enriched: `true`
   - enrichment_time: `${now()}`

7. **AttributesToJSON**
   - Destination: flowfile-content

8. **LogAttribute**
   - Log Payload: true

### Connections:
```
ListFile → FetchFile → ConvertRecord → LookupRecord
LookupRecord → EvaluateJsonPath → UpdateAttribute
UpdateAttribute → AttributesToJSON → LogAttribute
```

---

## 💰 Flow 03: High-Value Order Detection

**Objetivo:** Detectar e alertar pedidos de alto valor

**Tempo:** 10 min

### Processors:

1. **ListFile** (orders.csv)

2. **FetchFile**

3. **ConvertRecord** (CSV → JSON)

4. **QueryRecord**
   - Record Reader: JsonTreeReader
   - Record Writer: JsonRecordSetWriter
   - high_value: `SELECT * FROM FLOWFILE WHERE total_amount > 300`
   - medium_value: `SELECT * FROM FLOWFILE WHERE total_amount BETWEEN 100 AND 300`
   - low_value: `SELECT * FROM FLOWFILE WHERE total_amount < 100`

5. **UpdateAttribute** (High Value)
   - alert_level: `HIGH`
   - priority: `1`
   - notification: `Pedido alto valor detectado`

6. **UpdateAttribute** (Medium Value)
   - alert_level: `MEDIUM`
   - priority: `2`

7. **UpdateAttribute** (Low Value)
   - alert_level: `LOW`
   - priority: `3`

8. **RouteOnAttribute**
   - HIGH: `${alert_level:equals('HIGH')}`
   - MEDIUM: `${alert_level:equals('MEDIUM')}`
   - LOW: `${alert_level:equals('LOW')}`

9. **LogAttribute** (para cada rota)

### Connections:
```
ListFile → FetchFile → ConvertRecord → QueryRecord
QueryRecord → UpdateAttribute (each level) [high_value/medium_value/low_value]
All UpdateAttribute → RouteOnAttribute
RouteOnAttribute → LogAttribute (3x) [HIGH/MEDIUM/LOW]
```

---

## 📊 Flow 04: Regional Sales Aggregation

**Objetivo:** Agregar vendas por região em janelas de tempo

**Tempo:** 15 min

### Processors:

1. **ListFile** (orders.csv)

2. **FetchFile**

3. **ConvertRecord** (CSV → JSON)

4. **EvaluateJsonPath**
   - region: `$.region`
   - total_amount: `$.total_amount`
   - order_date: `$.order_date`

5. **UpdateAttribute**
   - window: `${order_date:toDate('yyyy-MM-dd HH:mm:ss'):format('yyyy-MM-dd HH:00')}`

6. **PartitionRecord**
   - Record Reader: JsonTreeReader
   - Record Writer: JsonRecordSetWriter
   - Partition by: `/region`

7. **QueryRecord**
   - Record Reader: JsonTreeReader
   - Record Writer: JsonRecordSetWriter
   - aggregated:
     ```sql
     SELECT
       region,
       COUNT(*) as order_count,
       SUM(total_amount) as total_revenue,
       AVG(total_amount) as avg_order_value,
       MIN(total_amount) as min_order,
       MAX(total_amount) as max_order
     FROM FLOWFILE
     GROUP BY region
     ```

8. **AttributesToJSON**

9. **LogAttribute**
   - Log Payload: true

### Connections:
```
ListFile → FetchFile → ConvertRecord → EvaluateJsonPath
EvaluateJsonPath → UpdateAttribute → PartitionRecord
PartitionRecord → QueryRecord → AttributesToJSON → LogAttribute
```

---

## 🔍 Flow 05: Data Quality Validation

**Objetivo:** Validar qualidade dos dados com múltiplas regras

**Tempo:** 15 min

### Processors:

1. **ListFile** (orders.csv)

2. **FetchFile**

3. **ConvertRecord** (CSV → JSON)

4. **QueryRecord** (Null Check)
   - valid_ids: `SELECT * FROM FLOWFILE WHERE order_id IS NOT NULL AND customer_id IS NOT NULL`
   - null_ids: `SELECT * FROM FLOWFILE WHERE order_id IS NULL OR customer_id IS NULL`

5. **QueryRecord** (Range Check)
   - valid_amounts: `SELECT * FROM FLOWFILE WHERE total_amount > 0 AND total_amount < 10000`
   - invalid_amounts: `SELECT * FROM FLOWFILE WHERE total_amount <= 0 OR total_amount >= 10000`

6. **QueryRecord** (Date Check)
   - valid_dates: `SELECT * FROM FLOWFILE WHERE order_date IS NOT NULL`
   - invalid_dates: `SELECT * FROM FLOWFILE WHERE order_date IS NULL`

7. **UpdateAttribute** (Valid Path)
   - quality_status: `PASSED`
   - validation_time: `${now()}`

8. **UpdateAttribute** (Invalid Path)
   - quality_status: `FAILED`
   - validation_time: `${now()}`

9. **RouteOnAttribute**
   - PASSED: `${quality_status:equals('PASSED')}`
   - FAILED: `${quality_status:equals('FAILED')}`

10. **PutFile** (Valid)
    - Directory: `./demo/data/validated`

11. **PutFile** (Invalid)
    - Directory: `./demo/data/rejected`

### Connections:
```
ListFile → FetchFile → ConvertRecord → QueryRecord(Null)
QueryRecord(Null) → QueryRecord(Range) [valid_ids]
QueryRecord(Range) → QueryRecord(Date) [valid_amounts]
QueryRecord(Date) → UpdateAttribute(Valid) [valid_dates]
All invalid paths → UpdateAttribute(Invalid)
Both UpdateAttribute → RouteOnAttribute
RouteOnAttribute → PutFile(Valid) [PASSED]
RouteOnAttribute → PutFile(Invalid) [FAILED]
```

---

## 🎨 Flow 06: Data Transformation Pipeline

**Objetivo:** Transformar e padronizar dados

**Tempo:** 12 min

### Processors:

1. **ListFile** (orders.csv)

2. **FetchFile**

3. **ConvertRecord** (CSV → JSON)

4. **UpdateRecord**
   - Record Reader: JsonTreeReader
   - Record Writer: JsonRecordSetWriter
   - Replacement Value Strategy: Record Path Value
   - `/order_id`: `upperCase(/order_id)`
   - `/region`: `upperCase(/region)`
   - `/status`: `lowerCase(/status)`

5. **JoltTransformJSON**
   - Jolt Specification:
     ```json
     [{
       "operation": "shift",
       "spec": {
         "order_id": "transaction.id",
         "customer_id": "transaction.customer",
         "total_amount": "transaction.amount",
         "region": "transaction.location",
         "order_date": "transaction.timestamp",
         "status": "transaction.state"
       }
     }]
     ```

6. **EvaluateJsonPath**
   - transaction_id: `$.transaction.id`
   - transaction_amount: `$.transaction.amount`

7. **AttributesToJSON**

8. **LogAttribute**
   - Log Payload: true

### Connections:
```
ListFile → FetchFile → ConvertRecord → UpdateRecord
UpdateRecord → JoltTransformJSON → EvaluateJsonPath
EvaluateJsonPath → AttributesToJSON → LogAttribute
```

---

## 📅 Flow 07: Time-Based Partitioning

**Objetivo:** Particionar dados por data para otimizar queries

**Tempo:** 12 min

### Processors:

1. **ListFile** (orders.csv)

2. **FetchFile**

3. **ConvertRecord** (CSV → JSON)

4. **EvaluateJsonPath**
   - order_date: `$.order_date`

5. **UpdateAttribute**
   - year: `${order_date:toDate('yyyy-MM-dd HH:mm:ss'):format('yyyy')}`
   - month: `${order_date:toDate('yyyy-MM-dd HH:mm:ss'):format('MM')}`
   - day: `${order_date:toDate('yyyy-MM-dd HH:mm:ss'):format('dd')}`
   - partition_path: `year=${year}/month=${month}/day=${day}`

6. **RouteOnAttribute**
   - 2024: `${year:equals('2024')}`
   - 2025: `${year:equals('2025')}`

7. **PutFile** (2024)
   - Directory: `./demo/data/partitioned/${partition_path}`
   - Conflict Resolution: replace

8. **PutFile** (2025)
   - Directory: `./demo/data/partitioned/${partition_path}`
   - Conflict Resolution: replace

### Connections:
```
ListFile → FetchFile → ConvertRecord → EvaluateJsonPath
EvaluateJsonPath → UpdateAttribute → RouteOnAttribute
RouteOnAttribute → PutFile(2024) [2024]
RouteOnAttribute → PutFile(2025) [2025]
```

---

## 🔔 Flow 08: Real-Time Alerting

**Objetivo:** Gerar alertas para condições específicas

**Tempo:** 12 min

### Processors:

1. **ListFile** (orders.csv)

2. **FetchFile**

3. **ConvertRecord** (CSV → JSON)

4. **QueryRecord**
   - Record Reader: JsonTreeReader
   - Record Writer: JsonRecordSetWriter
   - cancelled_orders: `SELECT * FROM FLOWFILE WHERE status = 'cancelled'`
   - refunded_orders: `SELECT * FROM FLOWFILE WHERE status = 'refunded'`
   - high_value_completed: `SELECT * FROM FLOWFILE WHERE status = 'completed' AND total_amount > 400`

5. **UpdateAttribute** (Cancelled)
   - alert_type: `ORDER_CANCELLED`
   - severity: `MEDIUM`
   - message: `Pedido cancelado: ${order_id}`

6. **UpdateAttribute** (Refunded)
   - alert_type: `ORDER_REFUNDED`
   - severity: `HIGH`
   - message: `Pedido reembolsado: ${order_id}`

7. **UpdateAttribute** (High Value)
   - alert_type: `HIGH_VALUE_SALE`
   - severity: `LOW`
   - message: `Venda alto valor: ${order_id} - $${total_amount}`

8. **AttributesToJSON** (para cada)

9. **LogAttribute** (para cada)

### Connections:
```
ListFile → FetchFile → ConvertRecord → QueryRecord
QueryRecord → UpdateAttribute(Cancelled) [cancelled_orders]
QueryRecord → UpdateAttribute(Refunded) [refunded_orders]
QueryRecord → UpdateAttribute(HighValue) [high_value_completed]
All UpdateAttribute → AttributesToJSON → LogAttribute
```

---

## 🔄 Flow 09: Deduplication Pipeline

**Objetivo:** Remover pedidos duplicados

**Tempo:** 10 min

### Processors:

1. **ListFile** (orders.csv)

2. **FetchFile**

3. **ConvertRecord** (CSV → JSON)

4. **EvaluateJsonPath**
   - order_id: `$.order_id`
   - customer_id: `$.customer_id`

5. **DetectDuplicate**
   - Cache Entry Identifier: `${order_id}`
   - FlowFile Description: `Order ${order_id}`

6. **UpdateAttribute** (Duplicate)
   - duplicate: `true`
   - action: `SKIP`

7. **UpdateAttribute** (Non-Duplicate)
   - duplicate: `false`
   - action: `PROCESS`

8. **RouteOnAttribute**
   - PROCESS: `${action:equals('PROCESS')}`
   - SKIP: `${action:equals('SKIP')}`

9. **LogAttribute** (Processed)

10. **LogAttribute** (Skipped)

### Connections:
```
ListFile → FetchFile → ConvertRecord → EvaluateJsonPath
EvaluateJsonPath → DetectDuplicate
DetectDuplicate → UpdateAttribute(NonDup) [non-duplicate]
DetectDuplicate → UpdateAttribute(Dup) [duplicate]
UpdateAttribute(NonDup) → RouteOnAttribute
UpdateAttribute(Dup) → RouteOnAttribute
RouteOnAttribute → LogAttribute(Processed) [PROCESS]
RouteOnAttribute → LogAttribute(Skipped) [SKIP]
```

---

## 📈 Flow 10: Product Sales Analytics

**Objetivo:** Analisar vendas por produto com join de produtos

**Tempo:** 15 min

### Processors:

1. **ListFile** (orders.csv)

2. **FetchFile**

3. **ConvertRecord** (CSV → JSON)

4. **LookupRecord**
   - Record Reader: JsonTreeReader
   - Record Writer: JsonRecordSetWriter
   - Lookup Service: SimpleCsvFileLookupService
     - CSV File: `./demo/data/output/products.csv`
     - Lookup Key Column: product_id
   - Result RecordPath: `/product_info`
   - Lookup Key: `/product_id`

5. **QueryRecord**
   - Record Reader: JsonTreeReader
   - Record Writer: JsonRecordSetWriter
   - product_stats:
     ```sql
     SELECT
       product_id,
       COUNT(*) as total_orders,
       SUM(total_amount) as total_revenue,
       AVG(total_amount) as avg_order_value,
       MIN(order_date) as first_order,
       MAX(order_date) as last_order
     FROM FLOWFILE
     GROUP BY product_id
     ORDER BY total_revenue DESC
     ```

6. **UpdateAttribute**
   - analysis_type: `product_performance`
   - analysis_time: `${now()}`

7. **ConvertRecord** (JSON → CSV)
   - For export

8. **PutFile**
   - Directory: `./demo/data/analytics`
   - Filename: `product_sales_${now():format('yyyy-MM-dd')}.csv`

9. **LogAttribute**

### Connections:
```
ListFile → FetchFile → ConvertRecord → LookupRecord
LookupRecord → QueryRecord → UpdateAttribute
UpdateAttribute → ConvertRecord(JSON→CSV) → PutFile → LogAttribute
```

---

## 📊 Resumo dos 10 Flows

| # | Flow | Tempo | Conceito Principal |
|---|------|-------|-------------------|
| 01 | CSV Orders Ingestion | 12 min | Ingestão + Validação |
| 02 | Customer Enrichment | 12 min | Lookup + Enriquecimento |
| 03 | High-Value Detection | 10 min | Roteamento + Alertas |
| 04 | Regional Aggregation | 15 min | Agregação + Particionamento |
| 05 | Data Quality | 15 min | Validação Multi-regras |
| 06 | Transformation | 12 min | JOLT + UpdateRecord |
| 07 | Time Partitioning | 12 min | Particionamento Temporal |
| 08 | Real-Time Alerting | 12 min | Detecção de Eventos |
| 09 | Deduplication | 10 min | DetectDuplicate |
| 10 | Product Analytics | 15 min | Join + Agregação |

**Tempo Total:** ~2 horas
**Resultado:** 10 flows production-ready! 🚀

---

## 🎯 Ordem de Implementação Sugerida

### Fase 1: Básicos (30 min)
1. Flow 01 - Ingestion
2. Flow 03 - High-Value Detection
3. Flow 09 - Deduplication

### Fase 2: Intermediários (45 min)
4. Flow 02 - Customer Enrichment
5. Flow 06 - Transformation
6. Flow 07 - Time Partitioning

### Fase 3: Avançados (45 min)
7. Flow 04 - Regional Aggregation
8. Flow 05 - Data Quality
9. Flow 08 - Alerting
10. Flow 10 - Product Analytics

---

## ✅ Checklist de Implementação

Para cada flow:
- [ ] Criar Process Group
- [ ] Adicionar processors na ordem
- [ ] Configurar properties
- [ ] Criar connections
- [ ] Testar com dados reais
- [ ] Start version control no Registry
- [ ] Capturar screenshot
- [ ] Documentar resultados

---

## 💡 Dicas

1. **Use Controller Services reusáveis:**
   - CSVReader (compartilhado por todos)
   - JsonTreeReader (compartilhado)
   - JsonRecordSetWriter (compartilhado)

2. **Configure uma vez, reuse:**
   - Configure CSVReader com schema de orders.csv
   - Reuse em todos os flows

3. **Test incrementalmente:**
   - Teste cada processor antes de adicionar próximo
   - Use pequeno subset de dados primeiro

4. **Version control:**
   - Commit após cada flow completo
   - Use mensagens descritivas

---

**Pronto para começar?** Comece pelo Flow 01! 🚀
