# ╔══════════════════════════════════════════════════════════╗
# ║  cmodel installer — by kekeu 🐉                        ║
# ║  Claude Code Preset Switcher + CCR Dashboard            ║
# ║  https://github.com/Kekeu-u/claude-code-presets-switcher║
# ╚══════════════════════════════════════════════════════════╝
#
# Install:
#   irm https://raw.githubusercontent.com/Kekeu-u/claude-code-presets-switcher/main/i | iex

$ErrorActionPreference = "Stop"

# ─── i18n ──────────────────────────────────────────────────

$lang = if ((Get-Culture).Name -match "^pt") { "pt" } else { "en" }

$i18n = @{
    en = @{
        banner_title = "cmodel installer"
        banner_sub   = "Claude Code Preset Switcher"
        step1        = "Detecting language"
        step1_ok     = "Language: English"
        step2        = "Checking dependencies"
        step2_git    = "Git found"
        step2_node   = "Node.js found"
        step3        = "Downloading cmodel"
        step3_update = "Updating existing installation"
        step3_ok     = "cmodel ready"
        step4        = "Setting up PowerShell profile"
        step4_ok     = "Aliases registered: cmodel, claude-preset"
        step4_skip   = "Profile already configured"
        step5        = "Registering ccr-dash command"
        step5_ok     = "ccr-dash available globally"
        step5_skip   = "Dashboard not found (optional)"
        step6        = "Creating quick reference guide"
        step6_ok     = "Guide saved to Desktop"
        step7        = "Done!"
        step7_usage  = "Quick start"
        step7_cmd1   = "cmodel              Interactive preset menu"
        step7_cmd2   = "cmodel <name>       Switch to a preset"
        step7_cmd3   = "cmodel -List        List all presets"
        step7_cmd4   = "ccr-dash            Open CCR Dashboard"
        step7_next   = "Restart your terminal, then run: cmodel"
        err_git      = "Git is required. Install: winget install Git.Git"
        err_node     = "Node.js is required. Install: winget install OpenJS.NodeJS.LTS"
        err_fail     = "Installation failed"
        guide_file   = "kekeu-ccr-guide.md"
    }
    pt = @{
        banner_title = "instalador cmodel"
        banner_sub   = "Claude Code Preset Switcher"
        step1        = "Detectando idioma"
        step1_ok     = "Idioma: Portugues"
        step2        = "Verificando dependencias"
        step2_git    = "Git encontrado"
        step2_node   = "Node.js encontrado"
        step3        = "Baixando cmodel"
        step3_update = "Atualizando instalacao existente"
        step3_ok     = "cmodel pronto"
        step4        = "Configurando perfil PowerShell"
        step4_ok     = "Aliases registrados: cmodel, claude-preset"
        step4_skip   = "Perfil ja configurado"
        step5        = "Registrando comando ccr-dash"
        step5_ok     = "ccr-dash disponivel globalmente"
        step5_skip   = "Dashboard nao encontrado (opcional)"
        step6        = "Criando guia de referencia rapida"
        step6_ok     = "Guia salvo na Area de Trabalho"
        step7        = "Concluido!"
        step7_usage  = "Como usar"
        step7_cmd1   = "cmodel              Menu interativo de presets"
        step7_cmd2   = "cmodel <nome>       Trocar para um preset"
        step7_cmd3   = "cmodel -List        Listar todos os presets"
        step7_cmd4   = "ccr-dash            Abrir Dashboard CCR"
        step7_next   = "Reinicie o terminal e rode: cmodel"
        err_git      = "Git e necessario. Instale: winget install Git.Git"
        err_node     = "Node.js e necessario. Instale: winget install OpenJS.NodeJS.LTS"
        err_fail     = "Falha na instalacao"
        guide_file   = "kekeu-ccr-guide.md"
    }
}

$t = $i18n[$lang]
$totalSteps = 7

# ─── Helpers ───────────────────────────────────────────────

function Write-Step { param([int]$n, [string]$msg) Write-Host "  [$n/$totalSteps] " -ForegroundColor DarkCyan -NoNewline; Write-Host $msg -ForegroundColor White }
function Write-Ok { param([string]$msg) Write-Host "     -> " -ForegroundColor Green -NoNewline; Write-Host $msg -ForegroundColor Green }
function Write-Warn { param([string]$msg) Write-Host "     -> " -ForegroundColor Yellow -NoNewline; Write-Host $msg -ForegroundColor Yellow }
function Write-Err { param([string]$msg) Write-Host "     -> " -ForegroundColor Red -NoNewline; Write-Host $msg -ForegroundColor Red }
function Write-Sep { Write-Host "  ════════════════════════════════════════" -ForegroundColor DarkGreen }
function Write-Mini { param([string]$msg) Write-Host "        $msg" -ForegroundColor DarkGray }

# ─── Banner ────────────────────────────────────────────────

Clear-Host
Write-Host ""
Write-Host "         __        _ " -ForegroundColor DarkGreen
Write-Host "       _/  \    _(\(o" -ForegroundColor DarkGreen
Write-Host "      ( \  `---'   \ " -ForegroundColor DarkGreen -NoNewline; Write-Host "   $($t.banner_title)" -ForegroundColor Green
Write-Host "       )   \     |_| " -ForegroundColor DarkGreen -NoNewline; Write-Host "   $($t.banner_sub)" -ForegroundColor DarkGray
Write-Host "      (  )__)____/   " -ForegroundColor DarkGreen -NoNewline; Write-Host "   by kekeu" -ForegroundColor DarkGray
Write-Host ""

# ─── Step 1: Language ──────────────────────────────────────

Write-Step 1 $t.step1
Write-Ok $t.step1_ok
Write-Host ""

# ─── Step 2: Pre-checks ───────────────────────────────────

Write-Step 2 $t.step2

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Err $t.err_git; Write-Host ""; return
}
Write-Ok $t.step2_git

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Err $t.err_node; Write-Host ""; return
}
Write-Ok $t.step2_node
Write-Host ""

# ─── Step 3: Clone / Update ───────────────────────────────

$installDir = "$env:USERPROFILE\.claude\presets"
$repoUrl = "https://github.com/Kekeu-u/claude-code-presets-switcher.git"

try {
    if (Test-Path "$installDir\.git") {
        Write-Step 3 $t.step3_update
        git -C $installDir pull --quiet 2>&1 | Out-Null
    }
    else {
        Write-Step 3 $t.step3

        # Backup existing presets
        $backupDir = "$env:TEMP\cmodel-backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        if (Test-Path $installDir) {
            Copy-Item $installDir $backupDir -Recurse -Force
        }

        # Ensure parent dir exists
        $parentDir = Split-Path $installDir
        if (-not (Test-Path $parentDir)) {
            New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
        }

        # Clone
        git clone $repoUrl $installDir --quiet 2>&1 | Out-Null

        # Restore backed up user presets
        if (Test-Path $backupDir) {
            Get-ChildItem "$backupDir\*.json" -ErrorAction SilentlyContinue | ForEach-Object {
                if (-not (Test-Path "$installDir\$($_.Name)")) {
                    Copy-Item $_.FullName $installDir -Force
                }
            }
            if (Test-Path "$backupDir\.active-preset") {
                Copy-Item "$backupDir\.active-preset" $installDir -Force
            }
        }
    }
    Write-Ok $t.step3_ok
}
catch {
    Write-Err "$($t.err_fail): $($_.Exception.Message)"
    Write-Host ""; return
}
Write-Host ""

# ─── Step 4: PowerShell Profile ────────────────────────────

Write-Step 4 $t.step4

$profilePath = $PROFILE
$profileDir = Split-Path $profilePath
if (-not (Test-Path $profileDir)) { New-Item -ItemType Directory -Path $profileDir -Force | Out-Null }
if (-not (Test-Path $profilePath)) { New-Item -ItemType File -Path $profilePath -Force | Out-Null }

$profileContent = Get-Content $profilePath -Raw -ErrorAction SilentlyContinue
if ($profileContent -and $profileContent -match "Switch-ClaudePreset") {
    Write-Ok $t.step4_skip
}
else {
    $snippet = @"

# Claude Code Preset Switcher - by kekeu
function Switch-ClaudePreset {
    . "`$env:USERPROFILE\.claude\presets\switch-preset.ps1" @args
}
Set-Alias claude-preset Switch-ClaudePreset
Set-Alias cmodel Switch-ClaudePreset
"@
    Add-Content -Path $profilePath -Value $snippet -Encoding utf8
    Write-Ok $t.step4_ok
}
Write-Host ""

# ─── Step 5: Register ccr-dash ─────────────────────────────

Write-Step 5 $t.step5

$dashBat = "$installDir\dashboard\ccr-dash.bat"
$npmDir = "$env:APPDATA\npm"

if ((Test-Path $dashBat) -and (Test-Path $npmDir)) {
    Copy-Item $dashBat "$npmDir\ccr-dash.bat" -Force
    Write-Ok $t.step5_ok
}
else {
    Write-Warn $t.step5_skip
}
Write-Host ""

# ─── Step 6: Generate Quick Reference Guide ───────────────

Write-Step 6 $t.step6

$desktopPath = [Environment]::GetFolderPath("Desktop")
$guidePath = Join-Path $desktopPath $t.guide_file

if ($lang -eq "pt") {
    $guideContent = @"
# cmodel - Guia de Referencia Rapida

> by **kekeu** | [GitHub](https://github.com/Kekeu-u/claude-code-presets-switcher)

---

## Comandos Essenciais

| Comando | O que faz |
|---------|-----------|
| ``cmodel`` | Menu interativo para escolher preset |
| ``cmodel <nome>`` | Troca direto para um preset |
| ``cmodel anthropic`` | Volta ao Claude oficial (OAuth) |
| ``cmodel -List`` | Lista todos os presets disponiveis |
| ``cmodel -Status`` | Mostra qual preset esta ativo |
| ``ccr-dash`` | Abre o dashboard CCR no browser |

---

## Como Criar um Preset

1. Crie um arquivo ``~/.claude/presets/meu-preset.json``
2. Use esta estrutura:

``````json
{
  "_preset": {
    "name": "Meu Preset",
    "description": "Descricao curta do preset"
  },
  "env": {
    "ANTHROPIC_BASE_URL": "https://seu-provider.com/v1",
    "ANTHROPIC_AUTH_TOKEN": "sk-sua-chave-aqui",
    "ANTHROPIC_MODEL": "nome-do-modelo"
  }
}
``````

3. Rode ``cmodel meu-preset`` e pronto!

---

## Campos Opcionais do env

| Campo | Para que serve |
|-------|---------------|
| ``ANTHROPIC_DEFAULT_SONNET_MODEL`` | Override do modelo Sonnet |
| ``ANTHROPIC_DEFAULT_OPUS_MODEL`` | Override do modelo Opus |
| ``ANTHROPIC_DEFAULT_HAIKU_MODEL`` | Override do modelo Haiku |
| ``ANTHROPIC_SMALL_FAST_MODEL`` | Modelo para tarefas rapidas |
| ``API_TIMEOUT_MS`` | Timeout da API (ms) |

---

## Dicas

- **Auto-start CCR**: Presets que usam ``localhost:3000`` iniciam o router automaticamente
- **Dashboard**: O CCR Dashboard abre no browser quando o router inicia
- **Atualizar**: Rode o comando de instalacao novamente para atualizar

``````powershell
irm https://raw.githubusercontent.com/Kekeu-u/claude-code-presets-switcher/main/i | iex
``````

---

*Gerado automaticamente pelo installer cmodel*
"@
}
else {
    $guideContent = @"
# cmodel - Quick Reference Guide

> by **kekeu** | [GitHub](https://github.com/Kekeu-u/claude-code-presets-switcher)

---

## Essential Commands

| Command | What it does |
|---------|-------------|
| ``cmodel`` | Interactive menu to choose a preset |
| ``cmodel <name>`` | Switch directly to a preset |
| ``cmodel anthropic`` | Switch back to official Claude (OAuth) |
| ``cmodel -List`` | List all available presets |
| ``cmodel -Status`` | Show the currently active preset |
| ``ccr-dash`` | Open CCR Dashboard in the browser |

---

## How to Create a Preset

1. Create a file ``~/.claude/presets/my-preset.json``
2. Use this structure:

``````json
{
  "_preset": {
    "name": "My Preset",
    "description": "Short description of the preset"
  },
  "env": {
    "ANTHROPIC_BASE_URL": "https://your-provider.com/v1",
    "ANTHROPIC_AUTH_TOKEN": "sk-your-key-here",
    "ANTHROPIC_MODEL": "model-name"
  }
}
``````

3. Run ``cmodel my-preset`` and you're good to go!

---

## Optional env Fields

| Field | Purpose |
|-------|---------|
| ``ANTHROPIC_DEFAULT_SONNET_MODEL`` | Sonnet model override |
| ``ANTHROPIC_DEFAULT_OPUS_MODEL`` | Opus model override |
| ``ANTHROPIC_DEFAULT_HAIKU_MODEL`` | Haiku model override |
| ``ANTHROPIC_SMALL_FAST_MODEL`` | Model for fast/small tasks |
| ``API_TIMEOUT_MS`` | API timeout in milliseconds |

---

## Tips

- **Auto-start CCR**: Presets using ``localhost:3000`` automatically start the router
- **Dashboard**: CCR Dashboard opens in the browser when the router starts
- **Update**: Run the install command again to update

``````powershell
irm https://raw.githubusercontent.com/Kekeu-u/claude-code-presets-switcher/main/i | iex
``````

---

*Auto-generated by cmodel installer*
"@
}

try {
    [System.IO.File]::WriteAllText($guidePath, $guideContent, [System.Text.UTF8Encoding]::new($false))
    Write-Ok "$($t.step6_ok): $($t.guide_file)"
}
catch {
    Write-Warn "Could not save guide: $($_.Exception.Message)"
}
Write-Host ""

# ─── Step 7: Done! ─────────────────────────────────────────

Write-Sep
Write-Host ""
Write-Host "  " -NoNewline
Write-Host $t.step7 -ForegroundColor Green
Write-Host ""
Write-Host "  $($t.step7_usage):" -ForegroundColor Cyan
Write-Host "     $($t.step7_cmd1)" -ForegroundColor Gray
Write-Host "     $($t.step7_cmd2)" -ForegroundColor Gray
Write-Host "     $($t.step7_cmd3)" -ForegroundColor Gray
Write-Host "     $($t.step7_cmd4)" -ForegroundColor Gray
Write-Host ""
Write-Host "  -> " -ForegroundColor Yellow -NoNewline
Write-Host $t.step7_next -ForegroundColor Yellow
Write-Host ""
Write-Sep
Write-Host ""
