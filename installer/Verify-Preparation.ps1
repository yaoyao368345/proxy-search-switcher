[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$BackupDir)
. "$PSScriptRoot\Common.ps1"
$backup=[IO.Path]::GetFullPath($BackupDir);Assert-SafePath $backup
$manifest=Get-Content -LiteralPath (Join-Path $backup 'manifest.json') -Raw|ConvertFrom-Json
if($manifest.Project -ne 'proxy-search-switcher-preparation' -or $manifest.Schema -ne 1){throw '未知备份格式。'}
$info=Find-Browser $manifest.Browser $manifest.InstallDir;$profilePath=Get-Profile $manifest.ProfileDir
$roots=@{install=$info.Directory;profile=$profilePath}
foreach($record in @($manifest.Files)){
    if($record.Root -notin @('install','profile') -or $record.RelativePath -match '(^|[\\/])\.\.([\\/]|$)' -or [IO.Path]::IsPathRooted($record.RelativePath)){throw '不合法目标路径。'}
    $target=Join-Path $roots[$record.Root] $record.RelativePath;Assert-SafePath $target
    if($record.Target -ne $target){throw '目标映射不符。'}
    $payloadRelative="payload/$($record.Root)/$($record.RelativePath)"
    if($record.PayloadRelativePath -ne $payloadRelative){throw '载荷路径不符。'}
    $payload=Join-Path $backup $payloadRelative;Assert-SafePath $payload
    if((Get-FileHash -LiteralPath $payload).Hash -ne $record.PayloadSha256){throw "载荷校验失败：$($record.RelativePath)"}
    if($record.OriginalExists){
        $backupRelative="originals/$($record.Root)/$($record.RelativePath)"
        if($record.BackupRelativePath -ne $backupRelative){throw '原文件备份路径不符。'}
        $original=Join-Path $backup $backupRelative;Assert-SafePath $original
        if(!(Test-Path -LiteralPath $target) -or (Get-FileHash -LiteralPath $target).Hash -ne $record.OriginalSha256 -or
            (Get-FileHash -LiteralPath $original).Hash -ne $record.OriginalSha256){throw "原目标或备份已变更：$target"}
    }elseif(Test-Path -LiteralPath $target){throw "原来不存在的目标现在出现：$target"}
}
foreach($record in @($manifest.AuditFiles)){
    Assert-SafePath $record.Target
    $dest=[IO.Path]::GetFullPath((Join-Path $backup $record.BackupRelativePath))
    if(!$dest.StartsWith($backup.TrimEnd('\')+'\audit\',[StringComparison]::OrdinalIgnoreCase)){throw '审计备份越界。'}
    Assert-SafePath $dest
    if((Get-FileHash -LiteralPath $record.Target).Hash -ne $record.Sha256 -or (Get-FileHash -LiteralPath $dest).Hash -ne $record.Sha256){throw '审计文件或备份已变更。'}
}
Write-Output 'PASS: 所有拟改目标仍符合原始快照；载荷、原始备份和旁路备份 SHA-256 一致。未执行任何浏览器修改。'
