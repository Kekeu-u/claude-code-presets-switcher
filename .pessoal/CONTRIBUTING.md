# 🛠️ Contributing — Guia de Desenvolvimento

> Como trabalhar neste projeto de forma profissional usando Git.

---

## 📁 Estrutura do Projeto

```
c:\Apps\claude-presets\              ← Repo Git (desenvolvimento)
├── switch-preset.ps1                ← Script principal
├── presets/                         ← Exemplos de preset (sem API keys!)
│   ├── kimi.json
│   ├── glm.json
│   ├── minimax.json
│   └── router.json
├── GUIA-PRESETS.md                  ← Guia detalhado em PT-BR
├── README.md                        ← Documentação do GitHub
├── CONTRIBUTING.md                  ← Este arquivo
├── LICENSE                          ← MIT
└── .gitignore

c:\Users\supar\.claude\presets\      ← Instalação local (NÃO é Git)
├── switch-preset.ps1                ← Cópia ativa do script
├── kimi.json                        ← Preset COM sua API key real
├── glm.json
├── minimax.json
├── router.json
├── oauth-backup.json                ← Auto-gerado
└── .active-preset                   ← Auto-gerado
```

> **⚠️ IMPORTANTE:** O repositório Git fica em `c:\Apps\claude-presets\`.
> A pasta `~\.claude\presets\` é a instalação local e **nunca** deve ter Git.
> Após alterar o script aqui, copie para a instalação local.

---

## 🔄 Workflow Diário

### 1. Editar

Faça suas alterações em `c:\Apps\claude-presets\`:

```powershell
cd c:\Apps\claude-presets
# Edite o switch-preset.ps1 ou os presets de exemplo
```

### 2. Testar localmente

Copie o script atualizado para a instalação ativa e teste:

```powershell
Copy-Item .\switch-preset.ps1 "$env:USERPROFILE\.claude\presets\" -Force
cmodel -List        # Testa listagem
cmodel kimi         # Testa troca
cmodel anthropic    # Testa rollback
```

### 3. Commitar

Use **Conventional Commits** — prefixos padronizados que descrevem o tipo de mudança:

```powershell
git add -A
git commit -m "tipo: descrição curta em inglês"
```

| Prefixo | Quando usar | Exemplo |
|---------|-------------|---------|
| `feat:` | Nova funcionalidade | `feat: add DeepSeek preset` |
| `fix:` | Correção de bug | `fix: router health check timeout` |
| `docs:` | Só documentação | `docs: update README with new preset` |
| `refactor:` | Refatoração sem mudar comportamento | `refactor: extract env var logic` |
| `chore:` | Tarefas internas (CI, configs) | `chore: update .gitignore` |
| `style:` | Formatação, espaços, etc. | `style: fix indentation in menu` |

### 4. Push

```powershell
git push
```

---

## 🏷️ Versionamento (Semantic Versioning)

O projeto usa **SemVer**: `vMAJOR.MINOR.PATCH`

| Parte | Quando incrementar | Exemplo |
|-------|-------------------|---------|
| **MAJOR** | Mudança que quebra compatibilidade | `v2.0.0` — formato do JSON mudou |
| **MINOR** | Nova funcionalidade retrocompatível | `v1.1.0` — novo preset adicionado |
| **PATCH** | Correção de bug | `v1.0.1` — fix no health check |

### Criar uma nova versão

```powershell
# 1. Commitar as mudanças
git add -A
git commit -m "feat: add deepseek preset"

# 2. Criar tag anotada
git tag -a v1.1.0 -m "v1.1.0 - Add DeepSeek preset

- New DeepSeek R1 preset
- Updated docs"

# 3. Push tudo
git push
git push origin v1.1.0
```

### Criar GitHub Release (opcional, mas profissional)

Depois de dar push na tag, vá em:
`https://github.com/Kekeu-u/claude-code-presets-switcher/releases/new`

1. Selecione a tag (ex: `v1.1.0`)
2. Título: `v1.1.0 — Add DeepSeek preset`
3. Escreva o changelog
4. Publique

---

## 🔒 Regras de Segurança

1. **NUNCA** commitar API keys reais
   - Os JSONs em `presets/` usam `YOUR_API_KEY_HERE`
   - Suas keys ficam só em `~\.claude\presets\` (fora do Git)
2. **SEMPRE** verificar antes do push:
   ```powershell
   git diff --staged | Select-String "sk-|eyJ|api.key"
   ```
3. `.gitignore` protege: `oauth-backup.json`, `.active-preset`

---

## 📝 Adicionando um Novo Preset

### 1. Criar o JSON de exemplo (sem key)

```powershell
# Em c:\Apps\claude-presets\presets\
```

```json
{
    "_preset": {
        "name": "Nome do Provider",
        "description": "Descrição curta para o menu",
        "created": "2026-MM-DD"
    },
    "env": {
        "API_TIMEOUT_MS": "3000000",
        "ANTHROPIC_BASE_URL": "https://api.provider.com/anthropic",
        "ANTHROPIC_AUTH_TOKEN": "YOUR_API_KEY_HERE",
        "ANTHROPIC_MODEL": "model-name",
        "ANTHROPIC_DEFAULT_SONNET_MODEL": "model-name",
        "ANTHROPIC_DEFAULT_OPUS_MODEL": "model-name",
        "ANTHROPIC_DEFAULT_HAIKU_MODEL": "model-fast",
        "ANTHROPIC_SMALL_FAST_MODEL": "model-fast",
        "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": "1"
    }
}
```

### 2. Commitar e versionar

```powershell
git add presets/novo-provider.json
git commit -m "feat: add novo-provider preset"
git tag -a v1.2.0 -m "v1.2.0 - Add novo-provider"
git push && git push origin v1.2.0
```

### 3. Instalar localmente (com sua key)

```powershell
Copy-Item .\presets\novo-provider.json "$env:USERPROFILE\.claude\presets\"
# Edite e coloque sua key real:
notepad "$env:USERPROFILE\.claude\presets\novo-provider.json"
```

---

## 🚀 Deploy (atualizar instalação local)

Após qualquer mudança no `switch-preset.ps1`:

```powershell
# Copiar script atualizado
Copy-Item .\switch-preset.ps1 "$env:USERPROFILE\.claude\presets\" -Force

# Recarregar no terminal
. $PROFILE

# Testar
cmodel -Status
```

---

## 📋 Checklist Pré-Push

- [ ] Testou localmente com `cmodel -List` e `cmodel <preset>`?
- [ ] Nenhuma API key real nos arquivos?
- [ ] Mensagem de commit segue Conventional Commits?
- [ ] Se é feature nova, criou tag com versão?
