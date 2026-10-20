import '../data/statistics_database.dart';

DateTime localDay(DateTime date) => DateTime(date.year, date.month, date.day);
DateTime previousDay(DateTime date) =>
    DateTime(date.year, date.month, date.day - 1);
String dayKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

enum StatisticsPeriod {
  week('Неделя'),
  month('Месяц'),
  all('Всё время');

  const StatisticsPeriod(this.title);
  final String title;

  String? since(DateTime now) => switch (this) {
    week => dayKey(DateTime(now.year, now.month, now.day - 6)),
    month => dayKey(DateTime(now.year, now.month, now.day - 29)),
    all => null,
  };
}

enum CalendarMetric {
  listening('Время'),
  keys('Нажатия'),
  focus('Концентрация');

  const CalendarMetric(this.title);
  final String title;
}

enum DailyGoalMetric {
  listening('Прослушивание'),
  focus('Концентрация');

  const DailyGoalMetric(this.title);
  final String title;

  int progressMs(ActivityDay? day) => switch (this) {
    listening => day?.listeningMs ?? 0,
    focus => day?.focusMs ?? 0,
  };
}

class PlaybackActivity {
  const PlaybackActivity({this.playlistId, this.atmosphereId});
  final String? playlistId;
  final String? atmosphereId;
  bool get audible => playlistId != null || atmosphereId != null;

  @override
  bool operator ==(Object other) =>
      other is PlaybackActivity &&
      playlistId == other.playlistId &&
      atmosphereId == other.atmosphereId;
  @override
  int get hashCode => Object.hash(playlistId, atmosphereId);
}

class ActivityIncrement {
  int listeningMs = 0;
  int musicMs = 0;
  int atmosphereMs = 0;
  int keys = 0;
  int focusMs = 0;
  int pomodoroMs = 0;
  int stopwatchMs = 0;
  final Map<(String, String), int> sources = {};

  void add(int milliseconds, PlaybackActivity activity) {
    if (!activity.audible) return;
    listeningMs += milliseconds;
    if (activity.playlistId case final String id) {
      musicMs += milliseconds;
      sources.update(
        ('music', id),
        (n) => n + milliseconds,
        ifAbsent: () => milliseconds,
      );
    }
    if (activity.atmosphereId case final String id) {
      atmosphereMs += milliseconds;
      sources.update(
        ('atmosphere', id),
        (n) => n + milliseconds,
        ifAbsent: () => milliseconds,
      );
    }
  }
}

// Суточные суммы: никаких символов, отдельных нажатий или журнала действий.
class ActivityAccumulator {
  final Map<String, ActivityIncrement> days = {};

  void recordFocus(
    DateTime start,
    DateTime end, {
    required bool pomodoro,
    required bool stopwatch,
  }) {
    if (!pomodoro && !stopwatch) return;
    var cursor = start;
    while (cursor.isBefore(end)) {
      final midnight = DateTime(cursor.year, cursor.month, cursor.day + 1);
      final stop = midnight.isBefore(end) ? midnight : end;
      final milliseconds = stop.difference(cursor).inMilliseconds;
      final increment = days.putIfAbsent(dayKey(cursor), ActivityIncrement.new);
      increment.focusMs += milliseconds;
      if (pomodoro) increment.pomodoroMs += milliseconds;
      if (stopwatch) increment.stopwatchMs += milliseconds;
      cursor = stop;
    }
  }

  void record(
    DateTime start,
    DateTime end,
    PlaybackActivity activity,
    int keys,
  ) {
    if (end.isBefore(start)) return;
    var cursor = start;
    while (cursor.isBefore(end)) {
      final midnight = DateTime(cursor.year, cursor.month, cursor.day + 1);
      final stop = midnight.isBefore(end) ? midnight : end;
      if (activity.audible) {
        days
            .putIfAbsent(dayKey(cursor), ActivityIncrement.new)
            .add(stop.difference(cursor).inMilliseconds, activity);
      }
      cursor = stop;
    }
    if (keys > 0) {
      days.putIfAbsent(dayKey(end), ActivityIncrement.new).keys += keys;
    }
  }
}

({int current, int best}) activityStreaks(
  List<ActivityDay> days,
  DateTime now,
) {
  final today = dayKey(now);
  final achieved = {
    for (final day in days)
      if (day.day.compareTo(today) <= 0 && day.goalCompleted) day.day,
  };
  var best = 0;
  var run = 0;
  DateTime? previous;
  for (final key in achieved.toList()..sort()) {
    final date = DateTime.parse(key);
    run = previous != null && dayKey(previousDay(date)) == dayKey(previous)
        ? run + 1
        : 1;
    if (run > best) best = run;
    previous = date;
  }
  var cursor = localDay(now);
  if (!achieved.contains(today)) cursor = previousDay(cursor);
  var current = 0;
  while (achieved.contains(dayKey(cursor))) {
    current++;
    cursor = previousDay(cursor);
  }
  return (current: current, best: best);
}
