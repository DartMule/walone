import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walone/core/widgets.dart';
import 'package:walone/features/timer/presentation/timer_readout.dart';
import 'package:walone/workspace.dart';
import 'package:walone/features/timer/presentation/timer_cubit.dart';
import 'package:walone/features/timer/presentation/timer_page.dart';

Finder readout(String value) => find.byWidgetPredicate(
  (widget) => widget is TimerReadout && widget.value == value,
);

void main() {
  testWidgets('Таймеры в узком окне: настройки, пауза и смена режима', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(560, 680);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var now = DateTime(2026);
    final timer = TimerCubit(now: () => now);
    await tester.pumpWidget(
      BlocProvider.value(
        value: timer,
        child: MaterialApp(
          builder: (_, child) => WaloneGlassHost(child: child!),
          home: const TimerPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Увеличить: Работа, мин'));
    await tester.pump();
    expect(timer.state.workMinutes, 26);
    await tester.tap(find.byTooltip('Запустить'));
    now = now.add(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 3));
    expect(readout('00:25:57'), findsOneWidget);
    await tester.tap(find.byTooltip('Пауза'));
    await tester.pump();
    expect(find.text('На паузе'), findsOneWidget);
    await tester.tap(find.text('Секундомер').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Запустить'));
    now = now.add(const Duration(seconds: 65));
    await tester.pump(const Duration(seconds: 1));
    expect(readout('00:01:05'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await timer.close();
  });

  testWidgets(
    'Движение останавливается на паузе, вне вкладки и при уменьшении движения',
    (tester) async {
      var now = DateTime(2026);
      var reduced = false;
      var visible = true;
      late StateSetter update;
      final timer = TimerCubit(now: () => now);
      await tester.pumpWidget(
        BlocProvider.value(
          value: timer,
          child: MaterialApp(
            builder: (_, child) => WaloneGlassHost(child: child!),
            home: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(disableAnimations: reduced),
                  child: TickerMode(enabled: visible, child: const TimerPage()),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      double scale() => tester
          .widget<Transform>(find.byKey(const ValueKey('timer-breath')))
          .transform
          .entry(0, 0);
      timer.toggle();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      final initial = scale();
      await tester.pump(const Duration(milliseconds: 600));
      expect(scale(), greaterThan(initial));
      expect(find.byKey(const ValueKey('timer-orbit')), findsOneWidget);

      now = now.add(const Duration(seconds: 1));
      timer.tick();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final middle = tester
          .widget<CircularProgressIndicator>(
            find.byType(CircularProgressIndicator),
          )
          .value!;
      expect(middle, greaterThan(0));
      expect(middle, lessThan(1 / 1500));
      timer.toggle();
      await tester.pumpAndSettle();
      final paused = scale();
      await tester.pump(const Duration(seconds: 1));
      expect(scale(), paused);

      timer.toggle();
      await tester.pump();
      timer.skip();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Отдых'), findsOneWidget);
      expect(tester.takeException(), isNull);
      update(() => reduced = true);
      await tester.pumpAndSettle();
      expect(scale(), 1);
      expect(find.byKey(const ValueKey('timer-orbit')), findsNothing);
      expect(
        tester
            .widgetList<AnimatedSwitcher>(find.byType(AnimatedSwitcher))
            .every((switcher) => switcher.duration == Duration.zero),
        isTrue,
      );
      await tester.pump(const Duration(seconds: 1));
      expect(scale(), 1);
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(timer.state.pomodoro.running, isTrue);

      update(() {
        reduced = false;
        visible = false;
      });
      await tester.pumpAndSettle();
      expect(scale(), 1);
      expect(tester.binding.hasScheduledFrame, isFalse);
      update(() => visible = true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 600));
      expect(scale(), greaterThan(1));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await timer.close();
    },
  );

  for (final brightness in Brightness.values) {
    testWidgets('Цвет этапа совпадает у времени и кольца: ${brightness.name}', (
      tester,
    ) async {
      final timer = TimerCubit(now: () => DateTime(2026));
      const orange = Color(0xFFFF9F0A);
      final green = brightness == Brightness.dark
          ? const Color(0xFF66BB6A)
          : const Color(0xFF2E7D32);
      final scheme = ColorScheme.fromSeed(
        seedColor: orange,
        brightness: brightness,
      ).copyWith(primary: orange);
      await tester.pumpWidget(
        BlocProvider.value(
          value: timer,
          child: MaterialApp(
            theme: ThemeData(colorScheme: scheme),
            builder: (_, child) => WaloneGlassHost(child: child!),
            home: const MediaQuery(
              data: MediaQueryData(disableAnimations: true),
              child: TimerPage(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      void expectColors(String time, Color color) {
        expect(tester.widget<TimerReadout>(readout(time)).style.color, color);
        expect(
          tester
              .widget<CircularProgressIndicator>(
                find.byType(CircularProgressIndicator),
              )
              .color,
          color,
        );
      }

      expectColors('00:25:00', orange);
      timer.toggle();
      timer.skip();
      await tester.pumpAndSettle();
      expectColors('00:05:00', green);
      expect(tester.widget<Text>(find.text('Отдых')).style?.color, green);
      timer.toggle();
      await tester.pumpAndSettle();
      expectColors('00:05:00', green);
      timer.selectMode(TimerMode.stopwatch);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TimerReadout>(readout('00:00:00')).style.color,
        scheme.onSurface,
      );
      timer.selectMode(TimerMode.pomodoro);
      timer.skip();
      await tester.pumpAndSettle();
      expectColors('00:25:00', orange);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await timer.close();
    });
  }

  testWidgets('Цвет плавно и синхронно меняется у кольца, времени и шапки', (
    tester,
  ) async {
    final timer = TimerCubit(now: () => DateTime(2026));
    const orange = Color(0xFFFF9F0A);
    const green = Color(0xFF2E7D32);
    var reduced = false;
    late StateSetter update;
    await tester.pumpWidget(
      BlocProvider.value(
        value: timer,
        child: MaterialApp(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: orange)
                .copyWith(primary: orange),
          ),
          builder: (context, child) => StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(disableAnimations: reduced),
                child: WaloneGlassHost(child: child!),
              );
            },
          ),
          home: Scaffold(
            body: Row(
              children: [
                WorkspaceSidebar(selected: 0, timer: timer, onSelected: (_) {}),
                const Expanded(child: TimerPage()),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    timer.toggle();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 600));
    Color ringColor() => tester
        .widget<CircularProgressIndicator>(
          find.byType(CircularProgressIndicator),
        )
        .color!;
    void expectSynchronized(String time, Color color) {
      expect(ringColor(), color);
      final clocks = tester.widgetList<TimerReadout>(readout(time)).toList();
      expect(clocks, hasLength(2));
      for (final clock in clocks) {
        expect(clock.style.color, color);
      }
    }

    expectSynchronized('00:25:00', orange);
    timer.skip();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 300));
    final middle = ringColor();
    expect(middle, isNot(orange));
    expect(middle, isNot(green));
    expectSynchronized('00:05:00', middle);
    await tester.pump(const Duration(milliseconds: 300));
    expectSynchronized('00:05:00', green);

    timer.skip();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 300));
    expect(ringColor(), isNot(green));
    expect(ringColor(), isNot(orange));
    expectSynchronized('00:25:00', ringColor());
    // Уменьшение движения завершает уже начатый цветовой переход сразу.
    update(() => reduced = true);
    await tester.pumpAndSettle();
    expectSynchronized('00:25:00', orange);
    timer.skip();
    await tester.pumpAndSettle();
    expectSynchronized('00:05:00', green);
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await timer.close();
  });
}
