[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$FxSourceDir)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
$root=Join-Path $repo ('work/setup-tests/'+[Guid]::NewGuid().ToString('N'))
$project=Join-Path $root 'project';New-Item -ItemType Directory -Path $project|Out-Null
foreach($name in @('src','installer','examples')){Copy-Item -LiteralPath (Join-Path $repo $name) -Destination (Join-Path $project $name) -Recurse}
Copy-Item -LiteralPath (Join-Path $repo 'dependencies.lock.json') -Destination (Join-Path $project 'dependencies.lock.json')
$lock=Get-Content -LiteralPath "$project/dependencies.lock.json" -Raw|ConvertFrom-Json
$global:PSSSetupFixtureState=@{Processes=@{};StopOnModule=$null;StopExpectedHash=$null;StopBrowser=$null}
function Get-Process {
    param($Name,$ErrorAction)
    if($global:PSSSetupFixtureState.Processes.ContainsKey($Name)){return $global:PSSSetupFixtureState.Processes[$Name]}
    if($Name -eq 'zen' -and $global:PSSSetupFixtureState.StopOnModule -and (Get-FileHash -LiteralPath $global:PSSSetupFixtureState.StopOnModule).Hash -eq $global:PSSSetupFixtureState.StopExpectedHash){return [pscustomobject]@{Path=(Join-Path $global:PSSSetupFixtureState.StopBrowser 'zen.exe')}}
    return @()
}
function Assert($Value,[string]$Message){if(!$Value){throw "FAILED: $Message"}}
function Must-Fail([scriptblock]$Action,[string]$Message){$failed=$false;try{& $Action|Out-Null}catch{$failed=$true};Assert $failed $Message}
function Fixture([string]$Name,[bool]$WithLoader){
    $b=Join-Path $root "$Name/browser";$p=Join-Path $root "$Name/profile"
    New-Item -ItemType Directory -Path "$b/defaults/pref",$p|Out-Null
    [IO.File]::WriteAllText("$b/zen.exe",'non executable fixture')
    [IO.File]::WriteAllText("$b/application.ini","Name=Zen`nVersion=fixture`n")
    if($WithLoader){
        foreach($f in $lock.Files){
            $target=if($f.Path.StartsWith('program/')){Join-Path $b $f.Path.Substring(8)}else{Join-Path $p $f.Path.Substring(8)}
            New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force|Out-Null
            Copy-Item -LiteralPath (Join-Path $FxSourceDir $f.Path) -Destination $target
        }
        New-Item -ItemType Directory -Path "$p/chrome/JS" -Force|Out-Null
    }
    return @{InstallDir=$b;ProfileDir=$p}
}
$setup="$project/installer/Setup.ps1"
$a=Fixture 'incremental' $true;$browser=$a.InstallDir;$profile=$a.ProfileDir
$config=Join-Path $profile 'proxy-search-switcher.local.json';$module=Join-Path $profile 'chrome/JS/proxy-search-switcher.sys.mjs';$owned=Join-Path $profile 'proxy-search-switcher.install.json'
$global:PSSSetupFixtureAnswers=[System.Collections.Generic.Queue[string]]::new()
$global:PSSSetupFixtureAnswers.Enqueue('1')
function Read-Host {param($Prompt) if(!$global:PSSSetupFixtureAnswers.Count){throw 'unexpected interactive question'};return $global:PSSSetupFixtureAnswers.Dequeue()}
$inspect=& $setup -Interactive @a
Assert ($inspect.LoaderReady -and !$inspect.ConfigExists -and !$inspect.ConfigContentRead) 'inspect does not create/read configuration'
& $setup -Action Install @a -WhatIf
Assert (!(Test-Path $config) -and !(Test-Path $module)) 'install WhatIf writes neither config nor module'
[IO.File]::WriteAllText($module,'// unowned')
Must-Fail {& $setup -Action Install @a} 'unknown module refused'
Assert (!(Test-Path $config)) 'unknown module refusal precedes template creation'
Remove-Item -LiteralPath $module
$temp="$module.pss-tmp";[IO.File]::WriteAllText($temp,'// unknown temp')
Must-Fail {& $setup -Action Install @a} 'unknown temporary file refused'
Assert (!(Test-Path $config)) 'unknown temp refusal precedes config creation'
Remove-Item -LiteralPath $temp
$global:PSSSetupFixtureState.Processes['crashhelper']=[pscustomobject]@{Path=(Join-Path $browser 'crashhelper.exe')}
Must-Fail {& $setup -Action Install @a} 'target helper process prevents install'
$global:PSSSetupFixtureState.Processes.Clear()
& $setup -Action Install @a
$c=Get-Content -LiteralPath $config -Raw|ConvertFrom-Json
Assert ($c.enabled -eq $false -and $c.token -eq '') 'new default config disabled with empty token'
$c.enabled=$true;$c.token='setup-fixture-only-secret-canary'
[IO.File]::WriteAllText($config,($c|ConvertTo-Json))
$configHash=(Get-FileHash -LiteralPath $config).Hash
$installHash=(Get-FileHash -LiteralPath $module).Hash
& $setup -Action Install @a
Assert ((Get-FileHash -LiteralPath $config).Hash -eq $configHash -and (Get-FileHash -LiteralPath $module).Hash -eq $installHash) 'repeat install preserves filled enabled config and module'
$neighbor=Join-Path $profile 'chrome/JS/neighbor.uc.js';[IO.File]::WriteAllText($neighbor,'// unrelated')
$neighborHash=(Get-FileHash -LiteralPath $neighbor).Hash
$loaderHash=(Get-FileHash -LiteralPath "$browser/config.js").Hash
# A genuine old version differs from the prospective bundle.
[IO.File]::WriteAllText($module,'// installed previous fixture version')
$o=Get-Content -LiteralPath $owned -Raw|ConvertFrom-Json;$o.Sha256=(Get-FileHash -LiteralPath $module).Hash
[IO.File]::WriteAllText($owned,($o|ConvertTo-Json))
$oldModuleHash=$o.Sha256;$oldRecordHash=(Get-FileHash -LiteralPath $owned).Hash
$backup=Join-Path $root 'upgrade'
& $setup -Action PrepareUpdate @a -BackupDir "$backup-whatif" -WhatIf
Assert (!(Test-Path "$backup-whatif")) 'prepare WhatIf creates no backups'
# Exclusive lock proves prepare/apply never open secret config contents.
$guard=[IO.File]::Open($config,[IO.FileMode]::Open,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
try{
    $output=& $setup -Action PrepareUpdate @a -BackupDir $backup|Out-String
    Assert (!$output.Contains('setup-fixture-only-secret-canary')) 'prepare output redacts credentials'
    $planPath=Join-Path $backup 'update-plan.json';$plan=Get-Content -LiteralPath $planPath -Raw|ConvertFrom-Json
    $planHash=(Get-FileHash -LiteralPath $planPath).Hash
    Must-Fail {& $setup -Action ApplyUpdate -BackupDir $backup -PlanSha256 ('0'*64)} 'wrong reviewed plan hash refused'
    Assert (!(Test-Path "$backup/deployment-transaction")) 'wrong plan leaves no transaction'
    $payload=Join-Path $backup $plan.Files[0].Payload;$bytes=[IO.File]::ReadAllBytes($payload)
    [IO.File]::AppendAllText($payload,'// corrupt')
    Must-Fail {& $setup -Action ApplyUpdate -BackupDir $backup -PlanSha256 $planHash} 'changed payload refused'
    [IO.File]::WriteAllBytes($payload,$bytes)
    & $setup -Action ApplyUpdate -BackupDir $backup -PlanSha256 $planHash -WhatIf
    Assert (!(Test-Path "$backup/deployment-transaction")) 'apply WhatIf no transaction or writes'
    $output=& $setup -Action ApplyUpdate -BackupDir $backup -PlanSha256 $planHash|Out-String
    Assert (!$output.Contains('setup-fixture-only-secret-canary')) 'apply output redacts credentials'
    foreach($entry in $plan.Files){Assert ((Get-FileHash -LiteralPath $entry.Target).Hash -eq $entry.NewSha256) 'applied both new hashes'}
    $receipt=Get-Content -LiteralPath "$backup/deployment-transaction/receipt.json" -Raw|ConvertFrom-Json
    Assert ($receipt.Status -eq 'updated-awaiting-manual-restart' -and $receipt.Files.Count -eq 2 -and !$receipt.ConfigContentRead) 'verified transaction receipt'
    Must-Fail {& $setup -Action ApplyUpdate -BackupDir $backup -PlanSha256 $planHash} 'repeat apply refuses consumed plan'
    & $setup -Action RestoreUpdate -BackupDir $backup -WhatIf
    & $setup -Action RestoreUpdate -BackupDir $backup
}finally{$guard.Dispose()}
Assert ((Get-FileHash -LiteralPath $config).Hash -eq $configHash) 'secret config byte-for-byte unchanged'
Assert ((Get-FileHash -LiteralPath $module).Hash -eq $oldModuleHash -and (Get-FileHash -LiteralPath $owned).Hash -eq $oldRecordHash) 'rollback restored both old files'
Assert ((Get-FileHash -LiteralPath $neighbor).Hash -eq $neighborHash -and (Get-FileHash -LiteralPath "$browser/config.js").Hash -eq $loaderHash) 'loader/user script unchanged'
foreach($f in @(Get-ChildItem -LiteralPath $backup -File -Recurse)){Assert (![IO.File]::ReadAllText($f.FullName).Contains('setup-fixture-only-secret-canary')) 'no secret configuration in backup or receipt'}
# Simulated browser appearance between the two replacements must leave a recoverable partial transaction.
$partial=Join-Path $root 'partial-upgrade'
& $setup -Action PrepareUpdate @a -BackupDir $partial
$p=Get-Content -LiteralPath "$partial/update-plan.json" -Raw|ConvertFrom-Json
$global:PSSSetupFixtureState.StopOnModule=$module;$global:PSSSetupFixtureState.StopExpectedHash=$p.Files[0].NewSha256;$global:PSSSetupFixtureState.StopBrowser=$browser
Must-Fail {& $setup -Action ApplyUpdate -BackupDir $partial -PlanSha256 (Get-FileHash "$partial/update-plan.json").Hash} 'browser appearance between replacements stops update'
$global:PSSSetupFixtureState.StopOnModule=$null
$receipt=Get-Content -LiteralPath "$partial/deployment-transaction/receipt.json" -Raw|ConvertFrom-Json
Assert ($receipt.Status -eq 'failed-stop' -and $receipt.Files.Count -eq 1) 'partial update explicitly recorded'
& $setup -Action RestoreUpdate -BackupDir $partial
Assert ((Get-FileHash -LiteralPath $module).Hash -eq $oldModuleHash) 'partial rollback restored original'
# Malicious/unknown ownership field changes are refused even if payload/plan hashes were recalculated.
$recordTest=Join-Path $root 'changed-record'
& $setup -Action PrepareUpdate @a -BackupDir $recordTest
$p=Get-Content -LiteralPath "$recordTest/update-plan.json" -Raw|ConvertFrom-Json
$newRecordPath=Join-Path $recordTest $p.Files[1].Payload
$newRecord=Get-Content -LiteralPath $newRecordPath -Raw|ConvertFrom-Json;$newRecord.Browser='firefox'
[IO.File]::WriteAllText($newRecordPath,($newRecord|ConvertTo-Json));$p.Files[1].NewSha256=(Get-FileHash $newRecordPath).Hash
[IO.File]::WriteAllText("$recordTest/update-plan.json",($p|ConvertTo-Json -Depth 6))
Must-Fail {& $setup -Action ApplyUpdate -BackupDir $recordTest -PlanSha256 (Get-FileHash "$recordTest/update-plan.json").Hash} 'only Sha256 may change in ownership record'
Assert (!(Test-Path "$recordTest/deployment-transaction")) 'unknown record changes stop before transaction'
# Fresh-loader flow has no automatic sandbox change and never copies existing local config.
$b=Fixture 'fresh' $false;$freshBackup=Join-Path $root 'fresh-snapshot';$freshConfig=Join-Path $b.ProfileDir 'proxy-search-switcher.local.json'
[IO.File]::WriteAllText($freshConfig,'{"token":"setup-fixture-only-secret-canary"}')
$guard=[IO.File]::Open($freshConfig,[IO.FileMode]::Open,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
try{Must-Fail {& $setup -Action PrepareLoader @b -FxSourceDir $FxSourceDir -BackupDir $freshBackup} 'existing secret config prevents preparation without reading it'}finally{$guard.Dispose()}
Assert (!(Test-Path $freshBackup)) 'existing config leaves no backup'
Remove-Item -LiteralPath $freshConfig
& $setup -Action PrepareLoader @b -FxSourceDir $FxSourceDir -BackupDir $freshBackup
Must-Fail {& $setup -Action ApplyLoader -BackupDir $freshBackup} 'sandbox change requires explicit consent'
Assert (!(Test-Path (Join-Path $b.InstallDir 'config.js'))) 'no implicit loader install'
& $setup -Action ApplyLoader -BackupDir $freshBackup -AllowSandboxChange -WhatIf
Assert (!(Test-Path (Join-Path $b.InstallDir 'config.js'))) 'loader WhatIf no writes'
& $setup -Action ApplyLoader -BackupDir $freshBackup -AllowSandboxChange
& $setup -Action Uninstall @b -WhatIf
& $setup -Action Uninstall @b
& $setup -Action RestoreLoader -BackupDir $freshBackup -WhatIf
& $setup -Action RestoreLoader -BackupDir $freshBackup
Assert (!(Test-Path (Join-Path $b.InstallDir 'config.js')) -and (Test-Path $freshConfig)) 'loader restored independently and config retained'
# Interactive ApplyLoader shows the snapshot target before requesting ALLOW-AUTOCONFIG.
$b3=Fixture 'fresh-interactive' $false
& $setup -Action PrepareLoader @b3 -FxSourceDir $FxSourceDir -BackupDir (Join-Path $root 'fresh3-snapshot')
$global:PSSSetupFixtureAnswers.Enqueue('4')
$global:PSSSetupFixtureAnswers.Enqueue((Join-Path $root 'fresh3-snapshot'))
$global:PSSSetupFixtureAnswers.Enqueue('not the consent phrase')
Must-Fail {& $setup -Interactive @b3} 'interactive apply without exact consent refused'
$global:PSSSetupFixtureAnswers.Enqueue('4')
$global:PSSSetupFixtureAnswers.Enqueue((Join-Path $root 'fresh3-snapshot'))
$global:PSSSetupFixtureAnswers.Enqueue('ALLOW-AUTOCONFIG')
& $setup -Interactive @b3
Assert (Test-Path (Join-Path $b3.InstallDir 'config.js')) 'interactive apply after consent installs loader'
# Profile discovery lists candidates; no reliance on a default profile.
. "$project/installer/Common.ps1"
. "$project/installer/Profiles.ps1"
$ini=Join-Path $root 'profiles.ini'
[IO.File]::WriteAllText($ini,"[Profile0]`nName=One`nIsRelative=1`nPath=incremental/profile`n[Profile1]`nName=Two`nIsRelative=0`nPath=$($b.ProfileDir)`n[InstallIgnored]`nDefault=ignored`n")
$candidates=@(Get-ProfileCandidates $ini)
Assert ($candidates.Count -eq 2 -and $candidates[0].Path -eq $profile -and $candidates[1].Path -eq $b.ProfileDir) 'relative/absolute profile discovery'
[IO.File]::WriteAllText($ini,"[Profile0]`nIsRelative=1`nPath=incremental/profile`nPath=fresh/profile`n")
Must-Fail {Get-ProfileCandidates $ini} 'ambiguous duplicate profile field refused'
$link=Join-Path $root 'profile-link'
New-Item -ItemType Junction -Path $link -Target $profile|Out-Null
Must-Fail {Get-Profile $link} 'profile junction refused'
Assert ((Get-FileHash -LiteralPath $config).Hash -eq $configHash) 'all tests preserve filled config'
Write-Output 'PASS: wizard inspection, profiles, template/WhatIf, conflicts/helpers, secret-free update, reviewed hash, partial failure/rollback, sandbox opt-in and loader recovery.'
Write-Output "Fixtures retained at $root"
