[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$signingPropertiesPath = Join-Path $repositoryRoot 'android\beta-signing.properties'

if (-not (Test-Path -LiteralPath $signingPropertiesPath -PathType Leaf)) {
    throw 'Missing android\beta-signing.properties. Follow docs\beta-release.md before building a distributable APK.'
}

$signingProperties = @{}
foreach ($line in Get-Content -LiteralPath $signingPropertiesPath) {
    if ($line -match '^\s*([^#][^=]*)=(.*)$') {
        $signingProperties[$matches[1].Trim()] = $matches[2].Trim()
    }
}

foreach ($requiredProperty in @('storeFile', 'storePassword', 'keyAlias', 'keyPassword')) {
    if (-not $signingProperties.ContainsKey($requiredProperty) -or
        [string]::IsNullOrWhiteSpace($signingProperties[$requiredProperty]) -or
        $signingProperties[$requiredProperty] -like 'REPLACE_*') {
        throw "android\beta-signing.properties has no usable $requiredProperty value."
    }
}

function Test-HasOddBackslashRun {
    param([Parameter(Mandatory)][string]$Value)

    $backslashRun = 0
    foreach ($character in $Value.ToCharArray()) {
        if ($character -eq '\') {
            $backslashRun++
            continue
        }
        if ($backslashRun % 2 -ne 0) {
            return $true
        }
        $backslashRun = 0
    }
    return $backslashRun % 2 -ne 0
}

foreach ($passwordProperty in @('storePassword', 'keyPassword')) {
    if (Test-HasOddBackslashRun $signingProperties[$passwordProperty]) {
        throw "Escape every password backslash as two backslashes in android\beta-signing.properties ($passwordProperty)."
    }
}

$keystorePath = $signingProperties['storeFile']
if (-not [System.IO.Path]::IsPathRooted($keystorePath)) {
    $keystorePath = Join-Path (Join-Path $repositoryRoot 'android') $keystorePath
}
if (-not (Test-Path -LiteralPath $keystorePath -PathType Leaf)) {
    throw "The configured beta keystore does not exist: $keystorePath"
}

$versionMatch = Select-String -LiteralPath (Join-Path $repositoryRoot 'pubspec.yaml') -Pattern '^version:\s*([^+\s]+)\+(\d+)\s*$'
if (-not $versionMatch) {
    throw 'Could not read a version in the expected x.y.z+build form from pubspec.yaml.'
}

$versionName = $versionMatch.Matches[0].Groups[1].Value
$buildNumber = $versionMatch.Matches[0].Groups[2].Value
$artifactName = "healthpocket-beta-$versionName-build-$buildNumber.apk"
$flutterArtifact = Join-Path $repositoryRoot 'build\app\outputs\flutter-apk\app-dev-release.apk'
$releaseDirectory = Join-Path $repositoryRoot 'beta-site\releases'
$publishedArtifact = Join-Path $releaseDirectory $artifactName

Push-Location $repositoryRoot
try {
    flutter build apk --release --flavor dev --target lib/main_dev.dart
    if ($LASTEXITCODE -ne 0) {
        throw "Flutter beta build failed with exit code $LASTEXITCODE."
    }
} finally {
    Pop-Location
}

if (-not (Test-Path -LiteralPath $flutterArtifact -PathType Leaf)) {
    throw "Flutter reported success but the expected APK was not found: $flutterArtifact"
}

New-Item -ItemType Directory -Path $releaseDirectory -Force | Out-Null
Copy-Item -LiteralPath $flutterArtifact -Destination $publishedArtifact -Force
$hash = (Get-FileHash -LiteralPath $publishedArtifact -Algorithm SHA256).Hash.ToLowerInvariant()
$sizeMb = [math]::Round((Get-Item -LiteralPath $publishedArtifact).Length / 1MB, 1)

Write-Host "Beta APK ready: $publishedArtifact"
Write-Host "Size: $sizeMb MB"
Write-Host "SHA-256: $hash"
