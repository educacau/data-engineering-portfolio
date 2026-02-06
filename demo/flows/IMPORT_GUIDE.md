# Guia de Importação de Flows - NiFi Registry

Este guia explica como importar flows no Apache NiFi 2.7.2+, que **não suporta mais templates XML diretos**. Todos os flows devem ser importados via **NiFi Registry**.

---

## ⚠️ Mudança Importante no NiFi 2.7.2

**NiFi 2.7.2+ removeu o suporte a templates XML!**

- ❌ **Não funciona mais:** Upload de templates via Menu → Templates
- ✅ **Novo workflow:** Import exclusivamente via NiFi Registry

---

## 🔍 Entendendo os Formatos

### Templates XML (.xml)
- **Uso:** Importar no **NiFi Registry** via script Python
- **Formato:** Apache NiFi Template XML (legado)
- **Conversão:** Script converte para VersionedFlowSnapshot

### Flow Snapshots (Registry)
- **Uso:** Formato nativo do **NiFi Registry 2.7.2+**
- **Formato:** VersionedFlowSnapshot JSON interno
- **Ação:** Baixar do Registry no NiFi Canvas

---

## ✅ Workflow Recomendado (NiFi 2.7.2+)

### Passo 1: Importar Flows para o Registry

**Via Script Automatizado (Recomendado):**

```bash
# Executar script de importação
./scripts/import-flows.sh
```

O script irá:
1. ✅ Criar bucket `demo-flows` no Registry
2. ✅ Converter e importar todos os 5 flows XML
3. ✅ Exibir status de cada importação

**Saída esperada:**
```
Creating bucket: demo-flows
  [OK] Bucket created: <uuid>

Importing: 01-ingest-orders-pipeline.xml
  Flow name: Ingest Orders Pipeline
  [OK] Flow created: <uuid>
  [OK] Flow version imported: v1

...

Import Summary:
Imported: 5/5 flows
```

---

### Passo 2: Conectar NiFi ao Registry

1. **Acesse o NiFi:**
   ```
   https://localhost:8443/nifi
   Username: nifi
   Password: changeme123
   ```

2. **Adicionar Registry Client:**
   - Menu (☰) → **Controller Settings**
   - Aba **Registry Clients** → **+** (Add)
   - Preencha:
     - **Name:** Local Registry
     - **URL:** `http://nifi-registry:18080`
     - **Description:** Local NiFi Registry
   - **Add** → **Apply** → **Close**

---

### Passo 3: Importar Flows do Registry

1. **Importar Flow:**
   - Clique direito no canvas (área vazia)
   - **Version → Import from Registry**
   - Ou: Menu (☰) → **Version → Import from Registry**

2. **Selecionar Flow:**
   - **Registry Client:** Local Registry
   - **Bucket:** demo-flows
   - **Flow:** Selecione um dos 5 flows
   - **Version:** 1 (latest)
   - **Import**

3. **Flow Importado:**
   - Process Group aparece no canvas
   - Ícone verde indica sincronização com Registry
   - Ready para configuração e execução!

---

## 🔧 Workflow Alternativo (NiFi CLI)

### Pré-requisitos

```bash
# Download NiFi Toolkit
wget https://archive.apache.org/dist/nifi/1.25.0/nifi-toolkit-1.25.0-bin.zip
unzip nifi-toolkit-1.25.0-bin.zip
export NIFI_TOOLKIT=/path/to/nifi-toolkit-1.25.0
```

### Importar Template via CLI

```bash
# Importar template no NiFi
$NIFI_TOOLKIT/bin/cli.sh nifi pg-import \
  -u https://localhost:8443 \
  -p root \
  -i demo/flows/01-ingest-orders-pipeline.xml

# Versionar no Registry
$NIFI_TOOLKIT/bin/cli.sh registry create-flow \
  -u http://nifi-registry:18080 \
  -b demo-flows \
  -fn "Ingest Orders Pipeline" \
  -fd "Ingests order CSV files to Kafka"
```

---

## 📊 Status dos Flows

### Flows Disponíveis

| # | Nome | Arquivo XML | Tamanho | Status |
|---|------|-------------|---------|--------|
| 01 | Ingest Orders Pipeline | `01-ingest-orders-pipeline.xml` | 16KB | ✅ Pronto |
| 02 | Stream Processing Pipeline | `02-stream-processing-pipeline.xml` | 18KB | ✅ Pronto |
| 03 | Data Quality Pipeline | `03-data-quality-pipeline.xml` | 23KB | ✅ Pronto |
| 04 | Backup to S3 Pipeline | `04-backup-to-s3-pipeline.xml` | 22KB | ✅ Pronto |
| 05 | Realtime Aggregation Pipeline | `05-realtime-aggregation-pipeline.xml` | 25KB | ✅ Pronto |

---

## ⚠️ Troubleshooting

### Erro: "Templates option not available in NiFi 2.7.2"

**Causa:** NiFi 2.7.2+ removeu o suporte a templates XML diretos.

**Solução:** Usar o workflow via Registry (script `import-flows.sh`).

---

### Erro: "flowContents não deve ser nulo"

**Causa:** Formato JSON inválido ao importar diretamente no Registry.

**Solução:**
```bash
# Use o script de importação que gera o formato correto
./scripts/import-flows.sh
```

---

### Erro: "Flow already exists"

**Causa:** Flow com mesmo nome já existe no bucket.

**Solução:**
```bash
# Opção 1: Deletar flow existente via API
curl -X DELETE http://localhost:18080/nifi-registry-api/buckets/<bucket-id>/flows/<flow-id>

# Opção 2: Modificar nome no script antes de importar
# Editar: scripts/import-flows-to-registry.py
```

---

### Erro: "Connection refused to Registry"

**Causa:** NiFi não consegue conectar ao Registry.

**Solução:**
```bash
# Verificar se Registry está rodando
docker ps | grep nifi-registry

# Testar conectividade
curl http://localhost:18080/nifi-registry/

# Verificar logs
docker logs nifi-registry

# Importante: Use URL interna no Docker
# NiFi usa: http://nifi-registry:18080 (nome do container)
# Browser usa: http://localhost:18080 (porta exposta)
```

---

### Erro: "Cannot connect to Registry"

**Causa:** NiFi não consegue acessar o Registry Client configurado.

**Solução:**
```bash
# Verificar se Registry está rodando
docker ps | grep nifi-registry

# Verificar logs do Registry
docker logs nifi-registry

# Testar conectividade
curl http://localhost:18080/nifi-registry/

# Usar URL interna do Docker se necessário
# URL: http://nifi-registry:18080 (dentro do container)
# URL: http://localhost:18080 (fora do container)
```

---

## 🎯 Próximos Passos

Após importar e versionar todos os 5 flows:

1. **Configurar Controller Services:**
   - Kafka Producers/Consumers
   - Schema Registry
   - Database Connection Pools (Trino, PostgreSQL)
   - S3 Client (MinIO)

2. **Configurar Variáveis:**
   - Kafka bootstrap servers
   - Database connection strings
   - S3 endpoints e credentials
   - Diretórios de dados

3. **Testar Flows:**
   - Seguir `TESTING_GUIDE.md`
   - Verificar conectividade com serviços
   - Executar testes de integração

4. **Documentar Mudanças:**
   - Commit no Registry após cada modificação
   - Adicionar comentários descritivos
   - Manter histórico de versões

---

## 📚 Referências

- **NiFi User Guide:** https://nifi.apache.org/docs/nifi-docs/html/user-guide.html
- **NiFi Registry User Guide:** https://nifi.apache.org/docs/nifi-registry-docs/html/user-guide.html
- **NiFi CLI Guide:** https://nifi.apache.org/docs/nifi-docs/html/toolkit-guide.html
- **REST API Documentation:** https://nifi.apache.org/docs/nifi-registry-docs/rest-api/index.html

---

**Criado em:** 2026-02-05
**Última atualização:** 2026-02-05
