import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walone/core/storage.dart';
import 'package:walone/features/atmosphere/data/atmosphere_audio.dart';
import 'package:walone/features/atmosphere/domain/atmosphere.dart';
import 'package:walone/features/atmosphere/presentation/atmosphere_cubit.dart';
import 'package:walone/features/music/domain/music.dart';
import 'package:walone/features/music/presentation/music_cubit.dart';
import 'package:walone/features/music/data/music_repository.dart';
import 'package:walone/features/keyboard/presentation/keyboard_cubit.dart';
import 'package:walone/features/statistics/data/statistics_database.dart';
import 'package:walone/features/statistics/domain/activity.dart';
import 'package:walone/features/statistics/presentation/statistics_cubit.dart';

import 'media_fakes.dart';

class _MusicFeed extends MusicCubit {
  _MusicFeed(super.repository);
  void update(MusicState value) => emit(value);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Фактическое воспроизведение, нулевая громкость и общая пауза', () {
    final library = MusicLibrary(
      playlists: [
        MusicPlaylist(id: 'playing', name: 'Играет'),
        MusicPlaylist(id: 'selected', name: 'Выбран'),
      ],
      playingID: 'playing',
      selectedID: 'selected',
    );
    final playing = MusicState(library: library, playing: true);
    final mix = AtmosphereMix(
      layers: {'rain': const SoundLayer(enabled: true)},
    );
    final atmosphere = AtmosphereState(
      mix: mix,
      running: true,
      selectedID: 'a',
    );
    expect(
      playbackActivity(playing, atmosphere),
      const PlaybackActivity(playlistId: 'playing', atmosphereId: 'a'),
    );
    expect(
      playbackActivity(
        playing,
        AtmosphereState(mix: mix, running: true, paused: true),
      ).audible,
      isFalse,
    );
    expect(
      playbackActivity(
        playing,
        AtmosphereState(mix: mix, running: true, master: 0),
      ).audible,
      isFalse,
    );
    expect(
      playbackActivity(
        MusicState(library: library.copyWith(volume: 0), playing: true),
        AtmosphereState(mix: mix, running: true, backgroundVolume: 0),
      ).audible,
      isFalse,
    );
    expect(
      playbackActivity(
        MusicState(library: library, playing: false),
        AtmosphereState(),
      ).audible,
      isFalse,
    );
    expect(
      playbackActivity(
        MusicState(library: library, playing: true, loading: true),
        AtmosphereState(),
      ).audible,
      isFalse,
    );
    expect(
      playbackActivity(
        MusicState(library: library),
        AtmosphereState(
          running: true,
          mix: AtmosphereMix(
            layers: {'rain': const SoundLayer(enabled: true, volume: 0)},
          ),
        ),
      ).audible,
      isFalse,
    );
  });

  test('Одновременные каналы не удваивают время; полночь разделяет дни', () {
    final activity = ActivityAccumulator();
    activity.record(
      DateTime(2026, 10, 18, 23, 59, 58),
      DateTime(2026, 10, 19, 0, 0, 3),
      const PlaybackActivity(playlistId: 'p', atmosphereId: 'a'),
      12,
    );
    expect(activity.days['2026-10-18']!.listeningMs, 2000);
    final today = activity.days['2026-10-19']!;
    expect(today.listeningMs, 3000);
    expect(today.musicMs, 3000);
    expect(today.atmosphereMs, 3000);
    expect(today.sources[('music', 'p')], 3000);
    expect(today.keys, 12);
  });

  test(
    'Серия сохраняется до конца сегодняшнего дня и использует прошлые цели',
    () {
      ActivityDay day(int date, int minutes, int goal) => ActivityDay(
        goalFocus: false,
        focusGoalMinutes: 60,
        focusMs: 0,
        pomodoroMs: 0,
        stopwatchMs: 0,
        day: dayKey(DateTime(2026, 10, date)),
        listeningMs: minutes * 60000,
        musicMs: minutes * 60000,
        atmosphereMs: 0,
        keyPresses: 0,
        goalMinutes: goal,
      );
      final days = [
        day(14, 30, 30),
        day(15, 30, 30),
        day(17, 15, 15),
        day(18, 15, 15),
        day(19, 5, 30),
      ];
      expect(activityStreaks(days, DateTime(2026, 10, 19)), (
        current: 2,
        best: 2,
      ));
      expect(activityStreaks(days, DateTime(2026, 10, 20)), (
        current: 0,
        best: 2,
      ));
      days[4] = day(19, 30, 30);
      expect(activityStreaks(days, DateTime(2026, 10, 19)), (
        current: 3,
        best: 3,
      ));
    },
  );

  group('SQLite', () {
    late StatisticsDatabase db;
    setUp(() => db = StatisticsDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('Итоги суммируются, рейтинги фильтруются, переименование сохраняет историю', () async {
      final preferences = await db.preferences();
      final pending = ActivityAccumulator();
      pending.record(
        DateTime(2026, 9, 1),
        DateTime(2026, 9, 1, 0, 1),
        const PlaybackActivity(playlistId: 'old'),
        50,
      );
      pending.record(
        DateTime(2026, 10, 19),
        DateTime(2026, 10, 19, 0, 2),
        const PlaybackActivity(playlistId: 'p', atmosphereId: 'rain'),
        100,
      );
      await db.record(pending.days, preferences, {
        ('music', 'old'): 'Архив',
        ('music', 'p'): 'Первое имя',
        ('atmosphere', 'rain'): 'Дождь',
      });
      await db.record(
        {'2026-10-19': ActivityIncrement()..keys = 7},
        preferences,
        {('music', 'p'): 'Новое имя'},
      );
      final today = (await db.days()).last;
      expect(today.listeningMs, 120000);
      expect(today.keyPresses, 107);
      final ranks = await db.rankings('2026-10-13', '2026-10-19');
      expect(ranks.map((r) => r.name), containsAll(['Новое имя', 'Дождь']));
      expect(ranks.any((r) => r.id == 'old'), isFalse);
      expect(
        (await db.rankings(null, '2026-10-19')).any((r) => r.id == 'old'),
        isTrue,
      );
      expect((await db.rankings(null, '2026-09-30')).single.name, 'Архив');
    });

    test(
      'Изменение целей затрагивает сегодня, очистка сохраняет настройки',
      () async {
        final preferences = await db.preferences();
        await db.record(
          {
            '2026-10-18': ActivityIncrement()..listeningMs = 1800000,
            '2026-10-19': ActivityIncrement()..listeningMs = 600000,
          },
          preferences,
          {},
        );
        await db.savePreferences(
          preferences.copyWith(
            goalMinutes: 10,
            keyGoal: const Value(500),
            collecting: false,
          ),
          '2026-10-19',
        );
        final days = await db.days();
        expect(days.first.goalMinutes, 30);
        expect(days.last.goalMinutes, 10);
        expect(days.first.keyGoal, isNull);
        expect(days.last.keyGoal, 500);
        await db.clearHistory();
        expect(await db.days(), isEmpty);
        expect((await db.preferences()).goalMinutes, 10);
        expect((await db.preferences()).collecting, isFalse);
      },
    );
  });

  test(
    'Файловая база сохраняется после закрытия и повторного открытия',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'walone-statistics-',
      );
      final file = File('${directory.path}/statistics.sqlite');
      final db = StatisticsDatabase(NativeDatabase(file));
      final preferences = await db.preferences();
      await db.record(
        {'2026-10-19': ActivityIncrement()..keys = 42},
        preferences,
        {},
      );
      await db.savePreferences(
        preferences.copyWith(goalFocus: true, focusGoalMinutes: 15),
        '2026-10-19',
      );
      await db.close();
      final reopened = StatisticsDatabase(NativeDatabase(file));
      expect((await reopened.days()).single.keyPresses, 42);
      expect((await reopened.preferences()).goalMetric, DailyGoalMetric.focus);
      expect((await reopened.preferences()).focusGoalMinutes, 15);
      expect((await reopened.days()).single.goalMetric, DailyGoalMetric.focus);
      expect(reopened.schemaVersion, 3);
      await reopened.close();
      await directory.delete(recursive: true);
    },
  );

  test(
    'Быстрая пауза не теряется, пока нативный счётчик отвечает на запуск',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'walone-statistics-feed-',
      );
      final music = _MusicFeed(
        MusicRepository(
          Directory('${root.path}/Music'),
          audioFactory: FakeAudio.new,
        ),
      );
      final keyboard = KeyboardCubit(FakeKeyboard());
      final atmosphere = AtmosphereCubit(
        store: JsonStore(File('${root.path}/atmosphere.json')),
        audio: AtmosphereAudio(factory: FakeAudio.new),
        music: music,
        keyboard: keyboard,
        keyboardEnvironment: (_, _) async {},
        lifecycle: const Stream.empty(),
      );
      Completer<void>? gate;
      final activations = <bool>[];
      final statistics = StatisticsCubit(
        StatisticsDatabase(NativeDatabase.memory()),
        syncKeys: (active) async {
          await gate?.future;
          activations.add(active);
          return 0;
        },
      );
      try {
        await statistics.initialize();
        final library = MusicLibrary(
          playlists: [MusicPlaylist(id: 'p', name: 'Плейлист')],
          playingID: 'p',
        );
        music.update(MusicState(library: library));
        statistics.attach(music, atmosphere);
        await statistics.tick();
        gate = Completer<void>();
        music.update(MusicState(library: library, playing: true));
        await Future<void>.delayed(Duration.zero);
        music.update(MusicState(library: library, playing: false));
        await Future<void>.delayed(Duration.zero);
        gate.complete();
        gate = null;
        await statistics.tick();
        expect(activations, contains(true));
        expect(activations.last, isFalse);
      } finally {
        if (gate != null && !gate.isCompleted) gate.complete();
        gate = null;
        await statistics.close();
        await atmosphere.close();
        await music.close();
        await keyboard.close();
        await root.delete(recursive: true);
      }
    },
  );

  group('Сбор активности', () {
    late StatisticsCubit cubit;
    late DateTime now;
    var monotonic = 0;
    var counter = 0;
    var active = false;

    void advance(int milliseconds, {int keys = 0}) {
      now = now.add(Duration(milliseconds: milliseconds));
      monotonic += milliseconds;
      if (active) counter += keys;
    }

    setUp(() async {
      now = DateTime(2026, 10, 19, 12);
      monotonic = 0;
      counter = 0;
      active = false;
      cubit = StatisticsCubit(
        StatisticsDatabase(NativeDatabase.memory()),
        clock: () => now,
        monotonicMilliseconds: () => monotonic,
        syncKeys: (enabled) async {
          active = enabled;
          return counter;
        },
      );
      await cubit.initialize();
    });
    tearDown(() => cubit.close());

    test('Нажатия учитываются только при прослушивании; выключение сохраняет историю', () async {
      advance(1000, keys: 100);
      await cubit.setActivity(
        const PlaybackActivity(playlistId: 'p'),
        names: {('music', 'p'): 'Плейлист'},
      );
      advance(3000, keys: 8);
      await cubit.configure(collecting: false);
      expect(active, isFalse);
      advance(3000, keys: 100);
      await cubit.configure(collecting: true);
      advance(2000, keys: 4);
      await cubit.setActivity(const PlaybackActivity());
      advance(2000, keys: 100);
      await cubit.setActivity(const PlaybackActivity());
      expect(cubit.state.days.single.listeningMs, 5000);
      expect(cubit.state.days.single.keyPresses, 12);
      expect(cubit.state.rankings.single.milliseconds, 5000);
    });

    test('Сон и перевод часов не превращаются в прослушивание', () async {
      await cubit.setActivity(
        const PlaybackActivity(atmosphereId: 'a'),
        names: {('atmosphere', 'a'): 'Атмосфера'},
      );
      advance(2000);
      await cubit.tick();
      advance(3600000);
      await cubit.tick();
      now = now.add(const Duration(hours: 2));
      await cubit.tick();
      advance(1000);
      await cubit.setActivity(const PlaybackActivity());
      expect(cubit.state.days.single.listeningMs, 3000);
    });

    test(
      'Смена плейлиста сохраняет отдельное время и не удваивает каналы',
      () async {
        await cubit.setActivity(
          const PlaybackActivity(playlistId: 'p', atmosphereId: 'a'),
          names: {
            ('music', 'p'): 'Первый',
            ('music', 'q'): 'Второй',
            ('atmosphere', 'a'): 'Атмосфера',
          },
        );
        advance(2000);
        await cubit.setActivity(
          const PlaybackActivity(playlistId: 'q', atmosphereId: 'a'),
        );
        advance(3000);
        await cubit.setActivity(const PlaybackActivity());
        final day = cubit.state.days.single;
        expect(day.listeningMs, 5000);
        expect(day.musicMs, 5000);
        expect(day.atmosphereMs, 5000);
        expect(cubit.state.rankings.first.milliseconds, 5000);
        expect(
          cubit.state.rankings.where((r) => r.id == 'p').single.milliseconds,
          2000,
        );
        await cubit.clearHistory();
        expect(cubit.state.days, isEmpty);
        expect(cubit.state.rankings, isEmpty);
        expect(cubit.state.preferences!.goalMinutes, 30);
      },
    );
  });
}
