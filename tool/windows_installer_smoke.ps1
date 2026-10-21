# Выполнять в чистом тестовом профиле: установка, повторная установка, удаление.
[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$Installer)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\dev.soyjanks.walone.flutter_is1'
if (Test-Path $key) { throw 'Walone is already installed in this profile; use a clean QA profile.' }
$Installer = (Resolve-Path -LiteralPath $Installer).Path
$target = Join-Path $env:TEMP ('WaloneInstallerSmoke-' + [guid]::NewGuid().ToString('N'))
$log = "$target.log"
try {
    for ($attempt = 0; $attempt -lt 2; $attempt++) {
        $setup = Start-Process -FilePath $Installer -ArgumentList @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', "/DIR=`"$target`"", "/LOG=`"$log`"") -PassThru -Wait
        if ($setup.ExitCode -ne 0) { throw "Install attempt $attempt failed: $($setup.ExitCode), log: $log" }
        foreach ($file in @('walone.exe', 'flutter_windows.dll', 'msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll', 'data\app.so', 'data\flutter_assets\assets\catalog.json', 'Legal\LICENSE.md', 'Legal\NOTICE.md')) {
            if (-not (Test-Path (Join-Path $target $file))) { throw "Missing installed file: $file" }
        }
        if ((Get-ItemPropertyValue $key -Name InstallLocation).TrimEnd('\') -ne $target) {
            throw 'Installer registered an unexpected location.'
        }
    }
} finally {
    $uninstaller = Join-Path $target 'unins000.exe'
    if (Test-Path $uninstaller) {
        $uninstall = Start-Process -FilePath $uninstaller -ArgumentList @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART') -PassThru -Wait
        if ($uninstall.ExitCode -ne 0) { throw "Uninstall failed: $($uninstall.ExitCode)" }
    }
}
if ((Test-Path $key) -or (Test-Path (Join-Path $target 'walone.exe'))) { throw 'Uninstall left the application or registry entry.' }
Write-Host 'Installer smoke passed: install, reinstall, CRT DLLs, registration, uninstall.'
