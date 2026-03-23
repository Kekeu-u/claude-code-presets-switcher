# ╔══════════════════════════════════════════╗
# ║  cmodel - Claude Code Preset Switcher    ║
# ║  by kekeu 🐉                             ║
# ╚══════════════════════════════════════════╝
#
# Uso: cmodel                         (menu interativo — padrao = Isolado)
#       cmodel kimi                   (aplica isolado no terminal + abre Claude)
#       cmodel kimi -ApplyOnly        (aplica preset isolado, NAO abre Claude)
#       cmodel kimi -SetDefault       (aplica + persiste como padrao do VS Code Claude)
#       cmodel kimi -SetDefault -ApplyOnly
#                                      (so persiste padrao, sem abrir)
#       cmodel anthropic              (limpa sessao, volta ao OAuth padrao)
#       cmodel anthropic -SetDefault  (limpa provider padrao persistido)
#       cmodel -List                  (lista presets)
#       cmodel -Status                (mostra sessao e padrao persistido)

param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$CliArgs
)

$PresetName = $null
$List = $false
$Status = $false
$ApplyOnly = $false
$SetDefault = $false
$ClaudeArgs = @()
$forwardClaudeArgs = $false
$selectedFromMenu = $false

foreach ($arg in $CliArgs) {
    if ($forwardClaudeArgs) {
        $ClaudeArgs += $arg
        continue
    }

    switch -Regex ($arg) {
        '^--$' { $forwardClaudeArgs = $true; continue }
        '^(-List|--list)$' { $List = $true; continue }
        '^(-Status|--status)$' { $Status = $true; continue }
        '^(-ApplyOnly|--apply-only|-NoLaunch|--no-launch)$' { $ApplyOnly = $true; continue }
        '^(-SetDefault|--set-default|-Default|--default)$' { $SetDefault = $true; continue }
        default {
            if (-not $PresetName) {
                $PresetName = $arg
            }
            else {
                $ClaudeArgs += $arg
            }
        }
    }
}

$presetsDir = Join-Path $env:USERPROFILE ".claude\presets"
$settingsJsonPath = Join-Path $env:USERPROFILE ".claude\settings.json"
$settingsLocalJsonPath = Join-Path $env:USERPROFILE ".claude\settings.local.json"
$legacyStateFiles = @(
    (Join-Path $presetsDir ".active-preset"),
    (Join-Path $presetsDir "oauth-accounts.json"),
    (Join-Path $presetsDir "oauth-backup.json")
)
$claudeEnvVars = @(
    "ANTHROPIC_BASE_URL",
    "ANTHROPIC_API_KEY",
    "ANTHROPIC_AUTH_TOKEN",
    "ANTHROPIC_MODEL",
    "ANTHROPIC_DEFAULT_SONNET_MODEL",
    "ANTHROPIC_DEFAULT_OPUS_MODEL",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL",
    "ANTHROPIC_SMALL_FAST_MODEL",
    "API_TIMEOUT_MS",
    "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC"
)
$managedSettingsRootKeys = @(
    "apiBaseUrl"
)
$modelSlotEnvVars = @(
    "ANTHROPIC_DEFAULT_SONNET_MODEL",
    "ANTHROPIC_DEFAULT_OPUS_MODEL",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL",
    "ANTHROPIC_SMALL_FAST_MODEL"
)

function New-JsonObject {
    return [PSCustomObject]@{}
}

function Get-ObjectPropertyValue {
    param(
        [AllowNull()]$Object,
        [string]$Name
    )

    if ($null -eq $Object) { return $null }

    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) { return $null }

    return $property.Value
}

function Set-ObjectProperty {
    param(
        [Parameter(Mandatory = $true)]$Object,
        [string]$Name,
        [AllowNull()]$Value
    )

    $property = $Object.PSObject.Properties[$Name]
    if ($property) {
        $property.Value = $Value
        return
    }

    $Object | Add-Member -NotePropertyName $Name -NotePropertyValue $Value
}

function Remove-ObjectProperty {
    param(
        [AllowNull()]$Object,
        [string]$Name
    )

    if ($null -eq $Object) { return }

    $property = $Object.PSObject.Properties[$Name]
    if ($property) {
        $Object.PSObject.Properties.Remove($Name)
    }
}

function Get-ObjectPropertyNames {
    param([AllowNull()]$Object)

    if ($null -eq $Object) { return @() }

    return @($Object.PSObject.Properties.Name)
}

function Get-JsonConfigObject {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        return (New-JsonObject)
    }

    try {
        $rawContent = Get-Content $Path -Raw -ErrorAction Stop
    }
    catch {
        throw "Could not read '$Path': $($_.Exception.Message)"
    }

    if ([string]::IsNullOrWhiteSpace($rawContent)) {
        return (New-JsonObject)
    }

    try {
        $config = $rawContent | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        throw "Could not parse '$Path': $($_.Exception.Message)"
    }

    if ($null -eq $config) {
        return (New-JsonObject)
    }

    if ($config -isnot [pscustomobject]) {
        throw "'$Path' must contain a JSON object at the root."
    }

    return $config
}

function Save-JsonConfigObject {
    param(
        [string]$Path,
        [Parameter(Mandatory = $true)]$Object
    )

    $propertyNames = @(Get-ObjectPropertyNames -Object $Object)
    if (-not $propertyNames.Count) {
        if (Test-Path $Path) {
            Remove-Item $Path -Force -ErrorAction SilentlyContinue
        }
        return
    }

    $parentDir = Split-Path $Path -Parent
    if (-not (Test-Path $parentDir)) {
        New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
    }

    $json = $Object | ConvertTo-Json -Depth 20
    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($Path, "$json`n", $utf8NoBom)
}

function Get-OrCreate-EnvObject {
    param(
        [Parameter(Mandatory = $true)]$Settings,
        [switch]$CreateWhenMissing
    )

    $envObject = Get-ObjectPropertyValue -Object $Settings -Name "env"
    if ($null -eq $envObject) {
        if (-not $CreateWhenMissing) { return $null }

        $envObject = New-JsonObject
        Set-ObjectProperty -Object $Settings -Name "env" -Value $envObject
        return $envObject
    }

    if ($envObject -is [System.Collections.IDictionary]) {
        $convertedEnv = New-JsonObject
        foreach ($key in $envObject.Keys) {
            Set-ObjectProperty -Object $convertedEnv -Name ([string]$key) -Value $envObject[$key]
        }
        Set-ObjectProperty -Object $Settings -Name "env" -Value $convertedEnv
        return $convertedEnv
    }

    if ($envObject -isnot [pscustomobject]) {
        throw "'env' in '$settingsLocalJsonPath' must be a JSON object."
    }

    return $envObject
}

function Get-PresetFiles {
    if (-not (Test-Path $presetsDir)) { return @() }

    Get-ChildItem $presetsDir -Filter "*.json" -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -ne "oauth-accounts.json" -and $_.Name -ne "oauth-backup.json" } |
        Sort-Object Name
}

function Read-PresetFile {
    param([string]$Path)

    try {
        return (Get-Content $Path -Raw | ConvertFrom-Json)
    }
    catch {
        return $null
    }
}

function Get-ProcessEnvVar {
    param([string]$Name)
    [Environment]::GetEnvironmentVariable($Name, "Process")
}

function Resolve-PresetEnvValue {
    param([AllowNull()]$Value)

    if ($null -eq $Value) { return $null }

    if ($Value -isnot [string]) {
        return $Value
    }

    $text = [string]$Value
    if ([string]::IsNullOrWhiteSpace($text)) { return $null }

    if ($text -match '^(?:env:|\$env:)([A-Za-z_][A-Za-z0-9_]*)$' -or $text -match '^\$\{([A-Za-z_][A-Za-z0-9_]*)\}$') {
        $envName = $Matches[1]
        foreach ($scope in @("Process", "User", "Machine")) {
            $resolvedValue = [Environment]::GetEnvironmentVariable($envName, $scope)
            if (-not [string]::IsNullOrWhiteSpace($resolvedValue)) {
                return [string]$resolvedValue
            }
        }

        throw "Environment variable '$envName' was not found for preset resolution."
    }

    return $text
}

function Clear-ClaudeEnvVars {
    foreach ($varName in $claudeEnvVars) {
        [Environment]::SetEnvironmentVariable($varName, $null, "Process")
    }
}

function Restore-ClaudeEnvVars {
    param([System.Collections.IDictionary]$ManagedEnv)

    Clear-ClaudeEnvVars

    foreach ($key in $ManagedEnv.Keys) {
        [Environment]::SetEnvironmentVariable($key, [string]$ManagedEnv[$key], "Process")
    }
}

function Remove-LegacyStateFiles {
    foreach ($path in $legacyStateFiles) {
        if (Test-Path $path) {
            Remove-Item $path -Force -ErrorAction SilentlyContinue
        }
    }
}

function Get-SettingsLeakKeys {
    if (-not (Test-Path $settingsJsonPath)) { return @() }

    $settings = $null
    try {
        $settings = Get-Content $settingsJsonPath -Raw | ConvertFrom-Json
    }
    catch {
        return @()
    }

    $leakKeys = @()
    foreach ($rootKey in $managedSettingsRootKeys) {
        if ($settings.PSObject.Properties[$rootKey]) {
            $leakKeys += $rootKey
        }
    }

    if ($settings.env) {
        foreach ($prop in $settings.env.PSObject.Properties) {
            if ($prop.Name -like "ANTHROPIC_*") {
                $leakKeys += $prop.Name
            }
        }
    }

    return $leakKeys
}

function Get-NormalizedPresetEnv {
    param([object]$Preset)

    $normalized = [ordered]@{}
    if (-not $Preset -or -not $Preset.env) { return $normalized }

    foreach ($prop in $Preset.env.PSObject.Properties) {
        if ($null -eq $prop.Value) { continue }

        $valueText = Resolve-PresetEnvValue -Value $prop.Value
        if ([string]::IsNullOrWhiteSpace($valueText)) { continue }

        $normalized[$prop.Name] = $valueText
    }

    $mainModel = $null
    if ($normalized.Contains("ANTHROPIC_MODEL")) {
        $mainModel = [string]$normalized["ANTHROPIC_MODEL"]
    }

    if (-not [string]::IsNullOrWhiteSpace($mainModel)) {
        foreach ($slotName in $modelSlotEnvVars) {
            if (-not $normalized.Contains($slotName)) {
                $normalized[$slotName] = $mainModel
            }
        }
    }

    return $normalized
}

function Get-PresetDefinition {
    param([string]$Name)

    if ($Name -ieq "anthropic") {
        return [PSCustomObject]@{
            Name = "anthropic"
            DisplayName = "anthropic (OAuth padrao)"
            Description = "Claude oficial (OAuth limpo)"
            NormalizedEnv = [ordered]@{}
            BaseUrl = $null
            Model = $null
        }
    }

    $presetFile = Get-PresetFiles | Where-Object { $_.BaseName -ieq $Name } | Select-Object -First 1
    if (-not $presetFile) { return $null }

    $preset = Read-PresetFile -Path $presetFile.FullName
    if (-not $preset) { return $null }

    $normalizedEnv = Get-NormalizedPresetEnv -Preset $preset
    $displayName = $presetFile.BaseName
    $description = ""

    if ($preset._preset -and $preset._preset.name) {
        $displayName = "$($presetFile.BaseName) ($($preset._preset.name))"
    }

    if ($preset._preset -and $preset._preset.description) {
        $description = [string]$preset._preset.description
    }

    return [PSCustomObject]@{
        Name = $presetFile.BaseName
        DisplayName = $displayName
        Description = $description
        NormalizedEnv = $normalizedEnv
        BaseUrl = $(if ($normalizedEnv.Contains("ANTHROPIC_BASE_URL")) { [string]$normalizedEnv["ANTHROPIC_BASE_URL"] } else { $null })
        Model = $(if ($normalizedEnv.Contains("ANTHROPIC_MODEL")) { [string]$normalizedEnv["ANTHROPIC_MODEL"] } else { $null })
    }
}

function Get-CurrentSessionManagedEnv {
    $managedEnv = [ordered]@{}

    foreach ($varName in $claudeEnvVars) {
        $value = [string](Get-ProcessEnvVar -Name $varName)
        if (-not [string]::IsNullOrWhiteSpace($value)) {
            $managedEnv[$varName] = $value
        }
    }

    return $managedEnv
}

function Get-ManagedEnvFromSettingsLocal {
    $settings = Get-JsonConfigObject -Path $settingsLocalJsonPath
    $envObject = Get-OrCreate-EnvObject -Settings $settings
    $managedEnv = [ordered]@{}

    if ($null -eq $envObject) { return $managedEnv }

    foreach ($varName in $claudeEnvVars) {
        $value = Get-ObjectPropertyValue -Object $envObject -Name $varName
        $valueText = [string]$value
        if (-not [string]::IsNullOrWhiteSpace($valueText)) {
            $managedEnv[$varName] = $valueText
        }
    }

    return $managedEnv
}

function Test-NormalizedEnvMatchesMap {
    param(
        [System.Collections.IDictionary]$ExpectedEnv,
        [System.Collections.IDictionary]$ActualEnv
    )

    if ($ExpectedEnv.Count -ne $ActualEnv.Count) {
        return $false
    }

    foreach ($key in $ExpectedEnv.Keys) {
        if (-not $ActualEnv.Contains($key)) {
            return $false
        }

        if ([string]$ExpectedEnv[$key] -ne [string]$ActualEnv[$key]) {
            return $false
        }
    }

    return $true
}

function Get-ActiveSessionPreset {
    $currentEnv = Get-CurrentSessionManagedEnv
    if (-not $currentEnv.Count) {
        return "anthropic"
    }

    foreach ($file in (Get-PresetFiles)) {
        $preset = Read-PresetFile -Path $file.FullName
        if (-not $preset) { continue }

        try {
            $normalizedEnv = Get-NormalizedPresetEnv -Preset $preset
        }
        catch {
            continue
        }

        if (Test-NormalizedEnvMatchesMap -ExpectedEnv $normalizedEnv -ActualEnv $currentEnv) {
            return $file.BaseName
        }
    }

    return "custom-session"
}

function Get-DefaultPreset {
    $persistedEnv = Get-ManagedEnvFromSettingsLocal
    if (-not $persistedEnv.Count) {
        return "anthropic"
    }

    foreach ($file in (Get-PresetFiles)) {
        $preset = Read-PresetFile -Path $file.FullName
        if (-not $preset) { continue }

        try {
            $normalizedEnv = Get-NormalizedPresetEnv -Preset $preset
        }
        catch {
            continue
        }

        if (Test-NormalizedEnvMatchesMap -ExpectedEnv $normalizedEnv -ActualEnv $persistedEnv) {
            return $file.BaseName
        }
    }

    return "custom-default"
}

function Set-DefaultPresetEnv {
    param([System.Collections.IDictionary]$NormalizedEnv)

    $settings = Get-JsonConfigObject -Path $settingsLocalJsonPath
    $envObject = Get-OrCreate-EnvObject -Settings $settings -CreateWhenMissing

    foreach ($rootKey in $managedSettingsRootKeys) {
        Remove-ObjectProperty -Object $settings -Name $rootKey
    }

    foreach ($varName in $claudeEnvVars) {
        Remove-ObjectProperty -Object $envObject -Name $varName
    }

    foreach ($key in $NormalizedEnv.Keys) {
        Set-ObjectProperty -Object $envObject -Name $key -Value $NormalizedEnv[$key]
    }

    if (-not (Get-ObjectPropertyNames -Object $envObject).Count) {
        Remove-ObjectProperty -Object $settings -Name "env"
    }

    Save-JsonConfigObject -Path $settingsLocalJsonPath -Object $settings
}

function Get-PresetOptions {
    $sessionPreset = Get-ActiveSessionPreset
    $defaultPreset = Get-DefaultPreset
    $options = @(
        [PSCustomObject]@{
            Name = "anthropic"
            Description = "Claude oficial (OAuth limpo)"
            IsSessionActive = ($sessionPreset -eq "anthropic")
            IsDefaultActive = ($defaultPreset -eq "anthropic")
        }
    )

    foreach ($file in (Get-PresetFiles)) {
        $preset = Read-PresetFile -Path $file.FullName
        $description = ""
        if ($preset -and $preset._preset -and $preset._preset.description) {
            $description = [string]$preset._preset.description
        }

        $options += [PSCustomObject]@{
            Name = $file.BaseName
            Description = $description
            IsSessionActive = ($sessionPreset -eq $file.BaseName)
            IsDefaultActive = ($defaultPreset -eq $file.BaseName)
        }
    }

    return $options
}

function Show-SettingsLeakWarning {
    $leakKeys = @(Get-SettingsLeakKeys)
    if (-not $leakKeys.Count) { return }

    Write-Host ""
    Write-Host "  [WARN] ~/.claude/settings.json ainda injeta provider global:" -ForegroundColor Yellow
    Write-Host ("         " + ($leakKeys -join ", ")) -ForegroundColor DarkYellow
    Write-Host "         Isso pode misturar provider/modelo fora do preset." -ForegroundColor DarkGray
}

function Get-PresetMarkerText {
    param($Option)

    $markers = @()
    if ($Option.IsSessionActive) { $markers += "session" }
    if ($Option.IsDefaultActive) { $markers += "default" }

    if (-not $markers.Count) { return "" }

    return " [" + ($markers -join ", ") + "]"
}

function Show-PresetMenu {
    $options = @(Get-PresetOptions)
    if (-not $options.Count) {
        Write-Host ""
        Write-Host "  [X] Nenhum preset encontrado em $presetsDir" -ForegroundColor Red
        Write-Host ""
        return $null
    }

    $selectedIndex = 0
    for ($i = 0; $i -lt $options.Count; $i++) {
        if ($options[$i].IsSessionActive) {
            $selectedIndex = $i
            break
        }

        if ($options[$i].IsDefaultActive) {
            $selectedIndex = $i
        }
    }

    while ($true) {
        Clear-Host
        Write-Host ""
        Write-Host "  cmodel" -ForegroundColor Green -NoNewline
        Write-Host " - escolha um preset" -ForegroundColor Gray
        Write-Host "  Use Up/Down, Enter para escolher e Q/Esc para sair." -ForegroundColor DarkGray
        Show-SettingsLeakWarning
        Write-Host ""

        for ($i = 0; $i -lt $options.Count; $i++) {
            $option = $options[$i]
            $prefix = if ($i -eq $selectedIndex) { "  >" } else { "   " }
            $nameColor = if ($i -eq $selectedIndex) { "Green" } elseif ($option.IsSessionActive -or $option.IsDefaultActive) { "Yellow" } else { "White" }
            $markerText = Get-PresetMarkerText -Option $option
            $description = if ([string]::IsNullOrWhiteSpace($option.Description)) { "" } else { " - $($option.Description)" }

            Write-Host $prefix -NoNewline -ForegroundColor DarkGray
            Write-Host " $($option.Name)" -NoNewline -ForegroundColor $nameColor
            Write-Host $markerText -NoNewline -ForegroundColor DarkYellow
            Write-Host $description -ForegroundColor Gray
        }

        $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        switch ($key.VirtualKeyCode) {
            38 {
                if ($selectedIndex -gt 0) {
                    $selectedIndex -= 1
                }
            }
            40 {
                if ($selectedIndex -lt ($options.Count - 1)) {
                    $selectedIndex += 1
                }
            }
            13 { return $options[$selectedIndex].Name }
            27 { return $null }
            81 { return $null }
        }
    }
}

function Show-SessionConflictWarning {
    param(
        [string]$CurrentPreset,
        [string]$NewPreset
    )

    Write-Host ""
    Write-Host "  [WARN] Ja existe sessao ativa: '$CurrentPreset'" -ForegroundColor Yellow
    Write-Host "         Trocando para '$NewPreset' nesta sessao." -ForegroundColor DarkGray
    Write-Host ""
}

function Show-ModeMenu {
    param(
        [string]$SelectedPreset,
        [string]$ActiveSessionPreset
    )

    if ($ActiveSessionPreset -and $ActiveSessionPreset -ne "anthropic" -and $ActiveSessionPreset -ne "custom-session") {
        Show-SessionConflictWarning -CurrentPreset $ActiveSessionPreset -NewPreset $SelectedPreset
    }

    while ($true) {
        Write-Host ""
        Write-Host "  Como voce quer abrir '$SelectedPreset'?" -ForegroundColor Cyan
        Write-Host "    [1] Isolado (so este terminal)         <-- padrao" -ForegroundColor Gray
        Write-Host "    [2] Definir como padrao do VS Code Claude" -ForegroundColor Gray
        Write-Host "    [3] Salvar padrao sem abrir Claude" -ForegroundColor Gray
        Write-Host "    [Q] Cancelar" -ForegroundColor DarkGray
        Write-Host ""

        $choice = Read-Host "  Escolha (1)"
        if ([string]::IsNullOrWhiteSpace($choice)) { $choice = "1" }
        switch ($choice.Trim().ToUpperInvariant()) {
            "1" {
                return [PSCustomObject]@{
                    SetDefault = $false
                    ApplyOnly = $false
                }
            }
            "2" {
                return [PSCustomObject]@{
                    SetDefault = $true
                    ApplyOnly = $false
                }
            }
            "3" {
                return [PSCustomObject]@{
                    SetDefault = $true
                    ApplyOnly = $true
                }
            }
            "Q" { return $null }
            default {
                Write-Host ""
                Write-Host "  [X] Opcao invalida." -ForegroundColor Red
            }
        }
    }
}

function Apply-Preset {
    param(
        [string]$Name,
        [switch]$PersistDefault,
        [switch]$ApplyToCurrentSession
    )

    Remove-LegacyStateFiles

    $presetDefinition = $null
    try {
        $presetDefinition = Get-PresetDefinition -Name $Name
    }
    catch {
        Write-Host ""
        Write-Host "  [X] $($_.Exception.Message)" -ForegroundColor Red
        Write-Host ""
        return $null
    }

    if (-not $presetDefinition) { return $null }

    if ($PersistDefault) {
        try {
            Set-DefaultPresetEnv -NormalizedEnv $presetDefinition.NormalizedEnv
        }
        catch {
            Write-Host ""
            Write-Host "  [X] $($_.Exception.Message)" -ForegroundColor Red
            Write-Host ""
            return $null
        }
    }
    elseif ($ApplyToCurrentSession) {
        Clear-ClaudeEnvVars

        foreach ($key in $presetDefinition.NormalizedEnv.Keys) {
            [Environment]::SetEnvironmentVariable($key, [string]$presetDefinition.NormalizedEnv[$key], "Process")
        }
    }

    return [PSCustomObject]@{
        Name = $presetDefinition.Name
        DisplayName = $presetDefinition.DisplayName
        Description = $presetDefinition.Description
        BaseUrl = $presetDefinition.BaseUrl
        Model = $presetDefinition.Model
        NormalizedEnv = $presetDefinition.NormalizedEnv
        Persisted = [bool]$PersistDefault
        SessionApplied = [bool]$ApplyToCurrentSession
    }
}

function Invoke-ClaudeSession {
    param(
        [string[]]$Arguments,
        [System.Collections.IDictionary]$NormalizedEnv
    )

    $claudeCommand = Get-Command "claude" -ErrorAction SilentlyContinue
    if (-not $claudeCommand) {
        Write-Host ""
        Write-Host "  [X] Comando 'claude' nao encontrado no PATH." -ForegroundColor Red
        Write-Host ""
        return 127
    }

    Write-Host ""
    Write-Host "  [OK] Abrindo Claude Code..." -ForegroundColor Green
    Write-Host ""

    $originalManagedEnv = Get-CurrentSessionManagedEnv
    try {
        Clear-ClaudeEnvVars

        foreach ($key in $NormalizedEnv.Keys) {
            [Environment]::SetEnvironmentVariable($key, [string]$NormalizedEnv[$key], "Process")
        }

        & $claudeCommand.Source @Arguments
    }
    finally {
        Restore-ClaudeEnvVars -ManagedEnv $originalManagedEnv
    }

    if ($null -eq $LASTEXITCODE) {
        return 0
    }

    return $LASTEXITCODE
}

Remove-LegacyStateFiles

if ($List) {
    $options = @(Get-PresetOptions)
    $sessionPreset = Get-ActiveSessionPreset
    $defaultPreset = Get-DefaultPreset

    Write-Host ""
    Write-Host "  Presets disponiveis:" -ForegroundColor Cyan
    Show-SettingsLeakWarning
    Write-Host ""

    foreach ($option in $options) {
        $marker = Get-PresetMarkerText -Option $option
        $description = if ([string]::IsNullOrWhiteSpace($option.Description)) { "" } else { " - $($option.Description)" }
        $nameColor = if ($option.IsSessionActive -or $option.IsDefaultActive) { "Green" } else { "Gray" }

        Write-Host "    $($option.Name)" -NoNewline -ForegroundColor $nameColor
        Write-Host $marker -NoNewline -ForegroundColor Green
        Write-Host $description -ForegroundColor DarkGray
    }

    if ($sessionPreset -eq "custom-session") {
        Write-Host "    custom-session [session]" -ForegroundColor Yellow
    }

    if ($defaultPreset -eq "custom-default") {
        Write-Host "    custom-default [default]" -ForegroundColor Yellow
    }

    Write-Host ""
    return
}

if ($Status) {
    Write-Host ""
    Write-Host "  Sessao atual: " -NoNewline -ForegroundColor Cyan
    Write-Host (Get-ActiveSessionPreset) -ForegroundColor Green
    Write-Host "  Padrao VS Code: " -NoNewline -ForegroundColor Cyan
    Write-Host (Get-DefaultPreset) -ForegroundColor Green
    Write-Host "  Arquivo monitorado pela extensao: " -NoNewline -ForegroundColor Cyan
    Write-Host $settingsLocalJsonPath -ForegroundColor DarkGray
    Show-SettingsLeakWarning
    Write-Host ""
    return
}

if (-not $PresetName) {
    $PresetName = Show-PresetMenu
    $selectedFromMenu = $true
    if (-not $PresetName) {
        Write-Host ""
        Write-Host "  [i] Cancelado." -ForegroundColor DarkGray
        Write-Host ""
        return
    }
}

if ($selectedFromMenu -and -not $ApplyOnly -and -not $SetDefault) {
    $activeSession = Get-ActiveSessionPreset
    $selectedMode = Show-ModeMenu -SelectedPreset $PresetName -ActiveSessionPreset $activeSession
    if (-not $selectedMode) {
        Write-Host ""
        Write-Host "  [i] Cancelado." -ForegroundColor DarkGray
        Write-Host ""
        return
    }

    $SetDefault = [bool]$selectedMode.SetDefault
    $ApplyOnly = [bool]$selectedMode.ApplyOnly
}

$applyToCurrentSession = ($ApplyOnly -and -not $SetDefault)
$appliedPreset = Apply-Preset -Name $PresetName -PersistDefault:$SetDefault -ApplyToCurrentSession:$applyToCurrentSession
if (-not $appliedPreset) {
    Write-Host ""
    Write-Host "  [X] Preset '$PresetName' nao encontrado ou invalido." -ForegroundColor Red
    Write-Host "  [i] Rode: cmodel -List" -ForegroundColor DarkGray
    Write-Host ""
    return
}

Write-Host ""
Write-Host "  [OK] $($appliedPreset.DisplayName)" -ForegroundColor Green
if (-not [string]::IsNullOrWhiteSpace($appliedPreset.Description)) {
    Write-Host "  [i] $($appliedPreset.Description)" -ForegroundColor DarkGray
}
if (-not [string]::IsNullOrWhiteSpace($appliedPreset.BaseUrl)) {
    Write-Host "  [i] Base URL: $($appliedPreset.BaseUrl)" -ForegroundColor DarkGray
}
if (-not [string]::IsNullOrWhiteSpace($appliedPreset.Model)) {
    Write-Host "  [i] Model:    $($appliedPreset.Model)" -ForegroundColor DarkGray
}
if ($appliedPreset.Persisted) {
    Write-Host "  [i] Padrao persistido em: $settingsLocalJsonPath" -ForegroundColor DarkGray
}
Show-SettingsLeakWarning

if ($ApplyOnly) {
    Write-Host ""
    if ($appliedPreset.Persisted) {
        if ($appliedPreset.Name -eq "anthropic") {
            Write-Host "  [i] Padrao limpo. O VS Code Claude volta ao OAuth padrao." -ForegroundColor Cyan
        }
        else {
            Write-Host "  [i] Preset salvo como padrao. O VS Code Claude usara esse provider." -ForegroundColor Cyan
        }
    }
    elseif ($appliedPreset.Name -eq "anthropic") {
        Write-Host "  [i] Sessao limpa. Claude volta ao OAuth padrao neste terminal." -ForegroundColor Cyan
    }
    else {
        Write-Host "  [i] Preset aplicado apenas nesta sessao. Rode 'claude' neste terminal." -ForegroundColor Cyan
    }
    Write-Host ""
    return
}

$exitCode = 0
$exitCode = Invoke-ClaudeSession -Arguments $ClaudeArgs -NormalizedEnv $appliedPreset.NormalizedEnv

$global:LASTEXITCODE = $exitCode
