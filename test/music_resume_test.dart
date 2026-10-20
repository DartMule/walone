import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:walone/features/music/data/music_repository.dart';
import 'package:walone/features/music/domain/music.dart';
import 'package:walone/features/music/presentation/music_cubit.dart';

import 'media_fakes.dart';

class ResumeAudio extends FakeAudio {
  Duration currentPosition = Duration.zero;
  final playbackPositions = <Duration>[];

  @override
  Future<Duration> load(
    String path, {
    bool asset = false,
    bool loop = false,
  }) async {
    currentPosition = Duration.zero;
    // audioplayers сообщает начальную позицию при загрузке источника.
    position.add(currentPosition);
    return super.load(path, asset: asset, loop: loop);
  }

  @override
  Future<void> seek(Duration value) async {
    currentPosition = value;
    await super.seek(value);
  }

  @override
  Future<void> play() async {
    playbackPositions.add(currentPosition);
    await super.play();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late MusicCubit music;
  late ResumeAudio audio;
  late MusicTrack track;
  late MusicTrack other;
  late String playlist;
  late List<FakeWaveform> waveforms;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('walone-resume-');
    final repository = MusicRepository(
      Directory(p.join(root.path, 'Music')),
      audioFactory: FakeAudio.new,
    );
    music = MusicCubit(repository);
    await music.initialize();
    final source = await File(p.join(root.path, 'first.wav'))
        .writeAsString('10');
    track = await repository.prepareFile(source.path);
    final second = await File(p.join(root.path, 'second.wav'))
        .writeAsString('11');
    other = await repository.prepareFile(second.path);
    await music.accept([track, other], newPlaylistName: 'Тест');
    playlist = repository.library.selectedID!;
    await music.play(trackID: track.id, playlistID: playlist);
    await music.seek(4);
    await music.close();

    audio = ResumeAudio();
    waveforms = [];
    music = MusicCubit(
      MusicRepository(repository.directory, audioFactory: () => audio),
      waveformFactory: () {
        final waveform = FakeWaveform();
        waveforms.add(waveform);
        return waveform;
      },
    );
    await music.initialize();
  });

  tearDown(() async {
    await music.close();
    await root.delete(recursive: true);
  });

  test(
    'Инициализация, громкость и пауза не создают музыкальный плеер',
    () async {
      var created = 0;
      final idle = MusicCubit(
        MusicRepository(
          music.repository.directory,
          audioFactory: () {
            created++;
            return ResumeAudio();
          },
        ),
      );
      await idle.initialize();
      await idle.environment(0.5, true);
      await idle.configure(volume: 0.4);
      await idle.pause();
      expect(created, 0);
      await idle.close();
      expect(created, 0);
    },
  );

  test('Скрытие отменяет расчёт, сохраняя звук и текущую позицию', () async {
    await music.play();
    await music.seek(6);
    expect(waveforms, hasLength(1));
    music.setVisualizationVisible(false);
    expect(waveforms.single.cancelled, isTrue);
    expect(music.visualization.value, isNull);
    expect(music.state.playing, isTrue);
    expect(audio.playing, isTrue);
    expect(audio.disposed, isFalse);
    audio.position.add(const Duration(seconds: 7));
    await Future<void>.delayed(Duration.zero);
    expect(music.state.position, 7);
    expect(waveforms, hasLength(1));
    music.setVisualizationVisible(true);
    expect(waveforms, hasLength(2));
    expect(waveforms.last.loads, 1);
    expect(audio.loads, hasLength(1));
    expect(audio.playbackPositions, [const Duration(seconds: 4)]);
    expect(music.state.position, 7);
  });

  test(
    'Пауза отменяет расчёт, Play возобновляет звук с той же позиции',
    () async {
      await music.play();
      await music.seek(6);
      await music.pause();
      expect(waveforms.single.cancelled, isTrue);
      expect(audio.playing, isFalse);
      expect(music.visualization.value, isNull);
      music.setVisualizationVisible(false);
      music.setVisualizationVisible(true);
      expect(waveforms, hasLength(1));
      await music.play();
      expect(waveforms, hasLength(2));
      expect(waveforms.last.cancelled, isFalse);
      expect(audio.playing, isTrue);
      expect(audio.loads, hasLength(1));
      expect(audio.playbackPositions.last, const Duration(seconds: 6));
    },
  );

  test('Play и смена трека в скрытом окне не запускают расчёт', () async {
    music.setVisualizationVisible(false);
    await music.play();
    await music.play(trackID: other.id, playlistID: playlist);
    expect(waveforms, isEmpty);
    expect(audio.playing, isTrue);
    music.setVisualizationVisible(true);
    music.setVisualizationVisible(true);
    expect(waveforms, hasLength(1));
    expect(music.state.library.trackID, other.id);
    expect(audio.playing, isTrue);
  });

  for (final fromTrack in [false, true]) {
    test(
      'После открытия Play продолжает с сохранённой позиции ($fromTrack)',
      () async {
        expect(music.state.position, 4);
        expect(music.state.playing, isFalse);
        if (fromTrack) {
          await music.play(trackID: track.id, playlistID: playlist);
        } else {
          await music.play();
        }
        expect(music.state.error, isNull);
        expect(audio.playbackPositions, [const Duration(seconds: 4)]);
        expect(music.state.position, 4);
      },
    );
  }

  test(
    'Пауза сохраняет позицию; смена трека или плейлиста сбрасывает её',
    () async {
      await music.play();
      await music.seek(6);
      await music.pause();
      await music.play(trackID: track.id, playlistID: playlist);
      expect(audio.playbackPositions.last, const Duration(seconds: 6));
      expect(audio.loads, hasLength(1));

      await music.play(trackID: other.id, playlistID: playlist);
      expect(audio.playbackPositions.last, Duration.zero);
      expect(music.state.library.trackID, other.id);

      await music.accept([other], newPlaylistName: 'Другой список');
      final otherPlaylist = music.state.library.selectedID!;
      await music.seek(3);
      await music.play(trackID: other.id, playlistID: otherPlaylist);
      expect(audio.playbackPositions.last, Duration.zero);
      expect(music.state.library.playingID, otherPlaylist);
      expect(music.state.error, isNull);
    },
  );
}
