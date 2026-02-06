# NiFi 2.7.2 Processors Reference

**Versão:** Apache NiFi 2.7.2 (Released: December 17, 2025)

**Fontes Oficiais:**
- [NiFi Documentation](https://nifi.apache.org/documentation/)
- [Component Documentation](https://nifi.apache.org/components/)
- [Release Notes](https://cwiki.apache.org/confluence/display/NIFI/Release+Notes)
- [NiFi 2.7.2 Announcement](http://www.mail-archive.com/announce@apache.org/msg10618.html)

---

## ✅ Processors Validados para NiFi 2.7.2

### 📂 File Operations
| Processor | Status | Documentation |
|-----------|--------|---------------|
| ListFile | ✅ | [Docs](https://nifi.apache.org/components/org.apache.nifi.processors.standard.ListFile/) |
| FetchFile | ✅ | [Docs](https://nifi.apache.org/components/org.apache.nifi.processors.standard.FetchFile/) |
| PutFile | ✅ | Standard processor |
| GetFile | ✅ | Standard processor |

### 🔄 Record Processing
| Processor | Status | Documentation |
|-----------|--------|---------------|
| ConvertRecord | ✅ | [Docs](https://nifi.apache.org/components/org.apache.nifi.processors.standard.ConvertRecord/) |
| ValidateRecord | ✅ | [Docs](https://nifi.apache.org/components/org.apache.nifi.processors.standard.ValidateRecord/) |
| UpdateRecord | ✅ | Standard processor |
| QueryRecord | ✅ | Standard processor |
| SplitRecord | ✅ | Standard processor |
| PartitionRecord | ✅ | Standard processor |
| LookupRecord | ✅ | Standard processor |

### 🔀 Routing & Control
| Processor | Status | Documentation |
|-----------|--------|---------------|
| RouteOnAttribute | ✅ | Standard processor |
| RouteOnContent | ✅ | Standard processor |
| DetectDuplicate | ✅ | Standard processor |

### 🏷️ Attributes
| Processor | Status | Documentation |
|-----------|--------|---------------|
| UpdateAttribute | ✅ | Standard processor |
| EvaluateJsonPath | ✅ | Standard processor |
| ExtractText | ✅ | Standard processor |
| AttributesToJSON | ✅ | Standard processor |

### 📊 Transformation
| Processor | Status | Documentation |
|-----------|--------|---------------|
| JoltTransformJSON | ✅ | Standard processor |
| JoltTransformRecord | ✅ | Standard processor |
| MergeContent | ✅ | Standard processor |
| MergeRecord | ✅ | Standard processor |

### 📝 Logging & Testing
| Processor | Status | Documentation |
|-----------|--------|---------------|
| LogAttribute | ✅ | Standard processor |
| LogMessage | ✅ | Standard processor |
| GenerateFlowFile | ✅ | Standard processor |

---

## ⚠️ KAFKA PROCESSORS - MUDANÇA IMPORTANTE

### ❌ Processors ANTIGOS (Deprecated)

**NÃO USAR EM NIFI 2.7.2:**
```
PublishKafka_2_6
PublishKafkaRecord_2_6
ConsumeKafka_2_6
ConsumeKafkaRecord_2_6
```

### ✅ Processors NOVOS (NiFi 2.x)

**USAR EM NIFI 2.7.2:**

#### PublishKafka (Unified)
```
Type: org.apache.nifi.processors.kafka.pubsub.PublishKafka
NAR: nifi-kafka-nar

Características:
- Unificado: suporta FlowFile-based e Record-based
- Substitui PublishKafka_2_6 e PublishKafkaRecord_2_6
- Configuração via Record Reader/Writer (opcional)

Properties principais:
- Kafka Brokers
- Topic Name
- Record Reader (opcional, para mode record)
- Record Writer (opcional, para mode record)
- Use Transactions
- Delivery Guarantee
- Compression Type
```

#### ConsumeKafka (Unified)
```
Type: org.apache.nifi.processors.kafka.pubsub.ConsumeKafka
NAR: nifi-kafka-nar

Características:
- Unificado: suporta FlowFile-based e Record-based
- Substitui ConsumeKafka_2_6 e ConsumeKafkaRecord_2_6
- Configuração via Record Reader/Writer (opcional)

Properties principais:
- Kafka Brokers
- Topic Name(s)
- Topic Name Format (Names/Pattern)
- Record Reader (opcional, para mode record)
- Record Writer (opcional, para mode record)
- Group ID
- Offset Reset
- Max Poll Records
```

---

## 🔧 Controller Services para NiFi 2.7.2

### CSV Processing
```
CSVReader
- Type: org.apache.nifi.csv.CSVReader
- Schema Access Strategy: Use String Schema Property / Infer Schema

CSVRecordSetWriter
- Type: org.apache.nifi.csv.CSVRecordSetWriter
```

### JSON Processing
```
JsonTreeReader
- Type: org.apache.nifi.json.JsonTreeReader
- Schema Access Strategy: Infer Schema

JsonRecordSetWriter
- Type: org.apache.nifi.json.JsonRecordSetWriter
- Schema Write Strategy: Full Schema Definition
```

### Avro Processing
```
AvroReader
- Type: org.apache.nifi.avro.AvroReader

AvroRecordSetWriter
- Type: org.apache.nifi.avro.AvroRecordSetWriter
```

---

## 📋 Template Atualizado para Flows

### Exemplo: Ingest to Kafka (NiFi 2.7.2)

```
ListFile
  ↓
FetchFile
  ↓
ConvertRecord (CSV → JSON)
  ↓
PublishKafka (NOVO - não _2_6)
  - Kafka Brokers: kafka:9092
  - Topic Name: orders-raw
  - Record Reader: JsonTreeReader
  - Record Writer: JsonRecordSetWriter
  - Delivery Guarantee: At Least Once
```

### Exemplo: Consume from Kafka (NiFi 2.7.2)

```
ConsumeKafka (NOVO - não _2_6)
  - Kafka Brokers: kafka:9092
  - Topic Names: orders-raw
  - Group ID: nifi-consumer-group
  - Record Reader: JsonTreeReader
  - Record Writer: JsonRecordSetWriter
  ↓
ProcessRecord/Transform
  ↓
LogAttribute
```

---

## 🎯 Checklist de Validação

Antes de criar flows, verifique:

- [ ] Processor existe na versão 2.7.2
- [ ] Properties são válidas para 2.7.2
- [ ] Kafka processors usam versão unificada (sem _2_6)
- [ ] Controller Services compatíveis
- [ ] Bundle version correto (2.7.2)

---

## 📚 Recursos Oficiais

### Documentação
- [NiFi 2.7.2 Documentation](https://nifi.apache.org/docs/nifi-docs/)
- [Component Documentation](https://nifi.apache.org/components/)
- [NiFi Processors List](https://www.nifi.rocks/apache-nifi-processors/)

### Release Information
- [Release Notes](https://cwiki.apache.org/confluence/display/NIFI/Release+Notes)
- [2.7.2 Release Announcement](http://www.mail-archive.com/announce@apache.org/msg10618.html)
- [JIRA Release Notes](https://issues.apache.org/jira/secure/ReleaseNote.jspa?projectId=12316020&version=12356562)

### Kafka Processor Changes
- [Kafka Processor Refactor Discussion](http://www.mail-archive.com/dev@nifi.apache.org/msg24240.html)

---

## ⚡ Quick Reference

**Sempre verificar:**
1. Processor name exato no NiFi UI
2. Bundle version (deve ser 2.7.2 ou compatível)
3. Kafka processors: usar versão unificada (PublishKafka, ConsumeKafka)
4. Controller Services: verificar compatibilidade

**Em caso de dúvida:**
- Consultar NiFi UI: Menu → Documentation → Processor name
- Verificar [nifi.apache.org/components](https://nifi.apache.org/components/)

---

**Última Atualização:** 2026-02-06
**Versão NiFi:** 2.7.2
**Status:** Validado contra documentação oficial
