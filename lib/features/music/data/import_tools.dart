import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../../../core/storage.dart';
import '../domain/import.dart';
import 'music_process.dart';

List<String> requiredImportTools(
  ImportProvider provider, {
  bool spotifyPlaylist = false,
}) => [
  'ffmpeg',
  if (provider != ImportProvider.vk) 'yt-dlp',
  if (provider == ImportProvider.youtube || provider == ImportProvider.spotify)
    'javascript',
  if (provider == ImportProvider.spotify && !spotifyPlaylist) 'spotdl',
];

/// Инструменты хранятся отдельно от медиатеки и системных программ.
class ImportTools {
  static const _networkTimeout = Duration(minutes: 2);
  static Future<void> install(
    String name,
    MusicProcess worker,
    Directory temporary,
    void Function(String) status, {
    Directory? destination,
  }) async {
    if (!Platform.isMacOS && !Platform.isWindows) {
      throw UnsupportedError('Загрузка доступна на macOS и Windows');
    }
    final client = HttpClient()..connectionTimeout = _networkTimeout;
    final staging = await temporary.createTemp('tool-');
    final cancellation = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (worker.cancelled) client.close(force: true);
    });
    try {
      final tool = name == 'javascript' ? 'deno' : name;
      final runtimeBundle = Platform.isMacOS && tool == 'yt-dlp';
      final filename = '$tool${Platform.isWindows ? '.exe' : ''}';
      String url;
      String? digest;
      int? size;
      String? member;
      if (tool == 'ffmpeg' && Platform.isMacOS) {
        final arch = Platform.version.contains('arm64') ? 'arm64' : 'amd64';
        url =
            'https://ffmpeg.martin-riedl.de/redirect/latest/macos/$arch/release/ffmpeg.zip';
        member = 'ffmpeg';
      } else {
        final repo = switch (tool) {
          'yt-dlp' => 'yt-dlp/yt-dlp',
          'deno' => 'denoland/deno',
          'spotdl' => 'spotDL/spotify-downloader',
          'ffmpeg' => 'BtbN/FFmpeg-Builds',
          _ => throw ArgumentError.value(name),
        };
        final release = jsonDecode(
          await _text(
            client,
            'https://api.github.com/repos/$repo/releases/latest',
            worker,
          ),
        ) as Map<String, dynamic>;
        final arch = Platform.version.contains('arm64') ? 'aarch64' : 'x86_64';
        final assetName = switch (tool) {
          'yt-dlp' => Platform.isMacOS ? 'yt-dlp_macos.zip' : 'yt-dlp.exe',
          'spotdl' =>
            'spotdl-${(release['tag_name'] as String).replaceFirst('v', '')}-${Platform.isMacOS ? 'darwin' : 'win32.exe'}',
          'deno' =>
            'deno-$arch-${Platform.isMacOS ? 'apple-darwin' : 'pc-windows-msvc'}.zip',
          _ => 'ffmpeg-master-latest-win64-gpl.zip',
        };
        final asset = (release['assets'] as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .firstWhere(
              (item) => item['name'] == assetName,
              orElse: () =>
                  throw StateError('Нет сборки $tool для этого компьютера'),
            );
        url = asset['browser_download_url'] as String;
        digest = asset['digest'] as String?;
        if (digest == null || !digest.startsWith('sha256:')) {
          throw StateError(
            'Источник не предоставил SHA-256 для $tool. Повторите позже.',
          );
        }
        size = asset['size'] as int;
        member = switch (tool) {
          'deno' => filename,
          'ffmpeg' => 'ffmpeg-master-latest-win64-gpl/bin/ffmpeg.exe',
          _ => null,
        };
      }
      status('Скачиваем $tool…');
      final archive = File(p.join(staging.path, 'download.zip'));
      var received = 0, reported = 0;
      final progressClock = Stopwatch()..start();
      for (var attempt = 0; ; attempt++) {
        IOSink? sink;
        try {
          final (response, downloadUri) = await _get(
            client,
            url,
            worker,
            offset: received,
          );
          if (response.statusCode == HttpStatus.partialContent) {
            final range = RegExp(r'^bytes (\d+)-(\d+)/(\d+)$').firstMatch(
              response.headers.value(HttpHeaders.contentRangeHeader) ?? '',
            );
            if (range == null ||
                int.parse(range[1]!) != received ||
                int.parse(range[2]!) != int.parse(range[3]!) - 1 ||
                size != null && int.parse(range[3]!) != size ||
                response.contentLength >= 0 &&
                    response.contentLength != int.parse(range[3]!) - received) {
              throw StateError(
                'Сервер вернул неверный диапазон загрузки $tool',
              );
            }
            size ??= int.parse(range[3]!);
          } else {
            // Сервер может не поддерживать Range: начинаем заново, не склеивая файлы.
            received = 0;
            reported = 0;
            if (size == null && response.contentLength >= 0) {
              size = response.contentLength;
            }
          }
          if (digest == null) {
            // Закрепляем конкретную версию FFmpeg и её checksum для докачки.
            url = downloadUri.toString();
            final checksum = await _text(client, '$downloadUri.sha256', worker);
            final match = RegExp(r'^([a-fA-F0-9]{64})(?:\s|$)')
                .firstMatch(checksum.trim());
            if (match == null) {
              throw StateError('Источник не предоставил SHA-256 для $tool');
            }
            digest = 'sha256:${match[1]!.toLowerCase()}';
          }
          sink = archive.openWrite(
            mode: received == 0 ? FileMode.write : FileMode.append,
          );
          await for (final bytes in response.timeout(_networkTimeout)) {
            worker.check();
            received += bytes.length;
            if (received > 536870912 || size != null && received > size) {
              throw StateError('Превышен размер загрузки $tool');
            }
            sink.add(bytes);
            if (received - reported >= 1048576 ||
                progressClock.elapsed >= const Duration(seconds: 1)) {
              reported = received;
              progressClock.reset();
              final progress = size == null || size == 0
                  ? '${(received / 1048576).toStringAsFixed(1)} МБ'
                  : '${(received / size * 100).floor()}%';
              status('Скачиваем $tool: $progress');
            }
          }
          await sink.flush();
          if (size != null && received != size) {
            throw HttpException('Файл $tool загружен не полностью');
          }
          break;
        } catch (error) {
          worker.check();
          if (error is! SocketException &&
              error is! HttpException &&
              error is! TimeoutException) {
            rethrow;
          }
          if (attempt >= 2) {
            throw StateError(
              'Не удалось загрузить $tool после 3 попыток. '
              'Проверьте соединение и повторите загрузку.',
            );
          }
          status(
            'Соединение прервано. Докачиваем $tool: попытка ${attempt + 2}/3…',
          );
        } finally {
          await sink?.close();
        }
        await Future<void>.delayed(Duration(seconds: attempt + 1));
        worker.check();
      }
      if ('sha256:${await sha256.bind(archive.openRead()).first}' != digest) {
        throw StateError('Проверка SHA-256 для $tool не пройдена');
      }
      worker.check();
      status('Проверяем $tool…');
      final directory = await Directory(
        destination?.path ??
            p.join(
              (await JsonStore.applicationDirectory()).path,
              'ImportTools',
            ),
      ).create(recursive: true);
      if (runtimeBundle) {
        final runtime = Directory(p.join(staging.path, 'runtime'));
        await _unpackRuntime(archive.path, runtime.path);
        worker.check();
        await _installRuntime(runtime, directory, worker);
        return;
      }
      final binary = File(p.join(staging.path, filename));
      if (member == null) {
        await archive.rename(binary.path);
      } else {
        // Извлекаем только нужный файл в поток, не распаковывая пути из архива.
        final process = await Process.start(
          Platform.isMacOS ? '/usr/bin/unzip' : 'tar.exe',
          Platform.isMacOS
              ? ['-p', archive.path, member]
              : ['-xOf', archive.path, member],
        );
        final errors = process.stderr.drain<void>();
        final timer = Timer(const Duration(minutes: 2), () => process.kill());
        try {
          await process.stdout.pipe(binary.openWrite());
          final code = await process.exitCode;
          await errors;
          if (code != 0) throw StateError('Не удалось распаковать $tool');
        } finally {
          timer.cancel();
        }
      }
      if (Platform.isMacOS) {
        final result = await Process.run('/bin/chmod', ['700', binary.path]);
        if (result.exitCode != 0) {
          throw StateError('Не удалось подготовить $tool');
        }
      }
      worker.check();
      // Самораспаковывающимся сборкам оставляем время на первый запуск.
      await MusicProcess.verify(
        binary.path,
        tool,
        worker: worker,
        timeout: const Duration(minutes: 2),
      );
      worker.check();
      final pending = File(p.join(directory.path, '$filename.pending'));
      try {
        await binary.copy(pending.path);
        worker.check();
        await pending.rename(p.join(directory.path, filename));
      } finally {
        if (await pending.exists()) await pending.delete();
      }
    } catch (_) {
      worker.check();
      rethrow;
    } finally {
      cancellation.cancel();
      client.close(force: true);
      // Windows может ненадолго удерживать EXE после завершения проверки версии.
      for (var attempt = 0; ; attempt++) {
        try {
          await staging.delete(recursive: true);
          break;
        } on FileSystemException catch (error) {
          if (!Platform.isWindows ||
              attempt >= 19 ||
              ![5, 32].contains(error.osError?.errorCode)) {
            rethrow;
          }
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
      }
    }
  }

  // Полный runtime остаётся на диске: нет распаковки PyInstaller при каждом запуске.
  static Future<void> _unpackRuntime(String archive, String destination) =>
      Isolate.run(
        () => extractFileToDisk(archive, destination, maxSize: 536870912),
      );

  static Future<void> _installRuntime(
    Directory runtime,
    Directory directory,
    MusicProcess worker,
  ) async {
    final target = Directory(p.join(directory.path, 'yt-dlp_macos'));
    final token = p.basename(runtime.parent.path);
    final pending = Directory(p.join(directory.path, '.yt-dlp-$token.pending'));
    final backup = Directory(p.join(directory.path, '.yt-dlp-$token.previous'));
    try {
      // ditto сохраняет права и внутренние ссылки, в том числе между томами.
      await worker.run(
        '/usr/bin/ditto',
        [runtime.path, pending.path],
        runtime.parent,
        timeout: const Duration(minutes: 2),
      );
      await MusicProcess.verify(
        p.join(pending.path, 'yt-dlp_macos'),
        'yt-dlp',
        worker: worker,
        timeout: const Duration(minutes: 2),
      );
      worker.check();
      if (await target.exists()) await target.rename(backup.path);
      var published = false;
      try {
        await pending.rename(target.path);
        published = true;
        // Проверяем и конечный путь: динамические библиотеки должны находиться
        // после переноса, а macOS может впервые проверять именно этот путь.
        await MusicProcess.verify(
          p.join(target.path, 'yt-dlp_macos'),
          'yt-dlp',
          worker: worker,
          timeout: const Duration(minutes: 2),
        );
        worker.check();
      } catch (_) {
        if (published) await target.delete(recursive: true);
        if (await backup.exists()) await backup.rename(target.path);
        rethrow;
      }
      if (await backup.exists()) await backup.delete(recursive: true);
    } finally {
      if (await pending.exists()) await pending.delete(recursive: true);
    }
  }

  static Future<(HttpClientResponse, Uri)> _get(
    HttpClient client,
    String url,
    MusicProcess worker, {
    int offset = 0,
  }) async {
    var uri = Uri.parse(url);
    for (var i = 0; i < 6; i++) {
      worker.check();
      if (uri.scheme != 'https' ||
          uri.userInfo.isNotEmpty ||
          ![
            'api.github.com',
            'github.com',
            'release-assets.githubusercontent.com',
            'objects.githubusercontent.com',
            'ffmpeg.martin-riedl.de',
          ].contains(uri.host)) {
        throw StateError('Неподдерживаемый адрес загрузки');
      }
      final request = await client.getUrl(uri).timeout(_networkTimeout);
      request.followRedirects = false;
      if (offset > 0) {
        request.headers.set(HttpHeaders.rangeHeader, 'bytes=$offset-');
      }
      request.headers.set(HttpHeaders.userAgentHeader, 'Walone');
      final response = await request.close().timeout(_networkTimeout);
      if (response.isRedirect && response.headers.value('location') != null) {
        uri = uri.resolve(response.headers.value('location')!);
        await response.listen(null).cancel();
        continue;
      }
      if (response.statusCode >= 500 ||
          response.statusCode == 408 ||
          response.statusCode == 429) {
        await response.listen(null).cancel();
        throw HttpException('Сервер временно недоступен');
      }
      if (response.statusCode != HttpStatus.ok &&
          !(offset > 0 && response.statusCode == HttpStatus.partialContent)) {
        throw StateError(
          'Сервер ${uri.host} вернул HTTP ${response.statusCode}. Повторите позже.',
        );
      }
      return (response, uri);
    }
    throw StateError('Слишком много перенаправлений загрузки');
  }

  static Future<String> _text(
    HttpClient client,
    String url,
    MusicProcess worker,
  ) async {
    for (var attempt = 0; ; attempt++) {
      try {
        final (response, _) = await _get(client, url, worker);
        final bytes = <int>[];
        await for (final chunk in response.timeout(_networkTimeout)) {
          worker.check();
          bytes.addAll(chunk);
          if (bytes.length > 4194304) {
            throw StateError('Слишком большой ответ сервера');
          }
        }
        return utf8.decode(bytes);
      } catch (error) {
        worker.check();
        if (error is! SocketException &&
            error is! HttpException &&
            error is! TimeoutException) {
          rethrow;
        }
        if (attempt >= 2) {
          throw StateError(
            'Не удалось получить сведения о компоненте после 3 попыток. '
            'Проверьте соединение и повторите загрузку.',
          );
        }
        await Future<void>.delayed(Duration(seconds: attempt + 1));
      }
    }
  }
}
