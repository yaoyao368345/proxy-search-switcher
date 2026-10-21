[CmdletBinding(SupportsShouldProcess=$true)]
param([ValidateSet('Inspect','Install','PrepareLoader','ApplyLoader','PrepareUpdate','ApplyUpdate','Uninstall','RestoreUpdate','RestoreLoader')][string]$Action='Inspect',
    [ValidateSet('zen','firefox')][string]$Browser='zen',[string]$InstallDir,[string]$ProfileDir,
    [string]$FxSourceDir,[string]$BackupDir,[string]$PlanSha256,[switch]$AllowSandboxChange,[switch]$Interactive)
. "$PSScriptRoot\Common.ps1"
. "$PSScriptRoot\Profiles.ps1"
if($Interactive){
    Write-Host 'Proxy Search Switcher 安装向导（不会关闭、启动浏览器或自动启用）'
    Write-Host '1 检查目标  2 增量安装  3 准备全新加载器  4 应用前置安装'
    Write-Host '5 准备升级  6 应用升级  7 卸载项目  8 恢复升级  9 恢复前置  0 退出'
    $choice=Read-Host '选择操作'
    $actions=@{'1'='Inspect';'2'='Install';'3'='PrepareLoader';'4'='ApplyLoader';'5'='PrepareUpdate';'6'='ApplyUpdate';'7'='Uninstall';'8'='RestoreUpdate';'9'='RestoreLoader'}
    if($choice -eq '0'){return}
    if(!$actions.ContainsKey($choice)){throw '无效操作。'}
    $Action=$actions[$choice]
}
$prepared=$Action -in @('ApplyLoader','ApplyUpdate','RestoreUpdate','RestoreLoader')
if($prepared){
    if($Browser -ne 'zen'){throw '当前准备快照应用/恢复仅支持Zen，拒绝忽略浏览器选择。'}
    if(!$BackupDir -and $Interactive){$BackupDir=Read-Host '输入已准备的备份目录（不要填Profile目录）'}
    if(!$BackupDir){throw '必须指定 -BackupDir。'}
    if($Action -eq 'ApplyUpdate'){
        if(!$PlanSha256 -and $Interactive){$PlanSha256=Read-Host '输入准备时审阅的计划SHA-256'}
        if(!$PlanSha256){throw '必须提供已审阅的 -PlanSha256。'}
    }
    if($Action -eq 'ApplyLoader' -and !$AllowSandboxChange -and !$WhatIfPreference){
        if($Interactive){
            Write-Host '此操作仅适用于全新环境，将关闭该安装目录的AutoConfig脚本沙箱，赋予本地脚本浏览器特权。'
            Write-Host '影响使用该安装目录的Profile；不关闭网页沙箱。已有AutoConfig或文件冲突会拒绝。'
            if((Read-Host '审阅备份清单后，输入 ALLOW-AUTOCONFIG 确认') -ceq 'ALLOW-AUTOCONFIG'){$AllowSandboxChange=$true}
        }
        if(!$AllowSandboxChange){throw '前置沙箱变更需显式 -AllowSandboxChange，未修改任何目标。'}
    }
    $planFile=if($Action -in @('ApplyUpdate','RestoreUpdate')){'update-plan.json'}else{'manifest.json'}
    $summaryPath=Join-Path ([IO.Path]::GetFullPath($BackupDir)) $planFile;Assert-SafePath $summaryPath
    $summary=Get-Content -LiteralPath $summaryPath -Raw|ConvertFrom-Json
    $summaryProfile=if($planFile -eq 'update-plan.json'){$summary.Profile}else{$summary.ProfileDir}
    Write-Host "快照目标：$($summary.InstallDir) / $summaryProfile"
    switch($Action){
        'ApplyLoader' {& "$PSScriptRoot\Apply-Preparation.ps1" -BackupDir $BackupDir -WhatIf:$WhatIfPreference}
        'ApplyUpdate' {& "$PSScriptRoot\Apply-Update.ps1" -BackupDir $BackupDir -PlanSha256 $PlanSha256 -WhatIf:$WhatIfPreference}
        'RestoreUpdate' {& "$PSScriptRoot\Restore-Update.ps1" -BackupDir $BackupDir -WhatIf:$WhatIfPreference}
        'RestoreLoader' {& "$PSScriptRoot\Restore-Preparation.ps1" -BackupDir $BackupDir -WhatIf:$WhatIfPreference}
    }
    return
}
try{$info=Find-Browser $Browser $InstallDir}catch{
    if(!$Interactive){throw}
    $InstallDir=Read-Host '未能唯一识别安装，输入浏览器安装目录（含zen.exe/firefox.exe）'
    $info=Find-Browser $Browser $InstallDir
}
if(!$ProfileDir -and $Interactive){
    $relative=if($Browser -eq 'zen'){'zen\profiles.ini'}else{'Mozilla\Firefox\profiles.ini'}
    $profiles=@(Get-ProfileCandidates (Join-Path ([Environment]::GetFolderPath('ApplicationData')) $relative))
    for($i=0;$i -lt $profiles.Count;$i++){Write-Host "$($i+1) $($profiles[$i].Name)  $($profiles[$i].Path)"}
    $answer=Read-Host '用about:profiles核对后，输入编号或Profile根目录；没有默认选择'
    $number=0
    if([int]::TryParse($answer,[ref]$number)){
        if($number -lt 1 -or $number -gt $profiles.Count){throw 'Profile编号无效。'}
        $ProfileDir=$profiles[$number-1].Path
    }else{$ProfileDir=$answer}
}
$profile=Get-Profile $ProfileDir
$fx=Get-FxCapability $info $profile
Write-Host "目标：$($info.Directory) / $profile"
if($Action -eq 'Inspect'){
    $config=Join-Path $profile 'proxy-search-switcher.local.json';Assert-SafePath $config
    $exists=Test-Path -LiteralPath $config
    [pscustomobject]@{Browser=$Browser;InstallDir=$info.Directory;Profile=$profile;LoaderReady=$fx.Ready;Problems=$fx.Problems;
        ProjectInstalled=[bool](Read-Record $profile);ConfigExists=$exists;ConfigContentRead=$false;
        SuggestedAction=if(!$fx.Ready){'PrepareLoader (如有已有/未知文件先人工审查)'}elseif(Test-Path -LiteralPath (Join-Path $profile $script:ModuleRelative)){'PrepareUpdate'}else{'Install'}}
    return
}
if($Action -in @('PrepareLoader','PrepareUpdate')){
    if(!$BackupDir -and $Interactive){$BackupDir=Read-Host '输入全新的外部备份目录；升级备份需与Profile同卷'}
    if(!$BackupDir){throw '必须指定全新的 -BackupDir。'}
}
switch($Action){
    'Install' {& "$PSScriptRoot\Install.ps1" -Browser $Browser -InstallDir $info.Directory -ProfileDir $profile -CreateConfig -WhatIf:$WhatIfPreference}
    'Uninstall' {& "$PSScriptRoot\Uninstall.ps1" -Browser $Browser -InstallDir $info.Directory -ProfileDir $profile -WhatIf:$WhatIfPreference}
    'PrepareLoader' {
        if($Browser -ne 'zen'){throw 'Firefox只支持增量代码适配；全新前置安装当前仅支持Zen。'}
        if(!$FxSourceDir -and $Interactive){
            Write-Host '请独立下载固定fx-autoconfig源码；来源和许可见THIRD-PARTY-NOTICES.md，不使用未知portable封装。'
            $FxSourceDir=Read-Host '输入固定0.10.16源码目录'
        }
        if(!$FxSourceDir){throw '必须指定固定来源 -FxSourceDir。'}
        if($PSCmdlet.ShouldProcess($BackupDir,'仅创建前置安装准备；不修改浏览器')){
            & "$PSScriptRoot\Prepare.ps1" -Browser $Browser -InstallDir $info.Directory -ProfileDir $profile -FxSourceDir $FxSourceDir -BackupDir $BackupDir
            & "$PSScriptRoot\Verify-Preparation.ps1" -BackupDir $BackupDir
        }
    }
    'PrepareUpdate' {
        if($Browser -ne 'zen'){throw '当前安全更新计划仅支持Zen。'}
        if($PSCmdlet.ShouldProcess($BackupDir,'仅备份两个项目文件并准备升级；不读配置正文')){
            & "$PSScriptRoot\Prepare-Update.ps1" -InstallDir $info.Directory -ProfileDir $profile -BackupDir $BackupDir
            & "$PSScriptRoot\Verify-Update.ps1" -BackupDir $BackupDir
        }
    }
}
