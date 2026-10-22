import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show ImageByteFormat;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';
import 'package:path/path.dart' as p;
import 'package:walone/core/storage.dart';
import 'package:walone/core/widgets.dart';
import 'package:walone/features/atmosphere/data/atmosphere_audio.dart';
import 'package:walone/features/atmosphere/presentation/atmosphere_cubit.dart';
import 'package:walone/features/atmosphere/presentation/atmosphere_page.dart';
import 'package:walone/features/keyboard/presentation/keyboard_cubit.dart';
import 'package:walone/features/keyboard/presentation/keyboard_page.dart';
import 'package:walone/features/music/data/music_process.dart';
import 'package:walone/features/music/data/import_tools.dart';
import 'package:walone/features/music/data/music_repository.dart';
import 'package:walone/features/music/data/vk_session.dart';
import 'package:walone/features/music/domain/import.dart';
import 'package:walone/features/music/domain/music.dart';
import 'package:walone/features/music/presentation/import_cubit.dart';
import 'package:walone/features/music/presentation/music_cubit.dart';
import 'package:walone/features/music/presentation/music_page.dart';
import 'package:walone/features/music/presentation/music_dialogs.dart';
import 'package:walone/workspace.dart';
import 'package:walone/features/timer/presentation/timer_cubit.dart';
import 'package:walone/features/settings/presentation/settings_cubit.dart';
import 'package:walone/features/settings/presentation/settings_page.dart';

import 'media_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late MusicRepository repository;
  late MusicCubit music;
  late FakeAudio output;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('walone-test-');
    repository = MusicRepository(
      Directory(p.join(root.path, 'Music')),
      audioFactory: FakeAudio.new,
    );
    music = MusicCubit(repository);
    await music.initialize();
    output = FakeAudio();
  });
  tearDown(() async {
    await music.close();
    await output.dispose();
    await root.delete(recursive: true);
  });

  Future<MusicTrack> add(
    String name,
    String contents, {
    String? playlistID,
  }) async {
    final source = await File(p.join(root.path, '$name.wav'))
        .writeAsString(contents);
    final track = await repository.prepareFile(source.path);
    await music.accept([track], playlistID: playlistID, newPlaylistName: name);
    return track;
  }

  test(
    'Копии и SHA-256: удаление плейлиста сохраняет трек в медиатеке',
    () async {
      final track = await add('first', '10');
      final first = repository.library.selectedID!;
      final same = await repository.prepareFile(
        (await File(p.join(root.path, 'same.mp3')).writeAsString('10')).path,
      );
      expect(same.id, track.id);
      await music.accept([same], newPlaylistName: 'Второй');
      final second = repository.library.selectedID!;
      expect(repository.library.tracks, hasLength(1));
      await music.removeTrack(track.id, first);
      expect(await File(repository.pathFor(track)).exists(), isTrue);
      await music.deletePlaylist(second);
      expect(await File(repository.pathFor(track)).exists(), isTrue);
      await music.removeTracks({track.id});
      expect(await File(repository.pathFor(track)).exists(), isFalse);
      expect(await File(p.join(root.path, 'first.wav')).readAsString(), '10');
    },
  );

  test(
    'Повреждённый манифест и небезопасный путь не перезаписываются',
    () async {
      final corrupted = Directory(p.join(root.path, 'corrupted'));
      await corrupted.create();
      final manifest = await File(p.join(corrupted.path, 'library.json'))
          .writeAsString('{broken');
      final protected = MusicRepository(corrupted, audioFactory: FakeAudio.new);
      addTearDown(protected.close);
      await expectLater(protected.initialize(), throwsStateError);
      await expectLater(protected.commit(MusicLibrary()), throwsStateError);
      expect(await manifest.readAsString(), '{broken');
      expect(
        () => MusicTrack.fromJson({
          'id': 'a' * 64,
          'title': 'Bad',
          'filename': '../outside.wav',
          'duration': 1,
        }),
        throwsFormatException,
      );
    },
  );

  test(
    'Открытие другого списка не меняет очередь; пауза сохраняет позицию',
    () async {
      final track = await add('first', '10');
      final first = repository.library.selectedID!;
      await music.play(trackID: track.id, playlistID: first);
      await music.seek(4);
      await music.savePlaylist('Другой');
      expect(repository.library.playingID, first);
      expect(repository.library.selectedID, isNot(first));
      expect(music.state.playing, isTrue);
      await music.environment(0.2, false);
      expect(music.state.playing, isFalse);
      await music.environment(0.2, true);
      expect(music.state.playing, isTrue);
      await music.environment(0.2, false, clearIntent: true);
      await music.environment(0.2, true);
      expect(music.state.playing, isFalse);
      final restored = MusicRepository(
        repository.directory,
        audioFactory: FakeAudio.new,
      );
      addTearDown(restored.close);
      await restored.initialize();
      expect(restored.library.position, 4);
    },
  );

  test(
    'Shuffle обходит очередь; ручной Next работает при повторе трека',
    () async {
      final first = await add('first', '10');
      final playlist = repository.library.selectedID!;
      await add('second', '11', playlistID: playlist);
      await add('third', '12', playlistID: playlist);
      await music.configure(shuffle: true, repeatMode: MusicRepeat.track);
      await music.play(trackID: first.id, playlistID: playlist);
      final seen = {repository.library.trackID};
      await music.next();
      seen.add(repository.library.trackID);
      await music.next();
      seen.add(repository.library.trackID);
      expect(seen, hasLength(3));
      expect(repository.library.tracksIn(playlist).length, 3);
      await music.reorder(playlist, 0, 3);
      expect(repository.library.playlist(playlist)!.trackIDs.last, first.id);
    },
  );

  test('Нарезка атомарна; ошибка и отмена оставляют исходник', () async {
    final original = await add('original', '10');
    final playlist = repository.library.selectedID!;
    final worker = FakeProcess()..failAt = 2;
    final importer = ImportCubit(
      music,
      FakeVkSession(root),
      toolFinder: (name) async => name,
      workerFactory: () => worker,
    );
    await importer.split(original, playlist, '0:00 Первый\n4:00 За границей');
    expect(repository.library.playlist(playlist)!.trackIDs, [original.id]);
    await importer.split(original, playlist, '0:00 Первый\n0:04 Второй');
    expect(importer.state.error, contains('Ошибка нарезки'));
    expect(repository.library.playlist(playlist)!.trackIDs, [original.id]);
    expect(
      (await repository.directory
          .list()
          .where((f) => f.path.endsWith('.m4a'))
          .toList()),
      isEmpty,
    );
    worker.failAt = null;
    worker.cancelAt = worker.renders + 1;
    await importer.split(original, playlist, '0:00 Первый\n0:04 Второй');
    expect(repository.library.playlist(playlist)!.trackIDs, [original.id]);
    expect(await File(repository.pathFor(original)).exists(), isTrue);
    await importer.close();
  });

  test('Успешная нарезка заменяет трек только в выбранном списке', () async {
    final original = await add('original', '10');
    final first = repository.library.selectedID!;
    await music.accept([original], newPlaylistName: 'Копия списка');
    final second = repository.library.selectedID!;
    final importer = ImportCubit(
      music,
      FakeVkSession(root),
      toolFinder: (name) async => name,
      workerFactory: FakeProcess.new,
    );
    await importer.split(original, first, '0:00 Первый\n0:04 Второй');
    expect(importer.state.error, isNull);
    expect(repository.library.playlist(first)!.trackIDs, hasLength(2));
    expect(repository.library.playlist(second)!.trackIDs, [original.id]);
    expect(await File(repository.pathFor(original)).exists(), isTrue);
    await importer.close();
  });

  test(
    'YouTube, SoundCloud и VK сохраняют локальные треки и ID источника',
    () async {
      final vk = FakeVkSession(root);
      final importer = ImportCubit(
        music,
        vk,
        toolFinder: (name) async => name,
        workerFactory: FakeProcess.new,
      );
      await importer.remote(
        ImportProvider.youtube,
        'https://youtu.be/abcdefghijk',
      );
      expect(importer.state.error, isNull);
      expect(repository.library.tracks, hasLength(2));
      expect(repository.library.playlists.single.trackIDs, hasLength(2));
      await importer.remote(
        ImportProvider.soundcloud,
        'https://soundcloud.com/artist/track',
      );
      expect(importer.state.error, isNull);
      await importer.remote(ImportProvider.vk, 'https://vk.ru/audio1_2');
      expect(importer.state.error, isNull);
      expect(vk.releases, 1);
      final cancelledWorker = FakeProcess()..cancel();
      final cancelledImport = ImportCubit(
        music,
        vk,
        toolFinder: (name) async => name,
        workerFactory: () => cancelledWorker,
      );
      await cancelledImport.remote(ImportProvider.vk, 'https://vk.ru/audio1_2');
      expect(cancelledImport.state.error, contains('Импорт отменён'));
      expect(vk.releases, 2);
      await cancelledImport.close();
      expect(
        repository.library.tracks.any(
          (t) => t.sourceID == 'youtube:abcdefghijk:0.0:4.0',
        ),
        isTrue,
      );
      expect(
        repository.library.tracks.any((t) => t.sourceID == 'soundcloud:123'),
        isTrue,
      );
      await importer.remote(ImportProvider.vk, 'https://example.com/invalid');
      expect(importer.state.error, isNotNull);
      expect(vk.releases, 3);
      await importer.close();
    },
  );

  test(
    'SoundCloud сообщает ошибку загрузки вместо успешного нуля треков',
    () async {
      await add('Исходный', '10');
      final before = repository.library.toJson();
      final importer = ImportCubit(
        music,
        FakeVkSession(root),
        toolFinder: (name) async => name,
        workerFactory: () => FakeProcess()..failDownload = true,
      );
      try {
        await importer.remote(
          ImportProvider.soundcloud,
          'https://soundcloud.com/artist/track',
        );
        expect(importer.state.error, contains('Сервис не ответил'));
        expect(repository.library.toJson(), before);
      } finally {
        await importer.close();
      }
    },
  );

  test(
    'Источник ссылки определяется только для поддерживаемых HTTPS-адресов',
    () {
      for (final (url, provider) in [
        (' https://youtu.be/abcdefghijk ', ImportProvider.youtube),
        (
          'https://music.youtube.com/watch?v=abcdefghijk',
          ImportProvider.youtube,
        ),
        ('https://youtube.com/shorts/abcdefghijk', ImportProvider.youtube),
        ('https://soundcloud.com/artist/track', ImportProvider.soundcloud),
        ('https://soundcloud.com/artist/sets/album', ImportProvider.soundcloud),
        ('https://vk.ru/audio1_2', ImportProvider.vk),
        ('https://m.vk.com/music/playlist/-1_2_abc', ImportProvider.vk),
      ]) {
        expect(MusicLink.detect(url).provider, provider);
      }
      for (final url in [
        'https://example.com/song',
        'https://youtube.com.evil.test/watch?v=abcdefghijk',
        'http://youtu.be/abcdefghijk',
        'https://user@youtu.be/abcdefghijk',
        'https://youtu.be:444/abcdefghijk',
        'https://youtube.com/watch?v=bad',
        'https://soundcloud.com/artist',
        'https://vk.ru/feed',
      ]) {
        expect(() => MusicLink.detect(url), throwsFormatException, reason: url);
      }
    },
  );

  test('Проверка запуска отклоняет устаревший JavaScript runtime', () async {
    if (Platform.isWindows) return;
    final script = File(p.join(root.path, 'runtime'));
    for (final (tool, version, supported) in [
      ('node', 'v20.0.0', false),
      ('node', 'v22.0.0', true),
      ('deno', 'deno 2.2.0', false),
      ('deno', 'deno 2.3.0', true),
      ('deno', 'unexpected', false),
    ]) {
      await script.writeAsString('#!/bin/sh\necho "$version"\n');
      await Process.run('/bin/chmod', ['700', script.path]);
      if (supported) {
        await MusicProcess.verify(script.path, tool);
      } else {
        await expectLater(
          MusicProcess.verify(script.path, tool),
          throwsStateError,
        );
      }
    }
  });

  test('Компоненты: альтернативный runtime, загрузка только недостающего и повторная проверка', () async {
    final available = {'ffmpeg', 'yt-dlp'};
    final installed = <String>[];
    final importer = ImportCubit(
      music,
      FakeVkSession(root),
      toolFinder: (name) async {
        if (!available.contains(name)) throw StateError('Нет $name');
        return name;
      },
      toolInstaller: (name, worker, temporary, status) async {
        installed.add(name);
        available.add(name == 'javascript' ? 'deno' : name);
      },
    );
    expect((await importer.checkTools())['javascript'], isFalse);
    await importer.installTools(ImportProvider.youtube);
    expect(installed, ['javascript']);
    expect(importer.state.error, isNull);
    expect((await importer.checkTools())['javascript'], isTrue);
    available.remove('deno');
    available.add('node');
    await importer.installTools(ImportProvider.youtube);
    expect(installed, ['javascript']);
    available.clear();
    await importer.installTools(ImportProvider.vk);
    expect(installed, ['javascript', 'ffmpeg']);
    expect(requiredImportTools(ImportProvider.soundcloud), [
      'ffmpeg',
      'yt-dlp',
    ]);
    await importer.close();
  });

  test(
    'Сбой yt-dlp не мешает установить spotDL, повтор качает только недостающее',
    () async {
      final available = {'ffmpeg', 'deno'};
      final attempts = <String>[];
      var fail = true;
      final importer = ImportCubit(
        music,
        FakeVkSession(root),
        toolFinder: (name) async {
          if (!available.contains(name)) throw StateError('Отсутствует');
          return name;
        },
        toolInstaller: (name, worker, temporary, status) async {
          attempts.add(name);
          if (name == 'yt-dlp' && fail) throw StateError('Сеть недоступна');
          available.add(name);
        },
      );
      try {
        await importer.installTools(ImportProvider.spotify);
        expect(attempts, ['yt-dlp', 'spotdl']);
        expect(importer.state.error, contains('yt-dlp: Сеть недоступна'));
        expect((await importer.checkTools())['spotdl'], isTrue);
        fail = false;
        await importer.installTools(ImportProvider.spotify);
        expect(attempts, ['yt-dlp', 'spotdl', 'yt-dlp']);
        expect(importer.state.error, isNull);
      } finally {
        await importer.close();
      }
    },
  );

  test(
    'Ошибка загрузки компонентов не меняет медиатеку и допускает повтор',
    () async {
      final before = repository.library.toJson();
      final importer = ImportCubit(
        music,
        FakeVkSession(root),
        toolFinder: (_) async => throw StateError('Отсутствует'),
        toolInstaller: (_, worker, temporary, status) async =>
            throw StateError('Сеть недоступна'),
      );
      await importer.installTools(ImportProvider.youtube);
      expect(importer.state.error, contains('Сеть недоступна'));
      expect(importer.state.busy, isFalse);
      expect(music.state.importing, isFalse);
      expect(repository.library.toJson(), before);
      await importer.close();
    },
  );

  testWidgets(
    'Окно импорта: автоисточник, ошибка ссылки и готовность компонентов',
    (tester) async {
      final available = {'ffmpeg', 'yt-dlp'};
      final importer = ImportCubit(
        music,
        FakeVkSession(root),
        toolFinder: (name) async {
          if (!available.contains(name)) throw StateError('Нет $name');
          return name;
        },
      );
      addTearDown(importer.close);
      tester.view.physicalSize = const Size(600, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      if (const bool.fromEnvironment('CAPTURE_IMPORT_DIALOG')) {
        await tester.runAsync(() async {
          final font = FontLoader('Preview')
            ..addFont(
              Future.value(
                ByteData.sublistView(
                  await File(
                    '.fvm/flutter_sdk/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf',
                  ).readAsBytes(),
                ),
              ),
            );
          await font.load();
          final icons = FontLoader('MaterialIcons')
            ..addFont(
              Future.value(
                ByteData.sublistView(
                  await File(
                    '.fvm/flutter_sdk/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
                  ).readAsBytes(),
                ),
              ),
            );
          await icons.load();
        });
      }
      final previewKey = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: previewKey,
          child: BlocProvider.value(
            value: importer,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: ThemeData(
                fontFamily: const bool.fromEnvironment('CAPTURE_IMPORT_DIALOG')
                    ? 'Preview'
                    : null,
                colorScheme: ColorScheme.fromSeed(
                  seedColor: const Color(0xFFFFAD32),
                  brightness: Brightness.dark,
                ),
              ),
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => BlocProvider.value(
                        value: importer,
                        child: const MusicImportDialog(),
                      ),
                    ),
                    child: const Text('Открыть'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Открыть'));
      await tester.pumpAndSettle();
      expect(find.text('Без cookies браузера'), findsOneWidget);
      await tester.runAsync(
        () => importer.remote(
          ImportProvider.youtube,
          'https://youtube.com/watch?v=invalid',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Некорректный ID видео'), findsOneWidget);
      await tester.tap(find.text('Без cookies браузера'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Firefox'));
      await tester.pumpAndSettle();
      expect(find.text('Firefox'), findsOneWidget);
      expect(find.text('Некорректный ID видео'), findsNothing);
      expect(find.byType(DropdownButton<ImportProvider>), findsNothing);
      expect(find.text('Скачать недостающее'), findsOneWidget);
      FilledButton importButton() => tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Импортировать'),
      );
      expect(importButton().onPressed, isNull);
      await tester.enterText(
        find.byType(TextField).first,
        'https://soundcloud.com/artist/track',
      );
      await tester.pumpAndSettle();
      expect(find.text('Firefox'), findsNothing);
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'SoundCloud'))
            .selected,
        isTrue,
      );
      expect(importButton().onPressed, isNotNull);
      await tester.enterText(
        find.byType(TextField).first,
        'https://example.com/song',
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Источник не поддерживается.'),
        findsOneWidget,
      );
      expect(importButton().onPressed, isNull);
      await tester.enterText(
        find.byType(TextField).first,
        'https://youtu.be/abcdefghijk',
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'YouTube'))
            .selected,
        isTrue,
      );
      expect(importButton().onPressed, isNull);
      available.add('node');
      await tester.ensureVisible(find.text('Проверить снова'));
      await tester.tap(find.text('Проверить снова'));
      await tester.pumpAndSettle();
      expect(importButton().onPressed, isNotNull);
      await tester.enterText(
        find.byType(TextField).first,
        'https://vk.ru/audio1_2',
      );
      await tester.pumpAndSettle();
      expect(find.text('Войти в VK'), findsOneWidget);
      expect(find.text('JavaScript runtime · Deno / Node.js'), findsNothing);
      for (final width in [420.0, 900.0]) {
        tester.view.physicalSize = Size(width, 900);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      if (const bool.fromEnvironment('CAPTURE_IMPORT_DIALOG')) {
        await tester.enterText(
          find.byType(TextField).first,
          'https://youtu.be/abcdefghijk',
        );
        await tester.pumpAndSettle();
        available.remove('node');
        await tester.tap(find.text('Проверить снова'));
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          final image =
              await (previewKey.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage();
          final data = await image.toByteData(format: ImageByteFormat.png);
          await File('/tmp/walone-import-dialog.png')
              .writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.tap(find.text('Закрыть'));
      await tester.pumpAndSettle();
    },
  );

  test('Таймкоды, главы и ссылки: валидация до запуска инструментов', () {
    expect(AudioSection.timestamp('1:02:03'), 3723);
    expect(AudioSection.timestamp('1:70'), isNull);
    final sections = AudioSection.parse('0:02 Первый\n0:06 Второй', 10);
    expect(sections.first.title, 'Начало записи');
    expect(sections.last.end, 10);
    expect(
      () => AudioSection.parse('0:06 Первый\n0:02 Второй', 10),
      throwsFormatException,
    );
    expect(
      () => MusicLink.parse(
        ImportProvider.youtube,
        'https://youtube.com.evil.test/watch?v=abcdefghijk',
      ),
      throwsFormatException,
    );
    expect(
      () => MusicLink.parse(ImportProvider.vk, 'https://user@vk.ru/audio1_2'),
      throwsFormatException,
    );
    expect(
      MusicLink.parse(
        ImportProvider.vk,
        'https://vk.com/music/playlist/-1_2_abc',
      ).url,
      'https://m.vk.ru/audio?act=audio_playlist-1_2_abc',
    );
    expect(VkSession.allows('https://id.vk.com/authorize'), isTrue);
    expect(VkSession.allows('https://vk.com.evil.test/'), isFalse);
    expect(VkSession.isLoginComplete('https://vk.ru/feed'), isTrue);
    expect(VkSession.isLoginComplete('https://vk.com/feed?from=login'), isTrue);
    expect(VkSession.isLoginComplete('https://id.vk.ru/feed'), isFalse);
    expect(VkSession.isLoginComplete('https://vk.ru.evil.test/feed'), isFalse);
    expect(VkSession.isLoginComplete('https://vk.ru/'), isFalse);
    expect(VkSession.isLoginComplete('https://id.vk.ru/authorize'), isFalse);
  });

  test(
    'Наборы атмосферы, отмена переключения, общая пауза и восстановление',
    () async {
      final keyboard = KeyboardCubit(FakeKeyboard());
      await keyboard.initialize();
      final environment = <(double, bool)>[];
      final backgroundPlayers = <FakeAudio>[];
      final atmosphere = AtmosphereCubit(
        store: JsonStore(File(p.join(root.path, 'atmosphere.json'))),
        audio: AtmosphereAudio(
          factory: () {
            final player = FakeAudio();
            backgroundPlayers.add(player);
            return player;
          },
        ),
        music: music,
        keyboard: keyboard,
        keyboardEnvironment: (volume, allowed) async {
          environment.add((volume, allowed));
        },
        lifecycle: const Stream.empty(),
      );
      await atmosphere.initialize();
      final originalMaster = atmosphere.state.master;
      final originalMusicVolume = music.state.library.volume;
      final originalKeyboardVolume = keyboard.state.volume;
      await atmosphere.setBackgroundVolume(0.4);
      expect(atmosphere.state.backgroundVolume, 0.4);
      expect(atmosphere.state.master, originalMaster);
      expect(music.state.library.volume, originalMusicVolume);
      expect(keyboard.state.volume, originalKeyboardVolume);
      await atmosphere.setLayer('rain', enabled: true, volume: 0.3);
      await atmosphere.savePreset('Дождь');
      final id = atmosphere.state.presets.single.id;
      await atmosphere.setLayer('rain', enabled: false);
      await atmosphere.selectPreset(id);
      expect(atmosphere.state.running, isTrue);
      expect(atmosphere.state.mix.layers['rain']!.enabled, isTrue);
      expect(
        backgroundPlayers.first.volume,
        closeTo(0.3 * originalMaster * 0.4, 0.0001),
      );
      await atmosphere.setBackgroundVolume(0.2);
      expect(
        backgroundPlayers.first.volume,
        closeTo(0.3 * originalMaster * 0.2, 0.0001),
      );
      await atmosphere.setBackgroundVolume(0.4);

      await atmosphere.undo();
      expect(atmosphere.state.mix.layers['rain']!.enabled, isFalse);
      await atmosphere.pause(duration: const Duration(milliseconds: 20));
      expect(environment.last.$2, isFalse);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(atmosphere.state.paused, isFalse);
      await atmosphere.close();
      final saved = jsonDecode(
        await File(p.join(root.path, 'atmosphere.json')).readAsString(),
      ) as Map<String, dynamic>;
      expect((saved['presets'] as List<dynamic>), hasLength(1));
      expect(saved['backgroundVolume'], 0.4);
      await keyboard.close();
    },
  );

  test(
    'Событие сна останавливает все источники и очищает намерение Play',
    () async {
      final keyboard = KeyboardCubit(FakeKeyboard());
      await keyboard.initialize();
      final lifecycle = StreamController<dynamic>(sync: true);
      final environment = <bool>[];
      final players = <FakeAudio>[];
      final atmosphere = AtmosphereCubit(
        store: JsonStore(File(p.join(root.path, 'sleep-atmosphere.json'))),
        audio: AtmosphereAudio(
          factory: () {
            final player = FakeAudio();
            players.add(player);
            return player;
          },
        ),
        music: music,
        keyboard: keyboard,
        keyboardEnvironment: (_, allowed) async => environment.add(allowed),
        lifecycle: lifecycle.stream,
      );
      try {
        await atmosphere.initialize();
        await atmosphere.setLayer('rain', enabled: true);
        await atmosphere.toggleBackground();
        final track = await add('sleep-track', '30');
        await music.play(
          trackID: track.id,
          playlistID: repository.library.selectedID,
        );
        expect(music.state.playing, isTrue);
        expect(players.any((player) => player.playing), isTrue);
        final paused = atmosphere.stream.firstWhere((state) => state.paused);
        lifecycle.add({'reason': 'sleep'});
        // Ошибка плеера может прийти следом за отключением аудиовыхода.
        atmosphere.audio.onError!('Ошибка декодирования аудио');
        await paused.timeout(const Duration(seconds: 2));
        await Future<void>.delayed(Duration.zero);
        expect(atmosphere.state.error, contains('аудиовыхода'));
        expect(atmosphere.state.running, isTrue);
        expect(environment.last, isFalse);
        expect(music.state.playing, isFalse);
        expect(players.every((player) => player.disposed), isTrue);
        await atmosphere.resume();
        expect(environment.last, isTrue);
        expect(music.state.playing, isFalse);
        await music.play();
        expect(music.state.playing, isTrue);
      } finally {
        await atmosphere.close();
        await lifecycle.close();
        await keyboard.close();
      }
    },
  );

  testWidgets('Импорт доступен при провайдерах внутри маршрута', (
    tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('desktop_drop'),
          (_) async => null,
        );
    final importer = ImportCubit(
      music,
      FakeVkSession(root),
      toolFinder: (name) async => name,
    );
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider.value(value: music),
              BlocProvider.value(value: importer),
            ],
            child: const MusicPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Импорт по ссылке'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Импорт по ссылке'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('HTTPS-ссылка'), findsOneWidget);
      await tester.tap(find.text('Закрыть'));
      await tester.pumpAndSettle();
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(importer.close);
    }
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('Пустая медиатека не занимает место плеером', (tester) async {
    await tester.pumpWidget(
      BlocProvider.value(
        value: music,
        child: const MaterialApp(home: Scaffold(body: MusicPlayerBar())),
      ),
    );
    expect(find.byType(IconButton), findsNothing);
    expect(find.byType(GainSlider), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('В компактном плеере пустой канал музыки сохраняет место', (
    tester,
  ) async {
    await tester.pumpWidget(
      BlocProvider.value(
        value: music,
        child: const MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(width: 168, child: MusicPlayerBar(compact: true)),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Выберите трек в медиатеке'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.byWidgetPredicate(
              (widget) =>
                  widget is IconButton &&
                  widget.tooltip == 'Воспроизвести музыку',
            ),
          )
          .onPressed,
      isNull,
    );
    final position = tester.widget<GainSlider>(
      find.byWidgetPredicate(
        (widget) => widget is GainSlider && widget.label == 'Позиция',
      ),
    );
    expect(position.onChanged, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Разделы и плеер помещаются в 560×680, музыка сохраняется при переходах',
    (tester) async {
      Future<int> settle() => tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 5),
      );
      tester.view.physicalSize = const Size(560, 680);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('desktop_drop'),
            (_) async => null,
          );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('dev.soyjanks.walone/desktop'),
            (call) async =>
                call.method == 'initialize' || call.method == 'status'
                ? {'login': 'disabled', 'trayAvailable': true}
                : null,
          );
      const appearanceChannel = MethodChannel('dev.soyjanks.walone/appearance');
      double? systemTint;
      var reduceTransparency = false;
      var increaseContrast = false;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        appearanceChannel,
        (_) async => {
          'glassTint': systemTint,
          'reduceTransparency': reduceTransparency,
          'increaseContrast': increaseContrast,
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          appearanceChannel,
          null,
        ),
      );
      final keyboard = KeyboardCubit(FakeKeyboard());
      await keyboard.initialize();
      final atmosphere = AtmosphereCubit(
        store: JsonStore(File(p.join(root.path, 'atmosphere.json'))),
        audio: AtmosphereAudio(factory: FakeAudio.new),
        music: music,
        keyboard: keyboard,
        keyboardEnvironment: (_, _) async {},
        lifecycle: const Stream.empty(),
      );
      final importer = ImportCubit(
        music,
        FakeVkSession(root),
        toolFinder: (name) async => name,
      );
      final timer = TimerCubit();
      late SettingsCubit settings;
      await tester.runAsync(() async {
        await atmosphere.initialize();
        settings = SettingsCubit(atmosphere);
        await settings.initialize();
        final track = await add('original', '10');
        final playlistID = repository.library.selectedID!;
        await music.accept([
          for (var i = 1; i <= 60; i++)
            MusicTrack(
              id: i.toRadixString(16).padLeft(64, '0'),
              title: 'Track $i',
              filename: '${i.toRadixString(16).padLeft(64, '0')}.wav',
              duration: 10,
            ),
        ], playlistID: playlistID);
        await music.reorder(playlistID, 0, 61);
        await music.play(trackID: track.id, playlistID: playlistID);
        await music.savePlaylist('Другой список');
      });
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider.value(value: music),
            BlocProvider.value(value: keyboard),
            BlocProvider.value(value: atmosphere),
            BlocProvider.value(value: importer),
            BlocProvider.value(value: settings),
            BlocProvider.value(value: timer),
          ],
          child: MaterialApp(
            theme: ThemeData(useMaterial3: true),
            darkTheme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.dark,
            ),
            builder: (context, child) => WaloneGlassHost(
              // Непрерывная анимация логотипа не должна удерживать pumpAndSettle
              // в проверке компоновки; движение проверяется отдельными тестами.
              child: MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: child!,
              ),
            ),
            home: const WorkspacePage(),
          ),
        ),
      );
      await settle();
      final appearance = WaloneGlassHost.maybeOf(
        tester.element(find.byType(WorkspacePage)),
      )!;
      appearance.setCompactPlayer(false);
      await settle();
      expect(
        tester.widget<GlassHost>(find.byType(GlassHost)).maxCaptures,
        isNull,
      );
      expect(find.byType(MusicPage, skipOffstage: false), findsNothing);
      expect(find.byType(KeyboardPage, skipOffstage: false), findsNothing);
      expect(find.byType(SettingsPage, skipOffstage: false), findsNothing);
      expect(
        GlassBackdrop.maybeOf(tester.element(find.byType(AtmospherePage))),
        isNull,
      );
      void expectSharedGlass(double opacity, GlassTier tier) {
        final surfaces = find.byType(FrostedPanel, skipOffstage: false);
        expect(surfaces.evaluate().length, greaterThan(10));
        for (final element in surfaces.evaluate()) {
          final panel = find.byWidget(element.widget, skipOffstage: false);
          final material = tester.widget<Material>(
            find
                .descendant(
                  of: panel,
                  matching: find.byType(Material, skipOffstage: false),
                )
                .first,
          );
          final opaque = tier == GlassTier.opaque || increaseContrast;
          expect(material.color!.a, opaque ? 1 : lessThan(1));
          final glass = GlassTheme.of(element);
          expect(glass.finish.tint.a, closeTo(opacity, 0.001));
          final border = (material.shape! as RoundedRectangleBorder).side;
          if (increaseContrast) {
            final scheme = Theme.of(element).colorScheme;
            expect(
              border.color,
              (element.widget as FrostedPanel).selected
                  ? scheme.primary
                  : scheme.outline,
            );
          }
        }
      }

      for (final transparency in [0.3, 0.9, 0.0]) {
        appearance.setTransparency(transparency);
        await settle();
        expectSharedGlass(
          1 - transparency,
          transparency == 0 ? GlassTier.opaque : GlassTier.full,
        );
      }
      Future<void> refreshAppearance() async {
        await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
          appearanceChannel.name,
          appearanceChannel.codec.encodeMethodCall(const MethodCall('changed')),
          (_) {},
        );
        await settle();
      }

      systemTint = 0.65;
      await refreshAppearance();
      expectSharedGlass(0.65, GlassTier.full);
      reduceTransparency = true;
      increaseContrast = true;
      await refreshAppearance();
      expectSharedGlass(1, GlassTier.opaque);
      reduceTransparency = false;
      increaseContrast = false;
      systemTint = null;
      await refreshAppearance();
      appearance.setTransparency(0.85);
      await settle();
      expectSharedGlass(0.15, GlassTier.full);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await settle();
      expect(
        Theme.of(tester.element(find.byType(WorkspacePage))).brightness,
        Brightness.dark,
      );
      expectSharedGlass(0.15, GlassTier.full);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      await settle();
      expectSharedGlass(0.15, GlassTier.full);
      final expandedPlayer = find
          .ancestor(
            of: find.byType(MusicPlayerBar),
            matching: find.byType(FrostedPanel),
          )
          .first;
      Finder expandedSlider(String label) => find.descendant(
        of: expandedPlayer,
        matching: find.byWidgetPredicate(
          (widget) => widget is GainSlider && widget.label == label,
        ),
      );
      for (final label in ['Громкость атмосферы', 'Громкость клавиатуры']) {
        expect(expandedSlider(label).hitTestable(), findsOneWidget);
      }
      expect(
        tester
            .widget<GainSlider>(expandedSlider('Громкость атмосферы'))
            .onChanged,
        isNotNull,
      );
      expect(
        tester
            .widget<GainSlider>(expandedSlider('Громкость клавиатуры'))
            .onChanged,
        isNotNull,
      );
      await tester.tap(
        find.descendant(of: expandedPlayer, matching: find.text('Клавиатура')),
      );
      await settle();
      expect(find.text('Звук вашей клавиатуры'), findsOneWidget);
      await tester.runAsync(() async {
        final selected = music.stream.firstWhere(
          (state) => state.library.selectedID == state.library.playingID,
        );
        await tester.tap(
          find.descendant(of: expandedPlayer, matching: find.text('original')),
        );
        await selected.timeout(const Duration(seconds: 5));
        await Future<void>.delayed(Duration.zero);
      });
      await settle();
      expect(find.byType(MusicPage), findsOneWidget);
      expect(
        find.widgetWithText(MusicTrackTile, 'original').hitTestable(),
        findsOneWidget,
      );
      expect(repository.library.selectedID, repository.library.playingID);
      await tester.tap(
        find.descendant(of: expandedPlayer, matching: find.text('Атмосфера')),
      );
      await settle();
      expect(find.text('Звуки окружения'), findsOneWidget);
      expect(music.state.playing, isTrue);
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Моя музыка'),
        ),
      );
      await settle();
      expect(music.state.playing, isTrue);
      expect(
        tester
            .state<ScrollableState>(
              find
                  .descendant(
                    of: find.byType(MusicPage),
                    matching: find.byType(Scrollable),
                  )
                  .first,
            )
            .position
            .pixels,
        greaterThan(0),
      );
      tester
          .state<ScrollableState>(
            find
                .descendant(
                  of: find.byType(MusicPage),
                  matching: find.byType(Scrollable),
                )
                .first,
          )
          .position
          .jumpTo(0);
      await settle();
      expect(find.text('Добавить файлы'), findsOneWidget);
      await tester.ensureVisible(find.text('Импорт по ссылке'));
      await settle();
      await tester.tap(find.text('Импорт по ссылке'));
      await settle();
      expect(find.text('Импорт музыки'), findsOneWidget);
      await tester.tap(find.text('Закрыть'));
      await settle();
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Клавиатура'),
        ),
      );
      await settle();
      expect(music.state.playing, isTrue);
      expect(tester.takeException(), isNull);
      await tester.enterText(
        find.widgetWithText(TextField, 'Поиск клавиатуры'),
        'сохранённый поиск',
      );
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Настройки'),
        ),
      );
      await settle();
      final settingsPosition = tester
          .state<ScrollableState>(
            find
                .descendant(
                  of: find.byType(SettingsPage),
                  matching: find.byType(Scrollable),
                )
                .first,
          )
          .position;
      for (
        var step = 0;
        step < 10 &&
            find.text('Запускать при входе в систему').evaluate().isEmpty;
        step++
      ) {
        settingsPosition.jumpTo(
          (settingsPosition.pixels + 200).clamp(
            0,
            settingsPosition.maxScrollExtent,
          ),
        );
        await settle();
      }
      expect(find.text('Запускать при входе в систему'), findsOneWidget);
      expect(find.byType(KeyboardPage, skipOffstage: false), findsNothing);
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Клавиатура'),
        ),
      );
      await settle();
      expect(
        tester
            .widget<TextField>(
              find.widgetWithText(TextField, 'Поиск клавиатуры'),
            )
            .controller!
            .text,
        'сохранённый поиск',
      );
      expect(music.state.playing, isTrue);
      expect(tester.takeException(), isNull);
      for (final width in [760.0, 920.0, 1280.0]) {
        tester.view.physicalSize = Size(width, 820);
        await settle();
        expect(find.byType(WorkspaceSidebar), findsOneWidget);
        final bubble = find.byKey(const ValueKey('sidebar-selection-bubble'));
        expect(bubble, findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(WorkspaceSidebar),
            matching: find.byWidgetPredicate(
              (widget) => widget is ListTile && widget.selected,
            ),
          ),
          findsOneWidget,
        );
        // Выделение меню — стабильная заливка, независимо от прозрачности панелей.
        final selectedFill = Theme.of(tester.element(bubble))
            .colorScheme
            .primaryContainer;
        for (final transparency in [0.0, 0.5, 1.0]) {
          appearance.setTransparency(transparency);
          await settle();
          final decoration =
              tester.widget<DecoratedBox>(bubble).decoration as BoxDecoration;
          expect(decoration.color, selectedFill);
          expect(decoration.gradient, isNull);
          expect(
            find.descendant(of: bubble, matching: find.byType(GlassSurface)),
            findsNothing,
          );
        }
        appearance.setTransparency(0.85);
        await settle();
        await tester.tap(
          find.descendant(
            of: find.byType(WorkspaceSidebar),
            matching: find.text('Атмосфера'),
          ),
        );
        await settle();
        final rain = tester.getTopLeft(find.byType(AmbientLayerCard).at(0));
        final ocean = tester.getTopLeft(find.byType(AmbientLayerCard).at(1));
        if (width >= 920) {
          expect(ocean.dy, rain.dy);
          expect(ocean.dx, greaterThan(rain.dx));
        } else {
          expect(ocean.dy, greaterThan(rain.dy));
        }
        expect(music.state.playing, isTrue);
        expect(tester.takeException(), isNull);
      }
      await tester.tap(find.byTooltip('Убрать плеер в левое меню'));
      await settle();
      expect(find.byType(CompactPlayer), findsOneWidget);
      expect(
        GlassBackdrop.maybeOf(tester.element(find.byType(AtmospherePage))),
        isNotNull,
      );
      expect(tester.widget<GlassHost>(find.byType(GlassHost)).maxCaptures, 0);
      final compactPanel = find.byType(CompactPlayer);
      final playerCard = find.byKey(const ValueKey('sidebar-player-card'));
      expect(playerCard, findsOneWidget);
      expect(
        find.descendant(of: playerCard, matching: compactPanel),
        findsOneWidget,
      );
      expect(
        tester.getTopLeft(playerCard).dx,
        greaterThan(tester.getTopLeft(find.byType(WorkspaceSidebar)).dx),
      );
      for (final transparency in [0.0, 0.5, 1.0]) {
        appearance.setTransparency(transparency);
        await settle();
        final material = tester.widget<Material>(
          find
              .descendant(of: playerCard, matching: find.byType(Material))
              .first,
        );
        expect(material.color!.a, transparency == 0 ? 1 : lessThan(1));
        expect(
          find.descendant(of: playerCard, matching: find.byType(GlassSurface)),
          transparency == 0 ? findsNothing : findsOneWidget,
        );
      }
      appearance.setTransparency(0.85);
      await settle();
      await tester.tap(
        find.descendant(of: compactPanel, matching: find.text('Клавиатура')),
      );
      await settle();
      expect(find.text('Звук вашей клавиатуры'), findsOneWidget);
      expect(music.state.playing, isTrue);
      await tester.tap(
        find.descendant(of: compactPanel, matching: find.text('Атмосфера')),
      );
      await settle();
      expect(find.text('Звуки окружения'), findsOneWidget);
      expect(music.state.playing, isTrue);
      Finder compactSlider(String label) => find.descendant(
        of: compactPanel,
        matching: find.byWidgetPredicate(
          (widget) => widget is GainSlider && widget.label == label,
        ),
      );
      expect(tester.getSize(compactPanel).height, lessThan(440));
      final channelPositions = {
        for (final label in [
          'Громкость музыки',
          'Громкость атмосферы',
          'Громкость клавиатуры',
          'Общая громкость',
        ])
          label: tester.getTopLeft(compactSlider(label)),
      };
      for (final section in [
        'Клавиатура',
        'Моя музыка',
        'Настройки',
        'Атмосфера',
      ]) {
        await tester.tap(
          find.descendant(
            of: find.byType(WorkspaceSidebar),
            matching: find.widgetWithText(ListTile, section),
          ),
        );
        await settle();
        for (final entry in channelPositions.entries) {
          expect(compactSlider(entry.key), findsOneWidget);
          expect(tester.getTopLeft(compactSlider(entry.key)), entry.value);
        }
      }
      final position = compactSlider('Позиция');
      await tester.runAsync(() async {
        final moved = music.stream.firstWhere((state) => state.position > 0);
        await tester.tapAt(
          tester.getTopLeft(position) +
              Offset(tester.getSize(position).width * 0.7, 13),
        );
        await moved.timeout(const Duration(seconds: 3));
      });
      await settle();
      expect(music.state.position, closeTo(7, 0.2));
      expect(music.state.playing, isTrue);
      await tester.tap(
        find.descendant(of: compactPanel, matching: find.text('original')),
      );
      await settle();
      expect(find.byType(MusicPage), findsOneWidget);
      expect(
        find.widgetWithText(MusicTrackTile, 'original').hitTestable(),
        findsOneWidget,
      );
      expect(music.state.playing, isTrue);
      await tester.tap(
        find.descendant(of: compactPanel, matching: find.text('Атмосфера')),
      );
      await settle();

      await tester.runAsync(() async {
        await atmosphere.setLayer('rain', enabled: true);
        await atmosphere.pause(duration: const Duration(minutes: 15));
      });
      await settle();
      expect(find.textContaining('До '), findsOneWidget);
      expect(find.text('Выбран · общая пауза'), findsOneWidget);
      expect(music.state.playing, isFalse);
      expect(atmosphere.state.mix.layers['rain']!.enabled, isTrue);
      final levels = [
        atmosphere.state.master,
        atmosphere.state.backgroundVolume,
        keyboard.state.volume,
      ];
      await tester.runAsync(() async {
        final resumed = atmosphere.stream.firstWhere((state) => !state.paused);
        await tester.tap(find.text('Возобновить'));
        await resumed;
      });
      await settle();
      expect(atmosphere.state.paused, isFalse);
      expect(atmosphere.state.pausedUntil, isNull);
      expect(music.state.playing, isTrue);
      expect(find.textContaining('До '), findsNothing);
      expect([
        atmosphere.state.master,
        atmosphere.state.backgroundVolume,
        keyboard.state.volume,
      ], levels);

      expect(
        find.descendant(
          of: find.byType(WorkspaceSidebar),
          matching: find.byType(MusicPlayerBar),
        ),
        findsOneWidget,
      );
      expect(
        tester.getBottomRight(find.byType(CompactPlayer)).dx,
        lessThanOrEqualTo(
          tester.getBottomRight(find.byType(WorkspaceSidebar)).dx,
        ),
      );
      expect(
        MediaQuery.paddingOf(tester.element(find.byType(AtmospherePage)))
            .bottom,
        0,
      );
      expect(music.state.playing, isTrue);
      tester.view.physicalSize = const Size(560, 680);
      await settle();
      expect(find.byType(CompactPlayer), findsNothing);
      expect(find.byType(MusicPlayerBar), findsOneWidget);
      tester.view.physicalSize = const Size(920, 820);
      await settle();
      expect(find.byType(CompactPlayer), findsOneWidget);
      await tester.tap(find.byTooltip('Развернуть плеер'));
      await settle();
      expect(find.byType(CompactPlayer), findsNothing);
      expect(find.byTooltip('Убрать плеер в левое меню'), findsOneWidget);
      expect(music.state.playing, isTrue);
      tester.view.physicalSize = const Size(560, 680);
      await settle();
      await tester.runAsync(() async {
        final paused = atmosphere.stream.firstWhere((state) => state.paused);
        await tester.tap(find.text('Пауза всех звуков'));
        await paused;
      });
      await settle();
      expect(find.text('Все звуки на паузе'), findsOneWidget);
      expect(find.text('Возобновить все звуки'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final resumed = atmosphere.stream.firstWhere((state) => !state.paused);
        await tester.tap(find.text('Возобновить все звуки'));
        await resumed;
      });
      await settle();
      expect(music.state.playing, isTrue);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(tester.takeException(), isNull);
      final content = find.byKey(const ValueKey('workspace-content'));
      final player = find
          .ancestor(
            of: find.byType(MusicPlayerBar),
            matching: find.byType(FrostedPanel),
          )
          .first;
      final page = find.byType(AtmospherePage);
      expect(tester.getBottomRight(page).dy, tester.getBottomRight(content).dy);
      expect(
        tester.getTopLeft(player).dy,
        lessThan(tester.getBottomRight(page).dy),
      );
      final footer = find.text(
        'Все звуки доступны без интернета. Наборы также сохраняют выбор и громкость клавиатуры.',
      );
      final atmosphereScroll = tester
          .state<ScrollableState>(
            find.descendant(of: page, matching: find.byType(Scrollable)).first,
          )
          .position;
      atmosphereScroll.jumpTo(atmosphereScroll.maxScrollExtent);
      await settle();
      await tester.ensureVisible(footer);
      await settle();
      expect(
        tester.getBottomRight(footer).dy,
        lessThan(tester.getTopLeft(player).dy),
      );
      expect(music.state.playing, isTrue);
      final master = atmosphere.state.master;
      expect(find.byTooltip('Случайный порядок'), findsOneWidget);
      expect(find.byTooltip('Повтор выключен'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is GainSlider && widget.label == 'Громкость музыки',
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(MusicPlayerBar),
          matching: find.byType(PopupMenuButton<String>),
        ),
        findsNothing,
      );
      expect(atmosphere.state.master, master);
      expect(music.state.playing, isTrue);
      expect(tester.takeException(), isNull);
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Таймеры'),
        ),
      );
      await settle();
      expect(find.text('Помодоро'), findsOneWidget);
      await Scrollable.ensureVisible(
        tester.element(find.byTooltip('Запустить')),
        alignment: 0,
      );
      await settle();
      await tester.tap(find.byTooltip('Запустить'));
      await tester.pump();
      expect(timer.state.pomodoro.running, isTrue);
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Атмосфера'),
        ),
      );
      await settle();
      expect(timer.state.pomodoro.running, isTrue);
      expect(music.state.playing, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await settle();
      await timer.close();
      await tester.runAsync(() async {
        await settings.close();
        await importer.close();
        await atmosphere.close();
        await keyboard.close();
      });
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  test('Ошибки сервиса понятны и не раскрывают диагностические URL', () async {
    if (Platform.isWindows) return;
    for (final (diagnostic, expected) in [
      (
        'ERROR: Sign in to confirm you’re not a bot. https://private.invalid/token',
        'YouTube запросил проверку',
      ),
      (
        'WARNING: Read timed out https://private.invalid/token',
        'Сервис не ответил',
      ),
    ]) {
      await expectLater(
        MusicProcess().run('/bin/sh', [
          '-c',
          r'printf %s "$1" >&2; exit 1',
          'walone',
          diagnostic,
        ], root),
        throwsA(
          predicate(
            (error) =>
                error.toString().contains(expected) &&
                !error.toString().contains('private.invalid'),
          ),
        ),
      );
    }
  });

  test(
    'Срок ожидания возвращает понятную ошибку и завершает процесс',
    () async {
      if (Platform.isWindows) return;
      await expectLater(
        MusicProcess().run(
          '/bin/sh',
          ['-c', 'exec sleep 30'],
          root,
          timeout: const Duration(milliseconds: 50),
        ),
        throwsA(
          predicate((error) => error.toString().contains('Сервис не ответил')),
        ),
      );
    },
  );

  test('Процесс возвращает вывод и отменяет собственную задачу', () async {
    if (Platform.isWindows) return;
    final worker = MusicProcess();
    expect(
      await worker.run('/bin/sh', ['-c', 'printf ok'], root, capture: true),
      'ok',
    );
    final running = MusicProcess();
    final operation = running.run('/bin/sh', ['-c', 'exec sleep 30'], root);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    running.cancel();
    await expectLater(operation, throwsA(isA<ImportCancelled>()));
    worker.cancel();
    await expectLater(
      worker.run('/bin/sh', ['-c', 'printf no'], root),
      throwsA(isA<ImportCancelled>()),
    );
  });
}
