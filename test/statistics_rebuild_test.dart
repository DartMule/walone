import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walone/core/widgets.dart';
import 'package:walone/features/statistics/data/statistics_database.dart';
import 'package:walone/features/statistics/domain/activity.dart';
import 'package:walone/features/statistics/presentation/statistics_cubit.dart';
import 'package:walone/features/statistics/presentation/statistics_page.dart';

void main() {
  testWidgets('Длинный рейтинг создаёт только видимые строки при прокрутке', (
    tester,
  ) async {
    final now = DateTime(2026, 10, 19, 12);
    final db = StatisticsDatabase(NativeDatabase.memory());
    final preferences = await db.preferences();
    final increment = ActivityIncrement()..listeningMs = 1000000;
    final names = <(String, String), String>{};
    for (var i = 0; i < 1000; i++) {
      increment.sources[('music', 'p$i')] = 1000;
      names[('music', 'p$i')] = 'Плейлист $i';
    }
    await db.record({dayKey(now): increment}, preferences, names);
    final cubit = StatisticsCubit(
      db,
      clock: () => now,
      syncKeys: (_) async => 0,
    );
    await cubit.initialize();
    addTearDown(() async {
      debugOnRebuildDirtyWidget = null;
      await tester.pumpWidget(const SizedBox.shrink());
      final closing = cubit.close();
      await tester.pump(const Duration(seconds: 1));
      await closing;
    });
    var rows = 0;
    debugOnRebuildDirtyWidget = (element, _) {
      if (element.widget is SectionCard && element.widget.key != null) rows++;
    };
    await tester.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: MaterialApp(
          builder: (_, child) => WaloneGlassHost(child: child!),
          home: const StatisticsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .jumpTo(1600);
    await tester.pumpAndSettle();
    debugPrint('Ranking scroll: $rows built rows out of 1000');
    expect(cubit.state.rankings, hasLength(1000));
    expect(rows, inInclusiveRange(1, 35));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Прокрутка и смена периода не перестраивают неизменившийся календарь',
    (tester) async {
      final now = DateTime(2026, 10, 19, 12);
      final cubit = StatisticsCubit(
        StatisticsDatabase(NativeDatabase.memory()),
        clock: () => now,
        syncKeys: (_) async => 0,
      );
      await cubit.initialize();
      addTearDown(() async {
        debugOnRebuildDirtyWidget = null;
        await tester.pumpWidget(const SizedBox.shrink());
        final closing = cubit.close();
        await tester.pump(const Duration(seconds: 1));
        await closing;
      });
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        BlocProvider.value(
          value: cubit,
          child: MaterialApp(
            builder: (_, child) => WaloneGlassHost(child: child!),
            home: const ColoredBox(
              color: Color(0xFFF8F6F3),
              child: StatisticsPage(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      var calendarBuilds = 0;
      var tooltipBuilds = 0;
      debugOnRebuildDirtyWidget = (element, builtOnce) {
        if (element.widget is ActivityCalendar) calendarBuilds++;
        if (element.widget is Tooltip) tooltipBuilds++;
      };
      final stopwatch = Stopwatch()..start();
      await tester.drag(
        find.byType(CustomScrollView).first,
        const Offset(0, -120),
      );
      await tester.pumpAndSettle();
      await cubit.selectPeriod(StatisticsPeriod.month);
      await tester.pumpAndSettle();
      stopwatch.stop();
      debugPrint(
        'Statistics scroll/update: ${stopwatch.elapsedMilliseconds} ms, '
        '$calendarBuilds calendar builds, $tooltipBuilds tooltip builds',
      );
      expect(
        calendarBuilds,
        0,
        reason: 'Период рейтингов не меняет годовой календарь',
      );
      expect(
        tooltipBuilds,
        lessThan(30),
        reason: 'Не создавать заново 365 интерактивных дней',
      );
      calendarBuilds = 0;
      tooltipBuilds = 0;
      await cubit.database.record(
        {dayKey(now): ActivityIncrement()..listeningMs = 1000},
        cubit.state.preferences!,
        {},
      );
      await cubit.selectPeriod(StatisticsPeriod.month);
      await tester.pumpAndSettle();
      expect(calendarBuilds, 0);
      expect(tooltipBuilds, 1, reason: 'Обновляется только сегодняшний день');
      tooltipBuilds = 0;
      await cubit.configure(
        goalMetric: DailyGoalMetric.focus,
        focusGoalMinutes: 15,
      );
      await tester.pumpAndSettle();
      expect(
        tooltipBuilds,
        1,
        reason: 'Смена цели не перестраивает прошлые дни',
      );
      tooltipBuilds = 0;
      await tester.tap(find.bySemanticsLabel(RegExp(r'^18\.10\.2026:')));
      await tester.pumpAndSettle();
      expect(
        tooltipBuilds,
        0,
        reason: 'Выбор дня меняет выделение и детали, сохраняя сетку',
      );
      expect(tester.takeException(), isNull);
    },
  );
}
