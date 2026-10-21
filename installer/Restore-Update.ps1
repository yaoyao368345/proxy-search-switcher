[CmdletBinding(SupportsShouldProcess=$true)]
param([Parameter(Mandatory=$true)][string]$BackupDir)
. "$PSScriptRoot\Common.ps1"
$backup=[IO.Path]::GetFullPath($BackupDir);Assert-SafePath $backup
$plan=Get-Content -LiteralPath "$backup\update-plan.json" -Raw|ConvertFrom-Json
if($plan.Project -ne 'proxy-search-switcher-update' -or $plan.Schema -ne 1 -or $plan.Browser -ne 'zen'){throw '未知更新计划。'}
$info=Find-Browser 'zen' $plan.InstallDir;$profilePath=Get-Profile $plan.Profile
Assert-BrowserClosed $info
$expected=@((Join-Path $profilePath $script:ModuleRelative),(Join-Path $profilePath 'proxy-search-switcher.install.json'))
if(@($plan.Files).Count -ne 2){throw '恢复范围不符。'}
for($i=0;$i -lt 2;$i++){
    $record=$plan.Files[$i];$name=if($i -eq 0){'proxy-search-switcher.sys.mjs'}else{'proxy-search-switcher.install.json'}
    if($record.Target -ne $expected[$i] -or $record.Original -ne "originals/$name"){throw '恢复目标不合法。'}
    Assert-SafePath $record.Target;$original=Join-Path $backup $record.Original;Assert-SafePath $original
    if((Get-FileHash -LiteralPath $original).Hash -ne $record.OldSha256){throw '原备份损坏。'}
    if(!(Test-Path -LiteralPath $record.Target)){throw '目标缺失，需人工恢复。'}
    $hash=(Get-FileHash -LiteralPath $record.Target).Hash
    if($hash -ne $record.OldSha256 -and $hash -ne $record.NewSha256){throw '目标存在未知修改，不覆盖任何文件。'}
}
if(!$PSCmdlet.ShouldProcess($profilePath,'仅恢复两个本项目文件，不改本地配置和 fx-autoconfig')){return}
foreach($record in $plan.Files){
    if((Get-FileHash -LiteralPath $record.Target).Hash -ne $record.OldSha256){
        Copy-Item -LiteralPath (Join-Path $backup $record.Original) -Destination $record.Target -Force
    }
    if((Get-FileHash -LiteralPath $record.Target).Hash -ne $record.OldSha256){throw '恢复后校验失败，停止。'}
}
Write-Output 'PASS: 两个本项目文件已恢复原始哈希；配置和共享加载器未改动。'
