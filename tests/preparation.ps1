[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$FxSourceDir)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$project=Split-Path -Parent $PSScriptRoot
$fixture=Join-Path $project ('work\preparation-tests\'+[Guid]::NewGuid().ToString('N'))
$browserDir=Join-Path $fixture 'browser';$profileDir=Join-Path $fixture 'profile';$backupDir=Join-Path $fixture 'snapshot'
New-Item -ItemType Directory -Path "$browserDir\defaults\pref","$profileDir\chrome" -Force|Out-Null
[IO.File]::WriteAllText("$browserDir\zen.exe",'fixture')
[IO.File]::WriteAllText("$browserDir\application.ini","Name=Zen`nVersion=fixture`n")
[IO.File]::WriteAllText("$browserDir\defaults\pref\channel-prefs.js",'// fixture channel')
[IO.File]::WriteAllText("$profileDir\chrome\zen-themes.css",'/* preserve */')
function Get-Process{param($Name,$ErrorAction)return @()}
function Assert($Condition,[string]$Message){if(!$Condition){throw "FAILED: $Message"}}
& "$project\installer\Prepare.ps1" -Browser zen -InstallDir $browserDir -ProfileDir $profileDir -FxSourceDir $FxSourceDir -BackupDir $backupDir
& "$project\installer\Verify-Preparation.ps1" -BackupDir $backupDir
$manifest=Get-Content "$backupDir\manifest.json" -Raw|ConvertFrom-Json
Assert (!$manifest.Applied) 'preparation must not install'
$roots=@{install=$browserDir;profile=$profileDir}
foreach($record in $manifest.Files){
    Assert (!(Test-Path -LiteralPath $record.Target)) 'real fixture target still absent after preparation'
    New-Item -ItemType Directory -Path (Split-Path -Parent $record.Target) -Force|Out-Null
    Copy-Item -LiteralPath (Join-Path $backupDir $record.PayloadRelativePath) -Destination $record.Target
}
foreach($record in $manifest.Directories){New-Item -ItemType Directory -Path (Join-Path $profileDir $record.RelativePath) -Force|Out-Null}
& "$project\installer\Restore-Preparation.ps1" -BackupDir $backupDir -WhatIf
Assert (Test-Path "$browserDir\config.js") 'WhatIf must preserve simulated installation'
[IO.File]::AppendAllText("$browserDir\config.js",'// external edit')
$rejected=$false;try{& "$project\installer\Restore-Preparation.ps1" -BackupDir $backupDir}catch{$rejected=$true}
Assert $rejected 'unknown edit must block rollback'
Assert (Test-Path "$browserDir\defaults\pref\config-prefs.js") 'rejection must occur before any deletion'
Copy-Item -LiteralPath "$backupDir\payload\install\config.js" -Destination "$browserDir\config.js" -Force
[IO.File]::WriteAllText("$profileDir\proxy-search-switcher.local.json",'{"token":"fixture-new-local-value"}')
& "$project\installer\Restore-Preparation.ps1" -BackupDir $backupDir
& "$project\installer\Restore-Preparation.ps1" -BackupDir $backupDir
Assert (!(Test-Path "$browserDir\config.js")) 'loader reverted'
Assert (!(Test-Path "$browserDir\defaults\pref\config-prefs.js")) 'security selector reverted'
Assert (Test-Path "$profileDir\proxy-search-switcher.local.json") 'local token config kept'
Assert (Test-Path "$profileDir\chrome\zen-themes.css") 'theme preserved'
Assert (!(Test-Path "$profileDir\chrome\utils")) 'new empty utils directory removed'
Write-Output 'PASS: preparation isolation, payload/backup verification, rollback dry run, changed-file guard, repeat rollback, token/theme preservation.'
