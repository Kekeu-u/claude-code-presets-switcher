# 📚 Providers — Base de Conhecimento

> Tudo que sabemos sobre cada provedor compatível com Claude Code CLI.
> Atualizado: 2026-02-21

---

## 🔑 Como funciona a compatibilidade

Claude Code CLI se comunica via **Anthropic Messages API** (`/v1/messages`).
Provedores que oferecem um endpoint compatível com esse formato podem ser usados como drop-in replacement.

**Variáveis-chave:**
- `ANTHROPIC_BASE_URL` → endpoint do provedor
- `ANTHROPIC_AUTH_TOKEN` → API key do provedor
- `ANTHROPIC_MODEL` → nome do modelo no provedor
- `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC` → **obrigatório `"1"`** para APIs alternativas (desativa telemetria Anthropic)

---

## 🌙 Kimi (Moonshot AI)

| Info | Valor |
|------|-------|
| **Empresa** | Moonshot AI (China/Global) |
| **Site** | [kimi.ai](https://kimi.ai) |
| **Docs** | [platform.moonshot.cn/docs](https://platform.moonshot.cn/docs) |
| **Console** | [platform.moonshot.cn](https://platform.moonshot.cn) |
| **Base URL** | `https://api.kimi.com/coding/` |
| **Key format** | `sk-kimi-...` |
| **Protocolo** | Anthropic-compatible nativo |

### Modelos disponíveis

| Modelo | Uso recomendado | Observações |
|--------|----------------|-------------|
| `kimi-k2.5` | Sonnet/Opus (principal) | Modelo flagship, bom para coding |
| `kimi-for-coding` | Haiku (background/fast) | Modelo leve otimizado para código |

### Mapeamento no preset

```
Sonnet → kimi-k2.5
Opus   → kimi-k2.5
Haiku  → kimi-for-coding
Fast   → kimi-for-coding
```

### Notas
- Endpoint estável e rápido
- Suporta contexto longo
- Free tier generoso para testes

---

## 🧪 GLM (Zhipu AI / Z.AI)

| Info | Valor |
|------|-------|
| **Empresa** | Zhipu AI (China) |
| **Site** | [z.ai](https://z.ai) |
| **Docs Claude** | [docs.z.ai/devpack/tool/claude](https://docs.z.ai/devpack/tool/claude) |
| **Console** | [open.bigmodel.cn](https://open.bigmodel.cn) |
| **Base URL** | `https://api.z.ai/api/anthropic` |
| **Key format** | `xxxxxxxx.yyyyyyyy` (hash.hash) |
| **Protocolo** | Anthropic-compatible nativo |

### Modelos disponíveis

| Modelo | Uso recomendado | Observações |
|--------|----------------|-------------|
| `glm-4.7` | Todos os slots | Modelo único para tudo |

### Mapeamento no preset

```
Sonnet → glm-4.7
Opus   → glm-4.7
Haiku  → glm-4.7
Fast   → glm-4.7
```

### Notas
- Usa um único modelo para todos os slots
- Doc oficial tem guia específico para Claude Code
- API key no formato diferente (sem prefixo `sk-`)

---

## ⚡ MiniMax

| Info | Valor |
|------|-------|
| **Empresa** | MiniMax (China/Global) |
| **Site** | [minimax.io](https://minimax.io) |
| **Console** | [platform.minimax.io](https://platform.minimax.io) |
| **Base URL (Anthropic)** | `https://api.minimaxi.com/anthropic` |
| **Base URL (Chat v2)** | `https://api.minimax.chat/v1/text/chatcompletion_v2` |
| **Key format (Coding Plan)** | `sk-cp-...` |
| **Key format (Pay-as-you-go)** | `sk-api-...` |
| **Protocolo** | Anthropic-compatible nativo |

### Modelos disponíveis

| Modelo | Uso recomendado | Observações |
|--------|----------------|-------------|
| `minimax-m2.5` | Sonnet/Opus (principal) | Modelo flagship |
| `minimax-m2.1` | Haiku (background/fast) | Modelo leve |

### Mapeamento no preset

```
Sonnet → minimax-m2.5
Opus   → minimax-m2.5
Haiku  → minimax-m2.1
Fast   → minimax-m2.1
```

### ⚠️ Atenção: Dois tipos de API key

| Tipo | Prefixo | Uso |
|------|---------|-----|
| **Coding Plan** | `sk-cp-...` | Apenas modelos de texto |
| **Pay-as-you-go** | `sk-api-...` | Todos os modelos (texto, vídeo, speech, image) |

### ⚠️ Atenção: Dois domínios

| Domínio | Público |
|---------|---------|
| `api.minimax.chat` | API legada / China |
| `api.minimaxi.com` | API global (recomendado) |
| `api.minimax.io` | Alternativo global |

### Troubleshooting

| Erro | Causa | Solução |
|------|-------|---------|
| `status_code: 2049` — invalid api key | Key incompatível com endpoint | Usar `api.minimaxi.com/anthropic` |
| 401 Unauthorized | Key expirada ou tipo errado | Gerar nova key no console |

---

## 🌐 Smart Router (Claude Code Router / CCR)

| Info | Valor |
|------|-------|
| **Projeto** | [musistudio/claude-code-router](https://github.com/musistudio/claude-code-router) |
| **Instalação** | `npm install -g @musistudio/claude-code-router` |
| **Config** | `~\.claude-code-router\config.json` |
| **Base URL** | `http://127.0.0.1:3000/v1/messages` |
| **Auth Token** | `sk-musi` (fixo, apenas local) |
| **Dashboard** | `ccr ui` → `http://localhost:3000` |

### Como funciona

O CCR roda um proxy local (porta 3000) que intercepta as requisições do Claude Code e roteia para diferentes provedores baseado no tipo de tarefa:

| Tipo de tarefa | Configuração | Descrição |
|----------------|-------------|-----------|
| `default` | `provider,model` | Requisições normais |
| `background` | `provider,model` | Tasks internas do Claude Code |
| `think` | `provider,model` | Tarefas de raciocínio |
| `longContext` | `provider,model` | Quando contexto > threshold |
| `webSearch` | `provider,model` | Buscas na web |

### Configuração de exemplo

```json
{
  "Providers": [
    {
      "name": "kimi",
      "api_base_url": "https://api.moonshot.ai/v1/chat/completions",
      "api_key": "SUA_KEY",
      "models": ["kimi-k2.5"],
      "transformer": { "use": ["openai"] }
    },
    {
      "name": "gemini",
      "api_base_url": "https://generativelanguage.googleapis.com/v1beta/models/",
      "api_key": "SUA_KEY",
      "models": ["gemini-3-flash-preview", "gemini-3.1-pro-preview"],
      "transformer": { "use": ["gemini"] }
    }
  ],
  "Router": {
    "default": "kimi,kimi-k2.5",
    "background": "gemini,gemini-3-flash-preview",
    "think": "kimi,kimi-k2.5",
    "longContext": "gemini,gemini-3.1-pro-preview",
    "longContextThreshold": 50000
  }
}
```

### Notas
- O `cmodel` inicia o router automaticamente se o preset aponta para `localhost:3000`
- O health check verifica se o router está respondendo antes de continuar
- Use `ccr ui` para monitorar qual modelo está sendo usado em tempo real

---

## 🔍 Outros provedores (não testados ainda)

Provedores que oferecem endpoints compatíveis com Anthropic Messages API e podem funcionar:

| Provedor | Endpoint | Status |
|----------|----------|--------|
| DeepSeek | `https://api.deepseek.com/anthropic` | ❓ Não testado |
| OpenRouter | `https://openrouter.ai/api/v1` | ❓ Não testado (usa OpenAI format) |
| Google Gemini (via CCR) | Via transformer `gemini` | ✅ Funciona via Router |

> **Contribua!** Se testou um provedor novo, crie um preset em `presets/` e abra um PR.

---

## 📖 Referências

- [Claude Code CLI Docs](https://docs.anthropic.com/en/docs/claude-code)
- [Claude Code Router (CCR)](https://github.com/musistudio/claude-code-router)
- [Anthropic Messages API](https://docs.anthropic.com/en/api/messages)
- [Kimi Platform Docs](https://platform.moonshot.cn/docs)
- [Z.AI Claude Integration](https://docs.z.ai/devpack/tool/claude)
- [MiniMax Platform](https://platform.minimax.io)
