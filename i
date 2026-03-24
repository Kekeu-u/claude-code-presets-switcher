# cmodel installer
#
# Install:
#   irm https://raw.githubusercontent.com/Kekeu-u/claude-code-presets-switcher/main/i | iex

$ErrorActionPreference = "Stop"

$lang = if ((Get-Culture).Name -match "^pt") { "pt" } else { "en" }

$i18n = @{
    en = @{
        banner_title = "cmodel installer"
        banner_sub   = "Claude Code Preset Switcher"
        step1        = "Detecting language"
        step1_ok     = "Language: English"
        step2        = "Checking dependencies"
        step2_git    = "Git found"
        step3        = "Downloading cmodel"
        step3_update = "Updating existing installation"
        step3_ok     = "cmodel ready"
        step4        = "Setting up PowerShell profile"
        step4_ok     = "Aliases registered: cmodel, claude-preset"
        step4_skip   = "Profile already configured"
        step5        = "Creating quick reference guide"
        step5_ok     = "Guide saved to Desktop"
        step6        = "Done!"
        step6_usage  = "Quick start"
        step6_cmd1   = "cmodel              Choose a preset"
        step6_cmd2   = "cmodel litellm      Open Claude with local LiteLLM"
        step6_cmd3   = "cmodel <name> -ApplyOnly   Apply only in this terminal"
        step6_cmd4   = "cmodel <name> -SetDefault  Persist for VS Code Claude"
        step6_next   = "Restart your terminal, then run: cmodel"
        err_git      = "Git is required. Install: winget install Git.Git"
        err_fail     = "Installation failed"
        guide_file   = "kekeu-cmodel-guide.md"
    }
    pt = @{
        banner_title = "instalador cmodel"
        banner_sub   = "Claude Code Preset Switcher"
        step1        = "Detectando idioma"
        step1_ok     = "Idioma: Portugues"
        step2        = "Verificando dependencias"
        step2_git    = "Git encontrado"
        step3        = "Baixando cmodel"
        step3_update = "Atualizando instalacao existente"
        step3_ok     = "cmodel pronto"
        step4        = "Configurando perfil PowerShell"
        step4_ok     = "Aliases registrados: cmodel, claude-preset"
        step4_skip   = "Perfil ja configurado"
        step5        = "Criando guia de referencia rapida"
        step5_ok     = "Guia salvo na Area de Trabalho"
        step6        = "Concluido!"
        step6_usage  = "Como usar"
        step6_cmd1   = "cmodel              Escolhe um preset"
        step6_cmd2   = "cmodel litellm      Abre o Claude com LiteLLM local"
        step6_cmd3   = "cmodel <nome> -ApplyOnly   Aplica so neste terminal"
        step6_cmd4   = "cmodel <nome> -SetDefault  Salva para o VS Code Claude"
        step6_next   = "Reinicie o terminal e rode: cmodel"
        err_git      = "Git e necessario. Instale: winget install Git.Git"
        err_fail     = "Falha na instalacao"
        guide_file   = "kekeu-cmodel-guide.md"
    }
}

$t = $i18n[$lang]
$totalSteps = 5

function Write-Step { param([int]$n, [string]$msg) Write-Host "  [$n/$totalSteps] " -ForegroundColor DarkCyan -NoNewline; Write-Host $msg -ForegroundColor White }
function Write-Ok { param([string]$msg) Write-Host "     -> " -ForegroundColor Green -NoNewline; Write-Host $msg -ForegroundColor Green }
function Write-Warn { param([string]$msg) Write-Host "     -> " -ForegroundColor Yellow -NoNewline; Write-Host $msg -ForegroundColor Yellow }
function Write-Err { param([string]$msg) Write-Host "     -> " -ForegroundColor Red -NoNewline; Write-Host $msg -ForegroundColor Red }
function Write-Sep { Write-Host "  =======================================" -ForegroundColor DarkGreen }

function Remove-OldDashboardFiles {
    param([string]$InstallDir)

    $dashboardDir = Join-Path $InstallDir "dashboard"
    if (Test-Path $dashboardDir) {
        Remove-Item $dashboardDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    $dashBat = Join-Path $env:APPDATA "npm\ccr-dash.bat"
    if (Test-Path $dashBat) {
        Remove-Item $dashBat -Force -ErrorAction SilentlyContinue
    }
}

Clear-Host
Write-Host ""
Write-Sep
Write-Host ""
Write-Host "      " -NoNewline
Write-Host $t.banner_title -ForegroundColor Green
Write-Host "      $($t.banner_sub)" -ForegroundColor DarkGray
Write-Host "      by " -ForegroundColor DarkGray -NoNewline
Write-Host "kekeu" -ForegroundColor Green
Write-Host ""
Write-Sep
Write-Host ""

Write-Step 1 $t.step1
Write-Ok $t.step1_ok
Write-Host ""

Write-Step 2 $t.step2
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Err $t.err_git
    Write-Host ""
    return
}
Write-Ok $t.step2_git
Write-Host ""

$installDir = "$env:USERPROFILE\.claude\presets"
$repoUrl = "https://github.com/Kekeu-u/claude-code-presets-switcher.git"

try {
    if (Test-Path "$installDir\.git") {
        Write-Step 3 $t.step3_update
        git -C $installDir pull --quiet 2>&1 | Out-Null
    }
    else {
        Write-Step 3 $t.step3

        $backupDir = "$env:TEMP\cmodel-backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        if (Test-Path $installDir) {
            Copy-Item $installDir $backupDir -Recurse -Force
        }

        $parentDir = Split-Path $installDir
        if (-not (Test-Path $parentDir)) {
            New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
        }

        git clone $repoUrl $installDir --quiet 2>&1 | Out-Null

        if (Test-Path $backupDir) {
            Get-ChildItem "$backupDir\*.json" -ErrorAction SilentlyContinue | ForEach-Object {
                if (-not (Test-Path "$installDir\$($_.Name)")) {
                    Copy-Item $_.FullName $installDir -Force
                }
            }
        }
    }

    foreach ($legacyPath in @(
        "$installDir\.active-preset",
        "$installDir\oauth-accounts.json",
        "$installDir\oauth-backup.json",
        "$installDir\GUIA-PRESETS.md"
    )) {
        if (Test-Path $legacyPath) {
            Remove-Item $legacyPath -Force -ErrorAction SilentlyContinue
        }
    }

    Remove-OldDashboardFiles -InstallDir $installDir
    Write-Ok $t.step3_ok
}
catch {
    Write-Err "$($t.err_fail): $($_.Exception.Message)"
    Write-Host ""
    return
}
Write-Host ""

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

Write-Step 5 $t.step5
$desktopPath = [Environment]::GetFolderPath("Desktop")
$guidePath = Join-Path $desktopPath $t.guide_file

if ($lang -eq "pt") {
    $guideContent = @"
# cmodel - Guia de Referencia Rapida

## Comandos

| Comando | O que faz |
|---------|-----------|
| ``cmodel`` | Abre o menu de presets |
| ``cmodel litellm`` | Abre o Claude com o proxy LiteLLM local |
| ``cmodel <nome> -ApplyOnly`` | Aplica so neste terminal |
| ``cmodel <nome> -SetDefault`` | Salva em ``~/.claude/settings.local.json`` |
| ``cmodel anthropic`` | Volta para o Claude oficial |

## LiteLLM local

1. Suba o LiteLLM:

``````bash
litellm --config config.yaml
``````

2. Exemplo minimo de preset:

``````json
{
  "_preset": {
    "name": "LiteLLM Local",
    "description": "Proxy local via LiteLLM"
  },
  "env": {
    "ANTHROPIC_BASE_URL": "http://127.0.0.1:4000/v1/messages",
    "ANTHROPIC_AUTH_TOKEN": "sk-litellm-local",
    "ANTHROPIC_MODEL": "claude-code",
    "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": 1
  }
}
``````

3. Se seu LiteLLM estiver usando passthrough Anthropic, troque a URL para:

``````text
http://127.0.0.1:4000/anthropic/v1/messages
``````
"@
}
else {
    $guideContent = @"
# cmodel - Quick Reference Guide

## Commands

| Command | What it does |
|---------|--------------|
| ``cmodel`` | Opens the preset menu |
| ``cmodel litellm`` | Opens Claude with the local LiteLLM proxy |
| ``cmodel <name> -ApplyOnly`` | Applies only in this terminal |
| ``cmodel <name> -SetDefault`` | Persists into ``~/.claude/settings.local.json`` |
| ``cmodel anthropic`` | Returns to official Claude |

## Local LiteLLM

1. Start LiteLLM:

``````bash
litellm --config config.yaml
``````

2. Minimal preset example:

``````json
{
  "_preset": {
    "name": "LiteLLM Local",
    "description": "Local proxy via LiteLLM"
  },
  "env": {
    "ANTHROPIC_BASE_URL": "http://127.0.0.1:4000/v1/messages",
    "ANTHROPIC_AUTH_TOKEN": "sk-litellm-local",
    "ANTHROPIC_MODEL": "claude-code",
    "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": 1
  }
}
``````

3. If your LiteLLM setup uses Anthropic passthrough, switch the URL to:

``````text
http://127.0.0.1:4000/anthropic/v1/messages
``````
"@
}

try {
    [System.IO.File]::WriteAllText($guidePath, $guideContent, [System.Text.UTF8Encoding]::new($false))
    Write-Ok "$($t.step5_ok): $($t.guide_file)"
}
catch {
    Write-Warn "Could not save guide: $($_.Exception.Message)"
}
Write-Host ""

Write-Sep
Write-Host ""
Write-Host "  " -NoNewline
Write-Host $t.step6 -ForegroundColor Green
Write-Host ""
Write-Host "  $($t.step6_usage):" -ForegroundColor Cyan
Write-Host "     $($t.step6_cmd1)" -ForegroundColor Gray
Write-Host "     $($t.step6_cmd2)" -ForegroundColor Gray
Write-Host "     $($t.step6_cmd3)" -ForegroundColor Gray
Write-Host "     $($t.step6_cmd4)" -ForegroundColor Gray
Write-Host ""
Write-Host "  -> " -ForegroundColor Yellow -NoNewline
Write-Host $t.step6_next -ForegroundColor White
Write-Host ""
Write-Sep
Write-Host ""
