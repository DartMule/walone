import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

abstract interface class AudioHandle {
  Stream<Duration> get positions;
  Stream<void> get completions;
  Stream<String> get errors;
  Future<Duration> load(String path, {bool asset = false, bool loop = false});
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> seek(Duration position);
  Future<void> setVolume(double volume);
  Future<void> dispose();
}

typedef AudioFactory = AudioHandle Function();

class DesktopAudio implements AudioHandle {
  DesktopAudio() : _player = AudioPlayer() {
    // Опрос позиции не должен запрашивать кадры у статичного окна.
    // 100 мс достаточно для прогресса и запуска двухсекундного кроссфейда;
    // музыкальная визуализация интерполирует позицию своим таймером.
    _player.positionUpdater = TimerPositionUpdater(
      getPosition: _player.getCurrentPosition,
      interval: const Duration(milliseconds: 100),
    );
    _subscription = _player.eventStream.listen(
      (_) {},
      onError: (Object _) => _errors.add('Ошибка декодирования аудио'),
    );
  }
  final AudioPlayer _player;
  final _errors = StreamController<String>.broadcast();
  late final StreamSubscription<dynamic> _subscription;

  @override
  Stream<Duration> get positions =>
      _player.onPositionChanged.handleError((Object _) {});
  @override
  Stream<void> get completions =>
      _player.onPlayerComplete.handleError((Object _) {});
  @override
  Stream<String> get errors => _errors.stream;

  @override
  Future<Duration> load(
    String path, {
    bool asset = false,
    bool loop = false,
  }) async {
    await _player.setReleaseMode(loop ? ReleaseMode.loop : ReleaseMode.stop);
    await _player.setSource(asset ? AssetSource(path) : DeviceFileSource(path));
    final duration = await _player.getDuration();
    if (duration == null || duration <= Duration.zero) {
      throw StateError('Файл пуст или формат аудио не поддерживается');
    }
    return duration;
  }

  @override
  Future<void> play() => _player.resume();
  @override
  Future<void> pause() => _player.pause();
  @override
  Future<void> stop() => _player.stop();
  @override
  Future<void> seek(Duration position) => _player.seek(position);
  @override
  Future<void> setVolume(double volume) =>
      _player.setVolume(volume.clamp(0, 1));
  @override
  Future<void> dispose() async {
    await _subscription.cancel();
    await _player.dispose();
    await _errors.close();
  }
}
