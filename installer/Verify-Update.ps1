[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$BackupDir)
. "$PSScriptRoot\Common.ps1"
$backup=[IO.Path]::GetFullPath($BackupDir);Assert-SafePath $backup
$plan=Get-Content -LiteralPath "$backup\update-plan.json" -Raw|ConvertFrom-Json
if($plan.Project -ne 'proxy-search-switcher-update' -or $plan.Schema -ne 1 -or $plan.Browser -ne 'zen'){throw '未知更新计划。'}
$info=Find-Browser 'zen' $plan.InstallDir;$profilePath=Get-Profile $plan.Profile
$expected=@((Join-Path $profilePath $script:ModuleRelative),(Join-Path $profilePath 'proxy-search-switcher.install.json'))
if(@($plan.Files).Count -ne 2){throw '更新范围必须是两个本项目文件。'}
for($i=0;$i -lt 2;$i++){
    $record=$plan.Files[$i]
    $name=if($i -eq 0){'proxy-search-switcher.sys.mjs'}else{'proxy-search-switcher.install.json'}
    if($record.Target -ne $expected[$i] -or $record.Original -ne "originals/$name" -or $record.Payload -ne "payload/$name"){throw '更新目标或备份路径不符。'}
    Assert-SafePath $record.Target
    foreach($file in @((Join-Path $backup $record.Original),(Join-Path $backup $record.Payload))){Assert-SafePath $file}
    if((Get-FileHash -LiteralPath $record.Target).Hash -ne $record.OldSha256 -or
        (Get-FileHash -LiteralPath (Join-Path $backup $record.Original)).Hash -ne $record.OldSha256 -or
        (Get-FileHash -LiteralPath (Join-Path $backup $record.Payload)).Hash -ne $record.NewSha256){throw '原目标、备份或新版载荷哈希发生变化。'}
}
$owned=Read-Record $profilePath
if(!$owned -or $owned.Sha256 -ne $plan.Files[0].OldSha256 -or $owned.InstallDir -ne $info.Directory){throw '模块与原安装记录不一致。'}
$next=Get-Content -LiteralPath (Join-Path $backup $plan.Files[1].Payload) -Raw|ConvertFrom-Json
if($next.Sha256 -ne $plan.Files[0].NewSha256 -or $next.ConfigPath -ne $owned.ConfigPath -or $next.Profile -ne $profilePath){throw '新安装记录与载荷不一致。'}
$fx=Get-FxCapability $info $profilePath;if(!$fx.Ready){throw '前置加载器发生变化。'}
foreach($file in $plan.FxAudit){Assert-SafePath $file.Target;if((Get-FileHash -LiteralPath $file.Target).Hash -ne $file.Sha256){throw '共享加载器文件变更。'}}
if($plan.ConfigMetadata.Path -ne $owned.ConfigPath){throw '配置元数据路径不符。'}
Assert-SafePath $plan.ConfigMetadata.Path
$meta=Get-Item -LiteralPath $plan.ConfigMetadata.Path
if($meta.Length -ne $plan.ConfigMetadata.Length -or $meta.LastWriteTimeUtc.Ticks -ne $plan.ConfigMetadata.LastWriteTimeUtcTicks){throw '配置元数据发生变化；停止，不读取内容。'}
Write-Output 'PASS: 更新基线、两份原备份及新版载荷哈希一致；配置和加载器未变；没有部署。'
