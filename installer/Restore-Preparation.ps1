[CmdletBinding(SupportsShouldProcess=$true)]
param([Parameter(Mandatory=$true)][string]$BackupDir)
. "$PSScriptRoot\Common.ps1"
$backup=[IO.Path]::GetFullPath($BackupDir);Assert-SafePath $backup
$manifest=Get-Content -LiteralPath (Join-Path $backup 'manifest.json') -Raw|ConvertFrom-Json
if($manifest.Project -ne 'proxy-search-switcher-preparation' -or $manifest.Schema -ne 1){throw '未知备份格式。'}
$info=Find-Browser $manifest.Browser $manifest.InstallDir;$profilePath=Get-Profile $manifest.ProfileDir
Assert-BrowserClosed $info
$roots=@{install=$info.Directory;profile=$profilePath}
$allowed=@{
    install=@('config.js','defaults/pref/config-prefs.js');
    profile=@('chrome/utils/boot.sys.mjs','chrome/utils/chrome.manifest','chrome/utils/fs.sys.mjs','chrome/utils/utils.sys.mjs',
        'chrome/utils/uc_api.sys.mjs','chrome/utils/module_loader.mjs','chrome/JS/proxy-search-switcher.sys.mjs','proxy-search-switcher.local.json')
}
# Validate all targets and backup bytes before changing any file.
foreach($record in @($manifest.Files)){
    if($record.Root -notin @('install','profile') -or $record.RelativePath -notin $allowed[$record.Root]){throw '备份记录含未知目标。'}
    $target=Join-Path $roots[$record.Root] $record.RelativePath
    if($record.Target -ne $target){throw '备份目标不符。'};Assert-SafePath $target
    $expectedBackup="originals/$($record.Root)/$($record.RelativePath)"
    if($record.BackupRelativePath -ne $expectedBackup){throw '备份来源路径不符。'}
    if($record.OriginalExists){
        $original=Join-Path $backup $expectedBackup;Assert-SafePath $original
        if((Get-FileHash -LiteralPath $original).Hash -ne $record.OriginalSha256){throw '原始备份损坏。'}
    }
    if(Test-Path -LiteralPath $target){
        $hash=(Get-FileHash -LiteralPath $target).Hash
        $localConfig=$record.Root -eq 'profile' -and $record.RelativePath -eq 'proxy-search-switcher.local.json'
        if(!$localConfig -and $hash -ne $record.PayloadSha256 -and (!$record.OriginalExists -or $hash -ne $record.OriginalSha256)){throw "文件已被另行修改，停止回滚：$target"}
    }
}
foreach($record in @($manifest.Directories)){
    if($record.Root -ne 'profile' -or $record.RelativePath -notin @('chrome/utils','chrome/JS','chrome/CSS','chrome/resources')){throw '目录恢复记录不合法。'}
    Assert-SafePath (Join-Path $profilePath $record.RelativePath)
}
if(!$PSCmdlet.ShouldProcess($info.Directory,'按已验证备份恢复准备时的文件状态（含 AutoConfig 沙箱策略文件）')){return}
# Remove the AutoConfig selector before scripts, so interruption fails safely.
$records=@($manifest.Files|Sort-Object @{Expression={if($_.RelativePath -eq 'defaults/pref/config-prefs.js'){0}else{1}}})
foreach($record in $records){
    $target=Join-Path $roots[$record.Root] $record.RelativePath
    if($record.Root -eq 'profile' -and $record.RelativePath -eq 'proxy-search-switcher.local.json'){continue}
    if($record.OriginalExists){
        if(!(Test-Path -LiteralPath $target) -or (Get-FileHash -LiteralPath $target).Hash -ne $record.OriginalSha256){
            Copy-Item -LiteralPath (Join-Path $backup $record.BackupRelativePath) -Destination $target -Force
        }
    } elseif(Test-Path -LiteralPath $target){Remove-Item -LiteralPath $target}
}
# Only remove known directories that were absent AND are now empty.
foreach($record in @($manifest.Directories)){
    $target=Join-Path $profilePath $record.RelativePath;Assert-SafePath $target
    if(!$record.OriginalExists -and (Test-Path -LiteralPath $target) -and @(Get-ChildItem -LiteralPath $target -Force).Count -eq 0){Remove-Item -LiteralPath $target}
}
foreach($record in @($manifest.Files)){
    $target=Join-Path $roots[$record.Root] $record.RelativePath
    if($record.Root -eq 'profile' -and $record.RelativePath -eq 'proxy-search-switcher.local.json'){continue}
    if($record.OriginalExists){if((Get-FileHash -LiteralPath $target).Hash -ne $record.OriginalSha256){throw '恢复后哈希不符。'}}
    elseif(Test-Path -LiteralPath $target){throw '恢复后新增文件仍存在。'}
}
Write-Output '已恢复准备时状态。第三方修改、其他用户脚本与当前默认搜索引擎不会被强制覆盖。'
