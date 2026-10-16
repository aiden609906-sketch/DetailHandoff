$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$plistPath = Join-Path $repoRoot 'DetailHandoff/Info.plist'
[xml]$plist = Get-Content -LiteralPath $plistPath -Raw
$dict = $plist.SelectSingleNode('/plist/dict')

function Get-ArrayValues([string]$key) {
    $array = $dict.SelectSingleNode("key[.='$key']/following-sibling::*[1]")
    if ($null -eq $array -or $array.Name -ne 'array') {
        throw "Missing array value for $key."
    }
    return @($array.SelectNodes('string') | ForEach-Object { $_.InnerText })
}

$phoneOrientations = Get-ArrayValues 'UISupportedInterfaceOrientations'
$expectedPhoneOrientations = @('UIInterfaceOrientationPortrait')
if (Compare-Object $expectedPhoneOrientations $phoneOrientations) {
    throw "Unexpected iPhone orientations: $($phoneOrientations -join ', ')"
}

$padOrientations = Get-ArrayValues 'UISupportedInterfaceOrientations~ipad'
$expectedPadOrientations = @(
    'UIInterfaceOrientationPortrait',
    'UIInterfaceOrientationPortraitUpsideDown',
    'UIInterfaceOrientationLandscapeLeft',
    'UIInterfaceOrientationLandscapeRight'
)
if (Compare-Object $expectedPadOrientations $padOrientations) {
    throw "Unexpected iPad orientations: $($padOrientations -join ', ')"
}

Write-Output 'Supported orientation configuration checks passed.'
