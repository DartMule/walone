import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:walone/features/settings/data/windows_updates.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Windows передаёт настройки прозрачности и контраста в Flutter', (
    tester,
  ) async {
    const channel = MethodChannel('dev.soyjanks.walone/appearance');
    final settings = await channel.invokeMapMethod<String, dynamic>(
      'accessibility',
    );
    expect(settings!['reduceTransparency'], isA<bool>());
    expect(settings['increaseContrast'], isA<bool>());
    final system = Platform.environment['SystemRoot'] ?? r'C:\Windows';
    final result = await Process.run(
      '$system\\System32\\WindowsPowerShell\\v1.0\\powershell.exe',
      [
        '-NoProfile',
        '-NonInteractive',
        '-EncodedCommand',
        encodePowershell(r'''
$value = Get-ItemPropertyValue -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name EnableTransparency -ErrorAction SilentlyContinue
@{reduce=($null -ne $value -and $value -eq 0)} | ConvertTo-Json -Compress
'''),
      ],
    );
    expect(result.exitCode, 0);
    expect(
      settings['reduceTransparency'],
      (jsonDecode(result.stdout as String) as Map)['reduce'],
    );
  }, skip: !Platform.isWindows);
}
