// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'statistics_database.dart';

// ignore_for_file: type=lint
class $ActivityDaysTable extends ActivityDays
    with TableInfo<$ActivityDaysTable, ActivityDay> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ActivityDaysTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _dayMeta = const VerificationMeta('day');
  @override
  late final GeneratedColumn<String> day = GeneratedColumn<String>(
    'day',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _listeningMsMeta = const VerificationMeta(
    'listeningMs',
  );
  @override
  late final GeneratedColumn<int> listeningMs = GeneratedColumn<int>(
    'listening_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _musicMsMeta = const VerificationMeta(
    'musicMs',
  );
  @override
  late final GeneratedColumn<int> musicMs = GeneratedColumn<int>(
    'music_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _atmosphereMsMeta = const VerificationMeta(
    'atmosphereMs',
  );
  @override
  late final GeneratedColumn<int> atmosphereMs = GeneratedColumn<int>(
    'atmosphere_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _keyPressesMeta = const VerificationMeta(
    'keyPresses',
  );
  @override
  late final GeneratedColumn<int> keyPresses = GeneratedColumn<int>(
    'key_presses',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _focusMsMeta = const VerificationMeta(
    'focusMs',
  );
  @override
  late final GeneratedColumn<int> focusMs = GeneratedColumn<int>(
    'focus_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _pomodoroMsMeta = const VerificationMeta(
    'pomodoroMs',
  );
  @override
  late final GeneratedColumn<int> pomodoroMs = GeneratedColumn<int>(
    'pomodoro_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _stopwatchMsMeta = const VerificationMeta(
    'stopwatchMs',
  );
  @override
  late final GeneratedColumn<int> stopwatchMs = GeneratedColumn<int>(
    'stopwatch_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _goalMinutesMeta = const VerificationMeta(
    'goalMinutes',
  );
  @override
  late final GeneratedColumn<int> goalMinutes = GeneratedColumn<int>(
    'goal_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _focusGoalMinutesMeta = const VerificationMeta(
    'focusGoalMinutes',
  );
  @override
  late final GeneratedColumn<int> focusGoalMinutes = GeneratedColumn<int>(
    'focus_goal_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(60),
  );
  static const VerificationMeta _goalFocusMeta = const VerificationMeta(
    'goalFocus',
  );
  @override
  late final GeneratedColumn<bool> goalFocus = GeneratedColumn<bool>(
    'goal_focus',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("goal_focus" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _keyGoalMeta = const VerificationMeta(
    'keyGoal',
  );
  @override
  late final GeneratedColumn<int> keyGoal = GeneratedColumn<int>(
    'key_goal',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    day,
    listeningMs,
    musicMs,
    atmosphereMs,
    keyPresses,
    focusMs,
    pomodoroMs,
    stopwatchMs,
    goalMinutes,
    focusGoalMinutes,
    goalFocus,
    keyGoal,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'activity_days';
  @override
  VerificationContext validateIntegrity(
    Insertable<ActivityDay> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('day')) {
      context.handle(
        _dayMeta,
        day.isAcceptableOrUnknown(data['day']!, _dayMeta),
      );
    } else if (isInserting) {
      context.missing(_dayMeta);
    }
    if (data.containsKey('listening_ms')) {
      context.handle(
        _listeningMsMeta,
        listeningMs.isAcceptableOrUnknown(
          data['listening_ms']!,
          _listeningMsMeta,
        ),
      );
    }
    if (data.containsKey('music_ms')) {
      context.handle(
        _musicMsMeta,
        musicMs.isAcceptableOrUnknown(data['music_ms']!, _musicMsMeta),
      );
    }
    if (data.containsKey('atmosphere_ms')) {
      context.handle(
        _atmosphereMsMeta,
        atmosphereMs.isAcceptableOrUnknown(
          data['atmosphere_ms']!,
          _atmosphereMsMeta,
        ),
      );
    }
    if (data.containsKey('key_presses')) {
      context.handle(
        _keyPressesMeta,
        keyPresses.isAcceptableOrUnknown(data['key_presses']!, _keyPressesMeta),
      );
    }
    if (data.containsKey('focus_ms')) {
      context.handle(
        _focusMsMeta,
        focusMs.isAcceptableOrUnknown(data['focus_ms']!, _focusMsMeta),
      );
    }
    if (data.containsKey('pomodoro_ms')) {
      context.handle(
        _pomodoroMsMeta,
        pomodoroMs.isAcceptableOrUnknown(data['pomodoro_ms']!, _pomodoroMsMeta),
      );
    }
    if (data.containsKey('stopwatch_ms')) {
      context.handle(
        _stopwatchMsMeta,
        stopwatchMs.isAcceptableOrUnknown(
          data['stopwatch_ms']!,
          _stopwatchMsMeta,
        ),
      );
    }
    if (data.containsKey('goal_minutes')) {
      context.handle(
        _goalMinutesMeta,
        goalMinutes.isAcceptableOrUnknown(
          data['goal_minutes']!,
          _goalMinutesMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_goalMinutesMeta);
    }
    if (data.containsKey('focus_goal_minutes')) {
      context.handle(
        _focusGoalMinutesMeta,
        focusGoalMinutes.isAcceptableOrUnknown(
          data['focus_goal_minutes']!,
          _focusGoalMinutesMeta,
        ),
      );
    }
    if (data.containsKey('goal_focus')) {
      context.handle(
        _goalFocusMeta,
        goalFocus.isAcceptableOrUnknown(data['goal_focus']!, _goalFocusMeta),
      );
    }
    if (data.containsKey('key_goal')) {
      context.handle(
        _keyGoalMeta,
        keyGoal.isAcceptableOrUnknown(data['key_goal']!, _keyGoalMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {day};
  @override
  ActivityDay map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ActivityDay(
      day: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}day'],
      )!,
      listeningMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}listening_ms'],
      )!,
      musicMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}music_ms'],
      )!,
      atmosphereMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}atmosphere_ms'],
      )!,
      keyPresses: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}key_presses'],
      )!,
      focusMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}focus_ms'],
      )!,
      pomodoroMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pomodoro_ms'],
      )!,
      stopwatchMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}stopwatch_ms'],
      )!,
      goalMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}goal_minutes'],
      )!,
      focusGoalMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}focus_goal_minutes'],
      )!,
      goalFocus: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}goal_focus'],
      )!,
      keyGoal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}key_goal'],
      ),
    );
  }

  @override
  $ActivityDaysTable createAlias(String alias) {
    return $ActivityDaysTable(attachedDatabase, alias);
  }
}

class ActivityDay extends DataClass implements Insertable<ActivityDay> {
  final String day;
  final int listeningMs;
  final int musicMs;
  final int atmosphereMs;
  final int keyPresses;
  final int focusMs;
  final int pomodoroMs;
  final int stopwatchMs;
  final int goalMinutes;
  final int focusGoalMinutes;
  final bool goalFocus;
  final int? keyGoal;
  const ActivityDay({
    required this.day,
    required this.listeningMs,
    required this.musicMs,
    required this.atmosphereMs,
    required this.keyPresses,
    required this.focusMs,
    required this.pomodoroMs,
    required this.stopwatchMs,
    required this.goalMinutes,
    required this.focusGoalMinutes,
    required this.goalFocus,
    this.keyGoal,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['day'] = Variable<String>(day);
    map['listening_ms'] = Variable<int>(listeningMs);
    map['music_ms'] = Variable<int>(musicMs);
    map['atmosphere_ms'] = Variable<int>(atmosphereMs);
    map['key_presses'] = Variable<int>(keyPresses);
    map['focus_ms'] = Variable<int>(focusMs);
    map['pomodoro_ms'] = Variable<int>(pomodoroMs);
    map['stopwatch_ms'] = Variable<int>(stopwatchMs);
    map['goal_minutes'] = Variable<int>(goalMinutes);
    map['focus_goal_minutes'] = Variable<int>(focusGoalMinutes);
    map['goal_focus'] = Variable<bool>(goalFocus);
    if (!nullToAbsent || keyGoal != null) {
      map['key_goal'] = Variable<int>(keyGoal);
    }
    return map;
  }

  ActivityDaysCompanion toCompanion(bool nullToAbsent) {
    return ActivityDaysCompanion(
      day: Value(day),
      listeningMs: Value(listeningMs),
      musicMs: Value(musicMs),
      atmosphereMs: Value(atmosphereMs),
      keyPresses: Value(keyPresses),
      focusMs: Value(focusMs),
      pomodoroMs: Value(pomodoroMs),
      stopwatchMs: Value(stopwatchMs),
      goalMinutes: Value(goalMinutes),
      focusGoalMinutes: Value(focusGoalMinutes),
      goalFocus: Value(goalFocus),
      keyGoal: keyGoal == null && nullToAbsent
          ? const Value.absent()
          : Value(keyGoal),
    );
  }

  factory ActivityDay.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ActivityDay(
      day: serializer.fromJson<String>(json['day']),
      listeningMs: serializer.fromJson<int>(json['listeningMs']),
      musicMs: serializer.fromJson<int>(json['musicMs']),
      atmosphereMs: serializer.fromJson<int>(json['atmosphereMs']),
      keyPresses: serializer.fromJson<int>(json['keyPresses']),
      focusMs: serializer.fromJson<int>(json['focusMs']),
      pomodoroMs: serializer.fromJson<int>(json['pomodoroMs']),
      stopwatchMs: serializer.fromJson<int>(json['stopwatchMs']),
      goalMinutes: serializer.fromJson<int>(json['goalMinutes']),
      focusGoalMinutes: serializer.fromJson<int>(json['focusGoalMinutes']),
      goalFocus: serializer.fromJson<bool>(json['goalFocus']),
      keyGoal: serializer.fromJson<int?>(json['keyGoal']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'day': serializer.toJson<String>(day),
      'listeningMs': serializer.toJson<int>(listeningMs),
      'musicMs': serializer.toJson<int>(musicMs),
      'atmosphereMs': serializer.toJson<int>(atmosphereMs),
      'keyPresses': serializer.toJson<int>(keyPresses),
      'focusMs': serializer.toJson<int>(focusMs),
      'pomodoroMs': serializer.toJson<int>(pomodoroMs),
      'stopwatchMs': serializer.toJson<int>(stopwatchMs),
      'goalMinutes': serializer.toJson<int>(goalMinutes),
      'focusGoalMinutes': serializer.toJson<int>(focusGoalMinutes),
      'goalFocus': serializer.toJson<bool>(goalFocus),
      'keyGoal': serializer.toJson<int?>(keyGoal),
    };
  }

  ActivityDay copyWith({
    String? day,
    int? listeningMs,
    int? musicMs,
    int? atmosphereMs,
    int? keyPresses,
    int? focusMs,
    int? pomodoroMs,
    int? stopwatchMs,
    int? goalMinutes,
    int? focusGoalMinutes,
    bool? goalFocus,
    Value<int?> keyGoal = const Value.absent(),
  }) => ActivityDay(
    day: day ?? this.day,
    listeningMs: listeningMs ?? this.listeningMs,
    musicMs: musicMs ?? this.musicMs,
    atmosphereMs: atmosphereMs ?? this.atmosphereMs,
    keyPresses: keyPresses ?? this.keyPresses,
    focusMs: focusMs ?? this.focusMs,
    pomodoroMs: pomodoroMs ?? this.pomodoroMs,
    stopwatchMs: stopwatchMs ?? this.stopwatchMs,
    goalMinutes: goalMinutes ?? this.goalMinutes,
    focusGoalMinutes: focusGoalMinutes ?? this.focusGoalMinutes,
    goalFocus: goalFocus ?? this.goalFocus,
    keyGoal: keyGoal.present ? keyGoal.value : this.keyGoal,
  );
  ActivityDay copyWithCompanion(ActivityDaysCompanion data) {
    return ActivityDay(
      day: data.day.present ? data.day.value : this.day,
      listeningMs: data.listeningMs.present
          ? data.listeningMs.value
          : this.listeningMs,
      musicMs: data.musicMs.present ? data.musicMs.value : this.musicMs,
      atmosphereMs: data.atmosphereMs.present
          ? data.atmosphereMs.value
          : this.atmosphereMs,
      keyPresses: data.keyPresses.present
          ? data.keyPresses.value
          : this.keyPresses,
      focusMs: data.focusMs.present ? data.focusMs.value : this.focusMs,
      pomodoroMs: data.pomodoroMs.present
          ? data.pomodoroMs.value
          : this.pomodoroMs,
      stopwatchMs: data.stopwatchMs.present
          ? data.stopwatchMs.value
          : this.stopwatchMs,
      goalMinutes: data.goalMinutes.present
          ? data.goalMinutes.value
          : this.goalMinutes,
      focusGoalMinutes: data.focusGoalMinutes.present
          ? data.focusGoalMinutes.value
          : this.focusGoalMinutes,
      goalFocus: data.goalFocus.present ? data.goalFocus.value : this.goalFocus,
      keyGoal: data.keyGoal.present ? data.keyGoal.value : this.keyGoal,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ActivityDay(')
          ..write('day: $day, ')
          ..write('listeningMs: $listeningMs, ')
          ..write('musicMs: $musicMs, ')
          ..write('atmosphereMs: $atmosphereMs, ')
          ..write('keyPresses: $keyPresses, ')
          ..write('focusMs: $focusMs, ')
          ..write('pomodoroMs: $pomodoroMs, ')
          ..write('stopwatchMs: $stopwatchMs, ')
          ..write('goalMinutes: $goalMinutes, ')
          ..write('focusGoalMinutes: $focusGoalMinutes, ')
          ..write('goalFocus: $goalFocus, ')
          ..write('keyGoal: $keyGoal')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    day,
    listeningMs,
    musicMs,
    atmosphereMs,
    keyPresses,
    focusMs,
    pomodoroMs,
    stopwatchMs,
    goalMinutes,
    focusGoalMinutes,
    goalFocus,
    keyGoal,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ActivityDay &&
          other.day == this.day &&
          other.listeningMs == this.listeningMs &&
          other.musicMs == this.musicMs &&
          other.atmosphereMs == this.atmosphereMs &&
          other.keyPresses == this.keyPresses &&
          other.focusMs == this.focusMs &&
          other.pomodoroMs == this.pomodoroMs &&
          other.stopwatchMs == this.stopwatchMs &&
          other.goalMinutes == this.goalMinutes &&
          other.focusGoalMinutes == this.focusGoalMinutes &&
          other.goalFocus == this.goalFocus &&
          other.keyGoal == this.keyGoal);
}

class ActivityDaysCompanion extends UpdateCompanion<ActivityDay> {
  final Value<String> day;
  final Value<int> listeningMs;
  final Value<int> musicMs;
  final Value<int> atmosphereMs;
  final Value<int> keyPresses;
  final Value<int> focusMs;
  final Value<int> pomodoroMs;
  final Value<int> stopwatchMs;
  final Value<int> goalMinutes;
  final Value<int> focusGoalMinutes;
  final Value<bool> goalFocus;
  final Value<int?> keyGoal;
  final Value<int> rowid;
  const ActivityDaysCompanion({
    this.day = const Value.absent(),
    this.listeningMs = const Value.absent(),
    this.musicMs = const Value.absent(),
    this.atmosphereMs = const Value.absent(),
    this.keyPresses = const Value.absent(),
    this.focusMs = const Value.absent(),
    this.pomodoroMs = const Value.absent(),
    this.stopwatchMs = const Value.absent(),
    this.goalMinutes = const Value.absent(),
    this.focusGoalMinutes = const Value.absent(),
    this.goalFocus = const Value.absent(),
    this.keyGoal = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ActivityDaysCompanion.insert({
    required String day,
    this.listeningMs = const Value.absent(),
    this.musicMs = const Value.absent(),
    this.atmosphereMs = const Value.absent(),
    this.keyPresses = const Value.absent(),
    this.focusMs = const Value.absent(),
    this.pomodoroMs = const Value.absent(),
    this.stopwatchMs = const Value.absent(),
    required int goalMinutes,
    this.focusGoalMinutes = const Value.absent(),
    this.goalFocus = const Value.absent(),
    this.keyGoal = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : day = Value(day),
       goalMinutes = Value(goalMinutes);
  static Insertable<ActivityDay> custom({
    Expression<String>? day,
    Expression<int>? listeningMs,
    Expression<int>? musicMs,
    Expression<int>? atmosphereMs,
    Expression<int>? keyPresses,
    Expression<int>? focusMs,
    Expression<int>? pomodoroMs,
    Expression<int>? stopwatchMs,
    Expression<int>? goalMinutes,
    Expression<int>? focusGoalMinutes,
    Expression<bool>? goalFocus,
    Expression<int>? keyGoal,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (day != null) 'day': day,
      if (listeningMs != null) 'listening_ms': listeningMs,
      if (musicMs != null) 'music_ms': musicMs,
      if (atmosphereMs != null) 'atmosphere_ms': atmosphereMs,
      if (keyPresses != null) 'key_presses': keyPresses,
      if (focusMs != null) 'focus_ms': focusMs,
      if (pomodoroMs != null) 'pomodoro_ms': pomodoroMs,
      if (stopwatchMs != null) 'stopwatch_ms': stopwatchMs,
      if (goalMinutes != null) 'goal_minutes': goalMinutes,
      if (focusGoalMinutes != null) 'focus_goal_minutes': focusGoalMinutes,
      if (goalFocus != null) 'goal_focus': goalFocus,
      if (keyGoal != null) 'key_goal': keyGoal,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ActivityDaysCompanion copyWith({
    Value<String>? day,
    Value<int>? listeningMs,
    Value<int>? musicMs,
    Value<int>? atmosphereMs,
    Value<int>? keyPresses,
    Value<int>? focusMs,
    Value<int>? pomodoroMs,
    Value<int>? stopwatchMs,
    Value<int>? goalMinutes,
    Value<int>? focusGoalMinutes,
    Value<bool>? goalFocus,
    Value<int?>? keyGoal,
    Value<int>? rowid,
  }) {
    return ActivityDaysCompanion(
      day: day ?? this.day,
      listeningMs: listeningMs ?? this.listeningMs,
      musicMs: musicMs ?? this.musicMs,
      atmosphereMs: atmosphereMs ?? this.atmosphereMs,
      keyPresses: keyPresses ?? this.keyPresses,
      focusMs: focusMs ?? this.focusMs,
      pomodoroMs: pomodoroMs ?? this.pomodoroMs,
      stopwatchMs: stopwatchMs ?? this.stopwatchMs,
      goalMinutes: goalMinutes ?? this.goalMinutes,
      focusGoalMinutes: focusGoalMinutes ?? this.focusGoalMinutes,
      goalFocus: goalFocus ?? this.goalFocus,
      keyGoal: keyGoal ?? this.keyGoal,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (day.present) {
      map['day'] = Variable<String>(day.value);
    }
    if (listeningMs.present) {
      map['listening_ms'] = Variable<int>(listeningMs.value);
    }
    if (musicMs.present) {
      map['music_ms'] = Variable<int>(musicMs.value);
    }
    if (atmosphereMs.present) {
      map['atmosphere_ms'] = Variable<int>(atmosphereMs.value);
    }
    if (keyPresses.present) {
      map['key_presses'] = Variable<int>(keyPresses.value);
    }
    if (focusMs.present) {
      map['focus_ms'] = Variable<int>(focusMs.value);
    }
    if (pomodoroMs.present) {
      map['pomodoro_ms'] = Variable<int>(pomodoroMs.value);
    }
    if (stopwatchMs.present) {
      map['stopwatch_ms'] = Variable<int>(stopwatchMs.value);
    }
    if (goalMinutes.present) {
      map['goal_minutes'] = Variable<int>(goalMinutes.value);
    }
    if (focusGoalMinutes.present) {
      map['focus_goal_minutes'] = Variable<int>(focusGoalMinutes.value);
    }
    if (goalFocus.present) {
      map['goal_focus'] = Variable<bool>(goalFocus.value);
    }
    if (keyGoal.present) {
      map['key_goal'] = Variable<int>(keyGoal.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ActivityDaysCompanion(')
          ..write('day: $day, ')
          ..write('listeningMs: $listeningMs, ')
          ..write('musicMs: $musicMs, ')
          ..write('atmosphereMs: $atmosphereMs, ')
          ..write('keyPresses: $keyPresses, ')
          ..write('focusMs: $focusMs, ')
          ..write('pomodoroMs: $pomodoroMs, ')
          ..write('stopwatchMs: $stopwatchMs, ')
          ..write('goalMinutes: $goalMinutes, ')
          ..write('focusGoalMinutes: $focusGoalMinutes, ')
          ..write('goalFocus: $goalFocus, ')
          ..write('keyGoal: $keyGoal, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ListeningSourcesTable extends ListeningSources
    with TableInfo<$ListeningSourcesTable, ListeningSource> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ListeningSourcesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [kind, sourceId, name];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'listening_sources';
  @override
  VerificationContext validateIntegrity(
    Insertable<ListeningSource> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {kind, sourceId};
  @override
  ListeningSource map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ListeningSource(
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
    );
  }

  @override
  $ListeningSourcesTable createAlias(String alias) {
    return $ListeningSourcesTable(attachedDatabase, alias);
  }
}

class ListeningSource extends DataClass implements Insertable<ListeningSource> {
  final String kind;
  final String sourceId;
  final String name;
  const ListeningSource({
    required this.kind,
    required this.sourceId,
    required this.name,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['kind'] = Variable<String>(kind);
    map['source_id'] = Variable<String>(sourceId);
    map['name'] = Variable<String>(name);
    return map;
  }

  ListeningSourcesCompanion toCompanion(bool nullToAbsent) {
    return ListeningSourcesCompanion(
      kind: Value(kind),
      sourceId: Value(sourceId),
      name: Value(name),
    );
  }

  factory ListeningSource.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ListeningSource(
      kind: serializer.fromJson<String>(json['kind']),
      sourceId: serializer.fromJson<String>(json['sourceId']),
      name: serializer.fromJson<String>(json['name']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'kind': serializer.toJson<String>(kind),
      'sourceId': serializer.toJson<String>(sourceId),
      'name': serializer.toJson<String>(name),
    };
  }

  ListeningSource copyWith({String? kind, String? sourceId, String? name}) =>
      ListeningSource(
        kind: kind ?? this.kind,
        sourceId: sourceId ?? this.sourceId,
        name: name ?? this.name,
      );
  ListeningSource copyWithCompanion(ListeningSourcesCompanion data) {
    return ListeningSource(
      kind: data.kind.present ? data.kind.value : this.kind,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      name: data.name.present ? data.name.value : this.name,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ListeningSource(')
          ..write('kind: $kind, ')
          ..write('sourceId: $sourceId, ')
          ..write('name: $name')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(kind, sourceId, name);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ListeningSource &&
          other.kind == this.kind &&
          other.sourceId == this.sourceId &&
          other.name == this.name);
}

class ListeningSourcesCompanion extends UpdateCompanion<ListeningSource> {
  final Value<String> kind;
  final Value<String> sourceId;
  final Value<String> name;
  final Value<int> rowid;
  const ListeningSourcesCompanion({
    this.kind = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.name = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ListeningSourcesCompanion.insert({
    required String kind,
    required String sourceId,
    required String name,
    this.rowid = const Value.absent(),
  }) : kind = Value(kind),
       sourceId = Value(sourceId),
       name = Value(name);
  static Insertable<ListeningSource> custom({
    Expression<String>? kind,
    Expression<String>? sourceId,
    Expression<String>? name,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (kind != null) 'kind': kind,
      if (sourceId != null) 'source_id': sourceId,
      if (name != null) 'name': name,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ListeningSourcesCompanion copyWith({
    Value<String>? kind,
    Value<String>? sourceId,
    Value<String>? name,
    Value<int>? rowid,
  }) {
    return ListeningSourcesCompanion(
      kind: kind ?? this.kind,
      sourceId: sourceId ?? this.sourceId,
      name: name ?? this.name,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ListeningSourcesCompanion(')
          ..write('kind: $kind, ')
          ..write('sourceId: $sourceId, ')
          ..write('name: $name, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SourceDaysTable extends SourceDays
    with TableInfo<$SourceDaysTable, SourceDay> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SourceDaysTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _dayMeta = const VerificationMeta('day');
  @override
  late final GeneratedColumn<String> day = GeneratedColumn<String>(
    'day',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _listeningMsMeta = const VerificationMeta(
    'listeningMs',
  );
  @override
  late final GeneratedColumn<int> listeningMs = GeneratedColumn<int>(
    'listening_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [day, kind, sourceId, listeningMs];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'source_days';
  @override
  VerificationContext validateIntegrity(
    Insertable<SourceDay> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('day')) {
      context.handle(
        _dayMeta,
        day.isAcceptableOrUnknown(data['day']!, _dayMeta),
      );
    } else if (isInserting) {
      context.missing(_dayMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('listening_ms')) {
      context.handle(
        _listeningMsMeta,
        listeningMs.isAcceptableOrUnknown(
          data['listening_ms']!,
          _listeningMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_listeningMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {day, kind, sourceId};
  @override
  SourceDay map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SourceDay(
      day: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}day'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      )!,
      listeningMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}listening_ms'],
      )!,
    );
  }

  @override
  $SourceDaysTable createAlias(String alias) {
    return $SourceDaysTable(attachedDatabase, alias);
  }
}

class SourceDay extends DataClass implements Insertable<SourceDay> {
  final String day;
  final String kind;
  final String sourceId;
  final int listeningMs;
  const SourceDay({
    required this.day,
    required this.kind,
    required this.sourceId,
    required this.listeningMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['day'] = Variable<String>(day);
    map['kind'] = Variable<String>(kind);
    map['source_id'] = Variable<String>(sourceId);
    map['listening_ms'] = Variable<int>(listeningMs);
    return map;
  }

  SourceDaysCompanion toCompanion(bool nullToAbsent) {
    return SourceDaysCompanion(
      day: Value(day),
      kind: Value(kind),
      sourceId: Value(sourceId),
      listeningMs: Value(listeningMs),
    );
  }

  factory SourceDay.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SourceDay(
      day: serializer.fromJson<String>(json['day']),
      kind: serializer.fromJson<String>(json['kind']),
      sourceId: serializer.fromJson<String>(json['sourceId']),
      listeningMs: serializer.fromJson<int>(json['listeningMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'day': serializer.toJson<String>(day),
      'kind': serializer.toJson<String>(kind),
      'sourceId': serializer.toJson<String>(sourceId),
      'listeningMs': serializer.toJson<int>(listeningMs),
    };
  }

  SourceDay copyWith({
    String? day,
    String? kind,
    String? sourceId,
    int? listeningMs,
  }) => SourceDay(
    day: day ?? this.day,
    kind: kind ?? this.kind,
    sourceId: sourceId ?? this.sourceId,
    listeningMs: listeningMs ?? this.listeningMs,
  );
  SourceDay copyWithCompanion(SourceDaysCompanion data) {
    return SourceDay(
      day: data.day.present ? data.day.value : this.day,
      kind: data.kind.present ? data.kind.value : this.kind,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      listeningMs: data.listeningMs.present
          ? data.listeningMs.value
          : this.listeningMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SourceDay(')
          ..write('day: $day, ')
          ..write('kind: $kind, ')
          ..write('sourceId: $sourceId, ')
          ..write('listeningMs: $listeningMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(day, kind, sourceId, listeningMs);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SourceDay &&
          other.day == this.day &&
          other.kind == this.kind &&
          other.sourceId == this.sourceId &&
          other.listeningMs == this.listeningMs);
}

class SourceDaysCompanion extends UpdateCompanion<SourceDay> {
  final Value<String> day;
  final Value<String> kind;
  final Value<String> sourceId;
  final Value<int> listeningMs;
  final Value<int> rowid;
  const SourceDaysCompanion({
    this.day = const Value.absent(),
    this.kind = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.listeningMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SourceDaysCompanion.insert({
    required String day,
    required String kind,
    required String sourceId,
    required int listeningMs,
    this.rowid = const Value.absent(),
  }) : day = Value(day),
       kind = Value(kind),
       sourceId = Value(sourceId),
       listeningMs = Value(listeningMs);
  static Insertable<SourceDay> custom({
    Expression<String>? day,
    Expression<String>? kind,
    Expression<String>? sourceId,
    Expression<int>? listeningMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (day != null) 'day': day,
      if (kind != null) 'kind': kind,
      if (sourceId != null) 'source_id': sourceId,
      if (listeningMs != null) 'listening_ms': listeningMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SourceDaysCompanion copyWith({
    Value<String>? day,
    Value<String>? kind,
    Value<String>? sourceId,
    Value<int>? listeningMs,
    Value<int>? rowid,
  }) {
    return SourceDaysCompanion(
      day: day ?? this.day,
      kind: kind ?? this.kind,
      sourceId: sourceId ?? this.sourceId,
      listeningMs: listeningMs ?? this.listeningMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (day.present) {
      map['day'] = Variable<String>(day.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (listeningMs.present) {
      map['listening_ms'] = Variable<int>(listeningMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SourceDaysCompanion(')
          ..write('day: $day, ')
          ..write('kind: $kind, ')
          ..write('sourceId: $sourceId, ')
          ..write('listeningMs: $listeningMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StatisticsPreferencesTable extends StatisticsPreferences
    with TableInfo<$StatisticsPreferencesTable, StatisticsPreference> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StatisticsPreferencesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _collectingMeta = const VerificationMeta(
    'collecting',
  );
  @override
  late final GeneratedColumn<bool> collecting = GeneratedColumn<bool>(
    'collecting',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("collecting" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _goalMinutesMeta = const VerificationMeta(
    'goalMinutes',
  );
  @override
  late final GeneratedColumn<int> goalMinutes = GeneratedColumn<int>(
    'goal_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(30),
  );
  static const VerificationMeta _focusGoalMinutesMeta = const VerificationMeta(
    'focusGoalMinutes',
  );
  @override
  late final GeneratedColumn<int> focusGoalMinutes = GeneratedColumn<int>(
    'focus_goal_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(60),
  );
  static const VerificationMeta _goalFocusMeta = const VerificationMeta(
    'goalFocus',
  );
  @override
  late final GeneratedColumn<bool> goalFocus = GeneratedColumn<bool>(
    'goal_focus',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("goal_focus" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _keyGoalMeta = const VerificationMeta(
    'keyGoal',
  );
  @override
  late final GeneratedColumn<int> keyGoal = GeneratedColumn<int>(
    'key_goal',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _calendarKeysMeta = const VerificationMeta(
    'calendarKeys',
  );
  @override
  late final GeneratedColumn<bool> calendarKeys = GeneratedColumn<bool>(
    'calendar_keys',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("calendar_keys" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _calendarFocusMeta = const VerificationMeta(
    'calendarFocus',
  );
  @override
  late final GeneratedColumn<bool> calendarFocus = GeneratedColumn<bool>(
    'calendar_focus',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("calendar_focus" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    collecting,
    goalMinutes,
    focusGoalMinutes,
    goalFocus,
    keyGoal,
    calendarKeys,
    calendarFocus,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'statistics_preferences';
  @override
  VerificationContext validateIntegrity(
    Insertable<StatisticsPreference> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('collecting')) {
      context.handle(
        _collectingMeta,
        collecting.isAcceptableOrUnknown(data['collecting']!, _collectingMeta),
      );
    }
    if (data.containsKey('goal_minutes')) {
      context.handle(
        _goalMinutesMeta,
        goalMinutes.isAcceptableOrUnknown(
          data['goal_minutes']!,
          _goalMinutesMeta,
        ),
      );
    }
    if (data.containsKey('focus_goal_minutes')) {
      context.handle(
        _focusGoalMinutesMeta,
        focusGoalMinutes.isAcceptableOrUnknown(
          data['focus_goal_minutes']!,
          _focusGoalMinutesMeta,
        ),
      );
    }
    if (data.containsKey('goal_focus')) {
      context.handle(
        _goalFocusMeta,
        goalFocus.isAcceptableOrUnknown(data['goal_focus']!, _goalFocusMeta),
      );
    }
    if (data.containsKey('key_goal')) {
      context.handle(
        _keyGoalMeta,
        keyGoal.isAcceptableOrUnknown(data['key_goal']!, _keyGoalMeta),
      );
    }
    if (data.containsKey('calendar_keys')) {
      context.handle(
        _calendarKeysMeta,
        calendarKeys.isAcceptableOrUnknown(
          data['calendar_keys']!,
          _calendarKeysMeta,
        ),
      );
    }
    if (data.containsKey('calendar_focus')) {
      context.handle(
        _calendarFocusMeta,
        calendarFocus.isAcceptableOrUnknown(
          data['calendar_focus']!,
          _calendarFocusMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StatisticsPreference map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StatisticsPreference(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      collecting: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}collecting'],
      )!,
      goalMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}goal_minutes'],
      )!,
      focusGoalMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}focus_goal_minutes'],
      )!,
      goalFocus: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}goal_focus'],
      )!,
      keyGoal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}key_goal'],
      ),
      calendarKeys: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}calendar_keys'],
      )!,
      calendarFocus: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}calendar_focus'],
      )!,
    );
  }

  @override
  $StatisticsPreferencesTable createAlias(String alias) {
    return $StatisticsPreferencesTable(attachedDatabase, alias);
  }
}

class StatisticsPreference extends DataClass
    implements Insertable<StatisticsPreference> {
  final int id;
  final bool collecting;
  final int goalMinutes;
  final int focusGoalMinutes;
  final bool goalFocus;
  final int? keyGoal;
  final bool calendarKeys;
  final bool calendarFocus;
  const StatisticsPreference({
    required this.id,
    required this.collecting,
    required this.goalMinutes,
    required this.focusGoalMinutes,
    required this.goalFocus,
    this.keyGoal,
    required this.calendarKeys,
    required this.calendarFocus,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['collecting'] = Variable<bool>(collecting);
    map['goal_minutes'] = Variable<int>(goalMinutes);
    map['focus_goal_minutes'] = Variable<int>(focusGoalMinutes);
    map['goal_focus'] = Variable<bool>(goalFocus);
    if (!nullToAbsent || keyGoal != null) {
      map['key_goal'] = Variable<int>(keyGoal);
    }
    map['calendar_keys'] = Variable<bool>(calendarKeys);
    map['calendar_focus'] = Variable<bool>(calendarFocus);
    return map;
  }

  StatisticsPreferencesCompanion toCompanion(bool nullToAbsent) {
    return StatisticsPreferencesCompanion(
      id: Value(id),
      collecting: Value(collecting),
      goalMinutes: Value(goalMinutes),
      focusGoalMinutes: Value(focusGoalMinutes),
      goalFocus: Value(goalFocus),
      keyGoal: keyGoal == null && nullToAbsent
          ? const Value.absent()
          : Value(keyGoal),
      calendarKeys: Value(calendarKeys),
      calendarFocus: Value(calendarFocus),
    );
  }

  factory StatisticsPreference.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StatisticsPreference(
      id: serializer.fromJson<int>(json['id']),
      collecting: serializer.fromJson<bool>(json['collecting']),
      goalMinutes: serializer.fromJson<int>(json['goalMinutes']),
      focusGoalMinutes: serializer.fromJson<int>(json['focusGoalMinutes']),
      goalFocus: serializer.fromJson<bool>(json['goalFocus']),
      keyGoal: serializer.fromJson<int?>(json['keyGoal']),
      calendarKeys: serializer.fromJson<bool>(json['calendarKeys']),
      calendarFocus: serializer.fromJson<bool>(json['calendarFocus']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'collecting': serializer.toJson<bool>(collecting),
      'goalMinutes': serializer.toJson<int>(goalMinutes),
      'focusGoalMinutes': serializer.toJson<int>(focusGoalMinutes),
      'goalFocus': serializer.toJson<bool>(goalFocus),
      'keyGoal': serializer.toJson<int?>(keyGoal),
      'calendarKeys': serializer.toJson<bool>(calendarKeys),
      'calendarFocus': serializer.toJson<bool>(calendarFocus),
    };
  }

  StatisticsPreference copyWith({
    int? id,
    bool? collecting,
    int? goalMinutes,
    int? focusGoalMinutes,
    bool? goalFocus,
    Value<int?> keyGoal = const Value.absent(),
    bool? calendarKeys,
    bool? calendarFocus,
  }) => StatisticsPreference(
    id: id ?? this.id,
    collecting: collecting ?? this.collecting,
    goalMinutes: goalMinutes ?? this.goalMinutes,
    focusGoalMinutes: focusGoalMinutes ?? this.focusGoalMinutes,
    goalFocus: goalFocus ?? this.goalFocus,
    keyGoal: keyGoal.present ? keyGoal.value : this.keyGoal,
    calendarKeys: calendarKeys ?? this.calendarKeys,
    calendarFocus: calendarFocus ?? this.calendarFocus,
  );
  StatisticsPreference copyWithCompanion(StatisticsPreferencesCompanion data) {
    return StatisticsPreference(
      id: data.id.present ? data.id.value : this.id,
      collecting: data.collecting.present
          ? data.collecting.value
          : this.collecting,
      goalMinutes: data.goalMinutes.present
          ? data.goalMinutes.value
          : this.goalMinutes,
      focusGoalMinutes: data.focusGoalMinutes.present
          ? data.focusGoalMinutes.value
          : this.focusGoalMinutes,
      goalFocus: data.goalFocus.present ? data.goalFocus.value : this.goalFocus,
      keyGoal: data.keyGoal.present ? data.keyGoal.value : this.keyGoal,
      calendarKeys: data.calendarKeys.present
          ? data.calendarKeys.value
          : this.calendarKeys,
      calendarFocus: data.calendarFocus.present
          ? data.calendarFocus.value
          : this.calendarFocus,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StatisticsPreference(')
          ..write('id: $id, ')
          ..write('collecting: $collecting, ')
          ..write('goalMinutes: $goalMinutes, ')
          ..write('focusGoalMinutes: $focusGoalMinutes, ')
          ..write('goalFocus: $goalFocus, ')
          ..write('keyGoal: $keyGoal, ')
          ..write('calendarKeys: $calendarKeys, ')
          ..write('calendarFocus: $calendarFocus')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    collecting,
    goalMinutes,
    focusGoalMinutes,
    goalFocus,
    keyGoal,
    calendarKeys,
    calendarFocus,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StatisticsPreference &&
          other.id == this.id &&
          other.collecting == this.collecting &&
          other.goalMinutes == this.goalMinutes &&
          other.focusGoalMinutes == this.focusGoalMinutes &&
          other.goalFocus == this.goalFocus &&
          other.keyGoal == this.keyGoal &&
          other.calendarKeys == this.calendarKeys &&
          other.calendarFocus == this.calendarFocus);
}

class StatisticsPreferencesCompanion
    extends UpdateCompanion<StatisticsPreference> {
  final Value<int> id;
  final Value<bool> collecting;
  final Value<int> goalMinutes;
  final Value<int> focusGoalMinutes;
  final Value<bool> goalFocus;
  final Value<int?> keyGoal;
  final Value<bool> calendarKeys;
  final Value<bool> calendarFocus;
  const StatisticsPreferencesCompanion({
    this.id = const Value.absent(),
    this.collecting = const Value.absent(),
    this.goalMinutes = const Value.absent(),
    this.focusGoalMinutes = const Value.absent(),
    this.goalFocus = const Value.absent(),
    this.keyGoal = const Value.absent(),
    this.calendarKeys = const Value.absent(),
    this.calendarFocus = const Value.absent(),
  });
  StatisticsPreferencesCompanion.insert({
    this.id = const Value.absent(),
    this.collecting = const Value.absent(),
    this.goalMinutes = const Value.absent(),
    this.focusGoalMinutes = const Value.absent(),
    this.goalFocus = const Value.absent(),
    this.keyGoal = const Value.absent(),
    this.calendarKeys = const Value.absent(),
    this.calendarFocus = const Value.absent(),
  });
  static Insertable<StatisticsPreference> custom({
    Expression<int>? id,
    Expression<bool>? collecting,
    Expression<int>? goalMinutes,
    Expression<int>? focusGoalMinutes,
    Expression<bool>? goalFocus,
    Expression<int>? keyGoal,
    Expression<bool>? calendarKeys,
    Expression<bool>? calendarFocus,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (collecting != null) 'collecting': collecting,
      if (goalMinutes != null) 'goal_minutes': goalMinutes,
      if (focusGoalMinutes != null) 'focus_goal_minutes': focusGoalMinutes,
      if (goalFocus != null) 'goal_focus': goalFocus,
      if (keyGoal != null) 'key_goal': keyGoal,
      if (calendarKeys != null) 'calendar_keys': calendarKeys,
      if (calendarFocus != null) 'calendar_focus': calendarFocus,
    });
  }

  StatisticsPreferencesCompanion copyWith({
    Value<int>? id,
    Value<bool>? collecting,
    Value<int>? goalMinutes,
    Value<int>? focusGoalMinutes,
    Value<bool>? goalFocus,
    Value<int?>? keyGoal,
    Value<bool>? calendarKeys,
    Value<bool>? calendarFocus,
  }) {
    return StatisticsPreferencesCompanion(
      id: id ?? this.id,
      collecting: collecting ?? this.collecting,
      goalMinutes: goalMinutes ?? this.goalMinutes,
      focusGoalMinutes: focusGoalMinutes ?? this.focusGoalMinutes,
      goalFocus: goalFocus ?? this.goalFocus,
      keyGoal: keyGoal ?? this.keyGoal,
      calendarKeys: calendarKeys ?? this.calendarKeys,
      calendarFocus: calendarFocus ?? this.calendarFocus,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (collecting.present) {
      map['collecting'] = Variable<bool>(collecting.value);
    }
    if (goalMinutes.present) {
      map['goal_minutes'] = Variable<int>(goalMinutes.value);
    }
    if (focusGoalMinutes.present) {
      map['focus_goal_minutes'] = Variable<int>(focusGoalMinutes.value);
    }
    if (goalFocus.present) {
      map['goal_focus'] = Variable<bool>(goalFocus.value);
    }
    if (keyGoal.present) {
      map['key_goal'] = Variable<int>(keyGoal.value);
    }
    if (calendarKeys.present) {
      map['calendar_keys'] = Variable<bool>(calendarKeys.value);
    }
    if (calendarFocus.present) {
      map['calendar_focus'] = Variable<bool>(calendarFocus.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StatisticsPreferencesCompanion(')
          ..write('id: $id, ')
          ..write('collecting: $collecting, ')
          ..write('goalMinutes: $goalMinutes, ')
          ..write('focusGoalMinutes: $focusGoalMinutes, ')
          ..write('goalFocus: $goalFocus, ')
          ..write('keyGoal: $keyGoal, ')
          ..write('calendarKeys: $calendarKeys, ')
          ..write('calendarFocus: $calendarFocus')
          ..write(')'))
        .toString();
  }
}

abstract class _$StatisticsDatabase extends GeneratedDatabase {
  _$StatisticsDatabase(QueryExecutor e) : super(e);
  $StatisticsDatabaseManager get managers => $StatisticsDatabaseManager(this);
  late final $ActivityDaysTable activityDays = $ActivityDaysTable(this);
  late final $ListeningSourcesTable listeningSources = $ListeningSourcesTable(
    this,
  );
  late final $SourceDaysTable sourceDays = $SourceDaysTable(this);
  late final $StatisticsPreferencesTable statisticsPreferences =
      $StatisticsPreferencesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    activityDays,
    listeningSources,
    sourceDays,
    statisticsPreferences,
  ];
}

typedef $$ActivityDaysTableCreateCompanionBuilder =
    ActivityDaysCompanion Function({
      required String day,
      Value<int> listeningMs,
      Value<int> musicMs,
      Value<int> atmosphereMs,
      Value<int> keyPresses,
      Value<int> focusMs,
      Value<int> pomodoroMs,
      Value<int> stopwatchMs,
      required int goalMinutes,
      Value<int> focusGoalMinutes,
      Value<bool> goalFocus,
      Value<int?> keyGoal,
      Value<int> rowid,
    });
typedef $$ActivityDaysTableUpdateCompanionBuilder =
    ActivityDaysCompanion Function({
      Value<String> day,
      Value<int> listeningMs,
      Value<int> musicMs,
      Value<int> atmosphereMs,
      Value<int> keyPresses,
      Value<int> focusMs,
      Value<int> pomodoroMs,
      Value<int> stopwatchMs,
      Value<int> goalMinutes,
      Value<int> focusGoalMinutes,
      Value<bool> goalFocus,
      Value<int?> keyGoal,
      Value<int> rowid,
    });

class $$ActivityDaysTableFilterComposer
    extends Composer<_$StatisticsDatabase, $ActivityDaysTable> {
  $$ActivityDaysTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get day => $composableBuilder(
    column: $table.day,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get listeningMs => $composableBuilder(
    column: $table.listeningMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get musicMs => $composableBuilder(
    column: $table.musicMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get atmosphereMs => $composableBuilder(
    column: $table.atmosphereMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get keyPresses => $composableBuilder(
    column: $table.keyPresses,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get focusMs => $composableBuilder(
    column: $table.focusMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pomodoroMs => $composableBuilder(
    column: $table.pomodoroMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get stopwatchMs => $composableBuilder(
    column: $table.stopwatchMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get goalMinutes => $composableBuilder(
    column: $table.goalMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get focusGoalMinutes => $composableBuilder(
    column: $table.focusGoalMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get goalFocus => $composableBuilder(
    column: $table.goalFocus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get keyGoal => $composableBuilder(
    column: $table.keyGoal,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ActivityDaysTableOrderingComposer
    extends Composer<_$StatisticsDatabase, $ActivityDaysTable> {
  $$ActivityDaysTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get day => $composableBuilder(
    column: $table.day,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get listeningMs => $composableBuilder(
    column: $table.listeningMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get musicMs => $composableBuilder(
    column: $table.musicMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get atmosphereMs => $composableBuilder(
    column: $table.atmosphereMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get keyPresses => $composableBuilder(
    column: $table.keyPresses,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get focusMs => $composableBuilder(
    column: $table.focusMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pomodoroMs => $composableBuilder(
    column: $table.pomodoroMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get stopwatchMs => $composableBuilder(
    column: $table.stopwatchMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get goalMinutes => $composableBuilder(
    column: $table.goalMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get focusGoalMinutes => $composableBuilder(
    column: $table.focusGoalMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get goalFocus => $composableBuilder(
    column: $table.goalFocus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get keyGoal => $composableBuilder(
    column: $table.keyGoal,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ActivityDaysTableAnnotationComposer
    extends Composer<_$StatisticsDatabase, $ActivityDaysTable> {
  $$ActivityDaysTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get day =>
      $composableBuilder(column: $table.day, builder: (column) => column);

  GeneratedColumn<int> get listeningMs => $composableBuilder(
    column: $table.listeningMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get musicMs =>
      $composableBuilder(column: $table.musicMs, builder: (column) => column);

  GeneratedColumn<int> get atmosphereMs => $composableBuilder(
    column: $table.atmosphereMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get keyPresses => $composableBuilder(
    column: $table.keyPresses,
    builder: (column) => column,
  );

  GeneratedColumn<int> get focusMs =>
      $composableBuilder(column: $table.focusMs, builder: (column) => column);

  GeneratedColumn<int> get pomodoroMs => $composableBuilder(
    column: $table.pomodoroMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get stopwatchMs => $composableBuilder(
    column: $table.stopwatchMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get goalMinutes => $composableBuilder(
    column: $table.goalMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get focusGoalMinutes => $composableBuilder(
    column: $table.focusGoalMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get goalFocus =>
      $composableBuilder(column: $table.goalFocus, builder: (column) => column);

  GeneratedColumn<int> get keyGoal =>
      $composableBuilder(column: $table.keyGoal, builder: (column) => column);
}

class $$ActivityDaysTableTableManager
    extends
        RootTableManager<
          _$StatisticsDatabase,
          $ActivityDaysTable,
          ActivityDay,
          $$ActivityDaysTableFilterComposer,
          $$ActivityDaysTableOrderingComposer,
          $$ActivityDaysTableAnnotationComposer,
          $$ActivityDaysTableCreateCompanionBuilder,
          $$ActivityDaysTableUpdateCompanionBuilder,
          (
            ActivityDay,
            BaseReferences<
              _$StatisticsDatabase,
              $ActivityDaysTable,
              ActivityDay
            >,
          ),
          ActivityDay,
          PrefetchHooks Function()
        > {
  $$ActivityDaysTableTableManager(
    _$StatisticsDatabase db,
    $ActivityDaysTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ActivityDaysTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ActivityDaysTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ActivityDaysTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> day = const Value.absent(),
                Value<int> listeningMs = const Value.absent(),
                Value<int> musicMs = const Value.absent(),
                Value<int> atmosphereMs = const Value.absent(),
                Value<int> keyPresses = const Value.absent(),
                Value<int> focusMs = const Value.absent(),
                Value<int> pomodoroMs = const Value.absent(),
                Value<int> stopwatchMs = const Value.absent(),
                Value<int> goalMinutes = const Value.absent(),
                Value<int> focusGoalMinutes = const Value.absent(),
                Value<bool> goalFocus = const Value.absent(),
                Value<int?> keyGoal = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ActivityDaysCompanion(
                day: day,
                listeningMs: listeningMs,
                musicMs: musicMs,
                atmosphereMs: atmosphereMs,
                keyPresses: keyPresses,
                focusMs: focusMs,
                pomodoroMs: pomodoroMs,
                stopwatchMs: stopwatchMs,
                goalMinutes: goalMinutes,
                focusGoalMinutes: focusGoalMinutes,
                goalFocus: goalFocus,
                keyGoal: keyGoal,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String day,
                Value<int> listeningMs = const Value.absent(),
                Value<int> musicMs = const Value.absent(),
                Value<int> atmosphereMs = const Value.absent(),
                Value<int> keyPresses = const Value.absent(),
                Value<int> focusMs = const Value.absent(),
                Value<int> pomodoroMs = const Value.absent(),
                Value<int> stopwatchMs = const Value.absent(),
                required int goalMinutes,
                Value<int> focusGoalMinutes = const Value.absent(),
                Value<bool> goalFocus = const Value.absent(),
                Value<int?> keyGoal = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ActivityDaysCompanion.insert(
                day: day,
                listeningMs: listeningMs,
                musicMs: musicMs,
                atmosphereMs: atmosphereMs,
                keyPresses: keyPresses,
                focusMs: focusMs,
                pomodoroMs: pomodoroMs,
                stopwatchMs: stopwatchMs,
                goalMinutes: goalMinutes,
                focusGoalMinutes: focusGoalMinutes,
                goalFocus: goalFocus,
                keyGoal: keyGoal,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ActivityDaysTable, ActivityDay>(table),
                  BaseReferences<
                    _$StatisticsDatabase,
                    $ActivityDaysTable,
                    ActivityDay
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ActivityDaysTableProcessedTableManager =
    ProcessedTableManager<
      _$StatisticsDatabase,
      $ActivityDaysTable,
      ActivityDay,
      $$ActivityDaysTableFilterComposer,
      $$ActivityDaysTableOrderingComposer,
      $$ActivityDaysTableAnnotationComposer,
      $$ActivityDaysTableCreateCompanionBuilder,
      $$ActivityDaysTableUpdateCompanionBuilder,
      (
        ActivityDay,
        BaseReferences<_$StatisticsDatabase, $ActivityDaysTable, ActivityDay>,
      ),
      ActivityDay,
      PrefetchHooks Function()
    >;
typedef $$ListeningSourcesTableCreateCompanionBuilder =
    ListeningSourcesCompanion Function({
      required String kind,
      required String sourceId,
      required String name,
      Value<int> rowid,
    });
typedef $$ListeningSourcesTableUpdateCompanionBuilder =
    ListeningSourcesCompanion Function({
      Value<String> kind,
      Value<String> sourceId,
      Value<String> name,
      Value<int> rowid,
    });

class $$ListeningSourcesTableFilterComposer
    extends Composer<_$StatisticsDatabase, $ListeningSourcesTable> {
  $$ListeningSourcesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ListeningSourcesTableOrderingComposer
    extends Composer<_$StatisticsDatabase, $ListeningSourcesTable> {
  $$ListeningSourcesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ListeningSourcesTableAnnotationComposer
    extends Composer<_$StatisticsDatabase, $ListeningSourcesTable> {
  $$ListeningSourcesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get sourceId =>
      $composableBuilder(column: $table.sourceId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);
}

class $$ListeningSourcesTableTableManager
    extends
        RootTableManager<
          _$StatisticsDatabase,
          $ListeningSourcesTable,
          ListeningSource,
          $$ListeningSourcesTableFilterComposer,
          $$ListeningSourcesTableOrderingComposer,
          $$ListeningSourcesTableAnnotationComposer,
          $$ListeningSourcesTableCreateCompanionBuilder,
          $$ListeningSourcesTableUpdateCompanionBuilder,
          (
            ListeningSource,
            BaseReferences<
              _$StatisticsDatabase,
              $ListeningSourcesTable,
              ListeningSource
            >,
          ),
          ListeningSource,
          PrefetchHooks Function()
        > {
  $$ListeningSourcesTableTableManager(
    _$StatisticsDatabase db,
    $ListeningSourcesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ListeningSourcesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ListeningSourcesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ListeningSourcesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> kind = const Value.absent(),
                Value<String> sourceId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ListeningSourcesCompanion(
                kind: kind,
                sourceId: sourceId,
                name: name,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String kind,
                required String sourceId,
                required String name,
                Value<int> rowid = const Value.absent(),
              }) => ListeningSourcesCompanion.insert(
                kind: kind,
                sourceId: sourceId,
                name: name,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ListeningSourcesTable, ListeningSource>(table),
                  BaseReferences<
                    _$StatisticsDatabase,
                    $ListeningSourcesTable,
                    ListeningSource
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ListeningSourcesTableProcessedTableManager =
    ProcessedTableManager<
      _$StatisticsDatabase,
      $ListeningSourcesTable,
      ListeningSource,
      $$ListeningSourcesTableFilterComposer,
      $$ListeningSourcesTableOrderingComposer,
      $$ListeningSourcesTableAnnotationComposer,
      $$ListeningSourcesTableCreateCompanionBuilder,
      $$ListeningSourcesTableUpdateCompanionBuilder,
      (
        ListeningSource,
        BaseReferences<
          _$StatisticsDatabase,
          $ListeningSourcesTable,
          ListeningSource
        >,
      ),
      ListeningSource,
      PrefetchHooks Function()
    >;
typedef $$SourceDaysTableCreateCompanionBuilder = SourceDaysCompanion Function({
  required String day,
  required String kind,
  required String sourceId,
  required int listeningMs,
  Value<int> rowid,
});
typedef $$SourceDaysTableUpdateCompanionBuilder = SourceDaysCompanion Function({
  Value<String> day,
  Value<String> kind,
  Value<String> sourceId,
  Value<int> listeningMs,
  Value<int> rowid,
});

class $$SourceDaysTableFilterComposer
    extends Composer<_$StatisticsDatabase, $SourceDaysTable> {
  $$SourceDaysTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get day => $composableBuilder(
    column: $table.day,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get listeningMs => $composableBuilder(
    column: $table.listeningMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SourceDaysTableOrderingComposer
    extends Composer<_$StatisticsDatabase, $SourceDaysTable> {
  $$SourceDaysTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get day => $composableBuilder(
    column: $table.day,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get listeningMs => $composableBuilder(
    column: $table.listeningMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SourceDaysTableAnnotationComposer
    extends Composer<_$StatisticsDatabase, $SourceDaysTable> {
  $$SourceDaysTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get day =>
      $composableBuilder(column: $table.day, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get sourceId =>
      $composableBuilder(column: $table.sourceId, builder: (column) => column);

  GeneratedColumn<int> get listeningMs => $composableBuilder(
    column: $table.listeningMs,
    builder: (column) => column,
  );
}

class $$SourceDaysTableTableManager
    extends
        RootTableManager<
          _$StatisticsDatabase,
          $SourceDaysTable,
          SourceDay,
          $$SourceDaysTableFilterComposer,
          $$SourceDaysTableOrderingComposer,
          $$SourceDaysTableAnnotationComposer,
          $$SourceDaysTableCreateCompanionBuilder,
          $$SourceDaysTableUpdateCompanionBuilder,
          (
            SourceDay,
            BaseReferences<_$StatisticsDatabase, $SourceDaysTable, SourceDay>,
          ),
          SourceDay,
          PrefetchHooks Function()
        > {
  $$SourceDaysTableTableManager(_$StatisticsDatabase db, $SourceDaysTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SourceDaysTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SourceDaysTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SourceDaysTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> day = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> sourceId = const Value.absent(),
                Value<int> listeningMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SourceDaysCompanion(
                day: day,
                kind: kind,
                sourceId: sourceId,
                listeningMs: listeningMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String day,
                required String kind,
                required String sourceId,
                required int listeningMs,
                Value<int> rowid = const Value.absent(),
              }) => SourceDaysCompanion.insert(
                day: day,
                kind: kind,
                sourceId: sourceId,
                listeningMs: listeningMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SourceDaysTable, SourceDay>(table),
                  BaseReferences<
                    _$StatisticsDatabase,
                    $SourceDaysTable,
                    SourceDay
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SourceDaysTableProcessedTableManager =
    ProcessedTableManager<
      _$StatisticsDatabase,
      $SourceDaysTable,
      SourceDay,
      $$SourceDaysTableFilterComposer,
      $$SourceDaysTableOrderingComposer,
      $$SourceDaysTableAnnotationComposer,
      $$SourceDaysTableCreateCompanionBuilder,
      $$SourceDaysTableUpdateCompanionBuilder,
      (
        SourceDay,
        BaseReferences<_$StatisticsDatabase, $SourceDaysTable, SourceDay>,
      ),
      SourceDay,
      PrefetchHooks Function()
    >;
typedef $$StatisticsPreferencesTableCreateCompanionBuilder =
    StatisticsPreferencesCompanion Function({
      Value<int> id,
      Value<bool> collecting,
      Value<int> goalMinutes,
      Value<int> focusGoalMinutes,
      Value<bool> goalFocus,
      Value<int?> keyGoal,
      Value<bool> calendarKeys,
      Value<bool> calendarFocus,
    });
typedef $$StatisticsPreferencesTableUpdateCompanionBuilder =
    StatisticsPreferencesCompanion Function({
      Value<int> id,
      Value<bool> collecting,
      Value<int> goalMinutes,
      Value<int> focusGoalMinutes,
      Value<bool> goalFocus,
      Value<int?> keyGoal,
      Value<bool> calendarKeys,
      Value<bool> calendarFocus,
    });

class $$StatisticsPreferencesTableFilterComposer
    extends Composer<_$StatisticsDatabase, $StatisticsPreferencesTable> {
  $$StatisticsPreferencesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get collecting => $composableBuilder(
    column: $table.collecting,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get goalMinutes => $composableBuilder(
    column: $table.goalMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get focusGoalMinutes => $composableBuilder(
    column: $table.focusGoalMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get goalFocus => $composableBuilder(
    column: $table.goalFocus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get keyGoal => $composableBuilder(
    column: $table.keyGoal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get calendarKeys => $composableBuilder(
    column: $table.calendarKeys,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get calendarFocus => $composableBuilder(
    column: $table.calendarFocus,
    builder: (column) => ColumnFilters(column),
  );
}

class $$StatisticsPreferencesTableOrderingComposer
    extends Composer<_$StatisticsDatabase, $StatisticsPreferencesTable> {
  $$StatisticsPreferencesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get collecting => $composableBuilder(
    column: $table.collecting,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get goalMinutes => $composableBuilder(
    column: $table.goalMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get focusGoalMinutes => $composableBuilder(
    column: $table.focusGoalMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get goalFocus => $composableBuilder(
    column: $table.goalFocus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get keyGoal => $composableBuilder(
    column: $table.keyGoal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get calendarKeys => $composableBuilder(
    column: $table.calendarKeys,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get calendarFocus => $composableBuilder(
    column: $table.calendarFocus,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StatisticsPreferencesTableAnnotationComposer
    extends Composer<_$StatisticsDatabase, $StatisticsPreferencesTable> {
  $$StatisticsPreferencesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<bool> get collecting => $composableBuilder(
    column: $table.collecting,
    builder: (column) => column,
  );

  GeneratedColumn<int> get goalMinutes => $composableBuilder(
    column: $table.goalMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get focusGoalMinutes => $composableBuilder(
    column: $table.focusGoalMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get goalFocus =>
      $composableBuilder(column: $table.goalFocus, builder: (column) => column);

  GeneratedColumn<int> get keyGoal =>
      $composableBuilder(column: $table.keyGoal, builder: (column) => column);

  GeneratedColumn<bool> get calendarKeys => $composableBuilder(
    column: $table.calendarKeys,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get calendarFocus => $composableBuilder(
    column: $table.calendarFocus,
    builder: (column) => column,
  );
}

class $$StatisticsPreferencesTableTableManager
    extends
        RootTableManager<
          _$StatisticsDatabase,
          $StatisticsPreferencesTable,
          StatisticsPreference,
          $$StatisticsPreferencesTableFilterComposer,
          $$StatisticsPreferencesTableOrderingComposer,
          $$StatisticsPreferencesTableAnnotationComposer,
          $$StatisticsPreferencesTableCreateCompanionBuilder,
          $$StatisticsPreferencesTableUpdateCompanionBuilder,
          (
            StatisticsPreference,
            BaseReferences<
              _$StatisticsDatabase,
              $StatisticsPreferencesTable,
              StatisticsPreference
            >,
          ),
          StatisticsPreference,
          PrefetchHooks Function()
        > {
  $$StatisticsPreferencesTableTableManager(
    _$StatisticsDatabase db,
    $StatisticsPreferencesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StatisticsPreferencesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$StatisticsPreferencesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$StatisticsPreferencesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<bool> collecting = const Value.absent(),
                Value<int> goalMinutes = const Value.absent(),
                Value<int> focusGoalMinutes = const Value.absent(),
                Value<bool> goalFocus = const Value.absent(),
                Value<int?> keyGoal = const Value.absent(),
                Value<bool> calendarKeys = const Value.absent(),
                Value<bool> calendarFocus = const Value.absent(),
              }) => StatisticsPreferencesCompanion(
                id: id,
                collecting: collecting,
                goalMinutes: goalMinutes,
                focusGoalMinutes: focusGoalMinutes,
                goalFocus: goalFocus,
                keyGoal: keyGoal,
                calendarKeys: calendarKeys,
                calendarFocus: calendarFocus,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<bool> collecting = const Value.absent(),
                Value<int> goalMinutes = const Value.absent(),
                Value<int> focusGoalMinutes = const Value.absent(),
                Value<bool> goalFocus = const Value.absent(),
                Value<int?> keyGoal = const Value.absent(),
                Value<bool> calendarKeys = const Value.absent(),
                Value<bool> calendarFocus = const Value.absent(),
              }) => StatisticsPreferencesCompanion.insert(
                id: id,
                collecting: collecting,
                goalMinutes: goalMinutes,
                focusGoalMinutes: focusGoalMinutes,
                goalFocus: goalFocus,
                keyGoal: keyGoal,
                calendarKeys: calendarKeys,
                calendarFocus: calendarFocus,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $StatisticsPreferencesTable,
                    StatisticsPreference
                  >(table),
                  BaseReferences<
                    _$StatisticsDatabase,
                    $StatisticsPreferencesTable,
                    StatisticsPreference
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$StatisticsPreferencesTableProcessedTableManager =
    ProcessedTableManager<
      _$StatisticsDatabase,
      $StatisticsPreferencesTable,
      StatisticsPreference,
      $$StatisticsPreferencesTableFilterComposer,
      $$StatisticsPreferencesTableOrderingComposer,
      $$StatisticsPreferencesTableAnnotationComposer,
      $$StatisticsPreferencesTableCreateCompanionBuilder,
      $$StatisticsPreferencesTableUpdateCompanionBuilder,
      (
        StatisticsPreference,
        BaseReferences<
          _$StatisticsDatabase,
          $StatisticsPreferencesTable,
          StatisticsPreference
        >,
      ),
      StatisticsPreference,
      PrefetchHooks Function()
    >;

class $StatisticsDatabaseManager {
  final _$StatisticsDatabase _db;
  $StatisticsDatabaseManager(this._db);
  $$ActivityDaysTableTableManager get activityDays =>
      $$ActivityDaysTableTableManager(_db, _db.activityDays);
  $$ListeningSourcesTableTableManager get listeningSources =>
      $$ListeningSourcesTableTableManager(_db, _db.listeningSources);
  $$SourceDaysTableTableManager get sourceDays =>
      $$SourceDaysTableTableManager(_db, _db.sourceDays);
  $$StatisticsPreferencesTableTableManager get statisticsPreferences =>
      $$StatisticsPreferencesTableTableManager(_db, _db.statisticsPreferences);
}
