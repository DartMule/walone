import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:walone/core/audio.dart';
import 'package:walone/features/keyboard/domain/keyboard.dart';
import 'package:walone/features/music/data/music_process.dart';
import 'package:walone/features/music/data/music_waveform.dart';
import 'package:walone/features/music/data/vk_session.dart';
import 'package:walone/features/music/domain/import.dart';

class FakeWaveform extends MusicWaveform {
  FakeWaveform() {
    addLevels(List.filled(1000, 0.25));
  }
  int loads = 0;
  bool cancelled = false;
  @override
  Future<void> load(String path) async {
    loads++;
  }

  @override
  void cancel() {
    cancelled = true;
  }
}

class FakeAudio implements AudioHandle {
  final position = StreamController<Duration>.broadcast();
  final complete = StreamController<void>.broadcast();
  final error = StreamController<String>.broadcast();
  String? source;
  final loads = <String>[];
  bool playing = false;
  bool disposed = false;
  double volume = 0;
  @override
  Stream<Duration> get positions => position.stream;
  @override
  Stream<void> get completions => complete.stream;
  @override
  Stream<String> get errors => error.stream;
  @override
  Future<Duration> load(
    String path, {
    bool asset = false,
    bool loop = false,
  }) async {
    source = path;
    loads.add(path);
    if (!asset) {
      final value = double.tryParse(await File(path).readAsString());
      return Duration(microseconds: ((value ?? 10) * 1000000).round());
    }
    return const Duration(seconds: 10);
  }

  @override
  Future<void> play() async {
    playing = true;
  }

  @override
  Future<void> pause() async {
    playing = false;
  }

  @override
  Future<void> stop() async {
    playing = false;
  }

  @override
  Future<void> seek(Duration value) async {
    position.add(value);
  }

  @override
  Future<void> setVolume(double value) async {
    volume = value;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    await position.close();
    await complete.close();
    await error.close();
  }
}

class FakeKeyboard implements KeyboardRepository {
  bool enabled = false;
  @override
  Future<List<KeyboardPack>> loadCatalog() async => const [
    KeyboardPack(
      id: 'brown',
      title: 'Brown',
      detail: '',
      author: '',
      keyCount: 6,
    ),
    KeyboardPack(id: 'red', title: 'Red', detail: '', author: '', keyCount: 6),
  ];
  @override
  Future<KeyboardStatus> initialize() => status();
  @override
  Future<KeyboardStatus> status() async => KeyboardStatus(enabled: enabled);
  @override
  Future<void> configure(KeyboardPack pack, bool enabled, double volume) async {
    this.enabled = enabled;
  }

  @override
  Future<void> preview() async {}
  @override
  Future<void> requestPermission() async {}
  @override
  Future<void> dispose() async {}
}

class FakeProcess extends MusicProcess {
  int renders = 0;
  int? failAt;
  int? cancelAt;
  bool failDownload = false;
  final List<List<String>> calls = [];
  @override
  Future<String> run(
    String tool,
    List<String> arguments,
    Directory directory, {
    Duration timeout = const Duration(minutes: 60),
    bool capture = false,
  }) async {
    check();
    calls.add(arguments);
    if (tool == 'ffmpeg') {
      renders++;
      if (failAt == renders) throw StateError('Ошибка нарезки');
      final duration = arguments[arguments.indexOf('-t') + 1];
      await File(arguments.last).writeAsString(duration);
      if (cancelAt == renders) cancel();
      return '';
    }
    if (arguments.contains('--dump-single-json')) {
      if (arguments.last.contains('soundcloud')) {
        return jsonEncode({
          'id': '123',
          'title': 'SoundCloud test',
          'duration': 10,
        });
      }
      return jsonEncode({
        'id': 'abcdefghijk',
        'title': 'YouTube test',
        'duration': 10,
        'chapters': [
          {'start_time': 0, 'title': 'Первый'},
          {'start_time': 4, 'title': 'Второй'},
        ],
      });
    }
    if (failDownload) throw StateError('Сервис не ответил вовремя');
    // Повторное извлечение по URL может отказать после успешных метаданных.
    final infoIndex = arguments.indexOf('--load-info-json');
    if (infoIndex < 0) throw StateError('Повторный запрос к сервису');
    final info = jsonDecode(
      await File(arguments[infoIndex + 1]).readAsString(),
    );
    if (info['id'] != '123' && info['id'] != 'abcdefghijk') {
      throw StateError('Метаданные другой записи');
    }
    await File(p.join(directory.path, 'source.m4a')).writeAsString('10');
    return '';
  }
}

class FakeVkSession extends VkSession {
  FakeVkSession(super.directory);
  int releases = 0;
  @override
  void release() => releases++;
  @override
  Future<Map<String, dynamic>> catalog(
    MusicLink link,
    MusicProcess worker, {
    int limit = 500,
  }) async => {
    'name': 'VK test',
    'tracks': [
      {
        'ownerID': '1',
        'id': '2',
        'raw': <dynamic>[],
        'artist': 'Автор',
        'title': 'Трек',
        'duration': 10,
      },
    ],
  };
  @override
  Future<Map<String, dynamic>> resolve(
    Map<String, dynamic> track,
    MusicProcess worker,
  ) async => {'url': 'https://example.com/audio.m3u8'};
  @override
  Future<void> cancel() async {}
  @override
  void dispose() {}
}
