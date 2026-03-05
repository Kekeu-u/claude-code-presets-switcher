# 📚 Providers

> All providers compatible with Claude Code CLI via `cmodel`.
> Updated: 2026-03-05

---

## How It Works

Claude Code CLI communicates via the **Anthropic Messages API** (`/v1/messages`). Any provider exposing a compatible endpoint can be used as a drop-in replacement.

**Required env vars:**
| Variable | Purpose |
|----------|---------|
| `ANTHROPIC_BASE_URL` | Provider API endpoint |
| `ANTHROPIC_AUTH_TOKEN` | Your API key |
| `ANTHROPIC_MODEL` | Default model |
| `ANTHROPIC_DEFAULT_SONNET_MODEL` | Model for "Sonnet" selection |
| `ANTHROPIC_DEFAULT_OPUS_MODEL` | Model for "Opus" selection |
| `ANTHROPIC_DEFAULT_HAIKU_MODEL` | Model for background tasks |
| `ANTHROPIC_SMALL_FAST_MODEL` | Model for quick internal ops |
| `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC` | **Must be `"1"`** for non-Anthropic APIs |

---

## 🤖 OpenAI Codex

| Field | Value |
|-------|-------|
| **Provider** | OpenAI |
| **Site** | [openai.com](https://openai.com) |
| **Docs** | [platform.openai.com/docs](https://platform.openai.com/docs) |
| **Base URL** | `https://api.openai.com/v1/chat/completions` |
| **Key format** | `sk-...` |
| **Protocol** | OpenAI Chat Completions (requires `openai` transformer in CCR) |

### Models

| Model | Use | Notes |
|-------|-----|-------|
| `gpt-5.3-codex` | Sonnet/Opus (main) | Flagship coding model, xhigh/high effort |
| `gpt-5.3-codex-spark` | Haiku/Fast | Lightweight, low effort |

### Mapping

```
Sonnet → gpt-5.3-codex
Opus   → gpt-5.3-codex
Haiku  → gpt-5.3-codex-spark
Fast   → gpt-5.3-codex-spark
```

### Notes
- Available via API since Feb 2026
- Also available via ChatGPT OAuth (requires CLIProxyAPI or similar proxy for token management)
- Best used through CCR with the `openai` transformer
- Supports extended context for code generation

---

## 🌙 Kimi (Moonshot AI)

| Field | Value |
|-------|-------|
| **Provider** | Moonshot AI (China/Global) |
| **Site** | [kimi.ai](https://kimi.ai) |
| **Docs** | [platform.moonshot.cn/docs](https://platform.moonshot.cn/docs) |
| **Base URL** | `https://api.kimi.com/coding/` |
| **Key format** | `sk-kimi-...` |
| **Protocol** | Anthropic-compatible native |

### Models

| Model | Use | Notes |
|-------|-----|-------|
| `kimi-k2.5` | Sonnet/Opus (main) | Flagship, good for coding |
| `kimi-for-coding` | Haiku/Fast | Lightweight, optimized for code |

### Notes
- Stable, fast endpoint
- Long context support
- Generous free tier for testing

---

## 🧪 GLM (Z.AI / Zhipu AI)

| Field | Value |
|-------|-------|
| **Provider** | Zhipu AI (China) |
| **Site** | [z.ai](https://z.ai) |
| **Docs** | [docs.z.ai/devpack/tool/claude](https://docs.z.ai/devpack/tool/claude) |
| **Base URL** | `https://api.z.ai/api/anthropic` |
| **Key format** | `xxxxxxxx.yyyyyyyy` (hash.hash) |
| **Protocol** | Anthropic-compatible native |

### Models

| Model | Use | Notes |
|-------|-----|-------|
| `glm-4.7` | All slots | Single model for everything |

---

## ⚡ MiniMax

| Field | Value |
|-------|-------|
| **Provider** | MiniMax (China/Global) |
| **Site** | [minimax.io](https://minimax.io) |
| **Base URL** | `https://api.minimaxi.com/anthropic` |
| **Key format (Coding Plan)** | `sk-cp-...` |
| **Key format (Pay-as-you-go)** | `sk-api-...` |
| **Protocol** | Anthropic-compatible native |

### Models

| Model | Use | Notes |
|-------|-----|-------|
| `minimax-m2.5` | Sonnet/Opus (main) | Flagship |
| `minimax-m2.1` | Haiku/Fast | Lightweight |

### ⚠️ Two key types

| Type | Prefix | Scope |
|------|--------|-------|
| Coding Plan | `sk-cp-...` | Text models only |
| Pay-as-you-go | `sk-api-...` | All models |

### ⚠️ Two domains

| Domain | Use |
|--------|-----|
| `api.minimaxi.com` | Global (recommended) |
| `api.minimax.chat` | Legacy / China |

---

## 🌐 Gemini (Google AI Studio)

| Field | Value |
|-------|-------|
| **Provider** | Google |
| **Site** | [ai.google.dev](https://ai.google.dev) |
| **Docs** | [ai.google.dev/gemini-api/docs](https://ai.google.dev/gemini-api/docs) |
| **Base URL** | `https://generativelanguage.googleapis.com/v1beta/openai` |
| **Key format** | `AIza...` |
| **Protocol** | OpenAI-compatible (requires CCR with `gemini` transformer for best results) |

### Models

| Model | Use | Notes |
|-------|-----|-------|
| `gemini-3.1-pro-preview` | Sonnet/Opus (main) | Latest pro model |
| `gemini-3-flash-preview` | Haiku/Fast | Fast and cheap |

### Notes
- Works best via CCR with `gemini` transformer
- Can also be used directly with OpenAI-compatible base URL
- Generous free tier

---

## 🌐 Smart Router (CCR)

| Field | Value |
|-------|-------|
| **Project** | [musistudio/claude-code-router](https://github.com/musistudio/claude-code-router) |
| **Install** | `npm install -g @musistudio/claude-code-router` |
| **Config** | `~\.claude-code-router\config.json` |
| **Base URL** | `http://127.0.0.1:3000/v1/messages` |
| **Auth Token** | `sk-musi` (fixed, local only) |

### How it works

CCR runs a local proxy (port 3000) that intercepts Claude Code requests and routes them to different providers based on task type:

| Task Type | Description |
|-----------|-------------|
| `default` | Normal requests |
| `background` | Internal Claude Code tasks |
| `think` | Reasoning tasks |
| `longContext` | When context exceeds threshold |
| `webSearch` | Web searches |

### Config example

```json
{
  "Providers": [
    {
      "name": "openai",
      "api_base_url": "https://api.openai.com/v1/chat/completions",
      "api_key": "YOUR_KEY",
      "models": ["gpt-5.3-codex", "gpt-5.3-codex-spark"],
      "transformer": { "use": ["openai"] }
    },
    {
      "name": "kimi",
      "api_base_url": "https://api.moonshot.ai/v1/chat/completions",
      "api_key": "YOUR_KEY",
      "models": ["kimi-k2.5"],
      "transformer": { "use": ["openai"] }
    }
  ],
  "Router": {
    "default": "openai,gpt-5.3-codex",
    "background": "openai,gpt-5.3-codex-spark",
    "think": "openai,gpt-5.3-codex",
    "longContext": "kimi,kimi-k2.5",
    "longContextThreshold": 256000
  }
}
```

---

## References

- [Claude Code CLI Docs](https://docs.anthropic.com/en/docs/claude-code)
- [Claude Code Router (CCR)](https://github.com/musistudio/claude-code-router)
- [Anthropic Messages API](https://docs.anthropic.com/en/api/messages)
