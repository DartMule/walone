import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:walone/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Нативный трей скрывает и возвращает окно без завершения Flutter',
    (tester) async {
      await tester.pumpWidget(const WaloneApp(keyboardOnly: true));
      await tester.pumpAndSettle();
      const desktop = MethodChannel('dev.soyjanks.walone/desktop');
      final initial = await desktop.invokeMapMethod<String, dynamic>(
        'initialize',
      );
      expect(
        initial!['login'],
        isIn(['disabled', 'enabled', 'requiresApproval', 'notFound']),
      );
      expect(initial['trayAvailable'], isTrue);
      await desktop.invokeMethod<void>('updateTray', {
        'paused': true,
        'running': false,
        'selectedID': 'test',
        'presets': [
          {'id': 'test', 'name': 'Тест & дождь'},
        ],
      });
      await desktop.invokeMethod<void>('updateTimerTray', {
        'title': 'Рабочая сессия · 00:24:54',
        'time': '00:24:54',
        'running': true,
      });
      final timerStatus = await desktop.invokeMapMethod<String, dynamic>(
        'status',
      );
      expect(timerStatus!['timerTitle'], 'Рабочая сессия · 00:24:54');
      if (Platform.isMacOS) expect(timerStatus['trayTimer'], ' 00:24:54');
      try {
        await desktop.invokeMethod<void>('hide');
        final hidden = await desktop.invokeMapMethod<String, dynamic>('status');
        expect(hidden!['windowVisible'], isFalse);
        expect(hidden['trayAvailable'], isTrue);
        expect(hidden['timerTitle'], 'Рабочая сессия · 00:24:54');
      } finally {
        await desktop.invokeMethod<void>('show');
      }
      final visible = await desktop.invokeMapMethod<String, dynamic>('status');
      expect(visible!['windowVisible'], isTrue);
      expect(visible['login'], initial['login']);
      await desktop.invokeMethod<void>('updateTimerTray', {
        'title': '',
        'time': '',
        'running': false,
      });
      final cleared = await desktop.invokeMapMethod<String, dynamic>('status');
      expect(cleared!['timerTitle'], isEmpty);
      if (Platform.isMacOS) expect(cleared['trayTimer'], isEmpty);
      await desktop.invokeMethod<void>('restoreTray');
      // Регистрацию в ОС не меняем: автоматическая проверка не включает автозапуск.
    },
  );
}
