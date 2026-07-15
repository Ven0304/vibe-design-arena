Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
function Assert-SmokeCondition { param([bool]$Condition,[string]$Message) if (-not $Condition) { throw "ASSERTION FAILED: $Message" } }
function Invoke-SmokeNativeProcess {
 param([Parameter(Mandatory=$true)][string]$Executable,[string[]]$Arguments=@(),[switch]$AllowFailure,[string]$Description=$Executable)
 $previousPreference=$ErrorActionPreference
 try { $ErrorActionPreference='Continue'; $output=@(& $Executable @Arguments 2>&1); $exitCode=$LASTEXITCODE }
 finally { $ErrorActionPreference=$previousPreference }
 $text=(($output|ForEach-Object{[string]$_})-join "`n").TrimEnd()
 if ($exitCode -ne 0 -and -not $AllowFailure) { throw "$Description failed ($exitCode): $text" }
 [pscustomobject]@{exitCode=$exitCode;output=$text}
}
function ConvertFrom-SmokeJson {
 param([AllowEmptyCollection()][object[]]$Output,[string]$Description,[switch]$RequirePass)
 $text=(($Output|ForEach-Object{[string]$_})-join "`n").Trim()
 if ([string]::IsNullOrWhiteSpace($text)) { throw "$Description returned no JSON." }
 try { $result=$text|ConvertFrom-Json -ErrorAction Stop } catch { throw "$Description returned invalid or non-structured JSON: $($_.Exception.Message)" }
 if ($null -eq $result -or $result -is [array]) { throw "$Description did not return exactly one JSON object." }
 if ($RequirePass -and [string]$result.status -ne 'PASS') { throw "$Description did not report PASS." }
 $result
}
Export-ModuleMember -Function Assert-SmokeCondition,Invoke-SmokeNativeProcess,ConvertFrom-SmokeJson
