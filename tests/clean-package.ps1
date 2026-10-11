[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$PackageZip,[Parameter(Mandatory=$true)][string]$FxSourceDir)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
$root=Join-Path $repo ('work\clean-package-'+[Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $root | Out-Null
Expand-Archive -LiteralPath $PackageZip -DestinationPath (Join-Path $root 'package')
$packageRoots=@(Get-ChildItem -LiteralPath (Join-Path $root 'package') -Directory)
if($packageRoots.Count -ne 1){throw 'ZIP必须单一根目录。'}
$project=$packageRoots[0].FullName
$packageVersion=(Get-Content -LiteralPath (Join-Path $project 'package.json') -Raw|ConvertFrom-Json).version
if($packageRoots[0].Name -ne "proxy-search-switcher-$packageVersion"){throw 'ZIP目录与版本不符。'}
$browser=Join-Path $root 'browser';$profile=Join-Path $root 'profile';$backup=Join-Path $root 'snapshot'
New-Item -ItemType Directory -Path "$browser\defaults\pref",$profile | Out-Null
# No actual browser binary, process, network, profile or API is used.
[IO.File]::WriteAllText("$browser\zen.exe",'isolated non-executable fixture')
[IO.File]::WriteAllText("$browser\application.ini","Name=Zen`nVersion=fixture`n")
function Get-Process {param($Name,$ErrorAction) return @()}
function Assert($value,$message){if(!$value){throw "FAILED: $message"}}
& "$project\installer\Prepare.ps1" -Browser zen -InstallDir $browser -ProfileDir $profile -FxSourceDir $FxSourceDir -BackupDir $backup
& "$project\installer\Verify-Preparation.ps1" -BackupDir $backup
& "$project\installer\Apply-Preparation.ps1" -BackupDir $backup
$module=Join-Path $profile 'chrome\JS\proxy-search-switcher.sys.mjs'
$config=Join-Path $profile 'proxy-search-switcher.local.json'
$record=Join-Path $profile 'proxy-search-switcher.install.json'
Assert (Test-Path $module) 'fresh module exists'
Assert (Test-Path $record) 'ownership exists'
$template=Get-Content -LiteralPath $config -Raw|ConvertFrom-Json
Assert ($template.enabled -eq $false -and $template.token -eq '') 'disabled no-secret initial config'
$moduleHash=(Get-FileHash -LiteralPath $module).Hash
$owned=Get-Content -LiteralPath $record -Raw|ConvertFrom-Json
Assert ($owned.Sha256 -eq $moduleHash) 'owned hash matches'
$loaderHash=(Get-FileHash -LiteralPath "$browser\defaults\pref\config-prefs.js").Hash
$userScript=Join-Path $profile 'chrome\JS\unrelated.uc.js'
[IO.File]::WriteAllText($userScript,'// isolated unrelated user script')
$userHash=(Get-FileHash -LiteralPath $userScript).Hash
& node "$repo\tests\helpers\isolated-lifecycle.cjs" $module $config
if($LASTEXITCODE -ne 0){throw 'isolated lifecycle failed'}
$configHash=(Get-FileHash -LiteralPath $config).Hash
$params=@{Browser='zen';InstallDir=$browser;ProfileDir=$profile}
& "$project\installer\Uninstall.ps1" @params -WhatIf
Assert (Test-Path $module) 'uninstall WhatIf no write'
& "$project\installer\Uninstall.ps1" @params
& "$project\installer\Uninstall.ps1" @params
Assert (!(Test-Path $module) -and !(Test-Path $record)) 'owned module and record absent'
Assert ((Get-FileHash -LiteralPath $config).Hash -eq $configHash) 'configuration retained'
Assert ((Get-FileHash -LiteralPath $userScript).Hash -eq $userHash) 'unrelated user script retained'
Assert ((Get-FileHash -LiteralPath "$browser\defaults\pref\config-prefs.js").Hash -eq $loaderHash) 'loader retained'
& "$project\installer\Install.ps1" @params
Assert (Test-Path $module) 'reinstall from same package works'
& "$project\installer\Uninstall.ps1" @params
Assert (!(Test-Path $module)) 'second clean uninstall'
"PASS: ZIP fresh loader/project installation, disabled/enabled/disabled simulated startup, uninstall dry-run/repeat/reinstall; loader/user scripts/config preserved. Fixture: $root"
