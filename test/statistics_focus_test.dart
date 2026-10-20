import 'dart:io';

import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walone/core/storage.dart';
import 'package:walone/features/atmosphere/data/atmosphere_audio.dart';
import 'package:walone/features/atmosphere/presentation/atmosphere_cubit.dart';
import 'package:walone/features/keyboard/presentation/keyboard_cubit.dart';
import 'package:walone/features/music/data/music_repository.dart';
import 'package:walone/features/music/presentation/music_cubit.dart';
import 'package:walone/features/statistics/data/statistics_database.dart';
import 'package:walone/features/statistics/domain/activity.dart';
import 'package:walone/features/statistics/presentation/statistics_cubit.dart';
import 'package:walone/features/timer/presentation/timer_cubit.dart';

import 'media_fakes.dart';
import 'statistics_migrations/schema.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Миграция v1 → v3 сохраняет историю и настройки, новые показатели равны нулю', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final schema = await verifier.schemaAt(1);
    schema.rawDatabase.execute(
      "INSERT INTO activity_days (day, listening_ms, music_ms, atmosphere_ms, key_presses, goal_minutes, key_goal) "
      "VALUES ('2026-10-18', 1800000, 1800000, 0, 250, 30, 500)",
    );
    schema.rawDatabase.execute(
      'INSERT INTO statistics_preferences (id, collecting, goal_minutes, key_goal, calendar_keys) '
      'VALUES (1, 0, 45, 500, 1)',
    );
    schema.rawDatabase.execute(
      "INSERT INTO listening_sources (kind, source_id, name) VALUES ('music', 'p', 'Мой плейлист')",
    );
    schema.rawDatabase.execute(
      "INSERT INTO source_days (day, kind, source_id, listening_ms) VALUES ('2026-10-18', 'music', 'p', 1800000)",
    );
    final database = StatisticsDatabase(schema.newConnection());
    try {
      await verifier.migrateAndValidate(database, 3);
      final day = (await database.days()).single;
      expect(day.listeningMs, 1800000);
      expect(day.keyPresses, 250);
      expect(day.focusMs, 0);
      expect(day.pomodoroMs, 0);
      expect(day.stopwatchMs, 0);
      final preferences = await database.preferences();
      expect(preferences.collecting, isFalse);
      expect(preferences.goalMinutes, 45);
      expect(preferences.goalMetric, DailyGoalMetric.listening);
      expect(preferences.focusGoalMinutes, 60);
      expect(day.goalMetric, DailyGoalMetric.listening);
      expect(day.goalCompleted, isTrue);
      expect(preferences.calendarMetric, CalendarMetric.keys);
      expect(
        (await database.rankings(null, '2026-10-19')).single.name,
        'Мой плейлист',
      );
    } finally {
      await database.close();
    }
  });

  test(
    'Миграция v2 → v3 сохраняет концентрацию, серию и выбор календаря',
    () async {
      final verifier = SchemaVerifier(GeneratedHelper());
      final schema = await verifier.schemaAt(2);
      schema.rawDatabase.execute(
        "INSERT INTO activity_days (day, listening_ms, focus_ms, pomodoro_ms, stopwatch_ms, goal_minutes) "
        "VALUES ('2026-10-18', 1800000, 3600000, 2400000, 1200000, 30)",
      );
      schema.rawDatabase.execute(
        'INSERT INTO statistics_preferences (id, goal_minutes, calendar_focus) VALUES (1, 45, 1)',
      );
      final database = StatisticsDatabase(schema.newConnection());
      try {
        await verifier.migrateAndValidate(database, 3);
        final day = (await database.days()).single;
        final preferences = await database.preferences();
        expect(day.focusMs, 3600000);
        expect(day.pomodoroMs, 2400000);
        expect(day.stopwatchMs, 1200000);
        expect(day.focusGoalMinutes, 60);
        expect(day.goalMetric, DailyGoalMetric.listening);
        expect(day.goalCompleted, isTrue);
        expect(preferences.goalMinutes, 45);
        expect(preferences.goalMetric, DailyGoalMetric.listening);
        expect(preferences.focusGoalMinutes, 60);
        expect(preferences.calendarMetric, CalendarMetric.focus);
      } finally {
        await database.close();
      }
    },
  );

  test(
    'Таймеры: рабочие фазы, паузы, наложение, полночь, выключение и очистка',
    () async {
      final root = await Directory.systemTemp.createTemp('walone-focus-');
      final start = DateTime(2026, 10, 18, 23, 59, 50);
      var now = start;
      final timer = TimerCubit(now: () => now);
      final music = MusicCubit(
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
      final statistics = StatisticsCubit(
        StatisticsDatabase(NativeDatabase.memory()),
        clock: () => now,
        monotonicMilliseconds: () => now.difference(start).inMilliseconds,
        syncKeys: (_) async => 0,
      );
      Future<void> advance(int seconds) async {
        now = now.add(Duration(seconds: seconds));
        timer.tick();
        await statistics.selectPeriod(StatisticsPeriod.all);
      }

      int total(int Function(ActivityDay) field) =>
          statistics.state.days.fold(0, (sum, day) => sum + field(day));
      try {
        await statistics.initialize();
        statistics.attach(music, atmosphere, timer: timer);
        await statistics.tick();
        timer.configure(workMinutes: 1, restMinutes: 1, repeats: 2);
        timer.toggle();
        await advance(20);
        expect(statistics.state.days.first.focusMs, 10000);
        expect(statistics.state.days.last.focusMs, 10000);
        timer.toggle();
        await advance(20);
        expect(total((d) => d.focusMs), 20000);
        timer.selectMode(TimerMode.stopwatch);
        timer.toggle();
        await advance(10);
        timer.selectMode(TimerMode.pomodoro);
        timer.toggle();
        await advance(50);
        expect(timer.state.resting, isTrue);
        expect(total((d) => d.focusMs), 80000);
        expect(total((d) => d.pomodoroMs), 60000);
        expect(total((d) => d.stopwatchMs), 60000);
        timer.selectMode(TimerMode.stopwatch);
        timer.toggle();
        await advance(50);
        await advance(5);
        expect(total((d) => d.focusMs), 85000);
        expect(total((d) => d.pomodoroMs), 65000);
        expect(total((d) => d.listeningMs), 0);
        expect(activityStreaks(statistics.state.days, now).current, 0);
        timer.selectMode(TimerMode.pomodoro);
        timer.reset();
        expect(total((d) => d.focusMs), 85000);
        timer.selectMode(TimerMode.stopwatch);
        timer.toggle();
        now = now.add(const Duration(milliseconds: 500));
        await statistics.configure(collecting: false);
        await advance(15);
        expect(total((d) => d.focusMs), 85500);
        await statistics.clearHistory();
        expect(statistics.state.days, isEmpty);
        await statistics.configure(
          collecting: true,
          calendarMetric: CalendarMetric.focus,
        );
        await advance(2);
        expect(statistics.state.days.single.focusMs, 2000);
        expect(
          statistics.state.preferences!.calendarMetric,
          CalendarMetric.focus,
        );
        expect(statistics.state.days.single.keyPresses, 0);
      } finally {
        await timer.close();
        await statistics.close();
        await atmosphere.close();
        await music.close();
        await keyboard.close();
        await root.delete(recursive: true);
      }
    },
  );
}
