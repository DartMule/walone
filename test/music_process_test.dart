import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:walone/features/music/data/music_process.dart';

void main() {
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
