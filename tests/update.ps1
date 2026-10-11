Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
$root=Join-Path $repo ('work\update-tests\'+[Guid]::NewGuid().ToString('N'))
$project=Join-Path $root 'project';$browser=Join-Path $root 'browser';$profilePath=Join-Path $root 'profile';$backup=Join-Path $root 'backup'
New-Item -ItemType Directory -Path "$project\installer","$browser\defaults\pref","$profilePath\chrome\utils","$profilePath\chrome\JS" -Force|Out-Null
Copy-Item -LiteralPath "$repo\src" -Destination "$project\src" -Recurse
Copy-Item -Path "$repo\installer\*.ps1" -Destination "$project\installer"
$lock=Get-Content "$repo\dependencies.lock.json" -Raw|ConvertFrom-Json
foreach($record in $lock.Files){
    $path=if($record.Path.StartsWith('program/')){Join-Path $browser $record.Path.Substring(8)}else{Join-Path $profilePath $record.Path.Substring(8)}
    $text="// synthetic existing fx fixture $($record.Path)`n";[IO.File]::WriteAllText($path,$text)
    $record.Sha256=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($text)))
}
[IO.File]::WriteAllText("$project\dependencies.lock.json",($lock|ConvertTo-Json -Depth 5))
[IO.File]::WriteAllText("$browser\zen.exe",'fixture');[IO.File]::WriteAllText("$browser\application.ini","Name=Zen`nVersion=fixture`n")
$configPath=Join-Path $profilePath 'proxy-search-switcher.local.json'
[IO.File]::WriteAllText($configPath,'{"enabled":false,"token":"fixture-credential-must-not-be-backed-up"}')
$configHash=(Get-FileHash $configPath).Hash
$target=Join-Path $profilePath 'chrome\JS\proxy-search-switcher.sys.mjs'
$ownedPath=Join-Path $profilePath 'proxy-search-switcher.install.json'
[IO.File]::WriteAllText($target,'// original fixture module')
$owned=@{Project='proxy-search-switcher';Schema=2;Browser='zen';Profile=$profilePath;InstallDir=$browser;ConfigPath=$configPath;
    RelativePath='chrome\JS\proxy-search-switcher.sys.mjs';Sha256=(Get-FileHash $target).Hash;OriginalExists=$false;FxRevision=$lock.Revision}
[IO.File]::WriteAllText($ownedPath,($owned|ConvertTo-Json))
function Get-Process{param($Name,$ErrorAction)return @()}
function Assert($Condition,[string]$Message){if(!$Condition){throw "FAILED: $Message"}}
function Must-Fail([scriptblock]$Action,[string]$Message){$failed=$false;try{& $Action|Out-Null}catch{$failed=$true};Assert $failed $Message}
$params=@{InstallDir=$browser;ProfileDir=$profilePath;BackupDir=$backup}
$moduleHash=(Get-FileHash $target).Hash;$ownedHash=(Get-FileHash $ownedPath).Hash
$result=& "$project\installer\Prepare-Update.ps1" @params|Out-String
Assert (!$result.Contains('fixture-credential')) 'preparation output must not expose credentials'
Assert ((Get-FileHash $target).Hash -eq $moduleHash) 'preparation must not update module'
Assert ((Get-FileHash $ownedPath).Hash -eq $ownedHash) 'preparation must not update ownership'
Assert ((Get-FileHash $configPath).Hash -eq $configHash) 'config unchanged'
Assert (@(Get-ChildItem "$backup\originals" -File).Count -eq 2) 'exactly two original files'
foreach($file in @(Get-ChildItem $backup -File -Recurse)){Assert (![IO.File]::ReadAllText($file.FullName).Contains('fixture-credential')) 'secret config absent from all backup and payload files'}
& "$project\installer\Verify-Update.ps1" -BackupDir $backup
Must-Fail {& "$project\installer\Prepare-Update.ps1" @params} 'existing backup not overwritten'
$plan=Get-Content "$backup\update-plan.json" -Raw|ConvertFrom-Json
# Simulate an authorized deployment only in this temporary fixture.
foreach($record in $plan.Files){Copy-Item -LiteralPath (Join-Path $backup $record.Payload) -Destination $record.Target -Force}
& "$project\installer\Restore-Update.ps1" -BackupDir $backup -WhatIf
Assert ((Get-FileHash $target).Hash -eq $plan.Files[0].NewSha256) 'WhatIf must leave new module'
[IO.File]::AppendAllText($ownedPath,'external edit')
Must-Fail {& "$project\installer\Restore-Update.ps1" -BackupDir $backup} 'unknown ownership edit must block all restore writes'
Assert ((Get-FileHash $target).Hash -eq $plan.Files[0].NewSha256) 'refused rollback leaves module'
Copy-Item -LiteralPath "$backup\payload\proxy-search-switcher.install.json" -Destination $ownedPath -Force
& "$project\installer\Restore-Update.ps1" -BackupDir $backup
& "$project\installer\Restore-Update.ps1" -BackupDir $backup
Assert ((Get-FileHash $target).Hash -eq $moduleHash) 'old module restored'
Assert ((Get-FileHash $ownedPath).Hash -eq $ownedHash) 'old ownership restored'
Assert ((Get-FileHash $configPath).Hash -eq $configHash) 'secret config still unchanged'
& "$project\installer\Verify-Update.ps1" -BackupDir $backup
Write-Output 'PASS: update preparation is read-only for browser, backs up only owned files, refuses unknown hashes, and restores idempotently without copying credentials.'
