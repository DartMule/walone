import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walone/features/statistics/data/statistics_database.dart';
import 'package:walone/features/statistics/domain/activity.dart';
import 'package:walone/features/statistics/presentation/statistics_cubit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Запись в SQLite обновляет статистику без ручного обновления', () async {
    final db = StatisticsDatabase(NativeDatabase.memory());
    final cubit = StatisticsCubit(
      db,
      clock: () => DateTime(2026, 10, 19, 12),
      syncKeys: (_) async => 0,
    );
    try {
      await cubit.initialize();
      final updated = cubit.stream
          .firstWhere((s) => s.daysByKey['2026-10-19']?.focusMs == 60000)
          .timeout(const Duration(seconds: 2));
      await db.record(
        {'2026-10-19': ActivityIncrement()..focusMs = 60000},
        cubit.state.preferences!,
        {},
      );
      expect((await updated).days.single.focusMs, 60000);

      final configured = cubit.stream
          .firstWhere(
            (s) =>
                s.preferences?.goalFocus == true && s.days.single.goalCompleted,
          )
          .timeout(const Duration(seconds: 2));
      await db.savePreferences(
        cubit.state.preferences!.copyWith(goalFocus: true, focusGoalMinutes: 1),
        '2026-10-19',
      );
      expect(
        activityStreaks((await configured).days, cubit.state.now).current,
        1,
      );

      final cleared = cubit.stream
          .firstWhere((s) => s.days.isEmpty)
          .timeout(const Duration(seconds: 2));
      await db.clearHistory();
      expect((await cleared).days, isEmpty);
    } finally {
      await cubit.close();
    }
  });

  test(
    'Активное прослушивание записывается и отображается каждую секунду',
    () async {
      var now = DateTime(2026, 10, 19, 12);
      var elapsed = 0;
      final db = StatisticsDatabase(NativeDatabase.memory());
      final cubit = StatisticsCubit(
        db,
        clock: () => now,
        monotonicMilliseconds: () => elapsed,
        syncKeys: (_) async => 0,
      );
      try {
        await cubit.initialize();
        await cubit.setActivity(
          const PlaybackActivity(playlistId: 'focus'),
          names: {('music', 'focus'): 'Фокус'},
        );
        for (var i = 1; i <= 3; i++) {
          now = now.add(const Duration(seconds: 1));
          elapsed += 1000;
          await cubit.tick();
          expect((await db.days()).single.listeningMs, i * 1000);
          expect(cubit.state.days.single.listeningMs, i * 1000);
          expect(cubit.state.rankings.single.milliseconds, i * 1000);
        }
      } finally {
        await cubit.close();
      }
    },
  );
}
