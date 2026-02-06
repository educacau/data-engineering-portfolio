# Manual Flow Build Guide - NiFi 2.7.2

## 📋 Situação Atual

**NiFi 2.7.2 mudanças importantes:**
- ❌ Removido: Upload de templates XML via UI
- ❌ Removido: Import de templates via CLI
- ✅ Novo: Flows devem ser criados no Canvas ou importados do Registry

**Nosso desafio:**
- Tentamos criar flows programaticamente via Registry API
- Encontramos problemas de compatibilidade de formato
- Properties ficam vazias, connections não são criadas corretamente

## ✅ Solução Recomendada

**Use os XMLs como DOCUMENTAÇÃO COMPLETA para construir os flows manualmente**

Os templates XML contêm TODAS as informações necessárias:
- ✅ Tipos de processors exatos
- ✅ Todas as propriedades configuradas
- ✅ Connections com relationships
- ✅ Posicionamento no canvas

---

## 🚀 Flow 01: Ingest Orders Pipeline

### Processors (na ordem)

#### 1. List CSV Files
```
Type: org.apache.nifi.processors.standard.ListFile
Name: List CSV Files
Position: (100, 100)

Properties:
  - Input Directory: /data/orders
  - File Filter: orders_.*\.csv
  - Recurse Subdirectories: false
  - Minimum File Age: 10 sec

Run Schedule: Every 30 seconds
```

#### 2. Fetch CSV Content
```
Type: org.apache.nifi.processors.standard.FetchFile
Name: Fetch CSV Content
Position: (300, 100)

Properties:
  - File to Fetch: ${absolute.path}/${filename}
  - Move Destination Directory: /data/orders/processed
  - Move Conflict Strategy: Rename
```

#### 3. CSV to JSON
```
Type: org.apache.nifi.processors.standard.ConvertRecord
Name: CSV to JSON
Position: (500, 100)

Properties:
  - Record Reader: CSVReader (Controller Service)
  - Record Writer: JsonRecordSetWriter (Controller Service)
```

#### 4. Validate Order Schema
```
Type: org.apache.nifi.processors.standard.ValidateRecord
Name: Validate Order Schema
Position: (700, 100)

Properties:
  - Record Reader: JsonTreeReader
  - Record Writer: JsonRecordSetWriter
  - Schema Access Strategy: Use String Schema Property
  - Schema Text: [Order schema definition]
```

#### 5. Add Ingestion Metadata
```
Type: org.apache.nifi.processors.attributes.UpdateAttribute
Name: Add Ingestion Metadata
Position: (900, 100)

Dynamic Properties:
  - ingestion.timestamp: ${now():format('yyyy-MM-dd HH:mm:ss')}
  - source.system: csv-ingestion
  - data.version: v1.0
  - kafka.topic: orders-raw
```

#### 6. Publish to Kafka
```
Type: org.apache.nifi.processors.kafka.pubsub.PublishKafka
Name: Publish to Kafka
Position: (1100, 100)

Properties:
  - Kafka Brokers: kafka:9092
  - Topic Name: ${kafka.topic}
  - Record Reader: JsonTreeReader
  - Record Writer: JsonRecordSetWriter
  - Message Key Field: order_id
  - Compression Type: snappy
  - Delivery Guarantee: DELIVERY_REPLICATED (replaces Acknowledgment: all)
```

#### 7. Log Invalid Records
```
Type: org.apache.nifi.processors.standard.LogAttribute
Name: Log Invalid Records
Position: (700, 300)

Properties:
  - Log Level: warn
  - Attributes to Log: All attributes
```

### Connections

```
1. List CSV Files → Fetch CSV Content
   Relationship: success

2. Fetch CSV Content → CSV to JSON
   Relationship: success

3. CSV to JSON → Validate Order Schema
   Relationship: success

4. Validate Order Schema → Add Ingestion Metadata
   Relationship: valid

5. Validate Order Schema → Log Invalid Records
   Relationship: invalid

6. Add Ingestion Metadata → Publish to Kafka
   Relationship: success
```

### Controller Services Needed

1. **CSVReader**
   - Type: CSVReader
   - Schema Access Strategy: Use String Schema Property

2. **JsonRecordSetWriter**
   - Type: JsonRecordSetWriter
   - Schema Write Strategy: Do Not Write Schema

3. **JsonTreeReader**
   - Type: JsonTreeReader
   - Schema Access Strategy: Infer Schema

---

## 📝 Passos para Construir

### 1. Criar Process Group

1. Arraste Process Group para canvas
2. Nome: "Ingest Orders Pipeline"
3. Dê duplo-clique para entrar

### 2. Adicionar Processors

Para cada processor acima:
1. Arraste processor icon para canvas
2. Busque pelo Type (ex: "ListFile")
3. Configure properties conforme listado
4. Posicione conforme coordenadas

### 3. Criar Connections

1. Arraste da saída de um processor para entrada do próximo
2. Selecione o relationship apropriado
3. Repita para todas as 6 connections

### 4. Configurar Controller Services

1. Clique direito no canvas → Configure
2. Aba Controller Services
3. Adicione os 3 services listados
4. Configure e Enable cada um

### 5. Versionar no Registry

1. Clique direito no Process Group (fora dele)
2. Version → Start version control
3. Registry: LocalRegistry
4. Bucket: demo-flows
5. Flow Name: Ingest Orders Pipeline
6. Save

---

## 🎯 Flows Restantes

Use a mesma abordagem para os outros 4 flows:

- **Flow 02:** Stream Processing Pipeline (7 processors)
- **Flow 03:** Data Quality Pipeline (10 processors)
- **Flow 04:** Backup to S3 Pipeline (10 processors)
- **Flow 05:** Realtime Aggregation Pipeline (10 processors)

Detalhes completos nos arquivos XML correspondentes.

---

## 💡 Dica

**Use os XMLs como referência:**
- Abra o XML em um editor
- Procure por `<processors>` para ver todos os processors
- Procure por `<connections>` para ver as ligações
- Cada `<properties><entry>` mostra configuração exata

---

## ⏱️ Tempo Estimado

- Flow 01 (manual): ~15-20 minutos
- Flows 02-05 (manual): ~30-40 minutos cada
- Total: ~2.5-3 horas para todos os 5 flows

**Alternativa:** Use os flows como documentação e crie versões simplificadas para demo.

---

**Criado:** 2026-02-06
**NiFi Version:** 2.7.2
**Status:** Solução pragmática para limitações da versão 2.7.2
