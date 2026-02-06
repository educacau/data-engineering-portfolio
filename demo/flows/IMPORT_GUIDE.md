# Guia de Importação de Flows - NiFi Registry

Este guia explica como importar corretamente os flow templates no Apache NiFi e versioná-los no NiFi Registry.

---

## 🔍 Entendendo os Formatos

### Templates XML (.xml)
- **Uso:** Importar no **NiFi Canvas** (interface do NiFi)
- **Formato:** Apache NiFi Template XML
- **Ação:** Upload via interface ou NiFi CLI

### Flow Snapshots JSON (.json)
- **Uso:** Importar diretamente no **NiFi Registry** via API
- **Formato:** VersionedFlowSnapshot JSON
- **Ação:** POST via REST API (workflow avançado)

---

## ✅ Workflow Recomendado (Interface)

### Passo 1: Importar Template no NiFi Canvas

1. **Acesse o NiFi:**
   ```
   https://localhost:8443/nifi
   Username: nifi
   Password: changeme123
   ```

2. **Importar Template:**
   - Clique no menu hambúrguer (☰) no canto superior direito
   - Selecione **Templates**
   - Clique no botão **Upload Template** (ícone de upload)
   - Navegue até `demo/flows/`
   - Selecione um arquivo **XML** (ex: `01-ingest-orders-pipeline.xml`)
   - Clique **Upload**
   - Clique **OK** na confirmação

3. **Adicionar ao Canvas:**
   - Arraste o ícone **Template** (ícone de página) da barra superior para o canvas
   - Selecione o template que você acabou de importar
   - Clique **Add**
   - O Process Group será criado no canvas

### Passo 2: Versionar no Registry

1. **Conectar ao Registry:**
   - Clique no menu hambúrguer (☰)
   - Selecione **Controller Settings**
   - Vá para a aba **Registry Clients**
   - Adicione um novo Registry Client:
     - **Name:** Local Registry
     - **URL:** `http://nifi-registry:18080`
     - **Description:** NiFi Registry local
   - Clique **Add**, depois **Apply** e **Close**

2. **Iniciar Version Control:**
   - Clique direito no Process Group que você adicionou
   - Selecione **Version → Start version control**
   - Preencha:
     - **Registry:** Local Registry
     - **Bucket:** Crie um novo bucket (ex: `demo-flows`)
     - **Flow Name:** Nome descritivo (ex: `Ingest Orders Pipeline`)
     - **Flow Description:** Descrição do flow
     - **Comments:** `Initial version`
   - Clique **Save**

3. **Confirmar Versionamento:**
   - O Process Group agora exibe um ícone de versão verde (✓)
   - Significa que está sincronizado com o Registry
   - Todas as mudanças futuras podem ser commitadas

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

### Erro: "flowContents não deve ser nulo"

**Causa:** Tentou importar arquivo JSON diretamente no Registry sem a estrutura VersionedFlowSnapshot correta.

**Solução:** Use os arquivos **XML** e siga o workflow recomendado acima.

---

### Erro: "Template already exists"

**Causa:** Template com mesmo nome já foi importado.

**Solução:**
```bash
# Remover template existente
# NiFi UI: Menu (☰) → Templates → Selecionar template → Delete
# Ou importar com nome diferente
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
