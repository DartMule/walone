; ISCC вызывается через tool/windows_release.ps1, версия берётся из pubspec.yaml.
[Setup]
AppId=dev.soyjanks.walone.flutter
AppName=Walone
AppVersion={#AppVersion}
VersionInfoVersion={#NumericVersion}
AppPublisher=dev.soyjanks
AppPublisherURL=https://github.com/DartMule/walone
DefaultDirName={localappdata}\Programs\Walone
DefaultGroupName=Walone
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
OutputDir={#OutputDir}
OutputBaseFilename=walone-{#AppVersion}-windows-x64-setup
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\walone.exe
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
AppMutex=Local\WaloneFlutter.Singleton
CloseApplications=no
RestartApplications=no
SetupLogging=yes
#ifdef SignedRelease
SignTool=release
SignedUninstaller=yes
#endif

[Languages]
Name: "russian"; MessagesFile: "compiler:Languages\Russian.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Files]
Source: "{#ReleaseDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs; Excludes: "*.pdb,native_assets.json"

[Icons]
Name: "{group}\Walone"; Filename: "{app}\walone.exe"

[Run]
Filename: "{app}\walone.exe"; Description: "{cm:LaunchProgram,Walone}"; Flags: nowait postinstall skipifsilent

[Code]
procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  Startup: String;
begin
  if CurUninstallStep = usUninstall then
    if RegQueryStringValue(HKCU, 'Software\Microsoft\Windows\CurrentVersion\Run', 'WaloneFlutter', Startup) then
      if CompareText(Startup, '"' + ExpandConstant('{app}\walone.exe') + '" --autostart') = 0 then
        RegDeleteValue(HKCU, 'Software\Microsoft\Windows\CurrentVersion\Run', 'WaloneFlutter');
end;
