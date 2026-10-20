import '../../../core/storage.dart';

const _keep = Object();

enum MusicRepeat { off, track, playlist }

class MusicTrack {
  const MusicTrack({
    required this.id,
    required this.title,
    required this.filename,
    required this.duration,
    this.sourceID,
  });
  final String id;
  final String title;
  final String filename;
  final double duration;
  final String? sourceID;

  factory MusicTrack.fromJson(Map<String, dynamic> row) {
    final track = MusicTrack(
      id: row['id'] as String,
      title: row['title'] as String,
      filename: row['filename'] as String,
      duration: finiteNumber(row['duration'], min: 0.001),
      sourceID: row['sourceID'] as String?,
    );
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(track.id) ||
        !RegExp(
          '^${track.id}\\.[a-zA-Z0-9]{1,10}\$',
        ).hasMatch(track.filename)) {
      throw const FormatException('Небезопасное имя файла медиатеки');
    }
    return track;
  }
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'filename': filename,
    'duration': duration,
    if (sourceID != null) 'sourceID': sourceID,
  };
}

class MusicPlaylist {
  MusicPlaylist({
    required this.id,
    required this.name,
    List<String> trackIDs = const [],
  }) : trackIDs = List.unmodifiable(trackIDs);
  final String id;
  final String name;
  final List<String> trackIDs;
  MusicPlaylist copyWith({String? name, List<String>? trackIDs}) =>
      MusicPlaylist(
        id: id,
        name: name ?? this.name,
        trackIDs: trackIDs ?? this.trackIDs,
      );
  factory MusicPlaylist.fromJson(Map<String, dynamic> row) => MusicPlaylist(
    id: row['id'] as String,
    name: checkedName(row['name'] as String),
    trackIDs: (row['trackIDs'] as List<dynamic>).cast<String>(),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'trackIDs': trackIDs,
  };
}

class MusicLibrary {
  MusicLibrary({
    List<MusicTrack> tracks = const [],
    List<MusicPlaylist> playlists = const [],
    this.selectedID,
    this.playingID,
    this.trackID,
    this.position = 0,
    this.volume = 0.7,
    this.shuffle = false,
    this.repeatMode = MusicRepeat.off,
  }) : tracks = List.unmodifiable(tracks),
       playlists = List.unmodifiable(playlists);
  final List<MusicTrack> tracks;
  final List<MusicPlaylist> playlists;
  final String? selectedID;
  final String? playingID;
  final String? trackID;
  final double position;
  final double volume;
  final bool shuffle;
  final MusicRepeat repeatMode;

  MusicPlaylist? playlist(String? id) =>
      playlists.where((p) => p.id == id).firstOrNull;
  MusicTrack? track(String? id) => tracks.where((t) => t.id == id).firstOrNull;
  List<MusicTrack> tracksIn(String? id) {
    final byID = {for (final track in tracks) track.id: track};
    return [
      for (final id in playlist(id)?.trackIDs ?? <String>[])
        if (byID[id] != null) byID[id]!,
    ];
  }

  MusicLibrary copyWith({
    List<MusicTrack>? tracks,
    List<MusicPlaylist>? playlists,
    Object? selectedID = _keep,
    Object? playingID = _keep,
    Object? trackID = _keep,
    double? position,
    double? volume,
    bool? shuffle,
    MusicRepeat? repeatMode,
  }) => MusicLibrary(
    tracks: tracks ?? this.tracks,
    playlists: playlists ?? this.playlists,
    selectedID: identical(selectedID, _keep)
        ? this.selectedID
        : selectedID as String?,
    playingID: identical(playingID, _keep)
        ? this.playingID
        : playingID as String?,
    trackID: identical(trackID, _keep) ? this.trackID : trackID as String?,
    position: position ?? this.position,
    volume: volume ?? this.volume,
    shuffle: shuffle ?? this.shuffle,
    repeatMode: repeatMode ?? this.repeatMode,
  );

  factory MusicLibrary.fromJson(Map<String, dynamic> row) {
    if (row['version'] != 1) {
      throw const FormatException('Неизвестная версия медиатеки');
    }
    final library = MusicLibrary(
      tracks: (row['tracks'] as List<dynamic>)
          .map((r) => MusicTrack.fromJson(jsonMap(r)))
          .toList(),
      playlists: (row['playlists'] as List<dynamic>)
          .map((r) => MusicPlaylist.fromJson(jsonMap(r)))
          .toList(),
      selectedID: row['selectedID'] as String?,
      playingID: row['playingID'] as String?,
      trackID: row['trackID'] as String?,
      position: finiteNumber(row['position']),
      volume: finiteNumber(row['volume'], max: 1),
      shuffle: row['shuffle'] as bool,
      repeatMode: MusicRepeat.values.byName(row['repeatMode'] as String),
    );
    final tracks = library.tracks.map((t) => t.id).toSet();
    final playlists = library.playlists.map((p) => p.id).toSet();
    if (tracks.length != library.tracks.length ||
        playlists.length != library.playlists.length ||
        library.playlists.any(
          (p) =>
              p.trackIDs.toSet().length != p.trackIDs.length ||
              !tracks.containsAll(p.trackIDs),
        ) ||
        library.selectedID != null && !playlists.contains(library.selectedID) ||
        library.playingID != null && !playlists.contains(library.playingID) ||
        library.trackID != null &&
            !(library
                    .playlist(library.playingID)
                    ?.trackIDs
                    .contains(library.trackID) ??
                false)) {
      throw const FormatException('Нарушены связи медиатеки');
    }
    return library;
  }
  Map<String, dynamic> toJson() => {
    'version': 1,
    'tracks': tracks.map((t) => t.toJson()).toList(),
    'playlists': playlists.map((p) => p.toJson()).toList(),
    'selectedID': selectedID,
    'playingID': playingID,
    'trackID': trackID,
    'position': position,
    'volume': volume,
    'shuffle': shuffle,
    'repeatMode': repeatMode.name,
  };
}
