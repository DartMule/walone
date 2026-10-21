// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'music_database.dart';

// ignore_for_file: type=lint
class $LibraryTracksTable extends LibraryTracks
    with TableInfo<$LibraryTracksTable, LibraryTrack> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LibraryTracksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _filenameMeta = const VerificationMeta(
    'filename',
  );
  @override
  late final GeneratedColumn<String> filename = GeneratedColumn<String>(
    'filename',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _durationMeta = const VerificationMeta(
    'duration',
  );
  @override
  late final GeneratedColumn<double> duration = GeneratedColumn<double>(
    'duration',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ordinalMeta = const VerificationMeta(
    'ordinal',
  );
  @override
  late final GeneratedColumn<int> ordinal = GeneratedColumn<int>(
    'ordinal',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    filename,
    duration,
    sourceId,
    ordinal,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'library_tracks';
  @override
  VerificationContext validateIntegrity(
    Insertable<LibraryTrack> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('filename')) {
      context.handle(
        _filenameMeta,
        filename.isAcceptableOrUnknown(data['filename']!, _filenameMeta),
      );
    } else if (isInserting) {
      context.missing(_filenameMeta);
    }
    if (data.containsKey('duration')) {
      context.handle(
        _durationMeta,
        duration.isAcceptableOrUnknown(data['duration']!, _durationMeta),
      );
    } else if (isInserting) {
      context.missing(_durationMeta);
    }
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    }
    if (data.containsKey('ordinal')) {
      context.handle(
        _ordinalMeta,
        ordinal.isAcceptableOrUnknown(data['ordinal']!, _ordinalMeta),
      );
    } else if (isInserting) {
      context.missing(_ordinalMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LibraryTrack map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LibraryTrack(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      filename: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}filename'],
      )!,
      duration: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}duration'],
      )!,
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      ),
      ordinal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ordinal'],
      )!,
    );
  }

  @override
  $LibraryTracksTable createAlias(String alias) {
    return $LibraryTracksTable(attachedDatabase, alias);
  }
}

class LibraryTrack extends DataClass implements Insertable<LibraryTrack> {
  final String id;
  final String title;
  final String filename;
  final double duration;
  final String? sourceId;
  final int ordinal;
  const LibraryTrack({
    required this.id,
    required this.title,
    required this.filename,
    required this.duration,
    this.sourceId,
    required this.ordinal,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['filename'] = Variable<String>(filename);
    map['duration'] = Variable<double>(duration);
    if (!nullToAbsent || sourceId != null) {
      map['source_id'] = Variable<String>(sourceId);
    }
    map['ordinal'] = Variable<int>(ordinal);
    return map;
  }

  LibraryTracksCompanion toCompanion(bool nullToAbsent) {
    return LibraryTracksCompanion(
      id: Value(id),
      title: Value(title),
      filename: Value(filename),
      duration: Value(duration),
      sourceId: sourceId == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceId),
      ordinal: Value(ordinal),
    );
  }

  factory LibraryTrack.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LibraryTrack(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      filename: serializer.fromJson<String>(json['filename']),
      duration: serializer.fromJson<double>(json['duration']),
      sourceId: serializer.fromJson<String?>(json['sourceId']),
      ordinal: serializer.fromJson<int>(json['ordinal']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'filename': serializer.toJson<String>(filename),
      'duration': serializer.toJson<double>(duration),
      'sourceId': serializer.toJson<String?>(sourceId),
      'ordinal': serializer.toJson<int>(ordinal),
    };
  }

  LibraryTrack copyWith({
    String? id,
    String? title,
    String? filename,
    double? duration,
    Value<String?> sourceId = const Value.absent(),
    int? ordinal,
  }) => LibraryTrack(
    id: id ?? this.id,
    title: title ?? this.title,
    filename: filename ?? this.filename,
    duration: duration ?? this.duration,
    sourceId: sourceId.present ? sourceId.value : this.sourceId,
    ordinal: ordinal ?? this.ordinal,
  );
  LibraryTrack copyWithCompanion(LibraryTracksCompanion data) {
    return LibraryTrack(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      filename: data.filename.present ? data.filename.value : this.filename,
      duration: data.duration.present ? data.duration.value : this.duration,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      ordinal: data.ordinal.present ? data.ordinal.value : this.ordinal,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LibraryTrack(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('filename: $filename, ')
          ..write('duration: $duration, ')
          ..write('sourceId: $sourceId, ')
          ..write('ordinal: $ordinal')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, title, filename, duration, sourceId, ordinal);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LibraryTrack &&
          other.id == this.id &&
          other.title == this.title &&
          other.filename == this.filename &&
          other.duration == this.duration &&
          other.sourceId == this.sourceId &&
          other.ordinal == this.ordinal);
}

class LibraryTracksCompanion extends UpdateCompanion<LibraryTrack> {
  final Value<String> id;
  final Value<String> title;
  final Value<String> filename;
  final Value<double> duration;
  final Value<String?> sourceId;
  final Value<int> ordinal;
  final Value<int> rowid;
  const LibraryTracksCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.filename = const Value.absent(),
    this.duration = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.ordinal = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LibraryTracksCompanion.insert({
    required String id,
    required String title,
    required String filename,
    required double duration,
    this.sourceId = const Value.absent(),
    required int ordinal,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       filename = Value(filename),
       duration = Value(duration),
       ordinal = Value(ordinal);
  static Insertable<LibraryTrack> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? filename,
    Expression<double>? duration,
    Expression<String>? sourceId,
    Expression<int>? ordinal,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (filename != null) 'filename': filename,
      if (duration != null) 'duration': duration,
      if (sourceId != null) 'source_id': sourceId,
      if (ordinal != null) 'ordinal': ordinal,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LibraryTracksCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String>? filename,
    Value<double>? duration,
    Value<String?>? sourceId,
    Value<int>? ordinal,
    Value<int>? rowid,
  }) {
    return LibraryTracksCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      filename: filename ?? this.filename,
      duration: duration ?? this.duration,
      sourceId: sourceId ?? this.sourceId,
      ordinal: ordinal ?? this.ordinal,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (filename.present) {
      map['filename'] = Variable<String>(filename.value);
    }
    if (duration.present) {
      map['duration'] = Variable<double>(duration.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (ordinal.present) {
      map['ordinal'] = Variable<int>(ordinal.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LibraryTracksCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('filename: $filename, ')
          ..write('duration: $duration, ')
          ..write('sourceId: $sourceId, ')
          ..write('ordinal: $ordinal, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LibraryArtistsTable extends LibraryArtists
    with TableInfo<$LibraryArtistsTable, LibraryArtist> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LibraryArtistsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _ordinalMeta = const VerificationMeta(
    'ordinal',
  );
  @override
  late final GeneratedColumn<int> ordinal = GeneratedColumn<int>(
    'ordinal',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, ordinal];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'library_artists';
  @override
  VerificationContext validateIntegrity(
    Insertable<LibraryArtist> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('ordinal')) {
      context.handle(
        _ordinalMeta,
        ordinal.isAcceptableOrUnknown(data['ordinal']!, _ordinalMeta),
      );
    } else if (isInserting) {
      context.missing(_ordinalMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LibraryArtist map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LibraryArtist(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      ordinal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ordinal'],
      )!,
    );
  }

  @override
  $LibraryArtistsTable createAlias(String alias) {
    return $LibraryArtistsTable(attachedDatabase, alias);
  }
}

class LibraryArtist extends DataClass implements Insertable<LibraryArtist> {
  final int id;
  final String name;
  final int ordinal;
  const LibraryArtist({
    required this.id,
    required this.name,
    required this.ordinal,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['ordinal'] = Variable<int>(ordinal);
    return map;
  }

  LibraryArtistsCompanion toCompanion(bool nullToAbsent) {
    return LibraryArtistsCompanion(
      id: Value(id),
      name: Value(name),
      ordinal: Value(ordinal),
    );
  }

  factory LibraryArtist.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LibraryArtist(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      ordinal: serializer.fromJson<int>(json['ordinal']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'ordinal': serializer.toJson<int>(ordinal),
    };
  }

  LibraryArtist copyWith({int? id, String? name, int? ordinal}) =>
      LibraryArtist(
        id: id ?? this.id,
        name: name ?? this.name,
        ordinal: ordinal ?? this.ordinal,
      );
  LibraryArtist copyWithCompanion(LibraryArtistsCompanion data) {
    return LibraryArtist(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      ordinal: data.ordinal.present ? data.ordinal.value : this.ordinal,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LibraryArtist(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('ordinal: $ordinal')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, ordinal);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LibraryArtist &&
          other.id == this.id &&
          other.name == this.name &&
          other.ordinal == this.ordinal);
}

class LibraryArtistsCompanion extends UpdateCompanion<LibraryArtist> {
  final Value<int> id;
  final Value<String> name;
  final Value<int> ordinal;
  const LibraryArtistsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.ordinal = const Value.absent(),
  });
  LibraryArtistsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required int ordinal,
  }) : name = Value(name),
       ordinal = Value(ordinal);
  static Insertable<LibraryArtist> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<int>? ordinal,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (ordinal != null) 'ordinal': ordinal,
    });
  }

  LibraryArtistsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<int>? ordinal,
  }) {
    return LibraryArtistsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      ordinal: ordinal ?? this.ordinal,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (ordinal.present) {
      map['ordinal'] = Variable<int>(ordinal.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LibraryArtistsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('ordinal: $ordinal')
          ..write(')'))
        .toString();
  }
}

class $LibraryTrackArtistsTable extends LibraryTrackArtists
    with TableInfo<$LibraryTrackArtistsTable, LibraryTrackArtist> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LibraryTrackArtistsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _trackIdMeta = const VerificationMeta(
    'trackId',
  );
  @override
  late final GeneratedColumn<String> trackId = GeneratedColumn<String>(
    'track_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES library_tracks (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _artistIdMeta = const VerificationMeta(
    'artistId',
  );
  @override
  late final GeneratedColumn<int> artistId = GeneratedColumn<int>(
    'artist_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES library_artists (id) ON DELETE RESTRICT',
    ),
  );
  static const VerificationMeta _ordinalMeta = const VerificationMeta(
    'ordinal',
  );
  @override
  late final GeneratedColumn<int> ordinal = GeneratedColumn<int>(
    'ordinal',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [trackId, artistId, ordinal];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'library_track_artists';
  @override
  VerificationContext validateIntegrity(
    Insertable<LibraryTrackArtist> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('track_id')) {
      context.handle(
        _trackIdMeta,
        trackId.isAcceptableOrUnknown(data['track_id']!, _trackIdMeta),
      );
    } else if (isInserting) {
      context.missing(_trackIdMeta);
    }
    if (data.containsKey('artist_id')) {
      context.handle(
        _artistIdMeta,
        artistId.isAcceptableOrUnknown(data['artist_id']!, _artistIdMeta),
      );
    } else if (isInserting) {
      context.missing(_artistIdMeta);
    }
    if (data.containsKey('ordinal')) {
      context.handle(
        _ordinalMeta,
        ordinal.isAcceptableOrUnknown(data['ordinal']!, _ordinalMeta),
      );
    } else if (isInserting) {
      context.missing(_ordinalMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {trackId, artistId};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {trackId, ordinal},
  ];
  @override
  LibraryTrackArtist map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LibraryTrackArtist(
      trackId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}track_id'],
      )!,
      artistId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}artist_id'],
      )!,
      ordinal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ordinal'],
      )!,
    );
  }

  @override
  $LibraryTrackArtistsTable createAlias(String alias) {
    return $LibraryTrackArtistsTable(attachedDatabase, alias);
  }
}

class LibraryTrackArtist extends DataClass
    implements Insertable<LibraryTrackArtist> {
  final String trackId;
  final int artistId;
  final int ordinal;
  const LibraryTrackArtist({
    required this.trackId,
    required this.artistId,
    required this.ordinal,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['track_id'] = Variable<String>(trackId);
    map['artist_id'] = Variable<int>(artistId);
    map['ordinal'] = Variable<int>(ordinal);
    return map;
  }

  LibraryTrackArtistsCompanion toCompanion(bool nullToAbsent) {
    return LibraryTrackArtistsCompanion(
      trackId: Value(trackId),
      artistId: Value(artistId),
      ordinal: Value(ordinal),
    );
  }

  factory LibraryTrackArtist.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LibraryTrackArtist(
      trackId: serializer.fromJson<String>(json['trackId']),
      artistId: serializer.fromJson<int>(json['artistId']),
      ordinal: serializer.fromJson<int>(json['ordinal']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'trackId': serializer.toJson<String>(trackId),
      'artistId': serializer.toJson<int>(artistId),
      'ordinal': serializer.toJson<int>(ordinal),
    };
  }

  LibraryTrackArtist copyWith({String? trackId, int? artistId, int? ordinal}) =>
      LibraryTrackArtist(
        trackId: trackId ?? this.trackId,
        artistId: artistId ?? this.artistId,
        ordinal: ordinal ?? this.ordinal,
      );
  LibraryTrackArtist copyWithCompanion(LibraryTrackArtistsCompanion data) {
    return LibraryTrackArtist(
      trackId: data.trackId.present ? data.trackId.value : this.trackId,
      artistId: data.artistId.present ? data.artistId.value : this.artistId,
      ordinal: data.ordinal.present ? data.ordinal.value : this.ordinal,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LibraryTrackArtist(')
          ..write('trackId: $trackId, ')
          ..write('artistId: $artistId, ')
          ..write('ordinal: $ordinal')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(trackId, artistId, ordinal);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LibraryTrackArtist &&
          other.trackId == this.trackId &&
          other.artistId == this.artistId &&
          other.ordinal == this.ordinal);
}

class LibraryTrackArtistsCompanion extends UpdateCompanion<LibraryTrackArtist> {
  final Value<String> trackId;
  final Value<int> artistId;
  final Value<int> ordinal;
  final Value<int> rowid;
  const LibraryTrackArtistsCompanion({
    this.trackId = const Value.absent(),
    this.artistId = const Value.absent(),
    this.ordinal = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LibraryTrackArtistsCompanion.insert({
    required String trackId,
    required int artistId,
    required int ordinal,
    this.rowid = const Value.absent(),
  }) : trackId = Value(trackId),
       artistId = Value(artistId),
       ordinal = Value(ordinal);
  static Insertable<LibraryTrackArtist> custom({
    Expression<String>? trackId,
    Expression<int>? artistId,
    Expression<int>? ordinal,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (trackId != null) 'track_id': trackId,
      if (artistId != null) 'artist_id': artistId,
      if (ordinal != null) 'ordinal': ordinal,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LibraryTrackArtistsCompanion copyWith({
    Value<String>? trackId,
    Value<int>? artistId,
    Value<int>? ordinal,
    Value<int>? rowid,
  }) {
    return LibraryTrackArtistsCompanion(
      trackId: trackId ?? this.trackId,
      artistId: artistId ?? this.artistId,
      ordinal: ordinal ?? this.ordinal,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (trackId.present) {
      map['track_id'] = Variable<String>(trackId.value);
    }
    if (artistId.present) {
      map['artist_id'] = Variable<int>(artistId.value);
    }
    if (ordinal.present) {
      map['ordinal'] = Variable<int>(ordinal.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LibraryTrackArtistsCompanion(')
          ..write('trackId: $trackId, ')
          ..write('artistId: $artistId, ')
          ..write('ordinal: $ordinal, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LibraryPlaylistsTable extends LibraryPlaylists
    with TableInfo<$LibraryPlaylistsTable, LibraryPlaylist> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LibraryPlaylistsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
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
  static const VerificationMeta _ordinalMeta = const VerificationMeta(
    'ordinal',
  );
  @override
  late final GeneratedColumn<int> ordinal = GeneratedColumn<int>(
    'ordinal',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, ordinal];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'library_playlists';
  @override
  VerificationContext validateIntegrity(
    Insertable<LibraryPlaylist> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('ordinal')) {
      context.handle(
        _ordinalMeta,
        ordinal.isAcceptableOrUnknown(data['ordinal']!, _ordinalMeta),
      );
    } else if (isInserting) {
      context.missing(_ordinalMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LibraryPlaylist map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LibraryPlaylist(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      ordinal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ordinal'],
      )!,
    );
  }

  @override
  $LibraryPlaylistsTable createAlias(String alias) {
    return $LibraryPlaylistsTable(attachedDatabase, alias);
  }
}

class LibraryPlaylist extends DataClass implements Insertable<LibraryPlaylist> {
  final String id;
  final String name;
  final int ordinal;
  const LibraryPlaylist({
    required this.id,
    required this.name,
    required this.ordinal,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['ordinal'] = Variable<int>(ordinal);
    return map;
  }

  LibraryPlaylistsCompanion toCompanion(bool nullToAbsent) {
    return LibraryPlaylistsCompanion(
      id: Value(id),
      name: Value(name),
      ordinal: Value(ordinal),
    );
  }

  factory LibraryPlaylist.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LibraryPlaylist(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      ordinal: serializer.fromJson<int>(json['ordinal']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'ordinal': serializer.toJson<int>(ordinal),
    };
  }

  LibraryPlaylist copyWith({String? id, String? name, int? ordinal}) =>
      LibraryPlaylist(
        id: id ?? this.id,
        name: name ?? this.name,
        ordinal: ordinal ?? this.ordinal,
      );
  LibraryPlaylist copyWithCompanion(LibraryPlaylistsCompanion data) {
    return LibraryPlaylist(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      ordinal: data.ordinal.present ? data.ordinal.value : this.ordinal,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LibraryPlaylist(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('ordinal: $ordinal')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, ordinal);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LibraryPlaylist &&
          other.id == this.id &&
          other.name == this.name &&
          other.ordinal == this.ordinal);
}

class LibraryPlaylistsCompanion extends UpdateCompanion<LibraryPlaylist> {
  final Value<String> id;
  final Value<String> name;
  final Value<int> ordinal;
  final Value<int> rowid;
  const LibraryPlaylistsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.ordinal = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LibraryPlaylistsCompanion.insert({
    required String id,
    required String name,
    required int ordinal,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       ordinal = Value(ordinal);
  static Insertable<LibraryPlaylist> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<int>? ordinal,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (ordinal != null) 'ordinal': ordinal,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LibraryPlaylistsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<int>? ordinal,
    Value<int>? rowid,
  }) {
    return LibraryPlaylistsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      ordinal: ordinal ?? this.ordinal,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (ordinal.present) {
      map['ordinal'] = Variable<int>(ordinal.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LibraryPlaylistsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('ordinal: $ordinal, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LibraryPlaylistTracksTable extends LibraryPlaylistTracks
    with TableInfo<$LibraryPlaylistTracksTable, LibraryPlaylistTrack> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LibraryPlaylistTracksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _playlistIdMeta = const VerificationMeta(
    'playlistId',
  );
  @override
  late final GeneratedColumn<String> playlistId = GeneratedColumn<String>(
    'playlist_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES library_playlists (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _trackIdMeta = const VerificationMeta(
    'trackId',
  );
  @override
  late final GeneratedColumn<String> trackId = GeneratedColumn<String>(
    'track_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES library_tracks (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _ordinalMeta = const VerificationMeta(
    'ordinal',
  );
  @override
  late final GeneratedColumn<int> ordinal = GeneratedColumn<int>(
    'ordinal',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [playlistId, trackId, ordinal];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'library_playlist_tracks';
  @override
  VerificationContext validateIntegrity(
    Insertable<LibraryPlaylistTrack> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('playlist_id')) {
      context.handle(
        _playlistIdMeta,
        playlistId.isAcceptableOrUnknown(data['playlist_id']!, _playlistIdMeta),
      );
    } else if (isInserting) {
      context.missing(_playlistIdMeta);
    }
    if (data.containsKey('track_id')) {
      context.handle(
        _trackIdMeta,
        trackId.isAcceptableOrUnknown(data['track_id']!, _trackIdMeta),
      );
    } else if (isInserting) {
      context.missing(_trackIdMeta);
    }
    if (data.containsKey('ordinal')) {
      context.handle(
        _ordinalMeta,
        ordinal.isAcceptableOrUnknown(data['ordinal']!, _ordinalMeta),
      );
    } else if (isInserting) {
      context.missing(_ordinalMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {playlistId, trackId};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {playlistId, ordinal},
  ];
  @override
  LibraryPlaylistTrack map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LibraryPlaylistTrack(
      playlistId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}playlist_id'],
      )!,
      trackId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}track_id'],
      )!,
      ordinal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ordinal'],
      )!,
    );
  }

  @override
  $LibraryPlaylistTracksTable createAlias(String alias) {
    return $LibraryPlaylistTracksTable(attachedDatabase, alias);
  }
}

class LibraryPlaylistTrack extends DataClass
    implements Insertable<LibraryPlaylistTrack> {
  final String playlistId;
  final String trackId;
  final int ordinal;
  const LibraryPlaylistTrack({
    required this.playlistId,
    required this.trackId,
    required this.ordinal,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['playlist_id'] = Variable<String>(playlistId);
    map['track_id'] = Variable<String>(trackId);
    map['ordinal'] = Variable<int>(ordinal);
    return map;
  }

  LibraryPlaylistTracksCompanion toCompanion(bool nullToAbsent) {
    return LibraryPlaylistTracksCompanion(
      playlistId: Value(playlistId),
      trackId: Value(trackId),
      ordinal: Value(ordinal),
    );
  }

  factory LibraryPlaylistTrack.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LibraryPlaylistTrack(
      playlistId: serializer.fromJson<String>(json['playlistId']),
      trackId: serializer.fromJson<String>(json['trackId']),
      ordinal: serializer.fromJson<int>(json['ordinal']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'playlistId': serializer.toJson<String>(playlistId),
      'trackId': serializer.toJson<String>(trackId),
      'ordinal': serializer.toJson<int>(ordinal),
    };
  }

  LibraryPlaylistTrack copyWith({
    String? playlistId,
    String? trackId,
    int? ordinal,
  }) => LibraryPlaylistTrack(
    playlistId: playlistId ?? this.playlistId,
    trackId: trackId ?? this.trackId,
    ordinal: ordinal ?? this.ordinal,
  );
  LibraryPlaylistTrack copyWithCompanion(LibraryPlaylistTracksCompanion data) {
    return LibraryPlaylistTrack(
      playlistId: data.playlistId.present
          ? data.playlistId.value
          : this.playlistId,
      trackId: data.trackId.present ? data.trackId.value : this.trackId,
      ordinal: data.ordinal.present ? data.ordinal.value : this.ordinal,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LibraryPlaylistTrack(')
          ..write('playlistId: $playlistId, ')
          ..write('trackId: $trackId, ')
          ..write('ordinal: $ordinal')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(playlistId, trackId, ordinal);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LibraryPlaylistTrack &&
          other.playlistId == this.playlistId &&
          other.trackId == this.trackId &&
          other.ordinal == this.ordinal);
}

class LibraryPlaylistTracksCompanion
    extends UpdateCompanion<LibraryPlaylistTrack> {
  final Value<String> playlistId;
  final Value<String> trackId;
  final Value<int> ordinal;
  final Value<int> rowid;
  const LibraryPlaylistTracksCompanion({
    this.playlistId = const Value.absent(),
    this.trackId = const Value.absent(),
    this.ordinal = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LibraryPlaylistTracksCompanion.insert({
    required String playlistId,
    required String trackId,
    required int ordinal,
    this.rowid = const Value.absent(),
  }) : playlistId = Value(playlistId),
       trackId = Value(trackId),
       ordinal = Value(ordinal);
  static Insertable<LibraryPlaylistTrack> custom({
    Expression<String>? playlistId,
    Expression<String>? trackId,
    Expression<int>? ordinal,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (playlistId != null) 'playlist_id': playlistId,
      if (trackId != null) 'track_id': trackId,
      if (ordinal != null) 'ordinal': ordinal,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LibraryPlaylistTracksCompanion copyWith({
    Value<String>? playlistId,
    Value<String>? trackId,
    Value<int>? ordinal,
    Value<int>? rowid,
  }) {
    return LibraryPlaylistTracksCompanion(
      playlistId: playlistId ?? this.playlistId,
      trackId: trackId ?? this.trackId,
      ordinal: ordinal ?? this.ordinal,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (playlistId.present) {
      map['playlist_id'] = Variable<String>(playlistId.value);
    }
    if (trackId.present) {
      map['track_id'] = Variable<String>(trackId.value);
    }
    if (ordinal.present) {
      map['ordinal'] = Variable<int>(ordinal.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LibraryPlaylistTracksCompanion(')
          ..write('playlistId: $playlistId, ')
          ..write('trackId: $trackId, ')
          ..write('ordinal: $ordinal, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LibrarySettingsTable extends LibrarySettings
    with TableInfo<$LibrarySettingsTable, LibrarySetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LibrarySettingsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _selectedIdMeta = const VerificationMeta(
    'selectedId',
  );
  @override
  late final GeneratedColumn<String> selectedId = GeneratedColumn<String>(
    'selected_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _playingIdMeta = const VerificationMeta(
    'playingId',
  );
  @override
  late final GeneratedColumn<String> playingId = GeneratedColumn<String>(
    'playing_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _trackIdMeta = const VerificationMeta(
    'trackId',
  );
  @override
  late final GeneratedColumn<String> trackId = GeneratedColumn<String>(
    'track_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES library_tracks (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<double> position = GeneratedColumn<double>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _volumeMeta = const VerificationMeta('volume');
  @override
  late final GeneratedColumn<double> volume = GeneratedColumn<double>(
    'volume',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _shuffleMeta = const VerificationMeta(
    'shuffle',
  );
  @override
  late final GeneratedColumn<bool> shuffle = GeneratedColumn<bool>(
    'shuffle',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("shuffle" IN (0, 1))',
    ),
  );
  static const VerificationMeta _repeatModeMeta = const VerificationMeta(
    'repeatMode',
  );
  @override
  late final GeneratedColumn<String> repeatMode = GeneratedColumn<String>(
    'repeat_mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _importLimitMeta = const VerificationMeta(
    'importLimit',
  );
  @override
  late final GeneratedColumn<int> importLimit = GeneratedColumn<int>(
    'import_limit',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    selectedId,
    playingId,
    trackId,
    position,
    volume,
    shuffle,
    repeatMode,
    importLimit,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'library_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<LibrarySetting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('selected_id')) {
      context.handle(
        _selectedIdMeta,
        selectedId.isAcceptableOrUnknown(data['selected_id']!, _selectedIdMeta),
      );
    }
    if (data.containsKey('playing_id')) {
      context.handle(
        _playingIdMeta,
        playingId.isAcceptableOrUnknown(data['playing_id']!, _playingIdMeta),
      );
    }
    if (data.containsKey('track_id')) {
      context.handle(
        _trackIdMeta,
        trackId.isAcceptableOrUnknown(data['track_id']!, _trackIdMeta),
      );
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('volume')) {
      context.handle(
        _volumeMeta,
        volume.isAcceptableOrUnknown(data['volume']!, _volumeMeta),
      );
    } else if (isInserting) {
      context.missing(_volumeMeta);
    }
    if (data.containsKey('shuffle')) {
      context.handle(
        _shuffleMeta,
        shuffle.isAcceptableOrUnknown(data['shuffle']!, _shuffleMeta),
      );
    } else if (isInserting) {
      context.missing(_shuffleMeta);
    }
    if (data.containsKey('repeat_mode')) {
      context.handle(
        _repeatModeMeta,
        repeatMode.isAcceptableOrUnknown(data['repeat_mode']!, _repeatModeMeta),
      );
    } else if (isInserting) {
      context.missing(_repeatModeMeta);
    }
    if (data.containsKey('import_limit')) {
      context.handle(
        _importLimitMeta,
        importLimit.isAcceptableOrUnknown(
          data['import_limit']!,
          _importLimitMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_importLimitMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LibrarySetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LibrarySetting(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      selectedId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}selected_id'],
      ),
      playingId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}playing_id'],
      ),
      trackId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}track_id'],
      ),
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}position'],
      )!,
      volume: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}volume'],
      )!,
      shuffle: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}shuffle'],
      )!,
      repeatMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}repeat_mode'],
      )!,
      importLimit: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}import_limit'],
      )!,
    );
  }

  @override
  $LibrarySettingsTable createAlias(String alias) {
    return $LibrarySettingsTable(attachedDatabase, alias);
  }
}

class LibrarySetting extends DataClass implements Insertable<LibrarySetting> {
  final int id;
  final String? selectedId;
  final String? playingId;
  final String? trackId;
  final double position;
  final double volume;
  final bool shuffle;
  final String repeatMode;
  final int importLimit;
  const LibrarySetting({
    required this.id,
    this.selectedId,
    this.playingId,
    this.trackId,
    required this.position,
    required this.volume,
    required this.shuffle,
    required this.repeatMode,
    required this.importLimit,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || selectedId != null) {
      map['selected_id'] = Variable<String>(selectedId);
    }
    if (!nullToAbsent || playingId != null) {
      map['playing_id'] = Variable<String>(playingId);
    }
    if (!nullToAbsent || trackId != null) {
      map['track_id'] = Variable<String>(trackId);
    }
    map['position'] = Variable<double>(position);
    map['volume'] = Variable<double>(volume);
    map['shuffle'] = Variable<bool>(shuffle);
    map['repeat_mode'] = Variable<String>(repeatMode);
    map['import_limit'] = Variable<int>(importLimit);
    return map;
  }

  LibrarySettingsCompanion toCompanion(bool nullToAbsent) {
    return LibrarySettingsCompanion(
      id: Value(id),
      selectedId: selectedId == null && nullToAbsent
          ? const Value.absent()
          : Value(selectedId),
      playingId: playingId == null && nullToAbsent
          ? const Value.absent()
          : Value(playingId),
      trackId: trackId == null && nullToAbsent
          ? const Value.absent()
          : Value(trackId),
      position: Value(position),
      volume: Value(volume),
      shuffle: Value(shuffle),
      repeatMode: Value(repeatMode),
      importLimit: Value(importLimit),
    );
  }

  factory LibrarySetting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LibrarySetting(
      id: serializer.fromJson<int>(json['id']),
      selectedId: serializer.fromJson<String?>(json['selectedId']),
      playingId: serializer.fromJson<String?>(json['playingId']),
      trackId: serializer.fromJson<String?>(json['trackId']),
      position: serializer.fromJson<double>(json['position']),
      volume: serializer.fromJson<double>(json['volume']),
      shuffle: serializer.fromJson<bool>(json['shuffle']),
      repeatMode: serializer.fromJson<String>(json['repeatMode']),
      importLimit: serializer.fromJson<int>(json['importLimit']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'selectedId': serializer.toJson<String?>(selectedId),
      'playingId': serializer.toJson<String?>(playingId),
      'trackId': serializer.toJson<String?>(trackId),
      'position': serializer.toJson<double>(position),
      'volume': serializer.toJson<double>(volume),
      'shuffle': serializer.toJson<bool>(shuffle),
      'repeatMode': serializer.toJson<String>(repeatMode),
      'importLimit': serializer.toJson<int>(importLimit),
    };
  }

  LibrarySetting copyWith({
    int? id,
    Value<String?> selectedId = const Value.absent(),
    Value<String?> playingId = const Value.absent(),
    Value<String?> trackId = const Value.absent(),
    double? position,
    double? volume,
    bool? shuffle,
    String? repeatMode,
    int? importLimit,
  }) => LibrarySetting(
    id: id ?? this.id,
    selectedId: selectedId.present ? selectedId.value : this.selectedId,
    playingId: playingId.present ? playingId.value : this.playingId,
    trackId: trackId.present ? trackId.value : this.trackId,
    position: position ?? this.position,
    volume: volume ?? this.volume,
    shuffle: shuffle ?? this.shuffle,
    repeatMode: repeatMode ?? this.repeatMode,
    importLimit: importLimit ?? this.importLimit,
  );
  LibrarySetting copyWithCompanion(LibrarySettingsCompanion data) {
    return LibrarySetting(
      id: data.id.present ? data.id.value : this.id,
      selectedId: data.selectedId.present
          ? data.selectedId.value
          : this.selectedId,
      playingId: data.playingId.present ? data.playingId.value : this.playingId,
      trackId: data.trackId.present ? data.trackId.value : this.trackId,
      position: data.position.present ? data.position.value : this.position,
      volume: data.volume.present ? data.volume.value : this.volume,
      shuffle: data.shuffle.present ? data.shuffle.value : this.shuffle,
      repeatMode: data.repeatMode.present
          ? data.repeatMode.value
          : this.repeatMode,
      importLimit: data.importLimit.present
          ? data.importLimit.value
          : this.importLimit,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LibrarySetting(')
          ..write('id: $id, ')
          ..write('selectedId: $selectedId, ')
          ..write('playingId: $playingId, ')
          ..write('trackId: $trackId, ')
          ..write('position: $position, ')
          ..write('volume: $volume, ')
          ..write('shuffle: $shuffle, ')
          ..write('repeatMode: $repeatMode, ')
          ..write('importLimit: $importLimit')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    selectedId,
    playingId,
    trackId,
    position,
    volume,
    shuffle,
    repeatMode,
    importLimit,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LibrarySetting &&
          other.id == this.id &&
          other.selectedId == this.selectedId &&
          other.playingId == this.playingId &&
          other.trackId == this.trackId &&
          other.position == this.position &&
          other.volume == this.volume &&
          other.shuffle == this.shuffle &&
          other.repeatMode == this.repeatMode &&
          other.importLimit == this.importLimit);
}

class LibrarySettingsCompanion extends UpdateCompanion<LibrarySetting> {
  final Value<int> id;
  final Value<String?> selectedId;
  final Value<String?> playingId;
  final Value<String?> trackId;
  final Value<double> position;
  final Value<double> volume;
  final Value<bool> shuffle;
  final Value<String> repeatMode;
  final Value<int> importLimit;
  const LibrarySettingsCompanion({
    this.id = const Value.absent(),
    this.selectedId = const Value.absent(),
    this.playingId = const Value.absent(),
    this.trackId = const Value.absent(),
    this.position = const Value.absent(),
    this.volume = const Value.absent(),
    this.shuffle = const Value.absent(),
    this.repeatMode = const Value.absent(),
    this.importLimit = const Value.absent(),
  });
  LibrarySettingsCompanion.insert({
    this.id = const Value.absent(),
    this.selectedId = const Value.absent(),
    this.playingId = const Value.absent(),
    this.trackId = const Value.absent(),
    required double position,
    required double volume,
    required bool shuffle,
    required String repeatMode,
    required int importLimit,
  }) : position = Value(position),
       volume = Value(volume),
       shuffle = Value(shuffle),
       repeatMode = Value(repeatMode),
       importLimit = Value(importLimit);
  static Insertable<LibrarySetting> custom({
    Expression<int>? id,
    Expression<String>? selectedId,
    Expression<String>? playingId,
    Expression<String>? trackId,
    Expression<double>? position,
    Expression<double>? volume,
    Expression<bool>? shuffle,
    Expression<String>? repeatMode,
    Expression<int>? importLimit,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (selectedId != null) 'selected_id': selectedId,
      if (playingId != null) 'playing_id': playingId,
      if (trackId != null) 'track_id': trackId,
      if (position != null) 'position': position,
      if (volume != null) 'volume': volume,
      if (shuffle != null) 'shuffle': shuffle,
      if (repeatMode != null) 'repeat_mode': repeatMode,
      if (importLimit != null) 'import_limit': importLimit,
    });
  }

  LibrarySettingsCompanion copyWith({
    Value<int>? id,
    Value<String?>? selectedId,
    Value<String?>? playingId,
    Value<String?>? trackId,
    Value<double>? position,
    Value<double>? volume,
    Value<bool>? shuffle,
    Value<String>? repeatMode,
    Value<int>? importLimit,
  }) {
    return LibrarySettingsCompanion(
      id: id ?? this.id,
      selectedId: selectedId ?? this.selectedId,
      playingId: playingId ?? this.playingId,
      trackId: trackId ?? this.trackId,
      position: position ?? this.position,
      volume: volume ?? this.volume,
      shuffle: shuffle ?? this.shuffle,
      repeatMode: repeatMode ?? this.repeatMode,
      importLimit: importLimit ?? this.importLimit,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (selectedId.present) {
      map['selected_id'] = Variable<String>(selectedId.value);
    }
    if (playingId.present) {
      map['playing_id'] = Variable<String>(playingId.value);
    }
    if (trackId.present) {
      map['track_id'] = Variable<String>(trackId.value);
    }
    if (position.present) {
      map['position'] = Variable<double>(position.value);
    }
    if (volume.present) {
      map['volume'] = Variable<double>(volume.value);
    }
    if (shuffle.present) {
      map['shuffle'] = Variable<bool>(shuffle.value);
    }
    if (repeatMode.present) {
      map['repeat_mode'] = Variable<String>(repeatMode.value);
    }
    if (importLimit.present) {
      map['import_limit'] = Variable<int>(importLimit.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LibrarySettingsCompanion(')
          ..write('id: $id, ')
          ..write('selectedId: $selectedId, ')
          ..write('playingId: $playingId, ')
          ..write('trackId: $trackId, ')
          ..write('position: $position, ')
          ..write('volume: $volume, ')
          ..write('shuffle: $shuffle, ')
          ..write('repeatMode: $repeatMode, ')
          ..write('importLimit: $importLimit')
          ..write(')'))
        .toString();
  }
}

abstract class _$MusicDatabase extends GeneratedDatabase {
  _$MusicDatabase(QueryExecutor e) : super(e);
  $MusicDatabaseManager get managers => $MusicDatabaseManager(this);
  late final $LibraryTracksTable libraryTracks = $LibraryTracksTable(this);
  late final $LibraryArtistsTable libraryArtists = $LibraryArtistsTable(this);
  late final $LibraryTrackArtistsTable libraryTrackArtists =
      $LibraryTrackArtistsTable(this);
  late final $LibraryPlaylistsTable libraryPlaylists = $LibraryPlaylistsTable(
    this,
  );
  late final $LibraryPlaylistTracksTable libraryPlaylistTracks =
      $LibraryPlaylistTracksTable(this);
  late final $LibrarySettingsTable librarySettings = $LibrarySettingsTable(
    this,
  );
  late final Index trackArtistsByArtist = Index(
    'track_artists_by_artist',
    'CREATE INDEX track_artists_by_artist ON library_track_artists (artist_id)',
  );
  late final Index playlistTracksByTrack = Index(
    'playlist_tracks_by_track',
    'CREATE INDEX playlist_tracks_by_track ON library_playlist_tracks (track_id)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    libraryTracks,
    libraryArtists,
    libraryTrackArtists,
    libraryPlaylists,
    libraryPlaylistTracks,
    librarySettings,
    trackArtistsByArtist,
    playlistTracksByTrack,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'library_tracks',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('library_track_artists', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'library_playlists',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('library_playlist_tracks', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'library_tracks',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('library_playlist_tracks', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'library_tracks',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('library_settings', kind: UpdateKind.update)],
    ),
  ]);
}

typedef $$LibraryTracksTableCreateCompanionBuilder =
    LibraryTracksCompanion Function({
      required String id,
      required String title,
      required String filename,
      required double duration,
      Value<String?> sourceId,
      required int ordinal,
      Value<int> rowid,
    });
typedef $$LibraryTracksTableUpdateCompanionBuilder =
    LibraryTracksCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<String> filename,
      Value<double> duration,
      Value<String?> sourceId,
      Value<int> ordinal,
      Value<int> rowid,
    });

final class $$LibraryTracksTableReferences
    extends BaseReferences<_$MusicDatabase, $LibraryTracksTable, LibraryTrack> {
  $$LibraryTracksTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<
    $LibraryTrackArtistsTable,
    List<LibraryTrackArtist>
  >
  _libraryTrackArtistsRefsTable(_$MusicDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.libraryTrackArtists,
        aliasName: 'library_tracks__id__library_track_artists__track_id',
      );

  $$LibraryTrackArtistsTableProcessedTableManager get libraryTrackArtistsRefs {
    final manager = $$LibraryTrackArtistsTableTableManager(
      $_db,
      $_db.libraryTrackArtists,
    ).filter((f) => f.trackId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _libraryTrackArtistsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $LibraryPlaylistTracksTable,
    List<LibraryPlaylistTrack>
  >
  _libraryPlaylistTracksRefsTable(_$MusicDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.libraryPlaylistTracks,
        aliasName: 'library_tracks__id__library_playlist_tracks__track_id',
      );

  $$LibraryPlaylistTracksTableProcessedTableManager
  get libraryPlaylistTracksRefs {
    final manager = $$LibraryPlaylistTracksTableTableManager(
      $_db,
      $_db.libraryPlaylistTracks,
    ).filter((f) => f.trackId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _libraryPlaylistTracksRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$LibrarySettingsTable, List<LibrarySetting>>
  _librarySettingsRefsTable(_$MusicDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.librarySettings,
        aliasName: 'library_tracks__id__library_settings__track_id',
      );

  $$LibrarySettingsTableProcessedTableManager get librarySettingsRefs {
    final manager = $$LibrarySettingsTableTableManager(
      $_db,
      $_db.librarySettings,
    ).filter((f) => f.trackId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _librarySettingsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$LibraryTracksTableFilterComposer
    extends Composer<_$MusicDatabase, $LibraryTracksTable> {
  $$LibraryTracksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get filename => $composableBuilder(
    column: $table.filename,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get duration => $composableBuilder(
    column: $table.duration,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ordinal => $composableBuilder(
    column: $table.ordinal,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> libraryTrackArtistsRefs(
    Expression<bool> Function($$LibraryTrackArtistsTableFilterComposer f) f,
  ) {
    final $$LibraryTrackArtistsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.libraryTrackArtists,
      getReferencedColumn: (t) => t.trackId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibraryTrackArtistsTableFilterComposer(
            $db: $db,
            $table: $db.libraryTrackArtists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> libraryPlaylistTracksRefs(
    Expression<bool> Function($$LibraryPlaylistTracksTableFilterComposer f) f,
  ) {
    final $$LibraryPlaylistTracksTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.libraryPlaylistTracks,
          getReferencedColumn: (t) => t.trackId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$LibraryPlaylistTracksTableFilterComposer(
                $db: $db,
                $table: $db.libraryPlaylistTracks,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<bool> librarySettingsRefs(
    Expression<bool> Function($$LibrarySettingsTableFilterComposer f) f,
  ) {
    final $$LibrarySettingsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.librarySettings,
      getReferencedColumn: (t) => t.trackId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibrarySettingsTableFilterComposer(
            $db: $db,
            $table: $db.librarySettings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LibraryTracksTableOrderingComposer
    extends Composer<_$MusicDatabase, $LibraryTracksTable> {
  $$LibraryTracksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get filename => $composableBuilder(
    column: $table.filename,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get duration => $composableBuilder(
    column: $table.duration,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ordinal => $composableBuilder(
    column: $table.ordinal,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LibraryTracksTableAnnotationComposer
    extends Composer<_$MusicDatabase, $LibraryTracksTable> {
  $$LibraryTracksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get filename =>
      $composableBuilder(column: $table.filename, builder: (column) => column);

  GeneratedColumn<double> get duration =>
      $composableBuilder(column: $table.duration, builder: (column) => column);

  GeneratedColumn<String> get sourceId =>
      $composableBuilder(column: $table.sourceId, builder: (column) => column);

  GeneratedColumn<int> get ordinal =>
      $composableBuilder(column: $table.ordinal, builder: (column) => column);

  Expression<T> libraryTrackArtistsRefs<T extends Object>(
    Expression<T> Function($$LibraryTrackArtistsTableAnnotationComposer a) f,
  ) {
    final $$LibraryTrackArtistsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.libraryTrackArtists,
          getReferencedColumn: (t) => t.trackId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$LibraryTrackArtistsTableAnnotationComposer(
                $db: $db,
                $table: $db.libraryTrackArtists,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> libraryPlaylistTracksRefs<T extends Object>(
    Expression<T> Function($$LibraryPlaylistTracksTableAnnotationComposer a) f,
  ) {
    final $$LibraryPlaylistTracksTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.libraryPlaylistTracks,
          getReferencedColumn: (t) => t.trackId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$LibraryPlaylistTracksTableAnnotationComposer(
                $db: $db,
                $table: $db.libraryPlaylistTracks,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> librarySettingsRefs<T extends Object>(
    Expression<T> Function($$LibrarySettingsTableAnnotationComposer a) f,
  ) {
    final $$LibrarySettingsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.librarySettings,
      getReferencedColumn: (t) => t.trackId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibrarySettingsTableAnnotationComposer(
            $db: $db,
            $table: $db.librarySettings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LibraryTracksTableTableManager
    extends
        RootTableManager<
          _$MusicDatabase,
          $LibraryTracksTable,
          LibraryTrack,
          $$LibraryTracksTableFilterComposer,
          $$LibraryTracksTableOrderingComposer,
          $$LibraryTracksTableAnnotationComposer,
          $$LibraryTracksTableCreateCompanionBuilder,
          $$LibraryTracksTableUpdateCompanionBuilder,
          (LibraryTrack, $$LibraryTracksTableReferences),
          LibraryTrack,
          PrefetchHooks Function({
            bool libraryTrackArtistsRefs,
            bool libraryPlaylistTracksRefs,
            bool librarySettingsRefs,
          })
        > {
  $$LibraryTracksTableTableManager(
    _$MusicDatabase db,
    $LibraryTracksTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LibraryTracksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LibraryTracksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LibraryTracksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> filename = const Value.absent(),
                Value<double> duration = const Value.absent(),
                Value<String?> sourceId = const Value.absent(),
                Value<int> ordinal = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LibraryTracksCompanion(
                id: id,
                title: title,
                filename: filename,
                duration: duration,
                sourceId: sourceId,
                ordinal: ordinal,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                required String filename,
                required double duration,
                Value<String?> sourceId = const Value.absent(),
                required int ordinal,
                Value<int> rowid = const Value.absent(),
              }) => LibraryTracksCompanion.insert(
                id: id,
                title: title,
                filename: filename,
                duration: duration,
                sourceId: sourceId,
                ordinal: ordinal,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LibraryTracksTable, LibraryTrack>(table),
                  $$LibraryTracksTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                libraryTrackArtistsRefs = false,
                libraryPlaylistTracksRefs = false,
                librarySettingsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (libraryTrackArtistsRefs) db.libraryTrackArtists,
                    if (libraryPlaylistTracksRefs) db.libraryPlaylistTracks,
                    if (librarySettingsRefs) db.librarySettings,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (libraryTrackArtistsRefs)
                        await $_getPrefetchedData<
                          LibraryTrack,
                          $LibraryTracksTable,
                          LibraryTrackArtist
                        >(
                          currentTable: table,
                          referencedTable: $$LibraryTracksTableReferences
                              ._libraryTrackArtistsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LibraryTracksTableReferences(
                                db,
                                table,
                                p0,
                              ).libraryTrackArtistsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.trackId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (libraryPlaylistTracksRefs)
                        await $_getPrefetchedData<
                          LibraryTrack,
                          $LibraryTracksTable,
                          LibraryPlaylistTrack
                        >(
                          currentTable: table,
                          referencedTable: $$LibraryTracksTableReferences
                              ._libraryPlaylistTracksRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LibraryTracksTableReferences(
                                db,
                                table,
                                p0,
                              ).libraryPlaylistTracksRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.trackId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (librarySettingsRefs)
                        await $_getPrefetchedData<
                          LibraryTrack,
                          $LibraryTracksTable,
                          LibrarySetting
                        >(
                          currentTable: table,
                          referencedTable: $$LibraryTracksTableReferences
                              ._librarySettingsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LibraryTracksTableReferences(
                                db,
                                table,
                                p0,
                              ).librarySettingsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.trackId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$LibraryTracksTableProcessedTableManager =
    ProcessedTableManager<
      _$MusicDatabase,
      $LibraryTracksTable,
      LibraryTrack,
      $$LibraryTracksTableFilterComposer,
      $$LibraryTracksTableOrderingComposer,
      $$LibraryTracksTableAnnotationComposer,
      $$LibraryTracksTableCreateCompanionBuilder,
      $$LibraryTracksTableUpdateCompanionBuilder,
      (LibraryTrack, $$LibraryTracksTableReferences),
      LibraryTrack,
      PrefetchHooks Function({
        bool libraryTrackArtistsRefs,
        bool libraryPlaylistTracksRefs,
        bool librarySettingsRefs,
      })
    >;
typedef $$LibraryArtistsTableCreateCompanionBuilder =
    LibraryArtistsCompanion Function({
      Value<int> id,
      required String name,
      required int ordinal,
    });
typedef $$LibraryArtistsTableUpdateCompanionBuilder =
    LibraryArtistsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<int> ordinal,
    });

final class $$LibraryArtistsTableReferences
    extends
        BaseReferences<_$MusicDatabase, $LibraryArtistsTable, LibraryArtist> {
  $$LibraryArtistsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<
    $LibraryTrackArtistsTable,
    List<LibraryTrackArtist>
  >
  _libraryTrackArtistsRefsTable(_$MusicDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.libraryTrackArtists,
        aliasName: 'library_artists__id__library_track_artists__artist_id',
      );

  $$LibraryTrackArtistsTableProcessedTableManager get libraryTrackArtistsRefs {
    final manager = $$LibraryTrackArtistsTableTableManager(
      $_db,
      $_db.libraryTrackArtists,
    ).filter((f) => f.artistId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _libraryTrackArtistsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$LibraryArtistsTableFilterComposer
    extends Composer<_$MusicDatabase, $LibraryArtistsTable> {
  $$LibraryArtistsTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ordinal => $composableBuilder(
    column: $table.ordinal,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> libraryTrackArtistsRefs(
    Expression<bool> Function($$LibraryTrackArtistsTableFilterComposer f) f,
  ) {
    final $$LibraryTrackArtistsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.libraryTrackArtists,
      getReferencedColumn: (t) => t.artistId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibraryTrackArtistsTableFilterComposer(
            $db: $db,
            $table: $db.libraryTrackArtists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LibraryArtistsTableOrderingComposer
    extends Composer<_$MusicDatabase, $LibraryArtistsTable> {
  $$LibraryArtistsTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ordinal => $composableBuilder(
    column: $table.ordinal,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LibraryArtistsTableAnnotationComposer
    extends Composer<_$MusicDatabase, $LibraryArtistsTable> {
  $$LibraryArtistsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get ordinal =>
      $composableBuilder(column: $table.ordinal, builder: (column) => column);

  Expression<T> libraryTrackArtistsRefs<T extends Object>(
    Expression<T> Function($$LibraryTrackArtistsTableAnnotationComposer a) f,
  ) {
    final $$LibraryTrackArtistsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.libraryTrackArtists,
          getReferencedColumn: (t) => t.artistId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$LibraryTrackArtistsTableAnnotationComposer(
                $db: $db,
                $table: $db.libraryTrackArtists,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$LibraryArtistsTableTableManager
    extends
        RootTableManager<
          _$MusicDatabase,
          $LibraryArtistsTable,
          LibraryArtist,
          $$LibraryArtistsTableFilterComposer,
          $$LibraryArtistsTableOrderingComposer,
          $$LibraryArtistsTableAnnotationComposer,
          $$LibraryArtistsTableCreateCompanionBuilder,
          $$LibraryArtistsTableUpdateCompanionBuilder,
          (LibraryArtist, $$LibraryArtistsTableReferences),
          LibraryArtist,
          PrefetchHooks Function({bool libraryTrackArtistsRefs})
        > {
  $$LibraryArtistsTableTableManager(
    _$MusicDatabase db,
    $LibraryArtistsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LibraryArtistsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LibraryArtistsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LibraryArtistsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<int> ordinal = const Value.absent(),
          }) => LibraryArtistsCompanion(id: id, name: name, ordinal: ordinal),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required int ordinal,
              }) => LibraryArtistsCompanion.insert(
                id: id,
                name: name,
                ordinal: ordinal,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LibraryArtistsTable, LibraryArtist>(table),
                  $$LibraryArtistsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({libraryTrackArtistsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (libraryTrackArtistsRefs) db.libraryTrackArtists,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (libraryTrackArtistsRefs)
                    await $_getPrefetchedData<
                      LibraryArtist,
                      $LibraryArtistsTable,
                      LibraryTrackArtist
                    >(
                      currentTable: table,
                      referencedTable: $$LibraryArtistsTableReferences
                          ._libraryTrackArtistsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$LibraryArtistsTableReferences(
                            db,
                            table,
                            p0,
                          ).libraryTrackArtistsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.artistId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$LibraryArtistsTableProcessedTableManager =
    ProcessedTableManager<
      _$MusicDatabase,
      $LibraryArtistsTable,
      LibraryArtist,
      $$LibraryArtistsTableFilterComposer,
      $$LibraryArtistsTableOrderingComposer,
      $$LibraryArtistsTableAnnotationComposer,
      $$LibraryArtistsTableCreateCompanionBuilder,
      $$LibraryArtistsTableUpdateCompanionBuilder,
      (LibraryArtist, $$LibraryArtistsTableReferences),
      LibraryArtist,
      PrefetchHooks Function({bool libraryTrackArtistsRefs})
    >;
typedef $$LibraryTrackArtistsTableCreateCompanionBuilder =
    LibraryTrackArtistsCompanion Function({
      required String trackId,
      required int artistId,
      required int ordinal,
      Value<int> rowid,
    });
typedef $$LibraryTrackArtistsTableUpdateCompanionBuilder =
    LibraryTrackArtistsCompanion Function({
      Value<String> trackId,
      Value<int> artistId,
      Value<int> ordinal,
      Value<int> rowid,
    });

final class $$LibraryTrackArtistsTableReferences
    extends
        BaseReferences<
          _$MusicDatabase,
          $LibraryTrackArtistsTable,
          LibraryTrackArtist
        > {
  $$LibraryTrackArtistsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $LibraryTracksTable _trackIdTable(_$MusicDatabase db) => db
      .libraryTracks
      .createAlias('library_track_artists__track_id__library_tracks__id');

  $$LibraryTracksTableProcessedTableManager get trackId {
    final $_column = $_itemColumn<String>('track_id')!;

    final manager = $$LibraryTracksTableTableManager(
      $_db,
      $_db.libraryTracks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_trackIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $LibraryArtistsTable _artistIdTable(_$MusicDatabase db) => db
      .libraryArtists
      .createAlias('library_track_artists__artist_id__library_artists__id');

  $$LibraryArtistsTableProcessedTableManager get artistId {
    final $_column = $_itemColumn<int>('artist_id')!;

    final manager = $$LibraryArtistsTableTableManager(
      $_db,
      $_db.libraryArtists,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_artistIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$LibraryTrackArtistsTableFilterComposer
    extends Composer<_$MusicDatabase, $LibraryTrackArtistsTable> {
  $$LibraryTrackArtistsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get ordinal => $composableBuilder(
    column: $table.ordinal,
    builder: (column) => ColumnFilters(column),
  );

  $$LibraryTracksTableFilterComposer get trackId {
    final $$LibraryTracksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.libraryTracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibraryTracksTableFilterComposer(
            $db: $db,
            $table: $db.libraryTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$LibraryArtistsTableFilterComposer get artistId {
    final $$LibraryArtistsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.artistId,
      referencedTable: $db.libraryArtists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibraryArtistsTableFilterComposer(
            $db: $db,
            $table: $db.libraryArtists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LibraryTrackArtistsTableOrderingComposer
    extends Composer<_$MusicDatabase, $LibraryTrackArtistsTable> {
  $$LibraryTrackArtistsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get ordinal => $composableBuilder(
    column: $table.ordinal,
    builder: (column) => ColumnOrderings(column),
  );

  $$LibraryTracksTableOrderingComposer get trackId {
    final $$LibraryTracksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.libraryTracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibraryTracksTableOrderingComposer(
            $db: $db,
            $table: $db.libraryTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$LibraryArtistsTableOrderingComposer get artistId {
    final $$LibraryArtistsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.artistId,
      referencedTable: $db.libraryArtists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibraryArtistsTableOrderingComposer(
            $db: $db,
            $table: $db.libraryArtists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LibraryTrackArtistsTableAnnotationComposer
    extends Composer<_$MusicDatabase, $LibraryTrackArtistsTable> {
  $$LibraryTrackArtistsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get ordinal =>
      $composableBuilder(column: $table.ordinal, builder: (column) => column);

  $$LibraryTracksTableAnnotationComposer get trackId {
    final $$LibraryTracksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.libraryTracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibraryTracksTableAnnotationComposer(
            $db: $db,
            $table: $db.libraryTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$LibraryArtistsTableAnnotationComposer get artistId {
    final $$LibraryArtistsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.artistId,
      referencedTable: $db.libraryArtists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibraryArtistsTableAnnotationComposer(
            $db: $db,
            $table: $db.libraryArtists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LibraryTrackArtistsTableTableManager
    extends
        RootTableManager<
          _$MusicDatabase,
          $LibraryTrackArtistsTable,
          LibraryTrackArtist,
          $$LibraryTrackArtistsTableFilterComposer,
          $$LibraryTrackArtistsTableOrderingComposer,
          $$LibraryTrackArtistsTableAnnotationComposer,
          $$LibraryTrackArtistsTableCreateCompanionBuilder,
          $$LibraryTrackArtistsTableUpdateCompanionBuilder,
          (LibraryTrackArtist, $$LibraryTrackArtistsTableReferences),
          LibraryTrackArtist,
          PrefetchHooks Function({bool trackId, bool artistId})
        > {
  $$LibraryTrackArtistsTableTableManager(
    _$MusicDatabase db,
    $LibraryTrackArtistsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LibraryTrackArtistsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LibraryTrackArtistsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$LibraryTrackArtistsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> trackId = const Value.absent(),
                Value<int> artistId = const Value.absent(),
                Value<int> ordinal = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LibraryTrackArtistsCompanion(
                trackId: trackId,
                artistId: artistId,
                ordinal: ordinal,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String trackId,
                required int artistId,
                required int ordinal,
                Value<int> rowid = const Value.absent(),
              }) => LibraryTrackArtistsCompanion.insert(
                trackId: trackId,
                artistId: artistId,
                ordinal: ordinal,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LibraryTrackArtistsTable, LibraryTrackArtist>(
                    table,
                  ),
                  $$LibraryTrackArtistsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({trackId = false, artistId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (trackId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.trackId,
                        referencedTable: $$LibraryTrackArtistsTableReferences
                            ._trackIdTable(db),
                        referencedColumn: $$LibraryTrackArtistsTableReferences
                            ._trackIdTable(db)
                            .id,
                      ) as T;
                    }
                    if (artistId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.artistId,
                        referencedTable: $$LibraryTrackArtistsTableReferences
                            ._artistIdTable(db),
                        referencedColumn: $$LibraryTrackArtistsTableReferences
                            ._artistIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$LibraryTrackArtistsTableProcessedTableManager =
    ProcessedTableManager<
      _$MusicDatabase,
      $LibraryTrackArtistsTable,
      LibraryTrackArtist,
      $$LibraryTrackArtistsTableFilterComposer,
      $$LibraryTrackArtistsTableOrderingComposer,
      $$LibraryTrackArtistsTableAnnotationComposer,
      $$LibraryTrackArtistsTableCreateCompanionBuilder,
      $$LibraryTrackArtistsTableUpdateCompanionBuilder,
      (LibraryTrackArtist, $$LibraryTrackArtistsTableReferences),
      LibraryTrackArtist,
      PrefetchHooks Function({bool trackId, bool artistId})
    >;
typedef $$LibraryPlaylistsTableCreateCompanionBuilder =
    LibraryPlaylistsCompanion Function({
      required String id,
      required String name,
      required int ordinal,
      Value<int> rowid,
    });
typedef $$LibraryPlaylistsTableUpdateCompanionBuilder =
    LibraryPlaylistsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<int> ordinal,
      Value<int> rowid,
    });

final class $$LibraryPlaylistsTableReferences
    extends
        BaseReferences<
          _$MusicDatabase,
          $LibraryPlaylistsTable,
          LibraryPlaylist
        > {
  $$LibraryPlaylistsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<
    $LibraryPlaylistTracksTable,
    List<LibraryPlaylistTrack>
  >
  _libraryPlaylistTracksRefsTable(_$MusicDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.libraryPlaylistTracks,
        aliasName:
            'library_playlists__id__library_playlist_tracks__playlist_id',
      );

  $$LibraryPlaylistTracksTableProcessedTableManager
  get libraryPlaylistTracksRefs {
    final manager = $$LibraryPlaylistTracksTableTableManager(
      $_db,
      $_db.libraryPlaylistTracks,
    ).filter((f) => f.playlistId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _libraryPlaylistTracksRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$LibraryPlaylistsTableFilterComposer
    extends Composer<_$MusicDatabase, $LibraryPlaylistsTable> {
  $$LibraryPlaylistsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ordinal => $composableBuilder(
    column: $table.ordinal,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> libraryPlaylistTracksRefs(
    Expression<bool> Function($$LibraryPlaylistTracksTableFilterComposer f) f,
  ) {
    final $$LibraryPlaylistTracksTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.libraryPlaylistTracks,
          getReferencedColumn: (t) => t.playlistId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$LibraryPlaylistTracksTableFilterComposer(
                $db: $db,
                $table: $db.libraryPlaylistTracks,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$LibraryPlaylistsTableOrderingComposer
    extends Composer<_$MusicDatabase, $LibraryPlaylistsTable> {
  $$LibraryPlaylistsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ordinal => $composableBuilder(
    column: $table.ordinal,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LibraryPlaylistsTableAnnotationComposer
    extends Composer<_$MusicDatabase, $LibraryPlaylistsTable> {
  $$LibraryPlaylistsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get ordinal =>
      $composableBuilder(column: $table.ordinal, builder: (column) => column);

  Expression<T> libraryPlaylistTracksRefs<T extends Object>(
    Expression<T> Function($$LibraryPlaylistTracksTableAnnotationComposer a) f,
  ) {
    final $$LibraryPlaylistTracksTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.libraryPlaylistTracks,
          getReferencedColumn: (t) => t.playlistId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$LibraryPlaylistTracksTableAnnotationComposer(
                $db: $db,
                $table: $db.libraryPlaylistTracks,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$LibraryPlaylistsTableTableManager
    extends
        RootTableManager<
          _$MusicDatabase,
          $LibraryPlaylistsTable,
          LibraryPlaylist,
          $$LibraryPlaylistsTableFilterComposer,
          $$LibraryPlaylistsTableOrderingComposer,
          $$LibraryPlaylistsTableAnnotationComposer,
          $$LibraryPlaylistsTableCreateCompanionBuilder,
          $$LibraryPlaylistsTableUpdateCompanionBuilder,
          (LibraryPlaylist, $$LibraryPlaylistsTableReferences),
          LibraryPlaylist,
          PrefetchHooks Function({bool libraryPlaylistTracksRefs})
        > {
  $$LibraryPlaylistsTableTableManager(
    _$MusicDatabase db,
    $LibraryPlaylistsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LibraryPlaylistsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LibraryPlaylistsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LibraryPlaylistsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> ordinal = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LibraryPlaylistsCompanion(
                id: id,
                name: name,
                ordinal: ordinal,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required int ordinal,
                Value<int> rowid = const Value.absent(),
              }) => LibraryPlaylistsCompanion.insert(
                id: id,
                name: name,
                ordinal: ordinal,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LibraryPlaylistsTable, LibraryPlaylist>(table),
                  $$LibraryPlaylistsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({libraryPlaylistTracksRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (libraryPlaylistTracksRefs) db.libraryPlaylistTracks,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (libraryPlaylistTracksRefs)
                    await $_getPrefetchedData<
                      LibraryPlaylist,
                      $LibraryPlaylistsTable,
                      LibraryPlaylistTrack
                    >(
                      currentTable: table,
                      referencedTable: $$LibraryPlaylistsTableReferences
                          ._libraryPlaylistTracksRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$LibraryPlaylistsTableReferences(
                            db,
                            table,
                            p0,
                          ).libraryPlaylistTracksRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.playlistId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$LibraryPlaylistsTableProcessedTableManager =
    ProcessedTableManager<
      _$MusicDatabase,
      $LibraryPlaylistsTable,
      LibraryPlaylist,
      $$LibraryPlaylistsTableFilterComposer,
      $$LibraryPlaylistsTableOrderingComposer,
      $$LibraryPlaylistsTableAnnotationComposer,
      $$LibraryPlaylistsTableCreateCompanionBuilder,
      $$LibraryPlaylistsTableUpdateCompanionBuilder,
      (LibraryPlaylist, $$LibraryPlaylistsTableReferences),
      LibraryPlaylist,
      PrefetchHooks Function({bool libraryPlaylistTracksRefs})
    >;
typedef $$LibraryPlaylistTracksTableCreateCompanionBuilder =
    LibraryPlaylistTracksCompanion Function({
      required String playlistId,
      required String trackId,
      required int ordinal,
      Value<int> rowid,
    });
typedef $$LibraryPlaylistTracksTableUpdateCompanionBuilder =
    LibraryPlaylistTracksCompanion Function({
      Value<String> playlistId,
      Value<String> trackId,
      Value<int> ordinal,
      Value<int> rowid,
    });

final class $$LibraryPlaylistTracksTableReferences
    extends
        BaseReferences<
          _$MusicDatabase,
          $LibraryPlaylistTracksTable,
          LibraryPlaylistTrack
        > {
  $$LibraryPlaylistTracksTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $LibraryPlaylistsTable _playlistIdTable(_$MusicDatabase db) =>
      db.libraryPlaylists.createAlias(
        'library_playlist_tracks__playlist_id__library_playlists__id',
      );

  $$LibraryPlaylistsTableProcessedTableManager get playlistId {
    final $_column = $_itemColumn<String>('playlist_id')!;

    final manager = $$LibraryPlaylistsTableTableManager(
      $_db,
      $_db.libraryPlaylists,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_playlistIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $LibraryTracksTable _trackIdTable(_$MusicDatabase db) => db
      .libraryTracks
      .createAlias('library_playlist_tracks__track_id__library_tracks__id');

  $$LibraryTracksTableProcessedTableManager get trackId {
    final $_column = $_itemColumn<String>('track_id')!;

    final manager = $$LibraryTracksTableTableManager(
      $_db,
      $_db.libraryTracks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_trackIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$LibraryPlaylistTracksTableFilterComposer
    extends Composer<_$MusicDatabase, $LibraryPlaylistTracksTable> {
  $$LibraryPlaylistTracksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get ordinal => $composableBuilder(
    column: $table.ordinal,
    builder: (column) => ColumnFilters(column),
  );

  $$LibraryPlaylistsTableFilterComposer get playlistId {
    final $$LibraryPlaylistsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.libraryPlaylists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibraryPlaylistsTableFilterComposer(
            $db: $db,
            $table: $db.libraryPlaylists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$LibraryTracksTableFilterComposer get trackId {
    final $$LibraryTracksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.libraryTracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibraryTracksTableFilterComposer(
            $db: $db,
            $table: $db.libraryTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LibraryPlaylistTracksTableOrderingComposer
    extends Composer<_$MusicDatabase, $LibraryPlaylistTracksTable> {
  $$LibraryPlaylistTracksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get ordinal => $composableBuilder(
    column: $table.ordinal,
    builder: (column) => ColumnOrderings(column),
  );

  $$LibraryPlaylistsTableOrderingComposer get playlistId {
    final $$LibraryPlaylistsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.libraryPlaylists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibraryPlaylistsTableOrderingComposer(
            $db: $db,
            $table: $db.libraryPlaylists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$LibraryTracksTableOrderingComposer get trackId {
    final $$LibraryTracksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.libraryTracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibraryTracksTableOrderingComposer(
            $db: $db,
            $table: $db.libraryTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LibraryPlaylistTracksTableAnnotationComposer
    extends Composer<_$MusicDatabase, $LibraryPlaylistTracksTable> {
  $$LibraryPlaylistTracksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get ordinal =>
      $composableBuilder(column: $table.ordinal, builder: (column) => column);

  $$LibraryPlaylistsTableAnnotationComposer get playlistId {
    final $$LibraryPlaylistsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.libraryPlaylists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibraryPlaylistsTableAnnotationComposer(
            $db: $db,
            $table: $db.libraryPlaylists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$LibraryTracksTableAnnotationComposer get trackId {
    final $$LibraryTracksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.libraryTracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibraryTracksTableAnnotationComposer(
            $db: $db,
            $table: $db.libraryTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LibraryPlaylistTracksTableTableManager
    extends
        RootTableManager<
          _$MusicDatabase,
          $LibraryPlaylistTracksTable,
          LibraryPlaylistTrack,
          $$LibraryPlaylistTracksTableFilterComposer,
          $$LibraryPlaylistTracksTableOrderingComposer,
          $$LibraryPlaylistTracksTableAnnotationComposer,
          $$LibraryPlaylistTracksTableCreateCompanionBuilder,
          $$LibraryPlaylistTracksTableUpdateCompanionBuilder,
          (LibraryPlaylistTrack, $$LibraryPlaylistTracksTableReferences),
          LibraryPlaylistTrack,
          PrefetchHooks Function({bool playlistId, bool trackId})
        > {
  $$LibraryPlaylistTracksTableTableManager(
    _$MusicDatabase db,
    $LibraryPlaylistTracksTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LibraryPlaylistTracksTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$LibraryPlaylistTracksTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$LibraryPlaylistTracksTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> playlistId = const Value.absent(),
                Value<String> trackId = const Value.absent(),
                Value<int> ordinal = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LibraryPlaylistTracksCompanion(
                playlistId: playlistId,
                trackId: trackId,
                ordinal: ordinal,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String playlistId,
                required String trackId,
                required int ordinal,
                Value<int> rowid = const Value.absent(),
              }) => LibraryPlaylistTracksCompanion.insert(
                playlistId: playlistId,
                trackId: trackId,
                ordinal: ordinal,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $LibraryPlaylistTracksTable,
                    LibraryPlaylistTrack
                  >(table),
                  $$LibraryPlaylistTracksTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({playlistId = false, trackId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (playlistId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.playlistId,
                        referencedTable: $$LibraryPlaylistTracksTableReferences
                            ._playlistIdTable(db),
                        referencedColumn: $$LibraryPlaylistTracksTableReferences
                            ._playlistIdTable(db)
                            .id,
                      ) as T;
                    }
                    if (trackId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.trackId,
                        referencedTable: $$LibraryPlaylistTracksTableReferences
                            ._trackIdTable(db),
                        referencedColumn: $$LibraryPlaylistTracksTableReferences
                            ._trackIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$LibraryPlaylistTracksTableProcessedTableManager =
    ProcessedTableManager<
      _$MusicDatabase,
      $LibraryPlaylistTracksTable,
      LibraryPlaylistTrack,
      $$LibraryPlaylistTracksTableFilterComposer,
      $$LibraryPlaylistTracksTableOrderingComposer,
      $$LibraryPlaylistTracksTableAnnotationComposer,
      $$LibraryPlaylistTracksTableCreateCompanionBuilder,
      $$LibraryPlaylistTracksTableUpdateCompanionBuilder,
      (LibraryPlaylistTrack, $$LibraryPlaylistTracksTableReferences),
      LibraryPlaylistTrack,
      PrefetchHooks Function({bool playlistId, bool trackId})
    >;
typedef $$LibrarySettingsTableCreateCompanionBuilder =
    LibrarySettingsCompanion Function({
      Value<int> id,
      Value<String?> selectedId,
      Value<String?> playingId,
      Value<String?> trackId,
      required double position,
      required double volume,
      required bool shuffle,
      required String repeatMode,
      required int importLimit,
    });
typedef $$LibrarySettingsTableUpdateCompanionBuilder =
    LibrarySettingsCompanion Function({
      Value<int> id,
      Value<String?> selectedId,
      Value<String?> playingId,
      Value<String?> trackId,
      Value<double> position,
      Value<double> volume,
      Value<bool> shuffle,
      Value<String> repeatMode,
      Value<int> importLimit,
    });

final class $$LibrarySettingsTableReferences
    extends
        BaseReferences<_$MusicDatabase, $LibrarySettingsTable, LibrarySetting> {
  $$LibrarySettingsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $LibraryTracksTable _trackIdTable(_$MusicDatabase db) => db
      .libraryTracks
      .createAlias('library_settings__track_id__library_tracks__id');

  $$LibraryTracksTableProcessedTableManager? get trackId {
    final $_column = $_itemColumn<String>('track_id');
    if ($_column == null) return null;
    final manager = $$LibraryTracksTableTableManager(
      $_db,
      $_db.libraryTracks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_trackIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$LibrarySettingsTableFilterComposer
    extends Composer<_$MusicDatabase, $LibrarySettingsTable> {
  $$LibrarySettingsTableFilterComposer({
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

  ColumnFilters<String> get selectedId => $composableBuilder(
    column: $table.selectedId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get playingId => $composableBuilder(
    column: $table.playingId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get volume => $composableBuilder(
    column: $table.volume,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get shuffle => $composableBuilder(
    column: $table.shuffle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get repeatMode => $composableBuilder(
    column: $table.repeatMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get importLimit => $composableBuilder(
    column: $table.importLimit,
    builder: (column) => ColumnFilters(column),
  );

  $$LibraryTracksTableFilterComposer get trackId {
    final $$LibraryTracksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.libraryTracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibraryTracksTableFilterComposer(
            $db: $db,
            $table: $db.libraryTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LibrarySettingsTableOrderingComposer
    extends Composer<_$MusicDatabase, $LibrarySettingsTable> {
  $$LibrarySettingsTableOrderingComposer({
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

  ColumnOrderings<String> get selectedId => $composableBuilder(
    column: $table.selectedId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get playingId => $composableBuilder(
    column: $table.playingId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get volume => $composableBuilder(
    column: $table.volume,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get shuffle => $composableBuilder(
    column: $table.shuffle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get repeatMode => $composableBuilder(
    column: $table.repeatMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get importLimit => $composableBuilder(
    column: $table.importLimit,
    builder: (column) => ColumnOrderings(column),
  );

  $$LibraryTracksTableOrderingComposer get trackId {
    final $$LibraryTracksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.libraryTracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibraryTracksTableOrderingComposer(
            $db: $db,
            $table: $db.libraryTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LibrarySettingsTableAnnotationComposer
    extends Composer<_$MusicDatabase, $LibrarySettingsTable> {
  $$LibrarySettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get selectedId => $composableBuilder(
    column: $table.selectedId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get playingId =>
      $composableBuilder(column: $table.playingId, builder: (column) => column);

  GeneratedColumn<double> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<double> get volume =>
      $composableBuilder(column: $table.volume, builder: (column) => column);

  GeneratedColumn<bool> get shuffle =>
      $composableBuilder(column: $table.shuffle, builder: (column) => column);

  GeneratedColumn<String> get repeatMode => $composableBuilder(
    column: $table.repeatMode,
    builder: (column) => column,
  );

  GeneratedColumn<int> get importLimit => $composableBuilder(
    column: $table.importLimit,
    builder: (column) => column,
  );

  $$LibraryTracksTableAnnotationComposer get trackId {
    final $$LibraryTracksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.libraryTracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibraryTracksTableAnnotationComposer(
            $db: $db,
            $table: $db.libraryTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LibrarySettingsTableTableManager
    extends
        RootTableManager<
          _$MusicDatabase,
          $LibrarySettingsTable,
          LibrarySetting,
          $$LibrarySettingsTableFilterComposer,
          $$LibrarySettingsTableOrderingComposer,
          $$LibrarySettingsTableAnnotationComposer,
          $$LibrarySettingsTableCreateCompanionBuilder,
          $$LibrarySettingsTableUpdateCompanionBuilder,
          (LibrarySetting, $$LibrarySettingsTableReferences),
          LibrarySetting,
          PrefetchHooks Function({bool trackId})
        > {
  $$LibrarySettingsTableTableManager(
    _$MusicDatabase db,
    $LibrarySettingsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LibrarySettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LibrarySettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LibrarySettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> selectedId = const Value.absent(),
                Value<String?> playingId = const Value.absent(),
                Value<String?> trackId = const Value.absent(),
                Value<double> position = const Value.absent(),
                Value<double> volume = const Value.absent(),
                Value<bool> shuffle = const Value.absent(),
                Value<String> repeatMode = const Value.absent(),
                Value<int> importLimit = const Value.absent(),
              }) => LibrarySettingsCompanion(
                id: id,
                selectedId: selectedId,
                playingId: playingId,
                trackId: trackId,
                position: position,
                volume: volume,
                shuffle: shuffle,
                repeatMode: repeatMode,
                importLimit: importLimit,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> selectedId = const Value.absent(),
                Value<String?> playingId = const Value.absent(),
                Value<String?> trackId = const Value.absent(),
                required double position,
                required double volume,
                required bool shuffle,
                required String repeatMode,
                required int importLimit,
              }) => LibrarySettingsCompanion.insert(
                id: id,
                selectedId: selectedId,
                playingId: playingId,
                trackId: trackId,
                position: position,
                volume: volume,
                shuffle: shuffle,
                repeatMode: repeatMode,
                importLimit: importLimit,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LibrarySettingsTable, LibrarySetting>(table),
                  $$LibrarySettingsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({trackId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (trackId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.trackId,
                        referencedTable: $$LibrarySettingsTableReferences
                            ._trackIdTable(db),
                        referencedColumn: $$LibrarySettingsTableReferences
                            ._trackIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$LibrarySettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$MusicDatabase,
      $LibrarySettingsTable,
      LibrarySetting,
      $$LibrarySettingsTableFilterComposer,
      $$LibrarySettingsTableOrderingComposer,
      $$LibrarySettingsTableAnnotationComposer,
      $$LibrarySettingsTableCreateCompanionBuilder,
      $$LibrarySettingsTableUpdateCompanionBuilder,
      (LibrarySetting, $$LibrarySettingsTableReferences),
      LibrarySetting,
      PrefetchHooks Function({bool trackId})
    >;

class $MusicDatabaseManager {
  final _$MusicDatabase _db;
  $MusicDatabaseManager(this._db);
  $$LibraryTracksTableTableManager get libraryTracks =>
      $$LibraryTracksTableTableManager(_db, _db.libraryTracks);
  $$LibraryArtistsTableTableManager get libraryArtists =>
      $$LibraryArtistsTableTableManager(_db, _db.libraryArtists);
  $$LibraryTrackArtistsTableTableManager get libraryTrackArtists =>
      $$LibraryTrackArtistsTableTableManager(_db, _db.libraryTrackArtists);
  $$LibraryPlaylistsTableTableManager get libraryPlaylists =>
      $$LibraryPlaylistsTableTableManager(_db, _db.libraryPlaylists);
  $$LibraryPlaylistTracksTableTableManager get libraryPlaylistTracks =>
      $$LibraryPlaylistTracksTableTableManager(_db, _db.libraryPlaylistTracks);
  $$LibrarySettingsTableTableManager get librarySettings =>
      $$LibrarySettingsTableTableManager(_db, _db.librarySettings);
}
