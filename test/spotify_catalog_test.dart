import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:walone/features/music/data/music_process.dart';
import 'package:walone/features/music/data/spotify_catalog.dart';
import 'package:walone/features/music/domain/import.dart';

const _url = 'https://open.spotify.com/playlist/6li523Zf0m6rr9j2tixnjJ';
Map<String, dynamic> _track(String id) => {
  'itemV2': {
    'data': {
      'mediaType': 'AUDIO',
      'trackDuration': {'totalMilliseconds': 229123},
    },
  },
  'itemV3': {
    'data': {
      'uri': 'spotify:track:$id',
      'identityTrait': {
        'name': 'Песня',
        'contributors': {
          'items': [
            {'name': 'Автор'},
            {'name': 'Гость'},
          ],
        },
      },
    },
  },
};

void main() {
  for (final limit in [0, 1]) {
    test(
      'Spotify читает страницы без запросов на каждый трек: лимит $limit',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final client = HttpClient();
        final offsets = <int>[];
        final paths = <String>[];
        final statuses = <String>[];
        server.listen((request) async {
          paths.add(request.uri.path);
          if (request.uri.path.startsWith('/embed/')) {
            request.response.write(
              '<script id="__NEXT_DATA__">${jsonEncode({
                'props': {
                  'pageProps': {
                    'state': {
                      'settings': {
                        'session': {'accessToken': 'anonymous-test-token'},
                      },
                    },
                  },
                },
              })}</script>',
            );
          } else if (request.uri.path.startsWith('/playlist/')) {
            request.response.write(
              '<script src="https://open.spotifycdn.com/cdn/build/web-player/web-player.test.js"></script>',
            );
          } else if (request.uri.path.endsWith('.js')) {
            request.response.write('"fetchPlaylist","query","${'a' * 64}"');
          } else {
            expect(request.method, 'POST');
            expect(
              request.headers.value(HttpHeaders.authorizationHeader),
              'Bearer anonymous-test-token',
            );
            final body = jsonDecode(await utf8.decoder.bind(request).join());
            final offset = body['variables']['offset'] as int;
            final count = body['variables']['limit'] as int;
            offsets.add(offset);
            final rows = [
              _track('1234567890123456789012'),
              {
                'itemV2': {'data': null},
                'itemV3': {'data': null},
              },
              _track('2234567890123456789012'),
              _track('3234567890123456789012'),
            ];
            request.response.write(
              jsonEncode({
                'data': {
                  'playlistV2': {
                    'name': 'Публичный список',
                    'uri': 'spotify:playlist:6li523Zf0m6rr9j2tixnjJ',
                    'content': {
                      'totalCount': 4,
                      'items': rows
                          .skip(offset)
                          .take(count.clamp(0, 2))
                          .toList(),
                    },
                  },
                },
              }),
            );
          }
          await request.response.close();
        });
        try {
          final songs = await HttpOverrides.runZoned(
            () => SpotifyCatalog.playlist(
              MusicLink.detect(_url),
              MusicProcess(),
              limit,
              statuses.add,
            ),
            createHttpClient: (_) => _LocalClient(client, server.port),
          );
          expect(songs.length, limit == 0 ? 3 : 1);
          expect(songs.first['artists'], ['Автор', 'Гость']);
          expect(songs.first['duration'], 229.123);
          expect(songs.first['list_name'], 'Публичный список');
          expect(offsets, limit == 0 ? [0, 2] : [0]);
          expect(paths.length, limit == 0 ? 5 : 4);
          expect(
            statuses.last,
            limit == 0
                ? 'Spotify: прочитано 4 из 4 позиций'
                : 'Spotify: прочитано 1 из 1 позиций',
          );
        } finally {
          client.close(force: true);
          await server.close(force: true);
        }
      },
    );
  }

  test('Отмена прерывает ожидание HTTP Spotify', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final client = HttpClient();
    final worker = MusicProcess();
    server.listen((_) => worker.cancel());
    try {
      await expectLater(
        HttpOverrides.runZoned(
          () => SpotifyCatalog.playlist(
            MusicLink.detect(_url),
            worker,
            0,
            (_) {},
          ).timeout(const Duration(seconds: 2)),
          createHttpClient: (_) => _LocalClient(client, server.port),
        ),
        throwsA(isA<ImportCancelled>()),
      );
    } finally {
      client.close(force: true);
      await server.close(force: true);
    }
  });

  test(
    'Реальный публичный плейлист: все доступные позиции',
    () async {
      final songs = await SpotifyCatalog.playlist(
        MusicLink.detect(_url),
        MusicProcess(),
        0,
        stdout.writeln,
      );
      expect(songs.length, greaterThan(1100));
      expect(songs.first['name'], 'Я и одиночество');
      expect(songs.first['artists'], contains('Три дня дождя'));
      stdout.writeln('Spotify: получено ${songs.length} доступных треков');
    },
    skip: !const bool.fromEnvironment('VERIFY_SPOTIFY_PLAYLIST'),
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

class _LocalClient extends Fake implements HttpClient {
  _LocalClient(this.client, this.port);
  final HttpClient client;
  final int port;
  @override
  set connectionTimeout(Duration? value) => client.connectionTimeout = value;
  @override
  set userAgent(String? value) => client.userAgent = value;
  @override
  Future<HttpClientRequest> openUrl(String method, Uri uri) => client.openUrl(
    method,
    Uri(scheme: 'http', host: '127.0.0.1', port: port, path: uri.path),
  );
  @override
  void close({bool force = false}) => client.close(force: force);
}
