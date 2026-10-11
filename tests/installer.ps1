Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$project=Split-Path -Parent $PSScriptRoot
$testRoot=Join-Path $project ('work\installer-tests\'+[Guid]::NewGuid().ToString('N'))
$fixtureProject=Join-Path $testRoot 'project';$browserDir=Join-Path $testRoot 'browser';$profileDir=Join-Path $testRoot 'profile'
New-Item -ItemType Directory -Path "$fixtureProject\installer","$browserDir\defaults\pref","$profileDir\chrome\JS","$profileDir\chrome\utils" -Force | Out-Null
Copy-Item -LiteralPath "$project\src" -Destination "$fixtureProject\src" -Recurse
Copy-Item -Path "$project\installer\*.ps1" -Destination "$fixtureProject\installer"
Copy-Item -LiteralPath "$project\dependencies.lock.json" -Destination "$fixtureProject\dependencies.lock.json"
function Get-Process {param($Name,$ErrorAction) return @()}
function Assert($Condition,[string]$Message){if(!$Condition){throw "FAILED: $Message"}}
function Must-Fail([scriptblock]$Action,[string]$Message){$failed=$false;try{& $Action|Out-Null}catch{$failed=$true};Assert $failed $Message}
$lock=Get-Content "$fixtureProject\dependencies.lock.json" -Raw | ConvertFrom-Json
# Synthetic loader fixture: change the copied project's lock, never the real lock.
# Tests exercise integrity/coexistence, not the third-party loader's runtime.
foreach($record in $lock.Files){
    $path=if($record.Path.StartsWith('program/')){Join-Path $browserDir $record.Path.Substring(8)}else{Join-Path $profileDir $record.Path.Substring(8)}
    $content="// synthetic fx-autoconfig fixture: $($record.Path)`n"
    [IO.File]::WriteAllText($path,$content)
    $record.Sha256=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($content)))
}
[IO.File]::WriteAllText("$fixtureProject\dependencies.lock.json",($lock|ConvertTo-Json -Depth 5))
[IO.File]::WriteAllText("$browserDir\zen.exe",'fixture')
[IO.File]::WriteAllText("$browserDir\application.ini","Name=Zen`nVersion=fixture`n")
$configPath=Join-Path $profileDir 'proxy-search-switcher.local.json'
Copy-Item -LiteralPath "$project\examples\config.example.json" -Destination $configPath
[IO.File]::WriteAllText("$profileDir\chrome\JS\user-script.uc.js",'// unrelated user script')
$userHash=(Get-FileHash "$profileDir\chrome\JS\user-script.uc.js").Hash
$fxHash=(Get-FileHash "$browserDir\defaults\pref\config-prefs.js").Hash
$install="$fixtureProject\installer\Install.ps1";$uninstall="$fixtureProject\installer\Uninstall.ps1";$recover="$fixtureProject\installer\Recover.ps1"
$params=@{InstallDir=$browserDir;ProfileDir=$profileDir}
$inspection=& $install @params -Inspect;Assert $inspection.Ready 'recognized existing loader'
& $install @params -WhatIf
$module="$profileDir\chrome\JS\proxy-search-switcher.sys.mjs"
Assert (!(Test-Path $module)) 'WhatIf must not publish'
[IO.File]::AppendAllText("$browserDir\config.js",'// external change')
Must-Fail {& $install @params} 'unknown or modified loader refused'
[IO.File]::WriteAllText("$browserDir\config.js","// synthetic fx-autoconfig fixture: program/config.js`n")
[IO.File]::WriteAllText("$browserDir\defaults\pref\other.js",'pref("general.config.filename", "other.js");')
Must-Fail {& $install @params} 'foreign AutoConfig refused'
Remove-Item -LiteralPath "$browserDir\defaults\pref\other.js"
[IO.File]::WriteAllText($module,'// foreign module')
Must-Fail {& $install @params} 'existing unowned module preserved'
Remove-Item -LiteralPath $module
& $install @params
$moduleHash=(Get-FileHash $module).Hash
& $install @params
Assert ((Get-FileHash $module).Hash -eq $moduleHash) 'repeat install stable'
Assert ((Get-FileHash "$browserDir\defaults\pref\config-prefs.js").Hash -eq $fxHash) 'loader never overwritten'
Assert ((Get-FileHash "$profileDir\chrome\JS\user-script.uc.js").Hash -eq $userHash) 'user script never overwritten'
$source=[IO.File]::ReadAllText($module)
Assert ($source.Contains('export function getStatus()') -and $source.Contains($configPath.Replace('\','\\'))) 'global module with config path'
Assert ($source -notmatch '(pref|defaultPref|lockPref)\s*\(\s*["'']general\.config\.sandbox_enabled') 'no security preference writes'
[IO.File]::AppendAllText($module,'// edited')
Must-Fail {& $uninstall @params} 'edited module preserved'
[IO.File]::WriteAllText($module,$source,[Text.UTF8Encoding]::new($false))
& $uninstall @params
& $uninstall @params
Assert (Test-Path $configPath) 'local token config preserved'
Assert ((Get-FileHash "$profileDir\chrome\JS\user-script.uc.js").Hash -eq $userHash) 'uninstall preserves user script'
# Simulated interruption after module publication, before formal manifest.
[IO.File]::WriteAllText($module,$source,[Text.UTF8Encoding]::new($false))
$record=@{Project='proxy-search-switcher';Schema=2;Profile=$profileDir;Browser='zen';InstallDir=$browserDir;
    RelativePath='chrome\JS\proxy-search-switcher.sys.mjs';Sha256=(Get-FileHash $module).Hash;OriginalExists=$false}
[IO.File]::WriteAllText("$profileDir\proxy-search-switcher.recovery.json",($record|ConvertTo-Json))
& $recover @params
& $recover @params
Assert (!(Test-Path $module)) 'crash recovery'
Remove-Item -LiteralPath "$browserDir\zen.exe"
[IO.File]::WriteAllText("$browserDir\firefox.exe",'fixture')
[IO.File]::WriteAllText("$browserDir\application.ini","Name=Firefox`nVersion=fixture`n")
& $install @params -Browser firefox
Assert ([IO.File]::ReadAllText($module).Contains('browser:"firefox"')) 'Firefox separate entry'
& $uninstall @params -Browser firefox
Write-Output 'PASS: existing fx-autoconfig coexistence, hash/conflict guards, dry run, repeat install/uninstall, user scripts, recovery, Firefox fixture.'
Write-Output "Fixtures retained at $testRoot"
