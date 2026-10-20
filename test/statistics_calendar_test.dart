import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walone/core/widgets.dart';
import 'package:walone/features/statistics/data/statistics_database.dart';
import 'package:walone/features/statistics/presentation/statistics_cubit.dart';
import 'package:walone/features/statistics/presentation/statistics_page.dart';

void main() {
  testWidgets(
    'Календарь показывает сегодня после повторного открытия статистики',
    (tester) async {
      tester.view.physicalSize = const Size(700, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final cubit = StatisticsCubit(
        StatisticsDatabase(NativeDatabase.memory()),
        clock: () => DateTime(2026, 10, 19, 12),
        syncKeys: (_) async => 0,
      );
      await cubit.initialize();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        final closing = cubit.close();
        await tester.pump(const Duration(seconds: 1));
        await closing;
      });
      final bucket = PageStorageBucket();
      Future<void> open(bool visible) async {
        await tester.pumpWidget(
          BlocProvider.value(
            value: cubit,
            child: MaterialApp(
              builder: (_, child) => WaloneGlassHost(child: child!),
              home: PageStorage(
                bucket: bucket,
                child: visible
                    ? const StatisticsPage()
                    : const SizedBox.shrink(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      void expectTodayVisible() {
        final calendar = find.descendant(
          of: find.byType(ActivityCalendar),
          matching: find.byType(SingleChildScrollView),
        );
        final today = find.bySemanticsLabel(RegExp(r'^19\.10\.2026:'));
        final viewport = tester.getRect(calendar);
        final cell = tester.getRect(today);
        expect(cell.left, greaterThanOrEqualTo(viewport.left));
        expect(cell.right, lessThanOrEqualTo(viewport.right));
      }

      await open(true);
      expectTodayVisible();
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(400);
      await tester.pumpAndSettle();
      await open(false);
      await open(true);
      expectTodayVisible();
      expect(tester.takeException(), isNull);
    },
  );
}
