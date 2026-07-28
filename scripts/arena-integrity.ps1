Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

[Console]::Error.WriteLine('DEPRECATION: scripts/arena-integrity.ps1 forwards to the Python controller; invoke the selected Python interpreter with scripts/arena_integrity.py directly.')

$python = $null
$launcherArgs = @()
if (-not [string]::IsNullOrWhiteSpace($env:ARENA_PYTHON)) {
    $python = Get-Command -Name $env:ARENA_PYTHON -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $python -and (Test-Path -LiteralPath $env:ARENA_PYTHON -PathType Leaf)) {
        $python = [pscustomobject]@{ Source = (Resolve-Path -LiteralPath $env:ARENA_PYTHON).Path }
    }
    if (-not $python) {
        [Console]::Error.WriteLine("ARENA_PYTHON does not resolve to an executable: $env:ARENA_PYTHON")
        exit 1
    }
} else {
    foreach ($candidate in @('python','python3','py')) {
        $python = Get-Command -Name $candidate -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($python) {
            if ($candidate -eq 'py') { $launcherArgs = @('-3') }
            break
        }
    }
    if (-not $python) {
        [Console]::Error.WriteLine('No Python interpreter found. Set ARENA_PYTHON to an approved Python 3.10+ interpreter; the shim never installs dependencies.')
        exit 1
    }
}

$entrypoint = Join-Path $PSScriptRoot 'arena_integrity.py'
& $python.Source @launcherArgs $entrypoint @args
exit $LASTEXITCODE