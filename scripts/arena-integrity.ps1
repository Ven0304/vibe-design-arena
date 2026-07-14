[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateSet('snapshot','normalize-brief','check-attributes','verify-brief')]
    [string]$Action,

    [string]$SkillRoot,
    [string[]]$ReferenceFiles,
    [string]$Path,
    [string]$FrozenPath,
    [string]$WorkingPath,
    [string]$Repository,
    [string]$Commit,
    [switch]$Write
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'lib\Arena.Core.psm1') -Force

function Emit-IntegrityResult {
    param(
        [Parameter(Mandatory = $true)][string]$Status,
        [Parameter(Mandatory = $true)]$Details
    )
    [ordered]@{
        schemaVersion = '1.0'
        action = $Action
        status = $Status
        timestamp = Get-ArenaUtcNow
        details = $Details
    } | ConvertTo-Json -Depth 50
}

try {
    switch ($Action) {
        'snapshot' {
            if (-not $SkillRoot) { throw 'snapshot requires -SkillRoot.' }
            if (-not $ReferenceFiles -or $ReferenceFiles.Count -eq 0) {
                $ReferenceFiles = @(
                    'SKILL.md',
                    'references/direction-brief.md',
                    'references/anti-slop.md',
                    'references/visual-quality-bar.md',
                    'references/interaction-quality-bar.md',
                    'references/arena-scorecard.md'
                )
            }
            $snapshot = Get-ArenaReferenceSnapshot -SkillRoot $SkillRoot -Files $ReferenceFiles
            Emit-IntegrityResult -Status 'PASS' -Details $snapshot
        }
        'normalize-brief' {
            if (-not $Path) { throw 'normalize-brief requires -Path.' }
            $before = Test-ArenaCanonicalUtf8Lf -Path $Path
            $result = ConvertTo-ArenaCanonicalUtf8Lf -Path $Path -Write:$Write
            $after = if ($Write) { Test-ArenaCanonicalUtf8Lf -Path $Path } else { $before }
            $status = if ($result.changed) { 'CHANGED' } elseif ($after.canonical) { 'PASS' } else { 'FAIL' }
            Emit-IntegrityResult -Status $status -Details ([pscustomobject]@{ before = $before; conversion = $result; after = $after })
        }
        'check-attributes' {
            if (-not $Repository) { throw 'check-attributes requires -Repository.' }
            $result = Test-ArenaBriefAttribute -Repository $Repository
            Emit-IntegrityResult -Status $(if ($result.valid) { 'PASS' } else { 'FAIL' }) -Details $result
        }
        'verify-brief' {
            if (-not $FrozenPath -or -not $WorkingPath) {
                throw 'verify-brief requires -FrozenPath and -WorkingPath.'
            }
            $frozenCanonical = Test-ArenaCanonicalUtf8Lf -Path $FrozenPath
            $workingCanonical = Test-ArenaCanonicalUtf8Lf -Path $WorkingPath
            $frozenHash = Get-ArenaSha256 -Path $FrozenPath
            $workingHash = Get-ArenaSha256 -Path $WorkingPath
            $blobHash = $null
            if ($Repository -and $Commit) {
                $blobHash = Get-ArenaGitBlobSha256 -Repository $Repository -Commit $Commit
            }
            $matches = $frozenCanonical.canonical -and $workingCanonical.canonical -and $frozenHash -eq $workingHash
            if ($blobHash) { $matches = $matches -and $blobHash -eq $frozenHash }
            $details = [pscustomobject]@{
                frozen = $frozenCanonical
                working = $workingCanonical
                frozenSha256 = $frozenHash
                workingSha256 = $workingHash
                gitBlobSha256 = $blobHash
                classification = if ($matches) { 'exact-match' } elseif (-not $workingCanonical.validUtf8) { 'invalid-utf8' } elseif ($workingCanonical.hasBom) { 'bom-mismatch' } elseif ($workingCanonical.hasCrLf -or $workingCanonical.hasBareCr) { 'line-ending-mismatch' } else { 'content-mismatch' }
            }
            Emit-IntegrityResult -Status $(if ($matches) { 'PASS' } else { 'FAIL' }) -Details $details
        }
    }
} catch {
    Emit-IntegrityResult -Status 'FAIL' -Details ([pscustomobject]@{ error = $_.Exception.Message })
    exit 1
}
