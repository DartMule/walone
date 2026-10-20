import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';
import 'package:g1455/glass_diagnostics.dart';
import 'package:walone/core/widgets.dart';
import 'package:walone/features/keyboard/data/keyboard_preview.dart';
import 'package:walone/features/timer/data/timer_sound.dart';
import 'package:walone/features/timer/presentation/timer_cubit.dart';

import 'keyboard_test.dart' show red;
import 'media_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Завершённый пример освобождается, следующий создаёт новый плеер',
    () async {
      final players = <FakeAudio>[];
      final preview = KeyboardPreview(
        factory: () {
          final audio = FakeAudio();
          players.add(audio);
          return audio;
        },
        interval: Duration.zero,
        tail: Duration.zero,
      );
      await preview.play(red, group: 0, volume: 0.5);
      expect(players.single.disposed, isTrue);
      await preview.play(red, group: 1, volume: 0.5);
      expect(players, hasLength(2));
      expect(players.last.loads.single, endsWith('/space.wav'));
      expect(players.every((audio) => audio.disposed), isTrue);
      await preview.dispose();
      await preview.dispose();
    },
  );

  test('Сигналы освобождаются по завершению, ошибке и закрытию', () async {
    final players = <FakeAudio>[];
    final sound = TimerSound(
      factory: () {
        final audio = FakeAudio();
        players.add(audio);
        return audio;
      },
    );
    await sound.play(PomodoroPhase.work);
    players.single.complete.add(null);
    await Future<void>.delayed(Duration.zero);
    expect(players.single.disposed, isTrue);
    await sound.play(PomodoroPhase.work);
    players.last.error.add('Ошибка');
    await Future<void>.delayed(Duration.zero);
    expect(players.last.disposed, isTrue);
    await sound.play(PomodoroPhase.work);
    await sound.dispose();
    expect(players.last.disposed, isTrue);
    await sound.play(PomodoroPhase.work);
    expect(players, hasLength(3));
  });

  testWidgets('Скрытие освобождает захват стекла и сохраняет диалог и ввод', (
    tester,
  ) async {
    const channel = MethodChannel('dev.soyjanks.walone/appearance');
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => {
        'reduceTransparency': false,
        'increaseContrast': false,
        'windowVisible': true,
      },
    );
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        builder: (_, child) => WaloneGlassHost(child: child!),
        home: const Scaffold(body: FrostedPanel(child: TextField())),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Поиск');
    FocusManager.instance.primaryFocus?.unfocus();
    unawaited(
      showDialog<void>(
        context: navigator.currentContext!,
        builder: (_) =>
            const AlertDialog(content: TextField(), title: Text('Черновик')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Не сохранено');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    final handle = GlassProxyScope.maybeOf(
      tester.element(find.byType(TextField).last),
    )!;
    Future<void> visibility(bool value) async {
      await messenger.handlePlatformMessage(
        channel.name,
        channel.codec.encodeMethodCall(MethodCall('visibility', value)),
        (_) {},
      );
      await tester.pumpAndSettle();
    }

    await visibility(false);
    expect(find.text('Черновик'), findsNothing);
    expect(find.text('Не сохранено', skipOffstage: false), findsOneWidget);
    expect(tester.widget<GlassHost>(find.byType(GlassHost)).maxCaptures, 0);
    expect(handle.frame, isNull);
    await visibility(true);
    expect(find.text('Черновик'), findsOneWidget);
    expect(find.text('Не сохранено'), findsOneWidget);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('Поиск'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
