import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../core/storage.dart';

class ImportCancelled implements Exception {
  @override
  String toString() => 'Импорт отменён. Уже добавленные треки сохранены.';
}

class YoutubeAccessRequired extends StateError {
  YoutubeAccessRequired(super.message);
}

class MusicProcess {
  Process? _process;
  void Function()? _stop;
  bool cancelled = false;
  void check() {
    if (cancelled) throw ImportCancelled();
  }

  void cancel() {
    cancelled = true;
    _stop?.call();
  }

  // PyInstaller запускает дочерний процесс, который тоже держит stdout/stderr.
  static Future<void> _killTree(Process process) async {
    if (Platform.isWindows) {
      await Process.run('taskkill', ['/PID', '${process.pid}', '/T', '/F']);
      process.kill();
      return;
    }
    final descendants = <int>[];
    Future<void> collect(int pid) async {
      final result = await Process.run('/usr/bin/pgrep', ['-P', '$pid']);
      for (final line in '${result.stdout}'.trim().split('\n')) {
        final child = int.tryParse(line);
        if (child == null) continue;
        descendants.add(child);
        await collect(child);
      }
    }

    try {
      await collect(process.pid);
    } finally {
      for (final pid in descendants.reversed) {
        Process.killPid(pid, ProcessSignal.sigkill);
      }
      process.kill(ProcessSignal.sigkill);
    }
  }

  // Успешная проверка живёт в памяти до изменения файла или ручного обновления.
  static final _verifiedExecutables = <String, FileStat>{};

  static Future<String> executable(
    String name, {
    MusicProcess? worker,
    bool force = false,
  }) async {
    final env = Platform.environment;
    final home = env[Platform.isWindows ? 'USERPROFILE' : 'HOME'] ?? '';
    final managed = p.join(
      (await JsonStore.applicationDirectory()).path,
      'ImportTools',
    );
    final dirs = [
      managed,
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
    final paths = [
      if (Platform.isMacOS && name == 'yt-dlp')
        p.join(managed, 'yt-dlp_macos', 'yt-dlp_macos'),
      for (final dir in dirs.where((d) => d.isNotEmpty))
        p.join(
          dir.replaceAll('"', ''),
          '$name${Platform.isWindows ? '.exe' : ''}',
        ),
    ];
    for (final path in paths) {
      worker?.check();
      if (await File(path).exists()) {
        try {
          await verify(path, name, worker: worker, useCache: !force);
          return path;
        } on ImportCancelled {
          rethrow;
        } catch (_) {
          // Пропускаем повреждённый или несовместимый исполняемый файл.
        }
      }
    }
    throw StateError(
      'Не найден $name. Установите его и добавьте в PATH или папку tools рядом с приложением.',
    );
  }

  static Future<void> verify(
    String path,
    String name, {
    Duration? timeout,
    MusicProcess? worker,
    bool useCache = false,
  }) async {
    // На первом запуске macOS проверяет библиотеки Python-сборок. Проверка
    // после установки должна давать им столько же времени, сколько установщик.
    timeout ??= Platform.isMacOS && (name == 'yt-dlp' || name == 'spotdl')
        ? const Duration(minutes: 2)
        : const Duration(seconds: 15);
    worker?.check();
    final key = '$name\u0000$path';
    final stat = await File(path).stat();
    final cached = _verifiedExecutables[key];
    if (useCache &&
        stat.type == FileSystemEntityType.file &&
        cached != null &&
        stat.size == cached.size &&
        stat.modified == cached.modified &&
        stat.changed == cached.changed &&
        stat.mode == cached.mode) {
      worker?.check();
      return;
    }
    _verifiedExecutables.remove(key);
    final Process process;
    try {
      process = await Process.start(path, [
        name == 'ffmpeg' ? '-version' : '--version',
      ]);
    } on ProcessException catch (error) {
      throw StateError(
        'Не удалось запустить $name (код ОС: ${error.errorCode}). '
        'Проверьте совместимость компонента с вашей системой.',
      );
    }
    var terminated = false;
    void terminate() {
      if (terminated) return;
      terminated = true;
      unawaited(_killTree(process));
    }

    worker?._process = process;
    worker?._stop = terminate;
    if (worker?.cancelled == true) terminate();
    final output = process.stdout.transform(utf8.decoder).join();
    final errors = process.stderr.drain<void>();
    var timedOut = false;
    final timer = Timer(timeout, () {
      timedOut = true;
      terminate();
    });
    try {
      final code = await process.exitCode;
      final version = await output;
      await errors;
      worker?.check();
      if (timedOut) {
        throw StateError(
          'Проверка $name заняла слишком много времени. Повторите попытку.',
        );
      }
      if (code != 0) {
        throw StateError(
          'Не удалось запустить $name (код завершения: $code). Проверьте совместимость компонента с вашей системой.',
        );
      }
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
      _verifiedExecutables[key] = stat;
    } finally {
      timer.cancel();
      if (worker?._process == process) {
        worker?._process = null;
        worker?._stop = null;
      }
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
    final output = <int>[];
    var exceeded = false;
    var timedOut = false;
    var checking = false;
    var terminated = false;
    void terminate() {
      if (terminated) return;
      terminated = true;
      unawaited(_killTree(process));
    }

    _stop = terminate;
    if (cancelled) terminate();

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
    var browserCookiesRead = false;
    var youtubeAccountCookies = false;
    var youtubeCookiesExpired = false;
    var browserCookieKeyUnavailable = false;
    final stderr = process.stderr
        .transform(const Utf8Decoder(allowMalformed: true))
        .listen((text) {
          diagnostic += text.toLowerCase();
          browserCookiesRead |= RegExp(r'extracted \d+ cookies from')
              .hasMatch(diagnostic);
          youtubeAccountCookies |= diagnostic.contains(
            'found youtube account cookies',
          );
          youtubeCookiesExpired |= diagnostic.contains(
            'youtube account cookies are no longer valid',
          );
          browserCookieKeyUnavailable |=
              diagnostic.contains('find-generic-password failed') ||
              diagnostic.contains('cannot decrypt v10 cookies: no key found');
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
      if (Platform.isMacOS &&
          arguments.contains('--cookies-from-browser') &&
          browserCookieKeyUnavailable) {
        throw YoutubeAccessRequired(
          'Не удалось получить ключ расшифровки cookies из Связки ключей macOS. Выберите другой браузер, в котором выполнен вход в YouTube, или восстановите доступ к ключу выбранного браузера в Связке ключей.',
        );
      }
      if (code != 0 || exceeded) {
        if (diagnostic.contains('impersonate target') &&
            diagnostic.contains('not available')) {
          throw StateError(
            'Для SoundCloud нужен yt-dlp с поддержкой Chrome: установите полную официальную сборку или пакет yt-dlp[default,curl-cffi].',
          );
        }
        if (youtubeCookiesExpired) {
          throw YoutubeAccessRequired(
            'Сессия YouTube в браузере истекла. Войдите в YouTube заново в выбранном браузере и повторите импорт.',
          );
        }
        if (Platform.isMacOS &&
            diagnostic.contains('cookie') &&
            (diagnostic.contains('operation not permitted') ||
                diagnostic.contains('permission denied'))) {
          throw YoutubeAccessRequired(
            'macOS запретила доступ к cookies браузера. Разрешите Walone доступ в «Системные настройки → Конфиденциальность и безопасность → Полный доступ к диску», затем полностью завершите Walone и откройте снова.',
          );
        }
        if (diagnostic.contains('could not copy') &&
                diagnostic.contains('cookie') ||
            diagnostic.contains('failed to decrypt') ||
            diagnostic.contains('could not find') &&
                diagnostic.contains('cookies database') ||
            diagnostic.contains('operation not permitted') &&
                diagnostic.contains('cookie')) {
          throw YoutubeAccessRequired(
            'Не удалось прочитать cookies браузера. Закройте браузер и повторите или выберите другой браузер, в котором открыт YouTube.',
          );
        }
        if (diagnostic.contains('not a bot')) {
          final usesBrowser = arguments.contains('--cookies-from-browser');
          if (usesBrowser && youtubeAccountCookies) {
            throw YoutubeAccessRequired(
              'YouTube отклонил запрос с cookies, хотя вход в аккаунт распознан. Проверка в браузере не разрешила этот запрос. Проверьте, что браузер и Walone используют одну сеть, или повторите позже.',
            );
          }
          if (usesBrowser && browserCookiesRead) {
            throw YoutubeAccessRequired(
              'В cookies выбранного браузера не найдена активная сессия YouTube. Войдите в YouTube в обычном окне этого браузера и повторите импорт. Приватное окно использует отдельную сессию.',
            );
          }
          throw YoutubeAccessRequired(
            'YouTube запросил проверку «не бот». Откройте видео в браузере, войдите и пройдите проверку. Затем выберите этот браузер в окне импорта и повторите. Если не помогло, попробуйте позже или другую сеть.',
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
      await stdout.cancel();
      await stderr.cancel();
      if (identical(_process, process)) {
        _process = null;
        _stop = null;
      }
    }
  }
}
