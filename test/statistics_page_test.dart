import 'dart:io';
import 'dart:ui' show ImageByteFormat;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walone/core/widgets.dart';
import 'package:walone/features/statistics/data/statistics_database.dart';
import 'package:walone/features/statistics/domain/activity.dart';
import 'package:walone/features/statistics/presentation/statistics_cubit.dart';
import 'package:walone/features/statistics/presentation/statistics_page.dart';

void main() {
  testWidgets(
    'Календарь, цели и очистка истории работают в широком и узком окне',
    (tester) async {
      const capture = bool.fromEnvironment('CAPTURE_STATISTICS');
      late StatisticsDatabase db;
      final now = DateTime(2026, 10, 19, 12);
      late StatisticsCubit cubit;
      {
        db = StatisticsDatabase(NativeDatabase.memory());
        cubit = StatisticsCubit(db, clock: () => now, syncKeys: (_) async => 0);
        final preferences = await db.preferences();
        final pending = ActivityAccumulator();
        for (var i = 0; i < 365; i++) {
          if (i % 5 == 0) continue;
          final date = DateTime(now.year, now.month, now.day - i);
          pending.record(
            date,
            date.add(Duration(minutes: (i * 7) % 70 + 5)),
            PlaybackActivity(
              playlistId: i.isEven ? 'focus' : 'evening',
              atmosphereId: 'rain',
            ),
            i * 13 % 1800,
          );
        }
        pending.record(
          now,
          now.add(const Duration(minutes: 18)),
          const PlaybackActivity(playlistId: 'focus', atmosphereId: 'rain'),
          720,
        );
        pending.recordFocus(
          now,
          now.add(const Duration(minutes: 18)),
          pomodoro: true,
          stopwatch: true,
        );
        await db.record(pending.days, preferences, {
          ('music', 'focus'): 'Глубокая концентрация',
          ('music', 'evening'): 'Тихий вечер',
          ('atmosphere', 'rain'): 'Дождь за окном',
        });
        await cubit.initialize();
        if (capture) {
          await tester.runAsync(() async {
            final font = FontLoader('Preview')
              ..addFont(
                Future.value(
                  ByteData.sublistView(
                    await File(
                      '.fvm/flutter_sdk/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf',
                    ).readAsBytes(),
                  ),
                ),
              );
            await font.load();
            final icons = FontLoader('MaterialIcons')
              ..addFont(
                Future.value(
                  ByteData.sublistView(
                    await File(
                      '.fvm/flutter_sdk/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
                    ).readAsBytes(),
                  ),
                ),
              );
            await icons.load();
          });
        }
      }
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        final closing = cubit.close();
        await tester.pump(const Duration(seconds: 1));
        await closing;
      });
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final previewKey = GlobalKey();
      await tester.pumpWidget(
        BlocProvider.value(
          value: cubit,
          child: MaterialApp(
            builder: (_, child) => WaloneGlassHost(child: child!),
            theme: ThemeData(
              useMaterial3: true,
              fontFamily: capture ? 'Preview' : null,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF946000),
              ),
            ),
            home: RepaintBoundary(
              key: previewKey,
              child: const ColoredBox(
                color: Color(0xFFF8F6F3),
                child: StatisticsPage(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Календарь активности'), findsOneWidget);
      expect(find.text('18 мин / 30 мин'), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (capture) {
        await tester.runAsync(() async {
          final image =
              await (previewKey.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = await image.toByteData(format: ImageByteFormat.png);
          await File('/tmp/walone-statistics-wide.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      await tester.tap(find.widgetWithText(ChoiceChip, 'Нажатия'));
      await tester.runAsync(() async {
        await Future<void>.delayed(Duration.zero);
      });
      await tester.pumpAndSettle();
      expect(cubit.state.preferences!.calendarKeys, isTrue);
      final selectedDate = find.bySemanticsLabel(RegExp(r'^19\.10\.2026:'));
      await tester.tap(selectedDate);
      await tester.pumpAndSettle();
      expect(find.text('Нажатия: 720'), findsOneWidget);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Концентрация'));
      await tester.pumpAndSettle();
      expect(cubit.state.preferences!.calendarMetric, CalendarMetric.focus);
      expect(find.text('Концентрация: 18 мин'), findsOneWidget);
      expect(find.text('Помидоро: 18 мин'), findsOneWidget);
      expect(find.text('Секундомер: 18 мин'), findsOneWidget);

      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Настроить статистику'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, '15');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.tap(find.text('Дополнительная цель по нажатиям'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).last, '500');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.tap(find.text('Сохранить'));
      await tester.runAsync(() async {
        await Future<void>.delayed(Duration.zero);
      });
      await tester.pumpAndSettle();
      expect(cubit.state.preferences!.goalMinutes, 15);
      expect(cubit.state.preferences!.keyGoal, 500);
      expect(find.text('18 мин / 15 мин'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byTooltip('Настроить статистику'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('statistics-goal-metric')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('По концентрации').last);
      await tester.pumpAndSettle();
      final focusGoal = find.byKey(const ValueKey('statistics-focus-goal'));
      await tester.ensureVisible(focusGoal);
      await tester.enterText(focusGoal, '10');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();
      expect(cubit.state.preferences!.goalMetric, DailyGoalMetric.focus);
      expect(cubit.state.preferences!.focusGoalMinutes, 10);
      expect(cubit.state.preferences!.goalMinutes, 15);
      expect(find.text('18 мин / 10 мин'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Цель: Концентрация · 10 мин'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Цель: Концентрация · 10 мин'), findsOneWidget);
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Настроить статистику'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('statistics-listening-goal')),
            )
            .controller!
            .text,
        '15',
      );
      expect(tester.widget<TextFormField>(focusGoal).controller!.text, '10');
      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();

      if (capture) {
        await tester.runAsync(() async {
          final image =
              await (previewKey.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = await image.toByteData(format: ImageByteFormat.png);
          await File('/tmp/walone-statistics-narrow.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      await tester.tap(find.byTooltip('Настроить статистику'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Очистить историю'));
      await tester.tap(find.text('Очистить историю'));
      await tester.pumpAndSettle();
      expect(cubit.state.days, isNotEmpty);
      await tester.tap(find.text('Отмена').last);
      await tester.pumpAndSettle();
      expect(cubit.state.days, isNotEmpty);
      await tester.tap(find.text('Очистить историю'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Удалить'));
      await tester.runAsync(() async {
        await Future<void>.delayed(Duration.zero);
      });
      await tester.pumpAndSettle();
      expect(cubit.state.days, isEmpty);
      expect(cubit.state.preferences!.goalMinutes, 15);
      expect(cubit.state.preferences!.focusGoalMinutes, 10);
      expect(cubit.state.preferences!.goalMetric, DailyGoalMetric.focus);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
