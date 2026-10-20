import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../../../core/storage.dart';
import '../domain/music.dart';

// ZIP без повторного сжатия аудио: потоковая запись и ограниченная память.
class MusicArchive {
  static const manifest = 'walone.json';
  static const maxManifest = 16 * 1024 * 1024;
  static const maxAudio = 2147483648;

  static String _filename(int index, String title, String extension) {
    final clean = title.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f\x7f]'), '_');
    final name = StringBuffer();
    var length = 0;
    for (final rune in clean.runes) {
      final character = String.fromCharCode(rune);
      length += utf8.encode(character).length;
      if (length > 180) break;
      name.write(character);
    }
    final label = name.toString().trim().replaceFirst(RegExp(r'[. ]+$'), '');
    // Номер предотвращает коллизии регистра/Unicode и служебные имена Windows.
    return '${(index + 1).toString().padLeft(3, '0')} - '
        '${label.isEmpty ? 'Без названия' : label}$extension';
  }

  static bool _safeEntry(String name) {
    if (name == manifest) return true;
    final parts = name.split('/');
    return parts.length == 2 &&
        ['audio', 'playlists'].contains(parts.first) &&
        parts.last.isNotEmpty &&
        parts.last != '.' &&
        parts.last != '..' &&
        !RegExp(r'[<>:"\\|?*\x00-\x1f\x7f]').hasMatch(parts.last) &&
        !parts.last.endsWith('.') &&
        !parts.last.endsWith(' ') &&
        utf8.encode(parts.last).length <= 255;
  }

  static Future<void> write(
    String destination,
    String musicDirectory,
    MusicLibrary library,
  ) => Isolate.run(() async {
    final files = {
      for (var i = 0; i < library.tracks.length; i++)
        library.tracks[i].id:
            'audio/${_filename(i, library.tracks[i].title, p.extension(library.tracks[i].filename))}',
    };
    final playlists = {
      for (var i = 0; i < library.playlists.length; i++)
        library.playlists[i].id:
            'playlists/${_filename(i, library.playlists[i].name, '.m3u8')}',
    };
    final json = jsonEncode({
      'format': 'walone-music',
      'version': 2,
      'library': library.toJson(),
      'files': files,
      'playlistFiles': playlists,
    });
    if (utf8.encode(json).length > maxManifest) {
      throw const FormatException('Слишком большой манифест');
    }
    final encoder = ZipFileEncoder()..create(destination);
    try {
      encoder.addArchiveFile(
        ArchiveFile.string(manifest, json)..compression = CompressionType.none,
      );
      for (final track in library.tracks) {
        final path = p.join(musicDirectory, track.filename);
        if (await FileSystemEntity.type(path, followLinks: false) !=
            FileSystemEntityType.file) {
          throw FormatException('Нет аудиофайла: ${track.title}');
        }
        final file = File(path);
        if (await file.length() > maxAudio ||
            (await sha256.bind(file.openRead()).first).toString() != track.id) {
          throw FormatException('Аудиофайл повреждён: ${track.title}');
        }
        final input = InputFileStream(path);
        try {
          encoder.addArchiveFile(
            ArchiveFile.stream(files[track.id]!, input)
              ..compression = CompressionType.none,
          );
        } finally {
          await input.close();
        }
      }
      for (final playlist in library.playlists) {
        encoder.addArchiveFile(
          ArchiveFile.string(
            playlists[playlist.id]!,
            '#EXTM3U\n${playlist.trackIDs.map((id) => '../${files[id]!}\n').join()}',
          )..compression = CompressionType.none,
        );
      }
    } finally {
      await encoder.close();
    }
  });

  // Распаковываем только проверенные имена в отдельную временную папку.
  static Future<MusicLibrary> read(
    String source,
    String staging,
  ) => Isolate.run(() async {
    final input = InputFileStream(source);
    try {
      final directory = ZipDirectory()..read(input);
      final entries = <String, ZipFileHeader>{};
      for (final entry in directory.fileHeaders) {
        final file = entry.file;
        final limit = entry.filename.startsWith('audio/')
            ? maxAudio
            : maxManifest;
        if (file == null ||
            entry.filename != file.filename ||
            !_safeEntry(entry.filename) ||
            entries.containsKey(entry.filename) ||
            ![0, 8].contains(entry.compressionMethod) ||
            file.compressionMethod !=
                (entry.compressionMethod == 0
                    ? CompressionType.none
                    : CompressionType.deflate) ||
            entry.generalPurposeBitFlag & 1 != 0 ||
            file.flags & 1 != 0 ||
            (entry.externalFileAttributes >> 16) & 0xf000 == 0xa000 ||
            entry.uncompressedSize < 0 ||
            entry.uncompressedSize > limit ||
            entry.compressionMethod == 0 &&
                entry.compressedSize != entry.uncompressedSize ||
            file.length != entry.compressedSize) {
          throw const FormatException('Неподдерживаемый архив Walone');
        }
        entries[entry.filename] = entry;
      }
      final metadata = entries[manifest];
      if (metadata == null) {
        throw const FormatException('В архиве нет манифеста Walone');
      }
      final bytes = metadata.file!.getStream().toUint8List();
      if (getCrc32(bytes) != metadata.crc32) {
        throw const FormatException('Манифест архива повреждён');
      }
      final json = jsonMap(jsonDecode(utf8.decode(bytes)));
      if (json['format'] != 'walone-music' ||
          ![1, 2].contains(json['version'])) {
        throw const FormatException('Неизвестная версия архива Walone');
      }
      final library = MusicLibrary.fromJson(jsonMap(json['library']));
      final files = json['version'] == 1
          ? {
              for (final track in library.tracks)
                track.id: 'audio/${track.filename}',
            }
          : Map<String, String>.from(jsonMap(json['files']));
      final playlists = json['version'] == 1
          ? <String, String>{}
          : Map<String, String>.from(jsonMap(json['playlistFiles']));
      final paths = {...files.values, ...playlists.values, manifest};
      if (files.length != library.tracks.length ||
          library.tracks.any((t) => !files.containsKey(t.id)) ||
          json['version'] == 2 &&
              (playlists.length != library.playlists.length ||
                  library.playlists.any((p) => !playlists.containsKey(p.id))) ||
          files.values.any((path) => !path.startsWith('audio/')) ||
          playlists.values.any(
            (path) => !path.startsWith('playlists/') || !path.endsWith('.m3u8'),
          ) ||
          paths.length != files.length + playlists.length + 1 ||
          entries.length != paths.length ||
          !paths.every(entries.containsKey)) {
        throw const FormatException('Состав архива не совпадает с манифестом');
      }
      for (final track in library.tracks) {
        final entry = entries[files[track.id]];
        if (entry == null) {
          throw FormatException('В архиве нет трека: ${track.title}');
        }
        final path = p.join(staging, track.filename);
        final output = OutputFileStream(path);
        try {
          entry.file!.decompress(output);
        } finally {
          await output.close();
        }
        if ((await sha256.bind(File(path).openRead()).first).toString() !=
            track.id) {
          throw FormatException('Трек в архиве повреждён: ${track.title}');
        }
      }
      return library;
    } finally {
      await input.close();
    }
  });
}
