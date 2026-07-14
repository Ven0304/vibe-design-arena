[CmdletBinding()]
param(
    [string]$BaseRoot = 'C:\tmp',
    [switch]$KeepArtifacts
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$scriptRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$arenaScript = Join-Path $scriptRoot 'arena.ps1'
$coreModule = Join-Path $scriptRoot 'lib\Arena.Core.psm1'
$utf8NoBom = New-Object Text.UTF8Encoding($false)
$succeeded = $false

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "ASSERTION FAILED: $Message" }
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
    $previousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = @(& git -C $Repository @Arguments 2>&1)
    } finally {
        $ErrorActionPreference = $previousPreference
    }
    $exitCode = $LASTEXITCODE
    $text = (($output | ForEach-Object { [string]$_ }) -join "`n").TrimEnd()
    if ($exitCode -ne 0 -and -not $AllowFailure) {
        throw "git -C `"$Repository`" $($Arguments -join ' ') failed ($exitCode): $text"
    }
    return [pscustomobject]@{ exitCode = $exitCode; output = $text }
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
            if ($i + 1 -lt $Additional.Count -and -not ([string]$Additional[$i + 1]).StartsWith('-')) {
                $boundParameters[$key] = $Additional[$i + 1]
                $i++
            } else {
                $boundParameters[$key] = $true
            }
        }
        $output = @(& $arenaScript $Command @boundParameters)
        $exitCode = 0
    }
    $text = (($output | ForEach-Object { [string]$_ }) -join "`n").Trim()
    if ($ExpectFailure) {
        Assert-True ($exitCode -ne 0) "$Command was expected to fail. Output: $text"
        return $text
    }
    if ($exitCode -ne 0) { throw "$Command failed ($exitCode): $text" }
    if ([string]::IsNullOrWhiteSpace($text)) { throw "$Command returned no JSON." }
    return $text | ConvertFrom-Json
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

    & git init --bare $remote | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Unable to create local bare remote.' }
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

    # Phase 1 owns select/merge/cleanup, while Phase 2 owns qualification imports.
    # This isolated smoke fixture advances only the test run to selection-ready so
    # the Phase 1 tail can be exercised without implementing Phase 2 early.
    Import-Module $coreModule -Force
    $fixture = Read-ArenaJson -Path $statePath
    foreach ($styleName in @('style-a', 'style-b', 'style-c')) {
        $styleState = $fixture.styles.PSObject.Properties[$styleName].Value
        $styleState.qualification.overall = 'PASS'
    }
    $fixture.stage = 'selection-ready'
    $fixture.status = 'ready'
    $fixture.stateRevision = [int]$fixture.stateRevision + 1
    $fixture.updatedAt = Get-ArenaUtcNow
    Write-ArenaJsonAtomic -Path $statePath -Value $fixture
    Add-ArenaEvent -StatePath $statePath -Command 'phase1-smoke-fixture' -Outcome 'info' -Revision $fixture.stateRevision -Message 'Test-only transition to selection-ready.'
    $state = $fixture

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

    $succeeded = $true
    [pscustomobject][ordered]@{
        status = 'PASS'
        testRoot = $testRootAbsolute
        finalRevision = $state.stateRevision
        finalStage = $state.stage
        selected = $state.selection.style
        retainedBranches = @('style-a', 'style-b', 'style-c')
        partiallyPublished = 'style-b'
    } | ConvertTo-Json -Depth 10
} finally {
    if ($succeeded -and -not $KeepArtifacts -and (Test-Path -LiteralPath $testRootAbsolute)) {
        $resolved = (Resolve-Path -LiteralPath $testRootAbsolute).Path
        if (-not $resolved.StartsWith($baseAbsolute + '\', [StringComparison]::OrdinalIgnoreCase) -or -not [IO.Path]::GetFileName($resolved).StartsWith('vda-phase1-')) {
            throw "Refusing unsafe smoke-test cleanup: $resolved"
        }
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}
