import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

enum TimerMode { pomodoro, stopwatch }

enum PomodoroPhase { work, rest }

class TimerInterval {
  const TimerInterval(
    this.start,
    this.end, {
    required this.pomodoro,
    required this.stopwatch,
  });
  final DateTime start;
  final DateTime end;
  final bool pomodoro;
  final bool stopwatch;
}

String timerTime(Duration value) {
  final seconds = value.inSeconds.clamp(0, 999999999);
  return [
    seconds ~/ 3600,
    seconds ~/ 60 % 60,
    seconds % 60,
  ].map((part) => part.toString().padLeft(2, '0')).join(':');
}

class TimerSession {
  const TimerSession({
    this.elapsed = Duration.zero,
    this.running = false,
    this.phase = 0,
    this.finished = false,
  });
  final Duration elapsed;
  final bool running;
  final int phase;
  final bool finished;
}

class TimerState {
  const TimerState({
    this.mode = TimerMode.pomodoro,
    this.pomodoro = const TimerSession(),
    this.stopwatch = const TimerSession(),
    this.workMinutes = 25,
    this.restMinutes = 5,
    this.repeats = 2,
    this.showInTray = true,
  });
  final TimerMode mode;
  final TimerSession pomodoro;
  final TimerSession stopwatch;
  final int workMinutes;
  final int restMinutes;
  final int repeats;
  final bool showInTray;
  TimerSession get current => mode == TimerMode.pomodoro ? pomodoro : stopwatch;
  bool get resting => pomodoro.phase.isOdd;
  Duration get phaseDuration =>
      Duration(minutes: resting ? restMinutes : workMinutes);
  Duration get remaining =>
      pomodoro.finished ? Duration.zero : phaseDuration - pomodoro.elapsed;
  String get label => mode == TimerMode.stopwatch
      ? 'Секундомер'
      : pomodoro.finished
      ? 'Помодоро завершён'
      : resting
      ? 'Отдых'
      : 'Рабочая сессия';
  String get time => timerTime(
    mode == TimerMode.stopwatch
        ? stopwatch.elapsed
        : Duration(seconds: (remaining.inMilliseconds / 1000).ceil()),
  );
  String get trayTitle =>
      showInTray &&
          (current.running ||
              current.elapsed > Duration.zero ||
              current.finished ||
              current.phase > 0)
      ? '$label · $time${current.running || current.finished ? '' : ' · пауза'}'
      : '';

  TimerState copyWith({
    TimerMode? mode,
    TimerSession? pomodoro,
    TimerSession? stopwatch,
    int? workMinutes,
    int? restMinutes,
    int? repeats,
    bool? showInTray,
  }) => TimerState(
    mode: mode ?? this.mode,
    pomodoro: pomodoro ?? this.pomodoro,
    stopwatch: stopwatch ?? this.stopwatch,
    workMinutes: workMinutes ?? this.workMinutes,
    restMinutes: restMinutes ?? this.restMinutes,
    repeats: repeats ?? this.repeats,
    showInTray: showInTray ?? this.showInTray,
  );
}

class TimerCubit extends Cubit<TimerState> {
  TimerCubit({DateTime Function()? now, this.onPhaseComplete})
    : _now = now ?? DateTime.now,
      super(const TimerState()) {
    _lastTick = _now();
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) => tick());
  }
  final DateTime Function() _now;
  final void Function(PomodoroPhase phase)? onPhaseComplete;
  late DateTime _lastTick;
  late final Timer _ticker;
  final _intervals = StreamController<TimerInterval>.broadcast(sync: true);
  Stream<TimerInterval> get intervals => _intervals.stream;

  void _recordIntervals(DateTime start, DateTime end) {
    var cursor = start;
    var phase = state.pomodoro.phase;
    var elapsed = state.pomodoro.elapsed;
    while (state.pomodoro.running &&
        phase < state.repeats * 2 &&
        cursor.isBefore(end)) {
      final duration = Duration(
        minutes: phase.isEven ? state.workMinutes : state.restMinutes,
      );
      final boundary = cursor.add(duration - elapsed);
      final stop = boundary.isBefore(end) ? boundary : end;
      if (phase.isEven || state.stopwatch.running) {
        _intervals.add(
          TimerInterval(
            cursor,
            stop,
            pomodoro: phase.isEven,
            stopwatch: state.stopwatch.running,
          ),
        );
      }
      cursor = stop;
      if (stop.isBefore(boundary)) return;
      phase++;
      elapsed = Duration.zero;
    }
    if (state.stopwatch.running && cursor.isBefore(end)) {
      _intervals.add(
        TimerInterval(cursor, end, pomodoro: false, stopwatch: true),
      );
    }
  }

  // Считаем прошедшее время, а не тики: скрытие окна и сон не теряют секунды.
  void tick() {
    final now = _now();
    final start = _lastTick;
    final delta = now.difference(_lastTick);
    _lastTick = now;
    if (delta <= Duration.zero || isClosed) return;
    _recordIntervals(start, now);
    var focus = state.pomodoro;
    var watch = state.stopwatch;
    var changedPhase = false;
    if (focus.running) {
      var elapsed = focus.elapsed + delta;
      var phase = focus.phase;
      while (phase < state.repeats * 2) {
        final duration = Duration(
          minutes: phase.isEven ? state.workMinutes : state.restMinutes,
        );
        if (elapsed < duration) break;
        elapsed -= duration;
        phase++;
        changedPhase = true;
      }
      final finished = phase == state.repeats * 2;
      focus = TimerSession(
        elapsed: finished ? Duration.zero : elapsed,
        phase: phase,
        running: !finished,
        finished: finished,
      );
    }
    if (watch.running) {
      watch = TimerSession(elapsed: watch.elapsed + delta, running: true);
    }
    if (state.pomodoro.running || state.stopwatch.running) {
      emit(state.copyWith(pomodoro: focus, stopwatch: watch));
    }
    if (changedPhase) {
      onPhaseComplete?.call(
        focus.phase.isOdd ? PomodoroPhase.work : PomodoroPhase.rest,
      );
    }
  }

  void selectMode(TimerMode mode) {
    tick();
    emit(state.copyWith(mode: mode));
  }

  void setShowInTray(bool value) => emit(state.copyWith(showInTray: value));
  void configure({int? workMinutes, int? restMinutes, int? repeats}) {
    if (state.pomodoro.running ||
        state.pomodoro.elapsed > Duration.zero ||
        state.pomodoro.phase > 0) {
      return;
    }
    emit(
      state.copyWith(
        workMinutes: workMinutes?.clamp(1, 180),
        restMinutes: restMinutes?.clamp(1, 60),
        repeats: repeats?.clamp(1, 12),
      ),
    );
  }

  void _setCurrent(TimerSession session) => emit(
    state.mode == TimerMode.pomodoro
        ? state.copyWith(pomodoro: session)
        : state.copyWith(stopwatch: session),
  );
  void toggle() {
    tick();
    final current = state.current;
    _setCurrent(
      TimerSession(
        elapsed: current.finished ? Duration.zero : current.elapsed,
        running: !current.running,
        phase: current.finished ? 0 : current.phase,
      ),
    );
  }

  void reset() {
    tick();
    _setCurrent(const TimerSession());
  }

  void skip() {
    tick();
    if (state.mode != TimerMode.pomodoro || state.pomodoro.finished) return;
    final phase = state.pomodoro.phase + 1;
    final finished = phase >= state.repeats * 2;
    _setCurrent(
      TimerSession(
        phase: phase,
        running: state.pomodoro.running && !finished,
        finished: finished,
      ),
    );
  }

  @override
  Future<void> close() async {
    tick();
    _ticker.cancel();
    await _intervals.close();
    await super.close();
  }
}
