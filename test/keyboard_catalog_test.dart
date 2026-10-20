import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:walone/core/storage.dart';
import 'package:walone/features/keyboard/data/keyboard_history_repository.dart';
import 'package:walone/features/keyboard/data/keyboard_preview.dart';
import 'package:walone/features/keyboard/presentation/keyboard_cubit.dart';

import 'keyboard_test.dart' show FakeKeyboardRepository, brown, red;
import 'media_fakes.dart' show FakeAudio;

class DelayedPreviewAudio extends FakeAudio {
  final started = Completer<void>();
  final release = Completer<void>();
  @override
  Future<Duration> load(
    String path, {
    bool asset = false,
    bool loop = false,
  }) async {
    if (!started.isCompleted) {
      started.complete();
      await release.future;
    }
    return super.load(path, asset: asset, loop: loop);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late File file;
  late FakeKeyboardRepository native;
  late FakeAudio audio;
  late KeyboardCubit cubit;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('walone-catalog-');
    file = File('${directory.path}/history.json');
    native = FakeKeyboardRepository();
    audio = FakeAudio();
    cubit = KeyboardCubit(
      native,
      historyRepository: KeyboardHistoryRepository(store: JsonStore(file)),
      preview: KeyboardPreview(
        factory: () => audio,
        interval: Duration.zero,
        tail: Duration.zero,
      ),
    );
    await cubit.initialize();
  });
  tearDown(() async {
    await cubit.close();
    await directory.delete(recursive: true);
  });

  test('История хранит последний явный выбор; запуск, громкость и атмосфера не меняют даты', () async {
    expect(cubit.state.history, isEmpty);
    await cubit.choose(red);
    await cubit.choose(brown);
    await cubit.choose(red);
    expect(cubit.state.history.map((entry) => entry.packID), ['red', 'brown']);
    final dates = cubit.state.history.map((entry) => entry.lastUsed).toList();
    await cubit.configure(volume: 0.6);
    await cubit.configure(pack: brown);
    await cubit.preview(pack: red);
    expect(cubit.state.history.map((entry) => entry.lastUsed), dates);
    native.fail = true;
    await cubit.choose(red);
    expect(cubit.state.history.map((entry) => entry.lastUsed), dates);
    final restoredNative = FakeKeyboardRepository();
    final restored = KeyboardCubit(
      restoredNative,
      historyRepository: KeyboardHistoryRepository(store: JsonStore(file)),
    );
    await restored.initialize();
    expect(restored.state.selected?.id, 'red');
    expect(restoredNative.selected.id, 'red');
    expect(restored.state.history.map((entry) => entry.packID), [
      'red',
      'brown',
    ]);
    expect(restored.state.history.map((entry) => entry.lastUsed), dates);
    await restored.close();
  });

  test('Предпрослушивание всех групп не меняет выбранный набор, историю и включение', () async {
    await cubit.preview(pack: red);
    expect(native.selected.id, 'brown');
    expect(native.enabled, isFalse);
    expect(cubit.state.history, isEmpty);
    expect(audio.loads, hasLength(8));
    expect(
      audio.loads.where((path) => path.endsWith('/space.wav')),
      hasLength(1),
    );
    expect(
      audio.loads.where((path) => path.endsWith('enter.wav')),
      hasLength(1),
    );
    expect(
      audio.loads.where((path) => path.endsWith('backspace.wav')),
      hasLength(1),
    );
    await cubit.configure(volume: 0.5);
    await cubit.previewEnvironment(0.2, true);
    for (var group = 0; group < 4; group++) {
      expect(audio.disposed, isTrue);
      audio = FakeAudio();
      await cubit.preview(group: group);
    }
    expect(audio.loads.last, 'keyboards/brown/backspace.wav');
    expect(audio.volume, closeTo(0.1, 0.000001));
    final count = audio.loads.length;
    await cubit.previewEnvironment(0.2, false);
    await cubit.preview(pack: red);
    expect(audio.loads, hasLength(count));
    expect(cubit.state.previewID, isNull);
  });

  test('Поздняя загрузка отменённого примера не запускает звук и не сбрасывает новый', () async {
    final delayed = DelayedPreviewAudio();
    final preview = KeyboardPreview(
      factory: () => delayed.disposed ? FakeAudio() : delayed,
      interval: Duration.zero,
      tail: const Duration(milliseconds: 20),
    );
    final changes = <String?>[];
    preview.onChanged = changes.add;
    final first = preview.play(red, volume: 0);
    await delayed.started.future;
    final second = preview.play(brown, group: 3, volume: 0);
    delayed.release.complete();
    await first;
    expect(changes.last, 'brown');
    await second;
    expect(delayed.loads, [
      'keyboards/red/key0.wav',
      'keyboards/brown/backspace.wav',
    ]);
    expect(changes, ['red', 'brown', null]);
    expect(delayed.playing, isFalse);
    final cancelled = preview.play(red, volume: 0);
    await preview.environment(0.7, false, 0);
    await cancelled;
    expect(delayed.playing, isFalse);
    await preview.dispose();
    expect(delayed.disposed, isTrue);
  });

  test('Повреждённая история не перезаписывается при новом выборе', () async {
    final broken = await File('${directory.path}/broken.json')
        .writeAsString('{broken');
    final protected = KeyboardCubit(
      FakeKeyboardRepository(),
      historyRepository: KeyboardHistoryRepository(store: JsonStore(broken)),
    );
    await protected.initialize();
    expect(protected.state.loading, isFalse);
    expect(protected.state.historyError, isNotNull);
    await protected.choose(red);
    expect(protected.state.selected!.id, 'red');
    expect(protected.state.historyError, contains('сохранить'));
    expect(await broken.readAsString(), '{broken');
    await protected.close();
  });
}
