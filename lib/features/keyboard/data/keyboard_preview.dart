import 'dart:async';

import '../../../core/audio.dart';
import '../domain/keyboard.dart';

// Отдельный плеер не меняет набор и голоса нативной глобальной клавиатуры.
class KeyboardPreview {
  KeyboardPreview({
    this.factory = DesktopAudio.new,
    this.interval = const Duration(milliseconds: 180),
    this.tail = const Duration(milliseconds: 400),
  });
  final AudioFactory factory;
  final Duration interval;
  final Duration tail;
  AudioHandle? _audio;
  StreamSubscription<String>? _errors;
  Future<void>? _queue;
  int _generation = 0;
  int _variation = 0;
  bool _closed = false;
  bool _allowed = true;
  double _master = 0.7;
  double _volume = 0.35;
  String? _pack;
  void Function(String?)? onChanged;
  void Function(String)? onError;

  Future<void> _serial(Future<void> Function() action) {
    final operation = (_queue ?? Future<void>.value()).then((_) => action());
    _queue = operation.catchError((Object _) {});
    return operation;
  }

  Future<void> play(
    KeyboardPack pack, {
    int? group,
    required double volume,
  }) async {
    if (_closed || !_allowed) return;
    if (group != null && (group < 0 || group > 3)) {
      throw ArgumentError.value(group, 'group');
    }
    final token = ++_generation;
    _volume = volume.clamp(0, 1);
    _pack = pack.id;
    onChanged?.call(pack.id);
    try {
      for (final key in group == null ? [0, 0, 0, 0, 1, 0, 2, 3] : [group]) {
        await _serial(() async {
          if (_closed || token != _generation) return;
          final audio = _audio ??= factory();
          _errors ??= audio.errors.listen((message) {
            unawaited(stop().catchError((Object _) {}));
            onError?.call(message);
          });
          await audio.stop();
          final name = switch (key) {
            0 => 'key${_variation++ % pack.keyCount}',
            1 => 'space',
            2 => 'enter',
            _ => 'backspace',
          };
          await audio.setVolume(_volume * _master);
          await audio.load('keyboards/${pack.id}/$name.wav', asset: true);
          if (_closed || token != _generation) return;
          await audio.play();
        });
        if (_closed || token != _generation) return;
        await Future<void>.delayed(interval);
      }
      await Future<void>.delayed(tail);
      if (token == _generation) await stop();
    } catch (error) {
      if (token == _generation && !_closed) {
        try {
          await stop();
        } catch (_) {
          /* Ошибка исходной операции важнее ошибки остановки. */
        }
        onError?.call('Не удалось прослушать набор: $error');
      }
    }
  }

  Future<void> stop() {
    if (_closed) return Future.value();
    ++_generation;
    _pack = null;
    onChanged?.call(null);
    if (_audio == null) return Future.value();
    return _serial(_release);
  }

  Future<void> environment(double master, bool allowed, double volume) async {
    _master = master.clamp(0, 1);
    _volume = volume.clamp(0, 1);
    _allowed = allowed;
    if (!allowed) {
      await stop();
    } else if (_pack != null) {
      await _serial(() async => _audio?.setVolume(_volume * _master));
    }
  }

  Future<void> _release() async {
    final audio = _audio;
    final errors = _errors;
    _audio = null;
    _errors = null;
    try {
      await audio?.stop();
    } finally {
      await errors?.cancel();
      await audio?.dispose();
    }
  }

  Future<void> dispose() async {
    if (_closed) return _queue;
    _closed = true;
    ++_generation;
    if (_audio == null) return;
    await _serial(_release);
  }
}
