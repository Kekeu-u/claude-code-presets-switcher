# cmodel

Switch Claude Code between providers with one command.

`cmodel` supports two modes:

- **Isolated** (default) - preset applies only to the current terminal session, no file written.
- **Persisted** (`-SetDefault`) - writes to `~/.claude/settings.local.json` for VS Code Claude.

## Quick Start

```powershell
irm https://raw.githubusercontent.com/Kekeu-u/claude-code-presets-switcher/main/i | iex
```

Restart the terminal, then run `cmodel`.

## Usage

```powershell
cmodel                         # interactive menu - choose preset and open isolated
cmodel litellm                 # apply LiteLLM isolated + open Claude
cmodel litellm -ApplyOnly      # apply LiteLLM only in this terminal
cmodel litellm -SetDefault     # persist LiteLLM for VS Code Claude
cmodel anthropic               # clear session, revert to OAuth default
cmodel anthropic -SetDefault   # clear persisted default provider
cmodel -List                   # list available presets
cmodel -Status                 # show active session + persisted default
```

## What It Does

- **Isolated by default** - env vars are set in the current process scope, never written to disk.
- **Warns on session conflict** - if a session is already active, shows a warning before switching.
- **Windows interactive launch** - opens Claude in a dedicated PowerShell window when needed to preserve TTY.
- **Persisted default** - writes only managed provider keys into `~/.claude/settings.local.json` when `-SetDefault` is explicit.
- **Safe cleanup** - old local state files (`.active-preset`, etc.) are cleaned automatically.
- **Model fallback fill** - missing slot env vars inherit `ANTHROPIC_MODEL` automatically.

## Presets

The repo ships safe examples in [`presets/examples/`](./presets/examples/).

| Preset | Path | Notes |
|--------|------|-------|
| `kimi` | `presets/examples/kimi.example.json` | Direct Anthropic-compatible endpoint |
| `glm` | `presets/examples/glm.example.json` | Direct Anthropic-compatible endpoint |
| `minimax` | `presets/examples/minimax.example.json` | Direct Anthropic-compatible endpoint |
| `gemini` | `presets/examples/gemini.example.json` | OpenAI-compatible endpoint |
| `antigravity` | `presets/examples/antigravity.example.json` | Local Antigravity Manager on `127.0.0.1:8045` |
| `litellm` | `presets/examples/litellm.example.json` | Local LiteLLM proxy on `127.0.0.1:4000` |

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

For Antigravity, use `ANTHROPIC_API_KEY` instead of `ANTHROPIC_AUTH_TOKEN`:

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

## LiteLLM

`cmodel litellm` only points Claude to your local LiteLLM proxy. It does not auto-start the service.

LiteLLM's docs show two valid Anthropic-style routes:

- `http://127.0.0.1:4000/v1/messages`
- `http://127.0.0.1:4000/anthropic/v1/messages`

This repo uses `/v1/messages` in the example preset. If your LiteLLM setup is using Anthropic passthrough under `/anthropic`, adjust the preset accordingly.

Minimal local flow:

```bash
litellm --config config.yaml
```

Minimal `config.yaml` example:

```yaml
model_list:
  - model_name: claude-code
    litellm_params:
      model: anthropic/<your-model-name>
      api_key: os.environ/ANTHROPIC_API_KEY

general_settings:
  master_key: sk-litellm-local
```

Matching preset:

```json
{
  "_preset": {
    "name": "LiteLLM Local",
    "description": "Local LiteLLM proxy"
  },
  "env": {
    "ANTHROPIC_BASE_URL": "http://127.0.0.1:4000/v1/messages",
    "ANTHROPIC_AUTH_TOKEN": "sk-litellm-local",
    "ANTHROPIC_MODEL": "claude-code",
    "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": 1
  }
}
```

## Keep Claude Config Clean

Do not keep provider env such as `ANTHROPIC_BASE_URL`, `ANTHROPIC_API_KEY`, or `ANTHROPIC_AUTH_TOKEN` inside `~/.claude/settings.json`.

Do not keep a root `apiBaseUrl` there either. That value overrides provider endpoints globally and can silently force Claude back to the wrong proxy.

If you want the VS Code extension to follow the selected provider, use `cmodel <name> -SetDefault`. That writes only the managed provider keys into `~/.claude/settings.local.json`, while preserving existing permissions and unrelated settings.

## Manual Install

```powershell
git clone https://github.com/Kekeu-u/claude-code-presets-switcher.git
New-Item -ItemType Directory -Path "$env:USERPROFILE\.claude\presets" -Force | Out-Null
Copy-Item .\claude-code-presets-switcher\switch-preset.ps1 "$env:USERPROFILE\.claude\presets\" -Force
Copy-Item .\claude-code-presets-switcher\presets "$env:USERPROFILE\.claude\presets\" -Recurse -Force

Add-Content $PROFILE @'
function Switch-ClaudePreset { . "$env:USERPROFILE\.claude\presets\switch-preset.ps1" @args }
Set-Alias cmodel Switch-ClaudePreset
'@
```

## Safety

- Never commit preset JSON files with real keys.
- If you want to only prime the current terminal without opening Claude, use `cmodel <name> -ApplyOnly`.
- If the VS Code extension feels wrong, run `cmodel anthropic -SetDefault` to clear the persisted provider override.
- If a session feels wrong, remove global `ANTHROPIC_*` entries from `~/.claude/settings.json` and run `cmodel anthropic -ApplyOnly`.

## License

MIT
