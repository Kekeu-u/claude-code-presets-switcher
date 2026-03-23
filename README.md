# cmodel

Switch Claude Code between providers with one command.

`cmodel` supports two modes:

- **Isolated** (default) — preset applies only to the current terminal session, no file written.
- **Persisted** (`-SetDefault`) — writes to `~/.claude/settings.local.json` for VS Code Claude extension.

## Quick Start

```powershell
irm https://raw.githubusercontent.com/Kekeu-u/claude-code-presets-switcher/main/i | iex
```

Restart the terminal, then run `cmodel`.

## Usage

```powershell
cmodel                         # interactive menu — default is Isolated (Enter)
cmodel kimi                    # apply kimi isolated + open Claude in this terminal
cmodel kimi -ApplyOnly         # apply kimi isolated, do NOT open Claude
cmodel kimi -SetDefault        # apply + persist as VS Code Claude default
cmodel kimi -SetDefault -ApplyOnly
                               # persist default without opening Claude
cmodel router                  # apply router isolated + open Claude in this terminal
cmodel anthropic               # clear session, revert to OAuth default
cmodel anthropic -SetDefault   # clear persisted default provider
cmodel -List                   # list available presets
cmodel -Status                 # show active session + persisted default
```

## What It Does

- **Isolated by default** — env vars are set in the current process scope, never written to disk.
- **Warns on session conflict** — if a session is already active, shows a warning before switching.
- Dashboard launches are always isolated (`-ApplyOnly`).
- Persisted default via `~/.claude/settings.local.json` only when `-SetDefault` is explicit.
- Old local state files (`.active-preset`, etc.) are cleaned automatically.
- Missing model slots inherit `ANTHROPIC_MODEL` automatically.
- Optional local dashboard for CCR via `ccr-dash`.

## Presets

The repo ships safe examples in [`presets/examples/`](./presets/examples/).

| Preset | Path | Notes |
|--------|------|-------|
| `kimi` | `presets/examples/kimi.example.json` | Direct Anthropic-compatible endpoint |
| `glm` | `presets/examples/glm.example.json` | Direct Anthropic-compatible endpoint |
| `minimax` | `presets/examples/minimax.example.json` | Direct Anthropic-compatible endpoint |
| `gemini` | `presets/examples/gemini.example.json` | OpenAI-compatible endpoint |
| `antigravity` | `presets/examples/antigravity.example.json` | Local Antigravity Manager on `127.0.0.1:8045` |
| `router` | `presets/examples/router.example.json` | Local CCR on `127.0.0.1:3000` |
| `openai-oauth` | `presets/examples/openai.example.json` | OpenAI via CCR |

Copy an example, rename it to `.json`, and add your real key outside git.

```json
{
  "_preset": {
    "name": "My Provider",
    "description": "Short menu label"
  },
  "env": {
    "ANTHROPIC_BASE_URL": "https://api.provider.com/anthropic",
    "ANTHROPIC_AUTH_TOKEN": "YOUR_API_KEY",
    "ANTHROPIC_MODEL": "model-name",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "model-name",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "model-name",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "model-fast",
    "ANTHROPIC_SMALL_FAST_MODEL": "model-fast",
    "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": 1
  }
}
```

For Antigravity, use `ANTHROPIC_API_KEY` instead of `ANTHROPIC_AUTH_TOKEN` and keep it separate from CCR presets:

```json
{
  "_preset": {
    "name": "Antigravity"
  },
  "env": {
    "ANTHROPIC_BASE_URL": "http://127.0.0.1:8045",
    "ANTHROPIC_API_KEY": "YOUR_API_KEY",
    "API_TIMEOUT_MS": "300000"
  }
}
```

More preset notes live in [PROVIDERS.md](./PROVIDERS.md).

## Keep Claude Config Clean

Do not keep provider env such as `ANTHROPIC_BASE_URL`, `ANTHROPIC_API_KEY`, or `ANTHROPIC_AUTH_TOKEN` inside `~/.claude/settings.json`.

Do not keep a root `apiBaseUrl` there either. That value overrides provider endpoints globally and can silently force Claude back to a local proxy such as `http://127.0.0.1:8045`.

Those values are global and can leak across providers, which is exactly the kind of mixed session `cmodel` is trying to avoid.

If you want the VS Code extension to follow the selected provider, use `cmodel <name> -SetDefault`. That writes only the managed provider keys into `~/.claude/settings.local.json`, while preserving existing permissions and unrelated settings.

## CCR And Dashboard

`cmodel router` only points Claude to the local CCR endpoint. It does not auto-start anything.

`cmodel antigravity` is a separate local proxy preset and should not share router config with CCR.

```powershell
npm install -g @musistudio/claude-code-router
ccr start --no-claude
ccr-dash
```

The dashboard is a small local UI in [`dashboard/`](./dashboard/).

## Manual Install

```powershell
git clone https://github.com/Kekeu-u/claude-code-presets-switcher.git
New-Item -ItemType Directory -Path "$env:USERPROFILE\.claude\presets" -Force | Out-Null
Copy-Item .\claude-code-presets-switcher\switch-preset.ps1 "$env:USERPROFILE\.claude\presets\" -Force
Copy-Item .\claude-code-presets-switcher\dashboard "$env:USERPROFILE\.claude\presets\" -Recurse -Force
Copy-Item .\claude-code-presets-switcher\presets "$env:USERPROFILE\.claude\presets\" -Recurse -Force

Add-Content $PROFILE @'
function Switch-ClaudePreset { . "$env:USERPROFILE\.claude\presets\switch-preset.ps1" @args }
Set-Alias cmodel Switch-ClaudePreset
'@
```

## Safety

- Never commit preset JSON files with real keys.
- If you want the old manual flow, use `cmodel <name> -ApplyOnly`.
- If the VS Code extension feels wrong, run `cmodel anthropic -SetDefault` to clear the persisted provider override.
- If a session feels wrong, remove global `ANTHROPIC_*` entries from `~/.claude/settings.json` and run `cmodel anthropic -ApplyOnly`.

## License

MIT
