import 'dart:math' as math;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/widgets.dart';
import '../data/statistics_database.dart';
import '../domain/activity.dart';
import 'statistics_cubit.dart';

String listeningTime(int milliseconds) {
  final seconds = milliseconds ~/ 1000;
  if (seconds < 60) return '$seconds с';
  final minutes = seconds ~/ 60;
  if (minutes < 60) return '$minutes мин';
  return '${minutes ~/ 60} ч ${minutes % 60} мин';
}

String _dateLabel(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

class StatisticsPage extends StatelessWidget {
  const StatisticsPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    appBar: AppBar(
      title: const Text('Статистика'),
      actions: [
        IconButton(
          tooltip: 'Настроить статистику',
          icon: const Icon(Icons.tune_rounded),
          onPressed: () {
            final cubit = context.read<StatisticsCubit>();
            if (cubit.state.preferences == null) return;
            showDialog<void>(
              context: context,
              builder: (_) => BlocProvider.value(
                value: cubit,
                child: const _PreferencesDialog(),
              ),
            );
          },
        ),
      ],
    ),
    body: BlocSelector<StatisticsCubit, StatisticsState, (bool, bool, String?)>(
      selector: (s) => (
        s.loading,
        s.preferences != null,
        s.preferences == null ? s.error : null,
      ),
      builder: (context, value) {
        if (value.$1) return const Center(child: CircularProgressIndicator());
        if (value.$2) return const _StatisticsContent();
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(value.$3 ?? 'Статистика недоступна'),
                TextButton(
                  onPressed: context.read<StatisticsCubit>().initialize,
                  child: const Text('Повторить'),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class _StatisticsContent extends StatelessWidget {
  const _StatisticsContent();
  @override
  Widget build(BuildContext context) => CustomScrollView(
    key: const PageStorageKey('statistics-scroll'),
    slivers: [
      SliverPadding(
        padding: EdgeInsets.fromLTRB(
          WaloneDesign.pagePadding,
          WaloneDesign.cardPadding,
          WaloneDesign.pagePadding,
          WaloneDesign.pagePadding + MediaQuery.paddingOf(context).bottom,
        ),
        sliver: const SliverMainAxisGroup(
          slivers: [
            SliverToBoxAdapter(
              child: SceneBanner(
                title: 'Ваш ритм',
                subtitle: 'Каждый день в своём темпе. Вся история — на этом устройстве.',
                icon: Icons.insights_rounded,
              ),
            ),
            SliverToBoxAdapter(child: _CollectionNotice()),
            SliverToBoxAdapter(child: _StatisticsErrors()),
            SliverToBoxAdapter(child: SizedBox(height: 20)),
            SliverToBoxAdapter(child: _TodayStatistics()),
            SliverToBoxAdapter(child: SizedBox(height: 16)),
            SliverToBoxAdapter(child: ActivityCalendar()),
            SliverToBoxAdapter(child: SizedBox(height: 20)),
            SliverToBoxAdapter(child: _PeriodPicker()),
            SliverToBoxAdapter(child: SizedBox(height: 12)),
            SliverToBoxAdapter(child: _PeriodStatistics()),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'При одновременном воспроизведении общее время считается один раз. '
                  'Концентрация учитывается отдельно от прослушивания; отдых помидоро и паузы исключены.',
                ),
              ),
            ),
            _RankingSliver(kind: 'music', title: 'Любимые плейлисты'),
            _RankingSliver(kind: 'atmosphere', title: 'Любимые атмосферы'),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(top: 16),
                child: Text(
                  'Учитываются музыка и атмосфера с ненулевой громкостью в Walone, '
                  'в том числе в фоне. Паузы и сон исключаются из прослушивания. Нажатия считаются во всей '
                  'системе во время прослушивания; содержимое ввода не сохраняется. '
                  'На macOS нужен «Мониторинг ввода»; защищённые поля недоступны. '
                  'Время концентрации следует отсчёту запущенных таймеров.',
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _CollectionNotice extends StatelessWidget {
  const _CollectionNotice();
  @override
  Widget build(BuildContext context) =>
      BlocSelector<StatisticsCubit, StatisticsState, bool>(
        selector: (s) => s.preferences?.collecting ?? true,
        builder: (context, collecting) => collecting
            ? const SizedBox.shrink()
            : Padding(
                padding: const EdgeInsets.only(top: 12),
                child: SectionCard(
                  child: Row(
                    children: [
                      const Icon(Icons.pause_circle_outline),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Сбор статистики выключен. История сохранена.',
                        ),
                      ),
                      TextButton(
                        onPressed: () => context
                            .read<StatisticsCubit>()
                            .configure(collecting: true),
                        child: const Text('Включить'),
                      ),
                    ],
                  ),
                ),
              ),
      );
}

class _StatisticsErrors extends StatelessWidget {
  const _StatisticsErrors();
  @override
  Widget build(BuildContext context) =>
      BlocSelector<StatisticsCubit, StatisticsState, (String?, String?)>(
        selector: (s) => (s.error, s.keyboardError),
        builder: (context, errors) => Column(
          children: [
            for (final error in [errors.$1, errors.$2])
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: SelectableText(
                    error,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
          ],
        ),
      );
}

class _TodayStatistics extends StatelessWidget {
  const _TodayStatistics();
  @override
  Widget build(BuildContext context) =>
      BlocSelector<
        StatisticsCubit,
        StatisticsState,
        (ActivityDay?, DailyGoalMetric, int, int?, ({int current, int best}))
      >(
        selector: (s) => (
          s.daysByKey[dayKey(s.now)],
          s.preferences?.goalMetric ?? DailyGoalMetric.listening,
          s.preferences?.dailyGoalMinutes ?? 30,
          s.preferences?.keyGoal,
          activityStreaks(s.days, s.now),
        ),
        builder: (context, value) {
          final (today, goalMetric, goalMinutes, keyGoal, streak) = value;
          final progressMs = goalMetric.progressMs(today);
          return SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Сегодня', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                _Goal(
                  title: goalMetric.title,
                  label: '${listeningTime(progressMs)} / $goalMinutes мин',
                  progress: progressMs / (goalMinutes * 60000),
                ),
                if (keyGoal != null) ...[
                  const SizedBox(height: 16),
                  _Goal(
                    title: 'Нажатия клавиш',
                    label: '${today?.keyPresses ?? 0} / $keyGoal',
                    progress: (today?.keyPresses ?? 0) / keyGoal,
                  ),
                ],
                const SizedBox(height: 16),
                Wrap(
                  spacing: 24,
                  runSpacing: 12,
                  children: [
                    _Metric(
                      'Текущая серия',
                      '${streak.current} дн.',
                      Icons.local_fire_department_outlined,
                    ),
                    _Metric(
                      'Лучшая серия',
                      '${streak.best} дн.',
                      Icons.emoji_events_outlined,
                    ),
                    _Metric(
                      'Нажатия сегодня',
                      '${today?.keyPresses ?? 0}',
                      Icons.keyboard_outlined,
                    ),
                    _Metric(
                      'Концентрация',
                      listeningTime(today?.focusMs ?? 0),
                      Icons.psychology_outlined,
                    ),
                    _Metric(
                      'Помидоро',
                      listeningTime(today?.pomodoroMs ?? 0),
                      Icons.timelapse_rounded,
                    ),
                    _Metric(
                      'Секундомер',
                      listeningTime(today?.stopwatchMs ?? 0),
                      Icons.timer_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  progressMs >= goalMinutes * 60000
                      ? 'Цель «${goalMetric.title}» выполнена — серия продолжена.'
                      : 'Серию поддерживает цель «${goalMetric.title}». Сегодня ещё можно успеть.',
                ),
              ],
            ),
          );
        },
      );
}

class _PeriodPicker extends StatelessWidget {
  const _PeriodPicker();
  @override
  Widget build(
    BuildContext context,
  ) => BlocSelector<StatisticsCubit, StatisticsState, StatisticsPeriod>(
    selector: (s) => s.period,
    builder: (context, selected) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final period in StatisticsPeriod.values)
              ChoiceChip(
                label: Text(period.title),
                selected: selected == period,
                onSelected: (_) =>
                    context.read<StatisticsCubit>().selectPeriod(period),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          selected == StatisticsPeriod.all
              ? 'За всю историю'
              : 'Последние ${selected == StatisticsPeriod.week ? 7 : 30} дней, включая сегодня',
        ),
      ],
    ),
  );
}

class _PeriodStatistics extends StatelessWidget {
  const _PeriodStatistics();
  @override
  Widget build(BuildContext context) =>
      BlocSelector<
        StatisticsCubit,
        StatisticsState,
        (List<ActivityDay>, StatisticsPeriod, String)
      >(
        selector: (s) => (s.days, s.period, dayKey(s.now)),
        builder: (context, value) {
          final (days, period, today) = value;
          final since = period.since(DateTime.parse(today));
          var listening = 0, music = 0, atmosphere = 0, keys = 0;
          var focus = 0, pomodoro = 0, stopwatch = 0;
          for (final day in days) {
            if (day.day.compareTo(today) > 0 ||
                (since != null && day.day.compareTo(since) < 0)) {
              continue;
            }
            listening += day.listeningMs;
            music += day.musicMs;
            atmosphere += day.atmosphereMs;
            keys += day.keyPresses;
            focus += day.focusMs;
            pomodoro += day.pomodoroMs;
            stopwatch += day.stopwatchMs;
          }
          return SectionCard(
            child: Wrap(
              spacing: 32,
              runSpacing: 20,
              children: [
                _Metric(
                  'Общее время',
                  listeningTime(listening),
                  Icons.headphones_rounded,
                ),
                _Metric(
                  'Музыка',
                  listeningTime(music),
                  Icons.music_note_outlined,
                ),
                _Metric(
                  'Атмосфера',
                  listeningTime(atmosphere),
                  Icons.waves_rounded,
                ),
                _Metric('Нажатия', '$keys', Icons.keyboard_outlined),
                _Metric(
                  'Концентрация',
                  listeningTime(focus),
                  Icons.psychology_outlined,
                ),
                _Metric(
                  'Помидоро',
                  listeningTime(pomodoro),
                  Icons.timelapse_rounded,
                ),
                _Metric(
                  'Секундомер',
                  listeningTime(stopwatch),
                  Icons.timer_outlined,
                ),
              ],
            ),
          );
        },
      );
}

class _RankingSliver extends StatelessWidget {
  const _RankingSliver({required this.kind, required this.title});
  final String kind;
  final String title;
  @override
  Widget build(
    BuildContext context,
  ) => BlocSelector<StatisticsCubit, StatisticsState, List<ListeningRank>>(
    selector: (s) => s.rankings,
    builder: (context, ranks) {
      final entries = ranks.where((r) => r.kind == kind).toList();
      return SliverMainAxisGroup(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 20, bottom: 12),
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          if (entries.isEmpty)
            const SliverToBoxAdapter(
              child: SectionCard(
                child: Text(
                  'Здесь появятся ваши предпочтения после прослушивания.',
                ),
              ),
            ),
          SliverList.builder(
            itemCount: entries.length,
            itemBuilder: (context, i) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SectionCard(
                key: ValueKey((kind, entries[i].id)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 12,
                      children: [
                        Text('${i + 1}. ${entries[i].name}'),
                        Text(listeningTime(entries[i].milliseconds)),
                      ],
                    ),
                    const SizedBox(height: 5),
                    LinearProgressIndicator(
                      value:
                          entries[i].milliseconds /
                          math.max(1, entries.first.milliseconds),
                      minHeight: 4,
                      color: const Color(0xFF369B68),
                      semanticsLabel:
                          '${entries[i].name}, ${listeningTime(entries[i].milliseconds)}',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

class _Goal extends StatelessWidget {
  const _Goal({
    required this.title,
    required this.label,
    required this.progress,
  });
  final String title;
  final String label;
  final double progress;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Wrap(
        spacing: 12,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          Text(label),
          if (progress >= 1)
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_outline, size: 18),
                SizedBox(width: 6),
                Text('Цель выполнена'),
              ],
            ),
        ],
      ),
      const SizedBox(height: 8),
      LinearProgressIndicator(
        value: progress.clamp(0, 1),
        minHeight: 8,
        borderRadius: BorderRadius.circular(8),
        color: const Color(0xFF369B68),
        semanticsLabel: title,
      ),
    ],
  );
}

class _Metric extends StatelessWidget {
  const _Metric(this.title, this.value, this.icon);
  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 170,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(title)),
          ],
        ),
        const SizedBox(height: 6),
        Text(value, style: Theme.of(context).textTheme.headlineSmall),
      ],
    ),
  );
}

const _greens = [
  Color(0xFF1D4B36),
  Color(0xFF276F45),
  Color(0xFF32985B),
  Color(0xFF48BE72),
];

class _CalendarSelectionCubit extends Cubit<String?> {
  _CalendarSelectionCubit() : super(null);
  void select(String day) => emit(day);
}

class ActivityCalendar extends StatelessWidget {
  const ActivityCalendar({super.key});
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => _CalendarSelectionCubit(),
    child: const _CalendarBody(),
  );
}

class _CalendarBody extends StatelessWidget {
  const _CalendarBody();
  static const _months = [
    'янв',
    'фев',
    'мар',
    'апр',
    'май',
    'июн',
    'июл',
    'авг',
    'сен',
    'окт',
    'ноя',
    'дек',
  ];
  @override
  Widget build(
    BuildContext context,
  ) => BlocSelector<StatisticsCubit, StatisticsState, DateTime>(
    selector: (s) => localDay(s.now),
    builder: (context, now) {
      final start = DateTime(now.year - 1, now.month, now.day + 1);
      final first = DateTime(
        start.year,
        start.month,
        start.day - start.weekday + 1,
      );
      final weeks = <DateTime>[];
      for (
        var week = first;
        !week.isAfter(now);
        week = DateTime(week.year, week.month, week.day + 7)
      ) {
        weeks.add(week);
      }
      final empty = Theme.of(context).colorScheme.onSurface
          .withValues(alpha: 0.08);
      return SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Календарь активности',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const _CalendarMetricPicker(),
            const SizedBox(height: 12),
            RepaintBoundary(
              child: SingleChildScrollView(
                key: const PageStorageKey('activity-calendar-scroll'),
                scrollDirection: Axis.horizontal,
                reverse: true,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 22, right: 6),
                      child: Column(
                        children: [
                          for (final label in [
                            'Пн',
                            '',
                            'Ср',
                            '',
                            'Пт',
                            '',
                            '',
                          ])
                            SizedBox(
                              height: 18,
                              child: Text(
                                label,
                                style: const TextStyle(
                                  fontSize: 10,
                                  height: 1.3,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    for (var i = 0; i < weeks.length; i++)
                      SizedBox(
                        width: 18,
                        child: Column(
                          children: [
                            SizedBox(
                              height: 22,
                              child: OverflowBox(
                                alignment: Alignment.centerLeft,
                                minWidth: 0,
                                maxWidth: 50,
                                child: Text(
                                  i == 0 || weeks[i].month != weeks[i - 1].month
                                      ? _months[weeks[i].month - 1]
                                      : '',
                                  style: const TextStyle(fontSize: 10),
                                ),
                              ),
                            ),
                            for (var d = 0; d < 7; d++)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Builder(
                                  builder: (_) {
                                    final date = DateTime(
                                      weeks[i].year,
                                      weeks[i].month,
                                      weeks[i].day + d,
                                    );
                                    return date.isBefore(start) ||
                                            date.isAfter(now)
                                        ? const SizedBox(width: 14, height: 14)
                                        : _CalendarCell(date: date);
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text('Меньше'),
                for (final color in [empty, ..._greens])
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                const Text('Больше'),
              ],
            ),
            const SizedBox(height: 8),
            const _CalendarCaption(),
            const SizedBox(height: 16),
            const _CalendarDetails(),
          ],
        ),
      );
    },
  );
}

class _CalendarMetricPicker extends StatelessWidget {
  const _CalendarMetricPicker();
  @override
  Widget build(BuildContext context) =>
      BlocSelector<StatisticsCubit, StatisticsState, CalendarMetric>(
        selector: (s) =>
            s.preferences?.calendarMetric ?? CalendarMetric.listening,
        builder: (context, selected) => Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final metric in CalendarMetric.values)
              ChoiceChip(
                label: Text(metric.title),
                selected: selected == metric,
                onSelected: (_) => context.read<StatisticsCubit>().configure(
                  calendarMetric: metric,
                ),
              ),
          ],
        ),
      );
}

class _CalendarCaption extends StatelessWidget {
  const _CalendarCaption();
  @override
  Widget build(BuildContext context) =>
      BlocSelector<StatisticsCubit, StatisticsState, (CalendarMetric, int?)>(
        selector: (s) => (
          s.preferences?.calendarMetric ?? CalendarMetric.listening,
          s.preferences?.keyGoal,
        ),
        builder: (_, value) => Text(
          value.$1 == CalendarMetric.keys && value.$2 == null
              ? 'Последние 12 месяцев · шкала нажатий: до 1000 в день.'
              : 'Последние 12 месяцев · насыщенность — доля дневной цели.',
        ),
      );
}

class _CalendarCell extends StatelessWidget {
  const _CalendarCell({required this.date});
  final DateTime date;
  @override
  Widget build(BuildContext context) =>
      BlocSelector<
        StatisticsCubit,
        StatisticsState,
        (ActivityDay?, CalendarMetric)
      >(
        selector: (s) => (
          s.daysByKey[dayKey(date)],
          s.preferences?.calendarMetric ?? CalendarMetric.listening,
        ),
        builder: (context, value) {
          final (day, metric) = value;
          final amount = switch (metric) {
            CalendarMetric.keys => day?.keyPresses ?? 0,
            CalendarMetric.listening => day?.listeningMs ?? 0,
            CalendarMetric.focus => day?.focusMs ?? 0,
          };
          final target = switch (metric) {
            CalendarMetric.keys => day?.keyGoal ?? 1000,
            CalendarMetric.listening => (day?.goalMinutes ?? 30) * 60000,
            CalendarMetric.focus => (day?.focusGoalMinutes ?? 60) * 60000,
          };
          final level = amount <= 0
              ? -1
              : ((amount / target * 4).ceil() - 1).clamp(0, 3);
          final color = level < 0
              ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08)
              : _greens[level];
          final label =
              '${_dateLabel(date)}: ${listeningTime(day?.listeningMs ?? 0)}, '
              '${day?.keyPresses ?? 0} нажатий, концентрация ${listeningTime(day?.focusMs ?? 0)}';
          return Tooltip(
            message: label,
            child: BlocSelector<_CalendarSelectionCubit, String?, bool>(
              selector: (selected) =>
                  (selected ??
                      dayKey(context.read<StatisticsCubit>().state.now)) ==
                  dayKey(date),
              builder: (context, selected) => Semantics(
                label: label,
                button: true,
                selected: selected,
                child: InkWell(
                  onTap: () => context.read<_CalendarSelectionCubit>().select(
                    dayKey(date),
                  ),
                  borderRadius: BorderRadius.circular(3),
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(3),
                      border: selected
                          ? Border.all(
                              color: Theme.of(context).colorScheme.onSurface,
                              width: 1.5,
                            )
                          : null,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
}

class _CalendarDetails extends StatelessWidget {
  const _CalendarDetails();
  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<_CalendarSelectionCubit, String?>(
    builder: (context, selected) =>
        BlocSelector<StatisticsCubit, StatisticsState, (String, ActivityDay?)>(
          selector: (s) {
            final key = selected ?? dayKey(s.now);
            return (key, s.daysByKey[key]);
          },
          builder: (context, value) {
            final (key, detail) = value;
            final completed = detail?.goalCompleted ?? false;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _dateLabel(DateTime.parse(key)),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 20,
                  runSpacing: 8,
                  children: [
                    Text('Всего: ${listeningTime(detail?.listeningMs ?? 0)}'),
                    Text('Музыка: ${listeningTime(detail?.musicMs ?? 0)}'),
                    Text(
                      'Атмосфера: ${listeningTime(detail?.atmosphereMs ?? 0)}',
                    ),
                    Text('Нажатия: ${detail?.keyPresses ?? 0}'),
                    Text(
                      'Концентрация: ${listeningTime(detail?.focusMs ?? 0)}',
                    ),
                    Text('Помидоро: ${listeningTime(detail?.pomodoroMs ?? 0)}'),
                    Text(
                      'Секундомер: ${listeningTime(detail?.stopwatchMs ?? 0)}',
                    ),
                    if (detail != null)
                      Text(
                        'Цель: ${detail.goalMetric.title} · ${detail.dailyGoalMinutes} мин',
                      ),
                    Text(
                      detail == null
                          ? 'Нет записанной активности'
                          : completed
                          ? 'Цель выполнена'
                          : 'Цель по времени не выполнена',
                    ),
                  ],
                ),
                if (detail == null)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text(
                      'Включите музыку, атмосферу или таймер — здесь появится ваша история.',
                    ),
                  ),
              ],
            );
          },
        ),
  );
}

class _PreferencesDialog extends StatefulWidget {
  const _PreferencesDialog();
  @override
  State<_PreferencesDialog> createState() => _PreferencesDialogState();
}

class _PreferencesDialogState extends State<_PreferencesDialog> {
  final _form = GlobalKey<FormState>();
  late final _minutes = TextEditingController(
    text: '${context.read<StatisticsCubit>().state.preferences!.goalMinutes}',
  );
  late final _focusMinutes = TextEditingController(
    text:
        '${context.read<StatisticsCubit>().state.preferences!.focusGoalMinutes}',
  );
  late DailyGoalMetric _goalMetric = context
      .read<StatisticsCubit>()
      .state
      .preferences!
      .goalMetric;
  late final _keys = TextEditingController(
    text:
        '${context.read<StatisticsCubit>().state.preferences!.keyGoal ?? 1000}',
  );
  late bool _collecting = context
      .read<StatisticsCubit>()
      .state
      .preferences!
      .collecting;
  late bool _keyGoal =
      context.read<StatisticsCubit>().state.preferences!.keyGoal != null;
  bool _saving = false;

  @override
  void dispose() {
    _minutes.dispose();
    _focusMinutes.dispose();
    _keys.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => WaloneDialog(
    title: const Text('Настроить статистику'),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Собирать статистику'),
                value: _collecting,
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _collecting = value),
              ),
              const SizedBox(height: 12),
              DesktopSelect<DailyGoalMetric>(
                key: const ValueKey('statistics-goal-metric'),
                value: _goalMetric,
                label: 'Цель и серия дней',
                hint: 'Выберите метрику цели',
                items: const {
                  DailyGoalMetric.listening: 'По прослушиванию',
                  DailyGoalMetric.focus: 'По концентрации',
                },
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _goalMetric = value),
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const ValueKey('statistics-listening-goal'),
                controller: _minutes,
                enabled: !_saving,
                decoration: const InputDecoration(
                  labelText: 'Цель по прослушиванию, минут',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (text) {
                  final value = int.tryParse(text ?? '');
                  return value == null || value < 1 || value > 1440
                      ? 'От 1 до 1440 минут'
                      : null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const ValueKey('statistics-focus-goal'),
                controller: _focusMinutes,
                enabled: !_saving,
                decoration: const InputDecoration(
                  labelText: 'Цель по концентрации, минут',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (text) {
                  final value = int.tryParse(text ?? '');
                  return value == null || value < 1 || value > 1440
                      ? 'От 1 до 1440 минут'
                      : null;
                },
              ),
              const SizedBox(height: 12),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Дополнительная цель по нажатиям'),
                value: _keyGoal,
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _keyGoal = value),
              ),
              if (_keyGoal)
                TextFormField(
                  controller: _keys,
                  enabled: !_saving,
                  decoration: const InputDecoration(
                    labelText: 'Нажатий в день',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (text) {
                    final value = int.tryParse(text ?? '');
                    return value == null || value < 1 || value > 1000000
                        ? 'От 1 до 1 000 000'
                        : null;
                  },
                ),
              const SizedBox(height: 16),
              const Text(
                'Метрика серии и цели меняются с сегодняшнего дня. Прошлые достижения '
                'сохраняются. Цель по нажатиям остаётся независимой.',
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                icon: const Icon(Icons.delete_outline),
                label: const Text('Очистить историю'),
                onPressed: _saving
                    ? null
                    : () async {
                        final cubit = context.read<StatisticsCubit>();
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (_) => const ConfirmDialog(
                            title: 'Удалить всю статистику?',
                            message:
                                'Календарь, серии и история прослушивания будут удалены '
                                'с этого устройства. Цели и настройки сохранятся.',
                          ),
                        );
                        if (confirmed != true || !mounted) return;
                        setState(() => _saving = true);
                        await cubit.clearHistory();
                        if (!mounted) return;
                        setState(() => _saving = false);
                        if (cubit.state.error == null && context.mounted) {
                          Navigator.pop(context);
                        }
                      },
              ),
              BlocSelector<StatisticsCubit, StatisticsState, String?>(
                selector: (state) => state.error,
                builder: (_, error) =>
                    error == null ? const SizedBox.shrink() : Text(error),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      OutlinedButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('Отмена'),
      ),
      FilledButton(
        onPressed: _saving
            ? null
            : () async {
                if (!_form.currentState!.validate()) return;
                final cubit = context.read<StatisticsCubit>();
                setState(() => _saving = true);
                await cubit.configure(
                  collecting: _collecting,
                  goalMinutes: int.parse(_minutes.text),
                  focusGoalMinutes: int.parse(_focusMinutes.text),
                  goalMetric: _goalMetric,
                  keyGoal: Value(_keyGoal ? int.parse(_keys.text) : null),
                );
                if (!mounted) return;
                setState(() => _saving = false);
                if (cubit.state.error == null && context.mounted) {
                  Navigator.pop(context);
                }
              },
        child: Text(_saving ? 'Сохранение…' : 'Сохранить'),
      ),
    ],
  );
}
