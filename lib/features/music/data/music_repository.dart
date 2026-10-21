import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../../core/audio.dart';
import '../domain/music.dart';
import 'music_archive.dart';
import 'music_database.dart';

class MusicRepository {
  MusicRepository(this.directory, {this.audioFactory = DesktopAudio.new});
  final Directory directory;
  final AudioFactory audioFactory;
  MusicDatabase? _database;
  Future<void>? _initialization;
  MusicLibrary library = MusicLibrary();

  MusicDatabase get database => _database ??= MusicDatabase.open(
    File(p.join(directory.path, 'library.sqlite')),
  );

  Future<void> initialize() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    try {
      await directory.create(recursive: true);
      final saved = await database.load();
      if (saved != null) {
        library = saved;
        return;
      }
      var initial = MusicLibrary();
      final legacy = File(p.join(directory.path, 'library.json'));
      if (await legacy.exists()) {
        if (await legacy.length() > MusicArchive.maxManifest) {
          throw const FormatException('Слишком большой манифест');
        }
        final bytes = await legacy.readAsBytes();
        initial = MusicLibrary.fromJson(
          jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>,
        );
        final backup = File(
          '${legacy.path}.before-sqlite-${const Uuid().v4()}.bak',
        );
        final temporary = File('${backup.path}.tmp');
        try {
          await temporary.writeAsBytes(bytes, flush: true);
          await temporary.rename(backup.path);
        } finally {
          if (await temporary.exists()) await temporary.delete();
        }
      }
      library = await database.initializeLibrary(initial);
    } catch (error) {
      throw StateError(
        'Не удалось открыть или перенести медиатеку. '
        'Исходные файлы сохранены: ${directory.path}. $error',
      );
    }
  }

  Future<void> commit(MusicLibrary next) async {
    await initialize();
    await database.save(next, library);
    library = next;
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  String pathFor(MusicTrack track) => p.join(directory.path, track.filename);

  Future<void> exportArchive(
    String destination, {
    void Function()? check,
  }) async {
    await initialize();
    final target = p.normalize(p.absolute(destination));
    final root = p.normalize(p.absolute(directory.path));
    if (p.equals(root, target) || p.isWithin(root, target)) {
      throw const FormatException('Сохраните архив вне папки медиатеки');
    }
    final temporary = File('$target.${const Uuid().v4()}.tmp');
    try {
      await MusicArchive.write(temporary.path, directory.path, library);
      check?.call();
      await temporary.rename(target);
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  }

  Future<void> importArchive(
    String source, {
    void Function()? check,
    Future<String> Function(String)? resolveArtist,
  }) async {
    await initialize();
    final staging = await directory.createTemp('.archive-');
    final copied = <File>[];
    try {
      final imported = await MusicArchive.read(source, staging.path);
      check?.call();
      final artists = <String, String>{};
      for (final name in imported.artists) {
        check?.call();
        artists[name] = resolveArtist == null
            ? name
            : await resolveArtist(name);
      }
      final known = {for (final track in library.tracks) track.id: track};
      for (final track in imported.tracks) {
        check?.call();
        final existing = known[track.id];
        final filename = existing?.filename ?? track.filename;
        final target = File(p.join(directory.path, filename));
        if (!await target.exists()) {
          await File(p.join(staging.path, track.filename)).rename(target.path);
          copied.add(target);
        }
        known[track.id] = MusicTrack(
          id: track.id,
          title: track.title,
          filename: filename,
          duration: track.duration,
          sourceID: track.sourceID,
          artists: [for (final name in track.artists) artists[name] ?? name],
        );
      }
      final playlists = [
        for (final playlist in imported.playlists)
          MusicPlaylist(
            id: const Uuid().v4(),
            name: playlist.name,
            trackIDs: playlist.trackIDs,
          ),
      ];
      check?.call();
      final next = library.copyWith(
        tracks: known.values.toList(),
        artists: {...library.artists, ...artists.values}.toList(),
        playingID:
            library.artists.any(
              (name) =>
                  artistMusicID(name) == library.playingID &&
                  !(known[library.trackID]?.artists.contains(name) ?? false),
            )
            ? allMusicID
            : library.playingID,
        playlists: [...library.playlists, ...playlists],
        selectedID: playlists.firstOrNull?.id ?? library.selectedID,
      );
      if (utf8.encode(jsonEncode(next.toJson())).length >
          MusicArchive.maxManifest) {
        throw const FormatException('Объединённая медиатека слишком большая');
      }
      await commit(next);
      copied.clear();
    } finally {
      for (final file in copied) {
        if (await file.exists()) await file.delete();
      }
      await staging.delete(recursive: true);
    }
  }

  Future<MusicTrack> prepareFile(
    String path, {
    String? title,
    String? sourceID,
    String artist = '',
    List<String>? artists,
  }) async {
    if (await FileSystemEntity.type(path, followLinks: false) !=
        FileSystemEntityType.file) {
      throw const FormatException('Папки и ссылки не импортируются');
    }
    final extension = p.extension(path).substring(1).toLowerCase();
    if (!RegExp(r'^[a-z0-9]{1,10}$').hasMatch(extension)) {
      throw const FormatException('Некорректное расширение аудио');
    }
    await directory.create(recursive: true);
    final temporary = File(
      p.join(directory.path, '.${const Uuid().v4()}.$extension'),
    );
    final probe = audioFactory();
    try {
      // Хеш вычисляется по копии: источник может измениться во время импорта.
      if (await File(path).length() > 2147483648) {
        throw const FormatException('Файл больше 2 ГиБ');
      }
      await File(path).copy(temporary.path);
      final digest = await sha256.bind(temporary.openRead()).first;
      final duration = await probe
          .load(temporary.path)
          .timeout(const Duration(seconds: 30));
      final id = digest.toString();
      final existing = library.tracks.where((t) => t.id == id).firstOrNull;
      if (existing != null && await File(pathFor(existing)).exists()) {
        return existing;
      }
      final filename = existing?.filename ?? '$id.$extension';
      await temporary.rename(p.join(directory.path, filename));
      return MusicTrack(
        id: id,
        title: (title ?? p.basenameWithoutExtension(path)).trim(),
        filename: filename,
        duration: duration.inMicroseconds / Duration.microsecondsPerSecond,
        sourceID: sourceID,
        artist: artist,
        artists: artists,
      );
    } finally {
      await probe.dispose();
      if (await temporary.exists()) await temporary.delete();
    }
  }

  Future<void> discard(List<MusicTrack> tracks) async {
    final used = library.tracks.map((t) => t.filename).toSet();
    for (final track in tracks) {
      if (!used.contains(track.filename) &&
          await File(pathFor(track)).exists()) {
        await File(pathFor(track)).delete();
      }
    }
  }
}
