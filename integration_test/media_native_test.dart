import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:walone/core/audio.dart';
import 'package:walone/core/storage.dart';
import 'package:walone/core/widgets.dart';
import 'package:walone/features/atmosphere/data/atmosphere_audio.dart';
import 'package:walone/features/atmosphere/domain/atmosphere.dart';
import 'package:walone/features/atmosphere/presentation/atmosphere_cubit.dart';
import 'package:walone/features/keyboard/data/native_keyboard_repository.dart';
import 'package:walone/features/keyboard/presentation/keyboard_cubit.dart';
import 'package:walone/features/music/data/music_repository.dart';
import 'package:walone/features/music/data/vk_session.dart';
import 'package:walone/features/music/presentation/import_cubit.dart';
import 'package:walone/features/music/presentation/music_cubit.dart';
import 'package:walone/features/timer/data/timer_sound.dart';
import 'package:walone/features/timer/presentation/timer_cubit.dart';

class _CompletionAudio extends DesktopAudio {
  final disposed = Completer<void>();

  @override
  Future<void> dispose() async {
    await super.dispose();
    disposed.complete();
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Нативные сигналы работы и отдыха освобождают плееры', (
    tester,
  ) async {
    for (final phase in PomodoroPhase.values) {
      final audio = _CompletionAudio();
      await audio.setVolume(0);
      final sound = TimerSound(factory: () => audio);
      try {
        await sound.play(phase);
        await audio.disposed.future.timeout(const Duration(seconds: 10));
      } finally {
        await sound.dispose();
      }
    }
  });
  testWidgets('Нативный рендерер рисует стекло шейдером над реальным фоном', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (_, child) => WaloneGlassHost(child: child!),
        home: const Scaffold(
          body: Center(
            child: SizedBox(
              width: 200,
              height: 120,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: ColoredBox(color: Colors.black)),
                        Expanded(child: ColoredBox(color: Colors.white)),
                      ],
                    ),
                  ),
                  Positioned.fill(
                    child: FrostedPanel(radius: 0, child: SizedBox.expand()),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final appearance = WaloneGlassHost.maybeOf(
      tester.element(find.byType(FrostedPanel)),
    )!;
    appearance.followSystem(false);
    appearance.setTransparency(1);
    await tester.pumpAndSettle();
    final surface = tester.renderObject<RenderGlassSurface>(
      find.byType(GlassSurface),
    );
    expect(surface.paintsWithOptics, greaterThan(0));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Птицы и чайки освобождают нативные плееры после WAV', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    final players = <_CompletionAudio>[];
    final ready = Completer<void>();
    final audio = AtmosphereAudio(
      factory: () {
        final player = _CompletionAudio();
        players.add(player);
        if (players.length == 2) ready.complete();
        return player;
      },
    );
    try {
      await audio.update({'birds': 0, 'seagulls': 0});
      await ready.future.timeout(const Duration(seconds: 10));
      await Future.wait(players.map((player) => player.disposed.future))
          .timeout(const Duration(seconds: 20));
      expect(players, hasLength(2));
      expect(players.every((player) => player.disposed.isCompleted), isTrue);
    } finally {
      await audio.stop();
    }
  });

  testWidgets(
    'Нативное аудио: 14 фоновых WAV, локальный плеер, общий микс и FFmpeg-нарезка',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Text('Проверка аудио с нулевой громкостью')),
        ),
      );
      final root = await Directory.systemTemp.createTemp(
        'walone-native-media-',
      );
      final keyboard = KeyboardCubit(const NativeKeyboardRepository());
      final repository = MusicRepository(Directory(p.join(root.path, 'Music')));
      final music = MusicCubit(repository);
      final atmosphere = AtmosphereCubit(
        store: JsonStore(File(p.join(root.path, 'atmosphere.json'))),
        audio: AtmosphereAudio(),
        music: music,
        keyboard: keyboard,
      );
      final importer = ImportCubit(music, VkSession(root));
      try {
        await keyboard.initialize();
        await music.initialize();
        await atmosphere.initialize();
        await atmosphere.setMaster(0);
        final probe = DesktopAudio();
        try {
          await probe.setVolume(0);
          for (final id in ambientTitles.keys) {
            for (final name
                in id == 'birds' || id == 'seagulls'
                    ? ['$id-0', '$id-1', '$id-2']
                    : [id]) {
              expect(
                await probe.load('atmosphere/$name.wav', asset: true),
                greaterThan(Duration.zero),
              );
              await probe.play();
              await probe.pause();
            }
          }
        } finally {
          await probe.dispose();
        }
        final bytes = await rootBundle.load('assets/atmosphere/white.wav');
        final original = await File(p.join(root.path, 'recording.wav'))
            .writeAsBytes(
              bytes.buffer.asUint8List(
                bytes.offsetInBytes,
                bytes.lengthInBytes,
              ),
            );
        await music.savePlaylist('Нативный тест');
        final playlistID = repository.library.selectedID!;
        await importer.files([original.path]);
        expect(importer.state.error, isNull);
        final track = repository.library.tracks.single;
        await music.play(trackID: track.id, playlistID: playlistID);
        expect(music.state.error, isNull);
        expect(music.state.playing, isTrue);
        await music.seek(2);
        music.setVisualizationVisible(false);
        expect(music.visualization.value, isNull);
        expect(music.state.playing, isTrue);
        music.setVisualizationVisible(true);
        expect(music.state.playing, isTrue);
        await music.pause();
        expect(music.visualization.value, isNull);
        final restored = MusicRepository(repository.directory);
        try {
          await restored.initialize();
          expect(restored.library.position, closeTo(2, 0.5));
        } finally {
          await restored.close();
        }
        await atmosphere.setLayer('rain', enabled: true);
        await atmosphere.setLayer('ocean', enabled: true);
        await atmosphere.toggleBackground();
        expect(atmosphere.state.error, isNull);
        await music.play();
        await atmosphere.pause();
        expect(music.state.playing, isFalse);
        await atmosphere.resume();
        expect(music.state.playing, isTrue);
        await atmosphere.interrupt();
        await atmosphere.resume();
        expect(music.state.playing, isFalse);
        await importer.split(
          track,
          playlistID,
          '0:00 Первая часть\n0:04 Вторая часть',
        );
        expect(importer.state.error, isNull);
        expect(repository.library.playlist(playlistID)!.trackIDs, hasLength(2));
        expect(await original.exists(), isTrue);
        await atmosphere.pause();
      } finally {
        await importer.close();
        await atmosphere.close();
        await music.close();
        await keyboard.close();
        await root.delete(recursive: true);
      }
    },
  );
}
