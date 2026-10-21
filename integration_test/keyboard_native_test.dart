import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:integration_test/integration_test.dart';
import 'package:walone/features/keyboard/data/native_keyboard_repository.dart';
import 'package:walone/features/keyboard/domain/keyboard.dart';
import 'package:walone/main.dart';
import 'package:walone/features/keyboard/presentation/keyboard_cubit.dart';
import 'package:walone/features/keyboard/presentation/keyboard_page.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Нативный модуль загружает 20 наборов и воспроизводит их с нулевой громкостью',
    (tester) async {
      await tester.pumpWidget(const WaloneApp(keyboardOnly: true));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Проверить звучание'));
      await tester.pumpAndSettle();
      final typing = find.byKey(const ValueKey('keyboard-typing'));
      await tester.ensureVisible(typing);
      expect(find.byType(ErrorWidget), findsNothing);
      expect(tester.getSize(typing).height, lessThan(100));
      await tester.enterText(typing, 'Проверка печати');
      await tester.pump();
      expect(find.text('Проверка печати'), findsOneWidget);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      if (Platform.isMacOS) {
        const sensor = MethodChannel('dev.soyjanks.walone/keyboard');
        final experiment = await sensor.invokeMapMethod<String, dynamic>(
          'sensorStatus',
        );
        expect(experiment!['stage'], isIn([0, 1, 2]));
        expect(experiment['summary'], isA<String>());
        await expectLater(
          sensor.invokeMethod<void>('sensorConfigure', {
            'enabled': true,
            'sensitivity': -1.0,
            'stage': 0,
            'collecting': false,
          }),
          throwsA(isA<PlatformException>()),
        );
        final unchanged = await sensor.invokeMapMethod<String, dynamic>(
          'sensorStatus',
        );
        expect(unchanged!['sensitivity'], experiment['sensitivity']);
        expect(unchanged['enabled'], experiment['enabled']);
      }
      const repository = NativeKeyboardRepository();
      final packs = await repository.loadCatalog();
      expect(packs, hasLength(20));
      for (final pack in packs) {
        await repository.configure(pack, false, 0);
        await repository.preview();
        final status = await repository.status();
        expect(status.error, isNull, reason: pack.id);
        expect(status.enabled, isFalse);
      }
      const invalid = KeyboardPack(
        id: '../outside',
        title: '',
        detail: '',
        author: '',
        keyCount: 6,
      );
      await expectLater(
        repository.configure(invalid, false, 0),
        throwsA(isA<PlatformException>()),
      );
      await repository.configure(packs.first, false, 0);
      await repository.preview();
      final cubit = tester
          .element(find.byType(KeyboardPage))
          .read<KeyboardCubit>();
      await cubit.configure(volume: 0);
      for (final id in [
        'brown',
        'apex-pro-tkl-v2',
        'logitech-g915-tkl-brown',
      ]) {
        final pack = packs.singleWhere((pack) => pack.id == id);
        for (var group = 0; group < 4; group++) {
          await cubit.preview(pack: pack, group: group);
          expect(cubit.state.error, isNull, reason: '$id / $group');
        }
      }
      await cubit.preview(pack: packs.last);
      expect(cubit.state.selected!.id, packs.first.id);
      expect(cubit.state.history, isEmpty);
      expect(cubit.state.status.enabled, isFalse);
      expect(cubit.state.previewID, isNull);
      await repository.configure(packs.first, false, 0.35);
      expect((await repository.status()).error, isNull);
      // Разрешения ОС и реальная печать проверяются вручную; тест их не запрашивает.
      await repository.dispose();
      final stopped = await repository.status();
      expect(stopped.enabled, isFalse);
      expect(stopped.listening, isFalse);
    },
  );
}
