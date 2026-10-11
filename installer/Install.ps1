[CmdletBinding(SupportsShouldProcess=$true)]
param([ValidateSet('zen','firefox')][string]$Browser='zen',[string]$InstallDir,
    [string]$ProfileDir,[string]$ConfigPath,[switch]$Inspect)
. "$PSScriptRoot\Common.ps1"
$info=Find-Browser $Browser $InstallDir
$profilePath=Get-Profile $ProfileDir
$fx=Get-FxCapability $info $profilePath
if ($Inspect) {
    [pscustomobject]@{Browser=$Browser;InstallDir=$info.Directory;Version=$info.Version;ProfileDir=$profilePath;
        FxAutoconfigVersion=$fx.Version;Ready=$fx.Ready;Problems=@($fx.Problems);
        NewFiles=@($script:ModuleRelative,'proxy-search-switcher.install.json');
        ChangesBrowserInstall=$false;ChangesLoader=$false;ChangesSandboxPolicy=$false}
    return
}
if (!$fx.Ready) { throw "未检测到支持的 fx-autoconfig。不会覆盖加载器或改变沙箱设置。$($fx.Problems -join '; ')" }
Assert-BrowserClosed $info
if (!$ConfigPath) { $ConfigPath=Join-Path $profilePath 'proxy-search-switcher.local.json' }
$configFull=[IO.Path]::GetFullPath($ConfigPath);Assert-SafePath $configFull
if (!(Test-Path -LiteralPath $configFull -PathType Leaf) -or (Get-Item -LiteralPath $configFull).Length -gt 65536) { throw '请先创建小于 64 KiB 的本地 JSON 配置。' }
try { $config=[IO.File]::ReadAllText($configFull) | ConvertFrom-Json; $null=$config.controllerUrl; $null=$config.token }
catch { throw '本地 JSON 配置无效，或缺少 controllerUrl/token。' }
if ($config.controllerUrl -notmatch '^http://127\.0\.0\.1:[1-9]\d{0,4}/?$' -or
    [int]([regex]::Match($config.controllerUrl,':(\d+)/?$').Groups[1].Value) -gt 65535 -or $config.token -isnot [string] -or $config.token -match '[\r\n]') { throw '本地 API 配置无效。' }
$target=Join-Path $profilePath $script:ModuleRelative;Assert-SafePath $target
$existing=Read-Record $profilePath
if ($existing) {
    if ($existing.Browser -ne $Browser -or $existing.InstallDir -ne $info.Directory -or $existing.ConfigPath -ne $configFull) { throw '安装参数已变化，请先卸载。' }
    if (!(Test-Path -LiteralPath $target) -or (Get-FileHash -LiteralPath $target).Hash -ne $existing.Sha256) { throw '本项目模块缺失或被修改，停止重复安装。' }
    Write-Output '已安装，未重复修改。更新代码需先卸载再安装。';return
}
$journalPath=Join-Path $profilePath 'proxy-search-switcher.recovery.json'
if (Test-Path -LiteralPath $journalPath) { throw '存在未完成安装，请先运行 Recover.ps1。' }
if (Test-Path -LiteralPath $target) { throw '模块已经存在且无可信记录，拒绝覆盖。' }
$scriptDir=Split-Path -Parent $target
if (!(Test-Path -LiteralPath $scriptDir -PathType Container)) { throw '缺少 fx-autoconfig 的 chrome/JS 目录。' }
$bundle=Get-Bundle $Browser $configFull
if (!$PSCmdlet.ShouldProcess($profilePath,'增量新增本项目模块及安装记录，保持 fx-autoconfig 不变')) { return }
$temp="$target.pss-tmp";Assert-SafePath $temp
if (Test-Path -LiteralPath $temp) { throw '临时文件存在，拒绝覆盖。' }
$published=$false
try {
    Write-Utf8 $temp $bundle
    $hash=(Get-FileHash -LiteralPath $temp).Hash
    $record=[pscustomobject]@{Project='proxy-search-switcher';Schema=2;Browser=$Browser;Profile=$profilePath;
        InstallDir=$info.Directory;ConfigPath=$configFull;RelativePath=$script:ModuleRelative;Sha256=$hash;OriginalExists=$false;FxRevision=$fx.Revision}
    Write-Utf8 $journalPath ($record | ConvertTo-Json)
    Move-Item -LiteralPath $temp -Destination $target -ErrorAction Stop;$published=$true
    Write-Utf8 (Join-Path $profilePath 'proxy-search-switcher.install.json') ($record | ConvertTo-Json)
    Remove-Item -LiteralPath $journalPath
    Write-Output '安装完成。自行启动浏览器验证；加载器与其他脚本保持原样。'
} catch {
    if ($published -and (Test-Path -LiteralPath $target) -and (Get-FileHash -LiteralPath $target).Hash -eq $hash) { Remove-Item -LiteralPath $target }
    throw '安装失败，已回滚本次新增且未变更的模块。保留恢复记录，请运行 Recover.ps1。'
} finally { if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp } }
