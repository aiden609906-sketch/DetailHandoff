param(
    [string]$MetadataPath = (Join-Path $PSScriptRoot "../docs/release/app-store-metadata.en-US.json")
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $MetadataPath)) {
    Write-Error "Metadata file is missing: $MetadataPath"
    exit 1
}

$metadata = Get-Content -Raw -LiteralPath $MetadataPath | ConvertFrom-Json
$failures = [System.Collections.Generic.List[string]]::new()

$limits = @{
    appName = 30
    subtitle = 30
    promotionalText = 170
    description = 4000
}

foreach ($field in $limits.Keys) {
    $value = [string]$metadata.$field
    if ([string]::IsNullOrWhiteSpace($value)) {
        $failures.Add("$field is required.")
    } elseif ($value.Length -gt $limits[$field]) {
        $failures.Add("$field is $($value.Length) characters; limit is $($limits[$field]).")
    }
}

$keywordBytes = [System.Text.Encoding]::UTF8.GetByteCount([string]$metadata.keywords)
if ($keywordBytes -gt 100) {
    $failures.Add("keywords use $keywordBytes UTF-8 bytes; limit is 100.")
}
foreach ($keyword in ([string]$metadata.keywords -split ',')) {
    if ($keyword.Trim().Length -lt 3) {
        $failures.Add("keyword '$keyword' is shorter than three characters.")
    }
}
if (([string]$metadata.keywords).ToLowerInvariant().Contains(([string]$metadata.appName).ToLowerInvariant())) {
    $failures.Add("keywords must not duplicate the app name.")
}

$publicCopy = "$($metadata.subtitle)`n$($metadata.promotionalText)`n$($metadata.description)"
foreach ($claim in @("legal protection", "prevent disputes", "AI damage", "cloud sync")) {
    if ($publicCopy.IndexOf($claim, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
        $failures.Add("Unsupported public claim found: $claim")
    }
}

if ([string]::IsNullOrWhiteSpace([string]$metadata.reviewNotes)) {
    $failures.Add("reviewNotes is required for the handoff.")
}
if ([string]::IsNullOrWhiteSpace([string]$metadata.whatsNew)) {
    $failures.Add("whatsNew is required for the release handoff.")
}

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ -ErrorAction Continue }
    exit 1
}

Write-Host "PASS: App Store metadata is complete and within Apple field limits."
Write-Host "Name: $($metadata.appName.Length)/30 characters"
Write-Host "Subtitle: $($metadata.subtitle.Length)/30 characters"
Write-Host "Promotional text: $($metadata.promotionalText.Length)/170 characters"
Write-Host "Description: $($metadata.description.Length)/4000 characters"
Write-Host "Keywords: $keywordBytes/100 UTF-8 bytes"
