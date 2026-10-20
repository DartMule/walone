import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walone/features/statistics/data/statistics_database.dart';
import 'package:walone/features/statistics/domain/activity.dart';
import 'package:walone/features/statistics/presentation/statistics_cubit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Выбор метрики меняет цель и серию сегодня, сохраняя прошлые цели',
    () async {
      var now = DateTime(2026, 10, 19, 12);
      final db = StatisticsDatabase(NativeDatabase.memory());
      final preferences = await db.preferences();
      await db.record(
        {
          '2026-10-18': ActivityIncrement()..listeningMs = 1800000,
          '2026-10-19': ActivityIncrement()..focusMs = 1200000,
        },
        preferences,
        {},
      );
      final cubit = StatisticsCubit(
        db,
        clock: () => now,
        syncKeys: (_) async => 0,
      );
      try {
        await cubit.initialize();
        expect(activityStreaks(cubit.state.days, now), (current: 1, best: 1));
        await cubit.configure(
          goalMetric: DailyGoalMetric.focus,
          focusGoalMinutes: 15,
        );
        expect(cubit.state.preferences!.goalMinutes, 30);
        expect(cubit.state.preferences!.dailyGoalMinutes, 15);
        expect(cubit.state.days.first.goalMetric, DailyGoalMetric.listening);
        expect(cubit.state.days.last.goalCompleted, isTrue);
        expect(activityStreaks(cubit.state.days, now), (current: 2, best: 2));
        await cubit.configure(focusGoalMinutes: 25);
        expect(activityStreaks(cubit.state.days, now).current, 1);
        await cubit.configure(focusGoalMinutes: 15, goalMinutes: 5);
        expect(activityStreaks(cubit.state.days, now).current, 2);
        await cubit.configure(goalMetric: DailyGoalMetric.listening);
        expect(cubit.state.preferences!.dailyGoalMinutes, 5);
        expect(cubit.state.preferences!.focusGoalMinutes, 15);
        expect(activityStreaks(cubit.state.days, now).current, 1);
        await cubit.configure(goalMetric: DailyGoalMetric.focus);
        now = DateTime(2026, 10, 20, 12);
        await cubit.configure(
          goalMetric: DailyGoalMetric.listening,
          focusGoalMinutes: 45,
        );
        expect(cubit.state.days.last.goalMetric, DailyGoalMetric.focus);
        expect(cubit.state.days.last.focusGoalMinutes, 15);
        expect(cubit.state.days.last.goalCompleted, isTrue);
        expect(activityStreaks(cubit.state.days, now).current, 2);
        await db.record(
          {'2026-10-20': ActivityIncrement()..listeningMs = 300000},
          cubit.state.preferences!,
          {},
        );
        await cubit.selectPeriod(StatisticsPeriod.all);
        expect(activityStreaks(cubit.state.days, now), (current: 3, best: 3));
        expect(cubit.state.days.last.goalMetric, DailyGoalMetric.listening);
        expect(cubit.state.days.last.focusGoalMinutes, 45);
        await cubit.clearHistory();
        expect(cubit.state.days, isEmpty);
        expect(cubit.state.preferences!.goalMetric, DailyGoalMetric.listening);
        expect(cubit.state.preferences!.focusGoalMinutes, 45);
      } finally {
        await cubit.close();
      }
    },
  );

  test(
    'Концентрация достигает цели на границе минуты независимо от прослушивания',
    () async {
      final db = StatisticsDatabase(NativeDatabase.memory());
      try {
        final preferences = (await db.preferences()).copyWith(
          goalFocus: true,
          focusGoalMinutes: 15,
        );
        await db.record(
          {
            '2026-10-19': ActivityIncrement()
              ..listeningMs = 3600000
              ..focusMs = 899999,
          },
          preferences,
          {},
        );
        expect((await db.days()).single.goalCompleted, isFalse);
        await db.record(
          {'2026-10-19': ActivityIncrement()..focusMs = 1},
          preferences,
          {},
        );
        expect((await db.days()).single.goalCompleted, isTrue);
      } finally {
        await db.close();
      }
    },
  );

  test(
    'Неверная цель по концентрации не изменяет сохранённые настройки',
    () async {
      final cubit = StatisticsCubit(
        StatisticsDatabase(NativeDatabase.memory()),
        syncKeys: (_) async => 0,
      );
      try {
        await cubit.initialize();
        for (final invalid in [0, 1441]) {
          await cubit.configure(
            goalMetric: DailyGoalMetric.focus,
            focusGoalMinutes: invalid,
            goalMinutes: 10,
          );
          expect(cubit.state.error, contains('от 1 до 1440 минут'));
          expect(
            cubit.state.preferences!.goalMetric,
            DailyGoalMetric.listening,
          );
          expect(cubit.state.preferences!.goalMinutes, 30);
          expect(cubit.state.preferences!.focusGoalMinutes, 60);
        }
        await cubit.configure(
          goalMetric: DailyGoalMetric.focus,
          focusGoalMinutes: 1,
        );
        expect(cubit.state.error, isNull);
        expect(cubit.state.preferences!.dailyGoalMinutes, 1);
      } finally {
        await cubit.close();
      }
    },
  );
}
