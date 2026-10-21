# Read only profile names/paths; never read a browser's local secret configuration.
function Get-ProfileCandidates([string]$ProfilesIni){
    Assert-SafePath $ProfilesIni
    if(!(Test-Path -LiteralPath $ProfilesIni -PathType Leaf)){return}
    $records=@();$entry=$null
    foreach($line in [IO.File]::ReadAllLines($ProfilesIni)){
        $text=$line.Trim()
        if(!$text -or $text.StartsWith(';') -or $text.StartsWith('#')){continue}
        if($text -match '^\[(.+)\]$'){
            if($null -ne $entry){$records+=,$entry}
            $entry=if($Matches[1] -match '^Profile\d+$'){@{}}else{$null}
            continue
        }
        if($null -ne $entry -and $text -match '^([^=]+)=(.*)$'){
            $key=$Matches[1].Trim();$value=$Matches[2].Trim()
            if($entry.ContainsKey($key)){throw 'profiles.ini含重复字段，停止自动列举。'}
            $entry[$key]=$value
        }
    }
    if($null -ne $entry){$records+=,$entry}
    foreach($item in $records){
        if(!$item.ContainsKey('Path') -or !$item.ContainsKey('IsRelative') -or $item.IsRelative -notin @('0','1')){throw 'Profile路径定义不明确，请用about:profiles手动确认。'}
        if($item.IsRelative -eq '1' -and [IO.Path]::IsPathRooted($item.Path)){throw '相对Profile路径不能是绝对路径。'}
        $path=if($item.IsRelative -eq '1'){Join-Path (Split-Path -Parent $ProfilesIni) $item.Path}else{$item.Path}
        if($item.IsRelative -eq '0' -and ![IO.Path]::IsPathFullyQualified($path)){throw '绝对Profile路径无效。'}
        $path=[IO.Path]::GetFullPath($path);Assert-SafePath $path
        if(Test-Path -LiteralPath $path -PathType Container){
            $name=if($item.ContainsKey('Name')){$item.Name}else{'未命名Profile'}
            [pscustomobject]@{Name=$name;Path=$path}
        }
    }
}
