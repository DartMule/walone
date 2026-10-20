import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:walone/features/atmosphere/data/atmosphere_audio.dart';

import 'media_fakes.dart';

class RecordingAudio extends FakeAudio {
  final levels = <double>[];
  bool failVolume = false;

  @override
  Future<void> setVolume(double value) async {
    if (failVolume) throw StateError('Аудиовыход недоступен');
    levels.add(value);
    await super.setVolume(value);
  }
}

class LoadingAudio extends RecordingAudio {
  final started = Completer<void>();
  final resume = Completer<void>();
  int plays = 0;

  @override
  Future<Duration> load(
    String path, {
    bool asset = false,
    bool loop = false,
  }) async {
    started.complete();
    await resume.future;
    return super.load(path, asset: asset, loop: loop);
  }

  @override
  Future<void> play() async {
    plays++;
    await super.play();
  }
}

class StartingAudio extends RecordingAudio {
  final started = Completer<void>();
  final resume = Completer<void>();
  int plays = 0;

  @override
  Future<void> setVolume(double value) async {
    if (!started.isCompleted) {
      started.complete();
      await resume.future;
    }
    await super.setVolume(value);
  }

  @override
  Future<void> play() async {
    plays++;
    await super.play();
  }
}

void main() {
  test('Остановка события во время подготовки не возобновляет звук', () async {
    var now = DateTime(2026);
    final player = StartingAudio();
    final audio = AtmosphereAudio(factory: () => player, clock: () => now);
    final errors = <String>[];
    audio.onError = errors.add;
    addTearDown(audio.stop);
    await audio.update({'birds': 0.5});
    now = now.add(const Duration(seconds: 3));
    await player.started.future;
    await audio.stop();
    player.resume.complete();
    await Future<void>.delayed(Duration.zero);
    expect(player.plays, 0);
    expect(player.disposed, isTrue);
    expect(errors, isEmpty);
  });

  test('Остановка во время загрузки не оставляет живые плееры', () async {
    final pending = LoadingAudio();
    final players = <RecordingAudio>[];
    final audio = AtmosphereAudio(
      factory: () {
        final player = players.isEmpty ? pending : RecordingAudio();
        players.add(player);
        return player;
      },
    );
    addTearDown(audio.stop);
    final loading = audio.update({'rain': 0.5});
    await pending.started.future;
    await audio.stop();
    pending.resume.complete();
    await loading;
    expect(pending.plays, 0);
    expect(players.every((player) => player.disposed), isTrue);
  });

  test('Устаревшая загрузка не теряет плееры нового микса', () async {
    final pending = LoadingAudio();
    final players = <RecordingAudio>[];
    final audio = AtmosphereAudio(
      factory: () {
        final player = players.isEmpty ? pending : RecordingAudio();
        players.add(player);
        return player;
      },
    );
    addTearDown(audio.stop);
    final loading = audio.update({'rain': 0.5});
    await pending.started.future;
    await audio.update({'rain': 0.3});
    pending.resume.complete();
    await loading;
    await audio.stop();
    expect(players.every((player) => player.disposed), isTrue);
  });

  test('Птицы и чайки освобождаются в паузах и звучат снова', () async {
    var now = DateTime(2026);
    final players = <RecordingAudio>[];
    final audio = AtmosphereAudio(
      clock: () => now,
      factory: () {
        final player = RecordingAudio();
        players.add(player);
        return player;
      },
    );
    try {
      await audio.update({'birds': 0.4, 'seagulls': 0.6});
      now = now.add(const Duration(seconds: 3));
      await Future<void>.delayed(const Duration(milliseconds: 350));
      expect(players, hasLength(2));
      expect(players.every((player) => player.playing), isTrue);
      expect(players.map((player) => player.volume), containsAll([0.4, 0.6]));
      final sources = players.map((player) => player.source).toSet();
      for (final player in players) {
        player.complete.add(null);
      }
      await Future<void>.delayed(const Duration(milliseconds: 350));
      expect(players.every((player) => player.disposed), isTrue);
      expect(players, hasLength(2));

      now = now.add(const Duration(minutes: 1));
      await Future<void>.delayed(const Duration(milliseconds: 350));
      expect(players, hasLength(4));
      expect(players.skip(2).every((player) => player.playing), isTrue);
      expect(
        players.skip(2).every((player) => !sources.contains(player.source)),
        isTrue,
      );
    } finally {
      await audio.stop();
    }
    expect(players.every((player) => player.disposed), isTrue);
    now = now.add(const Duration(minutes: 1));
    await Future<void>.delayed(const Duration(milliseconds: 350));
    expect(players, hasLength(4));
  });

  test('Выключение слоя после завершения не обращается к плееру', () async {
    var now = DateTime(2026);
    final players = <RecordingAudio>[];
    final audio = AtmosphereAudio(
      clock: () => now,
      factory: () {
        final player = RecordingAudio();
        players.add(player);
        return player;
      },
    );
    try {
      await audio.update({'birds': 0.4});
      now = now.add(const Duration(seconds: 3));
      await Future<void>.delayed(const Duration(milliseconds: 350));
      players.single.complete.add(null);
      await Future<void>.delayed(const Duration(milliseconds: 350));
      expect(players.single.disposed, isTrue);
      players.single.failVolume = true;
      await audio.update({});
    } finally {
      await audio.stop();
    }
    now = now.add(const Duration(minutes: 1));
    await Future<void>.delayed(const Duration(milliseconds: 350));
    expect(players, hasLength(1));
  });

  test('Следующий проход звучит до окончания текущего', () async {
    final players = <RecordingAudio>[];
    final audio = AtmosphereAudio(
      factory: () {
        final player = RecordingAudio();
        players.add(player);
        return player;
      },
    );
    try {
      await audio.update({'rain': 0.6});
      players.first.position.add(const Duration(seconds: 8));
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(players, hasLength(2));
      expect(players.every((player) => player.playing), isTrue);
      expect(players.first.volume, inExclusiveRange(0, 0.6));
      expect(players.last.volume, inExclusiveRange(0, 0.6));
      await Future<void>.delayed(const Duration(milliseconds: 2200));
      expect(players.first.playing, isFalse);
      expect(players.first.volume, 0);
      expect(players.last.volume, closeTo(0.6, 0.0001));

      // На следующем цикле роли плееров меняются.
      players.last.position.add(const Duration(seconds: 8));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(players.every((player) => player.playing), isTrue);
      await audio.update({'rain': 0.3});
      expect(
        players.fold<double>(
          0,
          (sum, player) => sum + player.volume * player.volume,
        ),
        closeTo(0.3 * 0.3, 0.0001),
      );
    } finally {
      // Остановка должна освободить оба плеера даже во время перехода.
      await audio.stop();
    }
    expect(players.every((player) => player.disposed), isTrue);
  });

  test('Ошибка затухания всё равно освобождает плеер', () async {
    final player = RecordingAudio();
    var created = 0;
    final audio = AtmosphereAudio(
      factory: () => created++ == 0 ? player : RecordingAudio(),
    );
    await audio.update({'rain': 0.6});
    player.failVolume = true;

    await expectLater(audio.stop(), throwsStateError);

    expect(player.disposed, isTrue);
  });

  for (final stopAll in [false, true]) {
    test(
      stopAll
          ? 'Остановка атмосферы плавно снижает громкость'
          : 'Выключение слоя плавно снижает громкость',
      () async {
        final player = RecordingAudio();
        var created = 0;
        final audio = AtmosphereAudio(
          factory: () => created++ == 0 ? player : RecordingAudio(),
        );
        await audio.update({'rain': 0.6});
        player.levels.clear();

        final elapsed = Stopwatch()..start();
        if (stopAll) {
          await audio.stop();
        } else {
          await audio.update({});
        }
        expect(elapsed.elapsedMilliseconds, greaterThanOrEqualTo(700));

        expect(player.levels.length, greaterThan(1));
        expect(player.levels.first, inExclusiveRange(0, 0.6));
        expect(player.levels.last, 0);
        for (var i = 1; i < player.levels.length; i++) {
          expect(player.levels[i], lessThanOrEqualTo(player.levels[i - 1]));
        }
        expect(player.disposed, isTrue);
      },
    );
  }
}
