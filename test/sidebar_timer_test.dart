import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walone/core/widgets.dart';
import 'package:walone/features/timer/presentation/timer_readout.dart';
import 'package:walone/features/timer/presentation/timer_cubit.dart';
import 'package:walone/workspace.dart';

Finder readout(String value) => find.byWidgetPredicate(
  (widget) => widget is TimerReadout && widget.value == value,
);

void main() {
  testWidgets('Шапка анимирует активные отсчёты и открывает таймеры', (
    tester,
  ) async {
    var now = DateTime(2026);
    final timer = TimerCubit(now: () => now);
    var selected = 0;
    var reduced = false;
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        darkTheme: ThemeData(brightness: Brightness.dark),
        builder: (_, child) => WaloneGlassHost(child: child!),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(disableAnimations: reduced),
                child: WorkspaceSidebar(
                  selected: selected,
                  timer: timer,
                  onSelected: (value) => setState(() => selected = value),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final preview = find.byKey(const ValueKey('sidebar-timer-preview'));
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    Color? iconColor(IconData icon) =>
        tester.widget<Icon>(find.byIcon(icon)).color;
    Color? timeColor(String time) =>
        tester.widget<TimerReadout>(readout(time)).style.color;
    expect(find.text('Walone'), findsOneWidget);
    timer.toggle();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Walone'), findsOneWidget);
    expect(preview, findsOneWidget);
    final opacity = tester
        .widget<FadeTransition>(
          find
              .ancestor(of: preview, matching: find.byType(FadeTransition))
              .first,
        )
        .opacity
        .value;
    expect(opacity, greaterThan(0));
    expect(opacity, lessThan(1));
    await tester.pumpAndSettle();
    expect(find.text('Walone'), findsNothing);
    expect(readout('00:25:00'), findsOneWidget);
    now = now.add(const Duration(seconds: 3));
    timer.tick();
    await tester.pumpAndSettle();
    expect(readout('00:24:57'), findsOneWidget);
    timer.setShowInTray(false);
    await tester.pumpAndSettle();
    expect(preview, findsOneWidget);

    // Даже при выбранном секундомере нажатие открывает работающий помодоро.
    timer.selectMode(TimerMode.stopwatch);
    await tester.pumpAndSettle();
    await tester.tap(preview);
    await tester.pumpAndSettle();
    expect(selected, 4);
    expect(timer.state.mode, TimerMode.pomodoro);
    expect(find.text('Walone'), findsOneWidget);
    expect(preview, findsNothing);
    update(() => selected = 1);
    await tester.pumpAndSettle();
    expect(preview, findsOneWidget);

    // Выбор незапущенного режима не прячет уже работающий помодоро.
    timer.selectMode(TimerMode.stopwatch);
    await tester.pumpAndSettle();
    expect(readout('00:24:57'), findsOneWidget);
    timer.toggle();
    now = now.add(const Duration(seconds: 2));
    timer.tick();
    await tester.pumpAndSettle();
    expect(readout('00:24:55'), findsOneWidget);
    expect(readout('00:00:02'), findsOneWidget);
    expect(find.byIcon(Icons.work_outline_rounded), findsOneWidget);
    // При двух отсчётах у каждого свой переход, независимо от выбранного режима.
    timer.selectMode(TimerMode.pomodoro);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey(('sidebar-timer', TimerMode.stopwatch))),
    );
    await tester.pumpAndSettle();
    expect(selected, 4);
    expect(timer.state.mode, TimerMode.stopwatch);
    update(() => selected = 1);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey(('sidebar-timer', TimerMode.pomodoro))),
    );
    await tester.pumpAndSettle();
    expect(selected, 4);
    expect(timer.state.mode, TimerMode.pomodoro);
    update(() => selected = 1);
    timer.selectMode(TimerMode.stopwatch);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    timer.toggle();
    await tester.pumpAndSettle();
    expect(readout('00:00:02'), findsNothing);
    expect(readout('00:24:55'), findsOneWidget);

    timer.selectMode(TimerMode.pomodoro);
    timer.skip();
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.local_cafe_outlined), findsOneWidget);
    expect(find.byIcon(Icons.work_outline_rounded), findsNothing);
    expect(iconColor(Icons.local_cafe_outlined), const Color(0xFF2E7D32));
    expect(timeColor('00:05:00'), const Color(0xFF2E7D32));
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await tester.pumpAndSettle();
    expect(iconColor(Icons.local_cafe_outlined), const Color(0xFF66BB6A));
    expect(timeColor('00:05:00'), const Color(0xFF66BB6A));
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await tester.pumpAndSettle();
    timer.skip();
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.work_outline_rounded), findsOneWidget);
    expect(find.byIcon(Icons.local_cafe_outlined), findsNothing);
    final workColor = Theme.of(tester.element(preview)).colorScheme.primary;
    expect(iconColor(Icons.work_outline_rounded), workColor);
    expect(timeColor('00:25:00'), workColor);

    update(() => reduced = true);
    await tester.pumpAndSettle();
    timer.selectMode(TimerMode.pomodoro);
    timer.toggle();
    await tester.pumpAndSettle();
    expect(find.text('Walone'), findsOneWidget);
    expect(preview, findsNothing);
    expect(
      tester
          .widgetList<AnimatedSwitcher>(find.byType(AnimatedSwitcher))
          .every((switcher) => switcher.duration == Duration.zero),
      isTrue,
    );
    timer.toggle();
    await tester.pumpAndSettle();
    expect(preview, findsOneWidget);
    expect(find.text('Walone'), findsNothing);
    timer.reset();
    await tester.pumpAndSettle();
    expect(find.text('Walone'), findsOneWidget);
    timer.configure(workMinutes: 1, restMinutes: 1, repeats: 1);
    timer.toggle();
    now = now.add(const Duration(minutes: 2));
    timer.tick();
    await tester.pumpAndSettle();
    expect(timer.state.pomodoro.finished, isTrue);
    expect(find.text('Walone'), findsOneWidget);
    expect(preview, findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await timer.close();
  });
}
