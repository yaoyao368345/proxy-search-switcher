[CmdletBinding()]
param([ValidateSet('zen','firefox')][string]$Browser='zen',[string]$InstallDir,
    [Parameter(Mandatory=$true)][string]$ProfileDir,
    [Parameter(Mandatory=$true)][string]$FxSourceDir,
    [Parameter(Mandatory=$true)][string]$BackupDir)
. "$PSScriptRoot\Common.ps1"
$info=Find-Browser $Browser $InstallDir;$profilePath=Get-Profile $ProfileDir
$source=[IO.Path]::GetFullPath($FxSourceDir);$backup=[IO.Path]::GetFullPath($BackupDir)
Assert-SafePath $source;Assert-SafePath $backup
# Preparation may only write outside the real installation and profile trees.
foreach($root in @($info.Directory,$profilePath)) {
    if($backup.Equals($root,[StringComparison]::OrdinalIgnoreCase) -or $backup.StartsWith($root.TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)) { throw '备份目录不能位于浏览器安装或 profile 内。' }
}
if(Test-Path -LiteralPath $backup){throw '备份目标必须是新目录，避免覆盖已有快照。'}
$lock=Get-Content -LiteralPath (Join-Path $script:ProjectRoot 'dependencies.lock.json') -Raw|ConvertFrom-Json
$fxFiles=@($lock.Files)
foreach($record in $fxFiles){
    $file=Join-Path $source $record.Path;Assert-SafePath $file
    if(!(Test-Path -LiteralPath $file) -or (Get-TextHash $file) -ne $record.Sha256){throw "参考源码与固定版本不符：$($record.Path)"}
}
$configPath=Join-Path $profilePath 'proxy-search-switcher.local.json'
$planned=@()
foreach($record in $fxFiles){
    $rootKind=if($record.Path.StartsWith('program/')){'install'}else{'profile'}
    $relative=$record.Path.Substring(8)
    $planned+= [pscustomobject]@{Root=$rootKind;RelativePath=$relative;Source=Join-Path $source $record.Path;Generated=$false}
}
$planned+= [pscustomobject]@{Root='profile';RelativePath='chrome/JS/proxy-search-switcher.sys.mjs';Source='';Generated=$true}
$planned+= [pscustomobject]@{Root='profile';RelativePath='proxy-search-switcher.local.json';Source=Join-Path $script:ProjectRoot 'examples/config.example.json';Generated=$false}
$roots=@{install=$info.Directory;profile=$profilePath}
$inventory=@()
foreach($plan in $planned){
    $target=Join-Path $roots[$plan.Root] $plan.RelativePath;Assert-SafePath $target
    $exists=Test-Path -LiteralPath $target
    if($exists -and !(Test-Path -LiteralPath $target -PathType Leaf)){throw "目标不是普通文件：$target"}
    $inventory+= [pscustomobject]@{Root=$plan.Root;RelativePath=$plan.RelativePath;Target=$target;OriginalExists=[bool]$exists;
        OriginalSha256=if($exists){(Get-FileHash -LiteralPath $target).Hash}else{$null};PayloadSha256=$null;
        BackupRelativePath="originals/$($plan.Root)/$($plan.RelativePath)";PayloadRelativePath="payload/$($plan.Root)/$($plan.RelativePath)"}
}
# Everything above is read-only. Below writes only to the new backup directory.
New-Item -ItemType Directory -Path $backup | Out-Null
for($i=0;$i -lt $planned.Count;$i++){
    $plan=$planned[$i];$record=$inventory[$i]
    if($record.OriginalExists){
        $dest=Join-Path $backup $record.BackupRelativePath;New-Item -ItemType Directory -Path (Split-Path -Parent $dest) -Force|Out-Null
        Copy-Item -LiteralPath $record.Target -Destination $dest
        if((Get-FileHash -LiteralPath $dest).Hash -ne $record.OriginalSha256){throw '原始备份哈希不符。'}
    }
    $payload=Join-Path $backup $record.PayloadRelativePath;New-Item -ItemType Directory -Path (Split-Path -Parent $payload) -Force|Out-Null
    if($plan.Generated){Write-Utf8 $payload (Get-Bundle $Browser $configPath)}else{Copy-Item -LiteralPath $plan.Source -Destination $payload}
    $record.PayloadSha256=(Get-FileHash -LiteralPath $payload).Hash
}
$audit=@()
foreach($file in @((Join-Path $info.Directory 'defaults\pref\channel-prefs.js'),
    (Join-Path $profilePath 'chrome\zen-themes.css'),
    (Join-Path (Split-Path -Parent (Split-Path -Parent $profilePath)) 'profiles.ini'),
    (Join-Path (Split-Path -Parent (Split-Path -Parent $profilePath)) 'installs.ini'))){
    if(Test-Path -LiteralPath $file -PathType Leaf){
        $hash=(Get-FileHash -LiteralPath $file).Hash
        $relative='audit/'+($audit.Count.ToString())+'-'+[IO.Path]::GetFileName($file)
        $dest=Join-Path $backup $relative;New-Item -ItemType Directory -Path (Split-Path -Parent $dest) -Force|Out-Null
        Copy-Item -LiteralPath $file -Destination $dest
        if((Get-FileHash -LiteralPath $dest).Hash -ne $hash){throw '审计备份哈希不符。'}
        $audit+= [pscustomobject]@{Target=$file;BackupRelativePath=$relative;Sha256=$hash}
    }
}
Copy-Item -LiteralPath (Join-Path $source 'LICENSE') -Destination (Join-Path $backup 'fx-autoconfig-LICENSE.txt')
$dirs=@()
foreach($relative in @('chrome/utils','chrome/JS','chrome/CSS','chrome/resources')){
    $dirs+=[pscustomobject]@{Root='profile';RelativePath=$relative;OriginalExists=[bool](Test-Path -LiteralPath (Join-Path $profilePath $relative))}
}
$manifest=[ordered]@{Project='proxy-search-switcher-preparation';Schema=1;PreparedForDate='2026-10-11';Browser=$Browser;
    InstallDir=$info.Directory;Version=$info.Version;ProfileDir=$profilePath;FxRevision=$lock.Revision;FxVersion=$lock.Version;
    SandboxChange='general.config.sandbox_enabled: default true -> false (NOT APPLIED)';Applied=$false;
    Files=$inventory;Directories=$dirs;AuditFiles=$audit;
    Limitations=@('No browser files changed','No restart or shutdown','Local API token not read or filled','Real runtime verification pending')}
Write-Utf8 (Join-Path $backup 'manifest.json') ($manifest|ConvertTo-Json -Depth 8)
Write-Output "备份与安装载荷已准备：$backup"
Write-Output "拟新增/保留文件：$($inventory.Count)；原始文件备份：$(@($inventory|Where-Object OriginalExists).Count)；旁路审计备份：$($audit.Count)"
Write-Output '未修改浏览器；未应用沙箱变更。执行真实安装前必须重新核对并获得用户授权。'
