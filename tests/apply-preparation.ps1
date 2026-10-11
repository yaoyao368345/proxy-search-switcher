[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$FxSourceDir)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
 $repo=Split-Path -Parent $PSScriptRoot
$root=Join-Path $repo ('work\stage1-test-'+[Guid]::NewGuid().ToString('N'))
$toolDir=Join-Path $root 'tools\installer'
$browserDir=Join-Path $root 'browser';$profileDir=Join-Path $root 'profile';$backup=Join-Path $root 'backup'
New-Item -ItemType Directory -Path $toolDir,"$browserDir\defaults\pref","$profileDir\chrome" -Force|Out-Null
Copy-Item -Path "$repo\installer\*.ps1" -Destination $toolDir
Copy-Item -LiteralPath "$repo\installer\Apply-Preparation.ps1" -Destination "$toolDir\Apply-Preparation.ps1"
Copy-Item -LiteralPath "$repo\dependencies.lock.json" -Destination "$root\tools\dependencies.lock.json"
[IO.File]::WriteAllText("$browserDir\zen.exe",'fixture')
[IO.File]::WriteAllText("$browserDir\application.ini","Name=Zen`nVersion=fixture`n")
[IO.File]::WriteAllText("$browserDir\defaults\pref\channel-prefs.js",'// unchanged fixture channel')
function Get-Process{param($Name,$ErrorAction)return @()}
function Assert($Condition,[string]$Message){if(!$Condition){throw "FAILED: $Message"}}
& "$repo\installer\Prepare.ps1" -Browser zen -InstallDir $browserDir -ProfileDir $profileDir -FxSourceDir $FxSourceDir -BackupDir $backup
$manifestPath=Join-Path $backup 'manifest.json'
$manifest=Get-Content $manifestPath -Raw|ConvertFrom-Json
$record=@($manifest.Files|Where-Object RelativePath -eq 'proxy-search-switcher.local.json')[0]
$template=Join-Path $backup $record.PayloadRelativePath
$config=Get-Content $template -Raw|ConvertFrom-Json;$config.enabled=$false
[IO.File]::WriteAllText($template,($config|ConvertTo-Json),[Text.UTF8Encoding]::new($false))
$record.PayloadSha256=(Get-FileHash $template).Hash
[IO.File]::WriteAllText($manifestPath,($manifest|ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false))
& "$toolDir\Apply-Preparation.ps1" -BackupDir $backup -AllowRunningBrowser -WhatIf
Assert (!(Test-Path "$browserDir\config.js")) 'WhatIf must not create files'
[IO.File]::WriteAllText("$browserDir\defaults\pref\foreign.js",'pref("general.config.filename", "foreign.js");')
$failed=$false;try{& "$toolDir\Apply-Preparation.ps1" -BackupDir $backup -AllowRunningBrowser}catch{$failed=$true}
Assert $failed 'unknown AutoConfig must block before installation'
Assert (!(Test-Path "$browserDir\config.js")) 'conflict must leave targets absent'
Remove-Item -LiteralPath "$browserDir\defaults\pref\foreign.js"
& "$toolDir\Apply-Preparation.ps1" -BackupDir $backup -AllowRunningBrowser
$receipt=Get-Content "$backup\installation-receipt.json" -Raw|ConvertFrom-Json
Assert ($receipt.Status -eq 'installed-awaiting-manual-restart') 'must wait after installation'
Assert ($receipt.Files.Count -eq 11) 'ten authorized payloads plus ownership record'
foreach($file in $receipt.Files){Assert ((Get-FileHash -LiteralPath $file.Target).Hash -eq $file.Sha256) 'installed hash must match'}
$failed=$false;try{& "$toolDir\Apply-Preparation.ps1" -BackupDir $backup -AllowRunningBrowser}catch{$failed=$true}
Assert $failed 'repeat apply must refuse to overwrite'
& "$toolDir\Uninstall.ps1" -Browser zen -InstallDir $browserDir -ProfileDir $profileDir
& "$toolDir\Restore-Preparation.ps1" -BackupDir $backup
Assert (!(Test-Path "$browserDir\config.js")) 'rollback removes new AutoConfig'
Assert (Test-Path "$profileDir\proxy-search-switcher.local.json") 'local template retained'
Write-Output 'PASS: stage1 dry run, foreign AutoConfig refusal, verified exclusive writes, paused runtime config, no overwrite, uninstall and rollback.'
