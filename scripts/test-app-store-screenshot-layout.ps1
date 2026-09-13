param(
    [Parameter(Mandatory = $true)]
    [string]$ArtifactRoot
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$outputRoot = Join-Path ([System.IO.Path]::GetTempPath()) "detailhandoff-app-store-layout-test"
& (Join-Path $PSScriptRoot "render-app-store-screenshots.ps1") -ArtifactRoot $ArtifactRoot -Platform iPhone -OutputRoot $outputRoot | Out-Null

$imagePath = Join-Path $outputRoot "01-professional-record.png"
$image = [System.Drawing.Bitmap]::FromFile($imagePath)
$failures = [System.Collections.Generic.List[string]]::new()

$brandPixels = 0
for ($y = 90; $y -lt 230; $y += 2) {
    for ($x = 780; $x -lt 1210; $x += 2) {
        $pixel = $image.GetPixel($x, $y)
        if (($pixel.R + $pixel.G + $pixel.B) -gt 520) { $brandPixels++ }
    }
}
if ($brandPixels -gt 40) {
    $failures.Add("Unexpected upper-right brand label remains ($brandPixels bright samples).")
}

$cyanLeft = $image.Width
for ($y = 360; $y -lt 570; $y += 2) {
    for ($x = 40; $x -lt 1000; $x += 2) {
        $pixel = $image.GetPixel($x, $y)
        if ($pixel.R -lt 100 -and $pixel.G -gt 190 -and $pixel.B -gt 180) {
            $cyanLeft = [Math]::Min($cyanLeft, $x)
        }
    }
}
if ($cyanLeft -lt 300) {
    $failures.Add("Highlighted 'Every time.' starts too far left ($cyanLeft); it should follow 'record.' on the same line.")
}

function Find-WhiteTop([int]$X) {
    for ($y = 850; $y -lt 1350; $y++) {
        $pixel = $image.GetPixel($X, $y)
        if ($pixel.R -gt 238 -and $pixel.G -gt 238 -and $pixel.B -gt 238) { return $y }
    }
    return -1
}

$leftTop = Find-WhiteTop 280
$rightTop = Find-WhiteTop 1020
if ($leftTop -lt 0 -or $rightTop -lt 0 -or [Math]::Abs($leftTop - $rightTop) -lt 18) {
    $failures.Add("Primary report sheet is not visibly tilted (left=$leftTop, right=$rightTop).")
}

$rearSheetSamples = 0
for ($y = 1120; $y -lt 2400; $y += 3) {
    for ($x = 10; $x -lt 95; $x += 3) {
        $pixel = $image.GetPixel($x, $y)
        if (($pixel.R + $pixel.G + $pixel.B) -gt 330) { $rearSheetSamples++ }
    }
}
if ($rearSheetSamples -lt 350) {
    $failures.Add("Layered rear report sheets are missing ($rearSheetSamples light samples).")
}

$image.Dispose()

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ -ErrorAction Continue }
    exit 1
}

Write-Host "PASS: screenshot matches the selected tilted-report direction."
