# 🐉 cmodel — Claude Code Preset Switcher

> **Switch between AI providers in Claude Code CLI with a single command.**
> Use Kimi, GLM, MiniMax, Smart Router, or plain Anthropic — no config file editing needed.

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue?logo=powershell&logoColor=white)](https://github.com/PowerShell/PowerShell)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Claude Code](https://img.shields.io/badge/Claude_Code-Compatible-blueviolet?logo=anthropic&logoColor=white)](https://docs.anthropic.com/en/docs/claude-code)

---

## ✨ Features

- 🎮 **Interactive menu** with arrow keys navigation
- ⚡ **One-command switch** — `cmodel kimi`, `cmodel glm`, done
- 🔄 **Safe rollback** — `cmodel anthropic` restores OAuth instantly
- 🧩 **Extensible** — drop a `.json` in the folder, it auto-detects
- 🚀 **Auto-launch** — optionally starts Claude Code after switching
- 🌐 **Smart Router support** — use [Claude Code Router (CCR)](https://github.com/musistudio/claude-code-router) to route requests to the best model per task
- 📊 **CCR Dashboard** — real-time visual dashboard to manage your router
- 📥 **One-liner install** — bilingual installer (EN/PT-BR) with Desktop reference guide

---

## 📋 Requirements

- **Windows** + **PowerShell 5.1+** (Windows 10/11 default)
- **Claude Code CLI** installed and logged in at least once
- API key from your desired provider (Kimi, GLM, MiniMax, etc.)

---

## 🚀 Quick Start

Open **PowerShell** and run:

```powershell
irm https://raw.githubusercontent.com/Kekeu-u/claude-code-presets-switcher/main/i | iex
```

This will:

1. Clone the repo to `~/.claude/presets/`
2. Register `cmodel` and `ccr-dash` commands
3. Save a **quick reference guide** to your Desktop
4. Detect your language (English / Português) automatically

Restart your terminal and run `cmodel` — that's it! ✅

<details>
<summary>📖 Manual installation</summary>

```powershell
# 1. Clone
git clone https://github.com/Kekeu-u/claude-code-presets-switcher.git

# 2. Copy to Claude folder
New-Item -ItemType Directory -Path "$env:USERPROFILE\.claude\presets" -Force
Copy-Item .\claude-code-presets-switcher\* "$env:USERPROFILE\.claude\presets\" -Recurse

# 3. Add to PowerShell profile
Add-Content $PROFILE @'
function Switch-ClaudePreset { . "$env:USERPROFILE\.claude\presets\switch-preset.ps1" @args }
Set-Alias cmodel Switch-ClaudePreset
'@

# 4. Add your API keys
notepad "$env:USERPROFILE\.claude\presets\kimi.json"
```

</details>

---

## 🎮 Usage

```powershell
cmodel              # Interactive menu (↑↓ + Enter)
cmodel kimi          # Switch directly
cmodel glm           # Switch directly
cmodel minimax       # Switch directly
cmodel gemini        # Switch to Google AI Studio
cmodel anthropic     # Back to official Claude (OAuth)
cmodel router        # Use Smart Router (CCR)
cmodel -List         # List available presets
cmodel -Status       # Show active preset
```

After switching, the script asks: **🚀 Launch Claude Code now?**
- **Enter** = opens Claude
- **Q** = skip (run `claude` later)

---

## 📦 Included Presets

| Preset | Provider | Models | API Docs |
|--------|----------|--------|----------|
| `kimi` | [Moonshot AI](https://kimi.ai) | Kimi K2.5 (Sonnet/Opus) + Kimi for Coding (Haiku) | [docs](https://platform.moonshot.cn/docs) |
| `glm` | [Z.AI (Zhipu)](https://z.ai) | GLM-4.7 (all slots) | [docs](https://docs.z.ai/devpack/tool/claude) |
| `minimax` | [MiniMax](https://minimax.io) | M2.5 (Sonnet/Opus) + M2.1 (Haiku) | [docs](https://platform.minimax.io) |
| `gemini` | [Google AI Studio](https://aistudio.google.com) | Gemini 2.5 Pro + Flash | [docs](https://ai.google.dev/gemini-api/docs/openai) |
| `router` | [CCR](https://github.com/musistudio/claude-code-router) | Smart routing across providers | [docs](https://github.com/musistudio/claude-code-router) |

> **Add your own**: Just create a new `.json` following the same format. `cmodel` auto-detects it.

---

## 🧩 Preset Format

Every preset is a simple JSON with metadata + environment variables:

```json
{
    "_preset": {
        "name": "My Provider",
        "description": "Short description shown in the menu",
        "created": "2026-02-15"
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

---

## 🌟 Smart Router + Dashboard

For automatic model routing (e.g., Kimi for coding, Gemini for background tasks), install [Claude Code Router](https://github.com/musistudio/claude-code-router):

```powershell
npm install -g @musistudio/claude-code-router
```

Then use the `router` preset:

```powershell
cmodel router   # Auto-starts CCR + opens dashboard
ccr-dash        # Open dashboard manually
```

When you select a CCR preset, `cmodel` will:

1. **Auto-start the router** on port 3000
2. **Launch the CCR Dashboard** on [localhost:3456](http://localhost:3456)
3. **Open your browser** automatically

The dashboard lets you manage providers, configure routing, view logs, and install presets — all from a sleek dark UI.

---

## 📖 Environment Variables

| Variable | Purpose |
|----------|---------|
| `ANTHROPIC_BASE_URL` | Provider API endpoint |
| `ANTHROPIC_AUTH_TOKEN` | Your API key |
| `ANTHROPIC_MODEL` | Default model |
| `ANTHROPIC_DEFAULT_SONNET_MODEL` | Model for "Sonnet" selection |
| `ANTHROPIC_DEFAULT_OPUS_MODEL` | Model for "Opus" selection |
| `ANTHROPIC_DEFAULT_HAIKU_MODEL` | Model for background tasks |
| `ANTHROPIC_SMALL_FAST_MODEL` | Model for quick internal ops |
| `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC` | Disables telemetry (required for alt APIs) |

---

## ⚙️ How It Works

Claude Code reads environment variables **before** the settings file. This script:

1. Sets real env vars (`$env:ANTHROPIC_BASE_URL`, etc.) in the PowerShell session
2. Persists them as User-level env vars for new terminals
3. Keeps the original `settings` file intact (OAuth, permissions, etc.)
4. Tracks the active preset in `.active-preset`
5. To switch back: clears env vars → OAuth from settings kicks in again

---

## ❓ Troubleshooting

| Problem | Solution |
|---------|----------|
| Claude asks for login | Run `cmodel <preset>` and `claude` in the **same PowerShell 7 terminal** |
| `cmodel` not recognized | Run `. $PROFILE` or open a new terminal |
| Model doesn't change | Exit Claude (`/exit`) and reopen after `cmodel` |
| Script error | Confirm PowerShell **7+**: `$PSVersionTable.PSVersion` |
| Router won't start | Install Node.js + `npm i -g @musistudio/claude-code-router` |

---

## 🛡️ Best Practices & Safety

To avoid API bans or unexpected costs, follow these guidelines:

### 1. API Keys are Sensitive
- **NEVER** commit your `.json` presets to public repositories.
- The `.gitignore` in this repo already excludes `*.json` in the presets folder, but double-check before pushing.
- If you suspect a key leak, revoke it immediately in your provider's dashboard.

### 2. Respect Rate Limits
- Claude Code can make **many requests very quickly**, especially with "Smart Router".
- **Monitor your usage** in the provider's dashboard (OpenRouter, DeepSeek, etc.).
- Set **Hard Limits** ($) in your provider's billing settings to prevent runaway costs.

### 3. Loop Protection
- Claude Code is an agent; it can get stuck in loops (creating files, deleting them, repeating).
- **Control + C** is your friend. If it seems stuck, kill it.
- Use `verbose` mode (`claude --verbose`) if you suspect it's looping without output.

### 4. Terms of Service (ToS)
- You are subject to **both** Anthropic's ToS (for the client) and your Provider's ToS (for the API).
- Avoid generating prohibited content. Providers often have automated flags for NSFW/Illegal content.
- Repeated violations WILL get your API key banned.

---

## 🤝 Contributing

1. Fork this repo
2. Create your preset (e.g., `deepseek.json`)
3. Submit a PR with the preset template (no API keys!)

---

## 📄 License

MIT — use it, fork it, improve it. Just give credit. 🐉

---

**Made with ❤️ by [kekeu](https://github.com/Kekeu-u)**
