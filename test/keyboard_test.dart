import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walone/features/keyboard/data/native_keyboard_repository.dart';
import 'package:walone/features/keyboard/domain/keyboard.dart';
import 'package:walone/features/keyboard/presentation/keyboard_cubit.dart';
import 'package:walone/main.dart';
import 'package:walone/features/keyboard/data/keyboard_preview.dart';

import 'media_fakes.dart' show FakeAudio;

const brown = KeyboardPack(
  id: 'brown',
  title: 'Cherry MX Brown',
  detail: 'Тактильный',
  author: 'Mechvibes',
  keyCount: 6,
);
const red = KeyboardPack(
  id: 'red',
  title: 'Cherry MX Red',
  detail: 'Линейный',
  author: 'Mechvibes',
  keyCount: 6,
);

class FakeKeyboardRepository implements KeyboardRepository {
  bool enabled = false;
  bool fail = false;
  bool disposed = false;
  int previews = 0;
  int receivedKeys = 0;
  KeyboardPack selected = brown;
  double volume = 0.35;

  @override
  Future<List<KeyboardPack>> loadCatalog() async => [brown, red];

  @override
  Future<KeyboardStatus> initialize() => status();

  @override
  Future<KeyboardStatus> status() async => KeyboardStatus(
    hasPermission: false,
    listening: true,
    enabled: enabled,
    receivedKeys: receivedKeys,
  );

  @override
  Future<void> configure(KeyboardPack pack, bool enabled, double volume) async {
    if (fail) {
      throw PlatformException(code: 'audio', message: 'Не удалось открыть WAV');
    }
    selected = pack;
    this.enabled = enabled;
    this.volume = volume;
  }

  @override
  Future<void> preview() async {
    previews++;
  }

  @override
  Future<void> requestPermission() async {}

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Неизменный статус не обновляет интерфейс, новые нажатия обновляют',
    () async {
      final repository = FakeKeyboardRepository();
      final cubit = KeyboardCubit(repository);
      await cubit.initialize();
      final updates = <KeyboardState>[];
      final subscription = cubit.stream.listen(updates.add);
      for (var i = 0; i < 5; i++) {
        await cubit.refresh();
      }
      await Future<void>.delayed(Duration.zero);
      expect(updates, isEmpty);
      repository.receivedKeys = 1;
      await cubit.refresh();
      await Future<void>.delayed(Duration.zero);
      expect(updates.single.status.receivedKeys, 1);
      await subscription.cancel();
      await cubit.close();
    },
  );

  test(
    'Ошибка загрузки набора сохраняет предыдущий выбор и громкость',
    () async {
      final repository = FakeKeyboardRepository();
      final cubit = KeyboardCubit(repository);
      await cubit.initialize();
      await cubit.configure(enabled: true, volume: 0.6);
      expect(cubit.state.status.enabled, isTrue);
      repository.fail = true;
      await cubit.configure(pack: red, volume: 0.9);
      expect(cubit.state.selected?.id, 'brown');
      expect(cubit.state.volume, 0.6);
      expect(cubit.state.error, contains('Не удалось открыть WAV'));
      expect(cubit.state.busy, isFalse);
      repository.fail = false;
      await cubit.configure(pack: red);
      expect(cubit.state.selected?.id, 'red');
      expect(cubit.state.error, isNull);
      await cubit.close();
      expect(repository.disposed, isTrue);
    },
  );

  test('Нативная остановка при сне отражается в состоянии Flutter', () async {
    final repository = FakeKeyboardRepository();
    final cubit = KeyboardCubit(repository);
    await cubit.initialize();
    await cubit.configure(enabled: true);
    repository.enabled = false;
    repository.receivedKeys = 12;
    await cubit.refresh();
    expect(cubit.state.status.enabled, isFalse);
    expect(cubit.state.status.receivedKeys, 12);
    await cubit.close();
  });

  test(
    'Каталог содержит 20 наборов; все 172 WAV и лицензии упакованы',
    () async {
      const repository = NativeKeyboardRepository();
      final packs = await repository.loadCatalog();
      expect(packs, hasLength(20));
      expect(packs.map((p) => p.id).toSet(), hasLength(20));
      var clips = 0;
      for (final pack in packs) {
        final names = [
          for (var i = 0; i < pack.keyCount; i++) 'key$i',
          'space',
          'enter',
          'backspace',
        ];
        for (final name in names) {
          final data = await rootBundle.load(
            'assets/keyboards/${pack.id}/$name.wav',
          );
          expect(data.lengthInBytes, greaterThan(44));
          clips++;
        }
      }
      expect(clips, 172);
      for (final license in [
        'SOURCES.md',
        'Mechvibes-LICENSE.txt',
        'KeyboardSounds-LICENSE.txt',
        'Bucklespring-LICENSE.txt',
        'CC0-1.0.txt',
        'CC-BY-3.0.txt',
        'CC-BY-4.0.txt',
        'extra-keyboards.json',
      ]) {
        expect(
          await rootBundle.loadString('assets/licenses/$license'),
          isNotEmpty,
        );
      }
    },
  );

  test(
    'Мост передаёт только настройки и читает состояние разрешений',
    () async {
      const channel = MethodChannel('walone.test/keyboard');
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            if (call.method == 'status' || call.method == 'initialize') {
              return {
                'hasPermission': false,
                'listening': false,
                'secureInput': true,
                'enabled': false,
                'receivedKeys': 7,
                'error': null,
              };
            }
            return null;
          });
      const repository = NativeKeyboardRepository(channel: channel);
      await repository.configure(red, true, 0.4);
      expect(calls.single.arguments, {
        'pack': 'red',
        'keyCount': 6,
        'enabled': true,
        'volume': 0.4,
      });
      final status = await repository.status();
      expect(status.secureInput, isTrue);
      expect(status.hasPermission, isFalse);
      expect(status.receivedKeys, 7);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    },
  );

  testWidgets(
    'Поиск, выбор, прослушивание и выключатель на узком desktop-окне',
    (tester) async {
      Future<void> settle() async {
        await tester.pumpAndSettle();
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pumpAndSettle();
      }

      tester.view.physicalSize = const Size(560, 680);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = FakeKeyboardRepository();
      var audio = FakeAudio();
      final players = <FakeAudio>[audio];
      await tester.pumpWidget(
        WaloneApp(
          repository: repository,
          keyboardOnly: true,
          preview: KeyboardPreview(
            factory: () {
              if (audio.disposed) {
                audio = FakeAudio();
                players.add(audio);
              }
              return audio;
            },
          ),
        ),
      );
      await settle();
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await settle();
      expect(
        Theme.of(tester.element(find.byType(Scaffold))).brightness,
        Brightness.dark,
      );
      await tester.tap(find.text('Проверить звучание'));
      await settle();
      final typing = find.byKey(const ValueKey('keyboard-typing'));
      await tester.ensureVisible(typing);
      await tester.enterText(typing, 'Проверка печати');
      FocusManager.instance.primaryFocus?.unfocus();
      await settle();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 1000));
      await settle();
      await tester.tap(find.text('Проверить звучание'));
      await settle();
      expect(typing, findsNothing);
      await tester.tap(find.text('Проверить звучание'));
      await settle();
      expect(find.text('Проверка печати'), findsOneWidget);
      expect(repository.selected.id, 'brown');
      final search = find.widgetWithText(TextField, 'Поиск клавиатуры');
      await tester.ensureVisible(search);
      await tester.enterText(search, 'Red');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      await tester.scrollUntilVisible(
        find.text('Cherry MX Red'),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.byKey(const ValueKey('preview-red')));
      await tester.tap(find.byKey(const ValueKey('preview-red')));
      await settle();
      expect(repository.selected.id, 'brown');
      expect(audio.source, startsWith('keyboards/red/'));
      await tester.tap(find.byKey(const ValueKey('preview-red')));
      await settle();
      expect(audio.playing, isFalse);
      await tester.tap(find.byKey(const ValueKey('choose-red')));
      await settle();
      expect(repository.selected.id, 'red');
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 1000));
      await settle();
      await tester.tap(find.byKey(const ValueKey('preview-selected')));
      await settle();
      expect(
        players.expand((player) => player.loads).length,
        greaterThanOrEqualTo(2),
      );
      expect(repository.enabled, isFalse);
      for (final label in ['Буква', 'Пробел', 'Enter', '⌫']) {
        await tester.ensureVisible(find.text(label));
        await settle();
        await tester.tap(find.text(label));
        await settle();
      }
      expect(audio.source, 'keyboards/red/backspace.wav');
      await tester.ensureVisible(find.text('История'));
      await tester.tap(find.text('История'));
      await settle();
      expect(find.text('В истории: 1'), findsOneWidget);
      expect(find.text('Cherry MX Red'), findsWidgets);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 1000));
      await settle();
      await tester.tap(find.byType(Switch));
      await settle();
      expect(repository.enabled, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await settle();
      expect(audio.disposed, isTrue);
      expect(repository.disposed, isTrue);
    },
  );
}
