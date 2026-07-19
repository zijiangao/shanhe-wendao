$ErrorActionPreference = 'Stop'
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ("shanhe-steampipe-test-" + [Guid]::NewGuid().ToString('N'))
$buildRoot = Join-Path $testRoot 'build'
$outputRoot = Join-Path $testRoot 'generated'

try {
    foreach ($relativePath in @(
        'windows\ShanheWendao.exe',
        'windows\ShanheWendao.pck',
        'windows-demo\ShanheWendaoDemo.exe',
        'windows-demo\ShanheWendaoDemo.pck'
    )) {
        $path = Join-Path $buildRoot $relativePath
        New-Item -ItemType Directory -Force -Path (Split-Path $path) | Out-Null
        New-Item -ItemType File -Force -Path $path | Out-Null
    }

    & (Join-Path $PSScriptRoot 'prepare_steampipe.ps1') `
        -FullAppId 200001 -FullDepotId 200002 `
        -DemoAppId 200003 -DemoDepotId 200004 `
        -Version 9.8.7 -BetaBranch internal-qa -DemoBetaBranch demo-qa `
        -BuildRoot $buildRoot -OutputDirectory $outputRoot | Out-Null

    $generated = @(Get-ChildItem -LiteralPath $outputRoot -Filter '*.vdf' -File)
    if ($generated.Count -ne 4) {
        throw "Expected four generated VDF files, found $($generated.Count)."
    }
    $combined = ($generated | Get-Content -Raw -Encoding UTF8) -join "`n"
    if ($combined -match '<[A-Z0-9_]+>' -or $combined -notmatch '9\.8\.7' -or $combined -notmatch '200004') {
        throw 'Generated VDF content is incomplete or still contains placeholders.'
    }

    $duplicateRejected = $false
    try {
        & (Join-Path $PSScriptRoot 'prepare_steampipe.ps1') `
            -FullAppId 200001 -FullDepotId 200001 `
            -DemoAppId 200003 -DemoDepotId 200004 `
            -Version 9.8.7 -BetaBranch internal-qa -DemoBetaBranch demo-qa `
            -BuildRoot $buildRoot -OutputDirectory $outputRoot | Out-Null
    } catch {
        $duplicateRejected = $true
    }
    if (-not $duplicateRejected) {
        throw 'Duplicate Steam identifiers were not rejected.'
    }

    $publicRejected = $false
    try {
        & (Join-Path $PSScriptRoot 'prepare_steampipe.ps1') `
            -FullAppId 200001 -FullDepotId 200002 `
            -DemoAppId 200003 -DemoDepotId 200004 `
            -Version 9.8.7 -BetaBranch public -DemoBetaBranch demo-qa `
            -BuildRoot $buildRoot -OutputDirectory $outputRoot | Out-Null
    } catch {
        $publicRejected = $true
    }
    if (-not $publicRejected) {
        throw 'The public Steam branch was not rejected for a release candidate.'
    }

    Remove-Item -LiteralPath (Join-Path $buildRoot 'windows-demo\ShanheWendaoDemo.pck')
    $missingArtifactRejected = $false
    try {
        & (Join-Path $PSScriptRoot 'prepare_steampipe.ps1') `
            -FullAppId 200001 -FullDepotId 200002 `
            -DemoAppId 200003 -DemoDepotId 200004 `
            -Version 9.8.7 -BetaBranch internal-qa -DemoBetaBranch demo-qa `
            -BuildRoot $buildRoot -OutputDirectory $outputRoot | Out-Null
    } catch {
        $missingArtifactRejected = $true
    }
    if (-not $missingArtifactRejected) {
        throw 'A missing Demo PCK was not rejected.'
    }

    Write-Output 'SteamPipe preparation tests passed.'
} finally {
    if (Test-Path -LiteralPath $testRoot) {
        Remove-Item -LiteralPath $testRoot -Recurse -Force
    }
}
