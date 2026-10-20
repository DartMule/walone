import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/widgets.dart';
import 'timer_cubit.dart';
import 'timer_colors.dart';
import 'timer_readout.dart';

class TimerPage extends StatelessWidget {
  const TimerPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    appBar: AppBar(title: const Text('Таймеры')),
    body: BlocBuilder<TimerCubit, TimerState>(
      buildWhen: (previous, next) =>
          (
            previous.mode,
            previous.time,
            previous.label,
            previous.current.running,
            previous.current.finished,
            previous.current.phase,
            previous.workMinutes,
            previous.restMinutes,
            previous.repeats,
            previous.showInTray,
          ) !=
          (
            next.mode,
            next.time,
            next.label,
            next.current.running,
            next.current.finished,
            next.current.phase,
            next.workMinutes,
            next.restMinutes,
            next.repeats,
            next.showInTray,
          ),
      builder: (context, state) {
        final cubit = context.read<TimerCubit>();
        final focus = state.mode == TimerMode.pomodoro;
        final current = state.current;
        final scheme = Theme.of(context).colorScheme;
        final phaseColor = pomodoroColor(
          scheme,
          resting: focus && state.resting,
        );
        final motion = MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 240);
        final configurable =
            !state.pomodoro.running &&
            state.pomodoro.elapsed == Duration.zero &&
            state.pomodoro.phase == 0;
        return TimerColorTransition(
          color: phaseColor,
          builder: (context, phaseColor) => ListView(
            padding: EdgeInsets.fromLTRB(
              WaloneDesign.pagePadding,
              WaloneDesign.cardPadding,
              WaloneDesign.pagePadding,
              WaloneDesign.pagePadding + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              Center(
                child: SegmentedButton<TimerMode>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: TimerMode.pomodoro,
                      icon: Icon(Icons.local_cafe_outlined),
                      label: Text('Помодоро'),
                    ),
                    ButtonSegment(
                      value: TimerMode.stopwatch,
                      icon: Icon(Icons.timer_outlined),
                      label: Text('Секундомер'),
                    ),
                  ],
                  selected: {state.mode},
                  onSelectionChanged: (value) => cubit.selectMode(value.single),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 390),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const Positioned.fill(
                          child: GlassPanel(
                            radius: 220,
                            child: SizedBox.expand(),
                          ),
                        ),
                        const Positioned.fill(child: _TimerProgress()),
                        Padding(
                          padding: const EdgeInsets.all(34),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (focus)
                                Text(
                                  '${state.pomodoro.finished ? state.repeats : state.pomodoro.phase ~/ 2 + 1} / ${state.repeats}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                              const SizedBox(height: 8),
                              AnimatedSwitcher(
                                duration: motion,
                                child: Text(
                                  state.label,
                                  key: ValueKey(state.label),
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(
                                        color: focus ? phaseColor : null,
                                      ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Semantics(
                                label: '${state.label}: ${state.time}',
                                child: ExcludeSemantics(
                                  child: FittedBox(
                                    child: TimerReadout(
                                      value: state.time,
                                      style: TextStyle(
                                        fontSize: 54,
                                        fontWeight: FontWeight.w500,
                                        color: focus
                                            ? phaseColor
                                            : scheme.onSurface,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                    tooltip: 'Сбросить',
                                    onPressed: cubit.reset,
                                    icon: const Icon(Icons.stop_rounded),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton.filled(
                                    style: focus
                                        ? IconButton.styleFrom(
                                            backgroundColor: phaseColor,
                                            foregroundColor:
                                                ThemeData.estimateBrightnessForColor(
                                                      phaseColor,
                                                    ) ==
                                                    Brightness.dark
                                                ? Colors.white
                                                : Colors.black,
                                          )
                                        : null,
                                    iconSize: 36,
                                    padding: const EdgeInsets.all(12),
                                    tooltip: current.running
                                        ? 'Пауза'
                                        : 'Запустить',
                                    onPressed: cubit.toggle,
                                    icon: AnimatedSwitcher(
                                      duration: motion,
                                      transitionBuilder: (child, animation) =>
                                          ScaleTransition(
                                            scale: animation,
                                            child: FadeTransition(
                                              opacity: animation,
                                              child: child,
                                            ),
                                          ),
                                      child: Icon(
                                        current.running
                                            ? Icons.pause_rounded
                                            : Icons.play_arrow_rounded,
                                        key: ValueKey(current.running),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (focus)
                                    IconButton(
                                      tooltip: 'Следующий этап',
                                      onPressed: current.finished
                                          ? null
                                          : cubit.skip,
                                      icon: const Icon(Icons.skip_next_rounded),
                                    )
                                  else
                                    const SizedBox(width: 40),
                                ],
                              ),
                              _TimerReveal(
                                child:
                                    !current.running &&
                                        current.elapsed > Duration.zero
                                    ? const Padding(
                                        padding: EdgeInsets.only(top: 8),
                                        child: Text('На паузе'),
                                      )
                                    : const SizedBox(width: double.infinity),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _TimerReveal(
                child: !focus
                    ? const SizedBox(width: double.infinity)
                    : Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 560),
                          child: SectionCard(
                            child: Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 20,
                              runSpacing: 12,
                              children: [
                                _Stepper(
                                  label: 'Работа, мин',
                                  value: state.workMinutes,
                                  min: 1,
                                  max: 180,
                                  onChanged: configurable
                                      ? (v) => cubit.configure(workMinutes: v)
                                      : null,
                                ),
                                _Stepper(
                                  label: 'Отдых, мин',
                                  value: state.restMinutes,
                                  min: 1,
                                  max: 60,
                                  onChanged: configurable
                                      ? (v) => cubit.configure(restMinutes: v)
                                      : null,
                                ),
                                _Stepper(
                                  label: 'Повторы',
                                  value: state.repeats,
                                  min: 1,
                                  max: 12,
                                  onChanged: configurable
                                      ? (v) => cubit.configure(repeats: v)
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 12),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Показывать в трее'),
                    subtitle: const Text(
                      'Время выбранного режима и управление без окна',
                    ),
                    value: state.showInTray,
                    onChanged: cubit.setShowInTray,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });
  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int>? onChanged;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(label, style: Theme.of(context).textTheme.labelLarge),
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Уменьшить: $label',
            onPressed: onChanged != null && value > min
                ? () => onChanged!(value - 1)
                : null,
            icon: const Icon(Icons.remove_rounded, size: 18),
          ),
          SizedBox(
            width: 32,
            child: AnimatedSwitcher(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 180),
              child: Text(
                '$value',
                key: ValueKey(value),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Увеличить: $label',
            onPressed: onChanged != null && value < max
                ? () => onChanged!(value + 1)
                : null,
            icon: const Icon(Icons.add_rounded, size: 18),
          ),
        ],
      ),
    ],
  );
}

class _TimerProgress extends StatelessWidget {
  const _TimerProgress();
  @override
  Widget build(BuildContext context) =>
      BlocSelector<
        TimerCubit,
        TimerState,
        (TimerMode, Duration, Duration?, bool, bool, int, bool)
      >(
        selector: (s) => (
          s.mode,
          s.current.elapsed,
          s.mode == TimerMode.pomodoro ? s.phaseDuration : null,
          s.current.running,
          s.current.finished,
          s.current.phase,
          s.resting,
        ),
        builder: (context, value) {
          final (mode, elapsed, duration, running, finished, phase, resting) =
              value;
          final scheme = Theme.of(context).colorScheme;
          return TimerColorTransition(
            color: mode == TimerMode.pomodoro
                ? pomodoroColor(scheme, resting: resting)
                : scheme.primary,
            builder: (context, color) => _TimerRing(
              key: ValueKey((mode, phase)),
              elapsed: elapsed,
              duration: duration,
              running: running,
              finished: finished,
              color: color,
            ),
          );
        },
      );
}

class _TimerRing extends StatefulWidget {
  const _TimerRing({
    super.key,
    required this.elapsed,
    required this.duration,
    required this.running,
    required this.finished,
    required this.color,
  });
  final Duration elapsed;
  final Duration? duration;
  final bool running;
  final bool finished;
  final Color color;

  @override
  State<_TimerRing> createState() => _TimerRingState();
}

class _TimerRingState extends State<_TimerRing>
    with SingleTickerProviderStateMixin {
  late final _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  void _syncMotion() {
    if (widget.running &&
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled) {
      if (!_breath.isAnimating) _breath.repeat(reverse: true);
    } else {
      _breath.stop();
      _breath.value = 0;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion();
  }

  @override
  void didUpdateWidget(covariant _TimerRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncMotion();
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    final turns =
        widget.elapsed.inMicroseconds / Duration.microsecondsPerMinute;
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _breath,
                builder: (context, child) => Transform.scale(
                  key: const ValueKey('timer-breath'),
                  scale: 1 + Curves.easeInOut.transform(_breath.value) * 0.018,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: widget.color.withValues(
                          alpha: widget.running ? 0.22 : 0,
                        ),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: widget.color.withValues(
                            alpha: widget.running
                                ? 0.08 + _breath.value * 0.06
                                : 0,
                          ),
                          blurRadius: 20,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: turns, end: turns),
                  duration: reduced || !widget.running
                      ? Duration.zero
                      : const Duration(milliseconds: 200),
                  builder: (context, value, child) => Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: widget.finished
                            ? 1
                            : widget.duration == null
                            ? value % 1
                            : (value *
                                      Duration.microsecondsPerMinute /
                                      widget.duration!.inMicroseconds)
                                  .clamp(0, 1),
                        strokeWidth: 4,
                        strokeCap: StrokeCap.round,
                        backgroundColor: widget.color.withValues(alpha: 0.12),
                        color: widget.color,
                      ),
                      if (!reduced &&
                          (widget.running || widget.elapsed > Duration.zero))
                        Transform.rotate(
                          angle: value * math.pi * 2,
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: Container(
                              key: const ValueKey('timer-orbit'),
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: widget.color,
                                boxShadow: [
                                  BoxShadow(
                                    color: widget.color.withValues(alpha: 0.5),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimerReveal extends StatelessWidget {
  const _TimerReveal({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context) ||
        !TickerMode.valuesOf(context).enabled) {
      return child;
    }
    return AnimatedSize(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: child,
    );
  }
}
