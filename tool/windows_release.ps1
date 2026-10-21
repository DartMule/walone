# Сборка и упаковка без публикации. Подпись использует сертификат Windows Store.
[CmdletBinding()]
param(
    [string]$Flutter = 'flutter',
    [switch]$SkipBuild,
    [switch]$Unsigned,
    [string]$CertificateThumbprint = $env:WALONE_WINDOWS_CERTIFICATE,
    [string]$TimestampUrl = 'http://timestamp.digicert.com',
    [string]$Iscc = "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
    [string]$SignTool = 'signtool.exe',
    [string]$CrtDirectory
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$project = Split-Path $PSScriptRoot -Parent
Push-Location $project
try {
    if ((Get-Content pubspec.yaml -Raw) -notmatch '(?m)^version: (\d+\.\d+\.\d+)\+(\d+)\s*$') {
        throw 'Expected version: major.minor.patch+build in pubspec.yaml'
    }
    $version = "$($Matches[1])+$($Matches[2])"
    $numericVersion = "$($Matches[1]).$($Matches[2])"
    if (-not $Unsigned -and $CertificateThumbprint -notmatch '^[a-fA-F0-9]{40}$') {
        throw 'Set WALONE_WINDOWS_CERTIFICATE to a trusted code-signing certificate thumbprint, or use -Unsigned for QA.'
    }
    if (-not (Test-Path -LiteralPath $Iscc)) { throw 'Install Inno Setup 6 or pass -Iscc.' }
    if (-not $SkipBuild) {
        & $Flutter build windows --release --no-pub
        if ($LASTEXITCODE -ne 0) { throw "Flutter build failed: $LASTEXITCODE" }
    }
    $release = Join-Path $project 'build\windows\x64\runner\Release'
    if (-not (Test-Path "$release\walone.exe")) { throw 'Windows x64 Release build is missing.' }
    $exeVersion = (Get-Item "$release\walone.exe").VersionInfo
    $actual = "$($exeVersion.FileMajorPart).$($exeVersion.FileMinorPart).$($exeVersion.FileBuildPart).$($exeVersion.FilePrivatePart)"
    if ($actual -ne $numericVersion) { throw "Stale build: $actual, expected $numericVersion" }
    $output = Join-Path $project 'dist\windows'
    New-Item -ItemType Directory -Force $output | Out-Null
    # Упаковываем отдельную копию: QA и подписанная сборка не меняют build/.
    $stage = Join-Path $project 'build\windows-package'
    if (Test-Path $stage) { Remove-Item -Recurse -Force $stage }
    New-Item -ItemType Directory -Force $stage | Out-Null
    Copy-Item "$release\*" $stage -Recurse
    if (-not $CrtDirectory) {
        $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
        $visualStudio = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
        $redist = Get-ChildItem (Join-Path $visualStudio 'VC\Redist\MSVC') -Directory |
            Where-Object { Test-Path (Join-Path $_.FullName 'x64\Microsoft.VC143.CRT') } |
            Sort-Object { [version]$_.Name } -Descending | Select-Object -First 1
        if (-not $redist) { throw 'Visual C++ redistributable DLLs missing; pass -CrtDirectory.' }
        $CrtDirectory = Join-Path $redist.FullName 'x64\Microsoft.VC143.CRT'
    }
    foreach ($dll in @('msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll')) {
        if (-not (Test-Path (Join-Path $CrtDirectory $dll))) { throw "Missing $dll in CRT directory" }
    }
    Copy-Item (Join-Path $CrtDirectory '*.dll') $stage
    $arguments = @("/DAppVersion=$version", "/DNumericVersion=$numericVersion", "/DReleaseDir=$stage", "/DOutputDir=$output")
    if (-not $Unsigned) {
        $tool = (Get-Command $SignTool -ErrorAction Stop).Source
        $app = Join-Path $stage 'walone.exe'
        & $tool sign /sha1 $CertificateThumbprint /fd SHA256 /tr $TimestampUrl /td SHA256 $app
        if ($LASTEXITCODE -ne 0) { throw 'Failed to sign Walone.' }
        # Inno подписывает установщик и uninstaller тем же сертификатом.
        $signCommand = '$q' + $tool + '$q sign /sha1 ' + $CertificateThumbprint + ' /fd SHA256 /tr ' + $TimestampUrl + ' /td SHA256 $f'
        $arguments += @('/DSignedRelease', "/Srelease=$signCommand")
    }
    & $Iscc @arguments 'windows\installer\walone.iss'
    if ($LASTEXITCODE -ne 0) { throw 'Inno Setup compilation failed.' }
    $installer = Join-Path $output "walone-$version-windows-x64-setup.exe"
    if (-not $Unsigned) {
        foreach ($file in @((Join-Path $stage 'walone.exe'), $installer)) {
            $signature = Get-AuthenticodeSignature -LiteralPath $file
            if ($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Thumbprint -ne $CertificateThumbprint) {
                throw "Signature verification failed: $file"
            }
        }
    }
    $digest = (Get-FileHash $installer -Algorithm SHA256).Hash.ToLowerInvariant()
    "$digest  $(Split-Path $installer -Leaf)" | Set-Content "$installer.sha256" -Encoding ascii
    Write-Host "Installer: $installer"
    Write-Host "SHA-256: $digest"
    if ($Unsigned) { Write-Warning 'Unsigned QA installer. Automatic updates are disabled. Do not publish as a stable release.' }
} finally {
    Pop-Location
}
