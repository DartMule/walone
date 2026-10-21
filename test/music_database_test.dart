import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:walone/features/music/data/music_repository.dart';
import 'package:walone/features/music/domain/music.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late File legacy;
  final repositories = <MusicRepository>[];
  MusicRepository repository() {
    final result = MusicRepository(root);
    repositories.add(result);
    return result;
  }

  final first = MusicTrack(
    id: 'a' * 64,
    title: '夜 🎵',
    filename: '${'a' * 64}.mp3',
    duration: 120.5,
    sourceID: 'youtube:example',
    artists: ['Автор', 'Гость'],
  );
  final second = MusicTrack(
    id: 'b' * 64,
    title: 'Второй',
    filename: '${'b' * 64}.wav',
    duration: 12,
    artists: ['автор'],
  );
  MusicLibrary fixture() => MusicLibrary(
    tracks: [second, first],
    artists: ['Неиспользуемый', 'Гость', 'Автор', 'автор'],
    playlists: [
      MusicPlaylist(
        id: 'p',
        name: 'Мой список',
        trackIDs: [first.id, second.id],
      ),
      MusicPlaylist(id: 'empty', name: 'Пустой'),
      MusicPlaylist(id: 'shared', name: 'Общий', trackIDs: [first.id]),
    ],
    selectedID: 'empty',
    playingID: artistMusicID('Гость'),
    trackID: first.id,
    position: 24.5,
    volume: 0.33,
    shuffle: true,
    repeatMode: MusicRepeat.playlist,
    importLimit: 0,
  );

  Future<List<FileSystemEntity>> backups() => root
      .list()
      .where(
        (f) =>
            p.basename(f.path).startsWith('library.json.before-sqlite-') &&
            f.path.endsWith('.bak'),
      )
      .toList();

  setUp(() async {
    root = await Directory.systemTemp.createTemp('walone-sqlite-');
    legacy = File(p.join(root.path, 'library.json'));
  });
  tearDown(() async {
    for (final item in repositories) {
      await item.close();
    }
    repositories.clear();
    await root.delete(recursive: true);
  });

  test(
    'JSON мигрирует полностью; резервная копия и аудио побайтово сохранены',
    () async {
      final initial = fixture();
      final bytes = utf8.encode(
        const JsonEncoder.withIndent('  ').convert(initial.toJson()),
      );
      await legacy.writeAsBytes(bytes);
      final audio = await File(p.join(root.path, first.filename))
          .writeAsBytes([0, 1, 255, 7]);
      final repo = repository();
      await repo.initialize();
      expect(repo.library.toJson(), initial.toJson());
      expect((await repo.database.load())!.toJson(), initial.toJson());
      expect(await legacy.readAsBytes(), bytes);
      expect(await File((await backups()).single.path).readAsBytes(), bytes);
      expect(await audio.readAsBytes(), [0, 1, 255, 7]);
      expect(await File(p.join(root.path, 'library.sqlite')).exists(), isTrue);
      await repo.close();
      final reopened = repository();
      await reopened.initialize();
      expect(reopened.library.toJson(), initial.toJson());
    },
  );

  test(
    'После миграции SQLite имеет приоритет; JSON не импортируется повторно',
    () async {
      await legacy.writeAsString(jsonEncode(fixture().toJson()));
      final repo = repository();
      await repo.initialize();
      final next = repo.library.copyWith(
        tracks: [
          second,
          first.copyWith(title: 'Новое'),
        ],
        importLimit: 42,
      );
      await repo.commit(next);
      await repo.close();
      await legacy.writeAsString('{old broken json');
      final reopened = repository();
      await reopened.initialize();
      expect(reopened.library.toJson(), next.toJson());
      expect(await backups(), hasLength(1));
    },
  );

  test(
    'Старый одиночный исполнитель и отсутствие метаданных поддерживаются',
    () async {
      final json = fixture().toJson()
        ..remove('artists')
        ..remove('importLimit');
      final tracks = json['tracks'] as List;
      (tracks.first as Map)
        ..remove('artists')
        ..['artist'] = 'Tyler, The Creator';
      (tracks.last as Map).remove('artists');
      json['playingID'] = 'p';
      await legacy.writeAsString(jsonEncode(json));
      final repo = repository();
      await repo.initialize();
      expect(repo.library.tracks.first.artists, ['Tyler, The Creator']);
      expect(repo.library.tracks.last.artists, isEmpty);
      expect(repo.library.importLimit, 500);
    },
  );

  test(
    'Повреждённый JSON блокирует любые записи и остаётся нетронутым',
    () async {
      await legacy.writeAsString('{broken');
      final repo = repository();
      await expectLater(repo.initialize(), throwsStateError);
      await expectLater(repo.commit(MusicLibrary()), throwsStateError);
      expect(await legacy.readAsString(), '{broken');
      expect(await backups(), isEmpty);
      expect(await repo.database.load(), isNull);
      await repo.close();
      await legacy.writeAsString(jsonEncode(fixture().toJson()));
      final retry = repository();
      await retry.initialize();
      expect(retry.library.toJson(), fixture().toJson());
    },
  );

  test('Ошибка в середине миграции откатывает всё; повторный запуск переносит данные', () async {
    final bytes = utf8.encode(jsonEncode(fixture().toJson()));
    await legacy.writeAsBytes(bytes);
    final repo = repository();
    await repo.database.customStatement(
      "CREATE TRIGGER fail_migration BEFORE INSERT ON library_playlist_tracks "
      "BEGIN SELECT RAISE(ABORT, 'test migration failure'); END",
    );
    await expectLater(repo.initialize(), throwsStateError);
    expect(await repo.database.load(), isNull);
    expect(
      await repo.database.select(repo.database.libraryTracks).get(),
      isEmpty,
    );
    expect(
      await repo.database.select(repo.database.libraryArtists).get(),
      isEmpty,
    );
    expect(await legacy.readAsBytes(), bytes);
    expect(await File((await backups()).single.path).readAsBytes(), bytes);
    await repo.database.customStatement('DROP TRIGGER fail_migration');
    await repo.close();
    final retry = repository();
    await retry.initialize();
    expect(retry.library.toJson(), fixture().toJson());
  });

  test('Настройки не перезаписывают каталог; связи и ID исполнителей сохраняются', () async {
    final repo = repository();
    await repo.commit(fixture());
    final original = {
      for (final a
          in await repo.database.select(repo.database.libraryArtists).get())
        a.name: a.id,
    };
    for (final table in [
      'library_tracks',
      'library_artists',
      'library_track_artists',
      'library_playlists',
      'library_playlist_tracks',
    ]) {
      for (final operation in ['INSERT', 'UPDATE', 'DELETE']) {
        await repo.database.customStatement(
          'CREATE TRIGGER guard_${table}_$operation BEFORE $operation ON $table '
          "BEGIN SELECT RAISE(ABORT, 'catalog must not change'); END",
        );
      }
    }
    final next = repo.library.copyWith(position: 30, volume: 0.5);
    await repo.commit(next);
    expect((await repo.database.load())!.toJson(), next.toJson());
    for (final row
        in await repo.database
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type = 'trigger'",
            )
            .get()) {
      await repo.database.customStatement(
        'DROP TRIGGER ${row.read<String>('name')}',
      );
    }
    await repo.commit(
      next.copyWith(
        selectedID: 'p',
        artists: next.artists.reversed.toList(),
        tracks: [
          first.copyWith(artists: ['Гость', 'Автор']),
          second,
        ],
        playlists: [
          next.playlists.first.copyWith(trackIDs: [second.id, first.id]),
          next.playlists.last,
        ],
      ),
    );
    expect((await repo.database.load())!.toJson(), repo.library.toJson());
    final after = {
      for (final a
          in await repo.database.select(repo.database.libraryArtists).get())
        a.name: a.id,
    };
    expect(after, original);
    expect(after['Автор'], isNot(after['автор']));
  });

  test(
    'Неудачный commit сохраняет предыдущую базу и снимок в памяти',
    () async {
      final repo = repository();
      await repo.commit(fixture());
      final before = repo.library.toJson();
      await repo.database.customStatement(
        "CREATE TRIGGER reject_settings BEFORE INSERT ON library_settings "
        "BEGIN SELECT RAISE(ABORT, 'test commit failure'); END",
      );
      await expectLater(
        repo.commit(
          repo.library.copyWith(
            tracks: [
              second,
              first.copyWith(title: 'Не сохранить'),
            ],
          ),
        ),
        throwsA(isException),
      );
      expect(repo.library.toJson(), before);
      expect((await repo.database.load())!.toJson(), before);
    },
  );

  test('Повреждённая SQLite не заменяется старым JSON', () async {
    await legacy.writeAsString(jsonEncode(fixture().toJson()));
    final sqlite = await File(p.join(root.path, 'library.sqlite'))
        .writeAsString('broken SQLite');
    final repo = repository();
    await expectLater(repo.initialize(), throwsStateError);
    await expectLater(repo.commit(MusicLibrary()), throwsStateError);
    expect(await sqlite.readAsString(), 'broken SQLite');
    expect(await backups(), isEmpty);
  });
}
