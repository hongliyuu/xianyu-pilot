param()

$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $PSScriptRoot
$WebDir = Join-Path $Root 'apps\web'
$ApiDir = Join-Path $Root 'apps\api'
$CrawlerDir = Join-Path $Root 'apps\crawler'
$VenvPython = Join-Path $ApiDir '.venv\Scripts\python.exe'

function Require-Command([string]$Name) {
    $command = Get-Command $Name -ErrorAction SilentlyContinue
    if (-not $command) {
        throw "Required command not found: $Name"
    }
    return $command.Source
}

function Invoke-CheckedCommand(
    [string]$Name,
    [string]$CommandPath,
    [string[]]$Arguments,
    [string]$WorkingDirectory
) {
    Write-Host "==> $Name"
    $process = Start-Process -FilePath $CommandPath `
        -ArgumentList $Arguments `
        -WorkingDirectory $WorkingDirectory `
        -NoNewWindow `
        -Wait `
        -PassThru
    if ($process.ExitCode -ne 0) {
        throw "$Name failed with exit code $($process.ExitCode)."
    }
}

$npm = Require-Command 'npm.cmd'
if (-not (Test-Path -LiteralPath $VenvPython -PathType Leaf)) {
    throw "Local API virtual environment was not found: $VenvPython. Run scripts\\bootstrap-local-dev.ps1 first."
}
$python = (Resolve-Path -LiteralPath $VenvPython).Path
$pythonVersion = (& $python -c 'import sys; print(*sys.version_info[:2], sep=chr(46))').Trim()
try {
    $supportedPython = [version]$pythonVersion -ge [version]'3.11'
} catch {
    $supportedPython = $false
}
if ($LASTEXITCODE -ne 0 -or -not $supportedPython) {
    throw "Local API virtual environment must use Python 3.11 or newer, but reports $pythonVersion. Recreate it with scripts\\bootstrap-local-dev.ps1."
}

Invoke-CheckedCommand -Name 'Web production build' -CommandPath $npm -Arguments @('run', 'build') -WorkingDirectory $WebDir
Invoke-CheckedCommand -Name 'API compile check' -CommandPath $python -Arguments @('-m', 'compileall', '-q', 'app') -WorkingDirectory $ApiDir
Invoke-CheckedCommand -Name 'Crawler build' -CommandPath $npm -Arguments @('run', 'build') -WorkingDirectory $CrawlerDir

Write-Host 'verify-local passed.'
