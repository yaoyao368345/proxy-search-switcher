[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$OutputDir)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
$output=[IO.Path]::GetFullPath($OutputDir)
if(Test-Path -LiteralPath $output){throw '输出目录须尚不存在，拒绝覆盖。'}
if($output.StartsWith($repo.TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase) -and !$output.StartsWith((Join-Path $repo 'work')+'\',[StringComparison]::OrdinalIgnoreCase)){throw '使用外部输出目录或work。'}
$version=(Get-Content -LiteralPath (Join-Path $repo 'package.json') -Raw | ConvertFrom-Json).version
if($version -ne '0.1.0-beta.1'){throw '版本不符合此发布候选。'}
$revision=(& git -C $repo rev-parse HEAD).Trim()
if($LASTEXITCODE -ne 0){throw '无法读取来源提交。'}
$tracked=@(& git -C $repo ls-files)
$selected=@($tracked | Where-Object {
 $_ -in @('README.md','LICENSE','THIRD-PARTY-NOTICES.md','NOTICE','dependencies.lock.json','package.json','AGENTS.md','.gitignore') -or
 $_ -match '^(src|installer|scripts)/' -or
 $_ -match '^examples/(config\.example\.json|diagnostics/[^/]+\.js)$' -or
 $_ -in @('docs/INSTALL.md','docs/CONFIGURATION.md','docs/RECOVERY.md','docs/RELEASE-MATRIX.md','docs/RELEASE-NOTES-v0.1.0-beta.1.md','docs/RELEASE-CHECKLIST.md','docs/ARCHITECTURE.md','docs/FINAL-REVIEW.md','docs/BETA-PUBLISHING.md')
})
foreach($file in $selected){if($file -match '(^|/)(work|backups|\.git)/|\.local\.json$|\.env$'){throw '禁止的打包路径。'}}
$bundle=Join-Path $repo 'dist/proxy-search-switcher.sys.mjs'
if(!(Test-Path -LiteralPath $bundle)){throw '先运行npm run build。'}
if(!([IO.File]::ReadAllText($bundle).Contains("// @version $version`n"))){throw '构建版本标识与package.json不一致。'}
New-Item -ItemType Directory -Path $output | Out-Null
$stage=Join-Path $output "proxy-search-switcher-$version"
New-Item -ItemType Directory -Path $stage | Out-Null
foreach($file in $selected){
 $source=Join-Path $repo $file
 if((Get-Item -LiteralPath $source).Attributes -band [IO.FileAttributes]::ReparsePoint){throw '源码文件重解析点异常。'}
 $target=Join-Path $stage $file
 New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
 Copy-Item -LiteralPath $source -Destination $target
}
New-Item -ItemType Directory -Path (Join-Path $stage 'dist') | Out-Null
Copy-Item -LiteralPath $bundle -Destination (Join-Path $stage 'dist/proxy-search-switcher.sys.mjs')
$template=Get-Content -LiteralPath (Join-Path $stage 'examples/config.example.json') -Raw | ConvertFrom-Json
if($template.enabled -ne $false -or $template.token -ne ''){throw '分发模板必须停用且无Token。'}
foreach($file in @(Get-ChildItem -LiteralPath $stage -File -Recurse)){
 $text=[IO.File]::ReadAllText($file.FullName)
 if($text -match '(?i)[A-Z]:[\\/]+Users[\\/]+|Documents[\\/]+Codex'){throw '分发内容含个人路径或标识。'}
 if($text -match '"token"\s*:\s*"[^"\s][^"]*"|-----BEGIN (?:RSA |OPENSSH |EC )?PRIVATE KEY-----'){throw '分发内容含非空凭据字段或私钥。'}
}
$entries=@(Get-ChildItem -LiteralPath $stage -File -Recurse | Sort-Object FullName | ForEach-Object {
 [pscustomobject]@{Path=[IO.Path]::GetRelativePath($stage,$_.FullName).Replace('\','/');Sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash}
})
$manifest=[ordered]@{Version=$version;SourceRevision=$revision;FxAutoconfigBundled=$false;ConfigTemplateEnabled=$false;Files=$entries}
[IO.File]::WriteAllText((Join-Path $stage 'FILE-HASHES.json'),($manifest|ConvertTo-Json -Depth 5),[Text.UTF8Encoding]::new($false))
$zip=Join-Path $output "proxy-search-switcher-$version.zip"
Compress-Archive -LiteralPath $stage -DestinationPath $zip
$verify=Join-Path $output 'verification-extract'
Expand-Archive -LiteralPath $zip -DestinationPath $verify
$extracted=Join-Path $verify "proxy-search-switcher-$version"
$expectedCount=$entries.Count+1
if(@(Get-ChildItem -LiteralPath $extracted -File -Recurse).Count -ne $expectedCount){throw 'ZIP文件数量不符。'}
foreach($entry in $entries){if((Get-FileHash -LiteralPath (Join-Path $extracted $entry.Path)).Hash -ne $entry.Sha256){throw 'ZIP内容校验失败。'}}
if((Get-FileHash -LiteralPath (Join-Path $extracted 'FILE-HASHES.json')).Hash -ne (Get-FileHash -LiteralPath (Join-Path $stage 'FILE-HASHES.json')).Hash){throw 'ZIP清单校验失败。'}
$hash=(Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash
[IO.File]::WriteAllText((Join-Path $output 'SHA256SUMS.txt'),"$hash  proxy-search-switcher-$version.zip`n",[Text.UTF8Encoding]::new($false))
"PASS: $expectedCount files packaged and extracted hashes verified; no loader or local config. ZIP SHA-256: $hash"
