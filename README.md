# 🐉 cmodel — Claude Code Preset Switcher

> **Switch Claude Code CLI between AI providers with one command. Session-only — nothing persists.**

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue?logo=powershell&logoColor=white)](https://github.com/PowerShell/PowerShell)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Claude Code](https://img.shields.io/badge/Claude_Code-Compatible-blueviolet?logo=anthropic&logoColor=white)](https://docs.anthropic.com/en/docs/claude-code)

## The Problem

Claude Code uses Anthropic's API by default. To use other providers (Kimi, OpenAI, Gemini, etc.), you need to set 7+ environment variables manually — and remember to clean them up when switching back.

## The Solution

**`cmodel`** sets env vars in **Process scope only** (current terminal session). Close the terminal → everything reverts to Anthropic OAuth. No config files modified. No permanent state.

```
cmodel kimi       →  Kimi K2.5 active (this terminal only)
cmodel anthropic  →  Back to Claude (OAuth restored)
close terminal    →  Everything clean, as if nothing happened
```

---

## Quick Start

```powershell
irm https://raw.githubusercontent.com/Kekeu-u/claude-code-presets-switcher/main/i | iex
```

This clones the repo, registers `cmodel`, and saves a quick reference to your Desktop. Restart your terminal and run `cmodel`.

<details>
<summary>Manual installation</summary>

```powershell
git clone https://github.com/Kekeu-u/claude-code-presets-switcher.git
New-Item -ItemType Directory -Path "$env:USERPROFILE\.claude\presets" -Force
Copy-Item .\claude-code-presets-switcher\* "$env:USERPROFILE\.claude\presets\" -Recurse

Add-Content $PROFILE @'
function Switch-ClaudePreset { . "$env:USERPROFILE\.claude\presets\switch-preset.ps1" @args }
Set-Alias cmodel Switch-ClaudePreset
'@
```

</details>

---

## Usage

```powershell
cmodel                    # Interactive menu (↑↓ + Enter)
cmodel kimi               # Switch directly
cmodel openai-oauth       # OpenAI Codex via CCR
cmodel anthropic          # Back to official Claude (OAuth)
cmodel anthropic work     # Switch to saved OAuth account "work"
cmodel router             # Smart Router (multi-provider)
cmodel clean              # Clear session, restore OAuth
cmodel -List              # List available presets
cmodel -Status            # Show active preset
```

### OAuth Account Manager

Save your Anthropic logins once, switch instantly:

```powershell
claude login                        # Login normally
cmodel account save work            # Save as "work"
cmodel account use personal         # Switch to "personal"
cmodel account list                 # List saved accounts
```

---

## Providers

| Preset | Provider | Models | Docs |
|--------|----------|--------|------|
| `kimi` | [Moonshot AI](https://kimi.ai) | K2.5 + Kimi for Coding | [docs](https://platform.moonshot.cn/docs) |
| `glm` | [Z.AI (Zhipu)](https://z.ai) | GLM-4.7 | [docs](https://docs.z.ai/devpack/tool/claude) |
| `minimax` | [MiniMax](https://minimax.io) | M2.5 + M2.1 | [docs](https://platform.minimax.io) |
| `openai-oauth` | [OpenAI](https://openai.com) | GPT-5.3 Codex + Spark | [docs](https://platform.openai.com/docs) |
| `gemini` | [Google AI](https://ai.google.dev) | Gemini 3.1 Pro + Flash | [docs](https://ai.google.dev/gemini-api/docs) |
| `router` | [CCR](https://github.com/musistudio/claude-code-router) | Multi-provider smart routing | [docs](https://github.com/musistudio/claude-code-router) |

> **Add your own**: Copy any `.example.json` from `presets/examples/`, rename to `.json`, add your API key.

See [PROVIDERS.md](PROVIDERS.md) for detailed provider docs, endpoints, and troubleshooting.

---

## Preset Format

```json
{
    "_preset": {
        "name": "My Provider",
        "description": "Short description for the menu"
    },
    "env": {
        "ANTHROPIC_BASE_URL": "https://api.provider.com/anthropic",
        "ANTHROPIC_AUTH_TOKEN": "YOUR_API_KEY",
        "ANTHROPIC_MODEL": "model-name",
        "ANTHROPIC_DEFAULT_SONNET_MODEL": "model-main",
        "ANTHROPIC_DEFAULT_OPUS_MODEL": "model-main",
        "ANTHROPIC_DEFAULT_HAIKU_MODEL": "model-fast",
        "ANTHROPIC_SMALL_FAST_MODEL": "model-fast",
        "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": "1"
    }
}
```

---

## Smart Router (CCR)

For automatic model routing per task type, install [Claude Code Router](https://github.com/musistudio/claude-code-router):

```powershell
npm install -g @musistudio/claude-code-router
cmodel router     # Auto-starts CCR + launches dashboard
ccr-dash          # Open dashboard manually
```

`cmodel` auto-starts the router when the preset targets `localhost:3000`. The dashboard shows which model handles each request in real-time.

---

## How It Works

```
┌─────────────────────────────────────────────────┐
│  Terminal Session                                │
│                                                  │
│  cmodel kimi                                     │
│    ↓ Sets Process-scope env vars                 │
│    ↓ ANTHROPIC_BASE_URL = kimi endpoint          │
│    ↓ ANTHROPIC_AUTH_TOKEN = your key              │
│                                                  │
│  claude                                          │
│    ↓ Reads env vars → uses Kimi instead          │
│                                                  │
│  Close terminal → env vars gone → OAuth returns  │
└─────────────────────────────────────────────────┘
```

**Key design decisions:**
- **Process scope only** — env vars live in the current terminal, never written to User/System registry
- **Settings file untouched** — MCPs, plugins, permissions stay intact
- **Session cleanup** — when Claude exits via `cmodel`, env vars are auto-cleared
- **No cross-terminal leakage** — each terminal is independent

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Claude asks for login | Run `cmodel` and `claude` in the **same terminal** |
| `cmodel` not recognized | Run `. $PROFILE` or open new terminal |
| Model doesn't change | Exit Claude (`/exit`) and reopen after `cmodel` |
| Router won't start | Install Node.js + `npm i -g @musistudio/claude-code-router` |

---

## Safety

- **Never commit** preset JSONs with real API keys (`.gitignore` covers `presets/*.json`)
- **Monitor usage** in your provider's dashboard — set billing limits
- **Ctrl+C** if Claude gets stuck in a loop
- You're subject to both Anthropic's and your provider's ToS

---

## License

MIT — use it, fork it, improve it. 🐉

**Made by [kekeu](https://github.com/Kekeu-u)**
