$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$projectPath = Join-Path $repoRoot 'project.yml'
$workflowPath = Join-Path $repoRoot '.github/workflows/testflight-release.yml'

$project = Get-Content -LiteralPath $projectPath -Raw
if ($project -notmatch '(?m)^\s*MARKETING_VERSION:\s*"1\.0"\s*$') {
    throw 'project.yml must set MARKETING_VERSION to 1.0.'
}

if (-not (Test-Path -LiteralPath $workflowPath)) {
    throw 'The TestFlight release workflow is missing.'
}

$workflow = Get-Content -LiteralPath $workflowPath -Raw
$requiredFragments = @(
    'workflow_dispatch:',
    'APPLE_CERTIFICATE_BASE64',
    'APPLE_CERTIFICATE_PASSWORD',
    'APPLE_PROVISIONING_PROFILE_BASE64',
    'APP_STORE_CONNECT_API_KEY_BASE64',
    'APP_STORE_CONNECT_API_KEY_ID',
    'APP_STORE_CONNECT_API_ISSUER_ID',
    'xcodebuild archive',
    'xcodebuild -exportArchive',
    'xcrun altool --upload-app',
    'if: always()'
)

foreach ($fragment in $requiredFragments) {
    if (-not $workflow.Contains($fragment)) {
        throw "Release workflow is missing required fragment: $fragment"
    }
}

Write-Output 'TestFlight release configuration checks passed.'
