[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$InstallDir,[Parameter(Mandatory=$true)][string]$ProfileDir,
    [Parameter(Mandatory=$true)][string]$BackupDir)
. "$PSScriptRoot\Common.ps1"
$info=Find-Browser 'zen' $InstallDir;$profilePath=Get-Profile $ProfileDir
$record=Read-Record $profilePath
if(!$record -or $record.Browser -ne 'zen' -or $record.InstallDir -ne $info.Directory){throw '缺少或不匹配的本项目可信安装记录。'}
$target=Join-Path $profilePath $script:ModuleRelative;Assert-SafePath $target
if(!(Test-Path -LiteralPath $target) -or (Get-FileHash -LiteralPath $target).Hash -ne $record.Sha256){throw '已安装模块存在未知变化，拒绝准备更新。'}
$fx=Get-FxCapability $info $profilePath
if(!$fx.Ready){throw 'fx-autoconfig 来源或配置发生变化，停止准备。'}
$backup=[IO.Path]::GetFullPath($BackupDir);Assert-SafePath $backup
foreach($root in @($info.Directory,$profilePath)){
    if($backup.Equals($root,[StringComparison]::OrdinalIgnoreCase) -or $backup.StartsWith($root.TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)){throw '备份必须在实际安装和 profile 之外。'}
}
if([IO.Path]::GetPathRoot($backup) -ne [IO.Path]::GetPathRoot($profilePath)){throw '备份须与Profile同卷，原子替换才有意义。'}
if(Test-Path -LiteralPath $backup){throw '目标备份目录必须尚不存在。'}
$ownershipPath=Join-Path $profilePath 'proxy-search-switcher.install.json';Assert-SafePath $ownershipPath
$configPath=[IO.Path]::GetFullPath($record.ConfigPath);Assert-SafePath $configPath
if(!(Test-Path -LiteralPath $configPath -PathType Leaf)){throw '本地配置文件缺失。'}
# Only metadata is inspected; never read, copy or hash the secret configuration.
$configMeta=Get-Item -LiteralPath $configPath
$oldModuleHash=(Get-FileHash -LiteralPath $target).Hash
$oldRecordHash=(Get-FileHash -LiteralPath $ownershipPath).Hash
$bundle=Get-Bundle 'zen' $record.ConfigPath
New-Item -ItemType Directory -Path "$backup\originals","$backup\payload" -Force|Out-Null
Copy-Item -LiteralPath $target -Destination "$backup\originals\proxy-search-switcher.sys.mjs"
Copy-Item -LiteralPath $ownershipPath -Destination "$backup\originals\proxy-search-switcher.install.json"
if((Get-FileHash "$backup\originals\proxy-search-switcher.sys.mjs").Hash -ne $oldModuleHash -or
    (Get-FileHash "$backup\originals\proxy-search-switcher.install.json").Hash -ne $oldRecordHash){throw '备份期间原文件发生变化。'}
Write-Utf8 "$backup\payload\proxy-search-switcher.sys.mjs" $bundle
$newHash=(Get-FileHash "$backup\payload\proxy-search-switcher.sys.mjs").Hash
$record.Sha256=$newHash
Write-Utf8 "$backup\payload\proxy-search-switcher.install.json" ($record|ConvertTo-Json)
$newRecordHash=(Get-FileHash "$backup\payload\proxy-search-switcher.install.json").Hash
$fxAudit=@()
$lock=Get-Content -LiteralPath (Join-Path $script:ProjectRoot 'dependencies.lock.json') -Raw|ConvertFrom-Json
foreach($file in $lock.Files){
    $path=if($file.Path.StartsWith('program/')){Join-Path $info.Directory $file.Path.Substring(8)}else{Join-Path $profilePath $file.Path.Substring(8)}
    $fxAudit+=[pscustomobject]@{Target=$path;Sha256=(Get-FileHash -LiteralPath $path).Hash}
}
$plan=[ordered]@{Project='proxy-search-switcher-update';Schema=1;Applied=$false;Browser='zen';InstallDir=$info.Directory;Profile=$profilePath;
    Files=@(@{Target=$target;Original='originals/proxy-search-switcher.sys.mjs';Payload='payload/proxy-search-switcher.sys.mjs';OldSha256=$oldModuleHash;NewSha256=$newHash},
        @{Target=$ownershipPath;Original='originals/proxy-search-switcher.install.json';Payload='payload/proxy-search-switcher.install.json';OldSha256=$oldRecordHash;NewSha256=$newRecordHash});
    ConfigMetadata=@{Path=$configPath;Length=$configMeta.Length;LastWriteTimeUtcTicks=$configMeta.LastWriteTimeUtc.Ticks;ContentRead=$false;WillModify=$false};
    FxAudit=$fxAudit;WillModifyConfig=$false;WillStartBrowser=$false;MustCloseBrowserBeforeDeployment=$true}
Write-Utf8 "$backup\update-plan.json" ($plan|ConvertTo-Json -Depth 6)
Write-Output 'PASS: 已备份两个本项目文件并生成新版载荷；没有修改 Zen；没有读取或复制密钥配置。'
Write-Output "旧模块 SHA-256: $oldModuleHash"
Write-Output "新模块 SHA-256: $newHash"

Write-Output "计划 SHA-256: $((Get-FileHash -LiteralPath (Join-Path $backup 'update-plan.json')).Hash)"
