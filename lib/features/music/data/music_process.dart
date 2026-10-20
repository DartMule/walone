import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../core/storage.dart';

class ImportCancelled implements Exception {
  @override
  String toString() => 'Импорт отменён. Уже добавленные треки сохранены.';
}

class MusicProcess {
  Process? _process;
  bool cancelled = false;
  void check() {
    if (cancelled) throw ImportCancelled();
  }

  void cancel() {
    cancelled = true;
    _process?.kill();
  }

  static Future<String> executable(String name) async {
    final env = Platform.environment;
    final home = env[Platform.isWindows ? 'USERPROFILE' : 'HOME'] ?? '';
    final dirs = [
      p.join((await JsonStore.applicationDirectory()).path, 'ImportTools'),
      p.join(p.dirname(Platform.resolvedExecutable), 'tools'),
      '/opt/homebrew/bin',
      '/usr/local/bin',
      p.join(home, '.local', 'bin'),
      if (Platform.isWindows && env['LOCALAPPDATA'] != null)
        p.join(env['LOCALAPPDATA']!, 'Microsoft', 'WinGet', 'Links'),
      ...(env['PATH'] ?? '').split(Platform.isWindows ? ';' : ':'),
    ];
    if (name == 'node' && !Platform.isWindows) {
      final nvm = Directory(p.join(home, '.nvm/versions/node'));
      if (await nvm.exists()) {
        final versions = await nvm.list().toList();
        versions.sort((a, b) => b.path.compareTo(a.path));
        dirs.addAll(versions.map((d) => p.join(d.path, 'bin')));
      }
    }
    for (final dir in dirs.where((d) => d.isNotEmpty)) {
      final path = p.join(
        dir.replaceAll('"', ''),
        '$name${Platform.isWindows ? '.exe' : ''}',
      );
      if (await File(path).exists()) {
        try {
          await verify(path, name);
          return path;
        } catch (_) {
          // Пропускаем повреждённый или несовместимый исполняемый файл.
        }
      }
    }
    throw StateError(
      'Не найден $name. Установите его и добавьте в PATH или папку tools рядом с приложением.',
    );
  }

  static Future<void> verify(String path, String name) async {
    final process = await Process.start(path, [
      name == 'ffmpeg' ? '-version' : '--version',
    ]);
    final output = process.stdout.transform(utf8.decoder).join();
    final errors = process.stderr.drain<void>();
    final timer = Timer(
      const Duration(seconds: 15),
      () => process.kill(
        Platform.isWindows ? ProcessSignal.sigterm : ProcessSignal.sigkill,
      ),
    );
    try {
      final code = await process.exitCode;
      final version = await output;
      await errors;
      if (code != 0) throw StateError('Не удалось запустить $name');
      if (name == 'node' || name == 'deno') {
        final match = RegExp(r'^(?:deno |v)(\d+)\.(\d+)\.\d+')
            .firstMatch(version);
        final major = int.tryParse(match?[1] ?? '') ?? 0;
        final minor = int.tryParse(match?[2] ?? '') ?? 0;
        if (name == 'node'
            ? major < 22
            : major < 2 || major == 2 && minor < 3) {
          throw StateError('Нужен Deno 2.3+ или Node.js 22+');
        }
      }
    } finally {
      timer.cancel();
    }
  }

  Future<String> run(
    String tool,
    List<String> arguments,
    Directory directory, {
    Duration timeout = const Duration(minutes: 60),
    bool capture = false,
  }) async {
    check();
    final Process process;
    try {
      process = await Process.start(
        tool,
        arguments,
        workingDirectory: directory.path,
        runInShell: false,
      );
    } catch (_) {
      throw StateError('Не удалось запустить инструмент импорта');
    }
    _process = process;
    if (cancelled) process.kill();
    final output = <int>[];
    var exceeded = false;
    var timedOut = false;
    var checking = false;
    var terminated = false;
    Timer? force;
    void terminate() {
      if (terminated) return;
      terminated = true;
      process.kill();
      force = Timer(const Duration(seconds: 2), () {
        process.kill(
          Platform.isWindows ? ProcessSignal.sigterm : ProcessSignal.sigkill,
        );
      });
    }

    final watchdog = Timer.periodic(const Duration(milliseconds: 500), (
      _,
    ) async {
      if (checking) return;
      checking = true;
      try {
        var size = 0;
        await for (final entry in directory.list()) {
          if (entry is File) size += await entry.length();
        }
        if (size > 4294967296) {
          exceeded = true;
          terminate();
        }
        if (cancelled) terminate();
      } catch (_) {
        if (_process == process) {
          exceeded = true;
          terminate();
        }
      } finally {
        checking = false;
      }
    });
    final deadline = Timer(timeout, () {
      timedOut = true;
      exceeded = true;
      terminate();
    });
    final stdout = process.stdout.listen((bytes) {
      if (!capture) return;
      if (output.length + bytes.length > 16777216) {
        exceeded = true;
        terminate();
        return;
      }
      output.addAll(bytes);
    });
    // Храним ограниченный хвост только в памяти; наружу — фиксированный текст.
    var diagnostic = '';
    final stderr = process.stderr
        .transform(const Utf8Decoder(allowMalformed: true))
        .listen((text) {
          diagnostic += text.toLowerCase();
          if (diagnostic.length > 16384) {
            diagnostic = diagnostic.substring(diagnostic.length - 16384);
          }
        });
    final outputDone = stdout.asFuture<void>();
    final errorDone = stderr.asFuture<void>();
    try {
      final code = await process.exitCode;
      await outputDone;
      await errorDone;
      check();
      if (code != 0 || exceeded) {
        if (diagnostic.contains('impersonate target') &&
            diagnostic.contains('not available')) {
          throw StateError(
            'Для SoundCloud нужен yt-dlp с поддержкой Chrome: установите полную официальную сборку или пакет yt-dlp[default,curl-cffi].',
          );
        }
        if (diagnostic.contains('not a bot')) {
          throw StateError(
            'YouTube запросил проверку «не бот». Повторите позже или используйте другую сеть.',
          );
        }
        if (timedOut ||
            diagnostic.contains('timed out') ||
            diagnostic.contains('timeout')) {
          throw StateError(
            'Сервис не ответил вовремя. Проверьте сеть и повторите импорт.',
          );
        }
        throw StateError(
          'Операция не завершена. Проверьте доступ к записи, сеть, свободное место и версии yt-dlp/FFmpeg.',
        );
      }
      return utf8.decode(output);
    } finally {
      watchdog.cancel();
      deadline.cancel();
      force?.cancel();
      await stdout.cancel();
      await stderr.cancel();
      if (identical(_process, process)) _process = null;
    }
  }
}
