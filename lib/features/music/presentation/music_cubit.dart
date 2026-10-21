import 'dart:async';
import 'dart:math';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../core/audio.dart';
import '../../../core/storage.dart';
import '../data/music_repository.dart';
import '../data/music_waveform.dart';
import '../domain/music.dart';

class MusicState {
  MusicState({
    required this.library,
    this.playing = false,
    this.position = 0,
    this.loading = false,
    this.importing = false,
    this.error,
  });
  final MusicLibrary library;
  final bool playing;
  final double position;
  final bool loading;
  final bool importing;
  final String? error;
}

class MusicCubit extends Cubit<MusicState> {
  MusicCubit(this.repository, {this.waveformFactory = MusicWaveform.new})
    : super(MusicState(library: repository.library)) {
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_playing) _run(_savePosition);
    });
  }

  AudioHandle? _output;
  AudioHandle get _audio {
    if (_output case final output?) return output;
    final output = _output = repository.audioFactory();
    _subscriptions.add(
      output.positions.listen((value) {
        _position = value.inMicroseconds / Duration.microsecondsPerSecond;
        _publish();
      }, onError: _audioError),
    );
    _subscriptions.add(
      output.completions.listen(
        (_) => _run(() => _next(automatic: true)),
        onError: _audioError,
      ),
    );
    _subscriptions.add(output.errors.listen(_audioError));
    return output;
  }

  final MusicRepository repository;
  final MusicWaveform Function() waveformFactory;
  final _visualization = ValueNotifier<List<double>?>(null);
  ValueListenable<List<double>?> get visualization => _visualization;
  MusicWaveform? _waveform;
  String? _waveformPath;
  Timer? _visualizationTimer;
  final _visualizationClock = Stopwatch();
  bool _visualizationVisible = true;
  bool _trayVisualizationEnabled = false;

  void setTrayVisualizationEnabled(bool enabled) {
    if (isClosed || _trayVisualizationEnabled == enabled) return;
    _trayVisualizationEnabled = enabled;
    _syncVisualization(state);
  }

  void setVisualizationVisible(bool visible) {
    if (isClosed || _visualizationVisible == visible) return;
    _visualizationVisible = visible;
    _visualizationClock
      ..reset()
      ..start();
    _syncVisualization(state);
  }

  @override
  void onChange(Change<MusicState> change) {
    super.onChange(change);
    final next = change.nextState;
    if (next.position != state.position ||
        next.playing != state.playing ||
        next.library.trackID != state.library.trackID) {
      _visualizationClock
        ..reset()
        ..start();
    }
    _syncVisualization(next);
  }

  void _syncVisualization(MusicState next) {
    final track = next.library.track(next.library.trackID);
    final path = track == null ? null : repository.pathFor(track);
    if (path != _waveformPath) {
      _waveform?.cancel();
      _waveform = null;
      _waveformPath = path;
    }
    if ((_visualizationVisible || _trayVisualizationEnabled) &&
        next.playing &&
        path != null) {
      _waveform ??= waveformFactory()..load(path);
      _visualizationTimer ??= Timer.periodic(
        const Duration(milliseconds: 50),
        (_) => _updateVisualization(),
      );
    } else {
      _waveform?.cancel();
      _waveform = null;
      _visualizationTimer?.cancel();
      _visualizationTimer = null;
      _visualizationClock.stop();
      _visualization.value = null;
    }
  }

  void _updateVisualization() {
    final waveform = _waveform;
    _visualization.value = waveform == null || waveform.levels.isEmpty
        ? null
        : waveform.bars(
            state.position +
                (_visualizationClock.elapsedMicroseconds / 1000000).clamp(
                  0,
                  0.25,
                ),
            state.library.volume * _master,
          );
  }

  final List<StreamSubscription<dynamic>> _subscriptions = [];
  final Random _random = Random();
  Timer? _timer;
  Future<void> _tail = Future.value();
  String? _loaded;
  bool _playing = false;
  bool _intent = false;
  bool _allowed = true;
  bool _importing = false;
  double _master = 0.7;
  double get masterVolume => _master;
  double _position = 0;
  double? _pendingVolume;
  int _volumeRevision = 0;
  String? _error;
  String? _storageError;
  List<String> _remaining = [];
  List<String> _history = [];
  void Function()? onUserPlay;

  void _publish({bool loading = false}) {
    if (!isClosed) {
      emit(
        MusicState(
          library: _pendingVolume == null
              ? repository.library
              : repository.library.copyWith(volume: _pendingVolume),
          playing: _playing,
          position: _position,
          loading: loading,
          importing: _importing,
          error: _error ?? _storageError,
        ),
      );
    }
  }

  Future<void> _transaction(Future<void> Function() action) {
    final future = _tail.then((_) async {
      if (isClosed) throw StateError('Приложение закрыто');
      try {
        await action();
      } finally {
        _publish();
      }
    });
    _tail = future.catchError((Object _) {});
    return future;
  }

  Future<void> _run(Future<void> Function() action) => _transaction(() async {
    _error = null;
    try {
      await action();
    } catch (error) {
      _error = '$error';
    }
  });

  void _audioError(Object error, [StackTrace? stack]) {
    _run(() async {
      _intent = false;
      _playing = false;
      await _output?.pause();
      throw StateError('Ошибка чтения аудио: $error');
    });
  }

  Future<void> initialize() => _run(() async {
    try {
      await repository.initialize();
    } catch (error) {
      _storageError = '$error';
      rethrow;
    }
    _position = min(
      repository.library.position,
      repository.library.track(repository.library.trackID)?.duration ?? 0,
    );
  });

  Future<void> select(String id) => _run(() async {
    if (repository.library.playlist(id) != null) {
      await repository.commit(repository.library.copyWith(selectedID: id));
    }
  });
  Future<void> savePlaylist(String name, {String? id}) => _run(() async {
    if (_importing) return;
    final clean = checkedName(name);
    final library = repository.library;
    final playlist = MusicPlaylist(id: id ?? const Uuid().v4(), name: clean);
    await repository.commit(
      library.copyWith(
        playlists: id == null
            ? [...library.playlists, playlist]
            : library.playlists
                  .map((p) => p.id == id ? p.copyWith(name: clean) : p)
                  .toList(),
        selectedID: id ?? playlist.id,
      ),
    );
  });

  Future<void> deletePlaylist(String id) => _run(() async {
    if (_importing) return;
    final library = repository.library;
    if (library.playingID == id) await _reset();
    final remaining = library.playlists.where((p) => p.id != id).toList();
    await repository.commit(
      library.copyWith(
        playlists: remaining,
        selectedID: library.selectedID == id ? allMusicID : library.selectedID,
        playingID: library.playingID == id ? null : library.playingID,
        trackID: library.playingID == id ? null : library.trackID,
        position: library.playingID == id ? 0 : library.position,
      ),
    );
    _remaining = [];
    _history = [];
  });
  Future<void> removeTrack(String id, String playlistID) =>
      removeTracks({id}, playlistID: playlistID);
  Future<void> editTracks(
    Set<String> ids, {
    String? title,
    String? artist,
    List<String>? artists,
  }) => _run(() async {
    if (_importing) return;
    final library = repository.library;
    final playingArtist = library.artists.any(
      (a) => artistMusicID(a) == library.playingID,
    );
    await repository.commit(
      library.copyWith(
        playingID: playingArtist && ids.contains(library.trackID)
            ? allMusicID
            : library.playingID,
        tracks: [
          for (final track in library.tracks)
            ids.contains(track.id)
                ? track.copyWith(
                    title: title == null ? null : checkedName(title),
                    artist: artist?.trim(),
                    artists: artists,
                  )
                : track,
        ],
      ),
    );
    if (artist != null || artists != null) {
      _remaining = [];
      _history = [];
    }
  });

  Future<void> addToPlaylist(Set<String> ids, String playlistID) =>
      _run(() async {
        if (_importing) return;
        final library = repository.library;
        if (!library.isSavedPlaylist(playlistID)) return;
        final valid = library.tracks
            .where((t) => ids.contains(t.id))
            .map((t) => t.id);
        await repository.commit(
          library.copyWith(
            playlists: [
              for (final p in library.playlists)
                p.id == playlistID
                    ? p.copyWith(trackIDs: {...p.trackIDs, ...valid}.toList())
                    : p,
            ],
          ),
        );
      });

  Future<void> artistPlaylist(String artist) => _run(() async {
    if (_importing) return;
    final library = repository.library;
    final playlist = MusicPlaylist(
      id: const Uuid().v4(),
      name: checkedName(artist),
      trackIDs: library.tracks
          .where((t) => t.artists.contains(artist))
          .map((t) => t.id)
          .toList(),
    );
    await repository.commit(
      library.copyWith(
        playlists: [...library.playlists, playlist],
        selectedID: playlist.id,
      ),
    );
  });

  Future<void> removeTracks(
    Set<String> ids, {
    String? playlistID,
  }) => _run(() async {
    if (_importing) return;
    final library = repository.library;
    if (playlistID != null && !library.isSavedPlaylist(playlistID)) return;
    final stops =
        ids.contains(library.trackID) &&
        (playlistID == null || playlistID == library.playingID);
    if (stops) await _reset();
    final removed = library.tracks.where((t) => ids.contains(t.id)).toList();
    await repository.commit(
      library.copyWith(
        tracks: playlistID == null
            ? library.tracks.where((t) => !ids.contains(t.id)).toList()
            : null,
        playlists: [
          for (final p in library.playlists)
            if (playlistID == null || p.id == playlistID)
              p.copyWith(
                trackIDs: p.trackIDs.where((id) => !ids.contains(id)).toList(),
              )
            else
              p,
        ],
        trackID: stops ? null : library.trackID,
        position: stops ? 0 : library.position,
      ),
    );
    if (playlistID == null) await repository.discard(removed);
    _remaining = [];
    _history = [];
  });

  Future<void> reorder(String playlistID, int from, int to) => _run(() async {
    if (_importing) return;
    final library = repository.library;
    final playlist = library.playlist(playlistID);
    if (playlist == null ||
        from < 0 ||
        from >= playlist.trackIDs.length ||
        to < 0 ||
        to > playlist.trackIDs.length) {
      return;
    }
    final ids = [...playlist.trackIDs];
    if (to > from) to--;
    ids.insert(to, ids.removeAt(from));
    await repository.commit(
      library.copyWith(
        playlists: library.playlists
            .map((p) => p.id == playlistID ? p.copyWith(trackIDs: ids) : p)
            .toList(),
      ),
    );
    _remaining = [];
    _history = [];
  });

  void setImporting(bool value) {
    _importing = value;
    _publish();
  }

  Future<void> exportArchive(String path, {void Function()? check}) =>
      _transaction(() => repository.exportArchive(path, check: check));

  Future<void> importArchive(
    String path, {
    void Function()? check,
    Future<String> Function(String)? resolveArtist,
  }) => _transaction(
    () => repository.importArchive(
      path,
      check: check,
      resolveArtist: resolveArtist,
    ),
  );

  // Импорт готовых файлов фиксируется одной транзакцией, в том числе при нарезке.
  Future<void> accept(
    List<MusicTrack> tracks, {
    String? playlistID,
    String? newPlaylistName,
    String? replacing,
    bool repairMissingArtists = false,
  }) => _transaction(() async {
    final library = repository.library;
    final known = {for (final t in library.tracks) t.id: t};
    for (final track in tracks) {
      final previous = known[track.id];
      if (previous == null ||
          repairMissingArtists &&
              previous.sourceID != null &&
              previous.sourceID == track.sourceID &&
              previous.artists.isEmpty &&
              track.artists.isNotEmpty) {
        known[track.id] = track;
      }
    }
    final id = playlistID ?? const Uuid().v4();
    if (id == allMusicID ||
        library.artists.any((a) => artistMusicID(a) == id)) {
      await repository.commit(library.copyWith(tracks: known.values.toList()));
      return;
    }
    final existing = library.playlist(id);
    if (playlistID != null && existing == null) {
      throw StateError('Плейлист больше не существует');
    }
    final members = [...?existing?.trackIDs];
    if (replacing != null && !members.contains(replacing)) {
      throw StateError('Исходный трек больше не находится в плейлисте');
    }
    final insert = replacing == null
        ? members.length
        : members.indexOf(replacing);
    if (replacing != null) members.remove(replacing);
    final additions = tracks
        .map((t) => t.id)
        .where((id) => !members.contains(id))
        .toSet()
        .toList();
    members.insertAll(insert, additions);
    final playlist = MusicPlaylist(
      id: id,
      name: existing?.name ?? checkedName(newPlaylistName ?? 'Импорт'),
      trackIDs: members,
    );
    final stops =
        replacing != null &&
        library.playingID == id &&
        library.trackID == replacing;
    if (stops) await _reset();
    await repository.commit(
      library.copyWith(
        tracks: known.values.toList(),
        playlists: existing == null
            ? [...library.playlists, playlist]
            : library.playlists.map((p) => p.id == id ? playlist : p).toList(),
        selectedID: existing == null ? id : library.selectedID,
        trackID: stops ? null : library.trackID,
        position: stops ? 0 : library.position,
      ),
    );
    _remaining = [];
    _history = [];
    _publish();
  });

  Future<void> configure({
    int? importLimit,
    double? volume,
    bool? shuffle,
    MusicRepeat? repeatMode,
  }) {
    if (isClosed || (volume != null && !volume.isFinite)) return Future.value();
    final nextVolume = volume?.clamp(0.0, 1.0);
    final revision = nextVolume == null ? null : ++_volumeRevision;
    if (nextVolume != null) {
      _pendingVolume = nextVolume;
      _publish();
    }
    return _run(() async {
      try {
        await repository.commit(
          repository.library.copyWith(
            importLimit: importLimit,
            volume: nextVolume,
            shuffle: shuffle,
            repeatMode: repeatMode,
          ),
        );
        if (shuffle != null) {
          _remaining = [];
          _history = [];
        }
        await _output?.setVolume(repository.library.volume * _master);
      } finally {
        if (revision != null && revision == _volumeRevision) {
          _pendingVolume = null;
        }
      }
    });
  }

  Future<void> play({String? trackID, String? playlistID}) => _run(() async {
    onUserPlay?.call();
    final library = repository.library;
    if (trackID != null && playlistID != null) {
      if (!(library.playlist(playlistID)?.trackIDs.contains(trackID) ??
          false)) {
        return;
      }
      if (library.trackID != trackID || library.playingID != playlistID) {
        await _reset();
        await repository.commit(
          library.copyWith(
            playingID: playlistID,
            trackID: trackID,
            position: 0,
          ),
        );
        _remaining = [];
        _history = [];
      }
    } else if (library.trackID == null) {
      final ids = library.playlist(library.selectedID)?.trackIDs ?? [];
      if (ids.isEmpty) return;
      await repository.commit(
        library.copyWith(
          playingID: library.selectedID,
          trackID: library.shuffle
              ? ids[_random.nextInt(ids.length)]
              : ids.first,
          position: 0,
        ),
      );
      _position = 0;
    }
    _intent = true;
    await _start();
  });
  Future<void> _start() async {
    final library = repository.library;
    final track = library.track(library.trackID);
    if (!_allowed || !_intent || track == null) return;
    try {
      if (_loaded != track.id) {
        final position = _position;
        _publish(loading: true);
        await _audio.load(repository.pathFor(track));
        _loaded = track.id;
        await _output?.seek(
          Duration(
            microseconds:
                (position.clamp(0, max(0, track.duration - 0.01)) * 1000000)
                    .round(),
          ),
        );
      }
      await _output?.setVolume(library.volume * _master);
      await _audio.play();
      _playing = true;
    } catch (_) {
      _playing = false;
      _intent = false;
      _loaded = null;
      rethrow;
    }
  }

  Future<void> _savePosition() async {
    if (repository.library.trackID != null) {
      await repository.commit(repository.library.copyWith(position: _position));
    }
  }

  Future<void> pause() => _run(() async {
    _intent = false;
    await _suspend();
  });
  Future<void> _suspend() async {
    await _output?.pause();
    _playing = false;
    await _savePosition();
  }

  Future<void> environment(
    double master,
    bool allowed, {
    bool clearIntent = false,
  }) => _run(() async {
    _master = master.clamp(0, 1);
    _allowed = allowed;
    if (clearIntent) _intent = false;
    await _output?.setVolume(repository.library.volume * _master);
    if (!allowed || clearIntent) {
      await _suspend();
    } else if (_intent) {
      await _start();
    }
  });
  Future<void> seek(double seconds) => _run(() async {
    final duration =
        repository.library.track(repository.library.trackID)?.duration ?? 0;
    _position = seconds.clamp(0, duration);
    if (_loaded != null) {
      await _output?.seek(
        Duration(microseconds: (_position * 1000000).round()),
      );
    }
    await _savePosition();
  });
  Future<void> previous() => _run(() async {
    if (_position > 3) {
      _position = 0;
      if (_loaded != null) await _output?.seek(Duration.zero);
      await _savePosition();
      return;
    }
    final library = repository.library;
    final ids = library.playlist(library.playingID)?.trackIDs ?? [];
    final index = ids.indexOf(library.trackID ?? '');
    final id = library.shuffle
        ? (_history.isEmpty ? null : _history.removeLast())
        : index > 0
        ? ids[index - 1]
        : null;
    if (id == null) {
      _position = 0;
      if (_loaded != null) await _output?.seek(Duration.zero);
      await _savePosition();
    } else {
      await _switch(id);
    }
  });
  Future<void> next() => _run(() => _next());
  Future<void> _next({bool automatic = false}) async {
    final library = repository.library;
    final ids = library.playlist(library.playingID)?.trackIDs ?? [];
    final index = ids.indexOf(library.trackID ?? '');
    if (index < 0) return;
    _playing = false;
    if (automatic && library.repeatMode == MusicRepeat.track) {
      await _switch(ids[index]);
      return;
    }
    String? next;
    if (library.shuffle) {
      if (_remaining.isEmpty) {
        if (automatic &&
            _history.length >= ids.length - 1 &&
            library.repeatMode != MusicRepeat.playlist) {
          _intent = false;
          _position = 0;
          await _output?.pause();
          await _savePosition();
          return;
        }
        _remaining = ids.where((id) => id != library.trackID).toList()
          ..shuffle(_random);
        if (library.repeatMode == MusicRepeat.playlist) _history = [];
      }
      next = _remaining.isNotEmpty
          ? _remaining.removeAt(0)
          : library.repeatMode == MusicRepeat.playlist
          ? ids[index]
          : null;
    } else {
      next = index + 1 < ids.length
          ? ids[index + 1]
          : library.repeatMode == MusicRepeat.playlist
          ? ids.first
          : null;
    }
    if (next == null) {
      _intent = false;
      _position = 0;
      await _output?.pause();
      await _output?.seek(Duration.zero);
      await _savePosition();
      return;
    }
    if (library.shuffle) _history.add(ids[index]);
    await _switch(next);
  }

  Future<void> _switch(String id) async {
    final intent = _intent;
    await _reset();
    await repository.commit(
      repository.library.copyWith(trackID: id, position: 0),
    );
    _intent = intent;
    await _start();
  }

  Future<void> _reset() async {
    await _output?.stop();
    _loaded = null;
    _playing = false;
    _intent = false;
    _position = 0;
  }

  @override
  Future<void> close() async {
    _timer?.cancel();
    await _tail;
    _visualizationTimer?.cancel();
    _waveform?.cancel();
    _visualization.dispose();
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    try {
      await _savePosition();
    } catch (_) {
      /* Повреждённая медиатека остаётся нетронутой. */
    }
    await _output?.dispose();
    await repository.close();
    return super.close();
  }
}
