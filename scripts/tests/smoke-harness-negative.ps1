[CmdletBinding()]
param([string]$BaseRoot='C:\tmp')
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$modulePath=Join-Path $PSScriptRoot 'Smoke.TestHarness.psm1'; Import-Module $modulePath -Force
$phase2Path=Join-Path $PSScriptRoot 'phase2-smoke.ps1'; $powershell=(Get-Command powershell.exe -ErrorAction Stop).Source; $node=(Get-Command node.exe -ErrorAction Stop).Source
$utf8NoBom=New-Object Text.UTF8Encoding($false); $finalResult=$null; $root=Join-Path ([IO.Path]::GetFullPath($BaseRoot)) ('vda-smoke-negative-'+[Guid]::NewGuid().ToString('N').Substring(0,8)); [IO.Directory]::CreateDirectory($root)|Out-Null
function Write-Fixture { param([string]$Name,[string]$Content) $path=Join-Path $root $Name; [IO.File]::WriteAllText($path,$Content,$utf8NoBom); $path }
function Assert-EntryFails { param([string]$Name,[string]$Script,[string[]]$Arguments) $p=Invoke-SmokeNativeProcess $powershell (@('-NoProfile','-ExecutionPolicy','Bypass','-File',$Script)+$Arguments) -AllowFailure -Description $Name; Assert-SmokeCondition ($p.exitCode -ne 0) "$Name returned exit code 0."; Assert-SmokeCondition ($p.output -notmatch '"status"\s*:\s*"PASS"') "$Name emitted PASS on failure." }
try {
 $unitPass=Write-Fixture 'unit-pass.js' 'process.stdout.write(JSON.stringify({status:"PASS"}));'; $unitFail=Write-Fixture 'unit-fail.js' 'process.exit(23);'
 $pass=Write-Fixture 'pass.ps1' "[pscustomobject]@{status='PASS'}|ConvertTo-Json`n"; $throw=Write-Fixture 'throw.ps1' "throw 'controlled terminating error'`n"; $empty=Write-Fixture 'empty.ps1' "`n"; $fail=Write-Fixture 'fail.ps1' "[pscustomobject]@{status='FAIL'}|ConvertTo-Json`n"; $invalid=Write-Fixture 'invalid.ps1' "'not-json'`n"
 $probe=Write-Fixture 'assert.ps1' "Import-Module '$($modulePath.Replace("'","''"))' -Force`nAssert-SmokeCondition `$false 'controlled assertion failure'`n"
 $base=@('-BaseRoot',$root,'-QaUnitPath',$unitPass,'-NodeExecutable',$node)
 Assert-EntryFails 'native nonzero' $phase2Path @('-BaseRoot',$root,'-QaUnitPath',$unitFail,'-LifecycleSmokePath',$pass,'-NodeExecutable',$node)
 Assert-EntryFails 'terminating child script' $phase2Path ($base+@('-LifecycleSmokePath',$throw)); Assert-EntryFails 'empty child result' $phase2Path ($base+@('-LifecycleSmokePath',$empty)); Assert-EntryFails 'non-PASS child result' $phase2Path ($base+@('-LifecycleSmokePath',$fail)); Assert-EntryFails 'invalid JSON child result' $phase2Path ($base+@('-LifecycleSmokePath',$invalid)); Assert-EntryFails 'assertion failure' $probe @()
 $finalResult=[pscustomobject][ordered]@{status='PASS';cases=6}
} finally { if(Test-Path -LiteralPath $root){$resolved=(Resolve-Path -LiteralPath $root).Path;if([IO.Path]::GetFileName($resolved).StartsWith('vda-smoke-negative-')){Remove-Item -LiteralPath $resolved -Recurse -Force}} }

$finalResult|ConvertTo-Json -Compress
