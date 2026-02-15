# 🐉 cmodel — Claude Code Preset Switcher · by kekeu

> Use **APIs alternativas** (Kimi, GLM, MiniMax, etc.) no Claude Code CLI com um comando só.
> Menu interativo com setas e auto-launch do Claude.

---

## 📋 Requisitos

- **Windows** com **PowerShell 7+** → `winget install Microsoft.PowerShell`
- **Claude Code CLI** instalado e logado pelo menos 1 vez (pra criar o arquivo `~\.claude\settings`)
- API key do provedor desejado

---

## 🚀 Setup Completo

### Passo 1 — Criar pasta

```powershell
New-Item -ItemType Directory -Path "$env:USERPROFILE\.claude\presets" -Force
```

### Passo 2 — Criar o script principal

Crie o arquivo `$env:USERPROFILE\.claude\presets\switch-preset.ps1` com **exatamente** este conteúdo:

```powershell
# ╔══════════════════════════════════════════╗
# ║  cmodel - Claude Code Preset Switcher    ║
# ║  by kekeu 🐉                             ║
# ╚══════════════════════════════════════════╝
#
# Uso: cmodel              (menu interativo)
#       cmodel kimi          (direto)
#       cmodel anthropic     (volta ao padrão OAuth)
#       cmodel -List         (lista presets)
#       cmodel -Status       (mostra preset ativo)
#       cmodel -Silent kimi  (troca sem banner, usado no auto-load)

param(
    [string]$PresetName,
    [switch]$List,
    [switch]$Status,
    [switch]$Silent
)

$presetsDir = "$env:USERPROFILE\.claude\presets"
$settingsPath = "$env:USERPROFILE\.claude\settings"
$oauthBackupPath = "$env:USERPROFILE\.claude\presets\oauth-backup.json"
$activePresetFile = "$env:USERPROFILE\.claude\presets\.active-preset"

# Env vars que controlam o Claude Code
$claudeEnvVars = @(
    "ANTHROPIC_BASE_URL",
    "ANTHROPIC_AUTH_TOKEN",
    "ANTHROPIC_MODEL",
    "ANTHROPIC_DEFAULT_SONNET_MODEL",
    "ANTHROPIC_DEFAULT_OPUS_MODEL",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL",
    "ANTHROPIC_SMALL_FAST_MODEL",
    "API_TIMEOUT_MS",
    "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC"
)

# ─── Banner ────────────────────────────────────────────────

function Show-Banner {
    Write-Host ""
    Write-Host "  ════════════════════════════════════════" -ForegroundColor DarkGreen
    Write-Host "   🐉  " -NoNewline
    Write-Host "cmodel" -ForegroundColor Green -NoNewline
    Write-Host "  ·  " -ForegroundColor DarkGreen -NoNewline
    Write-Host "by " -ForegroundColor DarkGray -NoNewline
    Write-Host "kekeu" -ForegroundColor Green
    Write-Host "       Claude Code Preset Switcher" -ForegroundColor DarkGray
    Write-Host "  ════════════════════════════════════════" -ForegroundColor DarkGreen
    Write-Host ""
}

function Show-Separator {
    Write-Host "  ═══════════════════════════════════════" -ForegroundColor DarkGreen
}

# ─── Helpers ───────────────────────────────────────────────

function Write-SettingsFile {
    param([PSCustomObject]$Settings, [string]$Path)
    $json = $Settings | ConvertTo-Json -Depth 10
    [System.IO.File]::WriteAllText($Path, $json, [System.Text.UTF8Encoding]::new($false))
}

function Get-ActivePreset {
    if (Test-Path $activePresetFile) {
        return (Get-Content $activePresetFile -Raw).Trim()
    }
    return "anthropic"
}

function Set-ActivePreset {
    param([string]$Name)
    $Name | Set-Content $activePresetFile -Encoding utf8NoBOM -NoNewline
}

function Restore-OAuthToSettings {
    if (-not (Test-Path $settingsPath)) { return }

    $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json

    if (-not $settings.PSObject.Properties['oauthAccount']) {
        if (Test-Path $oauthBackupPath) {
            $oauth = Get-Content $oauthBackupPath -Raw | ConvertFrom-Json
            $settings | Add-Member -NotePropertyName "oauthAccount" -NotePropertyValue $oauth -Force
        }
    }

    if ($settings.PSObject.Properties['env']) { $settings.PSObject.Properties.Remove('env') }
    if ($settings.PSObject.Properties['_comment']) { $settings.PSObject.Properties.Remove('_comment') }

    Write-SettingsFile -Settings $settings -Path $settingsPath
}

function Apply-Preset {
    param([string]$Name)

    if ($Name -eq "anthropic") {
        foreach ($varName in $claudeEnvVars) {
            [Environment]::SetEnvironmentVariable($varName, $null, "Process")
        }
        Restore-OAuthToSettings
        Set-ActivePreset "anthropic"
        return $null
    }

    $presetFile = Join-Path $presetsDir "$Name.json"
    if (-not (Test-Path $presetFile)) { return $false }

    $preset = Get-Content $presetFile -Raw | ConvertFrom-Json
    Restore-OAuthToSettings

    foreach ($prop in $preset.env.PSObject.Properties) {
        [Environment]::SetEnvironmentVariable($prop.Name, $prop.Value, "User")
        [Environment]::SetEnvironmentVariable($prop.Name, $prop.Value, "Process")
    }

    # Auto-start CCR se o preset usar localhost:3000
    if ($preset.env.ANTHROPIC_BASE_URL -match "127.0.0.1:3000|localhost:3000") {
        if (Test-Path "$env:USERPROFILE\.claude-code-router") {
            if (-not (Get-Job -Name "claude-router" -ErrorAction SilentlyContinue)) {
                Write-Host "  🔄 Iniciando Claude Code Router..." -ForegroundColor Cyan
                Start-Job -ScriptBlock { ccr start --no-claude } -Name "claude-router" | Out-Null
                Start-Sleep -Seconds 2 # Aguarda init
            }
        }
    }

    Set-ActivePreset $Name
    return $preset
}

function Prompt-LaunchClaude {
    Write-Host ""
    Write-Host "  🚀 Iniciar Claude Code agora? " -ForegroundColor Green -NoNewline
    Write-Host "[Enter = Sim / Q = Não]" -ForegroundColor DarkGray

    $key = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    if ($key.VirtualKeyCode -eq 13) {
        Write-Host ""
        Show-Separator
        Write-Host ""
        claude
    } else {
        Write-Host ""
        Write-Host "  💡 Rode " -ForegroundColor DarkGray -NoNewline
        Write-Host "claude" -ForegroundColor Green -NoNewline
        Write-Host " neste terminal quando quiser." -ForegroundColor DarkGray
        Write-Host ""
    }
}

# ─── Lista Presets ─────────────────────────────────────────

function Show-PresetList {
    $active = Get-ActivePreset

    Show-Banner
    Write-Host "  📦 Presets disponíveis:" -ForegroundColor Cyan
    Write-Host ""

    $marker = if ($active -eq "anthropic") { " ◀ ativo" } else { "" }
    Write-Host "    anthropic" -ForegroundColor Yellow -NoNewline
    Write-Host " - Claude oficial (OAuth)" -ForegroundColor Gray -NoNewline
    Write-Host $marker -ForegroundColor Green

    if (Test-Path $presetsDir) {
        Get-ChildItem $presetsDir -Filter "*.json" | Where-Object { $_.Name -ne "oauth-backup.json" } | ForEach-Object {
            $p = Get-Content $_.FullName -Raw | ConvertFrom-Json
            $name = $_.BaseName
            $desc = $p._preset.description
            $marker = if ($active -eq $name) { " ◀ ativo" } else { "" }
            Write-Host "    $name" -ForegroundColor Yellow -NoNewline
            Write-Host " - $desc" -ForegroundColor Gray -NoNewline
            Write-Host $marker -ForegroundColor Green
        }
    }

    Write-Host ""
    Write-Host "  💡 Uso: " -ForegroundColor DarkGray -NoNewline
    Write-Host "cmodel <nome>" -ForegroundColor Green
    Show-Separator
    Write-Host ""
}

# ─── Menu Interativo ───────────────────────────────────────

function Show-PresetMenu {
    $presets = @()
    $presets += [PSCustomObject]@{ Name = "anthropic"; Description = "Claude oficial (OAuth)" }

    if (Test-Path $presetsDir) {
        Get-ChildItem $presetsDir -Filter "*.json" | Where-Object { $_.Name -ne "oauth-backup.json" } | ForEach-Object {
            $p = Get-Content $_.FullName -Raw | ConvertFrom-Json
            $presets += [PSCustomObject]@{ Name = $_.BaseName; Description = $p._preset.description }
        }
    }

    $selectedIndex = 0
    $continue = $true

    while ($continue) {
        Clear-Host
        Show-Banner
        Write-Host "  Use ↑↓ para navegar, Enter para selecionar, Q para sair`n" -ForegroundColor DarkGray

        for ($i = 0; $i -lt $presets.Count; $i++) {
            $p = $presets[$i]
            if ($i -eq $selectedIndex) {
                Write-Host "  🐉 " -NoNewline
                Write-Host "$($p.Name)" -NoNewline -ForegroundColor Green
                Write-Host " - $($p.Description)" -ForegroundColor White
            }
            else {
                Write-Host "     $($p.Name)" -NoNewline -ForegroundColor Gray
                Write-Host " - $($p.Description)" -ForegroundColor DarkGray
            }
        }

        Write-Host ""
        Show-Separator

        $key = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        switch ($key.VirtualKeyCode) {
            38 { $selectedIndex = [Math]::Max(0, $selectedIndex - 1) }
            40 { $selectedIndex = [Math]::Min($presets.Count - 1, $selectedIndex + 1) }
            13 { $continue = $false; return $presets[$selectedIndex].Name }
            81 { Write-Host "`n  ❌ Cancelado`n" -ForegroundColor Red; return $null }
        }
    }
}

# ─── Main ──────────────────────────────────────────────────

# Status
if ($Status) {
    $active = Get-ActivePreset
    Show-Banner
    Write-Host "  🎯 Preset ativo: " -NoNewline -ForegroundColor Cyan
    Write-Host $active -ForegroundColor Green
    if ($active -ne "anthropic") {
        Write-Host "  📡 Base URL: $($env:ANTHROPIC_BASE_URL)" -ForegroundColor Gray
        Write-Host "  🤖 Model:   " -ForegroundColor Gray -NoNewline
        Write-Host $env:ANTHROPIC_MODEL -ForegroundColor Green
    }
    else {
        Write-Host "  📡 Usando Anthropic OAuth" -ForegroundColor Gray
    }
    Write-Host ""
    Show-Separator
    Write-Host ""
    return
}

# Listar
if ($List) { Show-PresetList; return }

# Menu interativo
if (-not $PresetName) {
    $PresetName = Show-PresetMenu
    if (-not $PresetName) { return }
}

# Validar settings
if (-not (Test-Path $settingsPath)) {
    Write-Host "`n  ❌ Arquivo settings não encontrado!`n" -ForegroundColor Red
    return
}

# ─── Aplicar Preset ───────────────────────────────────────

$result = Apply-Preset $PresetName

# ─── Output: Anthropic ────────────────────────────────────

if ($PresetName -eq "anthropic") {
    if (-not $Silent) {
        Show-Banner
        Write-Host "  ✅ Preset " -ForegroundColor Green -NoNewline
        Write-Host "Anthropic" -ForegroundColor White -NoNewline
        Write-Host " ativado!" -ForegroundColor Green
        Write-Host "  📡 Usando Claude oficial com OAuth" -ForegroundColor Gray
        Write-Host "  🧹 Env vars limpos da sessão" -ForegroundColor DarkGray
        Write-Host ""
        Show-Separator
        Prompt-LaunchClaude
    }
    return
}

# ─── Output: Preset Customizado ───────────────────────────

if ($result -eq $false) {
    Write-Host "`n  ❌ Preset '$PresetName' não encontrado!" -ForegroundColor Red
    Show-PresetList
    return
}

$preset = $result

if ($Silent) { return }

Show-Banner
Write-Host "  ✅ Preset " -ForegroundColor Green -NoNewline
Write-Host "$($preset._preset.name)" -ForegroundColor White -NoNewline
Write-Host " ativado!" -ForegroundColor Green
Write-Host "  📝 $($preset._preset.description)" -ForegroundColor Gray
Write-Host ""
Write-Host "  📡 Base URL:  " -ForegroundColor DarkGray -NoNewline
Write-Host $env:ANTHROPIC_BASE_URL -ForegroundColor Green
Write-Host "  🤖 Model:     " -ForegroundColor DarkGray -NoNewline
Write-Host $env:ANTHROPIC_MODEL -ForegroundColor Green
Write-Host ""

# Verificação rápida
$ok = $true
foreach ($varName in @("ANTHROPIC_BASE_URL", "ANTHROPIC_AUTH_TOKEN", "ANTHROPIC_MODEL")) {
    $val = [Environment]::GetEnvironmentVariable($varName, "Process")
    if (-not $val) { $ok = $false }
}

if ($ok) {
    Write-Host "  ✅ Todas as env vars configuradas" -ForegroundColor Green
} else {
    Write-Host "  ⚠️  Algumas env vars não foram definidas!" -ForegroundColor Red
}

Write-Host ""
Show-Separator
Prompt-LaunchClaude
```

### Passo 3 — Criar os presets (JSONs)

Crie um `.json` por provedor em `$env:USERPROFILE\.claude\presets\`. Troque `ANTHROPIC_AUTH_TOKEN` pela **sua key**.

**Exemplo — `kimi.json`:**

```json
{
    "_preset": {
        "name": "Kimi (Moonshot AI)",
        "description": "Kimi K2.5 (Sonnet/Opus) + Kimi for Coding (Haiku)",
        "created": "2026-02-14"
    },
    "env": {
        "API_TIMEOUT_MS": "3000000",
        "ANTHROPIC_BASE_URL": "https://api.moonshot.ai/anthropic",
        "ANTHROPIC_AUTH_TOKEN": "COLE_SUA_KEY_AQUI",
        "ANTHROPIC_MODEL": "kimi-k2.5",
        "ANTHROPIC_DEFAULT_SONNET_MODEL": "kimi-k2.5",
        "ANTHROPIC_DEFAULT_OPUS_MODEL": "kimi-k2.5",
        "ANTHROPIC_DEFAULT_HAIKU_MODEL": "kimi-for-coding",
        "ANTHROPIC_SMALL_FAST_MODEL": "kimi-for-coding",
        "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": "1"
    }
}
```

**Exemplo — `glm.json`:**

```json
{
    "_preset": {
        "name": "GLM (Z.AI)",
        "description": "GLM-4.7 (Sonnet/Opus/Haiku) via Z.AI",
        "created": "2026-02-14"
    },
    "env": {
        "API_TIMEOUT_MS": "3000000",
        "ANTHROPIC_BASE_URL": "https://api.z.ai/api/anthropic",
        "ANTHROPIC_AUTH_TOKEN": "COLE_SUA_KEY_AQUI",
        "ANTHROPIC_MODEL": "glm-4.7",
        "ANTHROPIC_DEFAULT_SONNET_MODEL": "glm-4.7",
        "ANTHROPIC_DEFAULT_OPUS_MODEL": "glm-4.7",
        "ANTHROPIC_DEFAULT_HAIKU_MODEL": "glm-4.7",
        "ANTHROPIC_SMALL_FAST_MODEL": "glm-4.7",
        "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": "1"
    }
}
```

**Exemplo — `minimax.json`:**

```json
{
    "_preset": {
        "name": "MiniMax",
        "description": "MiniMax M2.5 (Sonnet/Opus) + M2.1 (Haiku)",
        "created": "2026-02-14"
    },
    "env": {
        "API_TIMEOUT_MS": "3000000",
        "ANTHROPIC_BASE_URL": "https://api.minimax.chat/anthropic",
        "ANTHROPIC_AUTH_TOKEN": "COLE_SUA_KEY_AQUI",
        "ANTHROPIC_MODEL": "MiniMax-M2.5",
        "ANTHROPIC_DEFAULT_SONNET_MODEL": "MiniMax-M2.5",
        "ANTHROPIC_DEFAULT_OPUS_MODEL": "MiniMax-M2.5",
        "ANTHROPIC_DEFAULT_HAIKU_MODEL": "MiniMax-M2.1",
        "ANTHROPIC_SMALL_FAST_MODEL": "MiniMax-M2.1",
        "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": "1"
    }
}
```

> **Adicionar novos provedores**: basta criar outro `.json` seguindo o mesmo formato. O `cmodel` detecta automaticamente.

### Passo 4 — Configurar o alias no PowerShell

```powershell
# Abrir profile
notepad $PROFILE
```

Cole **tudo** abaixo no final do arquivo e salve:

```powershell
# Claude Code Preset Switcher - by kekeu 🐉
function Switch-ClaudePreset {
    . "$env:USERPROFILE\.claude\presets\switch-preset.ps1" @args
}
Set-Alias claude-preset Switch-ClaudePreset
Set-Alias cmodel Switch-ClaudePreset

# Auto-start Claude Code Router (se configured)
# REMOVIDO: O próprio cmodel agora inicia o router se o preset precisar (localhost)

```

Recarregue o profile:

```powershell
. $PROFILE
```

**Setup completo!** ✅

---

## 🎮 Como Usar

```powershell
cmodel              # Menu interativo (setas ↑↓ + Enter)
cmodel kimi          # Troca direto
cmodel glm           # Troca direto
cmodel minimax       # Troca direto
cmodel anthropic     # Volta pro Claude oficial (OAuth)
cmodel -List         # Lista presets
cmodel -Status       # Mostra qual está ativo
```

Após confirmar o modelo, o script pergunta: **🚀 Iniciar Claude Code agora?**
- **Enter** = abre o Claude
- **Q** = não abre (você roda `claude` depois)



---

## 🌟 Nível Avançado (Opcional): Smart Router

Se você quiser algo **muito mais poderoso** que escolhe automaticamente o melhor modelo pra cada tarefa (ex: Kimi pra codar, Gemini 3 Flash pra tasks rápidas, etc.), instale o **Claude Code Router (CCR)**.

### 1. Instalar dependências

```powershell
# Instalar Node.js (se não tiver)
winget install OpenJS.NodeJS
# Instalar CCR globalmente
npm install -g @musistudio/claude-code-router
```

### 2. Configurar o Router (`~\.claude-code-router\config.json`)

```json
{
  "HOST": "127.0.0.1",
  "PORT": 3000,
  "API_TIMEOUT_MS": 600000,
  "NON_INTERACTIVE_MODE": true,
  "LOG": true,
  "LOG_LEVEL": "info",
  "Providers": [
    {
      "name": "kimi",
      "api_base_url": "https://api.moonshot.ai/v1/chat/completions",
      "api_key": "SUA_KEY_KIMI",
      "models": ["kimi-k2.5"],
      "transformer": { "use": ["openai"] }
    },
    {
      "name": "gemini",
      "api_base_url": "https://generativelanguage.googleapis.com/v1beta/models/",
      "api_key": "SUA_KEY_GEMINI",
      "models": ["gemini-3.0-flash-preview", "gemini-3.0-pro-preview"],
      "transformer": { "use": ["gemini"] }
    }
  ],
  "Router": {
    "default": "kimi,kimi-k2.5",
    "background": "gemini,gemini-3.0-flash-preview",
    "think": "kimi,kimi-k2.5",
    "longContext": "gemini,gemini-3.0-pro-preview",
    "longContextThreshold": 50000,
    "webSearch": "gemini,gemini-3.0-flash-preview"
  }
}
```

### 3. Criar preset `router.json`

Em `~\.claude\presets\router.json`:

```json
{
    "_preset": {
        "name": "Smart Router",
        "description": "Kimi (Main) + Gemini 3.0 (Background/Context) + GLM/MiniMax (Bkp)",
        "created": "2026-02-15"
    },
    "env": {
        "ANTHROPIC_BASE_URL": "http://127.0.0.1:3000/v1/messages",
        "ANTHROPIC_AUTH_TOKEN": "sk-musi",
        "ANTHROPIC_MODEL": "ccr-smart-router",
        "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": "1"
    }
}
```

### 4. Usar

```powershell
cmodel router
```

O `Start-Job` agora é feito automaticamente pelo próprio `cmodel` se ele detectar que o preset usa `localhost:3000`. Não precisa mais de nada no profile.

#### 📊 Dashboard Visual

Para ver em tempo real qual modelo está sendo usado para cada requisição:

```powershell
ccr ui
```
Isso abrirá `http://localhost:3000` no seu navegador, mostrando o log ao vivo das requisições interceptadas.

> **💡 Dica Pro**: Se quiser testar o funcionamento de um modelo específico através do router (para ver se o failover funciona, por exemplo), crie um novo preset apontando para o router mas com um nome de modelo diferente na variável (que você terá que configurar no `config.json` do router se não usar os padrões). Mas o jeito mais fácil é **olhar o `ccr ui`** enquanto usa o `smart-router`.


---

## ✅ Como Saber Qual Modelo Está Rodando

Dentro do Claude Code, pergunte:

```
Qual é o seu nome e modelo real? Quem te criou?
```

| Resposta | Modelo ativo |
|---|---|
| "Kimi, criado pela **Moonshot AI**" | ✅ Kimi |
| "GLM, criado pela **Zhipu AI**" | ✅ GLM |
| "MiniMax, criado pela **MiniMax**" | ✅ MiniMax |
| "Claude, criado pela **Anthropic**" | ✅ Claude oficial |
| (Variável no terminal) | `ccr-smart-router` (veja `ccr ui` para detalhes) |

No terminal: `cmodel -Status` ou `$env:ANTHROPIC_MODEL`

---

## 📖 Variáveis Explicadas

| Variável | O que faz |
|---|---|
| `ANTHROPIC_BASE_URL` | URL da API do provedor |
| `ANTHROPIC_AUTH_TOKEN` | Sua API key |
| `ANTHROPIC_MODEL` | Modelo padrão |
| `ANTHROPIC_DEFAULT_SONNET_MODEL` | Modelo para seleção "Sonnet" |
| `ANTHROPIC_DEFAULT_OPUS_MODEL` | Modelo para seleção "Opus" |
| `ANTHROPIC_DEFAULT_HAIKU_MODEL` | Modelo para tarefas background |
| `ANTHROPIC_SMALL_FAST_MODEL` | Modelo para operações rápidas internas |
| `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC` | Desativa telemetria (necessário pra APIs alternativas) |

---

## ⚙️ Como Funciona (Técnico)

O Claude Code CLI lê variáveis de ambiente **antes** do arquivo `settings`. O script:

1. Seta env vars reais (`$env:ANTHROPIC_BASE_URL`, etc.) na sessão do PowerShell
2. Mantém o `settings` original intacto (com OAuth, permissões, etc.)
3. Salva qual preset está ativo em `.active-preset`

5. Para voltar pro Claude: limpa as env vars → OAuth do settings volta a funcionar
6. **Smart Router**: Usa um proxy local (CCR). O script liga o router automaticamente (`Start-Job`) se a URL do preset for local.

---

## ❓ Troubleshooting

| Problema | Solução |
|---|---|
| Claude pede login | Rode `cmodel <preset>` e `claude` no **mesmo terminal PowerShell 7** (`pwsh`) |
| `cmodel` não reconhecido | Rode `. $PROFILE` ou abra um terminal novo |
| Modelo não muda | Feche o Claude (`/exit`) e abra de novo após `cmodel` |
| Erro no script | Confirme PowerShell **7+** (`$PSVersionTable.PSVersion`) |
| **Router não inicia** | Confirme se instalou Node.js e rodou `npm install -g @musistudio/claude-code-router` |

---

## 📁 Estrutura Final

```
~\.claude\
├── settings              ← Arquivo do Claude Code (NÃO mexer)
└── presets\
    ├── switch-preset.ps1 ← Script principal
    ├── router.json       ← Preset Smart Router (Opcional)
    ├── kimi.json         ← Preset Kimi
    ├── glm.json          ← Preset GLM
    ├── minimax.json      ← Preset MiniMax
    ├── .active-preset    ← Auto-gerado (último preset)
    └── oauth-backup.json ← Auto-gerado (backup OAuth)
```
