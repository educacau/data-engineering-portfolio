# NiFi Flow Definitions

Este diretório contém as definições versionadas dos flows do Apache NiFi, gerenciadas pelo NiFi Registry com controle de versão Git.

## 📁 Estrutura

```
flows/
├── [bucket-id]/              # ID do bucket (ex: production-flows)
│   └── [flow-id]/            # ID do flow
│       ├── 1.snapshot        # Versão 1
│       ├── 2.snapshot        # Versão 2
│       └── 3.snapshot        # Versão 3
└── README.md                 # Este arquivo
```

## 🔄 Sincronização

Os flows são sincronizados do NiFi Registry (container Docker) para este diretório usando o script:

```bash
# Executar do diretório raiz do projeto
./scripts/sync-flows.sh

# Modo dry-run (ver mudanças sem aplicar)
./scripts/sync-flows.sh --dry-run
```

## 📝 Formato dos Snapshots

Cada arquivo `.snapshot` é um JSON contendo:

- **header**: Metadados (nome, versão, bucket, autor, data)
- **content**: Definição completa do flow (processadores, conexões, configurações)

### Exemplo

```json
{
  "header": {
    "flowId": "abc123",
    "flowName": "Ingest Orders Pipeline",
    "bucketId": "xyz789",
    "bucketName": "production-flows",
    "version": 1,
    "author": "nifi",
    "created": 1770274341103,
    "comments": "v1: Initial configuration"
  },
  "content": {
    "identifier": "root-pg",
    "name": "Ingest Orders Pipeline",
    "processors": [ /* ... */ ],
    "connections": [ /* ... */ ]
  }
}
```

## 🎯 Workflow

### 1. Desenvolver Flow no NiFi

1. Acesse: https://localhost:8443/nifi
2. Crie/modifique um Process Group
3. Versione: `Version → Start version control` ou `Commit local changes`

### 2. Sincronizar com Repositório

```bash
# Sincronizar flows
./scripts/sync-flows.sh

# Verificar mudanças
git status
git diff flows/

# Commitar
git add flows/
git commit -m "feat: update ingest-orders-pipeline to v2"
git push
```

### 3. Deployment

Para deploy em outro ambiente:

1. Copie os snapshots desejados
2. Importe no NiFi Registry de destino
3. Faça deploy no NiFi usando "Change version"

## 📊 Mapeamento Bucket ID → Nome

Os diretórios usam IDs únicos gerados pelo NiFi Registry. Para referência:

| Bucket ID | Nome do Bucket | Ambiente |
|-----------|----------------|----------|
| `fbb45593-66ab-4205-b311-c19c26aa6070` | test-bucket | Development |
| _(adicione conforme criar buckets)_ | | |

## 🔍 Comandos Úteis

### Ver flows no container

```bash
# Listar todos os snapshots
docker exec nifi-registry find /opt/nifi-registry/flow-storage -name "*.snapshot"

# Ver commits Git
docker exec nifi-registry git -C /opt/nifi-registry/flow-storage log --oneline

# Ver conteúdo de um snapshot
docker exec nifi-registry cat /opt/nifi-registry/flow-storage/[bucket-id]/[flow-id]/[version].snapshot
```

### Comparar versões

```bash
# Diff entre versões locais
diff flows/[bucket-id]/[flow-id]/1.snapshot flows/[bucket-id]/[flow-id]/2.snapshot

# Diff no Git (se commitado)
git diff HEAD~1 flows/
```

## 🔒 Segurança

**Atenção:** Os snapshots podem conter:
- URLs e hostnames de sistemas
- Nomes de usuários
- Configurações de sistema
- Estrutura de dados

**Boas práticas:**
- ✅ Use Parameter Contexts para valores sensíveis
- ✅ Não hardcode credenciais
- ✅ Revise snapshots antes de commits
- ✅ Mantenha repositório privado se flows contêm info sensível

## 📚 Documentação

- [NIFI_REGISTRY_SETUP.md](../docs/NIFI_REGISTRY_SETUP.md) - Como configurar Registry
- [NIFI_REGISTRY_GIT.md](../docs/NIFI_REGISTRY_GIT.md) - Integração Git detalhada
- [NIFI_REGISTRY_GITHUB.md](../docs/NIFI_REGISTRY_GITHUB.md) - Push para GitHub
- [NiFi Version Control Docs](https://nifi.apache.org/docs/nifi-docs/html/user-guide.html#versioning-dataflow)

---

**Última sincronização:** Execute `./scripts/sync-flows.sh` para atualizar
