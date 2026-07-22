[CmdletBinding()]
param(
    [switch]$Force,
    [switch]$ResetAdminPassword
)

$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $PSScriptRoot
$EnvTemplate = Join-Path $Root '.env.development.example'
$EnvFile = Join-Path $Root '.env'
$VenvPython = Join-Path $Root 'apps\api\.venv\Scripts\python.exe'

function Require-Value([string]$Prompt, [string]$Default = '') {
    $value = Read-Host $Prompt
    if ([string]::IsNullOrWhiteSpace($value)) {
        $value = $Default
    }
    if ([string]::IsNullOrWhiteSpace($value)) {
        throw "$Prompt is required."
    }
    if ($value.Contains("`r") -or $value.Contains("`n")) {
        throw "$Prompt must not contain a line break."
    }
    return $value.Trim()
}

function ConvertTo-PlainText([securestring]$Value) {
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Value)
    try {
        return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    } finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }
}

function ConvertTo-DotEnvValue([string]$Value) {
    if ($Value.Contains("`r") -or $Value.Contains("`n")) {
        throw 'Configuration values must not contain line breaks.'
    }
    return '"' + $Value.Replace('\', '\\').Replace('"', '\"') + '"'
}

function Set-DotEnvValue([string]$Content, [string]$Name, [string]$Value) {
    $replacement = "$Name=$(ConvertTo-DotEnvValue $Value)"
    $pattern = "(?m)^" + [regex]::Escape($Name) + "=.*$"
    if (-not [regex]::IsMatch($Content, $pattern)) {
        throw "Configuration template is missing $Name."
    }
    return [regex]::Replace($Content, $pattern, $replacement)
}

if ($Force -and $ResetAdminPassword) {
    throw 'Use either -Force to recreate .env or -ResetAdminPassword to preserve its other settings.'
}

$envExists = Test-Path -LiteralPath $EnvFile
if ($envExists -and -not $Force -and -not $ResetAdminPassword) {
    throw '.env already exists and was left unchanged. To replace it, rerun this script with -Force.'
}
if ($ResetAdminPassword -and -not $envExists) {
    throw '.env does not exist. Run this script without -ResetAdminPassword first.'
}
if (-not $ResetAdminPassword -and -not (Test-Path -LiteralPath $EnvTemplate -PathType Leaf)) {
    throw '.env.development.example was not found.'
}
if (-not (Test-Path -LiteralPath $VenvPython -PathType Leaf)) {
    throw 'Local API virtual environment was not found. Run scripts\bootstrap-local-dev.ps1 first.'
}
$pythonVersion = (& $VenvPython -c 'import sys; print(*sys.version_info[:2], sep=chr(46))').Trim()
try {
    $supportedPython = [version]$pythonVersion -ge [version]'3.11'
} catch {
    $supportedPython = $false
}
if ($LASTEXITCODE -ne 0 -or -not $supportedPython) {
    throw "Local API virtual environment must use Python 3.11 or newer, but reports $pythonVersion. Recreate it with scripts\\bootstrap-local-dev.ps1."
}

& $VenvPython -c 'import bcrypt'
if ($LASTEXITCODE -ne 0) {
    throw 'The API virtual environment is missing bcrypt. Run scripts\bootstrap-local-dev.ps1 first.'
}

$adminUsername = if ($ResetAdminPassword) { $null } else { Require-Value 'Administrator username [admin]' 'admin' }
$adminPassword = Read-Host 'Local administrator password' -AsSecureString

$adminPasswordText = $null
$adminPasswordBytes = $null
$adminPasswordBase64 = $null
try {
    $adminPasswordText = ConvertTo-PlainText $adminPassword
    if ([string]::IsNullOrWhiteSpace($adminPasswordText)) {
        throw 'Administrator password must not be empty.'
    }

    $adminPasswordBytes = [System.Text.Encoding]::UTF8.GetBytes($adminPasswordText)
    $adminPasswordBase64 = [Convert]::ToBase64String($adminPasswordBytes)
    $adminPasswordHash = ($adminPasswordBase64 | & $VenvPython -c 'import base64, bcrypt, sys; password = base64.b64decode(sys.stdin.buffer.readline().strip()); print(bcrypt.hashpw(password, bcrypt.gensalt(rounds=12)).decode())').Trim()
    if ($LASTEXITCODE -ne 0 -or -not $adminPasswordHash.StartsWith('$2')) {
        throw 'Unable to generate the administrator password hash.'
    }

    $content = if ($ResetAdminPassword) {
        Get-Content -LiteralPath $EnvFile -Raw
    } else {
        Get-Content -LiteralPath $EnvTemplate -Raw
    }
    $settings = @(@{ Name = 'ADMIN_PASSWORD_HASH'; Value = $adminPasswordHash })
    if (-not $ResetAdminPassword) {
        $settings = @(@{ Name = 'ADMIN_USERNAME'; Value = $adminUsername }) + $settings
    }
    foreach ($setting in $settings) {
        $content = Set-DotEnvValue -Content $content -Name $setting.Name -Value $setting.Value
    }
    [System.IO.File]::WriteAllText($EnvFile, $content, [System.Text.UTF8Encoding]::new($false))
    $result = if ($ResetAdminPassword) { 'updated with a new administrator password' } elseif ($Force) { 'recreated' } else { 'created' }
    Write-Host ".env was $result. It is ignored by Git and was not printed."
} finally {
    $adminPasswordBase64 = $null
    $adminPasswordBytes = $null
    $adminPasswordText = $null
}
