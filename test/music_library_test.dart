import 'dart:convert';
import 'dart:io';
import 'dart:ui' show ImageByteFormat;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:walone/features/music/data/music_repository.dart';
import 'package:walone/features/music/data/music_process.dart';
import 'package:walone/features/music/domain/import.dart';
import 'package:walone/features/music/domain/music.dart';
import 'package:walone/features/music/presentation/import_cubit.dart';
import 'package:walone/features/music/presentation/music_cubit.dart';
import 'package:walone/features/music/presentation/music_dialogs.dart';
import 'package:walone/features/music/presentation/music_page.dart';

import 'media_fakes.dart';

class PlaylistProcess extends FakeProcess {
  PlaylistProcess({this.artist = 'Автор', this.artists, this.metadataError});
  final String artist;
  final List<String>? artists;
  final Object? metadataError;
  List<Map<String, dynamic>> get spotifySongs => [
    {
      'song_id': 'spotify-song',
      if (artists != null) 'artists': artists,
      'name': 'Песня',
      'artist': 'Автор',
      'duration': 10,
      'list_name': 'Spotify список',
    },
  ];
  static Future<List<Map<String, dynamic>>> catalog(
    MusicLink link,
    dynamic worker,
    int limit,
    void Function(String) status,
  ) async => (worker as PlaylistProcess).spotifySongs;
  @override
  Future<String> run(
    String tool,
    List<String> arguments,
    Directory directory, {
    Duration timeout = const Duration(minutes: 60),
    bool capture = false,
  }) async {
    if (tool == 'spotdl') {
      calls.add(arguments);
      await File(arguments[arguments.indexOf('--save-file') + 1])
          .writeAsString(jsonEncode(spotifySongs));
      return '';
    }
    if (arguments.contains('--dump-single-json')) {
      calls.add(arguments);
      if (arguments.last.startsWith('ytsearch')) {
        return jsonEncode({
          'entries': [
            {'id': 'abcdefghij0', 'title': 'Автор — Песня', 'duration': 10},
          ],
        });
      }
      if (arguments.contains('--flat-playlist')) {
        return jsonEncode({
          'title': 'Список',
          'entries': [
            for (var i = 0; i < 3; i++) {'id': 'abcdefghij$i'},
          ],
        });
      }
      if (metadataError case final error?) throw error;
      final id = Uri.parse(arguments.last).queryParameters['v']!;
      final index = int.parse(id.substring(10));
      return jsonEncode({
        'id': id,
        'track': 'Песня',
        'artist': artist,
        if (artists != null) 'artists': artists,
        'duration': 10 + index,
      });
    }
    if (tool != 'ffmpeg') {
      calls.add(arguments);
      await File(p.join(directory.path, 'source.m4a')).writeAsString('10');
      return '';
    }
    return super.run(
      tool,
      arguments,
      directory,
      timeout: timeout,
      capture: capture,
    );
  }
}

class InterruptedSpotifyProcess extends PlaylistProcess {
  var metadataCalls = 0;
  @override
  Future<String> run(
    String tool,
    List<String> arguments,
    Directory directory, {
    Duration timeout = const Duration(minutes: 60),
    bool capture = false,
  }) async {
    if (arguments.contains('--dump-single-json') &&
        arguments.last.startsWith('https://www.youtube.com/watch') &&
        ++metadataCalls == 2) {
      throw YoutubeAccessRequired('Не удалось прочитать cookies браузера');
    }
    return super.run(
      tool,
      arguments,
      directory,
      timeout: timeout,
      capture: capture,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late MusicRepository repository;
  late MusicCubit music;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('walone-library-');
    repository = MusicRepository(
      Directory(p.join(root.path, 'Music')),
      audioFactory: FakeAudio.new,
    );
    music = MusicCubit(repository);
    await music.initialize();
  });
  tearDown(() async {
    await music.close();
    await root.delete(recursive: true);
  });
  Future<MusicTrack> add(String title, String artist, int duration) async {
    final file = await File(p.join(root.path, '$duration.wav'))
        .writeAsString('$duration');
    final track = await repository.prepareFile(
      file.path,
      title: title,
      artist: artist,
    );
    await music.accept([track], playlistID: allMusicID);
    return track;
  }

  test('Ссылки на YouTube-плейлисты, Spotify и всю музыку VK', () {
    for (final url in [
      'https://www.youtube.com/playlist?list=PLabcdefghijk',
      'https://youtube.com/watch?v=abcdefghijk&list=PLabcdefghijk',
    ]) {
      expect(MusicLink.detect(url).playlist, isTrue);
      expect(
        MusicLink.detect(url).url,
        'https://www.youtube.com/playlist?list=PLabcdefghijk',
      );
    }
    expect(
      MusicLink.detect(
        'https://open.spotify.com/intl-ru/playlist/1234567890123456789012?si=foo',
      ).provider,
      ImportProvider.spotify,
    );
    expect(MusicLink.detect('https://vk.com/music').id, 'all');
    expect(MusicLink.detect('https://vk.ru/audios123').owner, '123');
    expect(
      () => MusicLink.detect(
        'https://open.spotify.com.evil/playlist/1234567890123456789012',
      ),
      throwsFormatException,
    );
    expect(
      () => MusicLink.detect('https://youtube.com/playlist?list=bad'),
      throwsFormatException,
    );
  });

  for (final chapters in [true, false]) {
    test(
      'Одиночное видео определяет исполнителей из ${chapters ? 'глав' : 'названия'}',
      () async {
        final worker = FakeProcess(
          youtubeMetadata: {
            'id': 'abcdefghijk',
            'title': chapters ? 'Сборник' : 'Дурной Вкус - Пластинки',
            'duration': 10,
            if (chapters)
              'chapters': [
                {'start_time': 0, 'title': 'Дурной Вкус - Пластинки'},
                {
                  'start_time': 4,
                  'title': 'Chernikovskaya Hata – Не Верь Слезам',
                },
              ],
          },
        );
        final importer = ImportCubit(
          music,
          FakeVkSession(root),
          toolFinder: (name) async => name,
          workerFactory: () => worker,
        );
        addTearDown(importer.close);
        await importer.remote(
          ImportProvider.youtube,
          'https://youtu.be/abcdefghijk',
        );
        expect(importer.state.error, isNull);
        expect(repository.library.tracks.first.title, 'Пластинки');
        expect(repository.library.tracks.first.artists, ['Дурной Вкус']);
        if (chapters) {
          expect(repository.library.tracks.last.title, 'Не Верь Слезам');
          expect(repository.library.tracks.last.artists, [
            'Chernikovskaya Hata',
          ]);
        }
      },
    );
  }

  test('Повторный импорт исправляет пустых исполнителей без скачивания и сохраняет ручные правки', () async {
    final legacy = await repository.prepareFile(
      (await File('${root.path}/legacy.wav').writeAsString('4')).path,
      title: 'Дурной Вкус - Пластинки',
      sourceID: 'youtube:abcdefghijk:0.0:4.0',
    );
    final edited = await repository.prepareFile(
      (await File('${root.path}/edited.wav').writeAsString('6')).path,
      title: 'Моё название',
      artists: ['Мой исполнитель'],
      sourceID: 'youtube:abcdefghijk:4.0:10.0',
    );
    await music.accept([legacy, edited], playlistID: allMusicID);
    final worker = FakeProcess(
      youtubeMetadata: {
        'id': 'abcdefghijk',
        'title': 'Сборник',
        'duration': 10,
        'chapters': [
          {'start_time': 0, 'title': 'Дурной Вкус - Пластинки'},
          {'start_time': 4, 'title': 'Chernikovskaya Hata - Не Верь Слезам'},
        ],
      },
    )..failDownload = true;
    final importer = ImportCubit(
      music,
      FakeVkSession(root),
      toolFinder: (name) async => name,
      workerFactory: () => worker,
    );
    addTearDown(importer.close);
    await importer.remote(
      ImportProvider.youtube,
      'https://youtu.be/abcdefghijk',
    );
    expect(importer.state.error, isNull);
    expect(repository.library.tracks, hasLength(2));
    final repaired = repository.library.tracks.firstWhere(
      (t) => t.id == legacy.id,
    );
    expect(repaired.title, 'Пластинки');
    expect(repaired.artists, ['Дурной Вкус']);
    expect(repaired.filename, legacy.filename);
    final preserved = repository.library.tracks.firstWhere(
      (t) => t.id == edited.id,
    );
    expect(preserved.title, 'Моё название');
    expect(preserved.artists, ['Мой исполнитель']);
    expect(worker.calls.where((a) => a.contains('--load-info-json')), isEmpty);
    expect(worker.renders, 0);
    await music.close();
    music = MusicCubit(
      MusicRepository(repository.directory, audioFactory: FakeAudio.new),
    );
    await music.initialize();
    expect(
      music.repository.library.tracks
          .firstWhere((t) => t.id == legacy.id)
          .artists,
      ['Дурной Вкус'],
    );
  });

  test(
    'Поиск Spotify отклоняет другую версию и несовпадающую длительность',
    () {
      final song = {'name': 'Песня', 'artist': 'Автор', 'duration': 180};
      expect(
        spotifyMatch(song, {
          'title': 'АВТОР — Песня (Official Audio)',
          'duration': 183,
        }),
        isTrue,
      );
      expect(
        spotifyMatch(song, {'title': 'Автор — Песня remix', 'duration': 180}),
        isFalse,
      );
      expect(
        spotifyMatch(song, {'title': 'Другой — Песня', 'duration': 180}),
        isFalse,
      );
      expect(
        spotifyMatch(song, {'title': 'Автор — Песня', 'duration': 250}),
        isFalse,
      );
      expect(trackDetails({'title': 'Автор — Песня'}).title, 'Песня');
      expect(trackDetails({'title': 'Автор — Песня'}).artists, ['Автор']);
      expect(
        trackDetails({'title': 'Видео', 'track': 'Песня', 'artist': 'Автор'})
            .title,
        'Песня',
      );
    },
  );

  test(
    'Старая медиатека, исполнители и архив проходят сохранение и загрузку',
    () async {
      final track = await add('Песня', 'Автор', 10);
      final legacy = repository.library.toJson()
        ..remove('artists')
        ..remove('importLimit');
      for (final row in legacy['tracks'] as List) {
        (row as Map)
          ..remove('artist')
          ..remove('artists');
      }
      expect(MusicLibrary.fromJson(legacy).tracks.single.artist, '');
      expect(MusicLibrary.fromJson(legacy).importLimit, 500);
      final zip = p.join(root.path, 'library.zip');
      await repository.exportArchive(zip);
      final target = MusicRepository(
        Directory(p.join(root.path, 'Other')),
        audioFactory: FakeAudio.new,
      );
      addTearDown(target.close);
      await target.importArchive(zip);
      expect(target.library.track(track.id)!.artist, 'Автор');
      expect(target.library.artists, ['Автор']);
      final reopened = MusicRepository(target.directory);
      addTearDown(reopened.close);
      await reopened.initialize();
      expect(
        reopened.library.tracksIn(artistMusicID('Автор')).single.id,
        track.id,
      );
    },
  );

  test(
    'Групповые действия, динамический исполнитель и явное удаление файлов',
    () async {
      final first = await add('Первая', 'Автор', 10);
      final second = await add('Вторая', 'автор', 11);
      await music.savePlaylist('Избранное');
      final playlist = repository.library.selectedID!;
      await music.addToPlaylist({first.id, second.id}, playlist);
      await music.addToPlaylist({first.id}, playlist);
      expect(repository.library.tracksIn(playlist), hasLength(2));
      await music.select(artistMusicID('Автор'));
      await music.play(trackID: first.id, playlistID: artistMusicID('Автор'));
      await music.editTracks({first.id, second.id}, artist: 'Общий');
      expect(music.state.error, isNull);
      expect(repository.library.playingID, allMusicID);
      expect(repository.library.tracksIn(artistMusicID('Общий')), hasLength(2));
      await music.editTracks({first.id}, title: 'Новое название');
      await music.artistPlaylist('Общий');
      expect(repository.library.playlists.last.trackIDs, [first.id, second.id]);
      await music.removeTracks({first.id, second.id}, playlistID: playlist);
      await music.deletePlaylist(repository.library.playlists.last.id);
      expect(repository.library.tracksIn(allMusicID), hasLength(2));
      expect(await File(repository.pathFor(first)).exists(), isTrue);
      await music.removeTracks({first.id});
      expect(await File(repository.pathFor(first)).exists(), isFalse);
      expect(repository.library.tracks.single.id, second.id);
      expect(music.state.playing, isFalse);
      expect(
        MusicLibrary.fromJson(repository.library.toJson()).trackID,
        isNull,
      );
    },
  );

  test(
    'YouTube-плейлист соблюдает лимит; выбор регистра кэшируется в импорте',
    () async {
      await add('Сохранённая', 'Автор', 20);
      final worker = PlaylistProcess(artist: 'автор');
      final importer = ImportCubit(
        music,
        FakeVkSession(root),
        toolFinder: (name) async => name,
        workerFactory: () => worker,
      );
      var choices = 0;
      await importer.remote(
        ImportProvider.youtube,
        'https://youtube.com/playlist?list=PLabcdefghijk',
        limit: 2,
        chooseArtist: (name, matches) async {
          choices++;
          expect(matches, ['Автор']);
          return matches.single;
        },
      );
      expect(importer.state.error, isNull);
      expect(choices, 1);
      expect(repository.library.playlists.single.trackIDs, hasLength(2));
      expect(repository.library.tracks.map((t) => t.artist).toSet(), {'Автор'});
      final args = worker.calls.firstWhere(
        (args) => args.contains('--flat-playlist'),
      );
      expect(args[args.indexOf('--playlist-end') + 1], '2');
      expect(repository.library.importLimit, 2);
      await importer.close();
    },
  );

  test('Отказ от объединения создаёт отдельного исполнителя; отмена не добавляет трек', () async {
    await add('Сохранённая', 'Автор', 20);
    final importer = ImportCubit(
      music,
      FakeVkSession(root),
      toolFinder: (name) async => name,
      workerFactory: () => PlaylistProcess(artist: 'автор'),
    );
    await importer.remote(
      ImportProvider.youtube,
      'https://youtube.com/playlist?list=PLabcdefghijk',
      limit: 1,
      chooseArtist: (name, matches) async => name,
    );
    expect(repository.library.artists.toSet(), {'Автор', 'автор'});
    final cancel = ImportCubit(
      music,
      FakeVkSession(root),
      toolFinder: (name) async => name,
      workerFactory: () => PlaylistProcess(artist: 'АВТОР'),
    );
    await cancel.remote(
      ImportProvider.youtube,
      'https://youtube.com/playlist?list=PLabcdefghijk',
      limit: 0,
      chooseArtist: (name, matches) async => null,
    );
    expect(cancel.state.error, contains('Импорт отменён'));
    expect(repository.library.tracks, hasLength(2));
    expect(cancel.state.busy, isFalse);
    await cancel.close();
    await importer.close();
  });

  test(
    'Spotify сохраняет причину ошибки YouTube и существующую медиатеку',
    () async {
      final saved = await add('Сохранённая', 'Автор', 20);
      final worker = PlaylistProcess(
        metadataError: StateError('YouTube запросил проверку «не бот»'),
      );
      final importer = ImportCubit(
        music,
        FakeVkSession(root),
        toolFinder: (name) async => name,
        workerFactory: () => worker,
      );
      addTearDown(importer.close);
      await importer.remote(
        ImportProvider.spotify,
        'https://open.spotify.com/track/1234567890123456789012',
      );
      expect(
        importer.state.error,
        contains('YouTube запросил проверку «не бот»'),
      );
      expect(importer.state.busy, isFalse);
      expect(music.state.importing, isFalse);
      expect(repository.library.tracks.single.id, saved.id);
    },
  );

  for (final provider in [
    ImportProvider.youtube,
    ImportProvider.spotify,
    ImportProvider.soundcloud,
  ]) {
    test(
      'Cookies браузера используются только для YouTube: ${provider.name}',
      () async {
        final worker = provider == ImportProvider.spotify
            ? PlaylistProcess()
            : FakeProcess();
        final importer = ImportCubit(
          music,
          FakeVkSession(root),
          toolFinder: (name) async => name,
          workerFactory: () => worker,
        );
        addTearDown(importer.close);
        await importer.remote(provider, switch (provider) {
          ImportProvider.spotify =>
            'https://open.spotify.com/track/1234567890123456789012',
          ImportProvider.soundcloud => 'https://soundcloud.com/artist/track',
          _ => 'https://youtube.com/watch?v=abcdefghijk',
        }, youtubeBrowser: 'firefox');
        final calls = worker.calls.where(
          (args) =>
              args.contains('--dump-single-json') ||
              args.contains('--load-info-json'),
        );
        expect(calls, isNotEmpty);
        for (final args in calls) {
          if (provider == ImportProvider.soundcloud) {
            expect(args, isNot(contains('--cookies-from-browser')));
          } else {
            expect(args[args.indexOf('--cookies-from-browser') + 1], 'firefox');
            expect(args, contains('--verbose'));
            expect(args, isNot(contains('--no-warnings')));
          }
        }
        expect(importer.state.error, isNull);
      },
    );
  }

  test(
    'Произвольные параметры вместо браузера отклоняются до запуска',
    () async {
      final worker = PlaylistProcess();
      final importer = ImportCubit(
        music,
        FakeVkSession(root),
        toolFinder: (name) async => name,
        workerFactory: () => worker,
      );
      addTearDown(importer.close);
      await importer.remote(
        ImportProvider.youtube,
        'https://youtube.com/watch?v=abcdefghij0',
        youtubeBrowser: 'chrome:private-profile',
      );
      expect(importer.state.error, 'Выберите браузер из списка');
      expect(worker.calls, isEmpty);
    },
  );

  test('Spotify сохраняет и показывает добавленный трек при последующей ошибке cookies', () async {
    final worker = InterruptedSpotifyProcess();
    final importer = ImportCubit(
      music,
      FakeVkSession(root),
      toolFinder: (name) async => name,
      workerFactory: () => worker,
      spotifyPlaylistLoader: (link, worker, limit, status) async => [
        ...PlaylistProcess().spotifySongs,
        {...PlaylistProcess().spotifySongs.first, 'song_id': 'second-song'},
      ],
    );
    addTearDown(importer.close);
    await importer.remote(
      ImportProvider.spotify,
      'https://open.spotify.com/playlist/6li523Zf0m6rr9j2tixnjJ',
      youtubeBrowser: 'chrome',
    );
    expect(
      importer.state.error,
      contains('Не удалось прочитать cookies браузера'),
    );
    expect(importer.state.error, contains('Добавлено: 1'));
    expect(importer.state.error, contains('Уже добавленные треки сохранены'));
    expect(repository.library.tracks.single.sourceID, 'spotify:spotify-song');
    expect(
      music.state.library.tracks.single.id,
      repository.library.tracks.single.id,
    );
    final saved = (await repository.database.load())!;
    expect(saved.playlists.single.trackIDs, [saved.tracks.single.id]);
    expect(saved.selectedID, saved.playlists.single.id);
    expect(
      await File(repository.pathFor(saved.tracks.single)).exists(),
      isTrue,
    );
    expect(importer.state.busy, isFalse);
    expect(music.state.importing, isFalse);
  });

  test('Ошибка cookies прекращает Spotify после первой попытки', () async {
    final invocations = File(p.join(root.path, 'cookie-attempts'));
    final tool = File(p.join(root.path, 'cookie-tool'));
    await tool.writeAsString(
      "#!/bin/sh\necho attempt >> '${invocations.path}'\n"
      "echo 'ERROR: Could not find Chrome cookies database in private-profile' >&2\nexit 1\n",
    );
    await Process.run('/bin/chmod', ['700', tool.path]);
    final importer = ImportCubit(
      music,
      FakeVkSession(root),
      toolFinder: (_) async => tool.path,
      spotifyPlaylistLoader: (link, worker, limit, status) async =>
          List.generate(3, (_) => PlaylistProcess().spotifySongs.first),
    );
    addTearDown(importer.close);
    await importer.remote(
      ImportProvider.spotify,
      'https://open.spotify.com/playlist/6li523Zf0m6rr9j2tixnjJ',
      youtubeBrowser: 'chrome',
    );
    expect((await invocations.readAsLines()).length, 1);
    expect(
      importer.state.error,
      contains('Не удалось прочитать cookies браузера'),
    );
    expect(importer.state.error, isNot(contains('private-profile')));
    expect(importer.state.error, contains('Добавлено: 0'));
    expect(importer.state.error, contains('трек 1 из 3'));
    expect(repository.library.tracks, isEmpty);
    expect(importer.state.busy, isFalse);
  }, skip: Platform.isWindows);

  test('Блокировка YouTube останавливает Spotify без повторов для остальных треков', () async {
    final worker = PlaylistProcess(
      metadataError: YoutubeAccessRequired(
        'YouTube запросил проверку «не бот»',
      ),
    );
    final importer = ImportCubit(
      music,
      FakeVkSession(root),
      toolFinder: (name) async => name,
      workerFactory: () => worker,
      spotifyPlaylistLoader: (link, worker, limit, status) async {
        final songs = (worker as PlaylistProcess).spotifySongs;
        return [...songs, ...songs];
      },
    );
    addTearDown(importer.close);
    await importer.remote(
      ImportProvider.spotify,
      'https://open.spotify.com/playlist/6li523Zf0m6rr9j2tixnjJ',
    );
    expect(
      importer.state.error,
      contains('YouTube запросил проверку «не бот»'),
    );
    expect(
      worker.calls.where((args) => args.last.startsWith('ytsearch')).length,
      1,
    );
    expect(repository.library.tracks, isEmpty);
    expect(music.state.importing, isFalse);
  });

  test('Успешная ссылка Spotify не импортируется повторно', () async {
    final worker = PlaylistProcess();
    final importer = ImportCubit(
      music,
      FakeVkSession(root),
      spotifyPlaylistLoader: PlaylistProcess.catalog,
      toolFinder: (name) async => name,
      workerFactory: () => worker,
    );
    addTearDown(importer.close);
    const url = 'https://open.spotify.com/playlist/6li523Zf0m6rr9j2tixnjJ';
    await importer.remote(ImportProvider.spotify, '$url?si=first');
    expect(importer.state.error, isNull);
    final calls = worker.calls.length;
    final playlists = repository.library.playlists.length;
    importer.clearResult();
    await importer.remote(
      ImportProvider.spotify,
      'https://open.spotify.com/intl-ru/playlist/6li523Zf0m6rr9j2tixnjJ?si=second',
    );
    expect(worker.calls.length, calls);
    expect(repository.library.playlists.length, playlists);
  });

  testWidgets('Окно блокирует успешно импортированную ссылку Spotify', (
    tester,
  ) async {
    final importer = ImportCubit(
      music,
      FakeVkSession(root),
      spotifyPlaylistLoader: PlaylistProcess.catalog,
      toolFinder: (name) async => name,
      workerFactory: PlaylistProcess.new,
    );
    addTearDown(importer.close);
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const url = 'https://open.spotify.com/playlist/6li523Zf0m6rr9j2tixnjJ';
    await tester.pumpWidget(
      BlocProvider.value(
        value: importer,
        child: const MaterialApp(home: Scaffold(body: MusicImportDialog())),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, url);
    await tester.pumpAndSettle();
    FilledButton button() => tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Импортировать'),
    );
    expect(button().onPressed, isNotNull);
    await tester.runAsync(() => importer.remote(ImportProvider.spotify, url));
    await tester.pumpAndSettle();
    expect(button().onPressed, isNull);
    expect(find.text('Эта ссылка уже импортирована.'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '$url?si=changed');
    await tester.pumpAndSettle();
    expect(button().onPressed, isNull);
    await tester.enterText(
      find.byType(TextField).first,
      'https://open.spotify.com/playlist/1234567890123456789012',
    );
    await tester.pumpAndSettle();
    expect(button().onPressed, isNotNull);
  });

  test(
    'Ошибка и отмена Spotify оставляют возможность повторить импорт',
    () async {
      var worker = PlaylistProcess(
        metadataError: StateError('Сеть недоступна'),
      );
      final importer = ImportCubit(
        music,
        FakeVkSession(root),
        spotifyPlaylistLoader: PlaylistProcess.catalog,
        toolFinder: (name) async => name,
        workerFactory: () => worker,
      );
      addTearDown(importer.close);
      const url = 'https://open.spotify.com/playlist/6li523Zf0m6rr9j2tixnjJ';
      await importer.remote(ImportProvider.spotify, url);
      expect(importer.state.error, isNotNull);
      expect(importer.hasImported(ImportProvider.spotify, url), isFalse);
      worker = PlaylistProcess()..cancelAt = 1;
      await importer.remote(ImportProvider.spotify, url);
      expect(importer.state.error, contains('Импорт отменён'));
      expect(importer.hasImported(ImportProvider.spotify, url), isFalse);
      worker = PlaylistProcess();
      await importer.remote(ImportProvider.spotify, url);
      expect(importer.state.error, isNull);
      expect(importer.hasImported(ImportProvider.spotify, url), isTrue);
      expect(importer.state.busy, isFalse);
      expect(music.state.importing, isFalse);
    },
  );

  test(
    'Spotify получает метаданные и сохраняет найденный трек YouTube',
    () async {
      final worker = PlaylistProcess();
      final importer = ImportCubit(
        music,
        FakeVkSession(root),
        spotifyPlaylistLoader: PlaylistProcess.catalog,
        toolFinder: (name) async => name,
        workerFactory: () => worker,
      );
      await importer.remote(
        ImportProvider.spotify,
        'https://open.spotify.com/playlist/1234567890123456789012',
      );
      expect(importer.state.error, isNull);
      expect(repository.library.tracks.single.artist, 'Автор');
      expect(repository.library.tracks.single.title, 'Песня');
      expect(repository.library.tracks.single.sourceID, 'spotify:spotify-song');
      expect(
        worker.calls.any((args) => args.contains('ytsearch5:Автор Песня')),
        isTrue,
      );
      await importer.close();
    },
  );

  test(
    'Архив предлагает сопоставить регистр исполнителя до изменения файлов',
    () async {
      await add('Сохранённая', 'Автор', 20);
      final donor = MusicRepository(
        Directory(p.join(root.path, 'Donor')),
        audioFactory: FakeAudio.new,
      );
      addTearDown(donor.close);
      final file = await File(p.join(root.path, 'donor.wav'))
          .writeAsString('10');
      final track = await donor.prepareFile(
        file.path,
        title: 'Импорт',
        artist: 'автор',
      );
      await donor.commit(MusicLibrary(tracks: [track]));
      final zip = p.join(root.path, 'donor.zip');
      await donor.exportArchive(zip);
      final importer = ImportCubit(music, FakeVkSession(root));
      await importer.importArchive(
        zip,
        chooseArtist: (name, matches) async => null,
      );
      expect(repository.library.tracks, hasLength(1));
      expect(await File(repository.pathFor(track)).exists(), isFalse);
      var choices = 0;
      await importer.importArchive(
        zip,
        chooseArtist: (name, matches) async {
          choices++;
          return matches.single;
        },
      );
      expect(importer.state.error, isNull);
      expect(choices, 1);
      expect(repository.library.tracks.map((t) => t.artist).toSet(), {'Автор'});
      await importer.close();
    },
  );

  test(
    'Несколько исполнителей сохраняются и каждый получает свои треки',
    () async {
      final first = await add('Совместная', 'Автор', 10);
      final second = await add('Сольная', 'Гость', 11);
      await music.editTracks(
        {first.id},
        artists: [' Автор ', 'Гость', 'Автор', ''],
      );
      expect(repository.library.track(first.id)!.artists, ['Автор', 'Гость']);
      expect(
        repository.library.tracksIn(artistMusicID('Автор')).map((t) => t.id),
        [first.id],
      );
      expect(
        repository.library.tracksIn(artistMusicID('Гость')).map((t) => t.id),
        [first.id, second.id],
      );
      await music.artistPlaylist('Гость');
      expect(repository.library.playlists.single.trackIDs, [
        first.id,
        second.id,
      ]);
      final zip = p.join(root.path, 'collaboration.zip');
      await repository.exportArchive(zip);
      final target = MusicRepository(
        Directory(p.join(root.path, 'Collaboration')),
        audioFactory: FakeAudio.new,
      );
      addTearDown(target.close);
      await target.importArchive(zip);
      expect(target.library.track(first.id)!.artists, ['Автор', 'Гость']);
      expect(target.library.artists.toSet(), {'Автор', 'Гость'});
      final legacy = first.toJson()
        ..remove('artists')
        ..['artist'] = 'Tyler, The Creator';
      expect(MusicTrack.fromJson(legacy).artists, ['Tyler, The Creator']);
      expect(
        () => repository.library.track(first.id)!.artists.add('Третий'),
        throwsUnsupportedError,
      );
      await music.play(trackID: first.id, playlistID: artistMusicID('Гость'));
      await music.editTracks({first.id}, artists: ['Автор']);
      expect(music.state.error, isNull);
      expect(
        MusicLibrary.fromJson(repository.library.toJson()).playingID,
        allMusicID,
      );
    },
  );

  test('Метаданные сохраняют списки и отличают feat. от запятых в имени', () {
    expect(
      metadataArtistNames({
        'artists': ['Tyler, The Creator', 'AC/DC', 'AC/DC'],
      }),
      ['Tyler, The Creator', 'AC/DC'],
    );
    expect(metadataArtistNames({'artist': 'Автор feat. Гость; Третий'}), [
      'Автор',
      'Гость',
      'Третий',
    ]);
    expect(metadataArtistNames({'artist': 'Earth, Wind & Fire'}), [
      'Earth, Wind & Fire',
    ]);
    expect(trackDetails({'title': 'Автор ft. Гость — Песня'}).artists, [
      'Автор',
      'Гость',
    ]);
  });

  test(
    'Импорт привязывает каждого участника и запрашивает совпадение регистра',
    () async {
      await add('Сохранённая', 'Автор', 20);
      final worker = PlaylistProcess(artists: ['автор', 'Гость']);
      final importer = ImportCubit(
        music,
        FakeVkSession(root),
        toolFinder: (name) async => name,
        workerFactory: () => worker,
      );
      var choices = 0;
      await importer.remote(
        ImportProvider.youtube,
        'https://youtube.com/playlist?list=PLabcdefghijk',
        limit: 1,
        chooseArtist: (name, matches) async {
          choices++;
          return matches.single;
        },
      );
      expect(importer.state.error, isNull);
      expect(choices, 1);
      expect(repository.library.tracks.last.artists, ['Автор', 'Гость']);
      expect(repository.library.artists.toSet(), {'Автор', 'Гость'});
      await importer.close();
    },
  );

  test(
    'Spotify сохраняет всех исполнителей из структурированного списка',
    () async {
      final worker = PlaylistProcess(artists: ['Автор', 'Гость']);
      final importer = ImportCubit(
        music,
        FakeVkSession(root),
        spotifyPlaylistLoader: PlaylistProcess.catalog,
        toolFinder: (name) async => name,
        workerFactory: () => worker,
      );
      await importer.remote(
        ImportProvider.spotify,
        'https://open.spotify.com/playlist/1234567890123456789012',
      );
      expect(importer.state.error, isNull);
      expect(repository.library.tracks.single.artists, ['Автор', 'Гость']);
      await importer.close();
    },
  );

  test(
    'Разный регистр новых соисполнителей сопоставляется до сохранения трека',
    () async {
      final worker = PlaylistProcess(artists: ['Новый', 'новый']);
      final importer = ImportCubit(
        music,
        FakeVkSession(root),
        toolFinder: (name) async => name,
        workerFactory: () => worker,
      );
      var choices = 0;
      await importer.remote(
        ImportProvider.youtube,
        'https://youtube.com/playlist?list=PLabcdefghijk',
        limit: 1,
        chooseArtist: (name, matches) async {
          choices++;
          expect(matches, ['Новый']);
          return matches.single;
        },
      );
      expect(importer.state.error, isNull);
      expect(choices, 1);
      expect(repository.library.tracks.single.artists, ['Новый']);
      await importer.close();
    },
  );

  testWidgets('Редактор выбирает сохранённого исполнителя и меняет название', (
    tester,
  ) async {
    final track = (await tester.runAsync(() => add('Песня', 'Автор', 10)))!;
    ({String title, List<String> artists})? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result =
                    await showDialog<({String title, List<String> artists})>(
                      context: context,
                      builder: (_) =>
                          TrackEditDialog(artists: ['Другой'], track: track),
                    );
              },
              child: const Text('Открыть'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Открыть'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Новое название');
    await tester.tap(find.text('Сохранённые исполнители'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Другой'));
    await tester.pumpAndSettle();
    expect(find.byType(InputChip), findsNWidgets(2));
    await tester.tap(find.byTooltip('Убрать исполнителя Автор'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Новый');
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(result!.title, 'Новое название');
    expect(result!.artists, ['Другой', 'Новый']);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Имя исполнителя открывает все его треки', (tester) async {
    final track = (await tester.runAsync(() => add('Песня', 'Автор', 10)))!;
    await tester.runAsync(
      () => music.editTracks({track.id}, artists: ['Автор', 'Гость']),
    );
    final playlist = repository.library.playlist(allMusicID)!;
    await tester.pumpWidget(
      BlocProvider.value(
        value: music,
        child: MaterialApp(
          home: Scaffold(
            body: MusicTrackTile(
              track: repository.library.track(track.id)!,
              playlist: playlist,
              index: 0,
              state: music.state,
              reorderable: false,
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      final changed = music.stream.firstWhere(
        (s) => s.library.selectedID == artistMusicID('Гость'),
      );
      await tester.tap(find.text('Гость'));
      await changed;
    });
    await tester.pumpAndSettle();
    expect(repository.library.selectedID, artistMusicID('Гость'));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'Общая коллекция: поиск, выделение и общий исполнитель в узком окне',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(900, 1000);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.runAsync(() async {
        await add('Первая песня', 'Автор', 10);
        await add('Вторая песня', 'Другой', 11);
      });
      if (const bool.fromEnvironment('CAPTURE_MUSIC_LIBRARY')) {
        await tester.runAsync(() async {
          for (final entry in {
            'Preview': '.fvm/flutter_sdk/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf',
            'MaterialIcons': '.fvm/flutter_sdk/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
          }.entries) {
            await (FontLoader(entry.key)..addFont(
                  File(entry.value)
                      .readAsBytes()
                      .then((bytes) => bytes.buffer.asByteData()),
                ))
                .load();
          }
        });
      }
      final importer = ImportCubit(music, FakeVkSession(root));
      final previewKey = GlobalKey();
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider.value(value: music),
            BlocProvider.value(value: importer),
          ],
          child: MaterialApp(
            theme: ThemeData(
              fontFamily: const bool.fromEnvironment('CAPTURE_MUSIC_LIBRARY')
                  ? 'Preview'
                  : null,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF64B5FF),
                brightness: Brightness.dark,
              ),
            ),
            home: RepaintBoundary(key: previewKey, child: const MusicPage()),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Первая песня'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Вторая');

      await tester.pumpAndSettle();
      expect(find.text('Первая песня'), findsNothing);
      expect(find.text('Вторая песня'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '');

      await tester.pumpAndSettle();
      await tester.tap(find.text('Выделить треки'));

      await tester.pumpAndSettle();
      await tester.tap(find.text('Выделить все'));

      await tester.pumpAndSettle();
      expect(find.text('Выбрано: 2'), findsOneWidget);
      await tester.runAsync(
        () => tester.tap(find.text('Действия с выбранными')),
      );

      await tester.pumpAndSettle();
      await tester.runAsync(
        () => tester.tap(find.text('Назначить исполнителей')),
      );

      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Общий');

      await tester.tap(find.text('Сохранить'));
      for (var i = 0; i < 20; i++) {
        await tester.pumpAndSettle();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        if (repository.library.tracks.every((t) => t.artist == 'Общий')) break;
      }
      await tester.pumpAndSettle();
      expect(find.text('Общий'), findsNWidgets(2));
      await tester.tap(find.text('Закончить выделение'));

      await tester.pumpAndSettle();
      for (final width in [420.0, 900.0]) {
        tester.view.physicalSize = Size(width, 1000);

        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      if (const bool.fromEnvironment('CAPTURE_MUSIC_LIBRARY')) {
        await tester.runAsync(() async {
          final image =
              await (previewKey.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage();
          final data = await image.toByteData(format: ImageByteFormat.png);
          await File('/tmp/walone-music-library.png')
              .writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(importer.close);
    },
  );
}
