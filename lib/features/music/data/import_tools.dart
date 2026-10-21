import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../../../core/storage.dart';
import '../domain/import.dart';
import 'music_process.dart';

List<String> requiredImportTools(ImportProvider provider) => [
  'ffmpeg',
  if (provider != ImportProvider.vk) 'yt-dlp',
  if (provider == ImportProvider.youtube || provider == ImportProvider.spotify)
    'javascript',
  if (provider == ImportProvider.spotify) 'spotdl',
];

/// Инструменты хранятся отдельно от медиатеки и системных программ.
class ImportTools {
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
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30);
    final staging = await temporary.createTemp('tool-');
    final cancellation = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (worker.cancelled) client.close(force: true);
    });
    var timedOut = false;
    final deadline = Timer(const Duration(minutes: 10), () {
      timedOut = true;
      client.close(force: true);
    });
    try {
      final tool = name == 'javascript' ? 'deno' : name;
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
          'yt-dlp' => Platform.isMacOS ? 'yt-dlp_macos' : 'yt-dlp.exe',
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
      final archive = File(p.join(staging.path, 'download'));
      var received = 0, reported = 0;
      final sink = archive.openWrite();
      try {
        final (response, downloadUri) = await _get(client, url, worker);
        if (size == null && response.contentLength >= 0) {
          size = response.contentLength;
        }
        if (digest == null) {
          // Берём checksum той же версии, на которую разрешился latest.
          final checksum = await _text(client, '$downloadUri.sha256', worker);
          final match = RegExp(r'^([a-fA-F0-9]{64})(?:\s|$)')
              .firstMatch(checksum.trim());
          if (match == null) {
            throw StateError('Источник не предоставил SHA-256 для $tool');
          }
          digest = 'sha256:${match[1]!.toLowerCase()}';
        }
        await for (final bytes in response.timeout(
          const Duration(seconds: 30),
        )) {
          worker.check();
          received += bytes.length;
          if (received > 536870912 || size != null && received > size) {
            throw StateError('Превышен размер загрузки $tool');
          }
          sink.add(bytes);
          if (received - reported >= 1048576) {
            reported = received;
            final progress = size == null || size == 0
                ? '${(received / 1048576).floor()} МБ'
                : '${(received / size * 100).floor()}%';
            status('Скачиваем $tool: $progress');
          }
        }
        await sink.flush();
      } finally {
        await sink.close();
      }
      if (size != null && received != size) {
        throw StateError('Файл $tool загружен не полностью');
      }
      if ('sha256:${await sha256.bind(archive.openRead()).first}' != digest) {
        throw StateError('Проверка SHA-256 для $tool не пройдена');
      }
      worker.check();
      status('Проверяем $tool…');
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
      try {
        await MusicProcess.verify(binary.path, tool);
      } catch (_) {
        throw StateError('Сборка $tool не запускается на этом компьютере');
      }
      worker.check();
      final directory = await Directory(
        destination?.path ??
            p.join(
              (await JsonStore.applicationDirectory()).path,
              'ImportTools',
            ),
      ).create(recursive: true);
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
      if (timedOut) {
        throw StateError(
          'Загрузка заняла слишком много времени. Повторите позже.',
        );
      }
      rethrow;
    } finally {
      cancellation.cancel();
      deadline.cancel();
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

  static Future<(HttpClientResponse, Uri)> _get(
    HttpClient client,
    String url,
    MusicProcess worker,
  ) async {
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
      final request = await client
          .getUrl(uri)
          .timeout(const Duration(seconds: 30));
      request.followRedirects = false;
      request.headers.set(HttpHeaders.userAgentHeader, 'Walone');
      final response = await request.close().timeout(
        const Duration(seconds: 30),
      );
      if (response.isRedirect && response.headers.value('location') != null) {
        uri = uri.resolve(response.headers.value('location')!);
        await response.drain<void>();
        continue;
      }
      if (response.statusCode != 200) {
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
    final (response, _) = await _get(client, url, worker);
    final bytes = <int>[];
    await for (final chunk in response.timeout(const Duration(seconds: 30))) {
      worker.check();
      bytes.addAll(chunk);
      if (bytes.length > 4194304) {
        throw StateError('Слишком большой ответ сервера');
      }
    }
    return utf8.decode(bytes);
  }
}
