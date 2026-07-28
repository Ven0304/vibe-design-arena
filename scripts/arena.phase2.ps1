[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateSet(
        'preflight',
        'create-worktrees',
        'start-previews',
        'stop-previews',
        'status',
        'import-builder-result',
        'import-qa-result',
        'sign-visual-review',
        'sign-direction-review',
        'qualify',
        'select',
        'merge',
        'cleanup',
        'publish-plan',
        'publish',
        'handoff-docs'
    )]
    [string]$Command,

    [Parameter(Mandatory = $true)][string]$State,
    [int]$ExpectedRevision = -1,
    [string]$Repo,
    [string]$SkillRoot,
    [string]$Config,
    [switch]$ApplyAttributes,
    [string]$BriefRoot,
    [string]$ResultPath,
    [ValidateSet('style-a','style-b','style-c')][string]$Style,
    [ValidateSet('PASS','FAIL')][string]$Result,
    [string]$Reviewer,
    [string[]]$EvidenceIds,
    [string]$CandidateCommit,
    [string]$Remote = 'origin',
    [string[]]$Branches,
    [switch]$ConfirmPublish
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'lib\Arena.Core.psm1') -Force

$statePath = [IO.Path]::GetFullPath($State)
if (-not $SkillRoot) {
    $SkillRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
}

function New-EmptyReview {
    return [pscustomobject][ordered]@{
        status = 'PENDING'
        reviewer = $null
        timestamp = $null
        candidateCommit = $null
        qaResultSha256 = $null
        evidenceIds = @()
    }
}

function New-StyleState {
    param([Parameter(Mandatory = $true)][string]$Name, [Parameter(Mandatory = $true)][string]$WorktreeRoot)
    return [pscustomobject][ordered]@{
        branch = $Name
        worktree = (Join-Path $WorktreeRoot $Name)
        dispatchId = $null
        candidateGeneration = 1
        brief = [pscustomobject][ordered]@{
            frozenPath = $null
            approvedSha256 = $null
            commit = $null
        }
        implementationCommit = $null
        builderResultPath = $null
        qaResultPath = $null
        qaResultSha256 = $null
        preview = [pscustomobject][ordered]@{
            executable = $null
            args = @()
            port = $null
            url = $null
            pid = $null
            processStartTimeUtc = $null
            stdoutLog = $null
            stderrLog = $null
            httpStatus = $null
            environmentBlocked = $false
            lastError = $null
            retryCommand = $null
        }
        reviews = [pscustomobject][ordered]@{
            visual = New-EmptyReview
            direction = New-EmptyReview
        }
        qualification = [pscustomobject][ordered]@{
            briefIntegrity = 'PENDING'
            validation = 'PENDING'
            automatedQa = 'PENDING'
            mainAgentVisualReview = 'PENDING'
            directionConsistencyReview = 'PENDING'
            overall = 'PENDING'
        }
        retainedCommit = $null
    }
}

function Get-DefaultConfiguration {
    return [pscustomobject][ordered]@{
        preview = [pscustomobject]@{}
        validation = @()
        referenceFiles = @(
            'SKILL.md',
            'references/direction-brief.md',
            'references/anti-slop.md',
            'references/visual-quality-bar.md',
            'references/interaction-quality-bar.md',
            'references/arena-scorecard.md'
        )
    }
}

function Get-StateStyle {
    param($ArenaState, [string]$Name)
    $property = $ArenaState.styles.PSObject.Properties[$Name]
    if ($null -eq $property) { throw "Unknown style in state: $Name" }
    return $property.Value
}

function Reset-ArenaCandidateQualification {
    param($StyleState, [switch]$KeepValidation)
    $StyleState.qaResultPath = $null
    $StyleState.qaResultSha256 = $null
    $StyleState.reviews.visual = New-EmptyReview
    $StyleState.reviews.direction = New-EmptyReview
    if (-not $KeepValidation) { $StyleState.qualification.validation = 'PENDING' }
    $StyleState.qualification.automatedQa = 'PENDING'
    $StyleState.qualification.mainAgentVisualReview = 'PENDING'
    $StyleState.qualification.directionConsistencyReview = 'PENDING'
    $StyleState.qualification.overall = 'PENDING'
}

function Get-ArenaCandidateHead {
    param($StyleState)
    if (-not (Test-Path -LiteralPath $StyleState.worktree -PathType Container)) { throw "Candidate worktree is unavailable: $($StyleState.worktree)" }
    return (Invoke-ArenaGit -Repository $StyleState.worktree -Arguments @('rev-parse','HEAD')).output
}

function Get-ArenaQaEvidenceIndex {
    param($QaResult)
    $index = @{}
    foreach ($item in @($QaResult.evidence)) {
        if (-not $item.PSObject.Properties['id'] -or [string]::IsNullOrWhiteSpace([string]$item.id)) { throw 'QA evidence item is missing id.' }
        $id = [string]$item.id
        if ($index.ContainsKey($id)) { throw "Duplicate QA evidence ID: $id" }
        $index[$id] = $item
    }
    return $index
}

function Assert-ArenaQaResultContract {
    param($ArenaState, $StyleState, $QaResult, [string]$QaPath)
    foreach ($propertyName in @('schemaVersion','arenaId','style','candidateGeneration','candidateCommit','outputRoot','overall','environmentBlocked','proxyDisclosure','coverage','checks','evidence')) {
        if ($null -eq $QaResult.PSObject.Properties[$propertyName]) { throw "QA result is missing required property: $propertyName" }
    }
    if ($QaResult.schemaVersion -ne '1.0' -or $QaResult.arenaId -ne $ArenaState.arenaId) { throw 'QA result schema or Arena ID mismatch.' }
    if ($QaResult.style -ne $StyleState.branch -or [int]$QaResult.candidateGeneration -ne [int]$StyleState.candidateGeneration) { throw 'QA result style or candidate generation mismatch.' }
    if ($QaResult.candidateCommit -ne $StyleState.implementationCommit) { throw 'QA result is stale for the recorded implementation commit.' }
    $actualHead = Get-ArenaCandidateHead -StyleState $StyleState
    if ($actualHead -ne $StyleState.implementationCommit -or $actualHead -ne $QaResult.candidateCommit) { throw 'QA result candidate commit does not match the current worktree HEAD.' }

    $expectedEvidenceRoot = [IO.Path]::GetFullPath((Join-Path $ArenaState.paths.recordsRoot "evidence\$($StyleState.branch)"))
    $resolvedQaPath = (Resolve-Path -LiteralPath $QaPath).Path
    Assert-ArenaChildPath -Root $expectedEvidenceRoot -Candidate $resolvedQaPath | Out-Null
    $resolvedOutputRoot = [IO.Path]::GetFullPath([string]$QaResult.outputRoot).TrimEnd('\','/')
    if (-not $resolvedOutputRoot.Equals($expectedEvidenceRoot.TrimEnd('\','/'), [StringComparison]::OrdinalIgnoreCase)) { throw 'QA result outputRoot must be the registered candidate evidence directory.' }
    if (@('PASS','FAIL','BLOCKED') -notcontains [string]$QaResult.overall) { throw 'QA result overall must be PASS, FAIL, or BLOCKED.' }
    if ([bool]$QaResult.environmentBlocked -ne ([string]$QaResult.overall -eq 'BLOCKED')) { throw 'QA result environmentBlocked is inconsistent with overall.' }
    if ($QaResult.proxyDisclosure.name -ne 'equivalent-200-percent-layout' -or [bool]$QaResult.proxyDisclosure.isRealBrowserZoom -or [int]$QaResult.proxyDisclosure.deviceScaleFactor -ne 1) {
        throw 'QA result misstates the equivalent-200-percent-layout proxy.'
    }

    $evidenceIndex = Get-ArenaQaEvidenceIndex -QaResult $QaResult
    $executedChecks = 0
    $failedChecks = 0
    foreach ($check in @($QaResult.checks)) {
        foreach ($propertyName in @('id','scenarioId','applicability','status','evidenceIds','assertions')) {
            if ($null -eq $check.PSObject.Properties[$propertyName]) { throw "QA check is missing required property: $propertyName" }
        }
        if (@('required','applicable','not-applicable') -notcontains [string]$check.applicability) { throw "QA check has invalid applicability: $($check.id)" }
        foreach ($evidenceId in @($check.evidenceIds)) {
            if (-not $evidenceIndex.ContainsKey([string]$evidenceId)) { throw "QA check references unknown evidence ID: $evidenceId" }
        }
        if ($check.applicability -eq 'not-applicable') {
            if ($check.status -ne 'NOT-APPLICABLE' -or [string]::IsNullOrWhiteSpace([string]$check.reason) -or [string]::IsNullOrWhiteSpace([string]$check.approvedBy) -or @($check.evidenceIds).Count -eq 0) {
                throw "Invalid not-applicable QA declaration: $($check.id)"
            }
        } else {
            $executedChecks++
            if (@('PASS','FAIL','BLOCKED') -notcontains [string]$check.status) { throw "Executable QA check has invalid status: $($check.id)" }
            if ($check.status -ne 'PASS') { $failedChecks++ }
        }
    }
    if (@($QaResult.checks).Count -eq 0) { throw 'QA result contains no checks.' }
    if ([int]$QaResult.coverage.executed -ne $executedChecks -or [int]$QaResult.coverage.failed -ne $failedChecks) { throw 'QA result coverage counters do not match the check records.' }
    if ($QaResult.overall -eq 'PASS' -and $failedChecks -ne 0) { throw 'QA result claims PASS while an executable check did not pass.' }
    if ($QaResult.overall -eq 'FAIL' -and $failedChecks -eq 0) { throw 'QA result claims FAIL without a failed executable check.' }
    if ($QaResult.overall -eq 'BLOCKED' -and @(@($QaResult.checks) | Where-Object { $_.status -eq 'BLOCKED' }).Count -eq 0) { throw 'QA result claims BLOCKED without a blocked check.' }

    if ($QaResult.overall -eq 'PASS') {
        $duplicateCheckIds = @(@($QaResult.checks) | Group-Object -Property id | Where-Object { $_.Count -gt 1 })
        if ($duplicateCheckIds.Count -gt 0) { throw "Passing QA result contains duplicate check IDs: $(@($duplicateCheckIds.Name) -join ', ')" }
        $standardViewports = @('mobile','tablet','desktop')
        $universalScenarios = @('primary','dense','touch-targets','keyboard-traversal','focus-visibility','focus-return','reduced-motion','rapid-toggle')
        foreach ($scenarioId in $universalScenarios) {
            foreach ($viewportId in $standardViewports) {
                $matches = @(@($QaResult.checks) | Where-Object { $_.scenarioId -eq $scenarioId -and $_.viewportId -eq $viewportId -and $_.applicability -eq 'required' -and $_.status -eq 'PASS' })
                if ($matches.Count -ne 1) { throw "Passing QA result lacks exactly one required PASS for $scenarioId at $viewportId." }
            }
        }
        $proxyChecks = @(@($QaResult.checks) | Where-Object { $_.scenarioId -eq 'equivalent-200-percent-layout' -and $_.viewportId -eq 'desktop-equivalent-200-percent' -and $_.applicability -eq 'required' -and $_.status -eq 'PASS' })
        if ($proxyChecks.Count -ne 1) { throw 'Passing QA result lacks the required equivalent-200-percent-layout proxy check.' }

        $productScenarios = @('loading','empty','error','disabled','stale-data','long-text','missing-value','negative-number','extreme-number','container-overflow')
        foreach ($scenarioId in $productScenarios) {
            $scenarioChecks = @(@($QaResult.checks) | Where-Object { $_.scenarioId -eq $scenarioId })
            if ($scenarioChecks.Count -eq 0) { throw "Passing QA result omits product-state declaration: $scenarioId" }
            $naChecks = @($scenarioChecks | Where-Object { $_.applicability -eq 'not-applicable' -and $_.status -eq 'NOT-APPLICABLE' })
            if ($naChecks.Count -gt 0) {
                if ($naChecks.Count -ne 1 -or $scenarioChecks.Count -ne 1) { throw "Product state $scenarioId must be either one valid N/A declaration or executed checks, not both." }
            } else {
                foreach ($viewportId in $standardViewports) {
                    $matches = @($scenarioChecks | Where-Object { $_.viewportId -eq $viewportId -and $_.applicability -in @('required','applicable') -and $_.status -eq 'PASS' })
                    if ($matches.Count -ne 1) { throw "Passing QA result lacks exactly one executed PASS for $scenarioId at $viewportId." }
                }
            }
        }

        foreach ($check in @($QaResult.checks | Where-Object { $_.applicability -in @('required','applicable') })) {
            $assertionTypes = @($check.assertions | ForEach-Object { [string]$_.type })
            foreach ($requiredType in @('overflow','axe','browser-errors')) {
                if ($assertionTypes -notcontains $requiredType) { throw "Passing QA check $($check.id) lacks required $requiredType evidence." }
            }
            $referencedEvidence = @($check.evidenceIds | ForEach-Object { $evidenceIndex[[string]$_] })
            if (@($referencedEvidence | Where-Object { $_.kind -eq 'screenshot' }).Count -eq 0) { throw "Passing QA check $($check.id) lacks screenshot evidence." }
            if (@($referencedEvidence | Where-Object { $_.kind -eq 'axe' }).Count -eq 0) { throw "Passing QA check $($check.id) lacks axe evidence." }
        }
    }

    foreach ($item in $evidenceIndex.Values) {
        if ($item.kind -eq 'screenshot') {
            if (-not $item.PSObject.Properties['path'] -or [string]::IsNullOrWhiteSpace([string]$item.path)) { throw "Screenshot evidence is missing a path: $($item.id)" }
            $screenshotPath = (Resolve-Path -LiteralPath ([string]$item.path)).Path
            Assert-ArenaChildPath -Root $expectedEvidenceRoot -Candidate $screenshotPath | Out-Null
        } elseif ($item.PSObject.Properties['path'] -and -not [string]::IsNullOrWhiteSpace([string]$item.path) -and -not (Test-Path -LiteralPath ([string]$item.path))) {
            throw "QA evidence path does not exist: $($item.path)"
        }
    }
    if ($QaResult.overall -eq 'PASS') {
        foreach ($viewportId in @('mobile','tablet','desktop','desktop-equivalent-200-percent')) {
            $count = @($evidenceIndex.Values | Where-Object { $_.kind -eq 'screenshot' -and $_.viewportId -eq $viewportId }).Count
            if ($count -eq 0) { throw "Passing QA result lacks screenshot evidence for viewport: $viewportId" }
        }
    }
    return [pscustomobject]@{ evidenceIndex = $evidenceIndex; expectedEvidenceRoot = $expectedEvidenceRoot; actualHead = $actualHead }
}

function Assert-ArenaReviewEvidence {
    param($StyleState, [string[]]$Ids, [ValidateSet('visual','direction')][string]$ReviewType)
    if (-not $StyleState.qaResultPath -or -not (Test-Path -LiteralPath $StyleState.qaResultPath)) { throw 'Review signing requires an imported QA result.' }
    $qaHash = Get-ArenaSha256 -Path $StyleState.qaResultPath
    if ($qaHash -ne $StyleState.qaResultSha256) { throw 'Imported QA result changed after import; re-import it before signing.' }
    $qaResult = Read-ArenaJson -Path $StyleState.qaResultPath
    $evidenceIndex = Get-ArenaQaEvidenceIndex -QaResult $qaResult
    foreach ($id in @($Ids)) { if (-not $evidenceIndex.ContainsKey([string]$id)) { throw "Review references unknown evidence ID: $id" } }
    $referenced = @($Ids | ForEach-Object { $evidenceIndex[[string]$_] })
    if (@($referenced | Where-Object { $_.kind -eq 'screenshot' }).Count -eq 0) { throw "$ReviewType review requires screenshot evidence." }
    if ($ReviewType -eq 'visual') {
        foreach ($viewportId in @('mobile','tablet','desktop')) {
            if (@($referenced | Where-Object { $_.kind -eq 'screenshot' -and $_.viewportId -eq $viewportId }).Count -eq 0) { throw "Visual review must cite an inspected $viewportId screenshot." }
        }
    }
    if ($ReviewType -eq 'direction' -and @($referenced | Where-Object { $_.kind -eq 'design-brief' }).Count -eq 0) { throw 'Direction review must cite the frozen design-brief evidence.' }
    return $qaHash
}
function Save-NewArenaState {
    param($ArenaState, [string]$Operation)
    $lock = $null
    try {
        $lock = Open-ArenaStateLock -StatePath $statePath
        if (Test-Path -LiteralPath $statePath) { throw "Arena state already exists: $statePath" }
        $ArenaState.stateRevision = 1
        $ArenaState.updatedAt = Get-ArenaUtcNow
        Write-ArenaJsonAtomic -Path $statePath -Value $ArenaState
        Add-ArenaEvent -StatePath $statePath -Command $Operation -Outcome $(if ($ArenaState.status -eq 'blocked') { 'blocked' } else { 'success' }) -Revision 1 -Message $ArenaState.status
        Write-ArenaDerivedRecords -State $ArenaState -StatePath $statePath
        return $ArenaState
    } finally {
        Close-ArenaStateLock -LockHandle $lock
    }
}

function Update-ArenaState {
    param(
        [Parameter(Mandatory = $true)][string]$Operation,
        [Parameter(Mandatory = $true)][int]$Revision,
        [Parameter(Mandatory = $true)][scriptblock]$Mutation
    )
    if ($Revision -lt 1) { throw "$Operation requires -ExpectedRevision from the latest status output." }
    $lock = $null
    try {
        $lock = Open-ArenaStateLock -StatePath $statePath
        $arenaState = Read-ArenaJson -Path $statePath
        if ([int]$arenaState.stateRevision -ne $Revision) {
            throw "State revision mismatch. Expected=$Revision Actual=$($arenaState.stateRevision). Run status and retry."
        }
        & $Mutation $arenaState
        $arenaState.stateRevision = [int]$arenaState.stateRevision + 1
        $arenaState.updatedAt = Get-ArenaUtcNow
        Write-ArenaJsonAtomic -Path $statePath -Value $arenaState
        Add-ArenaEvent -StatePath $statePath -Command $Operation -Outcome $(if ($arenaState.status -eq 'blocked') { 'blocked' } else { 'success' }) -Revision $arenaState.stateRevision -Message $arenaState.status
        Write-ArenaDerivedRecords -State $arenaState -StatePath $statePath
        return $arenaState
    } finally {
        Close-ArenaStateLock -LockHandle $lock
    }
}

function Test-PortOpen {
    param([int]$Port)
    $client = New-Object Net.Sockets.TcpClient
    try {
        $async = $client.BeginConnect('127.0.0.1', $Port, $null, $null)
        if (-not $async.AsyncWaitHandle.WaitOne(300)) { return $false }
        $client.EndConnect($async)
        return $true
    } catch {
        return $false
    } finally {
        $client.Dispose()
    }
}

function Invoke-HttpProbe {
    param([string]$Url)
    for ($attempt = 1; $attempt -le 10; $attempt++) {
        try {
            $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 3
            return [int]$response.StatusCode
        } catch {
            Start-Sleep -Milliseconds 500
        }
    }
    return 0
}

function Quote-ProcessArgument {
    param([AllowEmptyString()][string]$Argument)
    if ($Argument.Length -eq 0) { return '""' }
    if ($Argument -notmatch '[\s"]') { return $Argument }
    $escaped = [regex]::Replace($Argument, '(\\*)"', '$1$1\"')
    $escaped = [regex]::Replace($escaped, '(\\+)$', '$1$1')
    return '"' + $escaped + '"'
}

function Start-ArenaPreviewProcess {
    param($Spec, [string]$WorkingDirectory, [string]$StdoutLog, [string]$StderrLog, [int]$Port)
    $args = @()
    if (-not $Spec.PSObject.Properties['executable'] -or -not $Spec.executable) { throw 'Preview command requires executable.' }
    if ($Spec.PSObject.Properties['args'] -and $Spec.args) {
        $args = @($Spec.args | ForEach-Object { ([string]$_).Replace('{{PORT}}', [string]$Port) })
    }
    $saved = @{}
    $environmentProperties = @()
    if ($Spec.PSObject.Properties['environment'] -and $Spec.environment) {
        $environmentProperties = @($Spec.environment.PSObject.Properties)
    }
    $duplicates = @($environmentProperties | Group-Object -Property { $_.Name.ToUpperInvariant() } | Where-Object { $_.Count -gt 1 })
    if ($duplicates.Count -gt 0) { throw "Preview environment contains duplicate case-insensitive keys: $(@($duplicates.Name) -join ', ')" }
    foreach ($property in $environmentProperties) {
            $saved[$property.Name] = [Environment]::GetEnvironmentVariable($property.Name, 'Process')
            [Environment]::SetEnvironmentVariable($property.Name, ([string]$property.Value).Replace('{{PORT}}', [string]$Port), 'Process')
    }
    try {
        $argumentLine = ($args | ForEach-Object { Quote-ProcessArgument $_ }) -join ' '
        $process = Start-Process -FilePath ([string]$Spec.executable) -ArgumentList $argumentLine -WorkingDirectory $WorkingDirectory -RedirectStandardOutput $StdoutLog -RedirectStandardError $StderrLog -PassThru -WindowStyle Hidden
        return [pscustomobject]@{ process = $process; args = $args }
    } finally {
        foreach ($name in $saved.Keys) {
            [Environment]::SetEnvironmentVariable($name, $saved[$name], 'Process')
        }
    }
}

function Get-RemoteSha {
    param([string]$Repository, [string]$RemoteName, [string]$Branch)
    $result = Invoke-ArenaGit -Repository $Repository -Arguments @('ls-remote','--heads',$RemoteName,"refs/heads/$Branch") -AllowFailure
    if ($result.exitCode -ne 0 -or [string]::IsNullOrWhiteSpace($result.output)) { return $null }
    return ($result.output -split '\s+')[0]
}

function Assert-StyleBranchesRetained {
    param($ArenaState)
    foreach ($name in @('style-a','style-b','style-c')) {
        $styleState = Get-StateStyle $ArenaState $name
        $sha = (Invoke-ArenaGit -Repository $ArenaState.repository.root -Arguments @('rev-parse',$styleState.branch)).output
        if ($styleState.implementationCommit -and $sha -ne $styleState.implementationCommit) { throw "Retained branch commit mismatch for $name. Expected=$($styleState.implementationCommit) Actual=$sha" }
        $styleState.retainedCommit = $sha
    }
}

try {
    switch ($Command) {
        'preflight' {
            if (-not (Test-Path -LiteralPath $statePath)) {
                if (-not $Repo) { throw 'preflight requires -Repo when creating a new Arena state.' }
                $repository = (Resolve-Path -LiteralPath $Repo).Path
                $gitRootResult = Invoke-ArenaGit -Repository $repository -Arguments @('rev-parse','--show-toplevel')
                $gitRoot = (Resolve-Path -LiteralPath $gitRootResult.output).Path
                if (-not $repository.Equals($gitRoot, [StringComparison]::OrdinalIgnoreCase)) {
                    throw "-Repo must be the product Git root. Requested=$repository GitRoot=$gitRoot"
                }
                $inside = Invoke-ArenaGit -Repository $repository -Arguments @('rev-parse','--is-inside-work-tree') -AllowFailure
                if ($inside.exitCode -ne 0 -or $inside.output -ne 'true') { throw "Not a Git worktree: $repository" }
                $head = Invoke-ArenaGit -Repository $repository -Arguments @('rev-parse','HEAD') -AllowFailure
                if ($head.exitCode -ne 0) { throw 'Repository has no baseline commit.' }
                $dirty = (Invoke-ArenaGit -Repository $repository -Arguments @('status','--porcelain','--untracked-files=all')).output
                if (-not [string]::IsNullOrWhiteSpace($dirty)) { throw "Repository must be clean before preflight:`n$dirty" }

                $recordsRoot = Split-Path -Parent $statePath
                if ([IO.Path]::GetFileName($recordsRoot) -ne 'records') { throw 'State must be stored at ARENA_RUN_ROOT/records/arena-state.json.' }
                $runRoot = Split-Path -Parent $recordsRoot
                $repoPrefix = $repository.TrimEnd('\','/') + [IO.Path]::DirectorySeparatorChar
                if ($runRoot.StartsWith($repoPrefix, [StringComparison]::OrdinalIgnoreCase)) {
                    throw 'ARENA_RUN_ROOT must be outside the product repository.'
                }
                $worktreeRoot = Join-Path $runRoot 'worktrees'
                [IO.Directory]::CreateDirectory($recordsRoot) | Out-Null
                [IO.Directory]::CreateDirectory($worktreeRoot) | Out-Null
                foreach ($path in @(
                    (Join-Path $recordsRoot 'briefs'),
                    (Join-Path $recordsRoot 'candidates'),
                    (Join-Path $recordsRoot 'evidence'),
                    (Join-Path $recordsRoot 'generated')
                )) { [IO.Directory]::CreateDirectory($path) | Out-Null }

                $configuration = if ($Config) { Read-ArenaJson -Path $Config } else { Get-DefaultConfiguration }
                if ($null -eq $configuration.PSObject.Properties['preview']) { Set-ArenaProperty -Object $configuration -Name 'preview' -Value ([pscustomobject]@{}) }
                if ($null -eq $configuration.PSObject.Properties['validation']) { Set-ArenaProperty -Object $configuration -Name 'validation' -Value @() }
                $referenceFiles = if ($configuration.PSObject.Properties['referenceFiles']) { @($configuration.referenceFiles) } else { @(Get-DefaultConfiguration).referenceFiles }
                $snapshot = Get-ArenaReferenceSnapshot -SkillRoot $SkillRoot -Files $referenceFiles
                $attribute = Test-ArenaBriefAttribute -Repository $repository

                $styles = [pscustomobject][ordered]@{
                    'style-a' = New-StyleState -Name 'style-a' -WorktreeRoot $worktreeRoot
                    'style-b' = New-StyleState -Name 'style-b' -WorktreeRoot $worktreeRoot
                    'style-c' = New-StyleState -Name 'style-c' -WorktreeRoot $worktreeRoot
                }
                $publication = [pscustomobject][ordered]@{}
                foreach ($key in @('main','style-a','style-b','style-c')) {
                    Set-ArenaProperty -Object $publication -Name $key -Value ([pscustomobject][ordered]@{ published = $false; remote = $null; remoteSha = $null; publishedAt = $null })
                }
                $arenaState = [pscustomobject][ordered]@{
                    schemaVersion = '1.0'
                    stateRevision = 0
                    arenaId = [Guid]::NewGuid().ToString('N')
                    stage = 'preflight'
                    status = 'ready'
                    blockingReason = $null
                    createdAt = Get-ArenaUtcNow
                    updatedAt = Get-ArenaUtcNow
                    paths = [pscustomobject][ordered]@{
                        runRoot = $runRoot
                        recordsRoot = $recordsRoot
                        worktreeRoot = $worktreeRoot
                        stateFile = $statePath
                        eventLog = Join-Path $recordsRoot 'events.jsonl'
                    }
                    repository = [pscustomobject][ordered]@{ root = $repository; baseBranch = $null; baseSha = $null }
                    skillSnapshot = $snapshot
                    configuration = $configuration
                    styles = $styles
                    selection = [pscustomobject][ordered]@{ style = $null; branch = $null; selectedAt = $null }
                    merge = [pscustomobject][ordered]@{ status = 'PENDING'; method = $null; preMergeSha = $null; postMergeSha = $null; conflicts = @(); validation = @() }
                    cleanup = [pscustomobject][ordered]@{ completedAt = $null; removedWorktrees = @() }
                    publication = $publication
                    handoff = [pscustomobject][ordered]@{ generatedAt = $null; patchPath = $null }
                }

                if (-not $attribute.valid -and -not $ApplyAttributes) {
                    $patchPath = Join-Path $recordsRoot 'generated\gitattributes.patch'
                    $patchText = @(
                        'Required product-repository patch:',
                        '',
                        '--- .gitattributes',
                        '+++ .gitattributes',
                        '@@',
                        '+/DESIGN_BRIEF.md text eol=lf'
                    ) -join "`n"
                    Write-ArenaUtf8NoBom -Path $patchPath -Content ($patchText + "`n")
                    $arenaState.status = 'blocked'
                    $arenaState.blockingReason = "Confirm the generated .gitattributes patch, then rerun preflight with -ApplyAttributes. Patch: $patchPath"
                    Save-NewArenaState -ArenaState $arenaState -Operation 'preflight' | ConvertTo-Json -Depth 30
                    break
                }
                if (-not $attribute.valid -and $ApplyAttributes) {
                    Add-ArenaBriefAttributeRule -Repository $repository | Out-Null
                    Invoke-ArenaGit -Repository $repository -Arguments @('add','--','.gitattributes') | Out-Null
                    $stagedNames = (Invoke-ArenaGit -Repository $repository -Arguments @('diff','--cached','--name-only')).output
                    if ($stagedNames -ne '.gitattributes') { throw "Preflight staged unexpected files:`n$stagedNames" }
                    Invoke-ArenaGit -Repository $repository -Arguments @('commit','-m','Enforce LF for Vibe Design Arena briefs','--','.gitattributes') | Out-Null
                }
                $verifiedAttribute = Test-ArenaBriefAttribute -Repository $repository
                if (-not $verifiedAttribute.valid) { throw 'DESIGN_BRIEF.md text/eol attributes are still invalid.' }
                $dirtyAfter = (Invoke-ArenaGit -Repository $repository -Arguments @('status','--porcelain','--untracked-files=all')).output
                if (-not [string]::IsNullOrWhiteSpace($dirtyAfter)) { throw "Repository is not clean after .gitattributes handling:`n$dirtyAfter" }
                $arenaState.repository.baseBranch = (Invoke-ArenaGit -Repository $repository -Arguments @('branch','--show-current')).output
                if ([string]::IsNullOrWhiteSpace($arenaState.repository.baseBranch)) { throw 'Detached HEAD is not supported for Arena base.' }
                $arenaState.repository.baseSha = (Invoke-ArenaGit -Repository $repository -Arguments @('rev-parse','HEAD')).output
                $arenaState.status = 'ready'
                $arenaState.blockingReason = $null
                Save-NewArenaState -ArenaState $arenaState -Operation 'preflight' | ConvertTo-Json -Depth 30
            } else {
                $updated = Update-ArenaState -Operation 'preflight' -Revision $ExpectedRevision -Mutation {
                    param($arenaState)
                    if ($arenaState.stage -ne 'preflight') { throw 'preflight can only resume during the preflight stage.' }
                    $repository = $arenaState.repository.root
                    $dirty = (Invoke-ArenaGit -Repository $repository -Arguments @('status','--porcelain','--untracked-files=all')).output
                    if (-not [string]::IsNullOrWhiteSpace($dirty)) { throw "Repository must be clean before resumed preflight:`n$dirty" }
                    $attribute = Test-ArenaBriefAttribute -Repository $repository
                    if (-not $attribute.valid) {
                        if (-not $ApplyAttributes) { throw 'Rerun with -ApplyAttributes only after the user confirms the generated patch.' }
                        Add-ArenaBriefAttributeRule -Repository $repository | Out-Null
                        Invoke-ArenaGit -Repository $repository -Arguments @('add','--','.gitattributes') | Out-Null
                        $stagedNames = (Invoke-ArenaGit -Repository $repository -Arguments @('diff','--cached','--name-only')).output
                        if ($stagedNames -ne '.gitattributes') { throw "Preflight staged unexpected files:`n$stagedNames" }
                        Invoke-ArenaGit -Repository $repository -Arguments @('commit','-m','Enforce LF for Vibe Design Arena briefs','--','.gitattributes') | Out-Null
                    }
                    if (-not (Test-ArenaBriefAttribute -Repository $repository).valid) { throw 'DESIGN_BRIEF.md attributes remain invalid.' }
                    $dirtyAfter = (Invoke-ArenaGit -Repository $repository -Arguments @('status','--porcelain','--untracked-files=all')).output
                    if (-not [string]::IsNullOrWhiteSpace($dirtyAfter)) { throw "Repository is not clean after preflight:`n$dirtyAfter" }
                    $arenaState.repository.baseBranch = (Invoke-ArenaGit -Repository $repository -Arguments @('branch','--show-current')).output
                    $arenaState.repository.baseSha = (Invoke-ArenaGit -Repository $repository -Arguments @('rev-parse','HEAD')).output
                    $arenaState.status = 'ready'
                    $arenaState.blockingReason = $null
                }
                $updated | ConvertTo-Json -Depth 30
            }
        }

        'create-worktrees' {
            if (-not $BriefRoot) {
                $BriefRoot = Join-Path (Split-Path -Parent $statePath) 'briefs'
            }
            $briefRootAbsolute = (Resolve-Path -LiteralPath $BriefRoot).Path
            $currentState = Read-ArenaJson -Path $statePath
            if ($currentState.stage -eq 'preflight') {
            $approved = Update-ArenaState -Operation 'approve-briefs' -Revision $ExpectedRevision -Mutation {
                param($arenaState)
                if ($arenaState.stage -ne 'preflight') { throw 'Brief approval requires the preflight stage.' }
                if (-not $arenaState.repository.baseSha) { throw 'preflight has not recorded the final BASE_SHA.' }
                foreach ($name in @('style-a','style-b','style-c')) {
                    $briefPath = Join-Path $briefRootAbsolute "$name\DESIGN_BRIEF.md"
                    $canonical = Test-ArenaCanonicalUtf8Lf -Path $briefPath
                    if (-not $canonical.canonical) { throw "Approved brief is not UTF-8/no-BOM/LF: $briefPath" }
                    $styleState = Get-StateStyle $arenaState $name
                    $styleState.brief.frozenPath = (Resolve-Path -LiteralPath $briefPath).Path
                    $styleState.brief.approvedSha256 = $canonical.sha256
                }
                $arenaState.stage = 'briefs-approved'
                $arenaState.status = 'ready'
            }
            } elseif ($currentState.stage -eq 'briefs-approved') {
                if ([int]$currentState.stateRevision -ne $ExpectedRevision) { throw "State revision mismatch. Expected=$ExpectedRevision Actual=$($currentState.stateRevision). Run status and retry." }
                $approved = $currentState
            } else {
                throw "create-worktrees cannot run from stage $($currentState.stage)."
            }
            $created = Update-ArenaState -Operation 'create-worktrees' -Revision ([int]$approved.stateRevision) -Mutation {
                param($arenaState)
                $repository = $arenaState.repository.root
                if ($arenaState.stage -ne 'briefs-approved') { throw 'create-worktrees requires approved briefs.' }
                $dirty = (Invoke-ArenaGit -Repository $repository -Arguments @('status','--porcelain','--untracked-files=all')).output
                if (-not [string]::IsNullOrWhiteSpace($dirty)) { throw "Repository must remain clean before worktree creation:`n$dirty" }
                $currentHead = (Invoke-ArenaGit -Repository $repository -Arguments @('rev-parse','HEAD')).output
                if ($currentHead -ne $arenaState.repository.baseSha) { throw 'Main HEAD changed after preflight. Restart preflight to establish a new final BASE_SHA.' }
                foreach ($name in @('style-a','style-b','style-c')) {
                    $styleState = Get-StateStyle $arenaState $name
                    Assert-ArenaChildPath -Root $arenaState.paths.worktreeRoot -Candidate $styleState.worktree | Out-Null
                    $branchExists = Invoke-ArenaGit -Repository $repository -Arguments @('show-ref','--verify',"refs/heads/$($styleState.branch)") -AllowFailure
                    if ($branchExists.exitCode -eq 0) { throw "Style branch already exists: $($styleState.branch)" }
                    if (Test-Path -LiteralPath $styleState.worktree) { throw "Style worktree path already exists: $($styleState.worktree)" }
                }
                foreach ($name in @('style-a','style-b','style-c')) {
                    $styleState = Get-StateStyle $arenaState $name
                    Invoke-ArenaGit -Repository $repository -Arguments @('worktree','add','-b',$styleState.branch,$styleState.worktree,$arenaState.repository.baseSha) | Out-Null
                    $targetBrief = Join-Path $styleState.worktree 'DESIGN_BRIEF.md'
                    [IO.File]::Copy($styleState.brief.frozenPath, $targetBrief, $true)
                    if ((Get-ArenaSha256 -Path $targetBrief) -ne $styleState.brief.approvedSha256) { throw "Materialized brief hash mismatch for $name" }
                    Invoke-ArenaGit -Repository $styleState.worktree -Arguments @('add','--','DESIGN_BRIEF.md') | Out-Null
                    Invoke-ArenaGit -Repository $styleState.worktree -Arguments @('commit','-m',"Add approved Vibe Design Arena brief for $name",'--','DESIGN_BRIEF.md') | Out-Null
                    $styleState.brief.commit = (Invoke-ArenaGit -Repository $styleState.worktree -Arguments @('rev-parse','HEAD')).output
                    $blobHash = Get-ArenaGitBlobSha256 -Repository $styleState.worktree -Commit $styleState.brief.commit
                    if ($blobHash -ne $styleState.brief.approvedSha256) { throw "Committed brief blob mismatch for $name" }
                    $worktreeDirty = (Invoke-ArenaGit -Repository $styleState.worktree -Arguments @('status','--porcelain','--untracked-files=all')).output
                    if (-not [string]::IsNullOrWhiteSpace($worktreeDirty)) { throw "Worktree is dirty after brief commit for $name`n$worktreeDirty" }
                    $styleState.dispatchId = [Guid]::NewGuid().ToString('N')
                    $styleState.qualification.briefIntegrity = 'PASS'
                }
                $arenaState.stage = 'worktrees-ready'
                $arenaState.status = 'ready'
            }
            $created | ConvertTo-Json -Depth 30
        }

        'import-builder-result' {
            if (-not $ResultPath) { throw 'import-builder-result requires -ResultPath.' }
            $builderResult = Read-ArenaJson -Path $ResultPath
            $updated = Update-ArenaState -Operation 'import-builder-result' -Revision $ExpectedRevision -Mutation {
                param($arenaState)
                if ($arenaState.stage -notin @('worktrees-ready','building','previews-ready','qualifying')) { throw 'Builder results can only be imported before selection.' }
                if ($builderResult.schemaVersion -ne '1.0' -or $builderResult.arenaId -ne $arenaState.arenaId) { throw 'Builder result schema or Arena ID mismatch.' }
                $name = [string]$builderResult.style
                $styleState = Get-StateStyle $arenaState $name
                if ($styleState.preview.pid) { throw "Stop the recorded preview before importing a revised builder result for $name." }
                if ($builderResult.dispatchId -ne $styleState.dispatchId -or [int]$builderResult.candidateGeneration -ne [int]$styleState.candidateGeneration) { throw 'Stale builder result: dispatch ID or candidate generation mismatch.' }
                if ($builderResult.branch -ne $styleState.branch -or $builderResult.briefCommit -ne $styleState.brief.commit -or $builderResult.briefSha256 -ne $styleState.brief.approvedSha256) { throw 'Builder result branch or brief identity mismatch.' }
                $actualHead = (Invoke-ArenaGit -Repository $styleState.worktree -Arguments @('rev-parse','HEAD')).output
                if ($actualHead -ne $builderResult.implementationCommit) { throw 'Builder implementation commit does not match worktree HEAD.' }
                $workingHash = Get-ArenaSha256 -Path (Join-Path $styleState.worktree 'DESIGN_BRIEF.md')
                $blobHash = Get-ArenaGitBlobSha256 -Repository $styleState.worktree -Commit $actualHead
                if ($workingHash -ne $styleState.brief.approvedSha256 -or $blobHash -ne $styleState.brief.approvedSha256) { throw 'Builder changed the approved brief.' }
                $candidateDirectory = Join-Path $arenaState.paths.recordsRoot "candidates\$name"
                [IO.Directory]::CreateDirectory($candidateDirectory) | Out-Null
                $storedPath = Join-Path $candidateDirectory 'builder-result.json'
                [IO.File]::Copy((Resolve-Path -LiteralPath $ResultPath).Path, $storedPath, $true)
                $styleState.builderResultPath = $storedPath
                $styleState.implementationCommit = $actualHead
                $styleState.qualification.briefIntegrity = 'PASS'
                $styleState.qualification.validation = if ($builderResult.validation.overall -eq 'PASS') { 'PASS' } else { 'FAIL' }
                Reset-ArenaCandidateQualification -StyleState $styleState -KeepValidation
                $arenaState.stage = 'building'
                $arenaState.status = 'ready'
                $arenaState.blockingReason = $null
            }
            $updated | ConvertTo-Json -Depth 30
        }

        'start-previews' {
            $updated = Update-ArenaState -Operation 'start-previews' -Revision $ExpectedRevision -Mutation {
                param($arenaState)
                if ($arenaState.stage -notin @('building','previews-ready','qualifying')) { throw 'start-previews requires imported builder results.' }
                $allReady = $true
                foreach ($name in @('style-a','style-b','style-c')) {
                    $styleState = Get-StateStyle $arenaState $name
                    if (-not $styleState.implementationCommit) { throw "Missing builder result for $name" }
                    $previewProperty = $arenaState.configuration.preview.PSObject.Properties[$name]
                    if ($null -eq $previewProperty) { throw "Missing structured preview configuration for $name" }
                    $spec = $previewProperty.Value
                    $port = [int]$spec.port
                    if (-not $spec.PSObject.Properties['executable'] -or -not $spec.executable) { throw "Preview command requires executable for $name" }
                    $url = if ($spec.PSObject.Properties['url'] -and $spec.url) { ([string]$spec.url).Replace('{{PORT}}', [string]$port) } else { "http://127.0.0.1:$port" }
                    $retryArgs = if ($spec.PSObject.Properties['args'] -and $spec.args) { @($spec.args | ForEach-Object { ([string]$_).Replace('{{PORT}}', [string]$port) }) } else { @() }
                    $retryCommand = ((@([string]$spec.executable) + $retryArgs) | ForEach-Object { Quote-ProcessArgument ([string]$_) }) -join ' '
                    if ($styleState.preview.pid) {
                        $existing = Get-Process -Id ([int]$styleState.preview.pid) -ErrorAction SilentlyContinue
                        if ($existing) {
                            $actualStart = $existing.StartTime.ToUniversalTime()
                            $recordedStart = [DateTime]::Parse([string]$styleState.preview.processStartTimeUtc).ToUniversalTime()
                            if ([Math]::Abs(($actualStart - $recordedStart).TotalSeconds) -gt 1) {
                                throw "PID identity mismatch for $name; refusing to reuse process $($styleState.preview.pid)."
                            }
                            $httpStatus = Invoke-HttpProbe -Url $url
                            $styleState.preview.httpStatus = $httpStatus
                            $styleState.preview.url = $url
                            if ($httpStatus -eq 200) {
                                $styleState.preview.environmentBlocked = $false
                                $styleState.preview.lastError = $null
                            }
                            if ($httpStatus -eq 0) { $allReady = $false }
                            continue
                        }
                        $styleState.preview.pid = $null
                        $styleState.preview.processStartTimeUtc = $null
                        $styleState.preview.httpStatus = 0
                    }
                    if (Test-PortOpen -Port $port) { throw "Preview port is already occupied: $port" }
                    $logRoot = Join-Path $arenaState.paths.recordsRoot "evidence\$name\logs"
                    [IO.Directory]::CreateDirectory($logRoot) | Out-Null
                    $stdoutLog = Join-Path $logRoot 'preview.stdout.log'
                    $stderrLog = Join-Path $logRoot 'preview.stderr.log'
                    try {
                        $started = Start-ArenaPreviewProcess -Spec $spec -WorkingDirectory $styleState.worktree -StdoutLog $stdoutLog -StderrLog $stderrLog -Port $port
                        $process = $started.process
                        $url = if ($spec.PSObject.Properties['url'] -and $spec.url) { ([string]$spec.url).Replace('{{PORT}}', [string]$port) } else { "http://127.0.0.1:$port" }
                        $httpStatus = Invoke-HttpProbe -Url $url
                        $styleState.preview.executable = [string]$spec.executable
                        $styleState.preview.args = $started.args
                        $styleState.preview.port = $port
                        $styleState.preview.url = $url
                        $styleState.preview.pid = $process.Id
                        $styleState.preview.processStartTimeUtc = $process.StartTime.ToUniversalTime().ToString('o')
                        $styleState.preview.stdoutLog = $stdoutLog
                        $styleState.preview.stderrLog = $stderrLog
                        $styleState.preview.httpStatus = $httpStatus
                        $logText = ''
                        if (Test-Path -LiteralPath $stderrLog) { $logText = [IO.File]::ReadAllText($stderrLog) }
                        $styleState.preview.environmentBlocked = $httpStatus -eq 0 -and $logText -match 'spawn EPERM|duplicate.*Path|Path.*PATH'
                        $styleState.preview.retryCommand = $retryCommand
                        $styleState.preview.lastError = if ($httpStatus -eq 0 -and -not [string]::IsNullOrWhiteSpace($logText)) { $logText } else { $null }
                        if ($httpStatus -eq 0) { $allReady = $false }
                    } catch {
                        $styleState.preview.environmentBlocked = $_.Exception.Message -match 'EPERM|Path|permission'
                        $styleState.preview.stderrLog = $stderrLog
                        $styleState.preview.httpStatus = 0
                        $styleState.preview.lastError = $_.Exception.Message
                        $styleState.preview.retryCommand = $retryCommand
                        $allReady = $false
                    }
                }
                if ($allReady) {
                    $arenaState.stage = 'previews-ready'
                    $arenaState.status = 'ready'
                    $arenaState.blockingReason = $null
                } else {
                    $arenaState.status = 'blocked'
                    $arenaState.blockingReason = 'One or more previews did not respond. Inspect recorded logs and retry the exact structured command with the required approval.'
                }
            }
            $updated | ConvertTo-Json -Depth 30
        }

        'stop-previews' {
            $updated = Update-ArenaState -Operation 'stop-previews' -Revision $ExpectedRevision -Mutation {
                param($arenaState)
                foreach ($name in @('style-a','style-b','style-c')) {
                    $styleState = Get-StateStyle $arenaState $name
                    if ($styleState.preview.pid) {
                        $process = Get-Process -Id ([int]$styleState.preview.pid) -ErrorAction SilentlyContinue
                        if ($process) {
                            $actualStart = $process.StartTime.ToUniversalTime()
                            $recordedStart = [DateTime]::Parse([string]$styleState.preview.processStartTimeUtc).ToUniversalTime()
                            if ([Math]::Abs(($actualStart - $recordedStart).TotalSeconds) -gt 1) { throw "PID identity mismatch for $name; refusing to stop process $($styleState.preview.pid)." }
                            Stop-Process -Id $process.Id -ErrorAction Stop
                            $process.WaitForExit(5000) | Out-Null
                        }
                        $styleState.preview.pid = $null
                        $styleState.preview.processStartTimeUtc = $null
                        $styleState.preview.httpStatus = 0
                    }
                }
                $arenaState.status = 'ready'
                $arenaState.blockingReason = $null
            }
            $updated | ConvertTo-Json -Depth 30
        }

        'status' {
            $arenaState = Read-ArenaJson -Path $statePath
            $summary = [ordered]@{
                arenaId = $arenaState.arenaId
                stateRevision = $arenaState.stateRevision
                stage = $arenaState.stage
                status = $arenaState.status
                blockingReason = $arenaState.blockingReason
                baseBranch = $arenaState.repository.baseBranch
                baseSha = $arenaState.repository.baseSha
                selection = $arenaState.selection
                styles = $arenaState.styles
                publication = $arenaState.publication
            }
            $summary | ConvertTo-Json -Depth 30
        }

        'select' {
            if (-not $Style) { throw 'select requires -Style.' }
            $updated = Update-ArenaState -Operation 'select' -Revision $ExpectedRevision -Mutation {
                param($arenaState)
                if ($arenaState.stage -ne 'selection-ready') { throw 'All three candidates must qualify before selection.' }
                $styleState = Get-StateStyle $arenaState $Style
                if ($styleState.qualification.overall -ne 'PASS') { throw 'Selected style is not qualified.' }
                $arenaState.selection.style = $Style
                $arenaState.selection.branch = $styleState.branch
                $arenaState.selection.selectedAt = Get-ArenaUtcNow
                $arenaState.stage = 'selected'
                $arenaState.status = 'ready'
            }
            $updated | ConvertTo-Json -Depth 30
        }

        'merge' {
            $updated = Update-ArenaState -Operation 'merge' -Revision $ExpectedRevision -Mutation {
                param($arenaState)
                if ($arenaState.stage -ne 'selected') { throw 'merge requires a selected candidate.' }
                foreach ($name in @('style-a','style-b','style-c')) {
                    if ((Get-StateStyle $arenaState $name).preview.pid) { throw 'Stop all recorded preview processes before merge.' }
                }
                $repository = $arenaState.repository.root
                $selectedStyle = Get-StateStyle $arenaState $arenaState.selection.style
                Invoke-ArenaGit -Repository $repository -Arguments @('switch',$arenaState.repository.baseBranch) | Out-Null
                $mergeHead = Invoke-ArenaGit -Repository $repository -Arguments @('rev-parse','-q','--verify','MERGE_HEAD') -AllowFailure
                if ($mergeHead.exitCode -eq 0) {
                    $unmerged = (Invoke-ArenaGit -Repository $repository -Arguments @('diff','--name-only','--diff-filter=U') -AllowFailure).output
                    if (-not [string]::IsNullOrWhiteSpace($unmerged)) {
                        $arenaState.merge.status = 'CONFLICT'
                        $arenaState.merge.conflicts = @($unmerged -split "`n")
                        $arenaState.status = 'blocked'
                        $arenaState.blockingReason = 'Merge conflicts remain. Resolve them, inspect the focused diff with the user, then rerun merge.'
                        return
                    }
                    Invoke-ArenaGit -Repository $repository -Arguments @('commit','-m',"Merge selected Vibe Design Arena $($selectedStyle.branch)") | Out-Null
                    $arenaState.merge.method = 'merge-commit-resumed'
                } else {
                    $dirty = (Invoke-ArenaGit -Repository $repository -Arguments @('status','--porcelain','--untracked-files=all')).output
                    if (-not [string]::IsNullOrWhiteSpace($dirty)) { throw "Main worktree must be clean before merge:`n$dirty" }
                    $arenaState.merge.preMergeSha = (Invoke-ArenaGit -Repository $repository -Arguments @('rev-parse','HEAD')).output
                    $alreadyMerged = Invoke-ArenaGit -Repository $repository -Arguments @('merge-base','--is-ancestor',$selectedStyle.branch,'HEAD') -AllowFailure
                    if ($alreadyMerged.exitCode -ne 0) {
                        $ff = Invoke-ArenaGit -Repository $repository -Arguments @('merge-base','--is-ancestor','HEAD',$selectedStyle.branch) -AllowFailure
                        if ($ff.exitCode -eq 0) {
                            Invoke-ArenaGit -Repository $repository -Arguments @('merge','--ff-only',$selectedStyle.branch) | Out-Null
                            $arenaState.merge.method = 'fast-forward'
                        } else {
                            $mergeResult = Invoke-ArenaGit -Repository $repository -Arguments @('merge','--no-ff',$selectedStyle.branch,'-m',"Merge selected Vibe Design Arena $($selectedStyle.branch)") -AllowFailure
                            if ($mergeResult.exitCode -ne 0) {
                                $conflicts = (Invoke-ArenaGit -Repository $repository -Arguments @('diff','--name-only','--diff-filter=U') -AllowFailure).output
                                $arenaState.merge.status = 'CONFLICT'
                                $arenaState.merge.conflicts = if ($conflicts) { @($conflicts -split "`n") } else { @() }
                                $arenaState.status = 'blocked'
                                $arenaState.blockingReason = 'Merge conflicts require user judgment. No automatic resolution or abort was performed.'
                                return
                            }
                            $arenaState.merge.method = 'merge-commit'
                        }
                    } elseif (-not $arenaState.merge.method) {
                        $arenaState.merge.method = 'already-merged'
                    }
                }
                $postSha = (Invoke-ArenaGit -Repository $repository -Arguments @('rev-parse','HEAD')).output
                $mergedBrief = Join-Path $repository 'DESIGN_BRIEF.md'
                if ((Get-ArenaSha256 -Path $mergedBrief) -ne $selectedStyle.brief.approvedSha256) {
                    $arenaState.merge.status = 'BRIEF-INTEGRITY-FAIL'
                    $arenaState.status = 'blocked'
                    $arenaState.blockingReason = 'Merged DESIGN_BRIEF.md does not match the approved bytes.'
                    return
                }
                $validationResults = @()
                foreach ($spec in @($arenaState.configuration.validation)) {
                    $validationResults += Invoke-ArenaCommandSpec -Spec $spec -DefaultWorkingDirectory $repository
                }
                $arenaState.merge.validation = $validationResults
                if (@($validationResults | Where-Object { $_.status -ne 'PASS' }).Count -gt 0) {
                    $arenaState.merge.status = 'VALIDATION-FAIL'
                    $arenaState.merge.postMergeSha = $postSha
                    $arenaState.status = 'blocked'
                    $arenaState.blockingReason = 'Post-merge validation failed. Repair the merged result before cleanup.'
                    return
                }
                $arenaState.merge.postMergeSha = $postSha
                $arenaState.merge.status = 'PASS'
                $arenaState.stage = 'merged'
                $arenaState.status = 'ready'
                $arenaState.blockingReason = $null
            }
            $updated | ConvertTo-Json -Depth 30
        }

        'cleanup' {
            $cleaned = Update-ArenaState -Operation 'cleanup' -Revision $ExpectedRevision -Mutation {
                param($arenaState)
                if ($arenaState.stage -ne 'merged' -or $arenaState.merge.status -ne 'PASS') { throw 'cleanup requires a verified merged result.' }
                $removed = @()
                $registry = (Invoke-ArenaGit -Repository $arenaState.repository.root -Arguments @('worktree','list','--porcelain')).output
                $registeredPaths = @($registry -split "`n" | Where-Object { $_.StartsWith('worktree ') } | ForEach-Object {
                    $registeredPath = $_.Substring(9).Trim()
                    if (Test-Path -LiteralPath $registeredPath) { (Resolve-Path -LiteralPath $registeredPath).Path } else { [IO.Path]::GetFullPath($registeredPath) }
                })
                if ($registeredPaths.Count -lt 4) { throw 'Git worktree registry does not contain the main worktree plus all three candidates.' }

                foreach ($name in @('style-a','style-b','style-c')) {
                    $styleState = Get-StateStyle $arenaState $name
                    if ($styleState.preview.pid) { throw "Preview process is still recorded for $name" }
                    $path = Assert-ArenaChildPath -Root $arenaState.paths.worktreeRoot -Candidate $styleState.worktree
                    if (@($registeredPaths | Where-Object { $_.Equals($path, [StringComparison]::OrdinalIgnoreCase) }).Count -ne 1) {
                        throw "Registered worktree mismatch for ${name}: $path"
                    }
                    $branch = (Invoke-ArenaGit -Repository $path -Arguments @('branch','--show-current')).output
                    if ($branch -ne $styleState.branch) { throw "Worktree branch mismatch for $name" }
                    $dirty = (Invoke-ArenaGit -Repository $path -Arguments @('status','--porcelain','--untracked-files=all')).output
                    if (-not [string]::IsNullOrWhiteSpace($dirty)) { throw "Worktree contains uncommitted or untracked files; refusing cleanup for $name`n$dirty" }
                    Invoke-ArenaGit -Repository $arenaState.repository.root -Arguments @('worktree','remove',$path) | Out-Null
                    $removed += $path
                }
                Invoke-ArenaGit -Repository $arenaState.repository.root -Arguments @('worktree','prune') | Out-Null
                Assert-StyleBranchesRetained -ArenaState $arenaState
                $arenaState.cleanup.completedAt = Get-ArenaUtcNow
                $arenaState.cleanup.removedWorktrees = $removed
                $arenaState.stage = 'cleaned'
                $arenaState.status = 'ready'
            }
            $completed = Update-ArenaState -Operation 'complete' -Revision ([int]$cleaned.stateRevision) -Mutation {
                param($arenaState)
                if ($arenaState.stage -ne 'cleaned') { throw 'Internal cleanup completion transition requires cleaned stage.' }
                $arenaState.stage = 'complete'
                $arenaState.status = 'complete'
            }
            $completed | ConvertTo-Json -Depth 30
        }

        'publish-plan' {
            $arenaState = Read-ArenaJson -Path $statePath
            $requested = if ($Branches -and $Branches.Count -gt 0) { $Branches } else { @($arenaState.repository.baseBranch, $arenaState.styles.'style-a'.branch, $arenaState.styles.'style-b'.branch, $arenaState.styles.'style-c'.branch) }
            $plan = @()
            foreach ($branch in $requested) {
                $localSha = (Invoke-ArenaGit -Repository $arenaState.repository.root -Arguments @('rev-parse',$branch)).output
                $remoteSha = Get-RemoteSha -Repository $arenaState.repository.root -RemoteName $Remote -Branch $branch
                $plan += [pscustomobject]@{ branch = $branch; localSha = $localSha; remoteSha = $remoteSha; action = if ($localSha -eq $remoteSha) { 'none' } else { 'push' } }
            }
            [ordered]@{ remote = $Remote; branches = $plan; stateRevision = $arenaState.stateRevision } | ConvertTo-Json -Depth 10
        }

        'publish' {
            if (-not $ConfirmPublish) { throw 'publish requires -ConfirmPublish after reviewing publish-plan.' }
            if (-not $Branches -or $Branches.Count -eq 0) { throw 'publish requires an explicit -Branches list.' }
            $updated = Update-ArenaState -Operation 'publish' -Revision $ExpectedRevision -Mutation {
                param($arenaState)
                $allowed = @($arenaState.repository.baseBranch, $arenaState.styles.'style-a'.branch, $arenaState.styles.'style-b'.branch, $arenaState.styles.'style-c'.branch)
                foreach ($branch in $Branches) {
                    if ($allowed -notcontains $branch) { throw "Branch is outside the Arena publication set: $branch" }
                    Invoke-ArenaGit -Repository $arenaState.repository.root -Arguments @('push',$Remote,"$branch`:refs/heads/$branch") | Out-Null
                    $remoteSha = Get-RemoteSha -Repository $arenaState.repository.root -RemoteName $Remote -Branch $branch
                    $localSha = (Invoke-ArenaGit -Repository $arenaState.repository.root -Arguments @('rev-parse',$branch)).output
                    if ($remoteSha -ne $localSha) { throw "Remote verification failed after publishing $branch" }
                    $key = if ($branch -eq $arenaState.repository.baseBranch) { 'main' } else { (@('style-a','style-b','style-c') | Where-Object { (Get-StateStyle $arenaState $_).branch -eq $branch } | Select-Object -First 1) }
                    $publicationState = $arenaState.publication.PSObject.Properties[$key].Value
                    $publicationState.published = $true
                    $publicationState.remote = $Remote
                    $publicationState.remoteSha = $remoteSha
                    $publicationState.publishedAt = Get-ArenaUtcNow
                }
            }
            $updated | ConvertTo-Json -Depth 30
        }

        'handoff-docs' {
            $updated = Update-ArenaState -Operation 'handoff-docs' -Revision $ExpectedRevision -Mutation {
                param($arenaState)
                if ($arenaState.stage -notin @('cleaned','complete')) { throw 'handoff-docs is available only after cleanup.' }
                $patchPath = Join-Path $arenaState.paths.recordsRoot 'generated\README.arena-patch.md'
                $lines = @(
                    '# README patch draft — Vibe Design Arena result',
                    '',
                    "- Selected direction: $($arenaState.selection.style)",
                    "- Selected branch: $($arenaState.selection.branch)",
                    "- Post-merge SHA: $($arenaState.merge.postMergeSha)",
                    '',
                    '## Alternative branches'
                )
                foreach ($name in @('style-a','style-b','style-c')) {
                    $styleState = Get-StateStyle $arenaState $name
                    $publicationState = $arenaState.publication.PSObject.Properties[$name].Value
                    $lines += "- $($styleState.branch): local=$($styleState.retainedCommit), remotePublished=$($publicationState.published), remoteSha=$($publicationState.remoteSha)"
                }
                $lines += @('', '## Validation commands')
                foreach ($spec in @($arenaState.configuration.validation)) {
                    $lines += "- $($spec.executable) $(@($spec.args) -join ' ')"
                }
                Write-ArenaUtf8NoBom -Path $patchPath -Content (($lines -join "`n") + "`n")
                $arenaState.handoff.generatedAt = Get-ArenaUtcNow
                $arenaState.handoff.patchPath = $patchPath
            }
            $updated | ConvertTo-Json -Depth 30
        }

        'import-qa-result' {
            if (-not $ResultPath) { throw 'import-qa-result requires -ResultPath.' }
            $qaResult = Read-ArenaJson -Path $ResultPath
            $updated = Update-ArenaState -Operation 'import-qa-result' -Revision $ExpectedRevision -Mutation {
                param($arenaState)
                if ($arenaState.stage -notin @('previews-ready','qualifying')) { throw 'QA results can only be imported after all previews are ready and before selection.' }
                $name = [string]$qaResult.style
                $styleState = Get-StateStyle $arenaState $name
                $contract = Assert-ArenaQaResultContract -ArenaState $arenaState -StyleState $styleState -QaResult $qaResult -QaPath $ResultPath
                $candidateDirectory = Join-Path $arenaState.paths.recordsRoot "candidates\$name"
                [IO.Directory]::CreateDirectory($candidateDirectory) | Out-Null
                $storedPath = Join-Path $candidateDirectory 'qa-results.json'
                [IO.File]::Copy((Resolve-Path -LiteralPath $ResultPath).Path, $storedPath, $true)
                $styleState.qaResultPath = $storedPath
                $styleState.qaResultSha256 = Get-ArenaSha256 -Path $storedPath
                $styleState.reviews.visual = New-EmptyReview
                $styleState.reviews.direction = New-EmptyReview
                $styleState.qualification.automatedQa = [string]$qaResult.overall
                $styleState.qualification.mainAgentVisualReview = 'PENDING'
                $styleState.qualification.directionConsistencyReview = 'PENDING'
                $styleState.qualification.overall = 'PENDING'
                $arenaState.stage = 'qualifying'
                if ($qaResult.overall -eq 'BLOCKED') {
                    $arenaState.status = 'blocked'
                    $arenaState.blockingReason = [string]$qaResult.blocker
                } else {
                    $arenaState.status = 'ready'
                    $arenaState.blockingReason = $null
                }
            }
            $updated | ConvertTo-Json -Depth 30
        }

        'sign-visual-review' {
            if (-not $Style -or -not $Result -or [string]::IsNullOrWhiteSpace($Reviewer) -or [string]::IsNullOrWhiteSpace($CandidateCommit) -or -not $EvidenceIds -or $EvidenceIds.Count -eq 0) {
                throw 'sign-visual-review requires -Style, -Result, -Reviewer, -CandidateCommit, and -EvidenceIds.'
            }
            $updated = Update-ArenaState -Operation 'sign-visual-review' -Revision $ExpectedRevision -Mutation {
                param($arenaState)
                if ($arenaState.stage -ne 'qualifying') { throw 'Visual review can only be signed during qualifying.' }
                $styleState = Get-StateStyle $arenaState $Style
                $actualHead = Get-ArenaCandidateHead -StyleState $styleState
                if ($CandidateCommit -ne $styleState.implementationCommit -or $CandidateCommit -ne $actualHead) { throw 'Visual review candidate commit is stale.' }
                $qaHash = Assert-ArenaReviewEvidence -StyleState $styleState -Ids $EvidenceIds -ReviewType 'visual'
                $styleState.reviews.visual = [pscustomobject][ordered]@{
                    status = $Result
                    reviewer = $Reviewer
                    timestamp = Get-ArenaUtcNow
                    candidateCommit = $CandidateCommit
                    qaResultSha256 = $qaHash
                    evidenceIds = @($EvidenceIds)
                }
                $styleState.qualification.mainAgentVisualReview = $Result
                $styleState.qualification.overall = 'PENDING'
                $arenaState.status = 'ready'
                $arenaState.blockingReason = $null
            }
            $updated | ConvertTo-Json -Depth 30
        }

        'sign-direction-review' {
            if (-not $Style -or -not $Result -or [string]::IsNullOrWhiteSpace($Reviewer) -or [string]::IsNullOrWhiteSpace($CandidateCommit) -or -not $EvidenceIds -or $EvidenceIds.Count -eq 0) {
                throw 'sign-direction-review requires -Style, -Result, -Reviewer, -CandidateCommit, and -EvidenceIds.'
            }
            $updated = Update-ArenaState -Operation 'sign-direction-review' -Revision $ExpectedRevision -Mutation {
                param($arenaState)
                if ($arenaState.stage -ne 'qualifying') { throw 'Direction review can only be signed during qualifying.' }
                $styleState = Get-StateStyle $arenaState $Style
                $actualHead = Get-ArenaCandidateHead -StyleState $styleState
                if ($CandidateCommit -ne $styleState.implementationCommit -or $CandidateCommit -ne $actualHead) { throw 'Direction review candidate commit is stale.' }
                $qaHash = Assert-ArenaReviewEvidence -StyleState $styleState -Ids $EvidenceIds -ReviewType 'direction'
                $styleState.reviews.direction = [pscustomobject][ordered]@{
                    status = $Result
                    reviewer = $Reviewer
                    timestamp = Get-ArenaUtcNow
                    candidateCommit = $CandidateCommit
                    qaResultSha256 = $qaHash
                    evidenceIds = @($EvidenceIds)
                }
                $styleState.qualification.directionConsistencyReview = $Result
                $styleState.qualification.overall = 'PENDING'
                $arenaState.status = 'ready'
                $arenaState.blockingReason = $null
            }
            $updated | ConvertTo-Json -Depth 30
        }

        'qualify' {
            if (-not $Style) { throw 'qualify requires -Style.' }
            $updated = Update-ArenaState -Operation 'qualify' -Revision $ExpectedRevision -Mutation {
                param($arenaState)
                if ($arenaState.stage -ne 'qualifying') { throw 'qualify can only run during qualifying.' }
                $styleState = Get-StateStyle $arenaState $Style
                $actualHead = Get-ArenaCandidateHead -StyleState $styleState
                if ($actualHead -ne $styleState.implementationCommit) {
                    Reset-ArenaCandidateQualification -StyleState $styleState -KeepValidation
                    $arenaState.stage = 'building'
                    $arenaState.status = 'blocked'
                    $arenaState.blockingReason = "$Style changed after builder import. Import a builder result for commit $actualHead; old QA and review signatures are invalid."
                    return
                }

                $workingHash = Get-ArenaSha256 -Path (Join-Path $styleState.worktree 'DESIGN_BRIEF.md')
                $blobHash = Get-ArenaGitBlobSha256 -Repository $styleState.worktree -Commit $actualHead
                $styleState.qualification.briefIntegrity = if ($workingHash -eq $styleState.brief.approvedSha256 -and $blobHash -eq $styleState.brief.approvedSha256) { 'PASS' } else { 'FAIL' }
                if ($styleState.qaResultPath -and (Test-Path -LiteralPath $styleState.qaResultPath) -and (Get-ArenaSha256 -Path $styleState.qaResultPath) -eq $styleState.qaResultSha256) {
                    $qaResult = Read-ArenaJson -Path $styleState.qaResultPath
                    $styleState.qualification.automatedQa = [string]$qaResult.overall
                } else {
                    $styleState.qualification.automatedQa = 'PENDING'
                }

                $visual = $styleState.reviews.visual
                $visualCurrent = $visual.candidateCommit -eq $actualHead -and $visual.qaResultSha256 -eq $styleState.qaResultSha256
                $styleState.qualification.mainAgentVisualReview = if ($visualCurrent) { [string]$visual.status } else { 'PENDING' }
                $direction = $styleState.reviews.direction
                $directionCurrent = $direction.candidateCommit -eq $actualHead -and $direction.qaResultSha256 -eq $styleState.qaResultSha256
                $styleState.qualification.directionConsistencyReview = if ($directionCurrent) { [string]$direction.status } else { 'PENDING' }

                $gateValues = @(
                    $styleState.qualification.briefIntegrity,
                    $styleState.qualification.validation,
                    $styleState.qualification.automatedQa,
                    $styleState.qualification.mainAgentVisualReview,
                    $styleState.qualification.directionConsistencyReview
                )
                $styleState.qualification.overall = if (@($gateValues | Where-Object { $_ -ne 'PASS' }).Count -eq 0) { 'PASS' } else { 'FAIL' }
                $allQualified = $true
                foreach ($name in @('style-a','style-b','style-c')) {
                    if ((Get-StateStyle $arenaState $name).qualification.overall -ne 'PASS') { $allQualified = $false }
                }
                if ($allQualified) {
                    $arenaState.stage = 'selection-ready'
                    $arenaState.status = 'ready'
                    $arenaState.blockingReason = $null
                } elseif ($styleState.qualification.overall -eq 'PASS') {
                    $arenaState.stage = 'qualifying'
                    $arenaState.status = 'ready'
                    $arenaState.blockingReason = $null
                } else {
                    $arenaState.stage = 'qualifying'
                    $arenaState.status = 'blocked'
                    $arenaState.blockingReason = "$Style is not qualified. All five qualification gates must be PASS."
                }
            }
            $updated | ConvertTo-Json -Depth 30
        }

    }
} catch {
    $revision = -1
    if (Test-Path -LiteralPath $statePath) {
        try { $revision = [int](Read-ArenaJson -Path $statePath).stateRevision } catch { $revision = -1 }
    }
    try { Add-ArenaEvent -StatePath $statePath -Command $Command -Outcome 'failure' -Revision $revision -Message $_.Exception.Message } catch {}
    Write-Error $_.Exception.Message
    exit 1
}
