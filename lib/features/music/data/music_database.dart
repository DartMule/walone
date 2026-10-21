import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart' show listEquals;

import '../domain/music.dart';

part 'music_database.g.dart';

class LibraryTracks extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get filename => text().unique()();
  RealColumn get duration => real()();
  TextColumn get sourceId => text().nullable()();
  IntColumn get ordinal => integer()();
  @override
  Set<Column> get primaryKey => {id};
}

class LibraryArtists extends Table {
  IntColumn get id => integer().autoIncrement()();
  // Регистр значим: объединение имён подтверждает пользователь при импорте.
  TextColumn get name => text().unique()();
  IntColumn get ordinal => integer()();
}

@TableIndex(name: 'track_artists_by_artist', columns: {#artistId})
class LibraryTrackArtists extends Table {
  TextColumn get trackId =>
      text().references(LibraryTracks, #id, onDelete: KeyAction.cascade)();
  IntColumn get artistId =>
      integer().references(LibraryArtists, #id, onDelete: KeyAction.restrict)();
  IntColumn get ordinal => integer()();
  @override
  Set<Column> get primaryKey => {trackId, artistId};
  @override
  List<Set<Column>> get uniqueKeys => [
    {trackId, ordinal},
  ];
}

class LibraryPlaylists extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get ordinal => integer()();
  @override
  Set<Column> get primaryKey => {id};
}

@TableIndex(name: 'playlist_tracks_by_track', columns: {#trackId})
class LibraryPlaylistTracks extends Table {
  TextColumn get playlistId =>
      text().references(LibraryPlaylists, #id, onDelete: KeyAction.cascade)();
  TextColumn get trackId =>
      text().references(LibraryTracks, #id, onDelete: KeyAction.cascade)();
  IntColumn get ordinal => integer()();
  @override
  Set<Column> get primaryKey => {playlistId, trackId};
  @override
  List<Set<Column>> get uniqueKeys => [
    {playlistId, ordinal},
  ];
}

class LibrarySettings extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  TextColumn get selectedId => text().nullable()();
  TextColumn get playingId => text().nullable()();
  TextColumn get trackId => text().nullable().references(
    LibraryTracks,
    #id,
    onDelete: KeyAction.setNull,
  )();
  RealColumn get position => real()();
  RealColumn get volume => real()();
  BoolColumn get shuffle => boolean()();
  TextColumn get repeatMode => text()();
  IntColumn get importLimit => integer()();
  @override
  Set<Column> get primaryKey => {id};
  @override
  List<String> get customConstraints => ['CHECK (id = 1)'];
}

@DriftDatabase(
  tables: [
    LibraryTracks,
    LibraryArtists,
    LibraryTrackArtists,
    LibraryPlaylists,
    LibraryPlaylistTracks,
    LibrarySettings,
  ],
)
class MusicDatabase extends _$MusicDatabase {
  MusicDatabase(super.executor);
  factory MusicDatabase.open(File file) =>
      MusicDatabase(NativeDatabase.createInBackground(file));

  @override
  int get schemaVersion => 1;
  @override
  MigrationStrategy get migration => MigrationStrategy(
    beforeOpen: (_) async {
      await customStatement('PRAGMA foreign_keys = ON');
      await customStatement('PRAGMA busy_timeout = 5000');
    },
  );

  Future<MusicLibrary?> load() => transaction(() async {
    final settings = await select(librarySettings).getSingleOrNull();
    if (settings == null) return null;
    if ((await customSelect('PRAGMA foreign_key_check').get()).isNotEmpty) {
      throw const FormatException('Нарушены связи базы медиатеки');
    }
    final artists = await (select(
      libraryArtists,
    )..orderBy([(t) => OrderingTerm.asc(t.ordinal)])).get();
    final names = {for (final artist in artists) artist.id: artist.name};
    final trackArtists = <String, List<String>>{};
    for (final link in await (select(
      libraryTrackArtists,
    )..orderBy([(t) => OrderingTerm.asc(t.ordinal)])).get()) {
      trackArtists
          .putIfAbsent(link.trackId, () => [])
          .add(names[link.artistId]!);
    }
    final members = <String, List<String>>{};
    for (final link in await (select(
      libraryPlaylistTracks,
    )..orderBy([(t) => OrderingTerm.asc(t.ordinal)])).get()) {
      members.putIfAbsent(link.playlistId, () => []).add(link.trackId);
    }
    final tracks = await (select(
      libraryTracks,
    )..orderBy([(t) => OrderingTerm.asc(t.ordinal)])).get();
    final playlists = await (select(
      libraryPlaylists,
    )..orderBy([(t) => OrderingTerm.asc(t.ordinal)])).get();
    final library = MusicLibrary(
      tracks: [
        for (final t in tracks)
          MusicTrack(
            id: t.id,
            title: t.title,
            filename: t.filename,
            duration: t.duration,
            sourceID: t.sourceId,
            artists: trackArtists[t.id] ?? [],
          ),
      ],
      artists: artists.map((a) => a.name).toList(),
      playlists: [
        for (final p in playlists)
          MusicPlaylist(id: p.id, name: p.name, trackIDs: members[p.id] ?? []),
      ],
      selectedID: settings.selectedId,
      playingID: settings.playingId,
      trackID: settings.trackId,
      position: settings.position,
      volume: settings.volume,
      shuffle: settings.shuffle,
      repeatMode: MusicRepeat.values.byName(settings.repeatMode),
      importLimit: settings.importLimit,
    );
    return MusicLibrary.fromJson(library.toJson());
  });

  // Строка настроек появляется только вместе со всей медиатекой: это также
  // маркер завершённой миграции, включая совершенно пустую коллекцию.
  Future<MusicLibrary> initializeLibrary(MusicLibrary initial) =>
      transaction(() async {
        final existing = await load();
        if (existing != null) return existing;
        await _write(initial, null);
        return initial;
      });

  Future<void> save(MusicLibrary next, MusicLibrary previous) =>
      transaction(() => _write(next, previous));

  Future<void> _write(MusicLibrary next, MusicLibrary? previous) async {
    MusicLibrary.fromJson(next.toJson());
    final catalogChanged =
        previous == null ||
        !listEquals(previous.tracks, next.tracks) ||
        !listEquals(previous.artists, next.artists) ||
        !listEquals(previous.playlists, next.playlists);
    if (catalogChanged) {
      final oldTracks = {
        for (var i = 0; i < (previous?.tracks.length ?? 0); i++)
          previous!.tracks[i].id: (i, previous.tracks[i]),
      };
      final oldPlaylists = {
        for (var i = 0; i < (previous?.playlists.length ?? 0); i++)
          previous!.playlists[i].id: (i, previous.playlists[i]),
      };
      final oldArtists = {
        for (var i = 0; i < (previous?.artists.length ?? 0); i++)
          previous!.artists[i]: i,
      };
      await batch((b) {
        for (var i = 0; i < next.artists.length; i++) {
          final name = next.artists[i];
          if (!oldArtists.containsKey(name)) {
            b.insert(
              libraryArtists,
              LibraryArtistsCompanion.insert(name: name, ordinal: i),
            );
          }
        }
      });
      final artists = {
        for (final a in await select(libraryArtists).get()) a.name: a.id,
      };
      await batch((b) {
        for (var i = 0; i < next.artists.length; i++) {
          final name = next.artists[i];
          if (oldArtists.containsKey(name) && oldArtists[name] != i) {
            b.update(
              libraryArtists,
              LibraryArtistsCompanion(ordinal: Value(i)),
              where: (t) => t.id.equals(artists[name]!),
            );
          }
        }
        for (var i = 0; i < next.tracks.length; i++) {
          final t = next.tracks[i];
          final old = oldTracks[t.id];
          if (old == null ||
              old.$1 != i ||
              old.$2.title != t.title ||
              old.$2.filename != t.filename ||
              old.$2.duration != t.duration ||
              old.$2.sourceID != t.sourceID) {
            b.insert(
              libraryTracks,
              LibraryTracksCompanion.insert(
                id: t.id,
                title: t.title,
                filename: t.filename,
                duration: t.duration,
                sourceId: Value(t.sourceID),
                ordinal: i,
              ),
              onConflict: DoUpdate(
                (_) => LibraryTracksCompanion(
                  title: Value(t.title),
                  filename: Value(t.filename),
                  duration: Value(t.duration),
                  sourceId: Value(t.sourceID),
                  ordinal: Value(i),
                ),
              ),
            );
          }
        }
        for (var i = 0; i < next.playlists.length; i++) {
          final p = next.playlists[i];
          final old = oldPlaylists[p.id];
          if (old == null || old.$1 != i || old.$2.name != p.name) {
            b.insert(
              libraryPlaylists,
              LibraryPlaylistsCompanion.insert(
                id: p.id,
                name: p.name,
                ordinal: i,
              ),
              onConflict: DoUpdate(
                (_) => LibraryPlaylistsCompanion(
                  name: Value(p.name),
                  ordinal: Value(i),
                ),
              ),
            );
          }
        }
        for (final t in next.tracks) {
          if (!listEquals(oldTracks[t.id]?.$2.artists, t.artists)) {
            b.deleteWhere(libraryTrackArtists, (a) => a.trackId.equals(t.id));
            b.insertAll(libraryTrackArtists, [
              for (var i = 0; i < t.artists.length; i++)
                LibraryTrackArtistsCompanion.insert(
                  trackId: t.id,
                  artistId: artists[t.artists[i]]!,
                  ordinal: i,
                ),
            ]);
          }
        }
        for (final p in next.playlists) {
          if (!listEquals(oldPlaylists[p.id]?.$2.trackIDs, p.trackIDs)) {
            b.deleteWhere(
              libraryPlaylistTracks,
              (t) => t.playlistId.equals(p.id),
            );
            b.insertAll(libraryPlaylistTracks, [
              for (var i = 0; i < p.trackIDs.length; i++)
                LibraryPlaylistTracksCompanion.insert(
                  playlistId: p.id,
                  trackId: p.trackIDs[i],
                  ordinal: i,
                ),
            ]);
          }
        }
        final trackIDs = next.tracks.map((t) => t.id).toSet();
        final playlistIDs = next.playlists.map((p) => p.id).toSet();
        final artistNames = next.artists.toSet();
        for (final id in oldPlaylists.keys.where(
          (id) => !playlistIDs.contains(id),
        )) {
          b.deleteWhere(libraryPlaylists, (p) => p.id.equals(id));
        }
        // Настройки ссылаются на ещё существующие треки; обновляем их до удаления.
        b.insert(
          librarySettings,
          _settings(next),
          mode: InsertMode.insertOrReplace,
        );
        for (final id in oldTracks.keys.where((id) => !trackIDs.contains(id))) {
          b.deleteWhere(libraryTracks, (t) => t.id.equals(id));
        }
        for (final name in oldArtists.keys.where(
          (name) => !artistNames.contains(name),
        )) {
          b.deleteWhere(libraryArtists, (a) => a.id.equals(artists[name]!));
        }
      });
    } else {
      await into(librarySettings).insertOnConflictUpdate(_settings(next));
    }
  }

  LibrarySettingsCompanion _settings(MusicLibrary library) =>
      LibrarySettingsCompanion.insert(
        id: const Value(1),
        selectedId: Value(library.selectedID),
        playingId: Value(library.playingID),
        trackId: Value(library.trackID),
        position: library.position,
        volume: library.volume,
        shuffle: library.shuffle,
        repeatMode: library.repeatMode.name,
        importLimit: library.importLimit,
      );
}
