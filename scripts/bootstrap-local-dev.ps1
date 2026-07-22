[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $PSScriptRoot
$ApiDir = Join-Path $Root 'apps\api'
$WebDir = Join-Path $Root 'apps\web'
$CrawlerDir = Join-Path $Root 'apps\crawler'
$VenvPython = Join-Path $ApiDir '.venv\Scripts\python.exe'

function Require-CommandPath([string]$Name) {
    $command = Get-Command $Name -ErrorAction SilentlyContinue
    if (-not $command) {
        throw "Required command not found: $Name"
    }
    return $command.Source
}

function Test-SupportedPythonVersion([string]$Version) {
    try {
        return ([version]$Version -ge [version]'3.11')
    } catch {
        return $false
    }
}

function Resolve-SupportedPython() {
    $python = Require-CommandPath 'python'
    $version = (& $python -c 'import sys; print(*sys.version_info[:2], sep=chr(46))').Trim()
    if ($LASTEXITCODE -eq 0 -and (Test-SupportedPythonVersion $version)) {
        return [pscustomobject]@{ Path = $python; Prefix = @() }
    }

    $launcher = Get-Command 'py.exe' -ErrorAction SilentlyContinue
    if ($launcher) {
        $version = (& $launcher.Source -3.11 -c 'import sys; print(*sys.version_info[:2], sep=chr(46))' 2>$null).Trim()
        if ($LASTEXITCODE -eq 0 -and (Test-SupportedPythonVersion $version)) {
            return [pscustomobject]@{ Path = $launcher.Source; Prefix = @('-3.11') }
        }
    }

    throw 'Python 3.11 or newer is required. Install a supported CPython version and make it available through python or py -3.11.'
}

function Invoke-CheckedCommand(
    [string]$Name,
    [string]$CommandPath,
    [string[]]$Arguments,
    [string]$WorkingDirectory,
    [string[]]$CommandPrefix = @()
) {
    Write-Host "==> $Name"
    Push-Location $WorkingDirectory
    try {
        & $CommandPath @CommandPrefix @Arguments
        if ($LASTEXITCODE -ne 0) {
            throw "$Name failed with exit code $LASTEXITCODE."
        }
    } finally {
        Pop-Location
    }
}

$python = Resolve-SupportedPython
$node = Require-CommandPath 'node'
$npm = Require-CommandPath 'npm.cmd'

$nodeVersion = (& $node --version).Trim()
$npmVersion = (& $npm --version).Trim()
if ($nodeVersion -ne 'v22.23.1' -or $npmVersion -ne '10.9.8') {
    Write-Warning "This repository declares Node v22.23.1 and npm 10.9.8; detected Node $nodeVersion and npm $npmVersion. Continuing for local development."
}

if (-not (Test-Path -LiteralPath $VenvPython -PathType Leaf)) {
    Invoke-CheckedCommand -Name 'Create API virtual environment' -CommandPath $python.Path -CommandPrefix $python.Prefix -Arguments @('-m', 'venv', (Join-Path $ApiDir '.venv')) -WorkingDirectory $Root
}

$venvVersion = (& $VenvPython -c 'import sys; print(*sys.version_info[:2], sep=chr(46))').Trim()
if ($LASTEXITCODE -ne 0 -or -not (Test-SupportedPythonVersion $venvVersion)) {
    throw "Existing API virtual environment must use Python 3.11 or newer, but reports $venvVersion. Recreate apps\\api\\.venv with a supported Python version, then run this script again."
}

Invoke-CheckedCommand -Name 'Install API dependencies' -CommandPath $VenvPython -Arguments @('-m', 'pip', 'install', '--require-hashes', '-r', 'requirements.txt') -WorkingDirectory $ApiDir
Invoke-CheckedCommand -Name 'Install Web dependencies' -CommandPath $npm -Arguments @('--prefix', $WebDir, '--engine-strict=false', 'ci') -WorkingDirectory $Root
Invoke-CheckedCommand -Name 'Install Crawler dependencies' -CommandPath $npm -Arguments @('--prefix', $CrawlerDir, '--engine-strict=false', 'ci') -WorkingDirectory $Root
Invoke-CheckedCommand -Name 'Install Playwright Chromium' -CommandPath $npm -Arguments @('--prefix', $CrawlerDir, 'exec', 'playwright', 'install', 'chromium') -WorkingDirectory $Root

Write-Host 'Local development dependencies are ready. Run scripts\init-local-dev.ps1 next.'
