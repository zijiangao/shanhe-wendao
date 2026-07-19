param(
    [Parameter(Mandatory = $true)][ValidatePattern('^[1-9][0-9]*$')][string]$FullAppId,
    [Parameter(Mandatory = $true)][ValidatePattern('^[1-9][0-9]*$')][string]$FullDepotId,
    [Parameter(Mandatory = $true)][ValidatePattern('^[1-9][0-9]*$')][string]$DemoAppId,
    [Parameter(Mandatory = $true)][ValidatePattern('^[1-9][0-9]*$')][string]$DemoDepotId,
    [Parameter(Mandatory = $true)][ValidatePattern('^[0-9]+\.[0-9]+\.[0-9]+$')][string]$Version,
    [Parameter(Mandatory = $true)][ValidatePattern('^[A-Za-z0-9_-]+$')][string]$BetaBranch,
    [Parameter(Mandatory = $true)][ValidatePattern('^[A-Za-z0-9_-]+$')][string]$DemoBetaBranch,
    [string]$BuildRoot,
    [string]$OutputDirectory
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
if ([string]::IsNullOrWhiteSpace($BuildRoot)) {
    $BuildRoot = Join-Path $repositoryRoot 'build'
}
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $repositoryRoot 'steamworks\generated'
}
$BuildRoot = [IO.Path]::GetFullPath($BuildRoot)
$OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory)

$identifiers = @($FullAppId, $FullDepotId, $DemoAppId, $DemoDepotId)
if (($identifiers | Select-Object -Unique).Count -ne 4) {
    throw 'Full/Demo App IDs and Depot IDs must all be distinct.'
}
if ($BetaBranch -in @('default', 'public') -or $DemoBetaBranch -in @('default', 'public')) {
    throw 'Generate release candidates for private beta branches, not default/public.'
}

$requiredBuildFiles = @(
    (Join-Path $BuildRoot 'windows\ShanheWendao.exe'),
    (Join-Path $BuildRoot 'windows\ShanheWendao.pck'),
    (Join-Path $BuildRoot 'windows-demo\ShanheWendaoDemo.exe'),
    (Join-Path $BuildRoot 'windows-demo\ShanheWendaoDemo.pck')
)
foreach ($file in $requiredBuildFiles) {
    if (-not (Test-Path -LiteralPath $file -PathType Leaf)) {
        throw "Required SteamPipe build artifact is missing: $file"
    }
}

New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$buildOutput = Join-Path $repositoryRoot 'steamworks\output'
New-Item -ItemType Directory -Force -Path $buildOutput | Out-Null

function ConvertTo-VdfPath([string]$Path) {
    return ([IO.Path]::GetFullPath($Path) -replace '\\', '\\')
}

$replacements = @{
    '<APP_ID>' = $FullAppId
    '<WINDOWS_DEPOT_ID>' = $FullDepotId
    '<DEMO_APP_ID>' = $DemoAppId
    '<DEMO_WINDOWS_DEPOT_ID>' = $DemoDepotId
    '<VERSION>' = $Version
    '<PRIVATE_BETA_BRANCH>' = $BetaBranch
    '<PRIVATE_DEMO_BETA_BRANCH>' = $DemoBetaBranch
    '<CONTENT_ROOT>' = (ConvertTo-VdfPath $BuildRoot)
    '<FULL_CONTENT_ROOT>' = (ConvertTo-VdfPath (Join-Path $BuildRoot 'windows'))
    '<DEMO_CONTENT_ROOT>' = (ConvertTo-VdfPath (Join-Path $BuildRoot 'windows-demo'))
    '<BUILD_OUTPUT>' = (ConvertTo-VdfPath $buildOutput)
}

$templates = @(
    'app_build.vdf.example',
    'app_build_demo.vdf.example',
    'depot_build_windows.vdf.example',
    'depot_build_windows_demo.vdf.example'
)
foreach ($templateName in $templates) {
    $templatePath = Join-Path $PSScriptRoot $templateName
    $content = Get-Content -LiteralPath $templatePath -Raw -Encoding UTF8
    foreach ($placeholder in $replacements.Keys) {
        $content = $content.Replace($placeholder, [string]$replacements[$placeholder])
    }
    if ($content -match '<[A-Z0-9_]+>') {
        throw "Unresolved placeholder in $templateName"
    }
    $targetName = $templateName.Replace('.example', '')
    Set-Content -LiteralPath (Join-Path $OutputDirectory $targetName) -Value $content -Encoding UTF8
}

Write-Output "SteamPipe configuration prepared for $Version"
Write-Output "Full content: $(Join-Path $BuildRoot 'windows')"
Write-Output "Demo content: $(Join-Path $BuildRoot 'windows-demo')"
Write-Output "VDF output: $OutputDirectory"
