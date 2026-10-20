import 'package:flutter_test/flutter_test.dart';
import 'package:walone/features/timer/presentation/timer_cubit.dart';

void main() {
  late DateTime now;
  late TimerCubit timer;
  final alarms = <PomodoroPhase>[];
  setUp(() {
    now = DateTime(2026);
    alarms.clear();
    timer = TimerCubit(now: () => now, onPhaseComplete: alarms.add);
  });
  tearDown(() => timer.close());
  void advance(Duration duration) {
    now = now.add(duration);
    timer.tick();
  }

  test('Работа, отдых, повторы и завершение после задержанного тика', () {
    timer.configure(workMinutes: 1, restMinutes: 1, repeats: 2);
    timer.toggle();
    advance(const Duration(seconds: 60));
    expect(timer.state.resting, isTrue);
    expect(timer.state.time, '00:01:00');
    expect(alarms, [PomodoroPhase.work]);
    advance(const Duration(seconds: 75));
    expect(timer.state.pomodoro.phase, 2);
    expect(timer.state.time, '00:00:45');
    expect(alarms, [PomodoroPhase.work, PomodoroPhase.rest]);
    advance(const Duration(hours: 8));
    expect(timer.state.pomodoro.finished, isTrue);
    expect(timer.state.pomodoro.running, isFalse);
    expect(timer.state.time, '00:00:00');
    expect(alarms, [
      PomodoroPhase.work,
      PomodoroPhase.rest,
      PomodoroPhase.rest,
    ]);
    advance(const Duration(seconds: 1));
    expect(alarms, hasLength(3));
    timer.toggle();
    expect(timer.state.pomodoro.phase, 0);
    expect(timer.state.pomodoro.running, isTrue);
  });

  test(
    'Сигналы работы и отдыха звучат при каждом завершении, включая последнее',
    () {
      timer.configure(workMinutes: 1, restMinutes: 1, repeats: 2);
      timer.toggle();
      for (var phase = 0; phase < 4; phase++) {
        advance(const Duration(minutes: 1));
      }
      expect(alarms, [
        PomodoroPhase.work,
        PomodoroPhase.rest,
        PomodoroPhase.work,
        PomodoroPhase.rest,
      ]);
      expect(timer.state.pomodoro.finished, isTrue);
    },
  );

  test('Пауза исключает время ожидания, режимы работают независимо', () {
    timer.toggle();
    advance(const Duration(seconds: 5));
    timer.selectMode(TimerMode.stopwatch);
    timer.toggle();
    advance(const Duration(seconds: 10));
    timer.toggle();
    advance(const Duration(seconds: 20));
    expect(timer.state.stopwatch.elapsed.inSeconds, 10);
    expect(timer.state.pomodoro.elapsed.inSeconds, 35);
    timer.toggle();
    advance(const Duration(seconds: 2));
    expect(timer.state.time, '00:00:12');
    timer.reset();
    expect(timer.state.time, '00:00:00');
    expect(timer.state.pomodoro.running, isTrue);
    expect(timer.state.trayTitle, isEmpty);
    expect(alarms, isEmpty);
  });

  test('Настройки ограничены; сброс, пропуск и отображение в трее', () {
    timer.configure(workMinutes: 0, restMinutes: 999, repeats: 0);
    expect(timer.state.workMinutes, 1);
    expect(timer.state.restMinutes, 60);
    expect(timer.state.repeats, 1);
    timer.toggle();
    timer.configure(workMinutes: 50);
    expect(timer.state.workMinutes, 1);
    timer.skip();
    expect(timer.state.resting, isTrue);
    expect(timer.state.trayTitle, contains('Отдых'));
    timer.toggle();
    expect(timer.state.trayTitle, contains('пауза'));
    timer.setShowInTray(false);
    expect(timer.state.trayTitle, isEmpty);
    timer.skip();
    expect(timer.state.pomodoro.finished, isTrue);
    timer.reset();
    timer.configure(workMinutes: 30);
    expect(timer.state.workMinutes, 30);
    expect(timerTime(const Duration(hours: 123, seconds: 9)), '123:00:09');
    expect(alarms, isEmpty);
  });
}
