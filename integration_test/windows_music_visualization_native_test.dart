import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:walone/core/audio.dart';
import 'package:walone/features/music/data/music_repository.dart';
import 'package:walone/features/music/presentation/music_cubit.dart';
import 'package:walone/features/music/presentation/music_logo.dart';

import 'windows_waveform_native_test.dart' as waveform;

// Плеер и позиция настоящие; тест не озвучивает проверочный сигнал.
class _SilentAudio extends DesktopAudio {
  @override
  Future<void> setVolume(double volume) => super.setVolume(0);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  waveform.main();

  testWidgets('Windows анимирует логотип при настоящем воспроизведении', (
    tester,
  ) async {
    final directory = await Directory.systemTemp.createTemp(
      'walone-music-icon-',
    );
    final repository = MusicRepository(
      directory,
      audioFactory: _SilentAudio.new,
    );
    final music = MusicCubit(repository);
    final frames = <List<double>>[];
    void record() {
      final bars = music.visualization.value;
      if (bars != null) frames.add(List.of(bars));
    }

    try {
      final data = await rootBundle.load('assets/atmosphere/rain.wav');
      final source = File('${directory.path}/source.wav');
      await source.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
      await repository.initialize();
      final track = await repository.prepareFile(source.path);
      await repository.commit(repository.library.copyWith(tracks: [track]));
      await music.initialize();
      music.setTrayVisualizationEnabled(true);
      music.visualization.addListener(record);
      await tester.pumpWidget(MaterialApp(home: MusicLogo(music: music)));
      await music.play();
      await Future<void>.delayed(const Duration(seconds: 2));
      await tester.pump();
      expect(music.state.playing, isTrue, reason: music.state.error);
      expect(music.state.position, greaterThan(0.1));
      expect(frames.length, greaterThan(3));
      expect(
        frames.map((bars) => bars.last.toStringAsFixed(2)).toSet().length,
        greaterThan(1),
        reason: 'Уровни должны меняться вместе с реальным звуком',
      );
      expect(find.byIcon(Icons.graphic_eq_rounded), findsNothing);
      await music.pause();
      expect(music.visualization.value, isNull);
    } finally {
      music.visualization.removeListener(record);
      await tester.pumpWidget(const SizedBox.shrink());
      await music.close();
      await directory.delete(recursive: true);
    }
  }, skip: !Platform.isWindows);
}
