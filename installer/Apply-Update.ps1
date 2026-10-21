[CmdletBinding(SupportsShouldProcess=$true)]
param([Parameter(Mandatory=$true)][string]$BackupDir,
    [Parameter(Mandatory=$true)][ValidatePattern('^[A-Fa-f0-9]{64}$')][string]$PlanSha256)
. "$PSScriptRoot\Common.ps1"
$backup=[IO.Path]::GetFullPath($BackupDir);Assert-SafePath $backup
$planPath=Join-Path $backup 'update-plan.json';Assert-SafePath $planPath
if((Get-FileHash -LiteralPath $planPath).Hash -ne $PlanSha256){throw '计划与审阅SHA-256不符，停止。'}
$plan=Get-Content -LiteralPath $planPath -Raw|ConvertFrom-Json
& "$PSScriptRoot\Verify-Update.ps1" -BackupDir $backup
$info=Find-Browser 'zen' $plan.InstallDir;Assert-BrowserClosed $info
foreach($scope in @($info.Directory,$plan.Profile)){
    if($backup.Equals($scope,[StringComparison]::OrdinalIgnoreCase) -or $backup.StartsWith($scope.TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)){throw '备份/事务目录不能在浏览器或Profile内。'}
}
foreach($record in $plan.Files){if([IO.Path]::GetPathRoot($backup) -ne [IO.Path]::GetPathRoot($record.Target)){throw '原子替换要求备份与Profile在同一磁盘卷。'}}
$transaction=Join-Path $backup 'deployment-transaction';Assert-SafePath $transaction
if(Test-Path -LiteralPath $transaction){throw '已有事务记录，拒绝重放；请先检查或恢复。'}
if(!$PSCmdlet.ShouldProcess($plan.Profile,'按已审阅计划仅更新项目模块和安装记录，保留配置与加载器')){return}
New-Item -ItemType Directory -Path $transaction|Out-Null
$receiptPath=Join-Path $transaction 'receipt.json'
$receipt=[ordered]@{Project='proxy-search-switcher-update-deployment';Status='staging';PlanSha256=$PlanSha256;
    Files=@();ConfigContentRead=$false;ConfigModified=$false;BrowserStarted=$false;AutomaticSwitchingStartedByInstaller=$false}
function Save-UpdateReceipt {Write-Utf8 $receiptPath ($receipt|ConvertTo-Json -Depth 5)}
Save-UpdateReceipt
try{
    for($i=0;$i -lt 2;$i++){
        $record=$plan.Files[$i];$payload=Join-Path $backup $record.Payload
        if((Get-FileHash -LiteralPath $payload).Hash -ne $record.NewSha256){throw '载荷变化。'}
        $stage=Join-Path $transaction "staged-$i"
        Write-NewFile $stage ([IO.File]::ReadAllBytes($payload))
        if((Get-FileHash -LiteralPath $stage).Hash -ne $record.NewSha256){throw '暂存文件校验失败。'}
    }
    # Revalidate the complete baseline before the first replacement.
    & "$PSScriptRoot\Verify-Update.ps1" -BackupDir $backup
    for($i=0;$i -lt 2;$i++){
        Assert-BrowserClosed $info
        if((Get-FileHash -LiteralPath $planPath).Hash -ne $PlanSha256){throw '准备计划变化。'}
        $record=$plan.Files[$i];Assert-SafePath $record.Target
        if((Get-FileHash -LiteralPath $record.Target).Hash -ne $record.OldSha256){throw '目标存在未知修改。'}
        if((Get-FileHash -LiteralPath (Join-Path $backup $record.Original)).Hash -ne $record.OldSha256){throw '原备份损坏。'}
        $stage=Join-Path $transaction "staged-$i";Assert-SafePath $stage
        if((Get-FileHash -LiteralPath $stage).Hash -ne $record.NewSha256){throw '暂存载荷变化。'}
        $original=Join-Path $transaction "replaced-original-$i";Assert-SafePath $original
        if(Test-Path -LiteralPath $original){throw '事务备份冲突。'}
        $event=[pscustomobject]@{Target=$record.Target;OldSha256=$record.OldSha256;ExpectedNewSha256=$record.NewSha256;ActualSha256=$null;Status='replacing'}
        $receipt.Files+=$event;$receipt.Status='updating';Save-UpdateReceipt
        [IO.File]::Replace($stage,$record.Target,$original,$false)
        if((Get-FileHash -LiteralPath $original).Hash -ne $record.OldSha256){throw '替换时原文件发生变化。'}
        $event.ActualSha256=(Get-FileHash -LiteralPath $record.Target).Hash
        if($event.ActualSha256 -ne $record.NewSha256){throw '新目标哈希不符。'}
        $event.Status='verified';Save-UpdateReceipt
    }
    foreach($record in $plan.Files){if((Get-FileHash -LiteralPath $record.Target).Hash -ne $record.NewSha256 -or (Get-FileHash -LiteralPath (Join-Path $backup $record.Original)).Hash -ne $record.OldSha256){throw '最终文件校验失败。'}}
    foreach($audit in $plan.FxAudit){if((Get-FileHash -LiteralPath $audit.Target).Hash -ne $audit.Sha256){throw '加载器审计变化。'}}
    $meta=Get-Item -LiteralPath $plan.ConfigMetadata.Path
    if($meta.Length -ne $plan.ConfigMetadata.Length -or $meta.LastWriteTimeUtc.Ticks -ne $plan.ConfigMetadata.LastWriteTimeUtcTicks){throw '配置元数据变化。'}
    Assert-BrowserClosed $info
    $receipt.Status='updated-awaiting-manual-restart';Save-UpdateReceipt
    Write-Output '更新完成，两文件新哈希通过；配置和公共加载器保持原样。请自行启动浏览器验证。'
}catch{
    $receipt.Status='failed-stop';$receipt['ErrorCode']='verified-update-failed';Save-UpdateReceipt
    throw '更新已停止，保留原备份及事务记录。不要强制重试；检查后使用 Restore-Update.ps1 -WhatIf 恢复已知文件。'
}
