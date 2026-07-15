[CmdletBinding()]
param(
    [string]$BaseRoot = 'C:\tmp',
    [string]$OutputPath
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$scriptRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$controller = Join-Path $scriptRoot 'arena.ps1'
$integrity = Join-Path $scriptRoot 'arena-integrity.ps1'
$powershell = (Get-Command powershell.exe -ErrorAction Stop).Source
$fixtureRoot = Join-Path ([IO.Path]::GetFullPath($BaseRoot)) ('vda-contract-' + [Guid]::NewGuid().ToString('N').Substring(0,8))
[IO.Directory]::CreateDirectory($fixtureRoot) | Out-Null
$statePath = Join-Path $fixtureRoot 'records\arena-state.json'
$commands = @(
    'preflight','create-worktrees','start-previews','stop-previews','status',
    'import-builder-result','import-qa-result','sign-visual-review',
    'sign-direction-review','qualify','select','merge','cleanup',
    'publish-plan','publish','handoff-docs'
)
$actions = @('snapshot','normalize-brief','check-attributes','verify-brief')

function Normalize-TraceText {
    param([AllowEmptyString()][string]$Text)
    if ($null -eq $Text) { return '' }
    $value = $Text.Replace($fixtureRoot,'<FIXTURE_ROOT>')
    $value = [regex]::Replace($value,'(?i)\b[0-9a-f]{8}-[0-9a-f-]{27,}\b','<UUID>')
    $value = [regex]::Replace($value,'(?i)\b[0-9a-f]{40,64}\b','<GIT_OR_SHA>')
    $value = [regex]::Replace($value,'\b\d{4}-\d{2}-\d{2}T[^\s"}]+','<TIMESTAMP>')
    return $value.Replace('\','/')
}

function Invoke-TraceCase {
    param([string]$Kind,[string]$Name,[string]$Script,[string[]]$Arguments)
    $before = @(Get-ChildItem -LiteralPath $fixtureRoot -Recurse -Force -File -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName.Substring($fixtureRoot.Length).TrimStart('\').Replace('\','/') })
    $stateBefore = if(Test-Path -LiteralPath $statePath){ (Normalize-TraceText ([IO.File]::ReadAllText($statePath,[Text.Encoding]::UTF8))) | ConvertFrom-Json } else { $null }
    $psi = New-Object Diagnostics.ProcessStartInfo
    $psi.FileName = $powershell
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $allArguments = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$Script)+$Arguments
    $psi.Arguments = (($allArguments | ForEach-Object { ([char]34) + ([string]$_) + ([char]34) }) -join ' ')
    $process = New-Object Diagnostics.Process
    $process.StartInfo = $psi
    if(-not $process.Start()){ throw "Unable to start trace case $Name." }
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()
    $after = @(Get-ChildItem -LiteralPath $fixtureRoot -Recurse -Force -File -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName.Substring($fixtureRoot.Length).TrimStart('\').Replace('\','/') })
    $stateAfter = if(Test-Path -LiteralPath $statePath){ (Normalize-TraceText ([IO.File]::ReadAllText($statePath,[Text.Encoding]::UTF8))) | ConvertFrom-Json } else { $null }
    [pscustomobject][ordered]@{
        kind = $Kind
        name = $Name
        argv = @($Arguments)
        normalizedArgv = @($Arguments | ForEach-Object { Normalize-TraceText ([string]$_) })
        preconditions = [pscustomobject]@{ stateExists = ($null -ne $stateBefore); files = $before }
        stateBefore = $stateBefore
        stateAfter = $stateAfter
        exitCode = $process.ExitCode
        stdout = $stdout.TrimEnd()
        stderr = $stderr.TrimEnd()
        normalizedStdout = Normalize-TraceText $stdout.TrimEnd()
        normalizedStderr = Normalize-TraceText $stderr.TrimEnd()
        createdFiles = @($after | Where-Object { $_ -notin $before })
    }
}

try {
    $cases = @()
    foreach($command in $commands){
        $cases += Invoke-TraceCase -Kind 'controller' -Name $command -Script $controller -Arguments @($command,'-State',$statePath)
    }
    foreach($action in $actions){
        $cases += Invoke-TraceCase -Kind 'integrity' -Name $action -Script $integrity -Arguments @($action)
    }
    $result = [pscustomobject][ordered]@{
        formatVersion = '1.0'
        oracle = 'PowerShell'
        fixture = 'missing-required-input-or-state'
        cases = $cases
    }
    $json = $result | ConvertTo-Json -Depth 30
    if($OutputPath){
        $target = [IO.Path]::GetFullPath($OutputPath)
        $parent = Split-Path -Parent $target
        if($parent){[IO.Directory]::CreateDirectory($parent)|Out-Null}
        $canonicalJson = $json.Replace(([string][char]13 + [char]10),[string][char]10).Replace([string][char]13,[string][char]10)
        [IO.File]::WriteAllText($target,$canonicalJson+[char]10,(New-Object Text.UTF8Encoding($false)))
    }
    $json
} finally {
    if(Test-Path -LiteralPath $fixtureRoot){
        $resolved = (Resolve-Path -LiteralPath $fixtureRoot).Path
        if([IO.Path]::GetFileName($resolved).StartsWith('vda-contract-')){
            Remove-Item -LiteralPath $resolved -Recurse -Force
        }
    }
}