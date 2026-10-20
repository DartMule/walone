import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../../core/audio.dart';
import '../../../core/storage.dart';
import '../domain/music.dart';
import 'music_archive.dart';

class MusicRepository {
  MusicRepository(this.directory, {this.audioFactory = DesktopAudio.new})
    : store = JsonStore(File(p.join(directory.path, 'library.json')));
  final Directory directory;
  final JsonStore store;
  final AudioFactory audioFactory;
  MusicLibrary library = MusicLibrary();

  Future<void> initialize() async {
    try {
      final json = await store.read();
      if (json != null) library = MusicLibrary.fromJson(json);
    } catch (_) {
      store.protect();
      throw StateError(
        'Медиатека повреждена. Файлы сохранены без перезаписи: ${directory.path}',
      );
    }
  }

  Future<void> commit(MusicLibrary next) async {
    MusicLibrary.fromJson(next.toJson());
    await store.write(next.toJson());
    library = next;
  }

  String pathFor(MusicTrack track) => p.join(directory.path, track.filename);

  Future<void> exportArchive(
    String destination, {
    void Function()? check,
  }) async {
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

  Future<void> importArchive(String source, {void Function()? check}) async {
    await directory.create(recursive: true);
    final staging = await directory.createTemp('.archive-');
    final copied = <File>[];
    try {
      final imported = await MusicArchive.read(source, staging.path);
      check?.call();
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

  Future<void> removeUnused(MusicLibrary proposed) async {
    final used = proposed.playlists.expand((p) => p.trackIDs).toSet();
    final removed = proposed.tracks.where((t) => !used.contains(t.id)).toList();
    await commit(
      proposed.copyWith(
        tracks: proposed.tracks.where((t) => used.contains(t.id)).toList(),
      ),
    );
    // Сначала атомарно сохраняем состав, затем удаляем только наши копии.
    await discard(removed);
  }
}
