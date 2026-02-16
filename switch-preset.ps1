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
            [Environment]::SetEnvironmentVariable($varName, $null, "User")
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
    Write-Host "  � Iniciar Claude Code agora? " -ForegroundColor Green -NoNewline
    Write-Host "[Enter = Sim / Q = Não]" -ForegroundColor DarkGray

    $key = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    if ($key.VirtualKeyCode -eq 13) {
        Write-Host ""
        Show-Separator
        Write-Host ""
        claude
    }
    else {
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
        Write-Host "  � Usando Anthropic OAuth" -ForegroundColor Gray
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
}
else {
    Write-Host "  ⚠️  Algumas env vars não foram definidas!" -ForegroundColor Red
}

Write-Host ""
Show-Separator
Prompt-LaunchClaude



if ($ok) {
    Write-Host "  ✅ Todas as env vars configuradas" -ForegroundColor Green
}
else {
    Write-Host "  ⚠️  Algumas env vars não foram definidas!" -ForegroundColor Red
}

Write-Host ""
Show-Separator
Prompt-LaunchClaude
