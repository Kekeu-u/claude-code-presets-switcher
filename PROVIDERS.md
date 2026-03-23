# Providers

Reference for the preset examples shipped in this repo.

This file is intentionally narrow: it documents the example presets and the environment variables they set. It is not meant to be a full market survey of provider features.

## Required Env Vars

| Variable | Purpose |
|----------|---------|
| `ANTHROPIC_BASE_URL` | Endpoint Claude Code will call |
| `ANTHROPIC_AUTH_TOKEN` | Provider key for providers that expect Anthropic auth tokens |
| `ANTHROPIC_API_KEY` | Provider key for providers that expect API keys such as Antigravity |
| `ANTHROPIC_MODEL` | Main model |
| `ANTHROPIC_DEFAULT_SONNET_MODEL` | Main interactive slot |
| `ANTHROPIC_DEFAULT_OPUS_MODEL` | Main heavy slot |
| `ANTHROPIC_DEFAULT_HAIKU_MODEL` | Fast slot |
| `ANTHROPIC_SMALL_FAST_MODEL` | Small internal slot |
| `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC` | Set to `1` outside Anthropic |

## Example Presets

| Preset | Base URL | Main Model | Fast Model | Path |
|--------|----------|------------|------------|------|
| `kimi` | `https://api.kimi.com/coding/` | `kimi-k2.5` | `kimi-for-coding` | `presets/examples/kimi.example.json` |
| `glm` | `https://api.z.ai/api/anthropic` | `glm-4.7` | `glm-4.5` | `presets/examples/glm.example.json` |
| `minimax` | `https://api.minimax.io/anthropic` | `MiniMax-M2.7` | `MiniMax-M2.7` | `presets/examples/minimax.example.json` |
| `gemini` | `https://generativelanguage.googleapis.com/v1beta/openai` | `gemini-3.1-pro-preview` | `gemini-3-flash-preview` | `presets/examples/gemini.example.json` |
| `antigravity` | `http://127.0.0.1:8045` | `proxy-managed` | `proxy-managed` | `presets/examples/antigravity.example.json` |
| `router` | `http://127.0.0.1:3000/v1/messages` | `ccr-smart-router` | `ccr-smart-router` | `presets/examples/router.example.json` |
| `openai-oauth` | `http://127.0.0.1:3000/v1/messages` | `gpt-5.3-codex` | `gpt-5.3-codex-spark` | `presets/examples/openai.example.json` |

## Notes

### Direct Providers

`kimi`, `glm`, and `minimax` are configured as direct endpoints in the example presets.

MiniMax's current docs are split across two pages:

- `ANTHROPIC_BASE_URL=https://api.minimax.io/anthropic` for international users
- `ANTHROPIC_BASE_URL=https://api.minimaxi.com/anthropic` for users in China
- `ANTHROPIC_AUTH_TOKEN=<MINIMAX_API_KEY>` in the AI Coding Tools guide

This repo pins `MiniMax-M2.7` in every Claude Code slot for consistency. That is an implementation choice in this repo; the current MiniMax AI Coding Tools example page still shows `MiniMax-M2.5`.

### OpenAI And Router

`router` and `openai-oauth` both point to local CCR on port `3000`.

- `router` is a generic local routing preset.
- `openai-oauth` assumes CCR is already configured to route to OpenAI models.

### Antigravity

`antigravity` is separate from CCR and follows Antigravity Manager's Claude CLI flow: set `ANTHROPIC_BASE_URL` plus `ANTHROPIC_API_KEY`, and let the proxy manage model mapping.

### Gemini

The Gemini example uses Google's OpenAI-compatible endpoint. If your local CCR setup works better for Gemini in your environment, keep that mapping in CCR instead of using the direct preset.

## Adding A New Preset

1. Copy an example file from `presets/examples/`.
2. Rename it to `.json`.
3. Replace placeholder keys and models.
4. Test with `cmodel <name>` in the same terminal where Claude will run.
5. If you want the VS Code extension to use that provider too, run `cmodel <name> -SetDefault`.

## Related Files

- [README.md](./README.md)
- [switch-preset.ps1](./switch-preset.ps1)
- [dashboard/index.html](./dashboard/index.html)
