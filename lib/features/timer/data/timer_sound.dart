import 'dart:async';

import '../../../core/audio.dart';
import '../presentation/timer_cubit.dart';

// Сигнал живёт только до завершения воспроизведения, в том числе при работе в трее.
class TimerSound {
  TimerSound({this.factory = DesktopAudio.new});
  final AudioFactory factory;
  AudioHandle? _audio;
  StreamSubscription<void>? _completion;
  StreamSubscription<String>? _errors;
  Future<void> _tail = Future.value();
  bool _closed = false;

  Future<void> _serial(Future<void> Function() action) {
    final operation = _tail.then((_) => action());
    _tail = operation.catchError((Object _) {});
    return operation;
  }

  Future<void> play(PomodoroPhase phase) => _serial(() async {
    if (_closed) return;
    await _release();
    final audio = _audio = factory();
    void finished() {
      unawaited(
        _serial(() async {
          if (identical(_audio, audio)) await _release();
        }).catchError((Object _) {}),
      );
    }

    _completion = audio.completions.listen((_) => finished());
    _errors = audio.errors.listen((_) => finished());
    try {
      await audio.load('timer/${phase.name}-complete.wav', asset: true);
      if (!_closed) await audio.play();
    } catch (_) {
      await _release();
      rethrow;
    }
  });

  Future<void> _release() async {
    final audio = _audio;
    _audio = null;
    await _completion?.cancel();
    await _errors?.cancel();
    _completion = null;
    _errors = null;
    await audio?.dispose();
  }

  Future<void> dispose() {
    _closed = true;
    return _serial(_release);
  }
}
