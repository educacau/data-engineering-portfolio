# Configurar NiFi Registry com GitHub Remote

Guia para configurar o NiFi Registry para fazer push automático dos flows para um repositório GitHub.

## 📍 Estado Atual

Atualmente, os flows estão armazenados em um **repositório Git local** dentro do container:

```
Container: /opt/nifi-registry/flow-storage
Volume:    /var/lib/docker/volumes/data-lakehouse_nifi_registry_flow_storage/_data
```

## 🎯 Objetivo

Configurar o NiFi Registry para fazer **push automático** dos commits para o GitHub, permitindo:

- ✅ Backup off-site dos flows
- ✅ Colaboração entre equipes
- ✅ Histórico completo visível no GitHub
- ✅ CI/CD integration
- ✅ Code review via Pull Requests

---

## 🐙 Configuração GitHub Remote

### Passo 1: Criar Repositório no GitHub

1. Acesse https://github.com/new
2. Configurações do repositório:

| Campo | Valor |
|-------|-------|
| **Repository name** | `nifi-flows` (ou seu nome preferido) |
| **Description** | `NiFi flow definitions with version control` |
| **Visibility** | **🔒 Private** (recomendado - flows podem ter configs sensíveis) |
| **Initialize** | ❌ **NÃO** marque README, .gitignore ou LICENSE |

3. Clique **Create repository**
4. **Copie a URL do repositório:**
   ```
   https://github.com/SEU-USERNAME/nifi-flows.git
   ```

### Passo 2: Criar Personal Access Token (PAT)

O NiFi Registry precisa de autenticação para fazer push ao GitHub.

1. GitHub → **Settings** (seu perfil)
2. **Developer settings** → **Personal access tokens** → **Tokens (classic)**
3. Clique **Generate new token (classic)**
4. Configurações do token:

| Campo | Valor |
|-------|-------|
| **Note** | `NiFi Registry Flow Push` |
| **Expiration** | `No expiration` ou `1 year` |
| **Scopes** | ✅ **repo** (Full control of private repositories) |

5. Clique **Generate token**
6. **⚠️ COPIE O TOKEN IMEDIATAMENTE** (formato: `ghp_xxxxxxxxxxxx`)
   - Ele só é exibido uma vez!
   - Guarde em local seguro (ex: gerenciador de senhas)

### Passo 3: Configurar .env com Credenciais

Adicione as credenciais GitHub ao arquivo `.env`:

```bash
# Navegue até o diretório docker
cd docker

# Edite o arquivo .env (crie se não existir)
nano .env  # ou vim, code, notepad++
```

Adicione estas linhas ao final do arquivo:

```bash
# =============================================================================
# NiFi Registry - GitHub Remote Configuration
# =============================================================================

# Seu username do GitHub
GITHUB_USERNAME=seu-username-aqui

# Personal Access Token criado no passo anterior
GITHUB_TOKEN=ghp_seu_token_aqui

# URL do repositório (HTTPS)
GITHUB_REPO_URL=https://github.com/seu-username-aqui/nifi-flows.git
```

**Exemplo:**
```bash
GITHUB_USERNAME=educacau
GITHUB_TOKEN=ghp_1234567890abcdefghijklmnopqrstuvwxyz
GITHUB_REPO_URL=https://github.com/educacau/nifi-flows.git
```

⚠️ **Segurança:**
- ✅ `.env` está no `.gitignore` (nunca commite tokens!)
- ✅ Use tokens com escopo mínimo necessário
- ✅ Rotacione tokens periodicamente

### Passo 4: Atualizar docker-compose.yml

Adicione as variáveis de ambiente do GitHub ao serviço `nifi-registry`:

```yaml
  nifi-registry:
    build:
      context: ./nifi-registry
      dockerfile: Dockerfile
    image: nifi-registry:2.7.2-postgresql
    container_name: nifi-registry
    environment:
      # ... variáveis existentes ...

      # Flow Provider Configuration (Git + Database hybrid)
      NIFI_REGISTRY_FLOW_PROVIDER: git
      NIFI_REGISTRY_FLOW_STORAGE_DIR: /opt/nifi-registry/flow-storage

      # Git Remote Configuration (GitHub)
      NIFI_REGISTRY_GIT_REMOTE: origin
      NIFI_REGISTRY_GIT_REMOTE_URL: ${GITHUB_REPO_URL}
      NIFI_REGISTRY_GIT_USER: ${GITHUB_USERNAME}
      NIFI_REGISTRY_GIT_PASSWORD: ${GITHUB_TOKEN}

      # Git configuration for commits
      GIT_AUTHOR_NAME: NiFi Registry
      GIT_AUTHOR_EMAIL: nifi-registry@localhost
      GIT_COMMITTER_NAME: NiFi Registry
      GIT_COMMITTER_EMAIL: nifi-registry@localhost
    # ... resto da configuração ...
```

### Passo 5: Rebuild e Restart

```bash
# Parar o container atual
docker compose down nifi-registry

# Rebuild da imagem (se necessário)
docker compose build nifi-registry

# Iniciar com novas configurações
docker compose up -d nifi-registry

# Verificar logs
docker logs -f nifi-registry
```

### Passo 6: Configurar Remote no Repositório Existente

Se você já tem commits locais, precisa configurar o remote e fazer push inicial:

```bash
# Entrar no container
docker exec -it nifi-registry bash

# Navegar para o repositório
cd /opt/nifi-registry/flow-storage

# Adicionar remote origin
git remote add origin https://github.com/SEU-USERNAME/nifi-flows.git

# Configurar credenciais (temporário para push inicial)
git config credential.helper store

# Fazer push inicial
git push -u origin master

# Sair do container
exit
```

Você será solicitado a informar:
- **Username:** Seu GitHub username
- **Password:** Seu Personal Access Token (não a senha da conta!)

---

## 🔄 Fluxo de Trabalho com GitHub

### Como Funciona Após Configuração

1. **Você versiona um flow no NiFi** (Version → Commit local changes)
2. **NiFi Registry cria um commit local** no Git
3. **NiFi Registry automaticamente faz push** para o GitHub 🚀
4. **Commit aparece no GitHub** com histórico completo!

### Verificar Push Automático

```bash
# Ver remotes configurados
docker exec nifi-registry git -C /opt/nifi-registry/flow-storage remote -v

# Ver último commit local
docker exec nifi-registry git -C /opt/nifi-registry/flow-storage log -1

# Ver status (deve estar sincronizado)
docker exec nifi-registry git -C /opt/nifi-registry/flow-storage status

# Forçar push manual (se necessário)
docker exec nifi-registry git -C /opt/nifi-registry/flow-storage push origin master
```

### Visualizar no GitHub

1. Acesse https://github.com/SEU-USERNAME/nifi-flows
2. Você verá:
   - 📁 Estrutura de diretórios: `[bucket-id]/[flow-id]/[version].snapshot`
   - 📝 Histórico de commits com mensagens descritivas
   - 👤 Autor: "NiFi Registry"
   - 🕐 Data/hora de cada versão

---

## 🔍 Estrutura do Repositório GitHub

Após o push, seu repositório no GitHub terá esta estrutura:

```
nifi-flows/
├── README.md (opcional - você pode criar manualmente)
├── fbb45593-66ab-4205-b311-c19c26aa6070/    # Bucket ID: test-bucket
│   └── test-flow-id/                         # Flow ID
│       └── 1.snapshot                         # Versão 1
├── abc12345-67ab-89cd-ef01-234567890abc/    # Bucket ID: production-flows
│   ├── ingest-orders-pipeline/               # Flow 1
│   │   ├── 1.snapshot                        # v1
│   │   ├── 2.snapshot                        # v2
│   │   └── 3.snapshot                        # v3
│   └── enrich-customer-data/                 # Flow 2
│       ├── 1.snapshot                        # v1
│       └── 2.snapshot                        # v2
└── xyz98765-43ab-21cd-fe10-987654321cba/    # Bucket ID: development-flows
    └── experimental-flow/                    # Flow 3
        └── 1.snapshot                         # v1
```

### Exemplo de Commit no GitHub

```
commit a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0
Author: NiFi Registry <nifi-registry@localhost>
Date:   Thu Feb 5 10:30:45 2026 +0000

    Create flow ingest-orders-pipeline in bucket production-flows

    Created by: admin
    Comments: v1: Configuração inicial do pipeline de ingestão

 .../ingest-orders-pipeline/1.snapshot | 245 +++++++++++++++++++++
 1 file changed, 245 insertions(+)
```

---

## 🔒 Segurança e Best Practices

### Proteção de Credenciais

✅ **FAÇA:**
- Use Personal Access Tokens em vez de senha da conta
- Armazene tokens no arquivo `.env` (não comite!)
- Use repositórios privados para flows de produção
- Rotacione tokens periodicamente (ex: a cada 6 meses)
- Use tokens com escopo mínimo (`repo` apenas)

❌ **NÃO FAÇA:**
- Commitar tokens no Git
- Usar senha da conta GitHub
- Compartilhar tokens entre projetos
- Usar tokens pessoais em produção (use service accounts)
- Tornar público repositório com configs sensíveis

### Informações Sensíveis nos Flows

**Atenção:** Os snapshots JSON contêm:
- ✅ Estrutura do flow (processadores, conexões)
- ✅ Configurações dos processadores
- ⚠️ **Potencialmente:** URLs, hostnames, usernames
- ❌ **Nunca:** Senhas (NiFi usa Parameter Contexts)

**Recomendações:**
1. Use **Parameter Contexts** para valores sensíveis
2. Não hardcode credenciais nos processadores
3. Revise snapshots antes de tornar repo público
4. Use `.gitignore` para excluir backups locais

### Exemplo de .gitignore para o Repositório GitHub

Crie um arquivo `.gitignore` no repositório `nifi-flows`:

```gitignore
# Backups locais
*.bak
*.backup
*.tmp

# Arquivos de configuração local
.env
.env.local
credentials.json

# IDEs
.vscode/
.idea/
*.swp
*.swo

# OS
.DS_Store
Thumbs.db
```

---

## 🛠️ Troubleshooting

### Erro: "Authentication failed"

**Causa:** Token inválido ou sem permissões

**Soluções:**
1. Verifique se o token está correto no `.env`
2. Confirme que o token tem scope `repo`
3. Teste o token manualmente:
   ```bash
   curl -H "Authorization: token SEU_TOKEN" https://api.github.com/user
   ```
4. Regenere o token se necessário

### Erro: "Remote repository not found"

**Causa:** URL do repositório incorreta

**Soluções:**
1. Verifique a URL em `GITHUB_REPO_URL`
2. Confirme que o repositório existe no GitHub
3. Use HTTPS URL (não SSH): `https://github.com/user/repo.git`

### Push não Acontece Automaticamente

**Causa:** Configuração de remote não aplicada

**Soluções:**
1. Verifique se `NIFI_REGISTRY_GIT_REMOTE: origin` está configurado
2. Confirme que as variáveis de ambiente foram carregadas:
   ```bash
   docker exec nifi-registry env | grep GIT
   ```
3. Recrie o container:
   ```bash
   docker compose down nifi-registry
   docker compose up -d nifi-registry
   ```

### Ver Erros de Push nos Logs

```bash
# Ver logs completos do NiFi Registry
docker logs nifi-registry 2>&1 | grep -i "git\|push\|remote"

# Logs em tempo real
docker logs -f nifi-registry
```

### Testar Conectividade com GitHub

```bash
# De dentro do container
docker exec nifi-registry bash -c "
  git ls-remote https://github.com/SEU-USERNAME/nifi-flows.git
"
```

Se falhar, pode ser problema de rede ou autenticação.

---

## 🔄 Migração de Repositório Local para GitHub

Se você já tem commits locais e quer migrar para GitHub:

### Opção 1: Push Simples (Recomendado)

```bash
# 1. Criar repositório vazio no GitHub (sem README)

# 2. Adicionar remote
docker exec nifi-registry git -C /opt/nifi-registry/flow-storage \
  remote add origin https://github.com/SEU-USERNAME/nifi-flows.git

# 3. Push de todo histórico
docker exec nifi-registry git -C /opt/nifi-registry/flow-storage \
  push -u origin master

# 4. Verificar no GitHub
```

### Opção 2: Backup Completo e Restore

```bash
# 1. Fazer backup do repositório local
docker cp nifi-registry:/opt/nifi-registry/flow-storage ./flows-backup

# 2. Criar repo no GitHub e clonar localmente
git clone https://github.com/SEU-USERNAME/nifi-flows.git
cd nifi-flows

# 3. Copiar conteúdo do backup
cp -r ../flows-backup/* .
cp -r ../flows-backup/.git .

# 4. Push
git push origin master

# 5. Reconfigurar container para usar o novo remote
```

---

## 📊 Monitoramento e Auditoria

### Ver Histórico Completo

```bash
# No GitHub
https://github.com/SEU-USERNAME/nifi-flows/commits/master

# Via CLI
docker exec nifi-registry git -C /opt/nifi-registry/flow-storage log --graph --oneline --all
```

### Auditoria de Mudanças

```bash
# Ver quem modificou um flow específico
docker exec nifi-registry git -C /opt/nifi-registry/flow-storage \
  log --follow -- [bucket-id]/[flow-id]/

# Ver diferenças entre versões
docker exec nifi-registry git -C /opt/nifi-registry/flow-storage \
  diff [version1].snapshot [version2].snapshot
```

### Notificações de Commits

Configure GitHub Actions ou webhooks para receber notificações quando flows são atualizados:

```yaml
# .github/workflows/notify-on-flow-update.yml
name: Notify on Flow Update

on:
  push:
    branches: [ master ]
    paths:
      - '**/*.snapshot'

jobs:
  notify:
    runs-on: ubuntu-latest
    steps:
      - name: Send notification
        run: |
          echo "Flow updated: ${{ github.event.head_commit.message }}"
          # Adicionar integração Slack, Teams, Email, etc.
```

---

## 🎯 Benefícios da Integração GitHub

### Para Desenvolvimento

- ✅ **Code Review:** Pull Requests para mudanças em flows
- ✅ **Colaboração:** Múltiplos desenvolvedores podem contribuir
- ✅ **Histórico:** Ver evolução completa dos flows
- ✅ **Rollback:** Reverter para versões anteriores facilmente

### Para Operações

- ✅ **Backup:** Cópia off-site automática
- ✅ **Disaster Recovery:** Restaurar flows de qualquer ponto no tempo
- ✅ **Auditoria:** Rastreabilidade completa de mudanças
- ✅ **Compliance:** Evidências para auditorias

### Para CI/CD

- ✅ **Automação:** Detectar mudanças e trigger pipelines
- ✅ **Testing:** Validar flows automaticamente
- ✅ **Deploy:** Promover flows entre ambientes
- ✅ **Documentation:** Gerar docs a partir dos snapshots

---

## 📚 Recursos Adicionais

- [GitHub Personal Access Tokens](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token)
- [Git Remote Configuration](https://git-scm.com/book/en/v2/Git-Basics-Working-with-Remotes)
- [NiFi Registry Git Provider](https://nifi.apache.org/docs/nifi-registry-docs/html/administration-guide.html#gitflowpersistenceprovider)
- [NIFI_REGISTRY_GIT.md](./NIFI_REGISTRY_GIT.md) - Configuração Git local
- [NIFI_REGISTRY_SETUP.md](./NIFI_REGISTRY_SETUP.md) - Setup completo

---

## ✅ Checklist de Configuração GitHub

- [ ] Repositório privado criado no GitHub
- [ ] Personal Access Token gerado com scope `repo`
- [ ] Token adicionado ao arquivo `.env`
- [ ] Variáveis de ambiente GitHub adicionadas ao `docker-compose.yml`
- [ ] Container NiFi Registry recriado com novas configs
- [ ] Remote `origin` configurado no repositório Git
- [ ] Push inicial realizado com sucesso
- [ ] Commits aparecendo no GitHub
- [ ] Novo flow versionado → push automático funcionando
- [ ] Histórico completo visível no GitHub

**Se todos os itens estão marcados, a integração GitHub está completa! 🎉**
