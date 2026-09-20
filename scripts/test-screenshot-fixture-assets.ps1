$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$repositoryRoot = Split-Path $PSScriptRoot -Parent
$catalog = Join-Path $repositoryRoot 'DetailHandoff/Resources/ScreenshotFixtures.xcassets'
$fixtureSource = Get-Content (Join-Path $repositoryRoot 'DetailHandoff/Testing/UITestFixtures.swift') -Raw
$projectSource = Get-Content (Join-Path $repositoryRoot 'project.yml') -Raw

if ($fixtureSource -match 'Fixture evidence|FIX-017|Generated only for DEBUG UI verification') {
    throw 'Screenshot fixture still contains visible placeholder copy.'
}
if ($projectSource -notmatch '(?m)^\s+EXCLUDED_SOURCE_FILE_NAMES:\s*ScreenshotFixtures\.xcassets\s*$') {
    throw 'Release builds must exclude the screenshot-only photo catalog.'
}

$imageNames = @(
    'ScreenshotFront',
    'ScreenshotRear',
    'ScreenshotSide',
    'ScreenshotPassengerSide',
    'ScreenshotWheel',
    'ScreenshotInterior',
    'ScreenshotRearSeats',
    'ScreenshotCargo'
)

foreach ($name in $imageNames) {
    $imageSet = Join-Path $catalog "$name.imageset"
    $manifestPath = Join-Path $imageSet 'Contents.json'
    if (-not (Test-Path -LiteralPath $manifestPath)) {
        throw "Missing image-set manifest: $manifestPath"
    }
    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    $filename = $manifest.images[0].filename
    if (-not $filename) {
        throw "Image-set manifest has no image filename: $manifestPath"
    }
    $imagePath = Join-Path $imageSet $filename
    if (-not (Test-Path -LiteralPath $imagePath)) {
        throw "Image-set file is missing: $imagePath"
    }

    $bitmap = [System.Drawing.Bitmap]::FromFile($imagePath)
    try {
        if ($bitmap.Width -lt 640 -or $bitmap.Height -lt 480) {
            throw "$name is too small for a screenshot fixture: $($bitmap.Width)x$($bitmap.Height)"
        }
        $colors = [System.Collections.Generic.HashSet[int]]::new()
        for ($y = 0; $y -lt $bitmap.Height; $y += 32) {
            for ($x = 0; $x -lt $bitmap.Width; $x += 32) {
                [void]$colors.Add($bitmap.GetPixel($x, $y).ToArgb())
            }
        }
        if ($colors.Count -lt 100) {
            throw "$name appears to be a flat-color placeholder ($($colors.Count) sampled colors)."
        }
    } finally {
        $bitmap.Dispose()
    }
}

Write-Host "PASS: $($imageNames.Count) photographic screenshot fixtures are present and non-flat."
