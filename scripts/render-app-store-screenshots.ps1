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
    @{ File = "01-professional-record.png"; Line1 = "A professional record."; Line2 = "Every time."; Subtitle = "Document the work. Seal the report. Hand it off with confidence." },
    @{ File = "02-capture-every-angle.png"; Line1 = "Capture every angle."; Line2 = "Stay consistent."; Subtitle = "Use guided Before and After views for every vehicle." },
    @{ File = "03-record-findings.png"; Line1 = "Record what you see."; Line2 = "Right where it matters."; Subtitle = "Add findings, severity, notes, and supporting photos." },
    @{ File = "04-confirm-before-service.png"; Line1 = "Confirm before service."; Line2 = "Keep the context."; Subtitle = "Record the customer's acknowledgment with the job." },
    @{ File = "05-seal-and-revise.png"; Line1 = "Seal the report."; Line2 = "Keep every revision."; Subtitle = "Create shareable PDF versions without overwriting history." },
    @{ File = "06-private-by-design.png"; Line1 = "Your records."; Line2 = "Your control."; Subtitle = "No account, analytics, or developer cloud service." }
)

if ($Platform -eq "iPad") {
    $canvasWidth = 2048; $canvasHeight = 2732
    $sourceRoot = Join-Path $ArtifactRoot "TestAttachments-iPad"
    if (-not $OutputRoot) { $OutputRoot = Join-Path $PSScriptRoot "../docs/release/app-store-assets/ipad" }
    $sources = @("E76F557C-3405-480A-B46E-35C389314E4B.png", "49A80D53-28AF-49B4-9EFB-2D43B99B64C2.png", "93B69571-F135-4E4E-A3AF-197D2AD31100.png", "6CCF3566-CED0-4B15-8C87-E978CE399716.png", "CFE74894-DFDF-453E-9A33-5EE5ED15B196.png", "CD5EF74D-8DB3-41EE-A825-7D2165A87D3E.png")
    $layout = @{ Margin = 130; Icon = 190; IconY = 64; BrandY = 126; TitleY = 270; TitleSize = 118; RuleOffset = 50; SubtitleSize = 48; PanelX = 160; PanelY = 850; PanelWidth = 1728; PanelHeight = 2200; PanelInset = 34 }
} else {
    $canvasWidth = 1290; $canvasHeight = 2796
    $sourceRoot = Join-Path $ArtifactRoot "TestAttachments-iPhone"
    if (-not $OutputRoot) { $OutputRoot = Join-Path $PSScriptRoot "../docs/release/app-store-assets/iphone" }
    $sources = @("634B0F48-B1DA-41A7-A383-A3B79B495F86.png", "0C6E153A-9E54-418B-B582-B788695E3859.png", "EFA822E4-A3D7-414C-9300-FF27980CE8F7.png", "7E2841EC-4E8E-4779-A291-F44C7472E420.png", "1BAEC182-AD14-4A20-BBB3-153DF18B9617.png", "B2C8BE92-3DF9-4A20-BC35-A3DD2C830008.png")
    $layout = @{ Margin = 88; Icon = 176; IconY = 78; BrandY = 138; TitleY = 326; TitleSize = 104; RuleOffset = 44; SubtitleSize = 45; PanelX = 105; PanelY = 965; PanelWidth = 1080; PanelHeight = 2350; PanelInset = 28 }
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

    $brandFont = [System.Drawing.Font]::new("Segoe UI Semibold", 28, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
    $brandBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(176, 218, 235, 248))
    $brandFormat = [System.Drawing.StringFormat]::new()
    $brandFormat.Alignment = [System.Drawing.StringAlignment]::Far
    $graphics.DrawString("DETAILHANDOFF", $brandFont, $brandBrush, [System.Drawing.RectangleF]::new($canvasWidth - 700, $layout.BrandY, 570, 50), $brandFormat)
    $brandFormat.Dispose(); $brandBrush.Dispose(); $brandFont.Dispose()

    $white = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::White)
    $cyan = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(42, 238, 241))
    $muted = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(210, 224, 239, 249))
    $textWidth = $canvasWidth - (2 * $layout.Margin)
    $line1Height = Draw-FittedText -Graphics $graphics -Text $slide.Line1 -Brush $white -X $layout.Margin -Y $layout.TitleY -MaxWidth $textWidth -PreferredSize $layout.TitleSize
    $line2Height = Draw-FittedText -Graphics $graphics -Text $slide.Line2 -Brush $cyan -X $layout.Margin -Y ($layout.TitleY + 16 + $line1Height) -MaxWidth $textWidth -PreferredSize $layout.TitleSize

    $rule = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(42, 238, 241))
    $ruleY = $layout.TitleY + $layout.RuleOffset + $line1Height + $line2Height
    $graphics.FillRectangle($rule, $layout.Margin, $ruleY, 170, 6)
    $rule.Dispose()

    $subtitleFont = [System.Drawing.Font]::new("Segoe UI", $layout.SubtitleSize, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
    $subtitleFormat = [System.Drawing.StringFormat]::new()
    $subtitleFormat.Trimming = [System.Drawing.StringTrimming]::Word
    $graphics.DrawString($slide.Subtitle, $subtitleFont, $muted, [System.Drawing.RectangleF]::new($layout.Margin, $ruleY + 46, $textWidth, 130), $subtitleFormat)
    $subtitleFormat.Dispose(); $subtitleFont.Dispose()

    $panelX = [float]$layout.PanelX
    $panelY = [float]$layout.PanelY
    $panelWidth = [float]$layout.PanelWidth
    $panelHeight = [float]$layout.PanelHeight
    $shadowPath = New-RoundedPath -X ($panelX + 16) -Y ($panelY + 26) -Width $panelWidth -Height $panelHeight -Radius 66
    $shadowBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(90, 0, 3, 15))
    $graphics.FillPath($shadowBrush, $shadowPath)
    $shadowBrush.Dispose(); $shadowPath.Dispose()

    $panelPath = New-RoundedPath -X $panelX -Y $panelY -Width $panelWidth -Height $panelHeight -Radius 66
    $paper = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(250, 252, 255))
    $graphics.FillPath($paper, $panelPath)
    $paper.Dispose()

    $screen = [System.Drawing.Image]::FromFile($sourcePath)
    $innerX = $panelX + $layout.PanelInset
    $innerY = $panelY + $layout.PanelInset + 6
    $innerWidth = $panelWidth - (2 * $layout.PanelInset)
    $innerHeight = $innerWidth * $screen.Height / $screen.Width
    $screenPath = New-RoundedPath -X $innerX -Y $innerY -Width $innerWidth -Height $innerHeight -Radius 48
    $savedState = $graphics.Save()
    $graphics.SetClip($screenPath)
    $graphics.DrawImage($screen, $innerX, $innerY, $innerWidth, $innerHeight)
    $graphics.Restore($savedState)
    $screenPath.Dispose(); $screen.Dispose(); $panelPath.Dispose()

    $white.Dispose(); $cyan.Dispose(); $muted.Dispose()
    $graphics.Dispose()

    $outputPath = Join-Path $OutputRoot $slide.File
    $bitmap.Save($outputPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $bitmap.Dispose()
    Write-Host "Rendered $outputPath"
}
