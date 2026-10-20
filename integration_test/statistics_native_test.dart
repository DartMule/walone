import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:walone/features/statistics/data/statistics_database.dart';
import 'package:walone/features/statistics/domain/activity.dart';
import 'package:walone/features/statistics/presentation/statistics_cubit.dart';
import 'package:walone/features/statistics/presentation/statistics_page.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Цели, прогресс и серия восстанавливаются из SQLite', (
    tester,
  ) async {
    final directory = await Directory.systemTemp.createTemp('walone-goals-');
    final file = File('${directory.path}/statistics.sqlite');
    final now = DateTime(2026, 10, 19, 12);
    StatisticsCubit? cubit;
    try {
      final db = StatisticsDatabase.open(file);
      final preferences = await db.preferences();
      await db.record(
        {
          '2026-10-17': ActivityIncrement()..listeningMs = 1800000,
          '2026-10-18': ActivityIncrement()..listeningMs = 1800000,
          '2026-10-19': ActivityIncrement()
            ..listeningMs = 360000
            ..focusMs = 1200000,
        },
        preferences,
        {},
      );
      cubit = StatisticsCubit(db, clock: () => now, syncKeys: (_) async => 0);
      await cubit.initialize();
      await cubit.configure(
        goalMinutes: 5,
        focusGoalMinutes: 25,
        goalMetric: DailyGoalMetric.focus,
      );

      Future<void> restartAndCheck(
        DailyGoalMetric metric,
        String progress,
        int streak,
      ) async {
        await tester.pumpWidget(const SizedBox.shrink());
        await cubit!.close();
        cubit = StatisticsCubit(
          StatisticsDatabase.open(file),
          clock: () => now,
          syncKeys: (_) async => 0,
        );
        await cubit!.initialize();
        expect(cubit!.state.error, isNull);
        final saved = cubit!.state.preferences!;
        expect(saved.goalMetric, metric);
        expect(saved.goalMinutes, 5);
        expect(saved.focusGoalMinutes, 25);
        expect(activityStreaks(cubit!.state.days, now), (
          current: streak,
          best: streak,
        ));
        for (final day in cubit!.state.days.take(2)) {
          expect(day.goalMetric, DailyGoalMetric.listening);
          expect(day.goalMinutes, 30);
          expect(day.goalCompleted, isTrue);
        }
        await tester.pumpWidget(
          BlocProvider.value(
            value: cubit!,
            child: const MaterialApp(home: Scaffold(body: StatisticsPage())),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(progress), findsOneWidget);
        expect(find.text('$streak дн.'), findsNWidgets(2));
        expect(tester.takeException(), isNull);
      }

      await restartAndCheck(DailyGoalMetric.focus, '20 мин / 25 мин', 2);
      await cubit!.configure(goalMetric: DailyGoalMetric.listening);
      await tester.pumpAndSettle();
      expect(find.text('6 мин / 5 мин'), findsOneWidget);
      expect(find.text('3 дн.'), findsNWidgets(2));
      await restartAndCheck(DailyGoalMetric.listening, '6 мин / 5 мин', 3);
      await cubit!.configure(goalMetric: DailyGoalMetric.focus);
      await tester.pumpAndSettle();
      expect(find.text('20 мин / 25 мин'), findsOneWidget);
      expect(find.text('2 дн.'), findsNWidgets(2));
      await restartAndCheck(DailyGoalMetric.focus, '20 мин / 25 мин', 2);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await cubit?.close();
      await directory.delete(recursive: true);
    }
  });

  testWidgets('Нативный счётчик и SQLite доступны в собранном приложении', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: Text('Проверка статистики'))),
      ),
    );
    const channel = MethodChannel('dev.soyjanks.walone/keyboard');
    final directory = await Directory.systemTemp.createTemp(
      'walone-native-statistics-',
    );
    final file = File('${directory.path}/statistics.sqlite');
    StatisticsDatabase? db;
    try {
      await channel.invokeMethod<void>('initialize');
      final before = await channel.invokeMethod<int>('statistics', true);
      expect(before, isNonNegative);
      final after = await channel.invokeMethod<int>('statistics', false);
      expect(after, greaterThanOrEqualTo(before!));
      await expectLater(
        channel.invokeMethod<int>('statistics', 'invalid'),
        throwsA(isA<PlatformException>()),
      );
      db = StatisticsDatabase.open(file);
      final preferences = await db.preferences();
      await db.record(
        {
          '2026-10-19': ActivityIncrement()
            ..keys = 17
            ..focusMs = 3000
            ..pomodoroMs = 2000
            ..stopwatchMs = 1000,
        },
        preferences,
        {},
      );
      await db.savePreferences(
        preferences.copyWith(goalFocus: true, focusGoalMinutes: 25),
        '2026-10-19',
      );
      await db.close();
      db = StatisticsDatabase.open(file);
      expect((await db.days()).single.keyPresses, 17);
      expect((await db.days()).single.focusMs, 3000);
      expect((await db.days()).single.pomodoroMs, 2000);
      expect((await db.days()).single.stopwatchMs, 1000);
      expect((await db.preferences()).goalMinutes, 30);
      expect((await db.preferences()).goalMetric, DailyGoalMetric.focus);
      expect((await db.preferences()).focusGoalMinutes, 25);
      expect((await db.days()).single.goalMetric, DailyGoalMetric.focus);
      expect((await db.days()).single.focusGoalMinutes, 25);
      expect(await file.exists(), isTrue);
    } finally {
      await db?.close();
      await channel.invokeMethod<int>('statistics', false);
      await channel.invokeMethod<void>('dispose');
      await directory.delete(recursive: true);
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
