import 'dart:async';
import 'dart:math';

import '../../../core/audio.dart';

class AtmosphereAudio {
  AtmosphereAudio({this.factory = DesktopAudio.new, this.clock = DateTime.now});
  final AudioFactory factory;
  final DateTime Function() clock;
  final Map<String, _AtmospherePlayer> _players = {};
  final Map<String, double> _gains = {};
  final Map<String, DateTime> _due = {};
  final Map<String, int> _last = {};
  final Random _random = Random();
  Map<String, double> _targets = {};
  Timer? _timer;
  bool _ticking = false;
  int _generation = 0;
  void Function(String)? onError;
  _AtmospherePlayer _create() => _AtmospherePlayer(() {
    final player = factory();
    player.errors.listen((message) => onError?.call(message));
    return player;
  }, (message) => onError?.call(message));

  bool _event(String id) => id == 'birds' || id == 'seagulls';

  Future<void> update(Map<String, double> volumes) async {
    final generation = ++_generation;
    // Подготавливаем новые слои до изменения звучащего микса.
    final loaded = <String, _AtmospherePlayer>{};
    try {
      for (final id in volumes.keys.where(
        (id) => !_event(id) && !_players.containsKey(id),
      )) {
        final player = _create();
        loaded[id] = player;
        await player.load('atmosphere/$id.wav', asset: true, loop: true);
        if (generation != _generation) return;
        await player.setVolume(0);
        if (generation != _generation) return;
      }
      for (final player in loaded.values) {
        await player.play();
        if (generation != _generation) return;
      }
      _players.addAll(loaded);
      loaded.clear();
    } finally {
      // До передачи в _players ресурс принадлежит этой загрузке, даже если
      // stop() или другой update() успели отменить её во время await.
      for (final player in loaded.values) {
        await player.dispose();
      }
    }
    for (final id in volumes.keys.where(_event)) {
      if (!_targets.containsKey(id)) {
        _due[id] = clock().add(
          Duration(milliseconds: 500 + _random.nextInt(1500)),
        );
      }
    }
    _due.removeWhere((id, _) => !volumes.containsKey(id));
    _targets = Map.of(volumes);
    _timer ??= Timer.periodic(
      const Duration(milliseconds: 250),
      (_) => _tick(),
    );
    final starts = Map<String, double>.of(_gains);
    final steps = _players.keys.any((id) => !volumes.containsKey(id)) ? 40 : 10;
    for (var step = 1; step <= steps; step++) {
      if (generation != _generation) return;
      for (final entry in _players.entries.toList()) {
        final target = volumes[entry.key] ?? 0;
        final gain =
            (starts[entry.key] ?? 0) +
            (target - (starts[entry.key] ?? 0)) * step / steps;
        await entry.value.setVolume(gain);
        if (identical(_players[entry.key], entry.value)) {
          _gains[entry.key] = gain;
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    for (final id
        in _players.keys.where((id) => !volumes.containsKey(id)).toList()) {
      await _players.remove(id)!.dispose();
      _gains.remove(id);
    }
    if (_targets.isEmpty) {
      _timer?.cancel();
      _timer = null;
    }
  }

  Future<void> _tick() async {
    if (_ticking) return;
    _ticking = true;
    final generation = _generation;
    try {
      for (final id in _due.keys.toList()) {
        final completed = _players[id];
        if (completed != null && completed.completed) {
          _players.remove(id);
          _gains.remove(id);
          await completed.dispose();
        }
        if (!_targets.containsKey(id) || clock().isBefore(_due[id]!)) {
          continue;
        }
        final variants = [0, 1, 2]..remove(_last[id]);
        final variant = variants[_random.nextInt(variants.length)];
        final player = _create();
        try {
          final duration = await player.load(
            'atmosphere/$id-$variant.wav',
            asset: true,
          );
          if (generation != _generation || !_targets.containsKey(id)) {
            await player.dispose();
            continue;
          }
          await _players.remove(id)?.dispose();
          if (generation != _generation || !_targets.containsKey(id)) {
            await player.dispose();
            continue;
          }
          _players[id] = player;
          await player.setVolume(_targets[id]!);
          if (generation != _generation || !identical(_players[id], player)) {
            // stop()/update() уже приняли владение опубликованным плеером.
            continue;
          }
          await player.play();
          if (generation != _generation || !identical(_players[id], player)) {
            continue;
          }
          _gains[id] = _targets[id]!;
          _last[id] = variant;
          _due[id] = clock().add(
            duration + Duration(seconds: 12 + _random.nextInt(25)),
          );
        } catch (_) {
          await player.dispose();
          if (identical(_players[id], player)) {
            _players.remove(id);
            _gains.remove(id);
          }
          if (generation != _generation || !_targets.containsKey(id)) continue;
          _due[id] = clock().add(const Duration(seconds: 20));
          onError?.call('Не удалось воспроизвести фоновый звук $id');
        }
      }
    } finally {
      _ticking = false;
    }
  }

  Future<void> stop() async {
    _generation++;
    _timer?.cancel();
    _timer = null;
    _targets = {};
    _due.clear();
    final players = {
      for (final entry in _players.entries) entry.value: _gains[entry.key] ?? 0,
    };
    _players.clear();
    _gains.clear();
    try {
      if (players.isNotEmpty) {
        for (var step = 1; step <= 20; step++) {
          for (final entry in players.entries) {
            await entry.key.setVolume(entry.value * (1 - step / 20));
          }
          await Future<void>.delayed(const Duration(milliseconds: 40));
        }
      }
    } finally {
      for (final player in players.keys) {
        await player.dispose();
      }
    }
  }
}

// Второй плеер начинает звучать до конца записи, скрывая паузу перемотки.
class _AtmospherePlayer {
  _AtmospherePlayer(this.factory, this.onError) : _active = factory();

  final AudioFactory factory;
  final void Function(String) onError;
  AudioHandle _active;
  AudioHandle? _spare;
  final _subscriptions = <StreamSubscription<dynamic>>[];
  Duration _duration = Duration.zero;
  Future<void>? _transition;
  double _volume = 0;
  double _progress = 0;
  bool _disposed = false;
  Future<void>? _disposal;
  bool completed = false;

  Future<Duration> load(
    String path, {
    bool asset = false,
    bool loop = false,
  }) async {
    _duration = await _active.load(path, asset: asset, loop: loop);
    if (!loop) {
      _subscriptions.add(_active.completions.listen((_) => completed = true));
    } else {
      final spare = _spare = factory();
      await spare.load(path, asset: asset, loop: true);
      await spare.setVolume(0);
      for (final player in [_active, spare]) {
        _subscriptions.add(
          player.positions.listen((position) {
            if (_disposed ||
                player != _active ||
                _transition != null ||
                position < _duration - const Duration(milliseconds: 2500)) {
              return;
            }
            _transition = _crossfade()
                .catchError((Object _) {
                  onError('Не удалось плавно повторить фоновый звук');
                })
                .whenComplete(() => _transition = null);
          }),
        );
      }
    }
    return _duration;
  }

  Future<void> play() => _active.play();

  Future<void> setVolume(double value) async {
    if (_disposed) return;
    _volume = value;
    await _active.setVolume(value * cos(_progress * pi / 2));
    await _spare?.setVolume(value * sin(_progress * pi / 2));
  }

  Future<void> _crossfade() async {
    final next = _spare!;
    await next.play();
    final elapsed = Stopwatch()..start();
    while (!_disposed && _progress < 1) {
      // Равная мощность сохраняет громкость некоррелированных фоновых записей.
      _progress = min(1, elapsed.elapsedMicroseconds / 2000000);
      await setVolume(_volume);
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    if (_disposed) return;
    final previous = _active;
    _active = next;
    _spare = previous;
    _progress = 0;
    await previous.pause();
    await previous.seek(Duration.zero);
    await previous.setVolume(0);
  }

  Future<void> dispose() => _disposal ??= _dispose();

  Future<void> _dispose() async {
    _disposed = true;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _transition;
    await Future.wait([
      _active.dispose(),
      if (_spare != null) _spare!.dispose(),
    ]);
  }
}
