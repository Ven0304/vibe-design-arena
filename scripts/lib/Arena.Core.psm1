Set-StrictMode -Version 2.0

$script:Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$script:StageOrder = @('preflight','briefs-approved','worktrees-ready','building','previews-ready','qualifying','selection-ready','selected','merged','cleaned','complete')

function Get-ArenaUtcNow { return [DateTime]::UtcNow.ToString('o') }

function Write-ArenaUtf8NoBom {
    param([Parameter(Mandatory=$true)][string]$Path,[Parameter(Mandatory=$true)][AllowEmptyString()][string]$Content)
    $parent = Split-Path -Parent $Path
    if ($parent -and -not (Test-Path -LiteralPath $parent)) { [IO.Directory]::CreateDirectory($parent) | Out-Null }
    [IO.File]::WriteAllText($Path,$Content,$script:Utf8NoBom)
}

function Read-ArenaJson {
    param([Parameter(Mandatory=$true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "JSON file not found: $Path" }
    $raw = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $Path).Path,[Text.Encoding]::UTF8)
    return $raw | ConvertFrom-Json
}

function Write-ArenaJsonAtomic {
    param([Parameter(Mandatory=$true)][string]$Path,[Parameter(Mandatory=$true)]$Value)
    $absolute = [IO.Path]::GetFullPath($Path)
    $parent = Split-Path -Parent $absolute
    if (-not (Test-Path -LiteralPath $parent)) { [IO.Directory]::CreateDirectory($parent) | Out-Null }
    $temporary = Join-Path $parent ('.' + [IO.Path]::GetFileName($absolute) + '.' + [Guid]::NewGuid().ToString('N') + '.tmp')
    try {
        [IO.File]::WriteAllText($temporary,($Value | ConvertTo-Json -Depth 100) + "`n",$script:Utf8NoBom)
        if (Test-Path -LiteralPath $absolute) {
            $backup = $absolute + '.bak'
            try {
                [IO.File]::Replace($temporary,$absolute,$backup,$true)
                if (Test-Path -LiteralPath $backup) { Remove-Item -LiteralPath $backup -Force }
            } catch { Move-Item -LiteralPath $temporary -Destination $absolute -Force }
        } else { Move-Item -LiteralPath $temporary -Destination $absolute }
    } finally { if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary -Force } }
}

function Open-ArenaStateLock {
    param([Parameter(Mandatory=$true)][string]$StatePath)
    $lockPath = [IO.Path]::GetFullPath($StatePath) + '.lock'
    $parent = Split-Path -Parent $lockPath
    if (-not (Test-Path -LiteralPath $parent)) { [IO.Directory]::CreateDirectory($parent) | Out-Null }
    try { return [IO.File]::Open($lockPath,[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None) }
    catch { throw "Arena state is locked by another writer: $lockPath" }
}

function Close-ArenaStateLock { param($LockHandle); if ($null -ne $LockHandle) { $LockHandle.Dispose() } }

function Add-ArenaEvent {
    param(
        [Parameter(Mandatory=$true)][string]$StatePath,
        [Parameter(Mandatory=$true)][string]$Command,
        [Parameter(Mandatory=$true)][ValidateSet('success','failure','blocked','info')][string]$Outcome,
        [int]$Revision=-1,[string]$Message='',$Details=$null
    )
    $recordsRoot = Split-Path -Parent ([IO.Path]::GetFullPath($StatePath))
    if (-not (Test-Path -LiteralPath $recordsRoot)) { return }
    $event = [ordered]@{ timestamp=Get-ArenaUtcNow; command=$Command; outcome=$Outcome; stateRevision=$Revision; message=$Message; details=$Details }
    [IO.File]::AppendAllText((Join-Path $recordsRoot 'events.jsonl'),($event | ConvertTo-Json -Depth 30 -Compress) + "`n",$script:Utf8NoBom)
}

function Get-ArenaSha256 {
    param([Parameter(Mandatory=$true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "File not found for SHA-256: $Path" }
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Invoke-ArenaGit {
    param([Parameter(Mandatory=$true)][string]$Repository,[Parameter(Mandatory=$true)][string[]]$Arguments,[switch]$AllowFailure)
    $previousPreference=$ErrorActionPreference
    try {
        $ErrorActionPreference='Continue'
        $output = @(& git -C $Repository @Arguments 2>&1)
    } finally {
        $ErrorActionPreference=$previousPreference
    }
    $exitCode = $LASTEXITCODE
    $text = (($output | ForEach-Object { [string]$_ }) -join "`n").TrimEnd()
    $result = [pscustomobject]@{ exitCode=$exitCode; output=$text }
    if ($exitCode -ne 0 -and -not $AllowFailure) { throw "git -C `"$Repository`" $($Arguments -join ' ') failed ($exitCode): $text" }
    return $result
}

function Get-ArenaGitBlobSha256 {
    param([Parameter(Mandatory=$true)][string]$Repository,[Parameter(Mandatory=$true)][string]$Commit,[string]$Path='DESIGN_BRIEF.md')
    $temporary = [IO.Path]::GetTempFileName()
    try {
        $psi = New-Object Diagnostics.ProcessStartInfo
        $psi.FileName = 'git.exe'
        $psi.WorkingDirectory = (Resolve-Path -LiteralPath $Repository).Path
        $psi.Arguments = 'cat-file blob "' + $Commit + ':' + $Path.Replace('"','\"') + '"'
        $psi.UseShellExecute = $false; $psi.RedirectStandardOutput = $true; $psi.RedirectStandardError = $true; $psi.CreateNoWindow = $true
        $process = New-Object Diagnostics.Process; $process.StartInfo = $psi
        if (-not $process.Start()) { throw 'Unable to start git cat-file.' }
        $stream = [IO.File]::Open($temporary,[IO.FileMode]::Create,[IO.FileAccess]::Write,[IO.FileShare]::None)
        try { $process.StandardOutput.BaseStream.CopyTo($stream) } finally { $stream.Dispose() }
        $errorText = $process.StandardError.ReadToEnd(); $process.WaitForExit()
        if ($process.ExitCode -ne 0) { throw "git cat-file failed: $errorText" }
        return Get-ArenaSha256 -Path $temporary
    } finally { if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary -Force } }
}

function Resolve-ArenaAbsolutePath {
    param([Parameter(Mandatory=$true)][string]$Path,[switch]$MustExist)
    if ($MustExist) { return (Resolve-Path -LiteralPath $Path).Path }
    return [IO.Path]::GetFullPath($Path)
}

function Assert-ArenaChildPath {
    param([Parameter(Mandatory=$true)][string]$Root,[Parameter(Mandatory=$true)][string]$Candidate)
    $rootPath = [IO.Path]::GetFullPath($Root).TrimEnd([IO.Path]::DirectorySeparatorChar,[IO.Path]::AltDirectorySeparatorChar)
    $candidatePath = [IO.Path]::GetFullPath($Candidate)
    if (-not $candidatePath.StartsWith($rootPath + [IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) {
        throw "Path is outside the approved root. Root=$rootPath Candidate=$candidatePath"
    }
    return $candidatePath
}

function Test-ArenaCanonicalUtf8Lf {
    param([Parameter(Mandatory=$true)][string]$Path)
    $bytes = [IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $Path).Path)
    $hasBom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
    $strictUtf8 = New-Object Text.UTF8Encoding($false,$true)
    try { $text=$strictUtf8.GetString($bytes); $validUtf8=$true } catch { $text=''; $validUtf8=$false }
    return [pscustomobject]@{
        path=[IO.Path]::GetFullPath($Path); validUtf8=$validUtf8; hasBom=$hasBom
        hasCrLf=$validUtf8 -and $text.Contains("`r`n")
        hasBareCr=$validUtf8 -and ($text.Replace("`r`n",'')).Contains("`r")
        canonical=$validUtf8 -and -not $hasBom -and -not $text.Contains("`r")
        sha256=Get-ArenaSha256 -Path $Path
    }
}

function ConvertTo-ArenaCanonicalUtf8Lf {
    param([Parameter(Mandatory=$true)][string]$Path,[switch]$Write)
    $absolute=(Resolve-Path -LiteralPath $Path).Path; $bytes=[IO.File]::ReadAllBytes($absolute); $strictUtf8=New-Object Text.UTF8Encoding($false,$true)
    $offset=0; if($bytes.Length -ge 3 -and $bytes[0]-eq 0xEF -and $bytes[1]-eq 0xBB -and $bytes[2]-eq 0xBF){$offset=3}
    $text=$strictUtf8.GetString($bytes,$offset,$bytes.Length-$offset); $canonical=$text.Replace("`r`n","`n").Replace("`r","`n"); $changed=$offset -gt 0 -or $canonical -cne $text
    if($Write -and $changed){[IO.File]::WriteAllText($absolute,$canonical,$script:Utf8NoBom)}
    return [pscustomobject]@{path=$absolute;changed=$changed;written=[bool]$Write;sha256=if($Write){Get-ArenaSha256 -Path $absolute}else{$null}}
}

function Test-ArenaBriefAttribute {
    param([Parameter(Mandatory=$true)][string]$Repository)
    $result=Invoke-ArenaGit -Repository $Repository -Arguments @('check-attr','text','eol','--','DESIGN_BRIEF.md') -AllowFailure
    return [pscustomobject]@{
        valid=$result.exitCode -eq 0 -and $result.output -match 'DESIGN_BRIEF\.md: text: set' -and $result.output -match 'DESIGN_BRIEF\.md: eol: lf'
        output=$result.output;requiredRule='/DESIGN_BRIEF.md text eol=lf'
    }
}

function Add-ArenaBriefAttributeRule {
    param([Parameter(Mandatory=$true)][string]$Repository)
    $path=Join-Path $Repository '.gitattributes'; $rule='/DESIGN_BRIEF.md text eol=lf'; $lines=@()
    if(Test-Path -LiteralPath $path){$lines=@([IO.File]::ReadAllLines($path,[Text.Encoding]::UTF8))}
    if($lines -notcontains $rule){Write-ArenaUtf8NoBom -Path $path -Content ((($lines+$rule)-join "`n").TrimEnd("`n")+"`n")}
    return $path
}

function Get-ArenaReferenceSnapshot {
    param([Parameter(Mandatory=$true)][string]$SkillRoot,[Parameter(Mandatory=$true)][string[]]$Files)
    $root=(Resolve-Path -LiteralPath $SkillRoot).Path; $entries=@()
    foreach($relative in $Files){$path=Join-Path $root $relative;if(-not(Test-Path -LiteralPath $path -PathType Leaf)){throw "Reference file not found: $path"};$entries+=[pscustomobject]@{relativePath=$relative.Replace('\','/');absolutePath=(Resolve-Path -LiteralPath $path).Path;sha256=Get-ArenaSha256 -Path $path}}
    $gitRootResult=Invoke-ArenaGit -Repository $root -Arguments @('rev-parse','--show-toplevel') -AllowFailure;$provenance='NO-GIT/HASHED';$gitRoot=$null
    if($gitRootResult.exitCode -eq 0){$gitRoot=$gitRootResult.output;$commit=(Invoke-ArenaGit -Repository $root -Arguments @('rev-parse','HEAD')).output;$dirty=(Invoke-ArenaGit -Repository $root -Arguments @('status','--short','--','SKILL.md','references','scripts')).output;$provenance=if([string]::IsNullOrWhiteSpace($dirty)){$commit}else{'DIRTY-GIT/HASHED'}}
    $material=($entries|ForEach-Object{$_.relativePath+':'+$_.sha256})-join'|';$sha=[Security.Cryptography.SHA256]::Create()
    try{$snapshotId=([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($material)))).Replace('-','').ToLowerInvariant().Substring(0,16)}finally{$sha.Dispose()}
    return [pscustomobject]@{snapshotId=$snapshotId;skillRoot=$root;gitRoot=$gitRoot;provenance=$provenance;files=$entries}
}

function Invoke-ArenaCommandSpec {
    param([Parameter(Mandatory=$true)]$Spec,[string]$DefaultWorkingDirectory)
    if(-not $Spec.PSObject.Properties['executable'] -or -not $Spec.executable){throw 'Command spec requires executable.'};$workingDirectory=if($Spec.PSObject.Properties['workingDirectory'] -and $Spec.workingDirectory){[string]$Spec.workingDirectory}else{$DefaultWorkingDirectory};if(-not $workingDirectory){throw 'Command spec requires workingDirectory.'}
    $arguments=@();if($Spec.PSObject.Properties['args'] -and $Spec.args){$arguments=@($Spec.args|ForEach-Object{[string]$_})};$saved=@{}
    $environmentProperties=@();if($Spec.PSObject.Properties['environment'] -and $Spec.environment){$environmentProperties=@($Spec.environment.PSObject.Properties)}
    $duplicates=@($environmentProperties|Group-Object -Property{$_.Name.ToUpperInvariant()}|Where-Object{$_.Count-gt 1})
    if($duplicates.Count-gt 0){throw "Command environment contains duplicate case-insensitive keys: $(@($duplicates.Name)-join ', ')"}
    foreach($property in $environmentProperties){$saved[$property.Name]=[Environment]::GetEnvironmentVariable($property.Name,'Process');[Environment]::SetEnvironmentVariable($property.Name,[string]$property.Value,'Process')}
    try{
        $startedAt=Get-ArenaUtcNow;Push-Location -LiteralPath $workingDirectory;$previousPreference=$ErrorActionPreference
        try{$ErrorActionPreference='Continue';$output=@(& ([string]$Spec.executable) @arguments 2>&1);$exitCode=$LASTEXITCODE}finally{$ErrorActionPreference=$previousPreference;Pop-Location}
        return [pscustomobject]@{executable=[string]$Spec.executable;args=$arguments;workingDirectory=$workingDirectory;startedAt=$startedAt;completedAt=Get-ArenaUtcNow;exitCode=$exitCode;status=if($exitCode-eq 0){'PASS'}else{'FAIL'};output=(($output|ForEach-Object{[string]$_})-join"`n").TrimEnd()}
    }finally{foreach($name in $saved.Keys){[Environment]::SetEnvironmentVariable($name,$saved[$name],'Process')}}
}

function Get-ArenaStageIndex { param([Parameter(Mandatory=$true)][string]$Stage);$index=[Array]::IndexOf($script:StageOrder,$Stage);if($index-lt 0){throw "Unknown Arena stage: $Stage"};return $index }
function Set-ArenaProperty { param([Parameter(Mandatory=$true)]$Object,[Parameter(Mandatory=$true)][string]$Name,$Value);$Object|Add-Member -NotePropertyName $Name -NotePropertyValue $Value -Force }

function Write-ArenaDerivedRecords {
    param([Parameter(Mandatory=$true)]$State,[Parameter(Mandatory=$true)][string]$StatePath)
    $recordsRoot=Split-Path -Parent([IO.Path]::GetFullPath($StatePath));$generatedRoot=Join-Path $recordsRoot 'generated';$candidateRoot=Join-Path $recordsRoot 'candidates';[IO.Directory]::CreateDirectory($generatedRoot)|Out-Null;[IO.Directory]::CreateDirectory($candidateRoot)|Out-Null
    $record=@('# Vibe Design Arena Record','',"- Arena ID: $($State.arenaId)","- State revision: $($State.stateRevision)","- Stage: $($State.stage)","- Status: $($State.status)","- Product repository: $($State.repository.root)","- Base branch: $($State.repository.baseBranch)","- Base SHA: $($State.repository.baseSha)","- Updated: $($State.updatedAt)")-join"`n";Write-ArenaUtf8NoBom -Path(Join-Path $generatedRoot 'arena-record.md')-Content($record+"`n")
    $approval=@('# Approval Registry','','| Style | Approved SHA-256 | Brief commit |','| --- | --- | --- |');$preview=@('# Preview Registry','','| Style | Branch | Port | PID | HTTP | URL |','| --- | --- | ---: | ---: | --- | --- |')
    foreach($name in @('style-a','style-b','style-c')){$style=$State.styles.PSObject.Properties[$name].Value;$approval+="| $name | $($style.brief.approvedSha256) | $($style.brief.commit) |";$preview+="| $name | $($style.branch) | $($style.preview.port) | $($style.preview.pid) | $($style.preview.httpStatus) | $($style.preview.url) |";$lines=@("# Candidate Record: $name",'',"- Branch: $($style.branch)","- Worktree: $($style.worktree)","- Dispatch ID: $($style.dispatchId)","- Candidate generation: $($style.candidateGeneration)","- Brief SHA-256: $($style.brief.approvedSha256)","- Brief commit: $($style.brief.commit)","- Implementation commit: $($style.implementationCommit)","- QA result: $($style.qaResultPath)","- QA result SHA-256: $($style.qaResultSha256)","- Validation: $($style.qualification.validation)","- Automated QA: $($style.qualification.automatedQa)","- Main-agent visual review: $($style.qualification.mainAgentVisualReview)","- Visual reviewer: $($style.reviews.visual.reviewer)","- Visual evidence IDs: $(@($style.reviews.visual.evidenceIds) -join ', ')","- Direction consistency: $($style.qualification.directionConsistencyReview)","- Direction reviewer: $($style.reviews.direction.reviewer)","- Direction evidence IDs: $(@($style.reviews.direction.evidenceIds) -join ', ')","- Overall: $($style.qualification.overall)");Write-ArenaUtf8NoBom -Path(Join-Path $candidateRoot($name+'-record.md'))-Content(($lines-join"`n")+"`n")}
    Write-ArenaUtf8NoBom -Path(Join-Path $generatedRoot 'approval-registry.md')-Content(($approval-join"`n")+"`n");Write-ArenaUtf8NoBom -Path(Join-Path $generatedRoot 'preview-registry.md')-Content(($preview-join"`n")+"`n")
    if($State.stage-in@('cleaned','complete')){$final=@('# Vibe Design Arena Final Report','',"- Arena ID: $($State.arenaId)","- Selected style: $($State.selection.style)","- Selected branch: $($State.selection.branch)","- Merge method: $($State.merge.method)","- Post-merge SHA: $($State.merge.postMergeSha)","- Stage: $($State.stage)",'','## Retained branches');foreach($name in @('style-a','style-b','style-c')){$style=$State.styles.PSObject.Properties[$name].Value;$final+="- $($style.branch): $($style.retainedCommit)"};Write-ArenaUtf8NoBom -Path(Join-Path $generatedRoot 'final-report.md')-Content(($final-join"`n")+"`n")}
}

Export-ModuleMember -Function *-Arena*
