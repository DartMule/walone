import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:walone/core/storage.dart';
import 'package:walone/features/music/data/music_process.dart';

void main() {
  for (final cancel in [true, false]) {
    test('Остановка завершает дочерний процесс: отмена=$cancel', () async {
      final root = await Directory.systemTemp.createTemp(
        'walone-process-tree-',
      );
      final worker = MusicProcess();
      final childFile = File('${root.path}/child');
      int? child;
      try {
        final task = worker.run(
          '/bin/sh',
          ['-c', "trap 'exit 0' TERM; /bin/sleep 30 & echo \$! > child; wait"],
          root,
          timeout: cancel
              ? const Duration(seconds: 30)
              : const Duration(seconds: 1),
        );
        final result = expectLater(
          task.timeout(const Duration(seconds: 4)),
          throwsA(cancel ? isA<ImportCancelled>() : isA<StateError>()),
        );
        while (!await childFile.exists() ||
            (await childFile.readAsString()).trim().isEmpty) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        child = int.parse((await childFile.readAsString()).trim());
        if (cancel) worker.cancel();
        await result;
      } finally {
        if (child != null) Process.killPid(child, ProcessSignal.sigkill);
        worker.cancel();
        await root.delete(recursive: true);
      }
    }, skip: !Platform.isMacOS);
  }

  test('Проверка версии инструмента отменяется вместе с импортом', () async {
    final root = await Directory.systemTemp.createTemp('walone-verify-cancel-');
    final worker = MusicProcess();
    try {
      final tool = File('${root.path}/tool');
      await tool.writeAsString(
        '#!/bin/sh\necho ready > "${root.path}/started"\nexec /bin/sleep 30\n',
      );
      await Process.run('/bin/chmod', ['700', tool.path]);
      final task = MusicProcess.verify(tool.path, 'spotdl', worker: worker);
      final result = expectLater(
        task.timeout(const Duration(seconds: 4)),
        throwsA(isA<ImportCancelled>()),
      );
      while (!await File('${root.path}/started').exists()) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      worker.cancel();
      await result;
    } finally {
      worker.cancel();
      await root.delete(recursive: true);
    }
  }, skip: !Platform.isMacOS);

  test('Полный runtime yt-dlp обнаруживается раньше старой сборки', () async {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    final root = await Directory.systemTemp.createTemp(
      'walone-runtime-finder-',
    );
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (_) async => root.path,
    );
    try {
      final managed = p.join(
        (await JsonStore.applicationDirectory()).path,
        'ImportTools',
      );
      final runtime = File(p.join(managed, 'yt-dlp_macos', 'yt-dlp_macos'));
      await runtime.parent.create(recursive: true);
      await runtime.writeAsString(
        '#!/bin/sh\n/bin/sleep 0.1\necho 2026.10.21\n',
      );
      final old = File(p.join(managed, 'yt-dlp'));
      await old.writeAsString('#!/bin/sh\necho old\n');
      for (final file in [runtime, old]) {
        await Process.run('/bin/chmod', ['700', file.path]);
      }
      final found = await runZoned(
        () => MusicProcess.executable('yt-dlp'),
        zoneSpecification: ZoneSpecification(
          createTimer: (self, parent, zone, duration, callback) =>
              parent.createTimer(
                zone,
                duration == const Duration(seconds: 15)
                    ? const Duration(milliseconds: 20)
                    : duration,
                callback,
              ),
        ),
      );
      expect(found, runtime.path);
      await runtime.writeAsString('#!/bin/sh\nexit 42\n');
      expect(await MusicProcess.executable('yt-dlp'), old.path);
    } finally {
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
      await root.delete(recursive: true);
    }
  }, skip: !Platform.isMacOS);

  test('Повторный поиск проверяет версию только после изменения файла', () async {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    final root = await Directory.systemTemp.createTemp('walone-tool-cache-');
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (_) async => root.path,
    );
    try {
      final tool = File(
        p.join(
          (await JsonStore.applicationDirectory()).path,
          'ImportTools',
          'ffmpeg',
        ),
      );
      final calls = File(p.join(root.path, 'calls'));
      await tool.parent.create(recursive: true);
      Future<void> writeTool(String version) async {
        await tool.writeAsString(
          '#!/bin/sh\necho run >> "${calls.path}"\n/bin/sleep 0.1\necho $version\n',
        );
        await Process.run('/bin/chmod', ['700', tool.path]);
      }

      await writeTool('version-one');
      final first = Stopwatch()..start();
      expect(await MusicProcess.executable('ffmpeg'), tool.path);
      first.stop();
      final repeated = Stopwatch()..start();
      expect(await MusicProcess.executable('ffmpeg'), tool.path);
      repeated.stop();
      expect(await calls.readAsLines(), hasLength(1));
      await writeTool('version-two-changed');
      expect(await MusicProcess.executable('ffmpeg'), tool.path);
      expect(await calls.readAsLines(), hasLength(2));
      expect(await MusicProcess.executable('ffmpeg', force: true), tool.path);
      expect(await calls.readAsLines(), hasLength(3));
      final cancelled = MusicProcess()..cancel();
      await expectLater(
        MusicProcess.executable('ffmpeg', worker: cancelled),
        throwsA(isA<ImportCancelled>()),
      );
      expect(await calls.readAsLines(), hasLength(3));
      await Process.run('/bin/chmod', ['600', tool.path]);
      await expectLater(
        MusicProcess.verify(tool.path, 'ffmpeg', useCache: true),
        throwsStateError,
      );
      await Process.run('/bin/chmod', ['700', tool.path]);
      expect(await MusicProcess.executable('ffmpeg'), tool.path);
      expect(await calls.readAsLines(), hasLength(4));
      await tool.delete();
      await expectLater(
        MusicProcess.verify(tool.path, 'ffmpeg', useCache: true),
        throwsStateError,
      );
      stdout.writeln(
        'Tool verification: first=${first.elapsedMilliseconds}ms, repeated=${repeated.elapsedMilliseconds}ms',
      );
    } finally {
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
      await root.delete(recursive: true);
    }
  }, skip: Platform.isWindows);

  test(
    'Замер установленных компонентов без сети',
    () async {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      const channel = MethodChannel('plugins.flutter.io/path_provider');
      final support = p.join(
        Platform.environment['HOME']!,
        'Library',
        'Application Support',
        'dev.soyjanks.walone.flutter',
      );
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (_) async => support,
      );
      try {
        final timings = <int>[];
        for (var pass = 0; pass < 2; pass++) {
          final watch = Stopwatch()..start();
          for (final name in ['ffmpeg', 'yt-dlp', 'node']) {
            await MusicProcess.executable(name);
          }
          timings.add(watch.elapsedMilliseconds);
        }
        stdout.writeln(
          'Installed tools: first=${timings[0]}ms, repeated=${timings[1]}ms',
        );
      } finally {
        binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
      }
    },
    skip:
        !Platform.isMacOS ||
        !const bool.fromEnvironment('VERIFY_INSTALLED_IMPORT_TOOLS'),
  );

  for (final sample in [
    (
      'WARNING: find-generic-password failed\nWARNING: cannot decrypt v10 cookies: no key found\nERROR: Sign in to confirm you are not a bot.',
      'Связки ключей macOS',
    ),
    (
      'WARNING: find-generic-password failed\n${'debug\n' * 4000}ERROR: Sign in to confirm you are not a bot.',
      'Связки ключей macOS',
    ),
    (
      'ERROR: Could not find Chrome cookies database in private-profile',
      'Не удалось прочитать cookies браузера',
    ),
    (
      'ERROR: Could not copy Chrome cookie database',
      'Не удалось прочитать cookies браузера',
    ),
    (
      'ERROR: Failed to decrypt cookies with Keychain',
      'Не удалось прочитать cookies браузера',
    ),
    (
      'WARNING: The provided YouTube account cookies are no longer valid.\nERROR: Sign in to confirm you are not a bot.',
      'Сессия YouTube в браузере истекла',
    ),
    (
      'WARNING: Could not read cookie database: Operation not permitted\nERROR: Sign in to confirm you are not a bot.',
      'macOS запретила доступ к cookies',
    ),
    (
      '[Cookies] Extracted 12 cookies from firefox\nERROR: Sign in to confirm you are not a bot.',
      'не найдена активная сессия YouTube',
    ),
    (
      '[Cookies] Extracted 12 cookies from firefox\n[debug] Found YouTube account cookies\nERROR: Sign in to confirm you are not a bot.',
      'YouTube отклонил запрос с cookies',
    ),
    (
      '[Cookies] Extracted 12 cookies from firefox\n[debug] Found YouTube account cookies\n${'debug\n' * 4000}ERROR: Sign in to confirm you are not a bot.',
      'YouTube отклонил запрос с cookies',
    ),
  ]) {
    test('Причина cookies не теряется за проверкой бота: ${sample.$2}', () async {
      final root = await Directory.systemTemp.createTemp(
        'walone-cookie-error-',
      );
      try {
        final tool = File('${root.path}/tool');
        await tool.writeAsString(
          '#!/bin/sh\ncat >&2 <<\'DIAGNOSTIC\'\n${sample.$1}\nprivate-cookie-value\nDIAGNOSTIC\nexit 1\n',
        );
        await Process.run('/bin/chmod', ['700', tool.path]);
        await expectLater(
          MusicProcess().run(tool.path, [
            '--cookies-from-browser',
            'firefox',
          ], root),
          throwsA(
            isA<YoutubeAccessRequired>()
                .having((e) => e.message, 'причина', contains(sample.$2))
                .having(
                  (e) => e.message,
                  'приватность',
                  isNot(contains('private-cookie-value')),
                ),
          ),
        );
      } finally {
        await root.delete(recursive: true);
      }
    }, skip: !Platform.isMacOS);
  }

  test('Проверка инструмента различает код выхода и тайм-аут', () async {
    final root = await Directory.systemTemp.createTemp('walone-process-');
    try {
      final tool = File('${root.path}/tool');
      await tool.writeAsString('#!/bin/sh\nexit 42\n');
      await Process.run('/bin/chmod', ['700', tool.path]);
      await expectLater(
        MusicProcess.verify(tool.path, 'yt-dlp'),
        throwsA(
          isA<StateError>().having((e) => e.message, 'причина', contains('42')),
        ),
      );
      await tool.writeAsString('#!/bin/sh\nexec /bin/sleep 10\n');
      await expectLater(
        MusicProcess.verify(
          tool.path,
          'yt-dlp',
          timeout: const Duration(milliseconds: 50),
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'причина',
            contains('слишком много времени'),
          ),
        ),
      );
      await expectLater(
        MusicProcess.verify('${root.path}/missing', 'yt-dlp'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'причина',
            contains('код ОС:'),
          ),
        ),
      );
    } finally {
      await root.delete(recursive: true);
    }
  }, skip: Platform.isWindows);

  test(
    'Проверка YouTube предлагает использовать браузер без утечки stderr',
    () async {
      final root = await Directory.systemTemp.createTemp('walone-bot-');
      try {
        final tool = File('${root.path}/tool');
        await tool.writeAsString(
          '#!/bin/sh\necho "Sign in to confirm you are not a bot. private-url" >&2\nexit 1\n',
        );
        await Process.run('/bin/chmod', ['700', tool.path]);
        await expectLater(
          MusicProcess().run(tool.path, [], root),
          throwsA(
            isA<StateError>()
                .having(
                  (e) => e.message,
                  'решение',
                  contains('выберите этот браузер'),
                )
                .having(
                  (e) => e.message,
                  'приватность',
                  isNot(contains('private-url')),
                ),
          ),
        );
      } finally {
        await root.delete(recursive: true);
      }
    },
    skip: Platform.isWindows,
  );
}
