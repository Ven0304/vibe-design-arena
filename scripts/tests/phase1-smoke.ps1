[CmdletBinding()]
param(
    [string]$BaseRoot = 'C:\tmp',
    [switch]$KeepArtifacts
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$scriptRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$arenaScript = Join-Path $scriptRoot 'arena.ps1'
Import-Module (Join-Path $PSScriptRoot 'Smoke.TestHarness.psm1') -Force

$utf8NoBom = New-Object Text.UTF8Encoding($false)
$succeeded = $false
$finalResult = $null

function Assert-True {
    param([bool]$Condition, [string]$Message)
    Assert-SmokeCondition -Condition $Condition -Message $Message
}

function Write-TestFile {
    param([string]$Path, [string]$Content)
    $parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $parent)) { [IO.Directory]::CreateDirectory($parent) | Out-Null }
    [IO.File]::WriteAllText($Path, $Content.Replace("`r`n", "`n").Replace("`r", "`n"), $utf8NoBom)
}

function Write-TestJson {
    param([string]$Path, $Value)
    Write-TestFile -Path $Path -Content (($Value | ConvertTo-Json -Depth 50) + "`n")
}

function Invoke-TestGit {
    param([string]$Repository, [string[]]$Arguments, [switch]$AllowFailure)
    return Invoke-SmokeNativeProcess -Executable 'git.exe' -Arguments (@('-C', $Repository) + $Arguments) -AllowFailure:$AllowFailure -Description "git -C `"$Repository`" $($Arguments -join ' ')"
}

function Invoke-ArenaProcess {
    param([string]$Command, [string[]]$Additional = @(), [switch]$ExpectFailure)
    if ($ExpectFailure) {
        $arguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $arenaScript, $Command, '-State', $statePath) + $Additional
        $previousPreference = $ErrorActionPreference
        try {
            $ErrorActionPreference = 'Continue'
            $output = @(& powershell.exe @arguments 2>&1)
            $exitCode = $LASTEXITCODE
        } finally {
            $ErrorActionPreference = $previousPreference
        }
    } else {
        $boundParameters = @{ State = $statePath }
        for ($i = 0; $i -lt $Additional.Count; $i++) {
            $token = [string]$Additional[$i]
            if (-not $token.StartsWith('-')) { throw "Expected a named parameter, got: $token" }
            $key = $token.TrimStart('-')
            if ($key -in @('EvidenceIds','Branches')) {
                $values = @()
                while ($i + 1 -lt $Additional.Count -and -not ([string]$Additional[$i + 1]).StartsWith('-')) {
                    $values += $Additional[$i + 1]
                    $i++
                }
                if ($values.Count -eq 0) { throw "$key requires at least one value." }
                $boundParameters[$key] = $values
            } elseif ($i + 1 -lt $Additional.Count -and -not ([string]$Additional[$i + 1]).StartsWith('-')) {
                $boundParameters[$key] = $Additional[$i + 1]
                $i++
            } else {
                $boundParameters[$key] = $true
            }
        }
        try {
            $output = @(& $arenaScript $Command @boundParameters)
        } catch {
            throw "Arena command '$Command' failed: $($_.Exception.Message)"
        }
    }
    $text = (($output | ForEach-Object { [string]$_ }) -join "`n").Trim()
    if ($ExpectFailure) {
        Assert-True ($exitCode -ne 0) "$Command was expected to fail. Output: $text"
        return $text
    }
    return ConvertFrom-SmokeJson -Output $output -Description "Arena command '$Command'"
}

function New-TestQaResult {
    param($ArenaState, [string]$StyleName)
    $styleState = $ArenaState.styles.PSObject.Properties[$StyleName].Value
    $evidenceRoot = Join-Path $ArenaState.paths.recordsRoot "evidence\$StyleName"
    [IO.Directory]::CreateDirectory($evidenceRoot) | Out-Null
    $pngBytes = [Convert]::FromBase64String('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Y9Z3F8AAAAASUVORK5CYII=')
    $evidence = @(
        [pscustomobject][ordered]@{ id = "brief.$StyleName"; kind = 'design-brief'; description = 'Frozen design brief contract'; path = $styleState.brief.frozenPath; scenarioId = $null; viewportId = $null; route = $null }
    )
    foreach ($viewportId in @('mobile','tablet','desktop','desktop-equivalent-200-percent')) {
        $screenshotPath = Join-Path $evidenceRoot "$viewportId.png"
        [IO.File]::WriteAllBytes($screenshotPath, $pngBytes)
        $evidence += [pscustomobject][ordered]@{ id = "shot.$StyleName.$viewportId"; kind = 'screenshot'; description = "Qualification smoke screenshot $viewportId"; path = $screenshotPath; scenarioId = 'shared-smoke-evidence'; viewportId = $viewportId; route = $styleState.preview.url }
        $evidence += [pscustomobject][ordered]@{ id = "axe.$StyleName.$viewportId"; kind = 'axe'; description = "Qualification smoke axe result $viewportId"; path = $null; scenarioId = 'shared-smoke-evidence'; viewportId = $viewportId; route = $styleState.preview.url }
    }

    $checks = @()
    $standardViewports = @('mobile','tablet','desktop')
    $universalScenarios = @('primary','dense','touch-targets','keyboard-traversal','focus-visibility','focus-return','reduced-motion','rapid-toggle')
    foreach ($scenarioId in $universalScenarios) {
        foreach ($viewportId in $standardViewports) {
            $checks += [pscustomobject][ordered]@{
                id = "qa.$StyleName.$scenarioId.$viewportId"; scenarioId = $scenarioId; viewportId = $viewportId; applicability = 'required'; status = 'PASS'; reason = $null; approvedBy = $null
                evidenceIds = @("shot.$StyleName.$viewportId", "axe.$StyleName.$viewportId")
                assertions = @(
                    [pscustomobject]@{ id = "$scenarioId.$viewportId.overflow"; type = 'overflow'; status = 'PASS'; expected = $false; actual = $false },
                    [pscustomobject]@{ id = "$scenarioId.$viewportId.axe"; type = 'axe'; status = 'PASS'; expected = 0; actual = @() },
                    [pscustomobject]@{ id = "$scenarioId.$viewportId.browser"; type = 'browser-errors'; status = 'PASS'; expected = 0; actual = 0 }
                )
            }
        }
    }
    $proxyViewport = 'desktop-equivalent-200-percent'
    $checks += [pscustomobject][ordered]@{
        id = "qa.$StyleName.equivalent-200-percent-layout.$proxyViewport"; scenarioId = 'equivalent-200-percent-layout'; viewportId = $proxyViewport; applicability = 'required'; status = 'PASS'; reason = $null; approvedBy = $null
        evidenceIds = @("shot.$StyleName.$proxyViewport", "axe.$StyleName.$proxyViewport")
        assertions = @(
            [pscustomobject]@{ id = 'proxy.overflow'; type = 'overflow'; status = 'PASS'; expected = $false; actual = $false },
            [pscustomobject]@{ id = 'proxy.axe'; type = 'axe'; status = 'PASS'; expected = 0; actual = @() },
            [pscustomobject]@{ id = 'proxy.browser'; type = 'browser-errors'; status = 'PASS'; expected = 0; actual = 0 }
        )
    }
    foreach ($scenarioId in @('loading','empty','error','disabled','stale-data','long-text','missing-value','negative-number','extreme-number','container-overflow')) {
        $checks += [pscustomobject][ordered]@{ id = "qa.$StyleName.$scenarioId.not-applicable"; scenarioId = $scenarioId; viewportId = $null; applicability = 'not-applicable'; status = 'NOT-APPLICABLE'; reason = "Smoke product contract excludes $scenarioId behavior."; approvedBy = 'main-agent-smoke'; evidenceIds = @("brief.$StyleName"); assertions = @() }
    }

    return [pscustomobject][ordered]@{
        schemaVersion = '1.0'; arenaId = $ArenaState.arenaId; style = $StyleName; candidateGeneration = $styleState.candidateGeneration; candidateCommit = $styleState.implementationCommit
        generatedAt = [DateTime]::UtcNow.ToString('o'); configSha256 = ('0' * 64); baseUrl = $styleState.preview.url; outputRoot = $evidenceRoot
        overall = 'PASS'; environmentBlocked = $false; blocker = $null
        proxyDisclosure = [pscustomobject][ordered]@{ name = 'equivalent-200-percent-layout'; isRealBrowserZoom = $false; deviceScaleFactor = 1 }
        coverage = [pscustomobject][ordered]@{ required = 25; applicable = 0; notApplicable = 10; executed = 25; failed = 0 }
        checks = $checks; evidence = $evidence; browserErrors = @()
    }
}
function Get-FreePort {
    $listener = New-Object Net.Sockets.TcpListener([Net.IPAddress]::Loopback, 0)
    try {
        $listener.Start()
        return ([Net.IPEndPoint]$listener.LocalEndpoint).Port
    } finally {
        $listener.Stop()
    }
}

$baseAbsolute = [IO.Path]::GetFullPath($BaseRoot).TrimEnd('\')
[IO.Directory]::CreateDirectory($baseAbsolute) | Out-Null
$name = 'vda-phase1-中文 & long-segment-' + ('x' * 48) + '-' + [Guid]::NewGuid().ToString('N').Substring(0, 8)
$testRoot = Join-Path $baseAbsolute $name
$testRootAbsolute = [IO.Path]::GetFullPath($testRoot)
Assert-True ($testRootAbsolute.StartsWith($baseAbsolute + '\', [StringComparison]::OrdinalIgnoreCase)) 'Test root escaped BaseRoot.'
Assert-True ([IO.Path]::GetFileName($testRootAbsolute).StartsWith('vda-phase1-')) 'Unsafe test-root name.'

$repository = Join-Path $testRootAbsolute 'product repo'
$remote = Join-Path $testRootAbsolute 'remote.git'
$runRoot = Join-Path $testRootAbsolute 'arena run'
$recordsRoot = Join-Path $runRoot 'records'
$statePath = Join-Path $recordsRoot 'arena-state.json'
$configPath = Join-Path $testRootAbsolute 'arena-config.json'
$resultsRoot = Join-Path $testRootAbsolute 'builder results'

try {
    [IO.Directory]::CreateDirectory($repository) | Out-Null
    [IO.Directory]::CreateDirectory($resultsRoot) | Out-Null
    Invoke-TestGit -Repository $repository -Arguments @('init', '-b', 'main') | Out-Null
    Invoke-TestGit -Repository $repository -Arguments @('config', 'user.name', 'Arena Smoke Test') | Out-Null
    Invoke-TestGit -Repository $repository -Arguments @('config', 'user.email', 'arena-smoke@example.invalid') | Out-Null
    Invoke-TestGit -Repository $repository -Arguments @('config', 'core.autocrlf', 'true') | Out-Null

    Write-TestFile -Path (Join-Path $repository 'app.txt') -Content "baseline`n"
    Write-TestFile -Path (Join-Path $repository 'preview-server.mjs') -Content @'
import http from 'node:http';
const port = Number(process.argv[2]);
const server = http.createServer((_request, response) => {
  response.writeHead(200, { 'content-type': 'text/plain; charset=utf-8' });
  response.end('arena-preview-ok');
});
server.listen(port, '127.0.0.1');
'@
    Invoke-TestGit -Repository $repository -Arguments @('add', '--', 'app.txt', 'preview-server.mjs') | Out-Null
    Invoke-TestGit -Repository $repository -Arguments @('commit', '-m', 'Baseline product') | Out-Null
    $originalBaseline = (Invoke-TestGit -Repository $repository -Arguments @('rev-parse', 'HEAD')).output

    Invoke-SmokeNativeProcess -Executable 'git.exe' -Arguments @('init', '--bare', $remote) -Description 'Create local bare remote' | Out-Null
    Invoke-TestGit -Repository $repository -Arguments @('remote', 'add', 'origin', $remote) | Out-Null

    $ports = @()
    while ($ports.Count -lt 3) {
        $candidatePort = Get-FreePort
        if ($ports -notcontains $candidatePort) { $ports += $candidatePort }
    }
    $preview = [pscustomobject][ordered]@{}
    for ($i = 0; $i -lt 3; $i++) {
        $styleName = @('style-a', 'style-b', 'style-c')[$i]
        $spec = [pscustomobject][ordered]@{
            executable = 'node.exe'
            args = @((Join-Path $repository 'preview-server.mjs'), '{{PORT}}')
            port = $ports[$i]
            url = "http://127.0.0.1:$($ports[$i])"
            environment = [pscustomobject]@{}
        }
        $preview | Add-Member -NotePropertyName $styleName -NotePropertyValue $spec
    }
    $configuration = [pscustomobject][ordered]@{
        preview = $preview
        validation = @(
            [pscustomobject][ordered]@{
                executable = 'git.exe'
                args = @('diff', '--check', 'HEAD^', 'HEAD')
                environment = [pscustomobject]@{}
            }
        )
    }
    Write-TestJson -Path $configPath -Value $configuration

    $state = Invoke-ArenaProcess -Command 'preflight' -Additional @('-Repo', $repository, '-SkillRoot', (Split-Path -Parent $scriptRoot), '-Config', $configPath)
    Assert-True ($state.stage -eq 'preflight' -and $state.status -eq 'blocked') 'Initial preflight did not pause for .gitattributes approval.'
    Assert-True (Test-Path -LiteralPath (Join-Path $recordsRoot 'generated\gitattributes.patch')) 'Preflight patch draft is missing.'

    $state = Invoke-ArenaProcess -Command 'preflight' -Additional @('-ExpectedRevision', [string]$state.stateRevision, '-ApplyAttributes')
    Assert-True ($state.status -eq 'ready') 'Resumed preflight did not become ready.'
    $baseSha = (Invoke-TestGit -Repository $repository -Arguments @('rev-parse', 'HEAD')).output
    Assert-True ($state.repository.baseSha -eq $baseSha) 'Recorded BASE_SHA differs from product HEAD.'
    Assert-True ((Invoke-TestGit -Repository $repository -Arguments @('rev-parse', 'HEAD^')).output -eq $originalBaseline) '.gitattributes was not committed immediately after the original baseline.'
    Assert-True ((Invoke-TestGit -Repository $repository -Arguments @('show', '--format=', '--name-only', 'HEAD')).output.Trim() -eq '.gitattributes') 'Preflight baseline commit changed files other than .gitattributes.'
    $statusSnapshot = Invoke-ArenaProcess -Command 'status'
    Assert-True ($statusSnapshot.stateRevision -eq $state.stateRevision) 'Read-only status changed or misreported stateRevision.'
    Assert-True ($statusSnapshot.stage -eq $state.stage -and $statusSnapshot.status -eq $state.status) 'Status summary drifted from Arena state.'

    foreach ($styleName in @('style-a', 'style-b', 'style-c')) {
        $briefPath = Join-Path $recordsRoot "briefs\$styleName\DESIGN_BRIEF.md"
        Write-TestFile -Path $briefPath -Content "# $styleName`n`nDirection: independently designed $styleName.`n"
    }
    $state = Invoke-ArenaProcess -Command 'create-worktrees' -Additional @('-ExpectedRevision', [string]$state.stateRevision)
    Assert-True ($state.stage -eq 'worktrees-ready') 'Worktrees were not created.'
    foreach ($styleName in @('style-a', 'style-b', 'style-c')) {
        $styleState = $state.styles.PSObject.Properties[$styleName].Value
        Assert-True (Test-Path -LiteralPath $styleState.worktree) "$styleName worktree is missing."
        $briefParent = (Invoke-TestGit -Repository $styleState.worktree -Arguments @('rev-parse', 'HEAD^')).output
        Assert-True ($briefParent -eq $baseSha) "$styleName was not created from final BASE_SHA."
    }

    $builderPaths = @{}
    foreach ($styleName in @('style-a', 'style-b', 'style-c')) {
        $styleState = $state.styles.PSObject.Properties[$styleName].Value
        Write-TestFile -Path (Join-Path $styleState.worktree 'style.txt') -Content "$styleName implementation`n"
        Invoke-TestGit -Repository $styleState.worktree -Arguments @('add', '--', 'style.txt') | Out-Null
        Invoke-TestGit -Repository $styleState.worktree -Arguments @('commit', '-m', "Implement $styleName") | Out-Null
        $implementationCommit = (Invoke-TestGit -Repository $styleState.worktree -Arguments @('rev-parse', 'HEAD')).output
        $builder = [pscustomobject][ordered]@{
            schemaVersion = '1.0'
            arenaId = $state.arenaId
            style = $styleName
            dispatchId = $styleState.dispatchId
            candidateGeneration = $styleState.candidateGeneration
            branch = $styleState.branch
            briefCommit = $styleState.brief.commit
            briefSha256 = $styleState.brief.approvedSha256
            implementationCommit = $implementationCommit
            validation = [pscustomobject]@{ overall = 'PASS'; commands = @() }
            changedFiles = @('style.txt')
            risks = @()
        }
        $builderPath = Join-Path $resultsRoot "$styleName-builder-result.json"
        Write-TestJson -Path $builderPath -Value $builder
        $builderPaths[$styleName] = $builderPath
        $state = Invoke-ArenaProcess -Command 'import-builder-result' -Additional @('-ExpectedRevision', [string]$state.stateRevision, '-ResultPath', $builderPath)
    }
    Assert-True ($state.stage -eq 'building') 'Builder imports did not enter building stage.'

    $stale = [IO.File]::ReadAllText($builderPaths['style-a'], [Text.Encoding]::UTF8) | ConvertFrom-Json
    $stale.dispatchId = 'stale-dispatch-id'
    $stalePath = Join-Path $resultsRoot 'stale-builder-result.json'
    Write-TestJson -Path $stalePath -Value $stale
    $null = Invoke-ArenaProcess -Command 'import-builder-result' -Additional @('-ExpectedRevision', [string]$state.stateRevision, '-ResultPath', $stalePath) -ExpectFailure
    $afterStale = [IO.File]::ReadAllText($statePath, [Text.Encoding]::UTF8) | ConvertFrom-Json
    Assert-True ([int]$afterStale.stateRevision -eq [int]$state.stateRevision) 'Rejected stale builder result changed state revision.'

    $null = Invoke-ArenaProcess -Command 'stop-previews' -Additional @('-ExpectedRevision', [string]([int]$state.stateRevision - 1)) -ExpectFailure
    $afterConflict = [IO.File]::ReadAllText($statePath, [Text.Encoding]::UTF8) | ConvertFrom-Json
    Assert-True ([int]$afterConflict.stateRevision -eq [int]$state.stateRevision) 'Revision conflict changed machine state.'

    $state = Invoke-ArenaProcess -Command 'start-previews' -Additional @('-ExpectedRevision', [string]$state.stateRevision)
    if ($state.stage -ne 'previews-ready' -and $state.status -eq 'blocked') {
        $state = Invoke-ArenaProcess -Command 'start-previews' -Additional @('-ExpectedRevision', [string]$state.stateRevision)
    }
    Assert-True ($state.stage -eq 'previews-ready') 'All previews did not become ready after the idempotent re-probe.'
    foreach ($styleName in @('style-a', 'style-b', 'style-c')) {
        $styleState = $state.styles.PSObject.Properties[$styleName].Value
        Assert-True ([int]$styleState.preview.httpStatus -eq 200) "$styleName preview HTTP probe failed."
        Assert-True ($null -ne (Get-Process -Id ([int]$styleState.preview.pid) -ErrorAction SilentlyContinue)) "$styleName preview process is missing."
    }

    $lockPath = $statePath + '.lock'
    $lockHandle = [IO.File]::Open($lockPath, [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
    try {
        $null = Invoke-ArenaProcess -Command 'stop-previews' -Additional @('-ExpectedRevision', [string]$state.stateRevision) -ExpectFailure
    } finally {
        $lockHandle.Dispose()
    }
    $state = Invoke-ArenaProcess -Command 'stop-previews' -Additional @('-ExpectedRevision', [string]$state.stateRevision)
    foreach ($styleName in @('style-a', 'style-b', 'style-c')) {
        Assert-True (-not $state.styles.PSObject.Properties[$styleName].Value.preview.pid) "$styleName preview PID was not cleared."
    }

    # Phase 2 qualification must advance only through public Arena commands.
    $qaResults = @{}
    foreach ($styleName in @('style-a', 'style-b', 'style-c')) {
        $qaResult = New-TestQaResult -ArenaState $state -StyleName $styleName
        $qaPath = Join-Path $state.paths.recordsRoot "evidence\$styleName\qa-results.json"
        Write-TestJson -Path $qaPath -Value $qaResult
        $qaResults[$styleName] = [pscustomobject]@{ path = $qaPath; result = $qaResult }
    }

    $blockedQa = $qaResults['style-a'].result | ConvertTo-Json -Depth 50 | ConvertFrom-Json
    $blockedQa.overall = 'BLOCKED'
    $blockedQa.environmentBlocked = $true
    $blockedQa.blocker = 'Smoke fixture simulates a Playwright environment blocker.'
    $blockedQa.coverage.required = 1
    $blockedQa.coverage.notApplicable = 0
    $blockedQa.coverage.executed = 1
    $blockedQa.coverage.failed = 1
    $blockedQa.checks = @([pscustomobject][ordered]@{ id = 'qa.environment.dependencies'; scenarioId = 'environment'; viewportId = $null; applicability = 'required'; status = 'BLOCKED'; reason = $blockedQa.blocker; approvedBy = $null; evidenceIds = @(); assertions = @() })
    Write-TestJson -Path $qaResults['style-a'].path -Value $blockedQa
    $state = Invoke-ArenaProcess -Command 'import-qa-result' -Additional @('-ExpectedRevision', [string]$state.stateRevision, '-ResultPath', $qaResults['style-a'].path)
    Assert-True ($state.status -eq 'blocked' -and $state.styles.'style-a'.qualification.automatedQa -eq 'BLOCKED') 'Environment blocker was misclassified as a design failure.'

    $invalidNa = $qaResults['style-a'].result | ConvertTo-Json -Depth 50 | ConvertFrom-Json
    ($invalidNa.checks | Where-Object { $_.scenarioId -eq 'stale-data' }).reason = ''
    Write-TestJson -Path $qaResults['style-a'].path -Value $invalidNa
    $null = Invoke-ArenaProcess -Command 'import-qa-result' -Additional @('-ExpectedRevision', [string]$state.stateRevision, '-ResultPath', $qaResults['style-a'].path) -ExpectFailure
    $afterInvalidNa = [IO.File]::ReadAllText($statePath, [Text.Encoding]::UTF8) | ConvertFrom-Json
    Assert-True ([int]$afterInvalidNa.stateRevision -eq [int]$state.stateRevision) 'Invalid N/A changed state revision.'

    $staleQa = $qaResults['style-a'].result | ConvertTo-Json -Depth 50 | ConvertFrom-Json
    $staleQa.candidateCommit = ('0' * 40)
    Write-TestJson -Path $qaResults['style-a'].path -Value $staleQa
    $null = Invoke-ArenaProcess -Command 'import-qa-result' -Additional @('-ExpectedRevision', [string]$state.stateRevision, '-ResultPath', $qaResults['style-a'].path) -ExpectFailure
    $afterStaleQa = [IO.File]::ReadAllText($statePath, [Text.Encoding]::UTF8) | ConvertFrom-Json
    Assert-True ([int]$afterStaleQa.stateRevision -eq [int]$state.stateRevision) 'Stale QA result changed state revision.'

    foreach ($styleName in @('style-a', 'style-b', 'style-c')) {
        Write-TestJson -Path $qaResults[$styleName].path -Value $qaResults[$styleName].result
        $state = Invoke-ArenaProcess -Command 'import-qa-result' -Additional @('-ExpectedRevision', [string]$state.stateRevision, '-ResultPath', $qaResults[$styleName].path)
        $styleState = $state.styles.PSObject.Properties[$styleName].Value
        Assert-True ($styleState.qualification.automatedQa -eq 'PASS') "$styleName QA was not imported as PASS."

        if ($styleName -eq 'style-a') {
            $null = Invoke-ArenaProcess -Command 'sign-visual-review' -Additional @('-ExpectedRevision', [string]$state.stateRevision, '-Style', $styleName, '-Result', 'PASS', '-Reviewer', 'main-agent-smoke', '-CandidateCommit', $styleState.implementationCommit, '-EvidenceIds', 'unknown-evidence') -ExpectFailure
            $afterUnknownEvidence = [IO.File]::ReadAllText($statePath, [Text.Encoding]::UTF8) | ConvertFrom-Json
            Assert-True ([int]$afterUnknownEvidence.stateRevision -eq [int]$state.stateRevision) 'Unknown review evidence changed state revision.'
            $null = Invoke-ArenaProcess -Command 'sign-visual-review' -Additional @('-ExpectedRevision', [string]$state.stateRevision, '-Style', $styleName, '-Result', 'PASS', '-Reviewer', 'main-agent-smoke', '-CandidateCommit', ('0' * 40), '-EvidenceIds', "shot.$styleName.mobile") -ExpectFailure
            $afterStaleReview = [IO.File]::ReadAllText($statePath, [Text.Encoding]::UTF8) | ConvertFrom-Json
            Assert-True ([int]$afterStaleReview.stateRevision -eq [int]$state.stateRevision) 'Stale review signature changed state revision.'
        }

        $visualEvidence = @("shot.$styleName.mobile", "shot.$styleName.tablet", "shot.$styleName.desktop")
        $state = Invoke-ArenaProcess -Command 'sign-visual-review' -Additional (@('-ExpectedRevision', [string]$state.stateRevision, '-Style', $styleName, '-Result', 'PASS', '-Reviewer', 'main-agent-smoke', '-CandidateCommit', $styleState.implementationCommit, '-EvidenceIds') + $visualEvidence)
        $directionEvidence = @("shot.$styleName.desktop", "brief.$styleName")
        $state = Invoke-ArenaProcess -Command 'sign-direction-review' -Additional (@('-ExpectedRevision', [string]$state.stateRevision, '-Style', $styleName, '-Result', 'PASS', '-Reviewer', 'main-agent-smoke', '-CandidateCommit', $styleState.implementationCommit, '-EvidenceIds') + $directionEvidence)
        $state = Invoke-ArenaProcess -Command 'qualify' -Additional @('-ExpectedRevision', [string]$state.stateRevision, '-Style', $styleName)
        Assert-True ($state.styles.PSObject.Properties[$styleName].Value.qualification.overall -eq 'PASS') "$styleName did not pass all five qualification gates."

        if ($styleName -eq 'style-a') {
            $styleState = $state.styles.PSObject.Properties[$styleName].Value
            Write-TestFile -Path (Join-Path $styleState.worktree 'revision.txt') -Content "candidate revision invalidates prior signatures`n"
            Invoke-TestGit -Repository $styleState.worktree -Arguments @('add', '--', 'revision.txt') | Out-Null
            Invoke-TestGit -Repository $styleState.worktree -Arguments @('commit', '-m', 'Revise style-a after qualification') | Out-Null
            $revisedCommit = (Invoke-TestGit -Repository $styleState.worktree -Arguments @('rev-parse', 'HEAD')).output
            $state = Invoke-ArenaProcess -Command 'qualify' -Additional @('-ExpectedRevision', [string]$state.stateRevision, '-Style', $styleName)
            $invalidated = $state.styles.PSObject.Properties[$styleName].Value
            Assert-True ($state.stage -eq 'building' -and $state.status -eq 'blocked') 'Changed candidate did not return to building.'
            Assert-True ($invalidated.qualification.automatedQa -eq 'PENDING' -and $invalidated.reviews.visual.status -eq 'PENDING' -and $invalidated.reviews.direction.status -eq 'PENDING') 'Changed candidate retained stale QA or review signatures.'

            $revisedBuilder = [IO.File]::ReadAllText($builderPaths[$styleName], [Text.Encoding]::UTF8) | ConvertFrom-Json
            $revisedBuilder.implementationCommit = $revisedCommit
            $revisedBuilder.changedFiles = @('style.txt', 'revision.txt')
            Write-TestJson -Path $builderPaths[$styleName] -Value $revisedBuilder
            $state = Invoke-ArenaProcess -Command 'import-builder-result' -Additional @('-ExpectedRevision', [string]$state.stateRevision, '-ResultPath', $builderPaths[$styleName])
            $state = Invoke-ArenaProcess -Command 'start-previews' -Additional @('-ExpectedRevision', [string]$state.stateRevision)
            if ($state.stage -ne 'previews-ready' -and $state.status -eq 'blocked') {
                $state = Invoke-ArenaProcess -Command 'start-previews' -Additional @('-ExpectedRevision', [string]$state.stateRevision)
            }
            Assert-True ($state.stage -eq 'previews-ready') 'Revised candidate previews did not become ready.'
            $state = Invoke-ArenaProcess -Command 'stop-previews' -Additional @('-ExpectedRevision', [string]$state.stateRevision)

            $revisedQa = New-TestQaResult -ArenaState $state -StyleName $styleName
            $qaResults[$styleName] = [pscustomobject]@{ path = $qaResults[$styleName].path; result = $revisedQa }
            Write-TestJson -Path $qaResults[$styleName].path -Value $revisedQa
            $state = Invoke-ArenaProcess -Command 'import-qa-result' -Additional @('-ExpectedRevision', [string]$state.stateRevision, '-ResultPath', $qaResults[$styleName].path)
            $styleState = $state.styles.PSObject.Properties[$styleName].Value
            $visualEvidence = @("shot.$styleName.mobile", "shot.$styleName.tablet", "shot.$styleName.desktop")
            $state = Invoke-ArenaProcess -Command 'sign-visual-review' -Additional (@('-ExpectedRevision', [string]$state.stateRevision, '-Style', $styleName, '-Result', 'PASS', '-Reviewer', 'main-agent-smoke', '-CandidateCommit', $styleState.implementationCommit, '-EvidenceIds') + $visualEvidence)
            $directionEvidence = @("shot.$styleName.desktop", "brief.$styleName")
            $state = Invoke-ArenaProcess -Command 'sign-direction-review' -Additional (@('-ExpectedRevision', [string]$state.stateRevision, '-Style', $styleName, '-Result', 'PASS', '-Reviewer', 'main-agent-smoke', '-CandidateCommit', $styleState.implementationCommit, '-EvidenceIds') + $directionEvidence)
            $state = Invoke-ArenaProcess -Command 'qualify' -Additional @('-ExpectedRevision', [string]$state.stateRevision, '-Style', $styleName)
            Assert-True ($state.styles.PSObject.Properties[$styleName].Value.qualification.overall -eq 'PASS') 'Revised style-a did not requalify through fresh QA and signatures.'
        }
    }
    Assert-True ($state.stage -eq 'selection-ready') 'Three qualified candidates did not enter selection-ready.'

    $state = Invoke-ArenaProcess -Command 'select' -Additional @('-ExpectedRevision', [string]$state.stateRevision, '-Style', 'style-a')
    Assert-True ($state.stage -eq 'selected') 'Winner selection was not recorded.'
    $state = Invoke-ArenaProcess -Command 'merge' -Additional @('-ExpectedRevision', [string]$state.stateRevision)
    Assert-True ($state.stage -eq 'merged' -and $state.merge.status -eq 'PASS') 'Selected branch did not merge and validate.'
    $state = Invoke-ArenaProcess -Command 'cleanup' -Additional @('-ExpectedRevision', [string]$state.stateRevision)
    Assert-True ($state.stage -eq 'complete') 'Cleanup did not reach complete.'
    foreach ($styleName in @('style-a', 'style-b', 'style-c')) {
        $styleState = $state.styles.PSObject.Properties[$styleName].Value
        Assert-True (-not (Test-Path -LiteralPath $styleState.worktree)) "$styleName worktree remains after cleanup."
        $branchResult = Invoke-TestGit -Repository $repository -Arguments @('show-ref', '--verify', "refs/heads/$($styleState.branch)") -AllowFailure
        Assert-True ($branchResult.exitCode -eq 0) "$styleName branch was deleted by cleanup."
    }
    Assert-True (Test-Path -LiteralPath $recordsRoot) 'Cleanup removed Arena records.'

    $plan = Invoke-ArenaProcess -Command 'publish-plan' -Additional @('-Remote', 'origin', '-Branches', 'style-b')
    Assert-True ($plan.branches[0].action -eq 'push') 'Publish plan did not detect unpublished style-b.'
    $state = Invoke-ArenaProcess -Command 'publish' -Additional @('-ExpectedRevision', [string]$state.stateRevision, '-Remote', 'origin', '-Branches', 'style-b', '-ConfirmPublish')
    Assert-True ($state.publication.'style-b'.published) 'style-b publication state was not updated.'
    Assert-True (-not $state.publication.main.published -and -not $state.publication.'style-a'.published -and -not $state.publication.'style-c'.published) 'Partial publication incorrectly marked other branches as published.'

    $state = Invoke-ArenaProcess -Command 'handoff-docs' -Additional @('-ExpectedRevision', [string]$state.stateRevision)
    Assert-True (Test-Path -LiteralPath $state.handoff.patchPath) 'Handoff README patch draft is missing.'
    Assert-True (@(Get-ChildItem -LiteralPath $recordsRoot -Filter '*.tmp' -Recurse -Force).Count -eq 0) 'Atomic state writes left temporary files.'
    Assert-True ((Get-Content -LiteralPath (Join-Path $recordsRoot 'events.jsonl') -Encoding utf8).Count -ge 10) 'Event log is unexpectedly incomplete.'

    $finalResult = [pscustomobject][ordered]@{
        status = 'PASS'
        testRoot = $testRootAbsolute
        finalRevision = $state.stateRevision
        finalStage = $state.stage
        selected = $state.selection.style
        retainedBranches = @('style-a', 'style-b', 'style-c')
        partiallyPublished = 'style-b'
    }
    $succeeded = $true
} finally {
    if ($succeeded -and -not $KeepArtifacts -and (Test-Path -LiteralPath $testRootAbsolute)) {
        $resolved = (Resolve-Path -LiteralPath $testRootAbsolute).Path
        if (-not $resolved.StartsWith($baseAbsolute + '\', [StringComparison]::OrdinalIgnoreCase) -or -not [IO.Path]::GetFileName($resolved).StartsWith('vda-phase1-')) {
            throw "Refusing unsafe smoke-test cleanup: $resolved"
        }
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}

$finalResult | ConvertTo-Json -Depth 10
