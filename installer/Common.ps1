Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if($PSVersionTable.PSVersion -lt [version]'7.2'){throw '需要 PowerShell 7.2+（pwsh）。安装地址：https://aka.ms/powershell-release'}
$script:ProjectRoot=Split-Path -Parent $PSScriptRoot
$script:ModuleRelative='chrome\JS\proxy-search-switcher.sys.mjs'

function Assert-SafePath([string]$Path) {
    $current=[IO.Path]::GetFullPath($Path)
    while ($current) {
        if (Test-Path -LiteralPath $current) {
            if ((Get-Item -LiteralPath $current -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "路径包含链接，拒绝自动修改：$current。请指定真实路径。" }
        }
        $parent=Split-Path -Parent $current
        if ($parent -eq $current) { break }
        $current=$parent
    }
}
function Find-Browser([string]$Browser,[string]$InstallDir) {
    $exe=if($Browser -eq 'zen'){'zen.exe'}else{'firefox.exe'}
    $candidates=@()
    if ($InstallDir) { $candidates=@([IO.Path]::GetFullPath($InstallDir)) }
    else {
        foreach ($process in @(Get-Process -Name ([IO.Path]::GetFileNameWithoutExtension($exe)) -ErrorAction SilentlyContinue)) {
            if ($process.Path) { $candidates+=Split-Path -Parent $process.Path }
        }
        foreach ($hive in @('HKCU:','HKLM:')) {
            foreach ($key in @("$hive\Software\Microsoft\Windows\CurrentVersion\App Paths\$exe","$hive\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\App Paths\$exe")) {
                if (Test-Path -LiteralPath $key) {
                    $value=(Get-Item -LiteralPath $key).GetValue('')
                    if ($value) { $candidates+=Split-Path -Parent $value.Trim('"') }
                }
            }
        }
        $folder=if($Browser -eq 'zen'){'Zen Browser'}else{'Mozilla Firefox'}
        $candidates+=@("$env:ProgramFiles\$folder","${env:ProgramFiles(x86)}\$folder","$env:LOCALAPPDATA\Programs\$folder")
        foreach ($base in @("$env:USERPROFILE\scoop",'D:\scoop')) {
            $app=if($Browser -eq 'zen'){'zen-browser'}else{'firefox'}
            $link="$base\apps\$app\current"
            if (Test-Path -LiteralPath $link) {
                $item=Get-Item -LiteralPath $link
                if ($item.Target) { $candidates+=@($item.Target)[0] } else { $candidates+=$link }
            }
        }
    }
    $installMatches=@($candidates | Select-Object -Unique | Where-Object {Test-Path -LiteralPath (Join-Path $_ $exe)})
    if ($installMatches.Count -ne 1) { throw "发现 $($installMatches.Count) 个安装目录，请用 -InstallDir 指定。" }
    $directory=[IO.Path]::GetFullPath($installMatches[0]);Assert-SafePath $directory
    $ini=Join-Path $directory 'application.ini'
    if (!(Test-Path -LiteralPath $ini)) { throw '缺少 application.ini。' }
    $text=[IO.File]::ReadAllText($ini)
    $expected=if($Browser -eq 'zen'){'Zen'}else{'Firefox'}
    if ($text -notmatch "(?m)^Name=$expected\s*$") { throw '浏览器名称不符。' }
    return [pscustomobject]@{Directory=$directory;Executable=$exe;Version=[regex]::Match($text,'(?m)^Version=(.+)$').Groups[1].Value.Trim()}
}
function Assert-BrowserClosed($Info) {
    Assert-NoBrowserHelpers $Info
    foreach ($process in @(Get-Process -Name ([IO.Path]::GetFileNameWithoutExtension($Info.Executable)) -ErrorAction SilentlyContinue)) {
        if (!$process.Path -or [IO.Path]::GetFullPath($process.Path) -eq (Join-Path $Info.Directory $Info.Executable)) { throw '请自行退出目标浏览器后重试。脚本不会关闭浏览器。' }
    }
}
function Assert-NoBrowserHelpers($Info) {
    foreach($name in @('plugin-container','private_browsing','nmhproxy','pingsender','crashhelper','crashreporter','updater')){
        foreach($process in @(Get-Process -Name $name -ErrorAction SilentlyContinue)){
            try {$path=$process.Path} catch {throw '无法确认辅助进程路径，请手动确认浏览器已完全退出。'}
            if(!$path){throw '辅助进程路径不可见，停止修改浏览器文件。'}
            if([IO.Path]::GetFullPath($path).StartsWith($Info.Directory.TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)){throw '目标浏览器辅助进程仍运行，请手动退出后重试。'}
        }
    }
}
function Get-Profile([string]$ProfileDir) {
    if (!$ProfileDir) { throw '请用 -ProfileDir 指定 about:profiles 中的配置文件根目录，避免误改其他 profile。' }
    $full=[IO.Path]::GetFullPath($ProfileDir);Assert-SafePath $full
    if (!(Test-Path -LiteralPath $full -PathType Container)) { throw 'Profile 目录不存在。' }
    return $full
}
function Get-TextHash([string]$Path) {
    $text=[IO.File]::ReadAllText($Path).Replace("`r`n","`n")
    return [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($text)))
}
function Get-FxCapability($Info,[string]$profilePath) {
    $lock=[IO.File]::ReadAllText((Join-Path $script:ProjectRoot 'dependencies.lock.json')) | ConvertFrom-Json
    $problems=@()
    foreach ($record in @($lock.Files)) {
        if ($record.Path.StartsWith('program/')) { $path=Join-Path $Info.Directory $record.Path.Substring(8) }
        elseif ($record.Path.StartsWith('profile/')) { $path=Join-Path $profilePath $record.Path.Substring(8) }
        else { throw '依赖记录路径不合法。' }
        Assert-SafePath $path
        if (!(Test-Path -LiteralPath $path -PathType Leaf)) { $problems+="缺少 $path" }
        elseif ((Get-TextHash $path) -ne $record.Sha256) { $problems+="需审查不同版本或修改过的加载器：$path" }
    }
    # Exact upstream files confirm the loader and canonical chrome:// mapping.
    # Any additional AutoConfig selector could supersede it; refuse to merge.
    foreach ($file in @(Get-ChildItem -LiteralPath (Join-Path $Info.Directory 'defaults\pref') -Filter '*.js' -File -ErrorAction SilentlyContinue)) {
        if ($file.Name -eq 'config-prefs.js') { continue }
        if ([IO.File]::ReadAllText($file.FullName) -match 'general\.config\.(filename|sandbox_enabled|obscure_value|vendor)|autoadmin\.global_config_url') { $problems+="额外 AutoConfig 策略：$($file.FullName)" }
    }
    return [pscustomobject]@{Ready=$problems.Count -eq 0;Version=$lock.Version;Revision=$lock.Revision;Problems=$problems}
}
function Get-Bundle([string]$Browser,[string]$ConfigPath) {
    $files=@('src/core/state.cjs','src/core/mihomo.cjs','src/core/switcher.cjs','src/adapters/search.cjs',
        'src/adapters/zen/entry.cjs','src/adapters/firefox/entry.cjs','src/platform/windows/wininet.cjs','src/platform/windows/toolhelp.cjs','src/platform/windows/native.cjs','src/adapters/request.cjs','src/runtime/start.cjs')
    $text="// ==UserScript==`n// @name Proxy Search Switcher`n// @version 0.1.0-beta.1`n// @description Switch the real default search engine from explicit proxy state`n// ==/UserScript==`nconst scope = {};`n"
    foreach ($file in $files) { $text+="`n// $file`n"+[IO.File]::ReadAllText((Join-Path $script:ProjectRoot $file)).Replace('})(globalThis);','})(scope);')+"`n" }
    $json=ConvertTo-Json -InputObject ([IO.Path]::GetFullPath($ConfigPath)) -Compress
    $text=$text.Replace('browser:"zen",configPath:"__PSS_CONFIG_PATH__"',"browser:`"$Browser`",configPath:$json")
    # The fallback literal remains in runtime code; only the INSTALL marker changes.
    if ($text.Contains('configPath:"__PSS_CONFIG_PATH__"')) { throw '构建替换失败。' }
    return $text.Replace("`r`n","`n")+"`nexport function getStatus() { return scope.PSSInstance?.status; }`nexport function stop() { scope.PSSInstance?.stop?.(); }`n"
}
function Write-Utf8([string]$Path,[string]$Text) { [IO.File]::WriteAllText($Path,$Text,[Text.UTF8Encoding]::new($false)) }
function Read-Record([string]$profilePath,[switch]$Recovery) {
    $name=if($Recovery){'proxy-search-switcher.recovery.json'}else{'proxy-search-switcher.install.json'}
    $path=Join-Path $profilePath $name;Assert-SafePath $path
    if (!(Test-Path -LiteralPath $path)) { return $null }
    $record=[IO.File]::ReadAllText($path) | ConvertFrom-Json
    if ($record.Project -ne 'proxy-search-switcher' -or $record.Schema -ne 2 -or $record.Profile -ne $profilePath -or
        $record.RelativePath -ne $script:ModuleRelative -or $record.Sha256 -notmatch '^[A-Fa-f0-9]{64}$' -or $record.OriginalExists -ne $false) { throw '安装/恢复记录不可信。' }
    return $record
}

function Write-NewFile([string]$Path,[byte[]]$Bytes) {
    Assert-SafePath $Path
    $stream=[IO.FileStream]::new($Path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
    try {$stream.Write($Bytes,0,$Bytes.Length);$stream.Flush($true)} finally {$stream.Dispose()}
}
