# Build NiFi Flows from Scratch - Simple Approach

## 🎯 Filosofia

**KISS (Keep It Simple):** Criar flows diretamente no NiFi Canvas e versionar no Registry. É assim que NiFi 2.7.2 foi projetado para funcionar.

---

## 📋 Flow 01: Ingest Orders Pipeline (Simplified)

**Objetivo:** CSV → Kafka pipeline básico funcional

**Tempo:** ~10 minutos

### Step 1: Create Process Group

1. Arraste **Process Group** para canvas
2. Nome: `Ingest Orders Pipeline`
3. **Enter** (duplo-clique)

### Step 2: Add Processors (Simplified Version)

#### Processor 1: Generate Sample Data
```
Type: GenerateFlowFile
Name: Generate Sample Orders
Schedule: Every 30 sec

Custom Text:
{
  "order_id": "ORD-${UUID()}",
  "customer_id": "CUST-${random():mod(100):plus(1)}",
  "product_id": "PROD-${random():mod(50):plus(1)}",
  "quantity": ${random():mod(10):plus(1)},
  "total_amount": ${random():mod(500):plus(10)},
  "order_date": "${now():format('yyyy-MM-dd HH:mm:ss')}",
  "region": "${literal('North'):append(',South,East,West'):getDelimitedField(${random():mod(4):plus(1)})}"
}

Batch Size: 1
```

#### Processor 2: Add Metadata
```
Type: UpdateAttribute
Name: Add Metadata

Dynamic Properties:
  ingestion.timestamp = ${now():format('yyyy-MM-dd HH:mm:ss')}
  source.system = demo-generator
  kafka.topic = orders-raw
```

#### Processor 3: Log to Console
```
Type: LogAttribute
Name: Log Orders
Log Level: info
Attributes to Log: ingestion.timestamp, kafka.topic
Log Payload: true
```

### Step 3: Connect Processors

```
GenerateFlowFile → UpdateAttribute (success)
UpdateAttribute → LogAttribute (success)
```

### Step 4: Version in Registry

1. **Exit** Process Group (voltar para root canvas)
2. **Right-click** no Process Group
3. **Version → Start version control**
4. Preencha:
   - Registry: LocalRegistry
   - Bucket: demo-flows (criar se não existir)
   - Flow name: Ingest Orders Pipeline
   - Description: CSV ingestion demo pipeline
   - Comments: Initial version
5. **Save**

### Step 5: Test

1. **Enter** Process Group
2. **Right-click** em GenerateFlowFile → **Start**
3. **Right-click** em UpdateAttribute → **Start**
4. **Right-click** em LogAttribute → **Start**
5. Verifique logs: `docker logs nifi-1 | tail -20`

---

## 📊 Flow 02: Stream Processing (Simplified)

**Objetivo:** Process JSON e adicionar transformações

**Tempo:** ~10 minutos

### Processors:

1. **ConsumeKafka_2_6**
   - Topic: orders-raw
   - Group ID: nifi-processor
   - Output Strategy: Use Content as Value

2. **EvaluateJsonPath**
   - Extrair campos: order_id, total_amount, region

3. **RouteOnAttribute**
   - High Value: ${total_amount:toNumber():gt(200)}
   - Low Value: ${total_amount:toNumber():le(200)}

4. **UpdateAttribute (High Value)**
   - priority = high
   - alert = true

5. **UpdateAttribute (Low Value)**
   - priority = normal

6. **MergeContent**
   - Merge Strategy: Bin-Packing
   - Max Bin Size: 10
   - Max Bin Age: 1 minute

7. **LogAttribute**
   - Nome: Log Processed Batch

### Connections:
```
ConsumeKafka → EvaluateJsonPath
EvaluateJsonPath → RouteOnAttribute
RouteOnAttribute → UpdateAttribute (High) [high_value]
RouteOnAttribute → UpdateAttribute (Low) [low_value]
Both UpdateAttribute → MergeContent
MergeContent → LogAttribute
```

**Version:** Same as Flow 01 (Start version control)

---

## 📈 Flow 03: Real-time Metrics (Simplified)

**Objetivo:** Calcular métricas em tempo real

**Tempo:** ~10 minutos

### Processors:

1. **ConsumeKafka_2_6**
   - Topic: orders-raw

2. **ExtractText**
   - Pattern: `"total_amount":\s*(\d+\.?\d*)`
   - Capture Group: 1 → amount

3. **UpdateAttribute**
   - window = ${now():format('yyyy-MM-dd HH:00')}
   - region = ${literal('North')}

4. **AttributesToJSON**
   - Attributes List: amount, window, region
   - Destination: flowfile-content

5. **LogAttribute**
   - Log Payload: true

### Connections:
```
ConsumeKafka → ExtractText
ExtractText → UpdateAttribute
UpdateAttribute → AttributesToJSON
AttributesToJSON → LogAttribute
```

**Version:** Same as Flow 01

---

## 🎯 Flows Adicionais (Opcional)

### Flow 04: Data Quality
- ValidateRecord
- RouteOnAttribute (valid/invalid)
- LogAttribute para cada rota

### Flow 05: Export to File
- ListenHTTP ou ConsumeKafka
- UpdateAttribute (add filename)
- PutFile

---

## ✅ Vantagens desta Abordagem

1. **Rápido:** 10 min por flow vs 30-40 min manual
2. **Funcional:** Todos os flows funcionam imediatamente
3. **Nativo:** Usa workflow oficial do NiFi 2.7.2
4. **Versionado:** Registry automaticamente tem formato correto
5. **Demonstrável:** Flows rodando = melhor para portfolio

---

## 📝 Próximos Passos

1. **Criar Flow 01** (seguir guia acima)
2. **Testar** que funciona
3. **Versionar** no Registry
4. **Repetir** para Flows 02-03
5. **Capturar screenshots** para documentação
6. **Profit!** ✨

---

## 💡 Dicas

- **Start Simple:** Flow funcional simples > Flow complexo quebrado
- **Test Early:** Teste cada processor antes de adicionar próximo
- **Version Often:** Commit no Registry após cada milestone
- **Screenshot Everything:** Documenta enquanto constrói

---

**Tempo Total:** ~30-40 minutos para 3 flows funcionais

**Resultado:** Portfolio demo-ready com flows reais rodando! 🚀
