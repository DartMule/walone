// Диагностическая Release-точка входа; не использовать для установки приложения.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:walone/core/widgets.dart';
import 'package:walone/features/atmosphere/domain/atmosphere.dart';
import 'package:walone/features/atmosphere/presentation/atmosphere_cubit.dart';
import 'package:walone/features/keyboard/presentation/keyboard_cubit.dart';
import 'package:walone/features/music/presentation/music_cubit.dart';
import 'package:walone/features/music/domain/music.dart';
import 'package:walone/features/settings/presentation/settings_cubit.dart';
import 'package:walone/main.dart' as app;
import 'package:walone/workspace.dart';

Future<void> main(List<String> arguments) async {
  final path = Platform.environment['WALONE_MEMORY_PROBE'];
  if (path == null) {
    throw StateError('Запускайте через measure_macos_memory.py --probe');
  }
  final output = Directory(path);
  var sequence = 0;
  final frameSamples = <ui.FrameTiming>[];
  final frameReport = <String, Object>{};
  final frameClock = Stopwatch()..start();
  Future<void> stage(String name) async {
    await Future<void>.delayed(const Duration(seconds: 3));
    final id = ++sequence;
    final marker = File('${output.path}/stage.json');
    final temporary = File('${marker.path}.tmp');
    await temporary.writeAsString(jsonEncode({'id': id, 'name': name}));
    await temporary.rename(marker.path);
    final ack = File('${output.path}/$id.continue');
    final deadline = DateTime.now().add(const Duration(seconds: 60));
    while (!await ack.exists()) {
      if (DateTime.now().isAfter(deadline)) {
        throw StateError('Нет ответа измерителя: $name');
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    final frames = List<ui.FrameTiming>.of(frameSamples);
    frameSamples.clear();
    final elapsed = frameClock.elapsedMicroseconds;
    frameClock.reset();
    int percentile(List<int> values, double p) {
      if (values.isEmpty) return 0;
      values.sort();
      return values[((values.length - 1) * p).round()];
    }

    frameReport[name] = {
      'frames': frames.length,
      'elapsed_us': elapsed,
      'build_p95_us': percentile([
        for (final frame in frames) frame.buildDuration.inMicroseconds,
      ], 0.95),
      'raster_p95_us': percentile([
        for (final frame in frames) frame.rasterDuration.inMicroseconds,
      ], 0.95),
    };
    await File('${output.path}/frame-timings.json')
        .writeAsString(jsonEncode(frameReport));
  }

  WidgetsFlutterBinding.ensureInitialized().addTimingsCallback(
    frameSamples.addAll,
  );
  final scenario = Platform.environment['WALONE_MEMORY_SCENARIO'];
  if (scenario == 'empty' || scenario == 'animation' || scenario == 'slider') {
    runApp(
      const MaterialApp(
        home: Scaffold(body: Center(child: Text('Walone memory baseline'))),
      ),
    );
    await stage('empty_flutter');
    if (scenario == 'animation' || scenario == 'slider') {
      final level = ValueNotifier<double>(0.3);
      runApp(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: RepaintBoundary(
                child: ValueListenableBuilder<double>(
                  valueListenable: level,
                  builder: (_, value, _) => scenario == 'slider'
                      ? SizedBox(
                          width: 180,
                          child: GainSlider(
                            value: value,
                            onChanged: (_) {},
                            compact: true,
                          ),
                        )
                      : SizedBox(
                          width: 27,
                          height: 27,
                          child: Center(
                            child: Container(
                              width: 3,
                              height: 4 + 23 * value,
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
      );
      final timer = Timer.periodic(const Duration(milliseconds: 50), (_) {
        level.value = level.value == 0.3 ? 0.7 : 0.3;
      });
      await stage(scenario == 'slider' ? 'slider_animated' : 'empty_animated');
      timer.cancel();
      await stage('empty_stopped');
    }
  } else {
    await app.main(arguments);
    Element? workspace;
    void search(Element element) {
      if (element.widget is WorkspacePage) workspace = element;
      element.visitChildren(search);
    }

    for (var attempt = 0; attempt < 200 && workspace == null; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      WidgetsBinding.instance.rootElement?.visitChildren(search);
    }
    final context = workspace;
    if (context == null) throw StateError('Workspace не загрузился');
    final settings = context.read<SettingsCubit>();
    final keyboard = context.read<KeyboardCubit>();
    final appearance = WaloneGlassHost.maybeOf(context)!;
    await stage('startup');
    if (scenario == 'visual') {
      final music = context.read<MusicCubit>();
      settings.onNavigate!(0);
      (music.visualization as ValueNotifier<List<double>?>).value = [
        0.1,
        0.4,
        0.8,
        0.5,
        0.2,
      ];
      for (final compact in [true, false]) {
        appearance.setCompactPlayer(compact);
        for (final mode in [ThemeMode.light, ThemeMode.dark]) {
          appearance.setThemeMode(mode);
          final name = '${mode.name}_${compact ? "compact" : "expanded"}';
          await stage(name);
          final view = RendererBinding.instance.renderViews.single;
          // Собственная сцена тестового приложения; доступ к записи экрана не нужен.
          // ignore: invalid_use_of_protected_member
          final scene = view.layer!.buildScene(ui.SceneBuilder());
          final size = view.configuration.physicalConstraints.biggest;
          final image = await scene.toImage(
            size.width.ceil(),
            size.height.ceil(),
          );
          try {
            final png = await image.toByteData(format: ui.ImageByteFormat.png);
            await File('${output.path}/$name.png')
                .writeAsBytes(png!.buffer.asUint8List());
          } finally {
            image.dispose();
            scene.dispose();
          }
        }
      }
      await File('${output.path}/done').writeAsString('ok');
      return;
    }

    if (scenario == 'progress-only') {
      final music = context.read<MusicCubit>();
      final library = MusicLibrary(
        tracks: [
          MusicTrack(
            id: 'probe',
            title: 'Memory probe',
            filename: 'probe.wav',
            duration: 100,
          ),
        ],
        playlists: [
          MusicPlaylist(id: 'probe', name: 'Memory probe', trackIDs: ['probe']),
        ],
        selectedID: 'probe',
        playingID: 'probe',
        trackID: 'probe',
      );
      var position = 0.0;
      final timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
        position += 0.1;
        // ignore: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
        music.emit(MusicState(library: library, position: position));
      });
      await stage('progress_without_audio');
      timer.cancel();
      await stage('progress_stopped');
      await File('${output.path}/done').writeAsString('ok');
      return;
    }
    if (scenario == 'visualization-only') {
      final values =
          context.read<MusicCubit>().visualization
              as ValueNotifier<List<double>?>;
      var high = false;
      final timer = Timer.periodic(const Duration(milliseconds: 50), (_) {
        high = !high;
        values.value = high
            ? [0.7, 0.3, 0.5, 0.2, 0.8]
            : [0.3, 0.7, 0.2, 0.8, 0.5];
      });
      await stage('visualization_without_audio');
      timer.cancel();
      values.value = null;
      await stage('visualization_stopped');
      await File('${output.path}/done').writeAsString('ok');
      return;
    }

    final musicRender =
        scenario == 'music-render' || scenario == 'music-active';
    if (Platform.environment['WALONE_MEMORY_SCENARIO'] == 'music' ||
        musicRender) {
      final music = context.read<MusicCubit>();
      await context.read<AtmosphereCubit>().setMaster(musicRender ? 0.1 : 0);
      // Тот же музыкальный тракт и визуализация, но воспроизводимый локальный
      // WAV вместо зависимости от содержимого пользовательской медиатеки.
      final source = File('${output.path}/memory-track.wav');
      final bytes = await rootBundle.load('assets/atmosphere/rain.wav');
      await source.writeAsBytes(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      );
      final track = await music.repository.prepareFile(source.path);
      await music.accept([track], newPlaylistName: 'Memory probe');
      final playlistID = music.state.library.selectedID!;
      await music.configure(repeatMode: MusicRepeat.track);
      if (musicRender) {
        await music.play(trackID: track.id, playlistID: playlistID);
        if (music.state.error != null || !music.state.playing) {
          throw StateError(music.state.error ?? 'Музыка не запущена');
        }
        await stage('music_animated');
        if (!music.state.playing || music.state.error != null) {
          throw StateError(
            music.state.error ?? 'Музыка остановилась во время замера',
          );
        }
        if (scenario != 'music-active') {
          music.setVisualizationVisible(false);
          await stage('music_without_logo_animation');
          music.setVisualizationVisible(true);
          appearance.setTransparency(0);
          await stage('music_without_glass');
          appearance.setTransparency(0.75);
          await stage('music_restored');
        }
        await music.pause();
        await stage('music_paused');
        await File('${output.path}/done').writeAsString('ok');
        return;
      }
      for (var cycle = 1; cycle <= 5; cycle++) {
        await music.play(trackID: track.id, playlistID: playlistID);
        if (music.state.error != null || !music.state.playing) {
          throw StateError(music.state.error ?? 'Музыка не запущена');
        }
        await stage('music_playing_$cycle');
        await music.pause();
        await stage('music_paused_$cycle');
      }
      await Future<void>.delayed(const Duration(seconds: 20));
      await stage('music_idle_after_20s');
      await File('${output.path}/done').writeAsString('ok');
      return;
    }
    if (Platform.environment['WALONE_MEMORY_SCENARIO'] == 'media') {
      final atmosphere = context.read<AtmosphereCubit>();
      await atmosphere.setMaster(0);
      for (final id in ambientTitles.keys) {
        await atmosphere.setLayer(id, enabled: false);
      }
      await atmosphere.setLayer('rain', enabled: true);
      for (var cycle = 1; cycle <= 3; cycle++) {
        await atmosphere.toggleBackground();
        if (atmosphere.state.error != null) {
          throw StateError(atmosphere.state.error!);
        }
        await stage('rain_playing_$cycle');
        await atmosphere.toggleBackground();
        await stage('rain_stopped_$cycle');
      }
      await atmosphere.setLayer('ocean', enabled: true);
      await atmosphere.setLayer('train', enabled: true);
      await atmosphere.toggleBackground();
      if (atmosphere.state.error != null) {
        throw StateError(atmosphere.state.error!);
      }
      await stage('three_layers_playing');
      await atmosphere.toggleBackground();
      await stage('three_layers_stopped');
      await Future<void>.delayed(const Duration(seconds: 20));
      await stage('media_idle_after_20s');
      await File('${output.path}/done').writeAsString('ok');
      return;
    }
    for (var cycle = 1; cycle <= 3; cycle++) {
      for (final section in [1, 2, 3, 4, 5, 0]) {
        settings.onNavigate!(section);
        if (cycle == 1) {
          await stage('first_section_$section');
        } else {
          await Future<void>.delayed(const Duration(milliseconds: 700));
        }
      }
      await stage('after_tour_$cycle');
    }
    appearance.setCompactPlayer(false);
    await stage('live_glass');
    appearance.setCompactPlayer(true);
    await stage('compact_restored');
    appearance.setTransparency(0);
    await stage('no_glass');
    appearance.setTransparency(0.75);
    await stage('glass_restored');
    // Громкость 0: измеряем подготовку нативного пула, не воспроизводя звук.
    await keyboard.configure(enabled: true, volume: 0);
    if (keyboard.state.error != null) throw StateError(keyboard.state.error!);
    await stage('keyboard_enabled');
    await keyboard.configure(enabled: false, volume: 0);
    await stage('keyboard_disabled');
    await Future<void>.delayed(const Duration(seconds: 15));
    await stage('idle_after_15s');
  }
  await File('${output.path}/done').writeAsString('ok');
}
