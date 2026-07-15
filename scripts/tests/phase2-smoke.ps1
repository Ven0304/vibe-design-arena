[CmdletBinding()]
param(
    [string]$BaseRoot = 'C:\tmp',
    [switch]$KeepArtifacts,
    [string]$QaUnitPath,
    [string]$LifecycleSmokePath,
    [string]$NodeExecutable = 'node.exe'
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'Smoke.TestHarness.psm1') -Force
$qaUnit = if ($QaUnitPath) { $QaUnitPath } else { Join-Path $PSScriptRoot 'arena-qa-unit.mjs' }
$lifecycleSmoke = if ($LifecycleSmokePath) { $LifecycleSmokePath } else { Join-Path $PSScriptRoot 'phase1-smoke.ps1' }

$unitProcess = Invoke-SmokeNativeProcess -Executable $NodeExecutable -Arguments @($qaUnit) -Description 'Declarative QA unit tests'
$unitResult = ConvertFrom-SmokeJson -Output @($unitProcess.output) -Description 'Declarative QA unit tests' -RequirePass

$parameters = @{ BaseRoot = $BaseRoot }
if ($KeepArtifacts) { $parameters.KeepArtifacts = $true }
try { $lifecycleOutput = @(& $lifecycleSmoke @parameters) }
catch { throw "Lifecycle smoke test failed: $($_.Exception.Message)" }
$lifecycleResult = ConvertFrom-SmokeJson -Output $lifecycleOutput -Description 'Lifecycle smoke test' -RequirePass

[pscustomobject][ordered]@{
    status = 'PASS'
    declarativeQa = $unitResult
    lifecycle = $lifecycleResult
    qualificationPath = @('import-qa-result','sign-visual-review','sign-direction-review','qualify')
    staleCandidateInvalidation = 'PASS'
} | ConvertTo-Json -Depth 20
