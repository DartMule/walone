import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:walone/features/music/data/import_tools.dart';
import 'package:walone/features/music/data/music_process.dart';

void main() {
  for (final mode in [
    'resume',
    'restart',
    'wrong-range',
    'slow',
    'idle',
    'corrupt',
    'cancel',
    'exhausted',
    'metadata-retry',
    'redirect',
    'bad-runtime',
    'replace',
    'bad-final-runtime',
    'unsafe-archive',
  ]) {
    test('Установка yt-dlp при нестабильной сети: $mode', () async {
      final root = await Directory.systemTemp.createTemp('walone-network-');
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final client = HttpClient();
      final worker = MusicProcess();
      final launcher = utf8.encode(
        mode == 'bad-runtime'
            ? '#!/bin/sh\nexit 42\n'
            : mode == 'bad-final-runtime'
            ? '#!/bin/sh\ncase "\$0" in *.pending/*) exit 0;; *) exit 42;; esac\n'
            : '#!/bin/sh\nexec /bin/cat "\$(/usr/bin/dirname "\$0")/_internal/version.link"\n',
      );
      final bundle = Archive()
        ..addFile(ArchiveFile.bytes('yt-dlp_macos', launcher)..mode = 0x1c0)
        ..addFile(ArchiveFile.string('_internal/version.txt', '2026.10.21\n'))
        ..addFile(
          ArchiveFile.string('_internal/version.link', 'version.txt')
            ..mode = 0xa1ff,
        );
      if (mode == 'unsafe-archive') {
        bundle.addFile(ArchiveFile.string('../../escape', 'must not escape'));
      }
      final payload = ZipEncoder().encode(bundle);
      final requests = <String?>[];
      final serverErrors = <Object>[];
      final half = payload.length ~/ 2;
      var metadataRequests = 0;
      var verifying = false;
      server.listen((request) async {
        try {
          if (request.uri.path.endsWith('/latest')) {
            if (mode == 'metadata-retry' && metadataRequests++ == 0) {
              request.response.statusCode = HttpStatus.serviceUnavailable;
              await request.response.close();
              return;
            }
            request.response.write(
              jsonEncode({
                'tag_name': '2026.10.21',
                'assets': [
                  {
                    'name': 'yt-dlp_macos.zip',
                    'browser_download_url': 'https://github.com/tool',
                    'digest': 'sha256:${sha256.convert(payload)}',
                    'size': payload.length,
                  },
                ],
              }),
            );
            await request.response.close();
            return;
          }
          if (mode == 'redirect' && request.uri.path == '/tool') {
            request.response.statusCode = HttpStatus.found;
            request.response.headers.set(
              HttpHeaders.locationHeader,
              'https://release-assets.githubusercontent.com/asset',
            );
            await request.response.close();
            return;
          }
          requests.add(request.headers.value(HttpHeaders.rangeHeader));
          if (mode == 'exhausted' ||
              ![
                    'slow',
                    'corrupt',
                    'metadata-retry',
                    'bad-runtime',
                    'replace',
                    'bad-final-runtime',
                    'unsafe-archive',
                  ].contains(mode) &&
                  requests.length == 1) {
            final socket = await request.response.detachSocket(
              writeHeaders: false,
            );
            socket.add(
              utf8.encode(
                'HTTP/1.1 200 OK\r\nContent-Length: ${payload.length}\r\nConnection: close\r\n\r\n',
              ),
            );
            socket.add(payload.sublist(0, half));
            await socket.flush();
            if (mode == 'idle') {
              await Future<void>.delayed(const Duration(milliseconds: 500));
            }
            if (mode == 'cancel') worker.cancel();
            await socket.close();
            return;
          }
          var offset = 0;
          if (['resume', 'wrong-range', 'idle', 'redirect'].contains(mode)) {
            offset = half;
            request.response.statusCode = HttpStatus.partialContent;
            request.response.headers.set(
              HttpHeaders.contentRangeHeader,
              'bytes ${mode == 'wrong-range' ? 0 : offset}-${payload.length - 1}/${payload.length}',
            );
          }
          request.response.contentLength = payload.length - offset;
          if (mode == 'slow') {
            for (final byte in payload) {
              request.response.add([byte]);
              await request.response.flush();
              await Future<void>.delayed(const Duration(milliseconds: 3));
            }
          } else {
            request.response.add(
              mode == 'corrupt'
                  ? [payload.first ^ 1, ...payload.skip(1)]
                  : payload.sublist(offset),
            );
          }
          await request.response.close();
        } catch (error) {
          serverErrors.add(error);
        }
      });
      try {
        final destination = Directory(p.join(root.path, 'installed'));
        final installed = File(
          p.join(destination.path, 'yt-dlp_macos', 'yt-dlp_macos'),
        );
        const previous = '#!/bin/sh\necho previous\n';
        if (['bad-runtime', 'replace', 'bad-final-runtime'].contains(mode)) {
          await installed.parent.create(recursive: true);
          await installed.writeAsString(previous);
          await Process.run('/bin/chmod', ['700', installed.path]);
        }
        final install = runZoned(
          () => HttpOverrides.runZoned(
            () => ImportTools.install('yt-dlp', worker, root, (status) {
              if (status.startsWith('Проверяем')) verifying = true;
            }, destination: destination),
            createHttpClient: (_) => _LocalClient(client, server.port),
          ),
          // Сжимаем прежний общий дедлайн, сохраняя тайм-ауты простоя.
          zoneSpecification: ZoneSpecification(
            createTimer: (self, parent, zone, duration, callback) =>
                parent.createTimer(
                  zone,
                  mode == 'idle' &&
                          !verifying &&
                          duration == const Duration(minutes: 2)
                      ? const Duration(milliseconds: 100)
                      : duration == const Duration(minutes: 10)
                      ? const Duration(milliseconds: 20)
                      : duration,
                  callback,
                ),
          ),
        );
        if (['wrong-range', 'corrupt', 'exhausted'].contains(mode)) {
          final reason = switch (mode) {
            'wrong-range' => 'неверный диапазон',
            'corrupt' => 'SHA-256',
            _ => '3 попыток',
          };
          await expectLater(
            install,
            throwsA(
              isA<StateError>().having(
                (error) => error.message,
                'причина',
                contains(reason),
              ),
            ),
          );
          expect(await destination.exists(), isFalse);
        } else if (mode == 'cancel') {
          await expectLater(install, throwsA(isA<ImportCancelled>()));
          expect(await destination.exists(), isFalse);
        } else if (mode == 'bad-runtime' || mode == 'bad-final-runtime') {
          await expectLater(install, throwsStateError);
          expect(await installed.readAsString(), previous);
          await MusicProcess.verify(installed.path, 'yt-dlp');
        } else {
          await install;
          expect(await installed.readAsBytes(), launcher);
          expect(
            await File(
              p.join(installed.parent.path, '_internal', 'version.txt'),
            ).readAsString(),
            '2026.10.21\n',
          );
          await MusicProcess.verify(installed.path, 'yt-dlp');
        }
        if ([
          'resume',
          'restart',
          'wrong-range',
          'idle',
          'redirect',
        ].contains(mode)) {
          expect(requests, [null, 'bytes=$half-']);
        }
        if (mode == 'exhausted') expect(requests.length, 3);
        if (mode == 'cancel') expect(requests, [null]);
        if (mode == 'metadata-retry') expect(metadataRequests, 2);
        if (await destination.exists()) {
          expect(
            await destination
                .list()
                .map((entry) => p.basename(entry.path))
                .toList(),
            ['yt-dlp_macos'],
          );
        }
        expect(serverErrors, isEmpty);
        expect(
          await root
              .list()
              .where((entry) => entry.path != destination.path)
              .toList(),
          isEmpty,
        );
      } finally {
        client.close(force: true);
        await server.close(force: true);
        await root.delete(recursive: true);
      }
    }, skip: !Platform.isMacOS);
  }

  test('Отмена загрузки удаляет временные файлы до установки', () async {
    final root = await Directory.systemTemp.createTemp('walone-cancel-tools-');
    try {
      final worker = MusicProcess()..cancel();
      await expectLater(
        ImportTools.install(
          'yt-dlp',
          worker,
          root,
          (_) {},
          destination: Directory(p.join(root.path, 'installed')),
        ),
        throwsA(isA<ImportCancelled>()),
      );
      expect(await root.list().toList(), isEmpty);
    } finally {
      await root.delete(recursive: true);
    }
  });

  for (final name in ['yt-dlp', 'javascript', 'ffmpeg', 'spotdl']) {
    test(
      'Загрузка и запуск $name во временной папке',
      () async {
        final root = await Directory.systemTemp.createTemp(
          'walone-tools-test-',
        );
        try {
          final destination = Directory(p.join(root.path, 'installed'));
          {
            final statuses = <String>[];
            await ImportTools.install(
              name,
              MusicProcess(),
              root,
              statuses.add,
              destination: destination,
            );
            final tool = name == 'javascript' ? 'deno' : name;
            final binary = File(
              Platform.isMacOS && tool == 'yt-dlp'
                  ? p.join(destination.path, 'yt-dlp_macos', 'yt-dlp_macos')
                  : p.join(
                      destination.path,
                      '$tool${Platform.isWindows ? '.exe' : ''}',
                    ),
            );
            expect(await binary.exists(), isTrue);
            await MusicProcess.verify(binary.path, tool);
            expect(statuses.any((s) => s.startsWith('Проверяем')), isTrue);
          }
        } finally {
          await root.delete(recursive: true);
        }
      },
      skip: !const bool.fromEnvironment('VERIFY_TOOL_DOWNLOADS'),
      timeout: const Timeout(Duration(minutes: 15)),
    );
  }
}

// Меняем только транспорт: production-код продолжает проверять HTTPS и хосты.
class _LocalClient extends Fake implements HttpClient {
  _LocalClient(this.client, this.port);
  final HttpClient client;
  final int port;

  @override
  set connectionTimeout(Duration? value) => client.connectionTimeout = value;

  @override
  Future<HttpClientRequest> getUrl(Uri uri) => client.getUrl(
    Uri(scheme: 'http', host: '127.0.0.1', port: port, path: uri.path),
  );

  @override
  void close({bool force = false}) => client.close(force: force);
}
