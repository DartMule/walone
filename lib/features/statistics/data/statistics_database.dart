import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import '../domain/activity.dart';

part 'statistics_database.g.dart';

class ActivityDays extends Table {
  TextColumn get day => text()();
  IntColumn get listeningMs => integer().withDefault(const Constant(0))();
  IntColumn get musicMs => integer().withDefault(const Constant(0))();
  IntColumn get atmosphereMs => integer().withDefault(const Constant(0))();
  IntColumn get keyPresses => integer().withDefault(const Constant(0))();
  IntColumn get focusMs => integer().withDefault(const Constant(0))();
  IntColumn get pomodoroMs => integer().withDefault(const Constant(0))();
  IntColumn get stopwatchMs => integer().withDefault(const Constant(0))();
  IntColumn get goalMinutes => integer()();
  IntColumn get focusGoalMinutes => integer().withDefault(const Constant(60))();
  BoolColumn get goalFocus => boolean().withDefault(const Constant(false))();
  IntColumn get keyGoal => integer().nullable()();

  @override
  Set<Column> get primaryKey => {day};
}

class ListeningSources extends Table {
  TextColumn get kind => text()();
  TextColumn get sourceId => text()();
  TextColumn get name => text()();

  @override
  Set<Column> get primaryKey => {kind, sourceId};
}

class SourceDays extends Table {
  TextColumn get day => text()();
  TextColumn get kind => text()();
  TextColumn get sourceId => text()();
  IntColumn get listeningMs => integer()();

  @override
  Set<Column> get primaryKey => {day, kind, sourceId};
}

class StatisticsPreferences extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  BoolColumn get collecting => boolean().withDefault(const Constant(true))();
  IntColumn get goalMinutes => integer().withDefault(const Constant(30))();
  IntColumn get focusGoalMinutes => integer().withDefault(const Constant(60))();
  BoolColumn get goalFocus => boolean().withDefault(const Constant(false))();
  IntColumn get keyGoal => integer().nullable()();
  BoolColumn get calendarKeys => boolean().withDefault(const Constant(false))();
  BoolColumn get calendarFocus =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class ListeningRank {
  const ListeningRank(this.kind, this.id, this.name, this.milliseconds);
  final String kind;
  final String id;
  final String name;
  final int milliseconds;

  @override
  bool operator ==(Object other) =>
      other is ListeningRank &&
      kind == other.kind &&
      id == other.id &&
      name == other.name &&
      milliseconds == other.milliseconds;
  @override
  int get hashCode => Object.hash(kind, id, name, milliseconds);
}

extension StatisticsCalendarMetric on StatisticsPreference {
  DailyGoalMetric get goalMetric =>
      goalFocus ? DailyGoalMetric.focus : DailyGoalMetric.listening;
  int get dailyGoalMinutes => goalFocus ? focusGoalMinutes : goalMinutes;

  CalendarMetric get calendarMetric => calendarFocus
      ? CalendarMetric.focus
      : calendarKeys
      ? CalendarMetric.keys
      : CalendarMetric.listening;
}

extension ActivityDailyGoal on ActivityDay {
  DailyGoalMetric get goalMetric =>
      goalFocus ? DailyGoalMetric.focus : DailyGoalMetric.listening;
  int get dailyGoalMinutes => goalFocus ? focusGoalMinutes : goalMinutes;
  bool get goalCompleted =>
      goalMetric.progressMs(this) >= dailyGoalMinutes * 60000;
}

@DriftDatabase(
  tables: [ActivityDays, ListeningSources, SourceDays, StatisticsPreferences],
)
class StatisticsDatabase extends _$StatisticsDatabase {
  StatisticsDatabase(super.executor);

  factory StatisticsDatabase.open(File file) =>
      StatisticsDatabase(NativeDatabase.createInBackground(file));

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.addColumn(activityDays, activityDays.focusMs);
        await migrator.addColumn(activityDays, activityDays.pomodoroMs);
        await migrator.addColumn(activityDays, activityDays.stopwatchMs);
        await migrator.addColumn(
          statisticsPreferences,
          statisticsPreferences.calendarFocus,
        );
      }
      if (from < 3) {
        await migrator.addColumn(activityDays, activityDays.focusGoalMinutes);
        await migrator.addColumn(activityDays, activityDays.goalFocus);
        await migrator.addColumn(
          statisticsPreferences,
          statisticsPreferences.focusGoalMinutes,
        );
        await migrator.addColumn(
          statisticsPreferences,
          statisticsPreferences.goalFocus,
        );
      }
    },
  );

  Future<StatisticsPreference> preferences() async {
    final existing = await select(statisticsPreferences).getSingleOrNull();
    if (existing != null) return existing;
    await into(statisticsPreferences).insert(
      const StatisticsPreferencesCompanion(id: Value(1)),
      mode: InsertMode.insertOrIgnore,
    );
    return select(statisticsPreferences).getSingle();
  }

  Future<List<ActivityDay>> days() =>
      (select(activityDays)..orderBy([(t) => OrderingTerm.asc(t.day)])).get();

  Future<void> record(
    Map<String, ActivityIncrement> increments,
    StatisticsPreference preferences,
    Map<(String, String), String> names,
  ) => transaction(() async {
    for (final entry in names.entries) {
      await into(listeningSources).insertOnConflictUpdate(
        ListeningSourcesCompanion.insert(
          kind: entry.key.$1,
          sourceId: entry.key.$2,
          name: entry.value,
        ),
      );
    }
    for (final entry in increments.entries) {
      final previous = await (select(
        activityDays,
      )..where((t) => t.day.equals(entry.key))).getSingleOrNull();
      final increment = entry.value;
      await into(activityDays).insertOnConflictUpdate(
        ActivityDaysCompanion.insert(
          day: entry.key,
          listeningMs: Value(
            (previous?.listeningMs ?? 0) + increment.listeningMs,
          ),
          musicMs: Value((previous?.musicMs ?? 0) + increment.musicMs),
          atmosphereMs: Value(
            (previous?.atmosphereMs ?? 0) + increment.atmosphereMs,
          ),
          keyPresses: Value((previous?.keyPresses ?? 0) + increment.keys),
          focusMs: Value((previous?.focusMs ?? 0) + increment.focusMs),
          pomodoroMs: Value((previous?.pomodoroMs ?? 0) + increment.pomodoroMs),
          stopwatchMs: Value(
            (previous?.stopwatchMs ?? 0) + increment.stopwatchMs,
          ),
          goalMinutes: previous?.goalMinutes ?? preferences.goalMinutes,
          focusGoalMinutes: Value(
            previous?.focusGoalMinutes ?? preferences.focusGoalMinutes,
          ),
          goalFocus: Value(previous?.goalFocus ?? preferences.goalFocus),
          keyGoal: Value(
            previous == null ? preferences.keyGoal : previous.keyGoal,
          ),
        ),
      );
      for (final source in increment.sources.entries) {
        await customUpdate(
          'INSERT INTO source_days (day, kind, source_id, listening_ms) '
          'VALUES (?, ?, ?, ?) ON CONFLICT (day, kind, source_id) '
          'DO UPDATE SET listening_ms = listening_ms + excluded.listening_ms',
          variables: [
            Variable(entry.key),
            Variable(source.key.$1),
            Variable(source.key.$2),
            Variable(source.value),
          ],
          updates: {sourceDays},
        );
      }
    }
  });

  Future<void> savePreferences(StatisticsPreference value, String today) =>
      transaction(() async {
        await into(statisticsPreferences).insertOnConflictUpdate(value);
        await (update(activityDays)..where((t) => t.day.equals(today))).write(
          ActivityDaysCompanion(
            goalMinutes: Value(value.goalMinutes),
            focusGoalMinutes: Value(value.focusGoalMinutes),
            goalFocus: Value(value.goalFocus),
            keyGoal: Value(value.keyGoal),
          ),
        );
      });

  Future<List<ListeningRank>> rankings(String? since, String through) async {
    final total = sourceDays.listeningMs.sum();
    final query =
        select(sourceDays).join([
            innerJoin(
              listeningSources,
              listeningSources.kind.equalsExp(sourceDays.kind) &
                  listeningSources.sourceId.equalsExp(sourceDays.sourceId),
            ),
          ])
          ..addColumns([total])
          ..where(sourceDays.day.isSmallerOrEqualValue(through));
    if (since != null) query.where(sourceDays.day.isBiggerOrEqualValue(since));
    query
      ..groupBy([sourceDays.kind, sourceDays.sourceId])
      ..orderBy([OrderingTerm.desc(total)]);
    return (await query.get()).map((row) {
      final source = row.readTable(listeningSources);
      return ListeningRank(
        source.kind,
        source.sourceId,
        source.name,
        row.read(total) ?? 0,
      );
    }).toList();
  }

  Future<void> clearHistory() => transaction(() async {
    await delete(sourceDays).go();
    await delete(listeningSources).go();
    await delete(activityDays).go();
  });
}
