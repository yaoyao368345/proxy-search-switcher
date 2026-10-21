[CmdletBinding(SupportsShouldProcess=$true)]
param([Parameter(Mandatory=$true)][string]$BackupDir,[switch]$AllowRunningBrowser)
. "$PSScriptRoot\Common.ps1"
$backup=[IO.Path]::GetFullPath($BackupDir);Assert-SafePath $backup
& "$PSScriptRoot\Verify-Preparation.ps1" -BackupDir $backup
$manifest=Get-Content -LiteralPath (Join-Path $backup 'manifest.json') -Raw|ConvertFrom-Json
$info=Find-Browser $manifest.Browser $manifest.InstallDir
$profilePath=Get-Profile $manifest.ProfileDir
if($manifest.Browser -ne 'zen' -or $manifest.FxVersion -ne '0.10.16' -or $manifest.FxRevision -ne 'dfdab5684faffc112b76ccb1d8cab7f75da0102c'){throw '此安装入口仅支持审查过的 Zen/fx-autoconfig 版本。'}
if(!$AllowRunningBrowser){Assert-BrowserClosed $info}
$allowed=@{
    install=@('config.js','defaults/pref/config-prefs.js');
    profile=@('chrome/utils/boot.sys.mjs','chrome/utils/chrome.manifest','chrome/utils/fs.sys.mjs','chrome/utils/utils.sys.mjs',
        'chrome/utils/uc_api.sys.mjs','chrome/utils/module_loader.mjs','chrome/JS/proxy-search-switcher.sys.mjs','proxy-search-switcher.local.json')
}
if(@($manifest.Files).Count -ne 10){throw '安装清单数量不符。'}
$keys=@()
foreach($record in $manifest.Files){
    if($record.Root -notin @('install','profile') -or $record.RelativePath -notin $allowed[$record.Root] -or $record.OriginalExists){throw '仅允许审查清单中的新增文件。'}
    $keys+="$($record.Root)/$($record.RelativePath)"
}
if(@($keys|Select-Object -Unique).Count -ne 10){throw '安装清单包含重复项。'}
foreach($directory in $manifest.Directories){
    if($directory.Root -ne 'profile' -or $directory.RelativePath -notin @('chrome/utils','chrome/JS','chrome/CSS','chrome/resources')){throw '目录清单不符。'}
    $target=Join-Path $profilePath $directory.RelativePath;Assert-SafePath $target
    if((Test-Path -LiteralPath $target) -ne [bool]$directory.OriginalExists){throw "目录状态变化：$target"}
}
foreach($file in @(Get-ChildItem -LiteralPath (Join-Path $info.Directory 'defaults\pref') -Filter '*.js' -File)){
    if([IO.File]::ReadAllText($file.FullName) -match 'general\.config\.|autoadmin\.global_config_url'){throw "发现未知 AutoConfig：$($file.FullName)"}
}
if(@(Get-ChildItem -LiteralPath $info.Directory -Filter '*.cfg' -File).Count){throw '存在未知 AutoConfig cfg 文件。'}
$formalPath=Join-Path $profilePath 'proxy-search-switcher.install.json';Assert-SafePath $formalPath
if(Test-Path -LiteralPath $formalPath){throw '正式记录已存在，拒绝覆盖。'}
$receiptPath=Join-Path $backup 'installation-receipt.json'
if(Test-Path -LiteralPath $receiptPath){throw '此快照已有执行记录，拒绝重复应用。'}
$configRecord=@($manifest.Files|Where-Object RelativePath -eq 'proxy-search-switcher.local.json')[0]
$config=Get-Content -LiteralPath (Join-Path $backup $configRecord.PayloadRelativePath) -Raw|ConvertFrom-Json
if($config.enabled -ne $false -or $config.token -ne ''){throw '分阶段安装要求 enabled=false、token 为空。'}
function Write-NewBytes([string]$Path,[byte[]]$Bytes){
    Assert-SafePath $Path
    $stream=[IO.FileStream]::new($Path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
    try{$stream.Write($Bytes,0,$Bytes.Length);$stream.Flush($true)}finally{$stream.Dispose()}
}
if(!$PSCmdlet.ShouldProcess($info.Directory,'按固定快照新增 Zen 加载器及停用状态模块；不停止或重启浏览器')){return}
$receipt=[ordered]@{Project='proxy-search-switcher-stage1';Status='installing';BackupDir=$backup;BrowserWasAllowedToRemainRunning=[bool]$AllowRunningBrowser;Files=@();Directories=@();ErrorCode=$null}
Write-Utf8 $receiptPath ($receipt|ConvertTo-Json -Depth 6)
try{
    foreach($directory in $manifest.Directories){
        if(!$directory.OriginalExists){
            $target=Join-Path $profilePath $directory.RelativePath
            if(Test-Path -LiteralPath $target){throw "目录在检查后出现：$target"}
            New-Item -ItemType Directory -Path $target -ErrorAction Stop|Out-Null
            $receipt.Directories+= $target
        }
    }
    # Publish the AutoConfig preference selector LAST, after all supporting files.
    $ordered=@($manifest.Files|Sort-Object @{Expression={if($_.RelativePath -eq 'defaults/pref/config-prefs.js'){1}else{0}}})
    foreach($record in $ordered){
        $payload=Join-Path $backup $record.PayloadRelativePath
        if((Get-FileHash -LiteralPath $payload).Hash -ne $record.PayloadSha256){throw '载荷在检查后变化。'}
        Write-NewBytes $record.Target ([IO.File]::ReadAllBytes($payload))
        if((Get-FileHash -LiteralPath $record.Target).Hash -ne $record.PayloadSha256){throw '新文件写入哈希不符。'}
        $receipt.Files+= [pscustomobject]@{Target=$record.Target;Sha256=$record.PayloadSha256}
        Write-Utf8 $receiptPath ($receipt|ConvertTo-Json -Depth 6)
    }
    $module=@($manifest.Files|Where-Object RelativePath -eq 'chrome/JS/proxy-search-switcher.sys.mjs')[0]
    $ownership=[ordered]@{Project='proxy-search-switcher';Schema=2;Browser='zen';Profile=$profilePath;InstallDir=$info.Directory;
        ConfigPath=$configRecord.Target;RelativePath=$script:ModuleRelative;Sha256=$module.PayloadSha256;OriginalExists=$false;FxRevision=$manifest.FxRevision}
    $bytes=[Text.UTF8Encoding]::new($false).GetBytes(($ownership|ConvertTo-Json))
    Write-NewBytes $formalPath $bytes
    $receipt.Files+= [pscustomobject]@{Target=$formalPath;Sha256=(Get-FileHash -LiteralPath $formalPath).Hash}
    $capability=Get-FxCapability $info $profilePath
    if(!$capability.Ready){throw '安装后加载器依赖核验失败。'}
    foreach($audit in $manifest.AuditFiles){if((Get-FileHash -LiteralPath $audit.Target).Hash -ne $audit.Sha256){throw '未修改文件的审计哈希变化。'}}
    $receipt.Status='installed-awaiting-manual-restart'
    Write-Utf8 $receiptPath ($receipt|ConvertTo-Json -Depth 6)
    Write-Output "PASS: $($receipt.Files.Count) 个新增文件均经 SHA-256 核验；加载器文件完整；enabled=false；token 为空。"
    Write-Output '未关闭或重启 Zen。安装完成后暂停，等待用户手动重启。'
}catch{
    $receipt.Status='failed-stop';$receipt.ErrorCode='stage1-installation-failed'
    Write-Utf8 $receiptPath ($receipt|ConvertTo-Json -Depth 6)
    throw "安装异常，已停止；保留诊断记录：$receiptPath。自行关闭 Zen 后，按备份恢复方案处理。"
}
