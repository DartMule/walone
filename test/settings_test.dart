import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:walone/workspace.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:walone/core/storage.dart';
import 'package:walone/features/atmosphere/data/atmosphere_audio.dart';
import 'package:walone/features/atmosphere/presentation/atmosphere_cubit.dart';
import 'package:walone/features/keyboard/presentation/keyboard_cubit.dart';
import 'package:walone/features/music/data/music_repository.dart';
import 'package:walone/features/music/presentation/music_cubit.dart';
import 'package:walone/features/settings/presentation/settings_cubit.dart';

import 'package:walone/features/timer/presentation/timer_cubit.dart';

import 'media_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('walone/test/desktop');
  late Directory root;
  late KeyboardCubit keyboard;
  late MusicCubit music;
  late AtmosphereCubit atmosphere;
  late SettingsCubit settings;
  late TimerCubit timer;
  late List<MethodCall> calls;
  var login = 'disabled';
  var reject = false;
  var playerUnsupported = false;
  String? updateVersion;
  var updateReady = false;

  Future<void> action(
    String name, {
    String? id,
    String? version,
    bool? ready,
  }) async {
    final done = Completer<void>();
    ServicesBinding.instance.channelBuffers.push(
      channel.name,
      channel.codec.encodeMethodCall(
        MethodCall('action', {
          'action': name,
          'id': id,
          'version': version,
          'ready': ready,
        }),
      ),
      (reply) {
        try {
          channel.codec.decodeEnvelope(reply!);
          done.complete();
        } catch (error, stack) {
          done.completeError(error, stack);
        }
      },
    );
    await done.future;
  }

  setUp(() async {
    calls = [];
    login = 'disabled';
    reject = false;
    playerUnsupported = false;
    updateVersion = null;
    updateReady = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          switch (call.method) {
            case 'initialize':
            case 'status':
              return {
                'login': login,
                'trayAvailable': true,
                'updateVersion': updateVersion,
                'updateReady': updateReady,
              };
            case 'updatePlayerTray':
              if (playerUnsupported) throw MissingPluginException();
            case 'setLaunchAtLogin':
              if (reject) {
                throw PlatformException(code: 'denied', message: 'Отказ ОС');
              }
              login = call.arguments == true ? 'requiresApproval' : 'disabled';
          }
          return null;
        });
    root = await Directory.systemTemp.createTemp('walone-settings-');
    keyboard = KeyboardCubit(FakeKeyboard());
    await keyboard.initialize();
    music = MusicCubit(
      MusicRepository(
        Directory(p.join(root.path, 'Music')),
        audioFactory: FakeAudio.new,
      ),
      waveformFactory: FakeWaveform.new,
    );
    await music.initialize();
    atmosphere = AtmosphereCubit(
      store: JsonStore(File(p.join(root.path, 'atmosphere.json'))),
      audio: AtmosphereAudio(factory: FakeAudio.new),
      music: music,
      keyboard: keyboard,
      keyboardEnvironment: (_, _) async {},
      lifecycle: const Stream.empty(),
    );
    await atmosphere.initialize();
    timer = TimerCubit();
    settings = SettingsCubit(atmosphere, channel: channel, timer: timer);
    await settings.initialize();
  });
  tearDown(() async {
    await settings.close();
    await timer.close();
    await atmosphere.close();
    await music.close();
    await keyboard.close();
    await root.delete(recursive: true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  for (final brightness in Brightness.values) {
    testWidgets('Кнопка обновления рядом с настройками: $brightness', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: Scaffold(
            body: WorkspaceSidebar(
              selected: 0,
              onSelected: (_) {},
              settings: settings,
            ),
          ),
        ),
      );
      expect(find.byIcon(Icons.system_update_alt_rounded), findsNothing);
      await tester.runAsync(
        () => action('updateStatus', version: '0.1.1', ready: false),
      );
      await tester.pump();
      final button = find.byTooltip('Обновить до 0.1.1');
      expect(button, findsOneWidget);
      expect(
        tester.getCenter(find.text('Настройки')).dy,
        inInclusiveRange(
          tester.getTopLeft(button).dy,
          tester.getBottomRight(button).dy,
        ),
      );
      await tester.tap(button);
      expect(calls.last.method, 'checkForUpdates');
      await tester.runAsync(
        () => action('updateStatus', version: '0.1.1', ready: true),
      );
      await tester.pump();
      await tester.tap(find.byTooltip('Обновить и перезапустить'));
      expect(calls.last.method, 'checkForUpdates');
      await tester.runAsync(() => action('updateStatus'));
      await tester.pump();
      expect(find.byIcon(Icons.system_update_alt_rounded), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  test('Автозапуск меняется только явно; отказ сохраняет статус ОС', () async {
    expect(settings.state.launchAtLogin, isFalse);
    expect(calls.any((call) => call.method == 'setLaunchAtLogin'), isFalse);
    await settings.setLaunchAtLogin(true);
    expect(settings.state.login, LoginStatus.requiresApproval);
    expect(settings.state.launchAtLogin, isTrue);
    reject = true;
    await settings.setLaunchAtLogin(false);
    expect(settings.state.launchAtLogin, isTrue);
    expect(settings.state.error, contains('Отказ ОС'));
    reject = false;
    await settings.setLaunchAtLogin(false);
    expect(settings.state.launchAtLogin, isFalse);
    expect(settings.state.error, isNull);
  });

  test(
    'Готовое обновление сохраняется при обновлении статуса и командах',
    () async {
      updateVersion = '0.2.0';
      updateReady = true;
      await action('updateStatus', version: updateVersion, ready: true);
      expect(settings.state.updateVersion, '0.2.0');
      expect(settings.state.updateReady, isTrue);
      await settings.refresh();
      await settings.setLaunchAtLogin(true);
      expect(settings.state.updateReady, isTrue);
      await settings.command('checkForUpdates');
      expect(calls.last.method, 'checkForUpdates');
      await action('updateStatus', ready: false);
      expect(settings.state.updateReady, isFalse);
      expect(settings.state.updateVersion, isNull);
    },
  );

  test(
    'Трей получает пять уровней музыки и сбрасывает значок на паузе',
    () async {
      final source = await File(p.join(root.path, 'audio.wav'))
          .writeAsString('10');
      final track = await music.repository.prepareFile(source.path);
      await music.accept([track], newPlaylistName: 'Музыка');
      final frame = Completer<void>();
      void changed() {
        if (music.visualization.value != null && !frame.isCompleted) {
          frame.complete();
        }
      }

      music.visualization.addListener(changed);
      await music.play();
      await frame.future.timeout(const Duration(seconds: 2));
      await Future<void>.delayed(Duration.zero);
      final updates = calls.where((call) => call.method == 'updateMusicTray');
      expect(updates.last.arguments, hasLength(5));
      music.setVisualizationVisible(false);
      expect(music.state.playing, isTrue);
      final hiddenUpdates = updates.length;
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(updates.length, greaterThan(hiddenUpdates));
      expect(updates.last.arguments, hasLength(5));
      await music.pause();
      await Future<void>.delayed(Duration.zero);
      expect(
        calls.lastWhere((call) => call.method == 'updateMusicTray').arguments,
        isNull,
      );
      await music.play();
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(updates.last.arguments, hasLength(5));
      await settings.close();
      expect(music.state.playing, isTrue);
      expect(music.visualization.value, isNull);
      music.visualization.removeListener(changed);
    },
  );

  test('Трей использует общую паузу, таймер, фон и выбранный набор', () async {
    await atmosphere.setLayer('rain', enabled: true);
    await atmosphere.savePreset('Дождь & музыка');
    final preset = atmosphere.state.presets.single;
    await action('preset', id: preset.id);
    expect(atmosphere.state.running, isTrue);
    await action('togglePause');
    expect(atmosphere.state.paused, isTrue);
    await action('togglePause');
    expect(atmosphere.state.paused, isFalse);
    await action('pause15');
    expect(
      atmosphere.state.pausedUntil!.difference(DateTime.now()).inMinutes,
      14,
    );
    await action('stopBackground');
    expect(atmosphere.state.running, isFalse);
    await settings.refresh();
    // Очередь обновления меню должна закончиться до проверки последнего снимка.
    await Future<void>.delayed(Duration.zero);
    final tray =
        calls.lastWhere((call) => call.method == 'updateTray').arguments as Map;
    expect(tray['selectedID'], preset.id);
    expect(tray['running'], isFalse);
    expect((tray['presets'] as List).single, {
      'id': preset.id,
      'name': 'Дождь & музыка',
    });
  });

  test('Плеер трея управляет музыкой и обновляет название и паузу', () async {
    Map<dynamic, dynamic> snapshot() =>
        calls.lastWhere((call) => call.method == 'updatePlayerTray').arguments
            as Map;
    expect(snapshot()['available'], isFalse);
    final tracks = [
      for (var index = 0; index < 2; index++)
        await music.repository.prepareFile(
          (await File(p.join(root.path, 'track$index.wav'))
                  .writeAsString('${10 + index}'))
              .path,
        ),
    ];
    await music.accept(tracks, newPlaylistName: 'Музыка');
    await Future<void>.delayed(Duration.zero);
    expect(snapshot()['available'], isTrue);
    await action('toggleMusic');
    await Future<void>.delayed(Duration.zero);
    expect(music.state.playing, isTrue);
    expect(snapshot()['playing'], isTrue);
    expect(snapshot()['title'], tracks.first.title);
    await action('nextTrack');
    await Future<void>.delayed(Duration.zero);
    expect(music.state.library.trackID, tracks.last.id);
    expect(snapshot()['title'], tracks.last.title);
    await action('previousTrack');
    expect(music.state.library.trackID, tracks.first.id);
    await action('toggleMusic');
    await Future<void>.delayed(Duration.zero);
    expect(snapshot()['playing'], isFalse);
    int? section;
    settings.onNavigate = (value) => section = value;
    await action('music');
    expect(section, 1);
  });

  test(
    'Отсутствие нативного плеера не ломает настройки на других ОС',
    () async {
      playerUnsupported = true;
      final track = await music.repository.prepareFile(
        (await File(p.join(root.path, 'audio.wav')).writeAsString('10')).path,
      );
      await music.accept([track], newPlaylistName: 'Музыка');
      await Future<void>.delayed(Duration.zero);
      expect(settings.state.error, isNull);
      await action('togglePause');
      expect(atmosphere.state.paused, isTrue);
    },
  );

  test('Таймер передаёт время в трей и принимает команды меню', () async {
    timer.toggle();
    await Future<void>.delayed(Duration.zero);
    Map<dynamic, dynamic> snapshot() =>
        calls.lastWhere((call) => call.method == 'updateTimerTray').arguments
            as Map;
    expect(snapshot()['title'], contains('Рабочая сессия'));
    expect(snapshot()['running'], isTrue);
    await action('toggleTimer');
    await Future<void>.delayed(Duration.zero);
    expect(timer.state.current.running, isFalse);
    expect(snapshot()['title'], contains('пауза'));
    int? section;
    settings.onNavigate = (value) => section = value;
    await action('timers');
    expect(section, 4);
    await action('resetTimer');
    await Future<void>.delayed(Duration.zero);
    expect(snapshot()['title'], isEmpty);
    timer.toggle();
    timer.setShowInTray(false);
    await Future<void>.delayed(Duration.zero);
    expect(snapshot()['title'], contains('Рабочая сессия'));
    expect(snapshot()['time'], isEmpty);
    expect(timer.state.current.running, isTrue);
    await action('toggleTimer');
    expect(timer.state.current.running, isFalse);
  });

  test('Настройки и скрытие окна не посылают команду завершения', () async {
    int? section;
    settings.onNavigate = (value) => section = value;
    await action('settings');
    expect(section, 3);
    await action('atmosphere');
    expect(section, 0);
    await settings.command('hide');
    await settings.command('restoreTray');
    expect(calls.any((call) => call.method == 'quit'), isFalse);
    expect(settings.state.trayAvailable, isTrue);
    await settings.command('quit');
    expect(calls.last.method, 'quit');
  });
}
