[CmdletBinding(SupportsShouldProcess=$true)]
param([ValidateSet('zen','firefox')][string]$Browser='zen',[string]$InstallDir,[Parameter(Mandatory=$true)][string]$ProfileDir)
. "$PSScriptRoot\Common.ps1"
$info=Find-Browser $Browser $InstallDir;$profilePath=Get-Profile $ProfileDir
$record=Read-Record $profilePath
$target=Join-Path $profilePath $script:ModuleRelative;Assert-SafePath $target
if (!$record) {
    if (Test-Path -LiteralPath $target) { throw '模块存在但无可信安装记录，保持原样。' }
    Write-Output '未安装或已卸载。';return
}
if ($record.Browser -ne $Browser -or $record.InstallDir -ne $info.Directory) { throw '目标与安装记录不符。' }
Assert-BrowserClosed $info
if ((Test-Path -LiteralPath $target) -and (Get-FileHash -LiteralPath $target).Hash -ne $record.Sha256) { throw '模块已被修改；保留文件，请人工核对。' }
if (!$PSCmdlet.ShouldProcess($profilePath,'删除哈希匹配的本项目模块和安装记录')) { return }
if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target -ErrorAction Stop }
Remove-Item -LiteralPath (Join-Path $profilePath 'proxy-search-switcher.install.json')
Write-Output '已卸载。保留 fx-autoconfig、其他脚本、本地配置和当前默认搜索引擎。'
