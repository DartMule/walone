import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;

import '../data/music_process.dart';
import '../data/import_tools.dart';
import '../data/vk_session.dart';
import '../domain/import.dart';
import '../domain/music.dart';
import 'music_cubit.dart';

class ImportState {
  const ImportState({this.busy = false, this.status = '', this.error});
  final bool busy;
  final String status;
  final String? error;
}

class ImportCubit extends Cubit<ImportState> {
  ImportCubit(
    this.music,
    this.vk, {
    this.toolFinder = MusicProcess.executable,
    this.workerFactory = MusicProcess.new,
    this.toolInstaller = ImportTools.install,
  }) : super(const ImportState());
  final Future<String> Function(String) toolFinder;
  final MusicProcess Function() workerFactory;
  final Future<void> Function(
    String,
    MusicProcess,
    Directory,
    void Function(String),
  )
  toolInstaller;

  Future<Map<String, bool>> checkTools() async {
    final found = <String, bool>{};
    for (final name in ['ffmpeg', 'yt-dlp', 'deno', 'node', 'spotdl']) {
      try {
        await toolFinder(name);
        found[name] = true;
      } catch (_) {
        found[name] = false;
      }
    }
    return {
      'ffmpeg': found['ffmpeg']!,
      'yt-dlp': found['yt-dlp']!,
      'spotdl': found['spotdl']!,
      'javascript': found['deno']! || found['node']!,
    };
  }

  Future<void> installTools(ImportProvider provider) =>
      _run((worker, root) async {
        final tools = await checkTools();
        for (final name in requiredImportTools(provider)) {
          worker.check();
          if (!tools[name]!) await toolInstaller(name, worker, root, _status);
        }
        final checked = await checkTools();
        if (requiredImportTools(provider).any((name) => !checked[name]!)) {
          throw StateError('Не все компоненты готовы. Повторите проверку.');
        }
        return 'Компоненты установлены. Можно импортировать музыку.';
      });
  final MusicCubit music;
  final VkSession vk;
  MusicProcess? _worker;
  Future<void>? _task;

  void _status(String text) {
    if (!isClosed) emit(ImportState(busy: true, status: text));
  }

  Future<void> cancel() async {
    _worker?.cancel();
    await vk.cancel();
  }

  Future<void> login() async {
    try {
      await vk.open();
    } catch (error) {
      if (!isClosed) emit(ImportState(error: '$error'));
    }
  }

  Future<void> forget() async {
    if (state.busy) return;
    try {
      await vk.forget();
      if (!isClosed) emit(const ImportState(status: 'Вход VK удалён'));
    } catch (_) {
      if (!isClosed) {
        emit(const ImportState(error: 'Не удалось удалить вход VK'));
      }
    }
  }

  Future<void> _run(
    Future<String> Function(MusicProcess, Directory) action,
  ) async {
    if (state.busy || music.state.importing) return;
    final worker = workerFactory();
    _worker = worker;
    music.setImporting(true);
    _status('Подготовка…');
    final task = () async {
      Directory? directory;
      try {
        directory = await Directory.systemTemp.createTemp('walone-import-');
        final message = await action(worker, directory);
        if (!isClosed) emit(ImportState(status: message));
      } catch (error) {
        if (!isClosed) emit(ImportState(error: '$error'));
      } finally {
        _worker = null;
        music.setImporting(false);
        try {
          await directory?.delete(recursive: true);
        } catch (_) {
          /* Неудачная очистка временных файлов не меняет медиатеку. */
        }
      }
    }();
    _task = task;
    await task;
    _task = null;
  }

  Future<void> files(
    List<String> paths, {
    Future<String?> Function(String, List<String>)? chooseArtist,
  }) {
    if (state.busy) return Future.value();
    _chooseArtist = chooseArtist;
    _artistChoices.clear();
    final destination = music.repository.library.selectedID;
    return _run((worker, directory) async {
      if (destination == null) throw StateError('Сначала создайте плейлист');
      var added = 0;
      final errors = <String>[];
      for (var i = 0; i < paths.length; i++) {
        worker.check();
        _status('Файл ${i + 1} из ${paths.length}');
        MusicTrack? track;
        try {
          final details = trackDetails({
            'title': p.basenameWithoutExtension(paths[i]),
          });
          track = await music.repository.prepareFile(
            paths[i],
            title: details.title,
            artists: await _artists(details.artists),
          );
          worker.check();
          await music.accept([track], playlistID: destination);
          added++;
        } on ImportCancelled {
          rethrow;
        } catch (error) {
          if (track != null) await music.repository.discard([track]);
          worker.check();
          errors.add('${p.basename(paths[i])}: $error');
        }
      }
      return 'Обработано: $added. Пропущено: ${errors.length}.${errors.isEmpty ? '' : '\n${errors.take(20).join('\n')}'}';
    });
  }

  Future<void> exportArchive(String path) => _run((worker, _) async {
    _status('Экспорт медиатеки…');
    await music.exportArchive(path, check: worker.check);
    return 'Медиатека экспортирована: $path';
  });

  Future<void> importArchive(
    String path, {
    Future<String?> Function(String, List<String>)? chooseArtist,
  }) {
    if (state.busy) return Future.value();
    _chooseArtist = chooseArtist;
    _artistChoices.clear();
    return _run((worker, _) async {
      _status('Проверка и импорт архива…');
      await music.importArchive(
        path,
        check: worker.check,
        resolveArtist: _artist,
      );
      return 'Медиатека импортирована. Плейлисты добавлены.';
    });
  }

  Future<List<String>> _arguments(ImportProvider provider) async {
    final args = [
      if (provider == ImportProvider.soundcloud) ...['--impersonate', 'chrome'],
      '--ignore-config',
      '--no-plugin-dirs',
      '--no-remote-components',
      '--no-warnings',
      '--no-progress',
      if (provider == ImportProvider.soundcloud) ...[
        '--cache-dir',
        p.join(music.repository.directory.parent.path, 'ImportCache'),
      ] else
        '--no-cache-dir',
      '--socket-timeout',
      '30',
      '--retries',
      '2',
      '--fragment-retries',
      '2',
      '--encoding',
      'utf-8',
    ];
    var runtimeFound = false;
    for (final name in ['deno', 'node']) {
      try {
        args.addAll(['--js-runtimes', '$name:${await toolFinder(name)}']);
        runtimeFound = true;
      } catch (_) {
        /* Другой runtime может быть установлен. */
      }
    }
    if ((provider == ImportProvider.youtube ||
            provider == ImportProvider.spotify) &&
        !runtimeFound) {
      throw StateError(
        'Для YouTube нужен JavaScript runtime. Скачайте Deno в окне импорта.',
      );
    }
    return args;
  }

  Future<Map<String, dynamic>> _metadata(
    String link,
    MusicProcess worker,
    Directory root,
    String tool,
    List<String> args, {
    bool flat = false,
    int limit = 500,
  }) async {
    final text = await worker.run(
      tool,
      [
        ...args,
        // Не даём недоступному служебному JS занять весь срок метаданных.
        '--socket-timeout',
        '5',
        '--retries',
        '0',
        if (flat) ...[
          '--flat-playlist',
          if (limit > 0) ...['--playlist-end', '$limit'],
        ] else
          '--no-playlist',
        '--dump-single-json',
        '--skip-download',
        '--',
        link,
      ],
      root,
      capture: true,
      timeout: const Duration(minutes: 2),
    );
    try {
      return jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {
      throw const FormatException(
        'Сервис вернул неподдерживаемые данные. Обновите yt-dlp.',
      );
    }
  }

  double _duration(Map<String, dynamic> row) {
    final duration = (row['duration'] as num?)?.toDouble();
    if (row['is_live'] == true ||
        duration == null ||
        !duration.isFinite ||
        duration <= 0 ||
        duration > 86400) {
      throw const FormatException(
        'Поддерживаются завершённые записи до 24 часов',
      );
    }
    return duration;
  }

  Future<String> _download(
    Map<String, dynamic> metadata,
    MusicProcess worker,
    Directory root,
    String tool,
    List<String> args, {
    bool soundcloud = false,
  }) async {
    // Используем уже полученные форматы: повторный запрос может истечь/зависнуть.
    final info = File(p.join(root.path, 'source.info.json'));
    await info.writeAsString(jsonEncode(metadata));
    worker.check();
    await worker.run(tool, [
      ...args,
      '--load-info-json',
      info.path,
      '--no-playlist',
      '--downloader',
      'native',
      '--fixup',
      'never',
      '--max-filesize',
      '2G',
      '-f',
      soundcloud
          ? 'bestaudio[format_id!*=preview]'
          : 'bestaudio[ext=m4a]/bestaudio',
      '-o',
      'source.%(ext)s',
    ], root);
    final files = await root
        .list()
        .where(
          (entry) =>
              entry is File &&
              p.basenameWithoutExtension(entry.path) == 'source' &&
              [
                '.m4a',
                '.mp3',
                '.webm',
                '.opus',
                '.mp4',
                '.ogg',
                '.wav',
                '.flac',
                '.aac',
                '.aiff',
              ].contains(p.extension(entry.path)),
        )
        .toList();
    if (files.length != 1) throw StateError('Полный аудиофайл не получен');
    return files.single.path;
  }

  Future<String> _render(
    String input,
    AudioSection section,
    Directory root,
    MusicProcess worker,
    String ffmpeg,
    int index, {
    bool remote = false,
  }) async {
    final path = p.join(root.path, 'part$index.m4a');
    await worker.run(
      ffmpeg,
      [
        '-nostdin',
        '-v',
        'error',
        '-n',
        '-protocol_whitelist',
        remote ? 'https,tls,tcp,crypto' : 'file,crypto',
        if (remote) ...[
          '-tls_verify',
          '1',
          '-rw_timeout',
          '30000000',
          if (!Platform.isWindows &&
              await File('/etc/ssl/cert.pem').exists()) ...[
            '-ca_file',
            '/etc/ssl/cert.pem',
          ],
        ],
        if (!remote) ...['-ss', '${section.start}'],
        '-i',
        input,
        '-t',
        '${section.end - section.start}',
        '-map',
        '0:a:0',
        '-vn',
        '-map_metadata',
        '-1',
        '-map_chapters',
        '-1',
        '-c:a',
        'aac',
        '-b:a',
        '192k',
        '-metadata',
        'title=${section.title}',
        '-fflags',
        '+bitexact',
        '-flags:a',
        '+bitexact',
        '-fs',
        remote ? '268435456' : '2147483648',
        path,
      ],
      root,
      timeout: remote ? const Duration(minutes: 3) : const Duration(hours: 1),
    );
    if (await File(path).length() >=
        (remote ? 268435456 : 2147483648) - 65536) {
      throw StateError('Аудио превышает лимит размера');
    }
    return path;
  }

  Future<MusicTrack> _prepared(
    String path,
    AudioSection section,
    String sourceID, {
    List<String> artists = const [],
  }) async {
    final track = await music.repository.prepareFile(
      path,
      title: section.title,
      sourceID: sourceID,
      artists: await _artists(artists),
    );
    if ((track.duration - (section.end - section.start)).abs() >
        max(0.5, (section.end - section.start) * 0.02)) {
      await music.repository.discard([track]);
      throw StateError('Получен неполный фрагмент. Исходная запись сохранена.');
    }
    return track;
  }

  Future<void> split(MusicTrack track, String playlistID, String text) => _run((
    worker,
    root,
  ) async {
    final sections = AudioSection.parse(text, track.duration);
    final ffmpeg = await toolFinder('ffmpeg');
    final prepared = <MusicTrack>[];
    try {
      for (var i = 0; i < sections.length; i++) {
        worker.check();
        _status('Нарезка: ${i + 1} из ${sections.length}');
        final output = await _render(
          music.repository.pathFor(track),
          sections[i],
          root,
          worker,
          ffmpeg,
          i,
        );
        prepared.add(
          await _prepared(
            output,
            sections[i],
            'split:${track.id}:${sections[i].start}:${sections[i].end}',
            artists: track.artists,
          ),
        );
      }
      worker.check();
      await music.accept(prepared, playlistID: playlistID, replacing: track.id);
      return 'Нарезка сохранена: ${sections.length} треков';
    } finally {
      await music.repository.discard(prepared);
    }
  });

  Future<String?> Function(String, List<String>)? _chooseArtist;
  final _artistChoices = <String, String>{};
  Future<List<String>> _artists(List<String> names) async =>
      cleanArtistNames([for (final name in names) await _artist(name)]);

  Future<String> _artist(String name) async {
    final clean = name.trim();
    if (clean.isEmpty) return '';
    if (_artistChoices.containsKey(clean)) return _artistChoices[clean]!;
    final saved = {
      ...music.repository.library.artists,
      ..._artistChoices.values,
    };
    if (saved.contains(clean)) return _artistChoices[clean] = clean;
    final matches = saved
        .where((a) => a.toLowerCase() == clean.toLowerCase())
        .toList();
    if (matches.isEmpty) return _artistChoices[clean] = clean;
    if (_chooseArtist == null) {
      throw StateError('Выберите исполнителя для «$clean» в окне импорта');
    }
    final choice = await _chooseArtist!(clean, matches);
    _worker?.check();
    if (choice == null) throw ImportCancelled();
    if (choice != clean && !matches.contains(choice)) {
      throw StateError('Неизвестный исполнитель');
    }
    return _artistChoices[clean] = choice;
  }

  Future<void> remote(
    ImportProvider provider,
    String text, {
    int limit = 500,
    Future<String?> Function(String, List<String>)? chooseArtist,
  }) {
    if (state.busy) return Future.value();
    if (limit < 0 || limit > 100000) {
      emit(const ImportState(error: 'Лимит должен быть от 0 до 100000'));
      return Future.value();
    }
    _chooseArtist = chooseArtist;
    _artistChoices.clear();
    final destination = music.repository.library.selectedID;
    return _run((worker, root) async {
      await music.configure(importLimit: limit);
      if (provider == ImportProvider.vk) {
        try {
          final link = MusicLink.parse(provider, text);
          final ffmpeg = await toolFinder('ffmpeg');
          return await _vk(link, destination, worker, root, ffmpeg, limit);
        } finally {
          vk.release();
        }
      }
      final link = MusicLink.parse(provider, text);
      final ffmpeg = await toolFinder('ffmpeg');
      final tool = await toolFinder('yt-dlp');
      final args = await _arguments(provider);
      if (provider == ImportProvider.spotify) {
        return _spotify(
          link,
          destination,
          worker,
          root,
          tool,
          args,
          ffmpeg,
          limit,
        );
      }
      _status('Получаем список и разметку…');
      final metadata = await _metadata(
        link.url,
        worker,
        root,
        tool,
        args,
        flat: link.playlist,
        limit: limit,
      );
      if (provider == ImportProvider.youtube && !link.playlist) {
        if (metadata['id'] != link.id) {
          throw StateError('YouTube вернул другую запись');
        }
        final duration = _duration(metadata);
        final title = metadata['title'] as String;
        var sections = <AudioSection>[];
        var warning = '';
        try {
          final chapters = metadata['chapters'] as List<dynamic>?;
          sections = chapters != null && chapters.isNotEmpty
              ? AudioSection.fromMarks(
                  chapters.map((r) {
                    final row = r as Map<String, dynamic>;
                    return (
                      (row['start_time'] as num).toDouble(),
                      row['title'] as String? ?? 'Трек',
                    );
                  }).toList(),
                  duration,
                )
              : AudioSection.parse(
                  metadata['description'] as String? ?? '',
                  duration,
                  strict: false,
                );
        } catch (_) {
          warning = 'Разметка некорректна. Запись сохранена целиком.';
        }
        if (sections.isEmpty) {
          sections = [AudioSection(0, duration, title)];
          if (warning.isEmpty) {
            warning = 'Разметки нет. Запись можно разделить вручную.';
          }
        }
        if (limit > 0) sections = sections.take(limit).toList();
        _status('Загружаем аудио YouTube…');
        final input = await _download(metadata, worker, root, tool, args);
        final prepared = <MusicTrack>[];
        try {
          for (var i = 0; i < sections.length; i++) {
            worker.check();
            _status('Подготовка: ${i + 1} из ${sections.length}');
            final section = sections[i];
            final sourceID =
                'youtube:${link.id}:${section.start}:${section.end}';
            final existing = music.repository.library.tracks
                .where((t) => t.sourceID == sourceID)
                .firstOrNull;
            prepared.add(
              existing ??
                  await _prepared(
                    await _render(input, section, root, worker, ffmpeg, i),
                    section,
                    sourceID,
                    artists: metadataArtistNames(metadata),
                  ),
            );
          }
          worker.check();
          await music.accept(
            prepared,
            newPlaylistName: title.trim().substring(
              0,
              min(80, title.trim().length),
            ),
          );
        } finally {
          await music.repository.discard(prepared);
        }
        return 'Плейлист создан: ${sections.length} треков. $warning';
      }
      final entries = link.playlist
          ? metadata['entries'] as List<dynamic>?
          : [metadata];
      if (entries == null || entries.isEmpty) {
        throw StateError('Плейлист пуст или недоступен');
      }
      return _onlineEntries(
        link,
        limit == 0 ? entries : entries.take(limit).toList(),
        metadata['title'] as String? ?? provider.name,
        destination,
        worker,
        root,
        tool,
        args,
        ffmpeg,
      );
    });
  }

  Future<String> _onlineEntries(
    MusicLink link,
    List<dynamic> entries,
    String name,
    String? destination,
    MusicProcess worker,
    Directory root,
    String tool,
    List<String> args,
    String ffmpeg,
  ) async {
    String? playlistID = link.playlist ? null : destination;
    final label = link.provider == ImportProvider.youtube
        ? 'YouTube'
        : link.provider == ImportProvider.spotify
        ? 'Spotify'
        : 'SoundCloud';
    var added = 0, skipped = 0;
    Object? lastError;
    for (var i = 0; i < entries.length; i++) {
      worker.check();
      _status('$label: ${i + 1} из ${entries.length}');
      final row = entries[i];
      final youtube = link.provider != ImportProvider.soundcloud;
      if (row is! Map<String, dynamic> ||
          !(youtube ? RegExp(r'^[A-Za-z0-9_-]{11}$') : RegExp(r'^\d+$'))
              .hasMatch('${row['id']}')) {
        skipped++;
        continue;
      }
      final id = '${row['id']}';
      final sourceID = row['spotifyID'] is String
          ? 'spotify:${row['spotifyID']}'
          : '${youtube ? 'youtube' : 'soundcloud'}:$id';
      MusicTrack? prepared;
      final folder = await root.createTemp('track-');
      try {
        prepared = music.repository.library.tracks
            .where((t) => t.sourceID == sourceID)
            .firstOrNull;
        if (prepared == null) {
          final url = youtube
              ? 'https://www.youtube.com/watch?v=$id'
              : 'https://api.soundcloud.com/tracks/$id';
          final track = link.playlist || link.provider == ImportProvider.spotify
              ? await _metadata(url, worker, folder, tool, args)
              : row;
          if ('${track['id']}' != id) {
            throw StateError('$label вернул другой трек');
          }
          final duration = _duration(track);
          if (row['spotifyDuration'] case final num expected) {
            if ((expected - duration).abs() > max(8, expected * 0.05)) {
              throw StateError('Длительность найденной записи не совпадает');
            }
          }
          final details = trackDetails(track);
          final section = AudioSection(
            0,
            duration,
            row['spotifyTitle'] as String? ?? details.title,
          );
          final input = await _download(
            track,
            worker,
            folder,
            tool,
            args,
            soundcloud: !youtube,
          );
          prepared = await _prepared(
            await _render(input, section, folder, worker, ffmpeg, 0),
            section,
            sourceID,
            artists: row['spotifyArtists'] is List
                ? (row['spotifyArtists'] as List).cast<String>()
                : details.artists,
          );
        }
      } on ImportCancelled {
        rethrow;
      } catch (error) {
        worker.check();
        lastError = error;
        skipped++;
        continue;
      } finally {
        await folder.delete(recursive: true);
      }
      try {
        worker.check();
        await music.accept(
          [prepared],
          playlistID: playlistID,
          newPlaylistName: name.trim().isEmpty
              ? label
              : name.trim().substring(0, min(80, name.trim().length)),
        );
        playlistID ??= music.repository.library.selectedID;
        added++;
      } finally {
        await music.repository.discard([prepared]);
      }
    }
    if (added == 0) {
      throw lastError ?? StateError('$label не вернул доступные полные записи');
    }
    return '$label: добавлено $added, пропущено $skipped.';
  }

  Future<String> _spotify(
    MusicLink link,
    String? destination,
    MusicProcess worker,
    Directory root,
    String tool,
    List<String> args,
    String ffmpeg,
    int limit,
  ) async {
    _status('Получаем названия и исполнителей Spotify…');
    final file = File(p.join(root.path, 'tracks.spotdl'));
    await worker.run(
      await toolFinder('spotdl'),
      [
        'save',
        link.url,
        '--save-file',
        file.path,
        '--threads',
        '1',
        '--headless',
        '--lyrics',
        '--ffmpeg',
        ffmpeg,
      ],
      root,
      timeout: const Duration(minutes: 15),
    );
    if (await file.length() > 16 * 1024 * 1024) {
      throw StateError('Список Spotify превышает 16 МиБ');
    }
    final data = jsonDecode(await file.readAsString());
    if (data is! List || data.isEmpty) {
      throw StateError('Spotify не вернул список треков');
    }
    final songs = limit == 0 ? data : data.take(limit).toList();
    var added = 0, skipped = 0;
    Object? lastError;
    String? playlistID = link.playlist ? null : destination;
    for (var i = 0; i < songs.length; i++) {
      worker.check();
      _status('Spotify: поиск ${i + 1} из ${songs.length} на YouTube…');
      final song = songs[i];
      if (song is! Map<String, dynamic> ||
          song['name'] is! String ||
          song['artist'] is! String ||
          song['song_id'] is! String) {
        skipped++;
        continue;
      }
      final existing = music.repository.library.tracks
          .where((t) => t.sourceID == 'spotify:${song['song_id']}')
          .firstOrNull;
      if (existing != null) {
        await music.accept(
          [existing],
          playlistID: playlistID,
          newPlaylistName: song['list_name'] as String? ?? 'Spotify',
        );
        playlistID ??= music.repository.library.selectedID;
        added++;
        continue;
      }
      try {
        final search = await _metadata(
          'ytsearch5:${metadataArtistNames(song).join(' ')} ${song['name']}',
          worker,
          root,
          tool,
          args,
          flat: true,
          limit: 5,
        );
        final candidates = (search['entries'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>();
        final match = candidates
            .where((row) => spotifyMatch(song, row))
            .firstOrNull;
        if (match == null) {
          skipped++;
          continue;
        }
        await _onlineEntries(
          MusicLink(
            provider: ImportProvider.spotify,
            url: link.url,
            id: link.id,
          ),
          [
            {
              ...match,
              'spotifyID': song['song_id'],
              'spotifyTitle': song['name'],
              'spotifyArtists': metadataArtistNames(song),
              'spotifyDuration': song['duration'],
            },
          ],
          song['list_name'] as String? ?? 'Spotify',
          playlistID,
          worker,
          root,
          tool,
          args,
          ffmpeg,
        );
        playlistID ??= music.repository.library.selectedID;
        added++;
      } on ImportCancelled {
        rethrow;
      } catch (error) {
        worker.check();
        lastError = error;
        skipped++;
      }
    }
    if (added == 0) {
      throw lastError ??
          StateError(
            'Подходящие записи YouTube не найдены. Проверьте доступ Spotify и YouTube.',
          );
    }
    return 'Spotify: добавлено $added, не найдено или недоступно $skipped.';
  }

  Future<String> _vk(
    MusicLink link,
    String? destination,
    MusicProcess worker,
    Directory root,
    String ffmpeg,
    int limit,
  ) async {
    _status('Проверяем вход и получаем список VK…');
    final catalog = await vk.catalog(link, worker, limit: limit);
    final rows = catalog['tracks'] as List<dynamic>;
    final tracks = limit == 0 ? rows : rows.take(limit).toList();
    String? playlistID = link.playlist ? null : destination;
    var added = 0, skipped = 0;
    for (var i = 0; i < tracks.length; i++) {
      worker.check();
      _status('VK: ${i + 1} из ${tracks.length}');
      final row = tracks[i] as Map<String, dynamic>;
      final owner = '${row['ownerID']}', id = '${row['id']}';
      if (!RegExp(r'^-?\d+$').hasMatch(owner) ||
          !RegExp(r'^\d+$').hasMatch(id)) {
        skipped++;
        continue;
      }
      final sourceID = 'vk:${owner}_$id';
      MusicTrack? prepared;
      final folder = await root.createTemp('vk-');
      try {
        prepared = music.repository.library.tracks
            .where((t) => t.sourceID == sourceID)
            .firstOrNull;
        if (prepared == null) {
          await Future<void>.delayed(const Duration(milliseconds: 1500));
          worker.check();
          final resolved = await vk.resolve(row, worker);
          final uri = Uri.tryParse(resolved['url'] as String? ?? '');
          if (uri == null ||
              uri.scheme != 'https' ||
              uri.host.isEmpty ||
              uri.userInfo.isNotEmpty) {
            throw StateError('Аудио VK недоступно');
          }
          final title = row['title'] as String? ?? '';
          final duration = (row['duration'] as num).toDouble();
          if (!duration.isFinite || duration <= 0 || duration > 86400) {
            throw StateError('Неизвестная длительность VK');
          }
          final section = AudioSection(
            0,
            duration,
            title.isEmpty ? 'Трек VK' : title,
          );
          final output = await _render(
            uri.toString(),
            section,
            folder,
            worker,
            ffmpeg,
            0,
            remote: true,
          );
          prepared = await _prepared(
            output,
            section,
            sourceID,
            artists: metadataArtistNames(row),
          );
        }
      } on ImportCancelled {
        rethrow;
      } catch (_) {
        worker.check();
        skipped++;
        continue;
      } finally {
        await folder.delete(recursive: true);
      }
      try {
        worker.check();
        await music.accept(
          [prepared],
          playlistID: playlistID,
          newPlaylistName: (catalog['name'] as String? ?? 'VK')
              .trim()
              .substring(
                0,
                min(80, (catalog['name'] as String? ?? 'VK').trim().length),
              ),
        );
        playlistID ??= music.repository.library.selectedID;
        added++;
      } finally {
        await music.repository.discard([prepared]);
      }
    }
    return 'VK: добавлено $added, пропущено $skipped.';
  }

  @override
  Future<void> close() async {
    await cancel();
    await _task;
    vk.dispose();
    return super.close();
  }
}
