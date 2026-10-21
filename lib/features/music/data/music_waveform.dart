import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'music_process.dart';

/// Амплитуда стереозвука каждые 20 мс, без хранения декодированного трека.
class MusicWaveform {
  Float32List _levels = Float32List(0);
  int _length = 0;
  Float32List get levels => Float32List.sublistView(_levels, 0, _length);

  void addLevels(Iterable<double> values) {
    for (final value in values) {
      addLevel(value);
    }
  }

  void addLevel(double value) {
    if (_length == _levels.length) {
      _levels = Float32List(max(1024, _length * 2))..setAll(0, _levels);
    }
    _levels[_length++] = value;
  }

  void _clear() {
    _length = 0;
    _levels = Float32List(0);
  }

  Process? _process;
  bool _cancelled = false;
  static const _channel = MethodChannel('dev.soyjanks.walone/desktop');
  static int _nextID = 0;
  String? _nativeID;

  Future<void> _loadWindows(String path) async {
    final id = _nativeID = '${++_nextID}';
    try {
      await _channel.invokeMethod<void>('startWaveform', {
        'id': id,
        'path': path,
      });
      final deadline = Stopwatch()..start();
      while (!_cancelled && deadline.elapsed < const Duration(minutes: 2)) {
        final data = await _channel.invokeMapMethod<String, dynamic>(
          'readWaveform',
          id,
        );
        if (_cancelled) return;
        if (data == null || data['failed'] == true) {
          _clear();
          return;
        }
        addLevels((data['levels'] as List).cast<double>());
        if (data['done'] == true) return;
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    } finally {
      await _channel.invokeMethod<void>('stopWaveform', id);
      _nativeID = null;
    }
  }

  Future<void> load(String path) async {
    if (_cancelled) return;
    Timer? deadline;
    try {
      if (defaultTargetPlatform == TargetPlatform.windows) {
        await _loadWindows(path);
        return;
      }
      final executable = await MusicProcess.executable('ffmpeg');
      if (_cancelled) return;
      final process = await Process.start(executable, [
        '-nostdin',
        '-v',
        'error',
        '-threads',
        '1',
        '-i',
        path,
        '-t',
        '21600',
        '-vn',
        '-ac',
        '2',
        '-ar',
        '8000',
        '-f',
        'u8',
        'pipe:1',
      ]);
      _process = process;
      if (_cancelled) process.kill();
      deadline = Timer(const Duration(minutes: 2), cancel);
      final errors = process.stderr.drain<void>();
      await for (final level in amplitudes(process.stdout)) {
        if (!_cancelled) addLevel(level);
      }
      final code = await process.exitCode;
      await errors;
      if (code != 0) _clear();
    } catch (_) {
      // Отказ декодера визуализации не мешает воспроизведению музыки.
      _clear();
    } finally {
      deadline?.cancel();
      _process = null;
    }
  }

  void cancel() {
    _cancelled = true;
    _process?.kill();
    final id = _nativeID;
    if (id != null) {
      unawaited(
        _channel
            .invokeMethod<void>('stopWaveform', id)
            .catchError((Object _) {}),
      );
    }
    _clear();
  }

  static Stream<double> amplitudes(Stream<List<int>> pcm) async* {
    var count = 0;
    var energy = 0.0;
    await for (final bytes in pcm) {
      for (final byte in bytes) {
        final sample = (byte - 128) / 128;
        energy += sample * sample;
        if (++count == 320) {
          yield sqrt(energy / count);
          energy = 0;
          count = 0;
        }
      }
    }
    if (count > 0) yield sqrt(energy / count);
  }

  List<double> bars(double seconds, double volume) => List.generate(5, (bar) {
    final index = (seconds * 50).floor() - (4 - bar) * 2;
    if (index < 0 || index >= _length) return 0.0;
    return (sqrt(_levels[index] * volume.clamp(0, 1)) * 1.8).clamp(0.0, 1.0);
  });
}
