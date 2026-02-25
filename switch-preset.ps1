# ╔══════════════════════════════════════════╗
# ║  cmodel - Claude Code Preset Switcher    ║
# ║  by kekeu 🐉                             ║
# ╚══════════════════════════════════════════╝
#
# Uso: cmodel              (menu interativo)
#       cmodel kimi          (direto)
#       cmodel anthropic     (volta ao padrão OAuth)
#       cmodel anthropic <conta> (troca para conta OAuth salva)
#       cmodel account ...   (gerencia contas OAuth salvas)
#       cmodel clean          (limpa sessão atual e volta para OAuth)
#       cmodel -List         (lista presets)
#       cmodel -Status       (mostra preset ativo)
#       cmodel -Silent kimi  (troca sem banner, usado no auto-load)

param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$CliArgs
)

$PresetName = $null
$List = $false
$Status = $false
$Silent = $false
$extraArgs = @()

foreach ($arg in $CliArgs) {
    switch -Regex ($arg) {
        '^(-List|--list)$' { $List = $true; continue }
        '^(-Status|--status)$' { $Status = $true; continue }
        '^(-Silent|--silent)$' { $Silent = $true; continue }
        default {
            if (-not $PresetName) {
                $PresetName = $arg
            }
            else {
                $extraArgs += $arg
            }
        }
    }
}

$presetsDir = "$env:USERPROFILE\.claude\presets"
$activePresetFile = "$env:USERPROFILE\.claude\presets\.active-preset"
$settingsPath = "$env:USERPROFILE\.claude\settings"
$oauthAccountsStorePath = "$env:USERPROFILE\.claude\presets\oauth-accounts.json"

# Safety rule:
# This script preserves ~/.claude/settings structure.
# It only updates oauthAccount when explicitly switching saved accounts.

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

# Recursos iniciados por esta execução do cmodel (limpos no Ctrl+C do Claude).
$script:ManagedProcessIds = New-Object System.Collections.ArrayList
$script:ManagedJobNames = New-Object System.Collections.ArrayList

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

function Add-ManagedProcessId {
    param([int]$ProcessId)

    if ($ProcessId -le 0) { return }
    if (-not ($script:ManagedProcessIds -contains $ProcessId)) {
        [void]$script:ManagedProcessIds.Add($ProcessId)
    }
}

function Add-ManagedJobName {
    param([string]$JobName)

    if (-not $JobName) { return }
    if (-not ($script:ManagedJobNames -contains $JobName)) {
        [void]$script:ManagedJobNames.Add($JobName)
    }
}

function Stop-ManagedBackgroundResources {
    $stoppedSomething = $false

    foreach ($jobName in @($script:ManagedJobNames)) {
        $job = Get-Job -Name $jobName -ErrorAction SilentlyContinue
        if ($job) {
            Stop-Job -Id $job.Id -ErrorAction SilentlyContinue -Force
            Remove-Job -Id $job.Id -ErrorAction SilentlyContinue -Force
            $stoppedSomething = $true
        }
    }

    foreach ($procId in @($script:ManagedProcessIds)) {
        if ($procId -eq $PID) { continue }

        $proc = Get-Process -Id $procId -ErrorAction SilentlyContinue
        if ($proc) {
            Stop-Process -Id $procId -Force -ErrorAction SilentlyContinue
            $stoppedSomething = $true
        }
    }

    if ($stoppedSomething) {
        Write-Host "  🛑 Processos auxiliares iniciados pelo cmodel foram encerrados." -ForegroundColor Yellow
    }
}

function Invoke-ClaudeWithManagedCleanup {
    param([string]$LaunchedPreset = "anthropic")

    $managedCount = @($script:ManagedJobNames).Count + @($script:ManagedProcessIds).Count

    claude
    $exitCode = $LASTEXITCODE
    $interruptedByCtrlC = ($exitCode -eq 130)

    if ($interruptedByCtrlC -and $managedCount -gt 0) {
        Write-Host ""
        Write-Host "  ⛔ Ctrl+C detectado. Encerrando processos iniciados pelo cmodel..." -ForegroundColor Yellow
        Stop-ManagedBackgroundResources
    }

    if ($LaunchedPreset -and $LaunchedPreset -ne "anthropic") {
        Reset-ClaudeSessionState -Quiet
        Write-Host "  🧹 Sessão encerrada. Preset limpo deste terminal (modo sessão)." -ForegroundColor DarkGray
    }
}

function Write-JsonFile {
    param([object]$Data, [string]$Path)

    $json = $Data | ConvertTo-Json -Depth 100
    [System.IO.File]::WriteAllText($Path, $json, [System.Text.UTF8Encoding]::new($false))
}

function Get-ClaudeSettingsObject {
    if (-not (Test-Path $settingsPath)) {
        return $null
    }

    try {
        return (Get-Content $settingsPath -Raw | ConvertFrom-Json)
    }
    catch {
        return $null
    }
}

function Get-CurrentOAuthAccount {
    $settings = Get-ClaudeSettingsObject
    if ($settings -and $settings.oauthAccount) {
        return $settings.oauthAccount
    }
    return $null
}

function Set-CurrentOAuthAccount {
    param([object]$OauthAccount)

    if (-not (Test-Path $settingsPath)) {
        return $false
    }

    $settings = Get-ClaudeSettingsObject
    if (-not $settings) {
        return $false
    }

    $settings | Add-Member -NotePropertyName "oauthAccount" -NotePropertyValue $OauthAccount -Force
    Write-JsonFile -Data $settings -Path $settingsPath
    return $true
}

function Get-OAuthAccountsStore {
    if (Test-Path $oauthAccountsStorePath) {
        try {
            $store = Get-Content $oauthAccountsStorePath -Raw | ConvertFrom-Json
            if (-not $store.version) { $store | Add-Member -NotePropertyName "version" -NotePropertyValue 1 -Force }
            if (-not $store.uuidIndex) { $store | Add-Member -NotePropertyName "uuidIndex" -NotePropertyValue ([PSCustomObject]@{}) -Force }
            if (-not $store.accounts) { $store | Add-Member -NotePropertyName "accounts" -NotePropertyValue ([PSCustomObject]@{}) -Force }
            if (-not $store.PSObject.Properties["currentAlias"]) { $store | Add-Member -NotePropertyName "currentAlias" -NotePropertyValue $null -Force }
            return $store
        }
        catch {
            # Fall through to default structure.
        }
    }

    return [PSCustomObject]@{
        version = 1
        currentAlias = $null
        uuidIndex = [PSCustomObject]@{}
        accounts = [PSCustomObject]@{}
    }
}

function Save-OAuthAccountsStore {
    param([object]$Store)
    Write-JsonFile -Data $Store -Path $oauthAccountsStorePath
}

function Normalize-AccountAlias {
    param([string]$Alias)

    if (-not $Alias) { return $null }

    $normalized = $Alias.Trim().ToLowerInvariant()
    $normalized = $normalized -replace "[^a-z0-9._-]", "-"
    $normalized = $normalized -replace "-{2,}", "-"
    $normalized = $normalized -replace "^[._-]+", ""
    $normalized = $normalized -replace "[._-]+$", ""

    if (-not $normalized) { return $null }
    return $normalized
}

function Get-DefaultAccountAlias {
    param([object]$OauthAccount)

    $candidate = $null

    if ($OauthAccount.displayName) {
        $candidate = [string]$OauthAccount.displayName
    }
    elseif ($OauthAccount.emailAddress) {
        $candidate = ([string]$OauthAccount.emailAddress).Split("@")[0]
    }
    elseif ($OauthAccount.accountUuid) {
        $uuidText = [string]$OauthAccount.accountUuid
        $candidate = if ($uuidText.Length -ge 8) { $uuidText.Substring(0, 8) } else { $uuidText }
    }

    $alias = Normalize-AccountAlias $candidate
    if (-not $alias) {
        $alias = "anthropic-account"
    }

    return $alias
}

function Get-SavedAliasForAccountUuid {
    param([string]$AccountUuid)

    if (-not $AccountUuid) { return $null }

    $store = Get-OAuthAccountsStore
    $prop = $store.uuidIndex.PSObject.Properties[$AccountUuid]
    if ($prop) {
        return [string]$prop.Value
    }

    return $null
}

function Save-OAuthAccountProfile {
    param(
        [string]$Alias,
        [string]$Source = "manual",
        [switch]$Quiet
    )

    $oauth = Get-CurrentOAuthAccount
    if (-not $oauth) {
        if (-not $Quiet) {
            Write-Host "  ❌ Nenhuma conta OAuth encontrada no Claude. Rode 'claude login' primeiro." -ForegroundColor Red
        }
        return $null
    }

    $accountUuid = [string]$oauth.accountUuid
    if (-not $accountUuid) {
        if (-not $Quiet) {
            Write-Host "  ❌ Conta atual sem accountUuid. Não foi possível salvar." -ForegroundColor Red
        }
        return $null
    }

    $store = Get-OAuthAccountsStore

    $existingAliasByUuid = $null
    $uuidProp = $store.uuidIndex.PSObject.Properties[$accountUuid]
    if ($uuidProp) {
        $existingAliasByUuid = [string]$uuidProp.Value
    }

    $targetAlias = $null
    if ($Alias) {
        $targetAlias = Normalize-AccountAlias $Alias
        if (-not $targetAlias) {
            if (-not $Quiet) {
                Write-Host "  ❌ Nome da conta inválido. Use letras, números, '.', '-' ou '_'." -ForegroundColor Red
            }
            return $null
        }

        $targetAliasProp = $store.accounts.PSObject.Properties[$targetAlias]
        if ($targetAliasProp) {
            $ownerUuid = [string]$targetAliasProp.Value.accountUuid
            if ($ownerUuid -and $ownerUuid -ne $accountUuid) {
                if (-not $Quiet) {
                    Write-Host "  ❌ Já existe outra conta com o nome '$targetAlias'." -ForegroundColor Red
                }
                return $null
            }
        }
    }
    elseif ($existingAliasByUuid) {
        $targetAlias = $existingAliasByUuid
    }
    else {
        $baseAlias = Get-DefaultAccountAlias -OauthAccount $oauth
        $targetAlias = $baseAlias
        $suffix = 2

        while ($store.accounts.PSObject.Properties[$targetAlias]) {
            $targetAlias = "$baseAlias-$suffix"
            $suffix += 1
        }
    }

    if ($existingAliasByUuid -and $existingAliasByUuid -ne $targetAlias) {
        $store.accounts.PSObject.Properties.Remove($existingAliasByUuid)
    }

    $entry = [PSCustomObject]@{
        alias = $targetAlias
        savedAt = (Get-Date).ToString("o")
        source = $Source
        accountUuid = $accountUuid
        emailAddress = [string]$oauth.emailAddress
        displayName = [string]$oauth.displayName
        organizationName = [string]$oauth.organizationName
        oauthAccount = $oauth
    }

    $store.accounts | Add-Member -NotePropertyName $targetAlias -NotePropertyValue $entry -Force
    $store.uuidIndex | Add-Member -NotePropertyName $accountUuid -NotePropertyValue $targetAlias -Force

    if (-not $store.currentAlias) {
        $store.currentAlias = $targetAlias
    }

    Save-OAuthAccountsStore -Store $store

    if (-not $Quiet) {
        Write-Host "  ✅ Conta OAuth salva como '$targetAlias'." -ForegroundColor Green
    }

    return $targetAlias
}

function Remove-OAuthAccountProfile {
    param([string]$Alias)

    $normalizedAlias = Normalize-AccountAlias $Alias
    if (-not $normalizedAlias) {
        return $false
    }

    $store = Get-OAuthAccountsStore
    $prop = $store.accounts.PSObject.Properties[$normalizedAlias]
    if (-not $prop) {
        return $false
    }

    $accountUuid = [string]$prop.Value.accountUuid
    $store.accounts.PSObject.Properties.Remove($normalizedAlias)
    if ($accountUuid) {
        $store.uuidIndex.PSObject.Properties.Remove($accountUuid)
    }

    if ($store.currentAlias -eq $normalizedAlias) {
        $store.currentAlias = $null
    }

    Save-OAuthAccountsStore -Store $store
    return $true
}

function Show-OAuthAccountList {
    $store = Get-OAuthAccountsStore
    $currentOauth = Get-CurrentOAuthAccount
    $currentUuid = if ($currentOauth) { [string]$currentOauth.accountUuid } else { $null }

    Show-Banner
    Write-Host "  👤 Contas OAuth salvas:" -ForegroundColor Cyan
    Write-Host ""

    $aliases = @($store.accounts.PSObject.Properties.Name | Sort-Object)
    if ($aliases.Count -eq 0) {
        Write-Host "    (nenhuma conta salva)" -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "  💡 Rode: cmodel account save <nome>" -ForegroundColor DarkGray
        Show-Separator
        Write-Host ""
        return
    }

    foreach ($alias in $aliases) {
        $entry = $store.accounts.PSObject.Properties[$alias].Value
        $email = if ($entry.emailAddress) { $entry.emailAddress } else { "sem-email" }
        $displayName = if ($entry.displayName) { $entry.displayName } else { "sem-nome" }
        $marker = if ($currentUuid -and ([string]$entry.accountUuid -eq $currentUuid)) { " ◀ atual" } else { "" }

        Write-Host "    $alias" -ForegroundColor Yellow -NoNewline
        Write-Host " - $displayName <$email>" -ForegroundColor Gray -NoNewline
        Write-Host $marker -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "  💡 Uso: cmodel account use <nome>" -ForegroundColor DarkGray
    Show-Separator
    Write-Host ""
}

function Show-OAuthAccountHelp {
    Write-Host "  Uso de contas OAuth:" -ForegroundColor Cyan
    Write-Host "    cmodel account list" -ForegroundColor Gray
    Write-Host "    cmodel account save <nome>" -ForegroundColor Gray
    Write-Host "    cmodel account use <nome>" -ForegroundColor Gray
    Write-Host "    cmodel account rm <nome>" -ForegroundColor Gray
    Write-Host "    cmodel account current" -ForegroundColor Gray
    Write-Host ""
}

function Show-CurrentOAuthAccount {
    Show-Banner
    $oauth = Get-CurrentOAuthAccount
    if (-not $oauth) {
        Write-Host "  ❌ Nenhuma conta OAuth ativa." -ForegroundColor Red
        Write-Host "  💡 Rode: claude login" -ForegroundColor DarkGray
        Write-Host ""
        Show-Separator
        Write-Host ""
        return
    }

    $alias = Get-SavedAliasForAccountUuid -AccountUuid ([string]$oauth.accountUuid)

    Write-Host "  👤 Conta OAuth atual:" -ForegroundColor Cyan
    Write-Host "    Nome:   $($oauth.displayName)" -ForegroundColor Gray
    Write-Host "    Email:  $($oauth.emailAddress)" -ForegroundColor Gray
    Write-Host "    UUID:   $($oauth.accountUuid)" -ForegroundColor DarkGray
    if ($alias) {
        Write-Host "    Alias:  $alias" -ForegroundColor Green
    }

    Write-Host ""
    Show-Separator
    Write-Host ""
}

function Use-SavedOAuthAccount {
    param(
        [string]$Alias,
        [switch]$Quiet
    )

    $normalizedAlias = Normalize-AccountAlias $Alias
    if (-not $normalizedAlias) {
        if (-not $Quiet) {
            Write-Host "  ❌ Nome da conta inválido." -ForegroundColor Red
        }
        return $false
    }

    $store = Get-OAuthAccountsStore
    $entryProp = $store.accounts.PSObject.Properties[$normalizedAlias]
    if (-not $entryProp) {
        if (-not $Quiet) {
            Write-Host "  ❌ Conta '$normalizedAlias' não encontrada." -ForegroundColor Red
        }
        return $false
    }

    $entry = $entryProp.Value
    if (-not $entry.oauthAccount) {
        if (-not $Quiet) {
            Write-Host "  ❌ Conta '$normalizedAlias' sem dados OAuth válidos." -ForegroundColor Red
        }
        return $false
    }

    if (-not (Set-CurrentOAuthAccount -OauthAccount $entry.oauthAccount)) {
        if (-not $Quiet) {
            Write-Host "  ❌ Não foi possível atualizar ~/.claude/settings." -ForegroundColor Red
        }
        return $false
    }

    $entry | Add-Member -NotePropertyName "lastUsedAt" -NotePropertyValue (Get-Date).ToString("o") -Force
    $store.accounts | Add-Member -NotePropertyName $normalizedAlias -NotePropertyValue $entry -Force
    $store.currentAlias = $normalizedAlias
    Save-OAuthAccountsStore -Store $store

    if (-not $Quiet) {
        Write-Host "  ✅ Conta '$normalizedAlias' selecionada." -ForegroundColor Green
    }

    return $true
}

function Handle-OAuthAccountCommand {
    param([string[]]$CommandArgs)

    $action = "list"
    if ($CommandArgs -and $CommandArgs.Count -gt 0) {
        $action = $CommandArgs[0].ToLowerInvariant()
    }

    switch ($action) {
        "list" { Show-OAuthAccountList; return }
        "ls" { Show-OAuthAccountList; return }
        "help" { Show-Banner; Show-OAuthAccountHelp; Show-Separator; Write-Host ""; return }
        "current" { Show-CurrentOAuthAccount; return }
        "save" {
            $alias = if ($CommandArgs.Count -gt 1) { $CommandArgs[1] } else { $null }
            Show-Banner
            [void](Save-OAuthAccountProfile -Alias $alias -Source "manual")
            Write-Host ""
            Show-Separator
            Write-Host ""
            return
        }
        "use" {
            if ($CommandArgs.Count -lt 2) {
                Show-Banner
                Write-Host "  ❌ Informe a conta. Ex: cmodel account use trabalho" -ForegroundColor Red
                Write-Host ""
                Show-OAuthAccountHelp
                Show-Separator
                Write-Host ""
                return
            }

            Show-Banner
            $ok = Use-SavedOAuthAccount -Alias $CommandArgs[1]
            if ($ok) {
                Clear-ClaudeEnvVars
                Set-ActivePreset "anthropic"
                Write-Host "  ✅ Preset Anthropic ativo com a conta selecionada." -ForegroundColor Green
            }
            Write-Host ""
            Show-Separator
            Write-Host ""
            return
        }
        "rm" { 
            if ($CommandArgs.Count -lt 2) {
                Show-Banner
                Write-Host "  ❌ Informe a conta para remover. Ex: cmodel account rm trabalho" -ForegroundColor Red
                Write-Host ""
                Show-Separator
                Write-Host ""
                return
            }

            Show-Banner
            if (Remove-OAuthAccountProfile -Alias $CommandArgs[1]) {
                Write-Host "  ✅ Conta '$($CommandArgs[1])' removida." -ForegroundColor Green
            }
            else {
                Write-Host "  ❌ Conta '$($CommandArgs[1])' não encontrada." -ForegroundColor Red
            }
            Write-Host ""
            Show-Separator
            Write-Host ""
            return
        }
        "remove" {
            if ($CommandArgs.Count -lt 2) {
                Handle-OAuthAccountCommand -CommandArgs @("rm")
            }
            else {
                Handle-OAuthAccountCommand -CommandArgs @("rm", $CommandArgs[1])
            }
            return
        }
        "delete" {
            if ($CommandArgs.Count -lt 2) {
                Handle-OAuthAccountCommand -CommandArgs @("rm")
            }
            else {
                Handle-OAuthAccountCommand -CommandArgs @("rm", $CommandArgs[1])
            }
            return
        }
        default {
            Show-Banner
            Write-Host "  ❌ Comando desconhecido: account $action" -ForegroundColor Red
            Write-Host ""
            Show-OAuthAccountHelp
            Show-Separator
            Write-Host ""
            return
        }
    }
}

function Auto-CaptureCurrentOAuthAccount {
    $oauth = Get-CurrentOAuthAccount
    if (-not $oauth) { return }

    $accountUuid = [string]$oauth.accountUuid
    if (-not $accountUuid) { return }

    $store = Get-OAuthAccountsStore
    $existingAlias = $store.uuidIndex.PSObject.Properties[$accountUuid]
    if ($existingAlias) { return }

    [void](Save-OAuthAccountProfile -Source "auto" -Quiet)
}

function Get-PresetSearchDirs {
    $dirs = New-Object System.Collections.ArrayList

    if (Test-Path $presetsDir) {
        [void]$dirs.Add((Resolve-Path $presetsDir).Path)
    }

    $nestedPresetsDir = Join-Path $presetsDir "presets"
    if (Test-Path $nestedPresetsDir) {
        $resolvedNested = (Resolve-Path $nestedPresetsDir).Path
        if (-not ($dirs -contains $resolvedNested)) {
            [void]$dirs.Add($resolvedNested)
        }
    }

    return @($dirs)
}

function Get-PresetFiles {
    $seen = @{}
    $files = @()

    foreach ($dir in (Get-PresetSearchDirs)) {
        Get-ChildItem $dir -Filter "*.json" -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -ne "oauth-backup.json" } |
            Sort-Object Name |
            ForEach-Object {
                $key = $_.BaseName.ToLowerInvariant()
                if (-not $seen.ContainsKey($key)) {
                    $seen[$key] = $true
                    $files += $_
                }
            }
    }

    return $files
}

function Resolve-PresetFilePath {
    param([string]$Name)

    if (-not $Name) { return $null }
    $target = $Name.ToLowerInvariant()

    foreach ($file in (Get-PresetFiles)) {
        if ($file.BaseName.ToLowerInvariant() -eq $target) {
            return $file.FullName
        }
    }

    return $null
}

function Get-PresetEnvVarNames {
    $names = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    foreach ($name in $claudeEnvVars) {
        [void]$names.Add($name)
    }

    Get-PresetFiles | ForEach-Object {
        try {
            $preset = Get-Content $_.FullName -Raw | ConvertFrom-Json
            if ($preset -and $preset.env) {
                foreach ($prop in $preset.env.PSObject.Properties) {
                    if ($prop.Name) {
                        [void]$names.Add($prop.Name)
                    }
                }
            }
        }
        catch {
            # Ignore malformed preset files during cleanup discovery.
        }
    }

    return @($names)
}

function Clear-ClaudeEnvVars {
    param([string[]]$Keep = @())

    $keepSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($name in $Keep) {
        if ($name) {
            [void]$keepSet.Add($name)
        }
    }

    foreach ($varName in (Get-PresetEnvVarNames)) {
        if ($keepSet.Contains($varName)) { continue }
        # Limpa User por compatibilidade com versões antigas que persistiam no registro.
        # Novas execuções passam a usar só o escopo Process (sessão atual).
        [Environment]::SetEnvironmentVariable($varName, $null, "User")
        [Environment]::SetEnvironmentVariable($varName, $null, "Process")
    }
}

function Get-ActivePreset {
    $active = "anthropic"

    if (Test-Path $activePresetFile) {
        $readValue = (Get-Content $activePresetFile -Raw).Trim()
        if ($readValue) {
            $active = $readValue
        }
    }

    if ($active -eq "anthropic") {
        return $active
    }

    # .active-preset é persistente entre terminais, mas env vars não (modo sessão).
    # Se não há env de preset no processo atual, normaliza para anthropic.
    $hasPresetEnvInSession = $false
    foreach ($varName in (Get-PresetEnvVarNames)) {
        $value = [Environment]::GetEnvironmentVariable($varName, "Process")
        if ($value) {
            $hasPresetEnvInSession = $true
            break
        }
    }

    if (-not $hasPresetEnvInSession) {
        Set-ActivePreset "anthropic"
        return "anthropic"
    }

    return $active
}

function Set-ActivePreset {
    param([string]$Name)
    $Name | Set-Content $activePresetFile -Encoding utf8NoBOM -NoNewline
}

function Reset-ClaudeSessionState {
    param([switch]$Quiet)

    Clear-ClaudeEnvVars
    Set-ActivePreset "anthropic"

    if (-not $Quiet) {
        Write-Host "  ✅ Sessão limpa. Variáveis removidas e OAuth Anthropic restaurado." -ForegroundColor Green
    }
}

function Apply-Preset {
    param([string]$Name)

    if ($Name -eq "anthropic") {
        Reset-ClaudeSessionState -Quiet
        return $null
    }

    $presetFile = Resolve-PresetFilePath -Name $Name
    if (-not $presetFile) { return $false }

    $preset = Get-Content $presetFile -Raw | ConvertFrom-Json

    $keepEnvVars = @()
    if ($preset.env) {
        $keepEnvVars = @($preset.env.PSObject.Properties | ForEach-Object { $_.Name } | Where-Object { $_ })
    }

    # Prevent stale variables from previous presets leaking into the next one.
    Clear-ClaudeEnvVars -Keep $keepEnvVars

    if ($preset.env) {
        foreach ($prop in $preset.env.PSObject.Properties) {
            # Preset por sessão: não persistir em User para não vazar para novos terminais.
            [Environment]::SetEnvironmentVariable($prop.Name, $prop.Value, "Process")
        }
    }

    # Auto-start CCR se o preset usar localhost:3000
    if ($preset.env.ANTHROPIC_BASE_URL -match "127.0.0.1:3000|localhost:3000") {
        if (Test-Path "$env:USERPROFILE\.claude-code-router") {
            $routerJobName = "claude-router"
            if (-not (Get-Job -Name $routerJobName -ErrorAction SilentlyContinue)) {
                Write-Host "  🔄 Iniciando Claude Code Router..." -ForegroundColor Cyan
                Start-Job -ScriptBlock { ccr start --no-claude } -Name $routerJobName | Out-Null
                Add-ManagedJobName -JobName $routerJobName
                Start-Sleep -Seconds 2 # Aguarda init
            }
        }
    }

    Set-ActivePreset $Name
    return $preset
}

function Prompt-LaunchClaude {
    param([string]$LaunchedPreset = "anthropic")

    Write-Host ""
    Write-Host "  > Iniciar Claude Code agora? " -ForegroundColor Green -NoNewline
    Write-Host "[Enter = Sim / Q = Não]" -ForegroundColor DarkGray

    $key = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    if ($key.VirtualKeyCode -eq 13) {
        Write-Host ""
        Show-Separator
        Write-Host ""
        Invoke-ClaudeWithManagedCleanup -LaunchedPreset $LaunchedPreset
    }
    else {
        Write-Host ""
        Write-Host "  💡 Rode " -ForegroundColor DarkGray -NoNewline
        Write-Host "claude" -ForegroundColor Green -NoNewline
        Write-Host " neste terminal quando quiser." -ForegroundColor DarkGray
        if ($LaunchedPreset -and $LaunchedPreset -ne "anthropic") {
            Write-Host ""
            Write-Host "  💡 Para limpar a sessão sem abrir o Claude: " -ForegroundColor DarkGray -NoNewline
            Write-Host "cmodel clean" -ForegroundColor Green
        }
        Write-Host ""
    }
}

function Test-TcpEndpoint {
    param(
        [string]$HostName,
        [int]$Port,
        [int]$TimeoutMs = 1200
    )

    try {
        $client = [System.Net.Sockets.TcpClient]::new()
        $async = $client.BeginConnect($HostName, $Port, $null, $null)
        if (-not $async.AsyncWaitHandle.WaitOne($TimeoutMs, $false)) {
            $client.Close()
            return $false
        }

        $client.EndConnect($async) | Out-Null
        $client.Close()
        return $true
    }
    catch {
        return $false
    }
}

function Test-LocalBaseUrlReachable {
    param([string]$BaseUrl)

    $result = [PSCustomObject]@{
        Checked   = $false
        Reachable = $false
        Host      = $null
        Port      = $null
    }

    if (-not $BaseUrl) { return $result }

    $uri = $null
    if (-not [System.Uri]::TryCreate($BaseUrl, [System.UriKind]::Absolute, [ref]$uri)) {
        return $result
    }

    $hostName = $uri.Host
    $isLocal = $uri.IsLoopback -or $hostName -eq "localhost" -or $hostName -eq "127.0.0.1" -or $hostName -eq "::1"
    if (-not $isLocal) {
        return $result
    }

    $port = $uri.Port
    if ($port -le 0) {
        $port = if ($uri.Scheme -eq "https") { 443 } else { 80 }
    }

    $result.Checked = $true
    $result.Host = $hostName
    $result.Port = $port
    $result.Reachable = Test-TcpEndpoint -HostName $hostName -Port $port

    return $result
}

function Find-CLIProxyApiCommand {
    $candidates = @("cli-proxy-api", "CLIProxyAPI", "CLIProxyAPI.exe", "cli-proxy-api.exe")

    foreach ($candidate in $candidates) {
        $cmd = Get-Command $candidate -ErrorAction SilentlyContinue
        if ($cmd -and $cmd.Source) {
            return [PSCustomObject]@{
                Name = $candidate
                Path = $cmd.Source
            }
        }
    }

    $localCandidates = @(
        (Join-Path $PSScriptRoot "CLIProxyAPI.exe"),
        (Join-Path $env:USERPROFILE "CLIProxyAPI.exe"),
        (Join-Path $env:USERPROFILE "Downloads\CLIProxyAPI.exe")
    )

    foreach ($path in $localCandidates) {
        if (Test-Path $path) {
            return [PSCustomObject]@{
                Name = [System.IO.Path]::GetFileNameWithoutExtension($path)
                Path = (Resolve-Path $path).Path
            }
        }
    }

    return $null
}

function Ensure-CLIProxyApiForBaseUrl {
    param([string]$BaseUrl)

    $status = [PSCustomObject]@{
        Checked = $false
        AttemptedStart = $false
        Started = $false
        StartedProcessId = $null
        Reachable = $false
        EndpointHost = $null
        EndpointPort = $null
        LaunchPath = $null
        Error = $null
        CommandNotFound = $false
    }

    $endpoint = Test-LocalBaseUrlReachable -BaseUrl $BaseUrl
    if (-not $endpoint.Checked) {
        return $status
    }

    $status.Checked = $true
    $status.EndpointHost = $endpoint.Host
    $status.EndpointPort = $endpoint.Port
    $status.Reachable = $endpoint.Reachable

    if ($status.Reachable) {
        return $status
    }

    if ($status.EndpointPort -ne 8317) {
        return $status
    }

    $command = Find-CLIProxyApiCommand
    if (-not $command) {
        $status.CommandNotFound = $true
        return $status
    }

    $status.AttemptedStart = $true
    $status.LaunchPath = $command.Path

    try {
        $proc = Start-Process -FilePath $command.Path -WindowStyle Hidden -PassThru
        if ($proc -and $proc.Id) {
            $status.StartedProcessId = [int]$proc.Id
            Add-ManagedProcessId -ProcessId ([int]$proc.Id)
        }
        $status.Started = $true
    }
    catch {
        $status.Error = $_.Exception.Message
        return $status
    }

    $maxChecks = 6
    for ($i = 0; $i -lt $maxChecks; $i++) {
        Start-Sleep -Milliseconds 500
        $retry = Test-LocalBaseUrlReachable -BaseUrl $BaseUrl
        if ($retry.Checked -and $retry.Reachable) {
            $status.Reachable = $true
            break
        }
    }

    return $status
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

    Get-PresetFiles | ForEach-Object {
        $p = Get-Content $_.FullName -Raw | ConvertFrom-Json
        $name = $_.BaseName
        $desc = $p._preset.description
        $marker = if ($active -eq $name) { " ◀ ativo" } else { "" }
        Write-Host "    $name" -ForegroundColor Yellow -NoNewline
        Write-Host " - $desc" -ForegroundColor Gray -NoNewline
        Write-Host $marker -ForegroundColor Green
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

    Get-PresetFiles | ForEach-Object {
        $p = Get-Content $_.FullName -Raw | ConvertFrom-Json
        $presets += [PSCustomObject]@{ Name = $_.BaseName; Description = $p._preset.description }
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

Auto-CaptureCurrentOAuthAccount

if ($PresetName -eq "account") {
    Handle-OAuthAccountCommand -CommandArgs $extraArgs
    return
}

if ($PresetName) {
    $presetKeyword = $PresetName.ToLowerInvariant()
    if (@("clean", "cleanup", "clear", "reset") -contains $presetKeyword) {
        if (-not $Silent) { Show-Banner }
        Reset-ClaudeSessionState -Quiet:$Silent
        if (-not $Silent) {
            Write-Host ""
            Show-Separator
            Write-Host ""
        }
        return
    }
}

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
        Write-Host "  > Usando Anthropic OAuth" -ForegroundColor Gray
        $currentOauth = Get-CurrentOAuthAccount
        if ($currentOauth) {
            $alias = Get-SavedAliasForAccountUuid -AccountUuid ([string]$currentOauth.accountUuid)
            Write-Host "  👤 Conta:   $($currentOauth.displayName) <$($currentOauth.emailAddress)>" -ForegroundColor Gray
            if ($alias) {
                Write-Host "  🏷️ Alias:   $alias" -ForegroundColor Green
            }
        }
        else {
            Write-Host "  ⚠️  Sem conta OAuth ativa no settings." -ForegroundColor Yellow
        }
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

# Anthropic com alias de conta salvo: cmodel anthropic <conta>
$selectedAccountAlias = $null
if ($PresetName -eq "anthropic" -and $extraArgs -and $extraArgs.Count -gt 0) {
    $selectedAccountAlias = $extraArgs[0]
    if (-not (Use-SavedOAuthAccount -Alias $selectedAccountAlias -Quiet:$Silent)) {
        return
    }
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

        $currentOauth = Get-CurrentOAuthAccount
        if ($currentOauth) {
            $alias = Get-SavedAliasForAccountUuid -AccountUuid ([string]$currentOauth.accountUuid)
            Write-Host "  👤 Conta:   $($currentOauth.displayName) <$($currentOauth.emailAddress)>" -ForegroundColor Gray
            if ($alias) {
                Write-Host "  🏷️ Alias:   $alias" -ForegroundColor Green
            }
        }
        else {
            Write-Host "  ⚠️  Sem conta OAuth ativa no settings." -ForegroundColor Yellow
            Write-Host "  💡 Rode: claude login" -ForegroundColor DarkGray
        }

        Write-Host "  🧹 Env vars limpos da sessão" -ForegroundColor DarkGray
        Write-Host ""
        Show-Separator
        Prompt-LaunchClaude -LaunchedPreset "anthropic"
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

$endpoint = Test-LocalBaseUrlReachable -BaseUrl $env:ANTHROPIC_BASE_URL
if ($endpoint.Checked -and -not $endpoint.Reachable) {
    Write-Host "  ⚠️  Endpoint local indisponível em $($endpoint.Host):$($endpoint.Port) (ConnectionRefused)" -ForegroundColor Yellow
    if ($endpoint.Port -eq 8317) {
        $proxyStatus = Ensure-CLIProxyApiForBaseUrl -BaseUrl $env:ANTHROPIC_BASE_URL

        if ($proxyStatus.Started -and $proxyStatus.Reachable) {
            Write-Host "  ✅ CLIProxyAPI iniciado automaticamente para $($proxyStatus.EndpointHost):$($proxyStatus.EndpointPort)" -ForegroundColor Green
        }
        else {
            if ($proxyStatus.AttemptedStart -and $proxyStatus.Error) {
                Write-Host "  ⚠️  Falha ao iniciar CLIProxyAPI automaticamente: $($proxyStatus.Error)" -ForegroundColor Yellow
            }
            elseif ($proxyStatus.CommandNotFound) {
                Write-Host "  ⚠️  CLIProxyAPI não encontrado no PATH." -ForegroundColor Yellow
            }

            Write-Host "  💡 Inicie o CLIProxyAPI antes de abrir o Claude Code (OAuth Codex)." -ForegroundColor DarkGray
            Write-Host "     Exemplo: CLIProxyAPI.exe --codex-login (uma vez) / CLIProxyAPI.exe (subir proxy)" -ForegroundColor DarkGray
        }
    }
}

Write-Host ""
Show-Separator
Prompt-LaunchClaude -LaunchedPreset $PresetName
