param(
    [Parameter(Mandatory = $true)]
    [string]$ArtifactRoot,

    [ValidateSet("iPhone", "iPad")]
    [string]$Platform = "iPhone",

    [string]$OutputRoot
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$iconPath = Join-Path $PSScriptRoot "../DetailHandoff/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"

$copy = @(
    @{ File = "01-professional-record.png"; Line1 = "A professional"; Line2Prefix = "record. "; Line2Accent = "Every time."; Subtitle = "Document the work. Seal the report. Hand it off with confidence." },
    @{ File = "02-capture-every-angle.png"; Line1 = "Capture every angle."; Line2Prefix = ""; Line2Accent = "Stay consistent."; Subtitle = "Use guided Before and After views for every vehicle." },
    @{ File = "03-record-findings.png"; Line1 = "Record what you see."; Line2Prefix = ""; Line2Accent = "Right where it matters."; Subtitle = "Add findings, severity, notes, and supporting photos." },
    @{ File = "04-confirm-before-service.png"; Line1 = "Confirm before service."; Line2Prefix = ""; Line2Accent = "Keep the context."; Subtitle = "Record the customer's acknowledgment with the job." },
    @{ File = "05-seal-and-revise.png"; Line1 = "Seal the report."; Line2Prefix = ""; Line2Accent = "Keep every revision."; Subtitle = "Create shareable PDF versions without overwriting history." },
    @{ File = "06-private-by-design.png"; Line1 = "Your records."; Line2Prefix = ""; Line2Accent = "Your control."; Subtitle = "No account, analytics, or developer cloud service." }
)

if ($Platform -eq "iPad") {
    $canvasWidth = 2048; $canvasHeight = 2732
    $sourceRoot = Join-Path $ArtifactRoot "TestAttachments-iPad"
    if (-not $OutputRoot) { $OutputRoot = Join-Path $PSScriptRoot "../docs/release/app-store-assets/ipad" }
    $sources = @("E76F557C-3405-480A-B46E-35C389314E4B.png", "49A80D53-28AF-49B4-9EFB-2D43B99B64C2.png", "93B69571-F135-4E4E-A3AF-197D2AD31100.png", "6CCF3566-CED0-4B15-8C87-E978CE399716.png", "CFE74894-DFDF-453E-9A33-5EE5ED15B196.png", "CD5EF74D-8DB3-41EE-A825-7D2165A87D3E.png")
    $layout = @{ Margin = 130; Icon = 190; IconY = 64; TitleY = 270; TitleSize = 118; RuleOffset = 50; SubtitleSize = 48; PanelX = 180; PanelY = 900; PanelWidth = 1728; PanelHeight = 2200; PanelInset = 34; PanelAngle = -1.5 }
} else {
    $canvasWidth = 1290; $canvasHeight = 2796
    $sourceRoot = Join-Path $ArtifactRoot "TestAttachments-iPhone"
    if (-not $OutputRoot) { $OutputRoot = Join-Path $PSScriptRoot "../docs/release/app-store-assets/iphone" }
    $sources = @("634B0F48-B1DA-41A7-A383-A3B79B495F86.png", "0C6E153A-9E54-418B-B582-B788695E3859.png", "EFA822E4-A3D7-414C-9300-FF27980CE8F7.png", "7E2841EC-4E8E-4779-A291-F44C7472E420.png", "1BAEC182-AD14-4A20-BBB3-153DF18B9617.png", "B2C8BE92-3DF9-4A20-BC35-A3DD2C830008.png")
    $layout = @{ Margin = 82; Icon = 176; IconY = 78; TitleY = 315; TitleSize = 104; RuleOffset = 44; SubtitleSize = 45; PanelX = 145; PanelY = 1100; PanelWidth = 1080; PanelHeight = 2350; PanelInset = 28; PanelAngle = -2.3 }
}

$slides = for ($index = 0; $index -lt $copy.Count; $index++) {
    $item = $copy[$index].Clone()
    $item.Source = $sources[$index]
    $item
}

function New-RoundedPath {
    param([float]$X, [float]$Y, [float]$Width, [float]$Height, [float]$Radius)
    $path = [System.Drawing.Drawing2D.GraphicsPath]::new()
    $diameter = $Radius * 2
    $path.AddArc($X, $Y, $diameter, $diameter, 180, 90)
    $path.AddArc($X + $Width - $diameter, $Y, $diameter, $diameter, 270, 90)
    $path.AddArc($X + $Width - $diameter, $Y + $Height - $diameter, $diameter, $diameter, 0, 90)
    $path.AddArc($X, $Y + $Height - $diameter, $diameter, $diameter, 90, 90)
    $path.CloseFigure()
    return $path
}

function Draw-FittedText {
    param(
        [System.Drawing.Graphics]$Graphics,
        [string]$Text,
        [System.Drawing.Brush]$Brush,
        [float]$X,
        [float]$Y,
        [float]$MaxWidth,
        [float]$PreferredSize,
        [float]$MinimumSize = 62
    )
    $size = $PreferredSize
    do {
        $font = [System.Drawing.Font]::new("Segoe UI Semibold", $size, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
        $measured = $Graphics.MeasureString($Text, $font)
        if ($measured.Width -le $MaxWidth -or $size -le $MinimumSize) { break }
        $font.Dispose()
        $size -= 2
    } while ($true)
    $Graphics.DrawString($Text, $font, $Brush, $X, $Y)
    $height = $font.GetHeight($Graphics)
    $font.Dispose()
    return $height
}

function Draw-FittedSegmentedText {
    param(
        [System.Drawing.Graphics]$Graphics,
        [string]$Prefix,
        [string]$Accent,
        [System.Drawing.Brush]$PrefixBrush,
        [System.Drawing.Brush]$AccentBrush,
        [float]$X,
        [float]$Y,
        [float]$MaxWidth,
        [float]$PreferredSize,
        [float]$MinimumSize = 62
    )
    $size = $PreferredSize
    do {
        $font = [System.Drawing.Font]::new("Segoe UI Semibold", $size, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
        $prefixWidth = if ($Prefix) { $Graphics.MeasureString($Prefix, $font, [System.Drawing.PointF]::new(0, 0), [System.Drawing.StringFormat]::GenericTypographic).Width } else { 0 }
        $accentWidth = $Graphics.MeasureString($Accent, $font, [System.Drawing.PointF]::new(0, 0), [System.Drawing.StringFormat]::GenericTypographic).Width
        if (($prefixWidth + $accentWidth) -le $MaxWidth -or $size -le $MinimumSize) { break }
        $font.Dispose()
        $size -= 2
    } while ($true)
    if ($Prefix) { $Graphics.DrawString($Prefix, $font, $PrefixBrush, $X, $Y, [System.Drawing.StringFormat]::GenericTypographic) }
    $Graphics.DrawString($Accent, $font, $AccentBrush, $X + $prefixWidth, $Y, [System.Drawing.StringFormat]::GenericTypographic)
    $height = $font.GetHeight($Graphics)
    $font.Dispose()
    return $height
}

function Draw-RotatedSheet {
    param(
        [System.Drawing.Graphics]$Graphics,
        [System.Drawing.Image]$Screen,
        [float]$X,
        [float]$Y,
        [float]$Width,
        [float]$Height,
        [float]$Inset,
        [float]$Angle,
        [bool]$IsPrimary
    )
    $state = $Graphics.Save()
    $centerX = $X + ($Width / 2)
    $centerY = $Y + ($Height / 2)
    $Graphics.TranslateTransform($centerX, $centerY)
    $Graphics.RotateTransform($Angle)
    $Graphics.TranslateTransform(-$centerX, -$centerY)

    $shadowPath = New-RoundedPath -X ($X + 16) -Y ($Y + 28) -Width $Width -Height $Height -Radius 62
    $shadowBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb($(if ($IsPrimary) { 92 } else { 45 }), 0, 3, 15))
    $Graphics.FillPath($shadowBrush, $shadowPath)
    $shadowBrush.Dispose(); $shadowPath.Dispose()

    $sheetPath = New-RoundedPath -X $X -Y $Y -Width $Width -Height $Height -Radius 62
    $sheetColor = if ($IsPrimary) { [System.Drawing.Color]::FromArgb(250, 252, 255) } else { [System.Drawing.Color]::FromArgb(155, 177, 199) }
    $sheetBrush = [System.Drawing.SolidBrush]::new($sheetColor)
    $Graphics.FillPath($sheetBrush, $sheetPath)
    $sheetBrush.Dispose()

    $innerX = $X + $Inset
    $innerY = $Y + $Inset + 6
    $innerWidth = $Width - (2 * $Inset)
    $innerHeight = $innerWidth * $Screen.Height / $Screen.Width
    $screenPath = New-RoundedPath -X $innerX -Y $innerY -Width $innerWidth -Height $innerHeight -Radius 44
    $clipState = $Graphics.Save()
    $Graphics.SetClip($screenPath)
    $Graphics.DrawImage($Screen, $innerX, $innerY, $innerWidth, $innerHeight)
    if (-not $IsPrimary) {
        $veil = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(190, 103, 127, 151))
        $Graphics.FillRectangle($veil, $innerX, $innerY, $innerWidth, $innerHeight)
        $veil.Dispose()
    }
    $Graphics.Restore($clipState)
    $screenPath.Dispose()

    if ($IsPrimary) {
        $foldSize = [Math]::Min(150, $Width * 0.15)
        $fold = [System.Drawing.Drawing2D.GraphicsPath]::new()
        $fold.StartFigure()
        $fold.AddLine($X + $Width - $foldSize, $Y, $X + $Width, $Y + $foldSize)
        $fold.AddBezier($X + $Width, $Y + $foldSize, $X + $Width - 35, $Y + $foldSize + 8, $X + $Width - $foldSize - 8, $Y + 42, $X + $Width - $foldSize, $Y)
        $fold.CloseFigure()
        $foldBrush = [System.Drawing.Drawing2D.LinearGradientBrush]::new(
            [System.Drawing.RectangleF]::new($X + $Width - $foldSize, $Y, $foldSize, $foldSize),
            [System.Drawing.Color]::White,
            [System.Drawing.Color]::FromArgb(183, 193, 205),
            48.0
        )
        $Graphics.FillPath($foldBrush, $fold)
        $foldPen = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(150, 160, 173), 2)
        $Graphics.DrawPath($foldPen, $fold)
        $foldPen.Dispose(); $foldBrush.Dispose(); $fold.Dispose()
    }

    $sheetPath.Dispose()
    $Graphics.Restore($state)
}

if (-not (Test-Path -LiteralPath $iconPath)) {
    throw "App icon not found: $iconPath"
}
New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null

foreach ($slide in $slides) {
    $sourcePath = Join-Path $sourceRoot $slide.Source
    if (-not (Test-Path -LiteralPath $sourcePath)) {
        throw "Screenshot not found: $sourcePath"
    }

    $bitmap = [System.Drawing.Bitmap]::new($canvasWidth, $canvasHeight, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit

    $background = [System.Drawing.Drawing2D.LinearGradientBrush]::new(
        [System.Drawing.Rectangle]::new(0, 0, $canvasWidth, $canvasHeight),
        [System.Drawing.Color]::FromArgb(2, 55, 101),
        [System.Drawing.Color]::FromArgb(0, 17, 43),
        135.0
    )
    $graphics.FillRectangle($background, 0, 0, $canvasWidth, $canvasHeight)
    $background.Dispose()

    $glowPath = [System.Drawing.Drawing2D.GraphicsPath]::new()
    $glowPath.AddEllipse(310, 70, 900, 1000)
    $glow = [System.Drawing.Drawing2D.PathGradientBrush]::new($glowPath)
    $glow.CenterColor = [System.Drawing.Color]::FromArgb(70, 0, 119, 214)
    $glow.SurroundColors = @([System.Drawing.Color]::FromArgb(0, 0, 20, 50))
    $graphics.FillPath($glow, $glowPath)
    $glow.Dispose()
    $glowPath.Dispose()

    $icon = [System.Drawing.Image]::FromFile($iconPath)
    $graphics.DrawImage($icon, $layout.Margin, $layout.IconY, $layout.Icon, $layout.Icon)
    $icon.Dispose()

    $white = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::White)
    $cyan = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(42, 238, 241))
    $muted = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(210, 224, 239, 249))
    $textWidth = $canvasWidth - (2 * $layout.Margin)
    $line1Height = Draw-FittedText -Graphics $graphics -Text $slide.Line1 -Brush $white -X $layout.Margin -Y $layout.TitleY -MaxWidth $textWidth -PreferredSize $layout.TitleSize
    $line2Height = Draw-FittedSegmentedText -Graphics $graphics -Prefix $slide.Line2Prefix -Accent $slide.Line2Accent -PrefixBrush $white -AccentBrush $cyan -X $layout.Margin -Y ($layout.TitleY + 16 + $line1Height) -MaxWidth $textWidth -PreferredSize $layout.TitleSize

    $rule = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(42, 238, 241))
    $ruleY = $layout.TitleY + $layout.RuleOffset + $line1Height + $line2Height
    $graphics.FillRectangle($rule, $layout.Margin, $ruleY, 170, 6)
    $rule.Dispose()

    $subtitleFont = [System.Drawing.Font]::new("Segoe UI", $layout.SubtitleSize, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
    $subtitleFormat = [System.Drawing.StringFormat]::new()
    $subtitleFormat.Trimming = [System.Drawing.StringTrimming]::Word
    $graphics.DrawString($slide.Subtitle, $subtitleFont, $muted, [System.Drawing.RectangleF]::new($layout.Margin, $ruleY + 46, $textWidth, 130), $subtitleFormat)
    $subtitleFormat.Dispose(); $subtitleFont.Dispose()

    $screen = [System.Drawing.Image]::FromFile($sourcePath)
    $panelX = [float]$layout.PanelX
    $panelY = [float]$layout.PanelY
    $panelWidth = [float]$layout.PanelWidth
    $panelHeight = [float]$layout.PanelHeight
    Draw-RotatedSheet -Graphics $graphics -Screen $screen -X ($panelX - ($panelWidth * 0.13)) -Y ($panelY + 105) -Width ($panelWidth * 0.96) -Height $panelHeight -Inset $layout.PanelInset -Angle ($layout.PanelAngle - 4.2) -IsPrimary $false
    Draw-RotatedSheet -Graphics $graphics -Screen $screen -X ($panelX - ($panelWidth * 0.06)) -Y ($panelY + 58) -Width ($panelWidth * 0.98) -Height $panelHeight -Inset $layout.PanelInset -Angle ($layout.PanelAngle - 2.1) -IsPrimary $false
    Draw-RotatedSheet -Graphics $graphics -Screen $screen -X $panelX -Y $panelY -Width $panelWidth -Height $panelHeight -Inset $layout.PanelInset -Angle $layout.PanelAngle -IsPrimary $true
    $screen.Dispose()

    $white.Dispose(); $cyan.Dispose(); $muted.Dispose()
    $graphics.Dispose()

    $outputPath = Join-Path $OutputRoot $slide.File
    $bitmap.Save($outputPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $bitmap.Dispose()
    Write-Host "Rendered $outputPath"
}
