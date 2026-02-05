# Como Configurar NiFi Registry no NiFi

Guia passo a passo para conectar o NiFi ao NiFi Registry com integração Git.

## 🔐 Credenciais de Acesso

### NiFi
- **URL:** https://localhost:8443/nifi
- **Username:** `nifi`
- **Password:** `changeme123`

### NiFi Registry
- **URL:** http://localhost:18080/nifi-registry
- Sem autenticação (desenvolvimento)

---

## 📝 Configuração do Registry Client

### Passo 1: Acessar Controller Settings

1. Acesse https://localhost:8443/nifi
2. Faça login com as credenciais acima
3. No canto superior direito, clique no menu hambúrguer (☰)
4. Selecione **Controller Settings**

### Passo 2: Adicionar Registry Client

1. Na janela "NiFi Settings", vá para a aba **Registry Clients**
2. Clique no botão **+** (plus) no canto superior direito
3. Preencha o formulário:

| Campo | Valor |
|-------|-------|
| **Name** | `NiFi Registry (Local)` |
| **URL** | `http://nifi-registry:18080` |
| **Description** | `Local NiFi Registry with Git integration` |

⚠️ **IMPORTANTE:** Use o hostname do container (`nifi-registry`), não `localhost`!

4. Clique em **Add**
5. Feche a janela com **Close**

### Passo 3: Verificar Conexão

Você deve ver:
- ✅ Indicador verde ao lado do registry
- Nome "NiFi Registry (Local)" na lista
- Status: Connected

Se houver erro:
```bash
# Verificar se o Registry está rodando
docker ps | grep nifi-registry

# Testar conectividade
docker exec nifi-1 curl http://nifi-registry:18080/nifi-registry-api/buckets
```

---

## 🧪 Criar e Versionar um Flow

### Passo 1: Criar um Bucket no Registry (se ainda não existe)

Via API REST:
```bash
curl -X POST http://localhost:18080/nifi-registry-api/buckets \
  -H "Content-Type: application/json" \
  -d '{
    "name": "production-flows",
    "description": "Production-ready data flows",
    "allowPublicRead": false
  }'
```

Via UI do Registry:
1. Acesse http://localhost:18080/nifi-registry
2. Clique no ícone de **wrench** (Settings)
3. Clique em **New Bucket**
4. Nome: `production-flows`
5. Clique em **Create**

### Passo 2: Criar um Process Group no NiFi

1. No canvas do NiFi, arraste o ícone **Process Group** da toolbar
2. Nome: `Ingest Orders Pipeline`
3. Clique **Add**

### Passo 3: Adicionar Processadores ao Flow

1. **Entre no Process Group** (duplo clique)
2. Adicione processadores conforme seu pipeline:

**Exemplo: Pipeline Simples de Geração de Dados**
```
GenerateFlowFile → UpdateAttribute → LogAttribute
```

Para cada processador:
- Arraste o ícone **Processor**
- Busque pelo nome (ex: `GenerateFlowFile`)
- Configure conforme necessário
- Conecte os processadores arrastando a seta

3. Configure auto-termination para as relationships não utilizadas

### Passo 4: Iniciar Controle de Versão

1. **Volte para o nível root** (breadcrumb inferior esquerdo ou clique em "NiFi Flow")
2. **Clique direito** no Process Group
3. Selecione **Version → Start version control**

### Passo 5: Salvar a Primeira Versão

Na janela "Save Flow Version":

| Campo | Exemplo |
|-------|---------|
| **Registry** | `NiFi Registry (Local)` |
| **Bucket** | `production-flows` |
| **Flow Name** | `ingest-orders-pipeline` |
| **Flow Description** | `Pipeline para ingestão de pedidos do e-commerce` |
| **Comments** | `v1: Configuração inicial com GenerateFlowFile` |

Clique **Save**

### Passo 6: Confirmar Versionamento

Após salvar, você verá:
- ✅ **Checkmark verde** (✓) no Process Group
- **Versão "v1"** exibida no ícone
- **Nome do bucket** ao lado do ícone

---

## 🔄 Fluxo de Trabalho com Versionamento

### Fazer Mudanças no Flow

1. Entre no Process Group
2. Adicione/modifique/remova processadores
3. O ícone mudará para **asterisco verde** (✱) indicando mudanças não salvas
4. Volte ao nível root

### Commitar Mudanças (Save Changes)

1. Clique direito no Process Group
2. Selecione **Version → Commit local changes**
3. Adicione um comentário descritivo:
   ```
   v2: Adiciona validação de schema com ValidateRecord
   ```
4. Clique **Save**

### Reverter para Versão Anterior

1. Clique direito no Process Group
2. Selecione **Version → Change version**
3. Selecione a versão desejada no dropdown
4. Clique **Change**
5. **⚠️ ATENÇÃO:** Isso sobrescreverá as mudanças locais!

### Ver Histórico de Versões

1. Clique direito no Process Group
2. Selecione **Version → View version history**
3. Você verá todas as versões com:
   - Número da versão
   - Data/hora
   - Autor
   - Comentários

### Parar Controle de Versão

1. Clique direito no Process Group
2. Selecione **Version → Stop version control**
3. Confirme a ação
4. ⚠️ O flow continuará existindo no Registry, mas não estará mais vinculado

---

## 🔍 Verificar Commits no Git

### Comandos de Verificação

```bash
# Ver histórico de commits
docker exec nifi-registry git -C /opt/nifi-registry/flow-storage log --oneline

# Ver detalhes do último commit
docker exec nifi-registry git -C /opt/nifi-registry/flow-storage log -1 --stat

# Listar todos os snapshots
docker exec nifi-registry find /opt/nifi-registry/flow-storage -name "*.snapshot"

# Ver conteúdo de um snapshot específico
docker exec nifi-registry cat /opt/nifi-registry/flow-storage/[bucket-id]/[flow-id]/[version].snapshot

# Visualizar diff entre versões
docker exec nifi-registry git -C /opt/nifi-registry/flow-storage diff HEAD~1 HEAD
```

### Exemplo de Saída

```bash
$ docker exec nifi-registry git -C /opt/nifi-registry/flow-storage log --oneline
a1b2c3d Create flow ingest-orders-pipeline in bucket production-flows
e8bbc8a Create flow Test Flow in bucket test-bucket
```

---

## 🎯 Estrutura do Repositório Git

```
/opt/nifi-registry/flow-storage/
├── .git/                                    # Metadados do Git
├── [bucket-id-1]/                           # Bucket 1
│   ├── [flow-id-1]/                         # Flow 1
│   │   ├── 1.snapshot                       # Versão 1
│   │   ├── 2.snapshot                       # Versão 2
│   │   └── 3.snapshot                       # Versão 3
│   └── [flow-id-2]/                         # Flow 2
│       └── 1.snapshot                       # Versão 1
└── [bucket-id-2]/                           # Bucket 2
    └── [flow-id-3]/                         # Flow 3
        ├── 1.snapshot                       # Versão 1
        └── 2.snapshot                       # Versão 2
```

Cada `.snapshot` é um arquivo JSON contendo:
- **Header**: Metadados do flow (ID, nome, bucket, versão)
- **Content**: Definição completa do flow (processadores, conexões, configurações)

---

## 📊 Exemplo de Snapshot JSON

```json
{
  "header": {
    "dataModelVersion": "3",
    "flowId": "abc123-flow-id",
    "flowName": "Ingest Orders Pipeline",
    "bucketId": "xyz789-bucket-id",
    "bucketName": "production-flows",
    "version": 1,
    "author": "nifi",
    "created": 1770274341103,
    "comments": "v1: Configuração inicial"
  },
  "content": {
    "identifier": "root-pg-id",
    "name": "Ingest Orders Pipeline",
    "processors": [
      {
        "identifier": "proc-1",
        "name": "Generate Orders",
        "type": "org.apache.nifi.processors.standard.GenerateFlowFile",
        "properties": {
          "Batch Size": "1000",
          "File Size": "1KB"
        }
      }
    ],
    "connections": [
      {
        "identifier": "conn-1",
        "source": {
          "id": "proc-1"
        },
        "destination": {
          "id": "proc-2"
        }
      }
    ]
  }
}
```

---

## 🛠️ Troubleshooting

### Erro: "Unable to communicate with NiFi Registry"

**Causa:** NiFi não consegue alcançar o Registry

**Soluções:**
1. Verifique se o Registry está rodando:
   ```bash
   docker ps | grep nifi-registry
   ```

2. Teste conectividade de dentro do container NiFi:
   ```bash
   docker exec nifi-1 curl http://nifi-registry:18080/nifi-registry-api/buckets
   ```

3. Verifique se os containers estão na mesma rede Docker:
   ```bash
   docker network inspect data-lakehouse_backend
   ```

4. Verifique a URL configurada no Registry Client (deve ser `http://nifi-registry:18080`)

### Erro: "Bucket not found"

**Causa:** O bucket selecionado não existe no Registry

**Soluções:**
1. Liste os buckets disponíveis:
   ```bash
   curl http://localhost:18080/nifi-registry-api/buckets
   ```

2. Crie um bucket via API ou UI do Registry
3. Atualize a lista de buckets no NiFi (feche e reabra o dialog)

### Erro: "Flow name already exists"

**Causa:** Já existe um flow com o mesmo nome no bucket

**Soluções:**
1. Use um nome diferente
2. Ou delete o flow antigo:
   ```bash
   curl -X DELETE http://localhost:18080/nifi-registry-api/buckets/[bucket-id]/flows/[flow-id]
   ```

### Ícone com Asterisco Amarelo (⚠)

**Significado:** Mudanças locais conflitando com a versão do Registry

**Soluções:**
1. **Commit local changes:** Salvar suas mudanças como nova versão
2. **Revert local changes:** Descartar mudanças e voltar à versão do Registry
3. **View local changes:** Ver o diff das mudanças

---

## 🚀 Best Practices

### Nomenclatura

- **Buckets:** Use nomes descritivos por ambiente ou equipe
  - `production-flows`, `development-flows`, `team-data-engineering`

- **Flows:** Use kebab-case e seja descritivo
  - `ingest-orders-from-kafka`, `enrich-customer-data`, `backup-to-s3`

### Comentários de Commit

Seja descritivo nos comentários de versão:

✅ **BOM:**
```
v2: Adiciona validação de schema JSON usando ValidateRecord
v3: Corrige timeout no InvokeHTTP para 30s
v4: Remove processador obsoleto MergeContent
```

❌ **RUIM:**
```
v2: update
v3: fix
v4: changes
```

### Organização de Buckets

Separe flows por:
- **Ambiente:** `dev-flows`, `staging-flows`, `prod-flows`
- **Domínio:** `ecommerce-flows`, `analytics-flows`, `etl-flows`
- **Equipe:** `data-engineering`, `data-science`, `platform`

### Versionamento

- **Major version (v1 → v2):** Mudanças significativas na lógica
- **Minor updates:** Ajustes de configuração, correções
- **Always commit:** Não deixe mudanças sem versionar por muito tempo

---

## 📚 Recursos Adicionais

- [NiFi Version Control Documentation](https://nifi.apache.org/docs/nifi-docs/html/user-guide.html#versioning-dataflow)
- [NiFi Registry User Guide](https://nifi.apache.org/docs/nifi-registry-docs/html/user-guide.html)
- [Git Flow Persistence Provider](https://nifi.apache.org/docs/nifi-registry-docs/html/administration-guide.html#gitflowpersistenceprovider)
- [NIFI_REGISTRY_GIT.md](./NIFI_REGISTRY_GIT.md) - Configuração Git detalhada

---

## ✅ Checklist de Configuração

Use este checklist para garantir que tudo está configurado:

- [ ] NiFi está acessível em https://localhost:8443/nifi
- [ ] NiFi Registry está acessível em http://localhost:18080/nifi-registry
- [ ] Registry Client adicionado no NiFi com URL correta
- [ ] Indicador verde de conexão ao lado do Registry Client
- [ ] Pelo menos um bucket criado no Registry
- [ ] Process Group criado e versionado com sucesso
- [ ] Checkmark verde (✓) visível no Process Group
- [ ] Commit criado no Git (verificado via `git log`)
- [ ] Snapshot JSON criado no diretório flow-storage

**Se todos os itens estão marcados, a integração está 100% funcional! 🎉**
