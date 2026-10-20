import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../atmosphere/presentation/atmosphere_cubit.dart';
import '../../music/presentation/music_cubit.dart';
import '../../timer/presentation/timer_cubit.dart';
import '../data/statistics_database.dart';
import '../domain/activity.dart';

PlaybackActivity playbackActivity(
  MusicState music,
  AtmosphereState atmosphere,
) {
  final audible = !atmosphere.paused && atmosphere.master > 0;
  final playlist = music.library.playlist(music.library.playingID);
  return PlaybackActivity(
    playlistId:
        audible && music.playing && !music.loading && music.library.volume > 0
        ? playlist?.id
        : null,
    atmosphereId:
        audible &&
            atmosphere.running &&
            atmosphere.backgroundVolume > 0 &&
            atmosphere.mix.layers.values.any((l) => l.enabled && l.volume > 0)
        ? atmosphere.selectedID ?? 'custom'
        : null,
  );
}

class StatisticsState {
  StatisticsState({
    this.preferences,
    this.days = const [],
    this.rankings = const [],
    this.period = StatisticsPeriod.week,
    this.loading = true,
    this.error,
    this.keyboardError,
    required this.now,
  }) : daysByKey = Map<String, ActivityDay>.unmodifiable({
         for (final day in days) day.day: day,
       });
  final StatisticsPreference? preferences;
  final List<ActivityDay> days;
  final List<ListeningRank> rankings;
  final StatisticsPeriod period;
  final bool loading;
  final String? error;
  final String? keyboardError;
  final DateTime now;
  final Map<String, ActivityDay> daysByKey;
}

class StatisticsCubit extends Cubit<StatisticsState> {
  StatisticsCubit(
    this.database, {
    DateTime Function()? clock,
    int Function()? monotonicMilliseconds,
    Future<int> Function(bool)? syncKeys,
  }) : _clock = clock ?? DateTime.now,
       _syncKeys = syncKeys ?? _nativeKeys,
       super(StatisticsState(now: (clock ?? DateTime.now)())) {
    _stopwatch.start();
    _monotonic = monotonicMilliseconds ?? () => _stopwatch.elapsedMilliseconds;
  }

  final StatisticsDatabase database;
  final DateTime Function() _clock;
  final Future<int> Function(bool) _syncKeys;
  final Stopwatch _stopwatch = Stopwatch();
  late final int Function() _monotonic;
  final _pending = ActivityAccumulator();
  final Map<(String, String), String> _names = {};
  bool _namesDirty = false;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  Future<void> _tail = Future.value();
  StatisticsPreference? _preferences;
  PlaybackActivity _activity = const PlaybackActivity();
  bool _collecting = false;
  bool _closing = false;
  DateTime? _last;
  int _lastMonotonic = 0;
  int? _counter;
  StreamSubscription<dynamic>? _databaseUpdates;
  Timer? _timer;
  String? _keyboardError;
  StatisticsPeriod _period = StatisticsPeriod.week;
  TimerCubit? _focusTimer;

  static Future<int> _nativeKeys(bool active) async =>
      await const MethodChannel('dev.soyjanks.walone/keyboard')
          .invokeMethod<int>('statistics', active) ??
      0;

  Future<void> _run(Future<void> Function() action) {
    _tail = _tail.then((_) async {
      if (isClosed) return;
      try {
        await action();
      } catch (error) {
        emit(
          StatisticsState(
            preferences: _preferences,
            days: state.days,
            rankings: state.rankings,
            period: _period,
            loading: false,
            now: _clock(),
            error: 'Не удалось сохранить или прочитать статистику: $error',
            keyboardError: _keyboardError,
          ),
        );
      }
    });
    return _tail;
  }

  Future<void> initialize() => _run(() async {
    _preferences = await database.preferences();
    await _sample(const PlaybackActivity(), _preferences!.collecting);
    await _publish();
    _databaseUpdates ??= database.tableUpdates().listen(
      (_) {
        if (!_closing) _run(_publish);
      },
      onError: (Object error, StackTrace stack) {
        if (!_closing) {
          _run(() async => Error.throwWithStackTrace(error, stack));
        }
      },
    );
  });

  void attach(
    MusicCubit music,
    AtmosphereCubit atmosphere, {
    TimerCubit? timer,
  }) {
    _focusTimer = timer;
    if (timer != null) {
      _subscriptions.add(
        timer.intervals.listen((interval) {
          if (_closing) return;
          _run(() async {
            if (_preferences?.collecting != true) return;
            _pending.recordFocus(
              interval.start,
              interval.end,
              pomodoro: interval.pomodoro,
              stopwatch: interval.stopwatch,
            );
          });
        }),
      );
    }
    PlaybackActivity? observed;
    var observedNames = <(String, String), String>{};
    void observe() {
      if (_closing || _preferences == null) return;
      final m = music.state;
      final a = atmosphere.state;
      final next = playbackActivity(m, a);
      final names = <(String, String), String>{
        for (final p in m.library.playlists) ('music', p.id): p.name,
        for (final p in a.presets) ('atmosphere', p.id): p.name,
        ('atmosphere', 'custom'): 'Свой микс',
      };
      final renamed =
          names.length != observedNames.length ||
          names.entries.any((e) => observedNames[e.key] != e.value);
      if (next == observed && !renamed) return;
      observed = next;
      observedNames = names;
      // Снимок захватывается до постановки в очередь: быстрые переключения не теряются.
      _run(() async {
        await _sample(next, _preferences!.collecting);
        _namesDirty =
            _namesDirty || names.entries.any((e) => _names[e.key] != e.value);
        _names.addAll(names);
        await _flush();
        await _publish();
      });
    }

    _subscriptions.add(music.stream.listen((_) => observe()));
    _subscriptions.add(atmosphere.stream.listen((_) => observe()));
    observe();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  // Отдельный шаг позволяет проверить границы суток и сон без реального ожидания.
  Future<void> tick() => _run(() async {
    if (_preferences == null || _closing) return;
    await _sample(_activity, _preferences!.collecting);
    final changed =
        _pending.days.isNotEmpty ||
        _namesDirty ||
        dayKey(_clock()) != dayKey(state.now) ||
        _keyboardError != state.keyboardError ||
        state.error != null;
    await _flush();
    if (changed) await _publish();
  });

  Future<void> setActivity(
    PlaybackActivity activity, {
    Map<(String, String), String> names = const {},
  }) => _run(() async {
    if (_preferences == null) return;
    await _sample(activity, _preferences!.collecting);
    _namesDirty =
        _namesDirty || names.entries.any((e) => _names[e.key] != e.value);
    _names.addAll(names);
    await _flush();
    await _publish();
  });

  Future<void> _sample(PlaybackActivity next, bool collecting) async {
    final now = _clock();
    final monotonic = _monotonic();
    var keys = 0;
    try {
      final counter = await _syncKeys(collecting && next.audible);
      if (_counter != null && counter >= _counter!) keys = counter - _counter!;
      _counter = counter;
      _keyboardError = null;
    } catch (error) {
      _keyboardError = 'Счётчик нажатий недоступен: $error';
    }
    final last = _last;
    final eligibleKeys = _collecting && _activity.audible ? keys : 0;
    if (last != null) {
      final elapsed = monotonic - _lastMonotonic;
      final wall = now.difference(last).inMilliseconds;
      // После сна, задержки процесса или перевода часов не начисляем весь разрыв.
      if (_collecting &&
          elapsed >= 0 &&
          elapsed <= 5000 &&
          (wall - elapsed).abs() <= 2000 &&
          wall >= 0) {
        _pending.record(last, now, _activity, eligibleKeys);
      } else if (eligibleKeys > 0) {
        _pending.record(now, now, const PlaybackActivity(), eligibleKeys);
      }
    }
    _last = now;
    _lastMonotonic = monotonic;
    _activity = next;
    _collecting = collecting;
  }

  Future<void> _flush() async {
    if (_preferences == null) return;
    if (_pending.days.isEmpty && !_preferences!.collecting) return;
    if (_pending.days.isEmpty && !_namesDirty) return;
    await database.record(
      _pending.days,
      _preferences!,
      _namesDirty ? _names : const {},
    );
    _pending.days.clear();
    _namesDirty = false;
  }

  Future<void> _publish() async {
    final now = _clock();
    _preferences = await database.preferences();
    final loadedDays = await database.days();
    final loadedRanks = await database.rankings(
      _period.since(now),
      dayKey(now),
    );
    final days = listEquals(loadedDays, state.days)
        ? state.days
        : List<ActivityDay>.unmodifiable(loadedDays);
    final ranks = listEquals(loadedRanks, state.rankings)
        ? state.rankings
        : List<ListeningRank>.unmodifiable(loadedRanks);
    if (!state.loading &&
        state.error == null &&
        state.preferences == _preferences &&
        identical(days, state.days) &&
        identical(ranks, state.rankings) &&
        state.period == _period &&
        dayKey(state.now) == dayKey(now) &&
        state.keyboardError == _keyboardError) {
      return;
    }
    if (!isClosed) {
      emit(
        StatisticsState(
          preferences: _preferences,
          days: days,
          rankings: ranks,
          period: _period,
          loading: false,
          now: now,
          keyboardError: _keyboardError,
        ),
      );
    }
  }

  Future<void> configure({
    bool? collecting,
    int? goalMinutes,
    int? focusGoalMinutes,
    DailyGoalMetric? goalMetric,
    Value<int?> keyGoal = const Value.absent(),
    CalendarMetric? calendarMetric,
  }) {
    _focusTimer?.tick();
    return _run(() async {
      final current = _preferences;
      if (current == null) return;
      if (goalMinutes != null && (goalMinutes < 1 || goalMinutes > 1440)) {
        throw const FormatException('Цель должна быть от 1 до 1440 минут');
      }
      if (focusGoalMinutes != null &&
          (focusGoalMinutes < 1 || focusGoalMinutes > 1440)) {
        throw const FormatException(
          'Цель по концентрации должна быть от 1 до 1440 минут',
        );
      }
      if (keyGoal.present &&
          keyGoal.value != null &&
          (keyGoal.value! < 1 || keyGoal.value! > 1000000)) {
        throw const FormatException(
          'Цель должна быть от 1 до 1 000 000 нажатий',
        );
      }
      await _sample(_activity, current.collecting);
      await _flush();
      final next = current.copyWith(
        collecting: collecting,
        goalMinutes: goalMinutes,
        focusGoalMinutes: focusGoalMinutes,
        goalFocus: goalMetric == null
            ? null
            : goalMetric == DailyGoalMetric.focus,
        keyGoal: keyGoal,
        calendarKeys: calendarMetric == null
            ? null
            : calendarMetric == CalendarMetric.keys,
        calendarFocus: calendarMetric == null
            ? null
            : calendarMetric == CalendarMetric.focus,
      );
      await database.savePreferences(next, dayKey(_clock()));
      _preferences = next;
      await _sample(_activity, next.collecting);
      await _publish();
    });
  }

  Future<void> selectPeriod(StatisticsPeriod value) => _run(() async {
    _period = value;
    await _flush();
    await _publish();
  });

  Future<void> clearHistory() {
    _focusTimer?.tick();
    return _run(() async {
      if (_preferences == null) return;
      await _sample(_activity, false);
      await database.clearHistory();
      _pending.days.clear();
      _namesDirty = true;
      await _sample(_activity, _preferences!.collecting);
      await _publish();
    });
  }

  @override
  Future<void> close() async {
    _focusTimer?.tick();
    _closing = true;
    _timer?.cancel();
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _run(() async {
      await _sample(const PlaybackActivity(), false);
      await _flush();
    });
    await _databaseUpdates?.cancel();
    await database.close();
    _stopwatch.stop();
    return super.close();
  }
}
