import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walone/core/storage.dart';
import 'package:walone/core/widgets.dart';
import 'package:walone/features/atmosphere/data/atmosphere_audio.dart';
import 'package:walone/features/atmosphere/presentation/atmosphere_cubit.dart';
import 'package:walone/features/atmosphere/presentation/atmosphere_page.dart';
import 'package:walone/features/keyboard/domain/keyboard.dart';
import 'package:walone/features/keyboard/presentation/keyboard_cubit.dart';
import 'package:walone/features/keyboard/presentation/keyboard_page.dart';
import 'package:walone/features/music/data/music_repository.dart';
import 'package:walone/features/music/domain/music.dart';
import 'package:walone/features/music/presentation/import_cubit.dart';
import 'package:walone/features/music/presentation/music_cubit.dart';
import 'package:walone/features/settings/presentation/settings_cubit.dart';
import 'package:walone/features/timer/presentation/timer_cubit.dart';
import 'package:walone/workspace.dart';

import 'media_fakes.dart';

class MemoryMixStore extends JsonStore {
  MemoryMixStore() : super(File('/unused/mix.json'));
  @override
  Future<Map<String, dynamic>?> read() async => null;
  @override
  Future<void> write(Map<String, dynamic> value) async {}
}

class DelayedMusic extends MusicRepository {
  DelayedMusic()
    : super(Directory('/unused/music'), audioFactory: FakeAudio.new) {
    library = MusicLibrary(
      tracks: [
        MusicTrack(
          id: 'track',
          title: 'Track',
          filename: 'track.wav',
          duration: 10,
        ),
      ],
      playlists: [
        MusicPlaylist(id: 'playlist', name: 'Playlist', trackIDs: ['track']),
      ],
      selectedID: 'playlist',
      playingID: 'playlist',
      trackID: 'track',
    );
  }
  Completer<void>? gate;
  bool fail = false;
  @override
  Future<void> initialize() async {}
  @override
  Future<void> commit(MusicLibrary next) async {
    await gate?.future;
    if (fail) throw StateError('Запись недоступна');
    library = next;
  }
}

class DelayedKeyboard extends FakeKeyboard {
  Completer<void>? gate;
  double appliedVolume = 0;
  bool fail = false;
  @override
  Future<void> configure(KeyboardPack pack, bool enabled, double volume) async {
    await gate?.future;
    if (fail) throw StateError('Аудио недоступно');
    await super.configure(pack, enabled, volume);
    appliedVolume = volume;
  }
}

void main() {
  test(
    'Ошибка громкости клавиатуры восстанавливает подтверждённое значение',
    () async {
      final repository = DelayedKeyboard();
      final keyboard = KeyboardCubit(repository);
      await keyboard.initialize();
      final previous = keyboard.state.volume;
      repository.fail = true;
      await keyboard.configure(volume: 0.8);
      expect(keyboard.state.volume, previous);
      expect(keyboard.state.error, isNotNull);
      repository.fail = false;
      await keyboard.configure(volume: 0.2);
      expect(keyboard.state.volume, 0.2);
      expect(repository.appliedVolume, 0.2);
      await keyboard.close();
    },
  );

  test(
    'Ошибка сохранения музыки снимает ожидающее значение громкости',
    () async {
      final repository = DelayedMusic();
      final music = MusicCubit(repository);
      await music.initialize();
      final previous = music.state.library.volume;
      repository.fail = true;
      await music.configure(volume: 0.8);
      expect(music.state.library.volume, previous);
      expect(music.state.error, isNotNull);
      repository.fail = false;
      await music.configure(volume: 0.2);
      expect(music.state.library.volume, 0.2);
      expect(repository.library.volume, 0.2);
      await music.close();
    },
  );

  for (final label in [
    'Громкость атмосферы',
    'Громкость клавиатуры',
    'Громкость музыки',
    'Общая громкость',
    'Дождь',
  ]) {
    testWidgets('Быстрые изменения: $label синхронна во всех представлениях', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final messenger = tester.binding.defaultBinaryMessenger;
      const appearanceChannel = MethodChannel('dev.soyjanks.walone/appearance');
      messenger.setMockMethodCallHandler(
        appearanceChannel,
        (_) async => <String, dynamic>{},
      );
      addTearDown(
        () => messenger.setMockMethodCallHandler(appearanceChannel, null),
      );
      const desktopChannel = MethodChannel('dev.soyjanks.walone/desktop');
      messenger.setMockMethodCallHandler(
        desktopChannel,
        (_) async => <String, dynamic>{},
      );
      addTearDown(
        () => messenger.setMockMethodCallHandler(desktopChannel, null),
      );
      late DelayedMusic repository;
      late MusicCubit music;
      late DelayedKeyboard keyboardRepository;
      late KeyboardCubit keyboard;
      late AtmosphereCubit atmosphere;
      late ImportCubit importer;
      late SettingsCubit settings;
      Completer<void>? environmentGate;
      await tester.runAsync(() async {
        repository = DelayedMusic();
        music = MusicCubit(repository);
        keyboardRepository = DelayedKeyboard();
        keyboard = KeyboardCubit(keyboardRepository);
        atmosphere = AtmosphereCubit(
          store: MemoryMixStore(),
          audio: AtmosphereAudio(factory: FakeAudio.new),
          music: music,
          keyboard: keyboard,
          keyboardEnvironment: (_, _) async => environmentGate?.future,
          lifecycle: const Stream.empty(),
        );
        importer = ImportCubit(music, FakeVkSession(Directory('/unused')));
        settings = SettingsCubit(atmosphere);
        await music.initialize();
        await keyboard.initialize();
        await atmosphere.initialize();
      });
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider.value(value: music),
            BlocProvider.value(value: keyboard),
            BlocProvider.value(value: atmosphere),
            BlocProvider.value(value: importer),
            BlocProvider.value(value: settings),
            BlocProvider(create: (_) => TimerCubit()),
          ],
          child: MaterialApp(
            builder: (_, child) => WaloneGlassHost(child: child!),
            home: const WorkspacePage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final appearance = WaloneGlassHost.maybeOf(
        tester.element(find.byType(WorkspacePage)),
      )!;
      appearance.setCompactPlayer(false);
      if (label == 'Громкость клавиатуры') {
        final sidebar = find.byType(WorkspaceSidebar);
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(of: sidebar, matching: find.text('Клавиатура')).first,
        );
      }
      await tester.pumpAndSettle();
      Finder sliders() => find.byWidgetPredicate(
        (widget) => widget is GainSlider && widget.label == label,
        skipOffstage: false,
      );
      void expectValues(double value) {
        expect(
          sliders().evaluate().length,
          greaterThanOrEqualTo(
            ['Громкость атмосферы', 'Громкость клавиатуры'].contains(label)
                ? 2
                : 1,
          ),
        );
        for (final element in sliders().evaluate()) {
          final control = find.descendant(
            of: find.byWidget(element.widget, skipOffstage: false),
            matching: find.byType(CupertinoSlider, skipOffstage: false),
          );
          expect(
            tester.widget<CupertinoSlider>(control).value,
            closeTo(value, 0.001),
          );
        }
      }

      void change(double value, {bool mini = false, bool page = false}) {
        final target = page
            ? find
                  .descendant(
                    of: label == 'Громкость клавиатуры'
                        ? find.byType(KeyboardPage, skipOffstage: false)
                        : find.byType(AtmospherePage, skipOffstage: false),
                    matching: sliders(),
                  )
                  .first
            : mini
            ? find.descendant(
                of: find.byType(CompactPlayer),
                matching: sliders(),
              )
            : sliders().last;
        final control = tester.widget<CupertinoSlider>(
          find.descendant(
            of: target,
            matching: find.byType(CupertinoSlider, skipOffstage: false),
          ),
        );
        expect(control.onChanged, isNotNull);
        control.onChangeStart!(control.value);
        control.onChanged!(value);
        control.onChangeEnd!(value);
      }

      final gate = Completer<void>();
      if (label == 'Громкость музыки') {
        repository.gate = gate;
      } else if (label == 'Громкость клавиатуры') {
        keyboardRepository.gate = gate;
      } else {
        environmentGate = gate;
      }
      try {
        for (final value in [0.8, 0.2, 0.65, 0.35]) {
          change(value);
          await tester.pump();
          expectValues(value);
        }
        appearance.setCompactPlayer(true);
        await tester.pumpAndSettle();
        expectValues(0.35);
        change(0.8, mini: label != 'Дождь');
        await tester.pump();
        expectValues(0.8);
        if (['Громкость атмосферы', 'Громкость клавиатуры'].contains(label)) {
          change(0.55, page: true);
          await tester.pump();
          expectValues(0.55);
          change(0.8, page: true);
          await tester.pump();
          expectValues(0.8);
        }
        appearance.setCompactPlayer(false);
        await tester.pumpAndSettle();
        expectValues(0.8);
        gate.complete();
        for (var frame = 0; frame < 30; frame++) {
          await tester.pump(const Duration(milliseconds: 20));
          await tester.runAsync(() => Future<void>.delayed(Duration.zero));
          expectValues(0.8);
        }
        if (label == 'Громкость музыки') expect(repository.library.volume, 0.8);
        if (label == 'Громкость клавиатуры') {
          expect(keyboardRepository.appliedVolume, 0.8);
        }
      } finally {
        if (!gate.isCompleted) gate.complete();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();

        Future<void> drain(Future<void> operation) async {
          var done = false;
          operation.then((_) => done = true);
          for (var turn = 0; turn < 100 && !done; turn++) {
            await tester.pump();
            await tester.runAsync(() => Future<void>.delayed(Duration.zero));
          }
          expect(
            done,
            isTrue,
            reason: 'Очередь должна завершиться после снятия задержки',
          );
          await operation;
        }

        await drain(importer.close());
        await drain(settings.close());
        await drain(atmosphere.close());
        await drain(keyboard.close());
        await drain(music.close());
      }
    });
  }
}
