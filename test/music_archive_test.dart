import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:walone/features/music/data/music_repository.dart';
import 'package:walone/features/music/domain/music.dart';
import 'package:walone/features/music/presentation/import_cubit.dart';
import 'package:walone/features/music/presentation/music_cubit.dart';

import 'media_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late MusicRepository source;
  late MusicRepository destination;
  late MusicTrack first;
  late MusicTrack second;
  late File zip;
  late Map<String, String> audioPaths;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('walone-archive-test-');
    source = MusicRepository(
      Directory(p.join(root.path, 'old-pc')),
      audioFactory: FakeAudio.new,
    );
    destination = MusicRepository(
      Directory(p.join(root.path, 'new-pc')),
      audioFactory: FakeAudio.new,
    );
    final file = File(p.join(root.path, 'original.wav'));
    await file.writeAsString('10');
    first = await source.prepareFile(
      file.path,
      title: 'Первый — 夜 🎵',
      sourceID: 'youtube:example:0:10',
    );
    await file.writeAsString('20');
    second = await source.prepareFile(file.path, title: 'Второй трек');
    await source.commit(
      MusicLibrary(
        tracks: [first, second],
        playlists: [
          MusicPlaylist(
            id: 'shared-id',
            name: 'Вечерняя музыка',
            trackIDs: [second.id, first.id],
          ),
          MusicPlaylist(id: 'another', name: 'Другой', trackIDs: [first.id]),
          MusicPlaylist(id: 'empty', name: 'Пустой'),
        ],
        selectedID: 'shared-id',
      ),
    );
    zip = File(p.join(root.path, 'Music.zip'));
    await source.exportArchive(zip.path);
    final archive = ZipDecoder().decodeBytes(await zip.readAsBytes());
    final metadata = jsonDecode(
      utf8.decode(archive.find('walone.json')!.content),
    ) as Map<String, dynamic>;
    audioPaths = Map<String, String>.from(
      metadata['files'] as Map<String, dynamic>,
    );
  });

  tearDown(() async {
    await source.close();
    await destination.close();
    await root.delete(recursive: true);
  });

  Future<void> changeArchive(void Function(Archive) change) async {
    final archive = ZipDecoder().decodeBytes(await zip.readAsBytes());
    change(archive);
    await zip.writeAsBytes(ZipEncoder().encodeBytes(archive));
  }

  test(
    'Распакованный ZIP содержит читаемые Unicode-имена и плейлисты',
    () async {
      final archive = ZipDecoder().decodeBytes(await zip.readAsBytes());
      expect(archive.find('audio/001 - Первый — 夜 🎵.wav'), isNotNull);
      expect(archive.find('audio/002 - Второй трек.wav'), isNotNull);
      final playlist = archive.find('playlists/001 - Вечерняя музыка.m3u8');
      expect(playlist, isNotNull);
      expect(utf8.decode(playlist!.content).split('\n'), [
        '#EXTM3U',
        '../audio/002 - Второй трек.wav',
        '../audio/001 - Первый — 夜 🎵.wav',
        '',
      ]);
      expect(archive.find('playlists/003 - Пустой.m3u8'), isNotNull);
    },
  );

  test(
    'Архивы версии 1 со служебными именами по-прежнему импортируются',
    () async {
      final archive = Archive()
        ..add(
          ArchiveFile.string(
            'walone.json',
            jsonEncode({
              'format': 'walone-music',
              'version': 1,
              'library': source.library.toJson(),
            }),
          ),
        );
      for (final track in source.library.tracks) {
        archive.add(
          ArchiveFile.bytes(
            'audio/${track.filename}',
            await File(source.pathFor(track)).readAsBytes(),
          ),
        );
      }
      await zip.writeAsBytes(ZipEncoder().encodeBytes(archive));
      await destination.importArchive(zip.path);
      expect(destination.library.tracks.map((t) => t.title), [
        first.title,
        second.title,
      ]);
      expect(destination.library.playlists.first.name, 'Вечерняя музыка');
    },
  );

  test(
    'Языки, одинаковые и несовместимые с Windows имена не теряются',
    () async {
      final titles = [
        'Песня',
        'песня',
        '夜の音楽',
        'موسيقى',
        'CON',
        '../a:b?*',
        '🎵' * 100,
      ];
      final tracks = <MusicTrack>[];
      for (var i = 0; i < titles.length; i++) {
        final file = await File(p.join(root.path, 'song.wav'))
            .writeAsString('${i + 30}');
        tracks.add(await source.prepareFile(file.path, title: titles[i]));
      }
      await source.commit(
        MusicLibrary(
          tracks: tracks,
          playlists: [
            MusicPlaylist(
              id: 'unicode',
              name: 'Музыка 夜 موسيقى 🎵',
              trackIDs: tracks.map((t) => t.id).toList(),
            ),
          ],
        ),
      );
      await source.exportArchive(zip.path);
      final decoder = ZipDecoder();
      final archive = decoder.decodeBytes(await zip.readAsBytes());
      final names = archive.files
          .where((f) => f.name.startsWith('audio/'))
          .map((f) => f.name)
          .toList();
      expect(names.toSet(), hasLength(titles.length));
      expect(names[2], contains('夜の音楽'));
      expect(names[3], contains('موسيقى'));
      for (final name in names) {
        expect(
          utf8.encode(p.posix.basename(name)).length,
          lessThanOrEqualTo(255),
        );
        expect(RegExp(r'[<>:"\\|?*]').hasMatch(name), isFalse);
      }
      expect(
        decoder.directory.fileHeaders.every(
          (h) => h.generalPurposeBitFlag & 0x800 != 0,
        ),
        isTrue,
      );
      await destination.importArchive(zip.path);
      expect(destination.library.tracks.map((t) => t.title), titles);
      expect(destination.library.playlists.single.name, 'Музыка 夜 موسيقى 🎵');
    },
  );

  test(
    'Перенос на другой ПК сохраняет имена, списки, порядок и аудио',
    () async {
      // Исходная папка и файлы больше недоступны принимающему ПК.
      await source.close();
      await source.directory.delete(recursive: true);
      final music = MusicCubit(destination);
      await music.initialize();
      final importer = ImportCubit(music, FakeVkSession(root));
      await importer.importArchive(zip.path);
      expect(importer.state.error, isNull);
      expect(importer.state.busy, isFalse);
      expect(music.state.importing, isFalse);
      await importer.close();
      expect(music.state.library.tracks.map((t) => t.toJson()), [
        first.toJson(),
        second.toJson(),
      ]);
      expect(music.state.library.playlists.map((t) => t.name), [
        'Вечерняя музыка',
        'Другой',
        'Пустой',
      ]);
      expect(music.state.library.playlists.first.trackIDs, [
        second.id,
        first.id,
      ]);
      expect(music.state.library.playlists.last.trackIDs, isEmpty);
      expect(await File(destination.pathFor(first)).readAsString(), '10');
      expect(await File(destination.pathFor(second)).readAsString(), '20');
      await music.play(
        trackID: second.id,
        playlistID: music.state.library.playlists.first.id,
      );
      expect(music.state.playing, isTrue);
      expect(music.state.error, isNull);
      await music.close();
      final reopened = MusicRepository(destination.directory);
      addTearDown(reopened.close);
      await reopened.initialize();
      expect(reopened.library.toJson(), destination.library.toJson());
    },
  );

  test('Объединение не удаляет списки и не дублирует аудио', () async {
    await destination.directory.create(recursive: true);
    await File(source.pathFor(first)).copy(destination.pathFor(first));
    await destination.commit(
      MusicLibrary(
        tracks: [first],
        playlists: [
          MusicPlaylist(id: 'shared-id', name: 'Мой', trackIDs: [first.id]),
        ],
        selectedID: 'shared-id',
        volume: 0.3,
        shuffle: true,
      ),
    );
    await destination.importArchive(zip.path);
    await destination.importArchive(zip.path);
    expect(destination.library.tracks, hasLength(2));
    expect(destination.library.playlists, hasLength(7));
    expect(destination.library.playlists.first.name, 'Мой');
    expect(
      destination.library.playlists.map((t) => t.id).toSet(),
      hasLength(7),
    );
    expect(destination.library.volume, 0.3);
    expect(destination.library.shuffle, isTrue);
    expect(await destination.directory.list().length, 3);
  });

  test('Принимается также ZIP Deflate', () async {
    await changeArchive((archive) {
      for (final entry in archive) {
        final bytes = entry.content;
        archive[archive.files.indexOf(entry)] = ArchiveFile.bytes(
          entry.name,
          bytes,
        );
      }
    });
    await destination.importArchive(zip.path);
    expect(destination.library.playlists, hasLength(3));
    expect(await File(destination.pathFor(first)).readAsString(), '10');
  });

  for (final kind in [
    'audio',
    'missing',
    'links',
    'version',
    'path',
    'symlink',
  ]) {
    test('Повреждённый архив ($kind) не меняет медиатеку', () async {
      await destination.commit(MusicLibrary());
      final before = (await destination.database.load())!.toJson();
      await changeArchive((archive) {
        switch (kind) {
          case 'audio':
            archive.removeFile(archive.find(audioPaths[first.id]!)!);
            archive.add(
              ArchiveFile.string(audioPaths[first.id]!, 'bad')
                ..compression = CompressionType.none,
            );
          case 'missing':
            archive.removeFile(archive.find(audioPaths[first.id]!)!);
          case 'path':
            archive.add(
              ArchiveFile.string('../outside.txt', 'bad')
                ..compression = CompressionType.none,
            );
          case 'symlink':
            archive.add(
              ArchiveFile.string(audioPaths[first.id]!, '../outside.txt')
                ..compression = CompressionType.none
                ..mode = 0xa1ff,
            );
          default:
            final entry = archive.find('walone.json')!;
            final json =
                jsonDecode(utf8.decode(entry.content)) as Map<String, dynamic>;
            if (kind == 'version') {
              json['version'] = 99;
            } else {
              final library = json['library'] as Map<String, dynamic>;
              final playlists = library['playlists'] as List<dynamic>;
              (playlists.first as Map<String, dynamic>)['trackIDs'] = [
                'absent',
              ];
            }
            archive.removeFile(entry);
            archive.add(
              ArchiveFile.string('walone.json', jsonEncode(json))
                ..compression = CompressionType.none,
            );
        }
      });
      await expectLater(
        destination.importArchive(zip.path),
        throwsFormatException,
      );
      expect((await destination.database.load())!.toJson(), before);
      expect(await destination.directory.list().length, 1);
      expect(await File(p.join(root.path, 'outside.txt')).exists(), isFalse);
    });
  }

  test(
    'Ошибка сохранения или отмена убирает только новые аудиокопии',
    () async {
      await destination.commit(MusicLibrary());
      final before = (await destination.database.load())!.toJson();
      var checks = 0;
      await expectLater(
        destination.importArchive(
          zip.path,
          check: () {
            if (++checks == 3) throw StateError('Отмена');
          },
        ),
        throwsStateError,
      );
      expect(await destination.directory.list().length, 1);
      await destination.database.customStatement(
        "CREATE TRIGGER reject_track BEFORE INSERT ON library_tracks "
        "BEGIN SELECT RAISE(ABORT, 'test save failure'); END",
      );
      await expectLater(
        destination.importArchive(zip.path),
        throwsA(isException),
      );
      expect((await destination.database.load())!.toJson(), before);
      expect(await destination.directory.list().length, 1);
    },
  );

  test('Неудачный экспорт сохраняет прежний архив', () async {
    final before = await zip.readAsBytes();
    await File(source.pathFor(first)).delete();
    await expectLater(source.exportArchive(zip.path), throwsFormatException);
    expect(await zip.readAsBytes(), before);
    expect(await root.list().where((f) => f.path.endsWith('.tmp')).length, 0);
  });
}
