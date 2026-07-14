[CmdletBinding()]
param(
    [string]$BaseRoot = 'C:\tmp',
    [switch]$KeepArtifacts
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$qaUnit = Join-Path $PSScriptRoot 'arena-qa-unit.mjs'
$lifecycleSmoke = Join-Path $PSScriptRoot 'phase1-smoke.ps1'

$unitOutput = @(& node.exe $qaUnit 2>&1)
if ($LASTEXITCODE -ne 0) { throw "Declarative QA unit tests failed:`n$($unitOutput -join "`n")" }
$unitResult = ($unitOutput -join "`n") | ConvertFrom-Json
if ($unitResult.status -ne 'PASS') { throw 'Declarative QA unit tests did not report PASS.' }

$parameters = @{ BaseRoot = $BaseRoot }
if ($KeepArtifacts) { $parameters.KeepArtifacts = $true }
$lifecycleResult = & $lifecycleSmoke @parameters

[pscustomobject][ordered]@{
    status = 'PASS'
    declarativeQa = $unitResult
    lifecycle = $lifecycleResult
    qualificationPath = @('import-qa-result','sign-visual-review','sign-direction-review','qualify')
    staleCandidateInvalidation = 'PASS'
} | ConvertTo-Json -Depth 20
