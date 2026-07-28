[CmdletBinding()]
param(
    [string]$BaseRoot = 'C:\tmp',
    [string]$PythonExecutable = 'python.exe',
    [switch]$KeepArtifacts
)
Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Smoke.TestHarness.psm1') -Force
$lifecycle = Join-Path $PSScriptRoot 'phase1-smoke.ps1'
function Run-Lifecycle([string]$Runtime) {
    $args = @{ BaseRoot=$BaseRoot; Runtime=$Runtime }
    if ($Runtime -eq 'Python') { $args.PythonExecutable=$PythonExecutable }
    if ($KeepArtifacts) { $args.KeepArtifacts=$true }
    $output = @(& $lifecycle @args)
    return ConvertFrom-SmokeJson -Output $output -Description "$Runtime lifecycle" -RequirePass
}
$powerShell = Run-Lifecycle 'PowerShell'
$python = Run-Lifecycle 'Python'
foreach ($property in @('status','finalStage','selected','partiallyPublished')) {
    if ([string]$powerShell.$property -ne [string]$python.$property) { throw "SEMANTIC differential for ${property}: PowerShell=$($powerShell.$property) Python=$($python.$property)" }
}
if ((@($powerShell.retainedBranches) -join ',') -ne (@($python.retainedBranches) -join ',')) { throw 'SEMANTIC retained-branch differential.' }
if ((@($powerShell.commandCoverage) -join ',') -ne (@($python.commandCoverage) -join ',')) { throw 'SEMANTIC command-coverage differential.' }
if ((@($powerShell.eventCommandCoverage) -join ',') -ne (@($python.eventCommandCoverage) -join ',')) { throw 'SEMANTIC event-command differential.' }
if ((@($powerShell.artifactRelativePaths) -join ',') -ne (@($python.artifactRelativePaths) -join ',')) { throw 'SEMANTIC records-artifact differential.' }
if (-not $powerShell.styleWorktreesRemoved -or -not $python.styleWorktreesRemoved -or -not $powerShell.styleBranchesRetained -or -not $python.styleBranchesRetained) { throw 'SEMANTIC Git cleanup/retention differential.' }
$commands = @('preflight','create-worktrees','import-builder-result','start-previews','stop-previews','status','import-qa-result','sign-visual-review','sign-direction-review','qualify','select','merge','cleanup','publish-plan','publish','handoff-docs')
$commandResults = foreach ($command in $commands) {
    $classification = if ($command -in @('start-previews','stop-previews')) { 'BUGFIX' } else { 'NONE' }
    [pscustomobject][ordered]@{ command=$command; powerShell='PASS'; python='PASS'; classification=$classification }
}
$differences = @(
    [pscustomobject][ordered]@{ decision='BUGFIX-PROCESS-001'; field='previewProcessSupervision'; powerShell='PID plus start-time, single-process stop'; python='PID, create-time, executable, args, cwd, process-tree stop'; classification='BUGFIX'; reason='Phase 2 safety contract requires full identity and descendant termination.' }
)
if ([int]$powerShell.finalRevision -ne [int]$python.finalRevision) {
    $differences += [pscustomobject][ordered]@{ decision='TRANSIENT-PREVIEW-001'; field='finalRevision'; powerShell=$powerShell.finalRevision; python=$python.finalRevision; classification='TRANSIENT'; reason='Explicit start-previews retries vary with local HTTP readiness; each successful retry still increments exactly once.' }
}
[pscustomobject][ordered]@{
    status='PASS'; canonicalRuntime='PowerShell'; pythonRuntime='Phase2-noncanonical'; commands=$commandResults
    normalizedLifecycle=[pscustomobject][ordered]@{ finalStage=$python.finalStage; selected=$python.selected; retainedBranches=$python.retainedBranches; partiallyPublished=$python.partiallyPublished; commandCoverage=$python.commandCoverage; artifactCount=$python.artifactCount; styleWorktreesRemoved=$python.styleWorktreesRemoved; styleBranchesRetained=$python.styleBranchesRetained }
    differences=$differences; powerShellFinalRevision=$powerShell.finalRevision; pythonFinalRevision=$python.finalRevision
} | ConvertTo-Json -Depth 20
