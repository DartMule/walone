import 'dart:math';

import 'music.dart';

class AudioSection {
  const AudioSection(this.start, this.end, this.title);
  final double start;
  final double end;
  final String title;

  static double? timestamp(String value) {
    final parts = value.split(':');
    if (parts.length < 2 ||
        parts.length > 3 ||
        parts.any((p) => !RegExp(r'^\d+$').hasMatch(p))) {
      return null;
    }
    var result = double.tryParse(parts.first);
    if (result == null || !result.isFinite) return null;
    for (final part in parts.skip(1)) {
      final number = double.tryParse(part);
      if (part.length != 2 || number == null || number >= 60) return null;
      result = result! * 60 + number;
    }
    return result;
  }

  static List<AudioSection> fromMarks(
    List<(double, String)> input,
    double duration,
  ) {
    if (!duration.isFinite ||
        duration <= 0 ||
        input.isEmpty ||
        input.length > 1000) {
      throw const FormatException(
        'Разметка пуста или содержит больше 1000 границ',
      );
    }
    final marks = [...input];
    for (var i = 0; i < marks.length; i++) {
      if (!marks[i].$1.isFinite ||
          marks[i].$1 < 0 ||
          marks[i].$1 >= duration ||
          marks[i].$2.trim().isEmpty ||
          i > 0 && marks[i].$1 <= marks[i - 1].$1) {
        throw const FormatException(
          'Таймкоды должны возрастать и находиться внутри записи',
        );
      }
    }
    if (marks.first.$1 > 0) marks.insert(0, (0, 'Начало записи'));
    return [
      for (var i = 0; i < marks.length; i++)
        AudioSection(
          marks[i].$1,
          i + 1 < marks.length ? marks[i + 1].$1 : duration,
          marks[i].$2.trim().substring(0, min(250, marks[i].$2.trim().length)),
        ),
    ];
  }

  static List<AudioSection> parse(
    String text,
    double duration, {
    bool strict = true,
  }) {
    final regex = RegExp(
      r'^\s*(?:\d+[.)]\s+)?[\[(]?(\d+:\d{2}(?::\d{2})?)[\])]?\s*(?:[-–—|]\s*)?(.+?)\s*$',
    );
    final marks = <(double, String)>[];
    for (final line
        in text.split('\n').where((line) => line.trim().isNotEmpty)) {
      final match = regex.firstMatch(line);
      final time = match == null ? null : timestamp(match[1]!);
      if (match == null || time == null) {
        if (strict) {
          throw const FormatException(
            'Ожидается строка вида «0:00 Название трека»',
          );
        }
        continue;
      }
      marks.add((time, match[2]!));
    }
    if (!strict && marks.length < 2) return [];
    return fromMarks(marks, duration);
  }
}

enum ImportProvider { youtube, soundcloud, vk, spotify }

class MusicLink {
  const MusicLink({
    required this.provider,
    required this.url,
    required this.id,
    this.owner = '',
    this.accessKey = '',
    this.playlist = false,
  });
  final ImportProvider provider;
  final String url;
  final String id;
  final String owner;
  final String accessKey;
  final bool playlist;

  static MusicLink detect(String text) {
    final host = Uri.tryParse(text.trim())?.host.toLowerCase();
    final provider = switch (host) {
      'youtube.com' ||
      'www.youtube.com' ||
      'm.youtube.com' ||
      'music.youtube.com' ||
      'youtu.be' ||
      'www.youtu.be' => ImportProvider.youtube,
      'open.spotify.com' => ImportProvider.spotify,
      'soundcloud.com' ||
      'www.soundcloud.com' ||
      'm.soundcloud.com' => ImportProvider.soundcloud,
      'vk.com' ||
      'vk.ru' ||
      'm.vk.com' ||
      'm.vk.ru' ||
      'www.vk.com' ||
      'www.vk.ru' => ImportProvider.vk,
      _ => throw const FormatException(
        'Источник не поддерживается. Вставьте ссылку YouTube, SoundCloud, VK или Spotify.',
      ),
    };
    return parse(provider, text);
  }

  static MusicLink parse(ImportProvider provider, String text) {
    final uri = Uri.tryParse(text.trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        uri.hasPort ||
        uri.host.isEmpty) {
      throw const FormatException('Вставьте корректную HTTPS-ссылку');
    }
    final host = uri.host.toLowerCase();
    if (provider == ImportProvider.spotify) {
      final parts = uri.pathSegments
          .where((p) => !p.startsWith('intl-'))
          .toList();
      if (host != 'open.spotify.com' ||
          parts.length != 2 ||
          !['track', 'playlist', 'album'].contains(parts[0]) ||
          !RegExp(r'^[A-Za-z0-9]{22}$').hasMatch(parts[1])) {
        throw const FormatException(
          'Нужна ссылка на трек, альбом или плейлист Spotify',
        );
      }
      return MusicLink(
        provider: provider,
        url: 'https://open.spotify.com/${parts.join('/')}',
        id: parts[1],
        playlist: parts[0] != 'track',
      );
    }
    if (provider == ImportProvider.youtube) {
      if (![
        'youtube.com',
        'www.youtube.com',
        'm.youtube.com',
        'music.youtube.com',
        'youtu.be',
        'www.youtu.be',
      ].contains(host)) {
        throw const FormatException('Нужна ссылка YouTube');
      }
      final list = uri.queryParameters['list'];
      if (list != null &&
          (uri.path == '/playlist' ||
              uri.path == '/watch' ||
              host.endsWith('youtu.be'))) {
        if (!RegExp(r'^[A-Za-z0-9_-]{10,100}$').hasMatch(list)) {
          throw const FormatException('Некорректный ID плейлиста');
        }
        return MusicLink(
          provider: provider,
          url: 'https://www.youtube.com/playlist?list=$list',
          id: list,
          playlist: true,
        );
      }
      final parts = uri.pathSegments;
      final id = host.endsWith('youtu.be') && parts.length == 1
          ? parts.first
          : uri.path == '/watch'
          ? uri.queryParameters['v']
          : parts.length == 2 &&
                ['shorts', 'embed', 'live'].contains(parts.first)
          ? parts.last
          : null;
      if (id == null || !RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(id)) {
        throw const FormatException('Некорректный ID видео');
      }
      return MusicLink(
        provider: provider,
        url: 'https://www.youtube.com/watch?v=$id',
        id: id,
      );
    }
    if (provider == ImportProvider.soundcloud) {
      if (![
            'soundcloud.com',
            'www.soundcloud.com',
            'm.soundcloud.com',
          ].contains(host) ||
          uri.pathSegments.length < 2 ||
          uri.pathSegments.length > 3 ||
          uri.pathSegments.any(
            (s) => !RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(s),
          ) ||
          uri.pathSegments.length == 3 && uri.pathSegments[1] != 'sets') {
        throw const FormatException(
          'Нужна полная ссылка на трек или плейлист SoundCloud',
        );
      }
      return MusicLink(
        provider: provider,
        url: 'https://soundcloud.com${uri.path}',
        id: uri.path,
        playlist: uri.pathSegments.length == 3,
      );
    }
    if (![
      'vk.com',
      'vk.ru',
      'm.vk.com',
      'm.vk.ru',
      'www.vk.com',
      'www.vk.ru',
    ].contains(host)) {
      throw const FormatException('Нужна ссылка VK');
    }
    final collection = RegExp(r'^/audios(-?\d+)/?$').firstMatch(uri.path);
    if (collection != null ||
        ['/music', '/audio', '/audios'].contains(uri.path) &&
            uri.queryParameters.isEmpty) {
      final owner = collection?[1] ?? '';
      return MusicLink(
        provider: provider,
        url: owner.isEmpty
            ? 'https://m.vk.ru/audio'
            : 'https://m.vk.ru/audios$owner',
        id: 'all',
        owner: owner,
        playlist: true,
      );
    }
    var path = uri.queryParameters['z']?.startsWith('audio_playlist') == true
        ? uri.queryParameters['z']!.replaceAll('/', '_')
        : uri.path;
    if (uri.queryParameters['act']?.startsWith('audio_playlist') == true) {
      path = uri.queryParameters['act']!;
    }
    if (path.startsWith('audio_playlist') && path.split('_').length == 3) {
      final key =
          uri.queryParameters['access_hash'] ??
          uri.queryParameters['access_key'];
      if (key != null && key.isNotEmpty) path += '_$key';
    }
    final match = RegExp(
      r'^(?:/audio|/music/(playlist|album)/|/?audio_playlist)(-?\d+)_(\d+)(?:_([A-Za-z0-9]+))?/?$',
    ).firstMatch(path);
    if (match == null) {
      throw const FormatException(
        'Поддерживаются треки, альбомы и плейлисты VK',
      );
    }
    final owner = match[2]!, id = match[3]!, access = match[4] ?? '';
    final playlist = path.contains('playlist') || path.contains('/album/');
    final key = access.isEmpty ? '' : '_$access';
    return MusicLink(
      provider: provider,
      id: id,
      owner: owner,
      accessKey: access,
      playlist: playlist,
      url:
          'https://m.vk.ru/${playlist ? 'audio?act=audio_playlist$owner' : 'audio$owner'}_$id$key',
    );
  }
}

// Явные маркеры совместной записи; запятая и & могут быть частью имени.
List<String> splitArtistNames(String text) => cleanArtistNames(
  text.split(
    RegExp(r'\s+(?:feat\.?|ft\.?|featuring)\s+|[;\n]', caseSensitive: false),
  ),
);

List<String> metadataArtistNames(Map<String, dynamic> row) {
  final names = row['artists'];
  if (names is List && names.isNotEmpty) {
    return cleanArtistNames(names.cast<String>());
  }
  return splitArtistNames(
    row['artist'] as String? ?? row['creator'] as String? ?? '',
  );
}

({String title, List<String> artists}) trackDetails(Map<String, dynamic> row) {
  var title = (row['track'] as String? ?? row['title'] as String? ?? 'Трек')
      .trim();
  var artists = metadataArtistNames(row);
  if (artists.isEmpty) {
    final parts = title.split(RegExp(r'\s+[—–-]\s+'));
    if (parts.length == 2 && parts.every((s) => s.trim().isNotEmpty)) {
      artists = splitArtistNames(parts[0]);
      title = parts[1].trim();
    }
  }
  return (title: title, artists: artists);
}

bool spotifyMatch(Map<String, dynamic> song, Map<String, dynamic> candidate) {
  Set<String> words(String text) => text
      .toLowerCase()
      .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
      .trim()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toSet();
  final title = words(song['name'] as String);
  final artist = words(song['artist'] as String);
  final found = words(
    '${candidate['title'] ?? ''} ${candidate['artist'] ?? candidate['uploader'] ?? candidate['channel'] ?? ''}',
  );
  final duration = candidate['duration'];
  final expected = song['duration'];
  if (duration is! num ||
      expected is! num ||
      expected <= 0 ||
      (duration - expected).abs() >
          (expected * 0.05 > 8 ? expected * 0.05 : 8)) {
    return false;
  }
  if (title.isEmpty ||
      artist.isEmpty ||
      !found.containsAll(title) ||
      !artist.every(found.contains)) {
    return false;
  }
  for (final version in [
    'live',
    'remix',
    'cover',
    'karaoke',
    'sped',
    'slowed',
  ]) {
    if (found.contains(version) && !title.contains(version)) return false;
  }
  return true;
}

const youtubeBrowsers = {
  'chrome': 'Chrome',
  'firefox': 'Firefox',
  'safari': 'Safari',
  'edge': 'Edge',
  'brave': 'Brave',
};
