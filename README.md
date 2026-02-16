# 🐉 cmodel — Claude Code Preset Switcher

> **Switch between AI providers in Claude Code CLI with a single command.**
> Use Kimi, GLM, MiniMax, Smart Router, or plain Anthropic — no config file editing needed.

[![PowerShell](https://img.shields.io/badge/PowerShell-7%2B-blue?logo=powershell&logoColor=white)](https://github.com/PowerShell/PowerShell)
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

---

## 📋 Requirements

- **Windows** + **PowerShell 7+** → `winget install Microsoft.PowerShell`
- **Claude Code CLI** installed and logged in at least once
- API key from your desired provider (Kimi, GLM, MiniMax, etc.)

---

## 🚀 Quick Start

### 1. Clone this repo

```powershell
git clone https://github.com/Kekeu-u/claude-code-presets-switcher.git
```

### 2. Copy presets to your Claude folder

```powershell
# Create the presets directory
New-Item -ItemType Directory -Path "$env:USERPROFILE\.claude\presets" -Force

# Copy script + example presets
Copy-Item .\claude-code-presets-switcher\switch-preset.ps1 "$env:USERPROFILE\.claude\presets\"
Copy-Item .\claude-code-presets-switcher\presets\*.json "$env:USERPROFILE\.claude\presets\"
```

### 3. Add your API keys

Edit each `.json` in `~\.claude\presets\` and replace `YOUR_API_KEY_HERE` with your actual key:

```powershell
notepad "$env:USERPROFILE\.claude\presets\kimi.json"
```

### 4. Set up the alias

```powershell
# Open your PowerShell profile
notepad $PROFILE
```

Add this at the end and save:

```powershell
# 🐉 Claude Code Preset Switcher
function Switch-ClaudePreset { . "$env:USERPROFILE\.claude\presets\switch-preset.ps1" @args }
Set-Alias cmodel Switch-ClaudePreset
```

Reload:

```powershell
. $PROFILE
```

**Done!** ✅

---

## 🎮 Usage

```powershell
cmodel              # Interactive menu (↑↓ + Enter)
cmodel kimi          # Switch directly
cmodel glm           # Switch directly
cmodel minimax       # Switch directly
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

## 🌟 Smart Router (Advanced)

For automatic model routing (e.g., Kimi for coding, Gemini for background tasks), install [Claude Code Router](https://github.com/musistudio/claude-code-router):

```powershell
npm install -g @musistudio/claude-code-router
```

Then use the `router` preset:

```powershell
cmodel router   # Auto-starts CCR if needed
ccr ui          # Open dashboard to see live routing
```

The script **auto-starts CCR** when it detects a preset pointing to `localhost:3000`.

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

## 🤝 Contributing

1. Fork this repo
2. Create your preset (e.g., `deepseek.json`)
3. Submit a PR with the preset template (no API keys!)

---

## 📄 License

MIT — use it, fork it, improve it. Just give credit. 🐉

---

**Made with ❤️ by [kekeu](https://github.com/Kekeu-u)**
