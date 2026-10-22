import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:walone/core/storage.dart';
import 'package:walone/features/music/data/music_process.dart';

void main() {
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

  for (final sample in [
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
            isA<StateError>()
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
