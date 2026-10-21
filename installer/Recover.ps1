[CmdletBinding(SupportsShouldProcess=$true)]
param([ValidateSet('zen','firefox')][string]$Browser='zen',[string]$InstallDir,[Parameter(Mandatory=$true)][string]$ProfileDir)
. "$PSScriptRoot\Common.ps1"
$info=Find-Browser $Browser $InstallDir;$profilePath=Get-Profile $ProfileDir
$record=Read-Record $profilePath -Recovery
if (!$record) { Write-Output '没有待恢复安装。';return }
if ($record.Browser -ne $Browser -or $record.InstallDir -ne $info.Directory) { throw '恢复记录与目标不符。' }
Assert-BrowserClosed $info
$formal=Read-Record $profilePath
if ($formal) { throw '正式安装记录也存在，请先 Uninstall.ps1，随后 Recover.ps1。' }
$target=Join-Path $profilePath $script:ModuleRelative;Assert-SafePath $target
if ((Test-Path -LiteralPath $target) -and (Get-FileHash -LiteralPath $target).Hash -ne $record.Sha256) { throw '恢复模块已变更，保持原样。' }
if (!$PSCmdlet.ShouldProcess($profilePath,'按恢复记录回滚本项目新增模块')) { return }
if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target }
Remove-Item -LiteralPath (Join-Path $profilePath 'proxy-search-switcher.recovery.json')
Write-Output '已恢复安装前状态；fx-autoconfig 与本地配置保持原样。'
