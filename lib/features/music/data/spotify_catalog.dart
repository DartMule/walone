import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../domain/import.dart';
import '../domain/music.dart';
import 'music_process.dart';

/// Читает страницы публичного плейлиста без обогащения каждого трека в spotDL.
class SpotifyCatalog {
  static Future<List<Map<String, dynamic>>> playlist(
    MusicLink link,
    MusicProcess worker,
    int limit,
    void Function(String) status,
  ) async {
    if (link.provider != ImportProvider.spotify ||
        !link.url.contains('/playlist/')) {
      throw const FormatException('Нужна ссылка на плейлист Spotify');
    }
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20)
      ..userAgent =
          'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
          'AppleWebKit/537.36 (KHTML, like Gecko) '
          'Chrome/131.0.0.0 Safari/537.36';
    final cancellation = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (worker.cancelled) client.close(force: true);
    });
    try {
      return await _playlist(
        client,
        link,
        worker,
        limit,
        status,
      ).timeout(const Duration(minutes: 2));
    } catch (_) {
      worker.check();
      rethrow;
    } finally {
      cancellation.cancel();
      client.close(force: true);
    }
  }

  static Future<List<Map<String, dynamic>>> _playlist(
    HttpClient client,
    MusicLink link,
    MusicProcess worker,
    int limit,
    void Function(String) status,
  ) async {
    status('Spotify: получаем доступ к публичному плейлисту…');
    final embed = await _request(
      client,
      Uri.https('open.spotify.com', '/embed/playlist/${link.id}'),
      worker,
    );
    final state = RegExp(
      r'<script\b[^>]*\bid="__NEXT_DATA__"[^>]*>(.*?)</script>',
      dotAll: true,
    ).firstMatch(embed)?[1];
    if (state == null) throw StateError('Spotify не вернул данные плейлиста');
    final data = jsonDecode(state) as Map<String, dynamic>;
    // Анонимный токен публичного embed используется только в памяти.
    final token =
        data['props']?['pageProps']?['state']?['settings']?['session']?['accessToken'];
    if (token is! String || token.isEmpty) {
      throw StateError('Spotify не предоставил доступ к публичному плейлисту');
    }
    final page = await _request(client, Uri.parse(link.url), worker);
    final script = RegExp(
      r'<script\b[^>]*\bsrc="(https://open\.spotifycdn\.com/cdn/build/web-player/web-player\.[A-Za-z0-9]+\.js)"',
    ).firstMatch(page)?[1];
    if (script == null) throw StateError('Изменился формат страницы Spotify');
    status('Spotify: подготавливаем чтение списка…');
    final javascript = await _request(client, Uri.parse(script), worker);
    final hash = RegExp(r'"fetchPlaylist","query","([a-f0-9]{64})"')
        .firstMatch(javascript)?[1];
    if (hash == null) throw StateError('Изменился формат плеера Spotify');

    final songs = <Map<String, dynamic>>[];
    var offset = 0;
    int? total;
    do {
      worker.check();
      final response = jsonDecode(
        await _request(
          client,
          Uri.https('api-partner.spotify.com', '/pathfinder/v1/query'),
          worker,
          token: token,
          body: {
            'operationName': 'fetchPlaylist',
            'variables': {
              'uri': 'spotify:playlist:${link.id}',
              'offset': offset,
              'limit': limit == 0 ? 343 : (limit - offset).clamp(1, 343),
              'enableWatchFeedEntrypoint': false,
            },
            'extensions': {
              'persistedQuery': {'version': 1, 'sha256Hash': hash},
            },
          },
        ),
      ) as Map<String, dynamic>;
      final playlist = response['data']?['playlistV2'];
      final content = playlist?['content'];
      final rows = content?['items'];
      final count = content?['totalCount'];
      if (playlist?['uri'] != 'spotify:playlist:${link.id}' ||
          rows is! List ||
          count is! int ||
          count < 0 ||
          count > 100000) {
        throw StateError('Spotify не вернул доступный список треков');
      }
      total ??= limit == 0 ? count : count.clamp(0, limit);
      if (rows.isEmpty && offset < total) {
        throw StateError('Spotify вернул неполный список. Повторите импорт.');
      }
      for (final row in rows.take(total - offset)) {
        final song = _song(row, playlist['name']);
        if (song != null) songs.add(song);
      }
      offset += rows.length;
      status('Spotify: прочитано ${offset.clamp(0, total)} из $total позиций');
    } while (offset < total);
    if (songs.isEmpty) throw StateError('В плейлисте нет доступных треков');
    return songs;
  }

  static Map<String, dynamic>? _song(dynamic row, dynamic playlistName) {
    if (row is! Map) return null;
    final track = row['itemV2']?['data'];
    final entity = row['itemV3']?['data'];
    final identity = entity?['identityTrait'];
    final uri = entity?['uri'];
    final title = identity?['name'];
    final duration = track?['trackDuration']?['totalMilliseconds'];
    final contributors = identity?['contributors']?['items'];
    if (track?['mediaType'] != 'AUDIO' ||
        uri is! String ||
        !RegExp(r'^spotify:track:[A-Za-z0-9]{22}$').hasMatch(uri) ||
        title is! String ||
        title.trim().isEmpty ||
        duration is! num ||
        !duration.isFinite ||
        duration <= 0 ||
        contributors is! List) {
      return null;
    }
    final artists = cleanArtistNames([
      for (final artist in contributors)
        if (artist is Map && artist['name'] is String) artist['name'] as String,
    ]);
    if (artists.isEmpty) return null;
    return {
      'song_id': uri.substring('spotify:track:'.length),
      'name': title,
      'artist': artists.first,
      'artists': artists,
      'duration': duration / 1000,
      'list_name': playlistName is String ? playlistName : 'Spotify',
    };
  }

  static Future<String> _request(
    HttpClient client,
    Uri uri,
    MusicProcess worker, {
    String? token,
    Map<String, dynamic>? body,
  }) async {
    for (var redirect = 0; redirect < 5; redirect++) {
      worker.check();
      if (uri.scheme != 'https' ||
          uri.userInfo.isNotEmpty ||
          uri.hasPort ||
          ![
            'open.spotify.com',
            'open.spotifycdn.com',
            'api-partner.spotify.com',
          ].contains(uri.host)) {
        throw StateError('Неподдерживаемый адрес Spotify');
      }
      final request = await client
          .openUrl(body == null ? 'GET' : 'POST', uri)
          .timeout(const Duration(seconds: 20));
      request.followRedirects = false;
      if (token != null) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }
      if (body != null) {
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(body));
      }
      final response = await request.close().timeout(
        const Duration(seconds: 20),
      );
      if (response.isRedirect && token == null && body == null) {
        final location = response.headers.value(HttpHeaders.locationHeader);
        await response.listen(null).cancel();
        if (location == null) throw StateError('Некорректный ответ Spotify');
        uri = uri.resolve(location);
        continue;
      }
      if (response.statusCode != HttpStatus.ok) {
        await response.listen(null).cancel();
        throw StateError(
          'Spotify вернул HTTP ${response.statusCode}. Повторите позже.',
        );
      }
      final bytes = <int>[];
      await for (final chunk in response.timeout(const Duration(seconds: 20))) {
        worker.check();
        bytes.addAll(chunk);
        if (bytes.length > 16 * 1024 * 1024) {
          throw StateError('Слишком большой ответ Spotify');
        }
      }
      return utf8.decode(bytes);
    }
    throw StateError('Слишком много перенаправлений Spotify');
  }
}
