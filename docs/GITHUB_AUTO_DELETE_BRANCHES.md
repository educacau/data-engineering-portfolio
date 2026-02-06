# GitHub Auto-Delete Branches Configuration

Configuração para deletar automaticamente branches após merge de Pull Requests, mantendo o repositório limpo e seguindo as melhores práticas do Gitflow.

---

## ✅ Status Atual

```
Repository: educacau/data-engineering-portfolio
Auto-Delete: ✅ ATIVADO
Configurado em: 2026-02-05
```

---

## 🎯 O Que Faz

Quando você **mergeia um Pull Request** no GitHub, a branch usada para criar o PR é **automaticamente deletada**.

### Antes (Sem Auto-Delete)
```bash
# Após mergear PR #14
git branch -a
  main
  develop
* feature/nifi-flow-templates     ← ainda existe localmente
  remotes/origin/main
  remotes/origin/develop
  remotes/origin/feature/nifi-flow-templates  ← ainda existe no remote

# Você precisa deletar manualmente:
git branch -d feature/nifi-flow-templates
git push origin --delete feature/nifi-flow-templates
```

### Depois (Com Auto-Delete)
```bash
# Após mergear PR #15
git branch -a
  main
  develop
* feature/nova-feature             ← ainda existe localmente
  remotes/origin/main
  remotes/origin/develop
  # ✅ feature/nova-feature foi deletada automaticamente do remote!

# Você só precisa deletar localmente:
git branch -d feature/nova-feature
```

---

## 🔧 Como Funciona

### 1. Configuração GitHub (Já Ativa)

A configuração `delete_branch_on_merge: true` está ativada no repositório.

Você pode verificar em:
```
https://github.com/educacau/data-engineering-portfolio/settings
→ General → Pull Requests
→ ☑ Automatically delete head branches
```

### 2. Workflow Atualizado

```bash
# Passo 1: Criar feature branch
git checkout develop
git checkout -b feature/nova-funcionalidade

# Passo 2: Trabalhar e commitar
git add .
git commit -m "feat: nova funcionalidade"

# Passo 3: Push
git push origin feature/nova-funcionalidade

# Passo 4: Criar PR
./scripts/create-pr.sh

# Passo 5: Mergear PR no GitHub
# ✅ Branch remote é deletada AUTOMATICAMENTE

# Passo 6: Sync local (apenas delete local)
git checkout develop
git pull origin develop
git branch -d feature/nova-funcionalidade  # ← só isso!
```

---

## 🛠️ Script de Configuração

Se precisar ativar/verificar a configuração novamente:

```bash
./scripts/configure-auto-delete-branches.sh
```

**O que o script faz:**
- ✅ Extrai token do Git Credential Manager
- ✅ Verifica configuração atual do repositório
- ✅ Ativa `delete_branch_on_merge` se desativado
- ✅ Exibe status e instruções

---

## 📋 Comportamento Detalhado

### O Que É Deletado Automaticamente

✅ **SIM - Deletado após merge:**
- Feature branches (`feature/*`)
- Fix branches (`fix/*`)
- Hotfix branches (`hotfix/*`)
- Qualquer branch usada como **head** em um PR mergeado

❌ **NÃO - Nunca deletado:**
- `main` (protegida)
- `develop` (protegida)
- Branches que não estão em PRs
- Branches com PRs ainda abertos
- Branches com PRs fechados sem merge

### Exemplo de Ciclo de Vida

```
1. Criar branch
   └─ feature/new-flows (local + remote)

2. Criar PR #15
   └─ feature/new-flows → develop

3. Mergear PR #15
   ├─ Commit adicionado a develop ✅
   └─ feature/new-flows deletada do remote ✅

4. Sincronizar local
   ├─ git checkout develop
   ├─ git pull origin develop
   └─ git branch -d feature/new-flows  ← manual
```

---

## 🔄 Script de Sync Atualizado

O script `sync-after-merge.sh` detecta automaticamente se a branch remota foi deletada:

```bash
./scripts/sync-after-merge.sh

# Saída esperada (com auto-delete ativo):
# ✅ Feature branch deleted from remote
# Updating develop...
# Deleting local feature branch...
# Sync complete!
```

---

## ⚙️ Configuração Via GitHub UI

Se preferir configurar manualmente:

1. **Acessar Settings:**
   ```
   https://github.com/educacau/data-engineering-portfolio/settings
   ```

2. **Navegar até Pull Requests:**
   - Seção: **General** → **Pull Requests**

3. **Ativar Auto-Delete:**
   - ☑ **Automatically delete head branches**
   - Salvar (automático)

---

## 🧪 Testar a Configuração

### Teste Rápido

```bash
# 1. Criar branch de teste
git checkout develop
git checkout -b test/auto-delete
echo "test" > test.txt
git add test.txt
git commit -m "test: auto-delete configuration"
git push origin test/auto-delete

# 2. Criar PR via API
GITHUB_TOKEN=$(printf "protocol=https\nhost=github.com\n" | git credential fill | grep "password=" | cut -d'=' -f2)

curl -X POST \
  -H "Authorization: token ${GITHUB_TOKEN}" \
  -H "Accept: application/vnd.github.v3+json" \
  "https://api.github.com/repos/educacau/data-engineering-portfolio/pulls" \
  -d '{
    "title": "test: Auto-delete branch test",
    "head": "test/auto-delete",
    "base": "develop",
    "body": "Testing auto-delete configuration"
  }'

# 3. Mergear PR no GitHub

# 4. Verificar se branch foi deletada
git fetch --prune
git branch -a | grep test/auto-delete
# Resultado esperado: nenhuma saída (branch deletada)
```

---

## 🚨 Troubleshooting

### Problema: Branch não foi deletada após merge

**Possíveis causas:**

1. **Configuração desativada**
   ```bash
   # Verificar:
   ./scripts/configure-auto-delete-branches.sh
   ```

2. **Branch protegida**
   - Branches protegidas nunca são deletadas
   - Verificar em: Settings → Branches → Branch protection rules

3. **PR mergeado via linha de comando**
   - Auto-delete só funciona para merges via GitHub UI/API
   - Merges manuais (`git merge`) não ativam auto-delete

4. **Permissões insuficientes**
   - Token precisa de scope `repo` (full control)

### Problema: Script de sync reclama que branch ainda existe

**Solução:**
```bash
# Forçar fetch com prune (remove referências deletadas)
git fetch --prune

# Verificar branches remotas
git branch -r

# Se branch remota foi deletada, mas local ainda existe:
git branch -d nome-da-branch
```

---

## 📊 Benefícios

### Para o Repositório
- ✅ **Limpo:** Apenas branches ativas visíveis
- ✅ **Organizado:** Fácil identificar trabalho em andamento
- ✅ **Performance:** Menos branches = fetch/pull mais rápidos

### Para o Workflow
- ✅ **Automatizado:** Menos comandos manuais
- ✅ **Consistente:** Sempre deleta após merge
- ✅ **Seguro:** Pode restaurar branches deletadas se necessário

### Para o Time (Futuro)
- ✅ **Colaboração:** Branches antigas não confundem
- ✅ **Onboarding:** Novos membros veem apenas trabalho atual
- ✅ **Auditoria:** Histórico completo no GitHub (branches deletadas ficam no histórico)

---

## 🔐 Segurança e Recovery

### Branches Deletadas Podem Ser Recuperadas

**Sim!** Branches deletadas automaticamente podem ser restauradas:

1. **Via GitHub UI:**
   ```
   https://github.com/educacau/data-engineering-portfolio/pull/[PR_NUMBER]
   → Seção "Deleted branches"
   → Botão "Restore branch"
   ```

2. **Via Git (se souber o commit SHA):**
   ```bash
   # Encontrar SHA do último commit da branch
   git reflog | grep nome-da-branch

   # Recriar branch
   git checkout -b nome-da-branch [SHA]
   git push origin nome-da-branch
   ```

3. **Via GitHub API:**
   ```bash
   # Listar branches deletadas de um PR
   curl -H "Authorization: token ${GITHUB_TOKEN}" \
     "https://api.github.com/repos/educacau/data-engineering-portfolio/pulls/[PR_NUMBER]"
   ```

---

## 📚 Referências

- [GitHub Docs: Managing the automatic deletion of branches](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/configuring-pull-request-merges/managing-the-automatic-deletion-of-branches)
- [GitHub API: Update a repository](https://docs.github.com/en/rest/repos/repos#update-a-repository)
- [Gitflow Workflow](https://www.atlassian.com/git/tutorials/comparing-workflows/gitflow-workflow)

---

## ✅ Checklist de Configuração

- [x] Auto-delete ativado no repositório
- [x] Script `configure-auto-delete-branches.sh` criado
- [x] Documentação completa (este arquivo)
- [x] Testado com PR #14 ✅
- [x] Workflow atualizado
- [x] Time informado sobre novo comportamento

---

**Configuração ativa desde:** 2026-02-05
**Última verificação:** 2026-02-05
**Status:** ✅ Operacional
