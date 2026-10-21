import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:walone/features/music/data/import_tools.dart';
import 'package:walone/features/music/data/music_process.dart';

void main() {
  test('Отмена загрузки удаляет временные файлы до установки', () async {
    final root = await Directory.systemTemp.createTemp('walone-cancel-tools-');
    try {
      final worker = MusicProcess()..cancel();
      await expectLater(
        ImportTools.install(
          'yt-dlp',
          worker,
          root,
          (_) {},
          destination: Directory(p.join(root.path, 'installed')),
        ),
        throwsA(isA<ImportCancelled>()),
      );
      expect(await root.list().toList(), isEmpty);
    } finally {
      await root.delete(recursive: true);
    }
  });

  for (final name in ['yt-dlp', 'javascript', 'ffmpeg', 'spotdl']) {
    test(
      'Загрузка и запуск $name во временной папке',
      () async {
        final root = await Directory.systemTemp.createTemp(
          'walone-tools-test-',
        );
        try {
          final destination = Directory(p.join(root.path, 'installed'));
          {
            final statuses = <String>[];
            await ImportTools.install(
              name,
              MusicProcess(),
              root,
              statuses.add,
              destination: destination,
            );
            final tool = name == 'javascript' ? 'deno' : name;
            expect(
              await File(
                p.join(
                  destination.path,
                  '$tool${Platform.isWindows ? '.exe' : ''}',
                ),
              ).exists(),
              isTrue,
            );
            expect(statuses.any((s) => s.startsWith('Проверяем')), isTrue);
          }
        } finally {
          await root.delete(recursive: true);
        }
      },
      skip: !const bool.fromEnvironment('VERIFY_TOOL_DOWNLOADS'),
      timeout: const Timeout(Duration(minutes: 15)),
    );
  }
}
