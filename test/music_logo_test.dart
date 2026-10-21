import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walone/features/music/data/music_repository.dart';
import 'package:walone/features/music/data/music_waveform.dart';
import 'package:walone/features/music/presentation/music_cubit.dart';
import 'package:walone/features/music/presentation/music_logo.dart';
import 'package:walone/features/music/domain/music.dart';

import 'media_fakes.dart';

class _Music extends MusicCubit {
  _Music(FakeWaveform waveform)
    : super(
        MusicRepository(Directory.systemTemp, audioFactory: FakeAudio.new),
        waveformFactory: () => waveform,
      );

  void playing(bool value) => emit(
    MusicState(
      library: MusicLibrary(
        tracks: [
          MusicTrack(
            id: 'test',
            title: 'Test',
            filename: 'test.wav',
            duration: 10,
          ),
        ],
        trackID: 'test',
      ),
      playing: value,
    ),
  );
}

class _PaintCounter extends CustomPainter {
  int paints = 0;
  @override
  void paint(Canvas canvas, Size size) => paints++;
  @override
  bool shouldRepaint(_PaintCounter oldDelegate) => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Windows получает амплитуды без внешнего FFmpeg', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    const channel = MethodChannel('dev.soyjanks.walone/desktop');
    final calls = <MethodCall>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'readWaveform') {
        return {
          'levels': Float64List.fromList(List.filled(50, 0.25)),
          'done': true,
        };
      }
      return null;
    });
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      messenger.setMockMethodCallHandler(channel, null);
    });
    final waveform = MusicWaveform();
    await waveform.load(r'C:\Музыка\track.mp3');
    expect(waveform.bars(0.8, 1), everyElement(closeTo(0.9, 0.001)));
    expect(calls.first.method, 'startWaveform');
    expect((calls.first.arguments as Map)['path'], r'C:\Музыка\track.mp3');
    waveform.cancel();
    expect(waveform.levels, isEmpty);
  });
  for (final cancel in [true, false]) {
    test(
      'Windows освобождает расчёт при отмене/ошибке (cancel=$cancel)',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.windows;
        const channel = MethodChannel('dev.soyjanks.walone/desktop');
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        final reading = Completer<void>();
        final response = Completer<Map<String, dynamic>>();
        final stopped = <String>[];
        messenger.setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'readWaveform') {
            reading.complete();
            return response.future;
          }
          if (call.method == 'stopWaveform') {
            stopped.add(call.arguments as String);
          }
          return null;
        });
        addTearDown(() {
          debugDefaultTargetPlatformOverride = null;
          messenger.setMockMethodCallHandler(channel, null);
        });
        final waveform = MusicWaveform();
        final loading = waveform.load('track.wav');
        await reading.future;
        if (cancel) waveform.cancel();
        response.complete({
          'levels': Float64List.fromList([0.5]),
          'done': true,
          'failed': !cancel,
        });
        await loading;
        expect(waveform.levels, isEmpty);
        expect(stopped, isNotEmpty);
        expect(stopped.toSet(), hasLength(1));
      },
    );
  }
  test('Амплитуды хранятся компактно и сохраняются при росте буфера', () {
    final waveform = MusicWaveform();
    final values = List.generate(3000, (i) => i / 3000);
    waveform.addLevels(values.take(1000));
    waveform.addLevels(values.skip(1000));
    expect(waveform.levels, isA<Float32List>());
    expect(waveform.levels.length, values.length);
    expect(waveform.levels.buffer.lengthInBytes, lessThan(3000 * 2 * 4));
    for (var i = 0; i < values.length; i++) {
      expect(waveform.levels[i], closeTo(values[i], 0.000001));
    }
  });
  test('PCM: тишина, противофаза стерео и неполные блоки', () async {
    final levels = await MusicWaveform.amplitudes(
      Stream.fromIterable([
        List.filled(137, 128),
        [
          ...List.filled(183, 128),
          ...List.generate(320, (i) => i.isEven ? 64 : 192),
          128,
        ],
      ]),
    ).toList();
    expect(levels, [0, 0.5, 0]);
  });
  test('Полоски следуют амплитуде, позиции и громкости трека', () {
    final waveform = MusicWaveform();
    waveform.addLevels(List.generate(50, (i) => i < 25 ? 0.0 : 0.25));
    expect(waveform.bars(0.2, 1), everyElement(0));
    expect(waveform.bars(0.8, 1), everyElement(closeTo(0.9, 0.001)));
    expect(waveform.bars(0.8, 0), everyElement(0));
    expect(waveform.bars(0.8, 0.25).first, lessThan(0.9));
    expect(waveform.bars(2, 1), everyElement(0));
    expect(waveform.bars(0.2, 1), everyElement(0));
  });

  test('Отмена расчёта освобождает накопленные амплитуды', () async {
    final waveform = MusicWaveform()..addLevels(List.filled(3000, 0.5));
    waveform.cancel();
    expect(waveform.levels, isEmpty);
    expect(waveform.levels.buffer.lengthInBytes, 0);
    await waveform.load('cancelled.wav');
    expect(waveform.levels, isEmpty);
  });

  testWidgets('Полоски логотипа не перерисовывают неподвижную панель', (
    tester,
  ) async {
    final music = _Music(FakeWaveform());
    final background = _PaintCounter();
    (music.visualization as ValueNotifier<List<double>?>).value = [
      0.2,
      0.4,
      0.6,
      0.4,
      0.2,
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: CustomPaint(
          painter: background,
          child: Center(child: MusicLogo(music: music)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final paints = background.paints;
    (music.visualization as ValueNotifier<List<double>?>).value = [
      0.4,
      0.6,
      0.8,
      0.6,
      0.4,
    ];
    await tester.pump();
    expect(background.paints, paints);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(music.close);
  });

  testWidgets(
    'Общий источник продолжает работу без виджета, пауза останавливает его',
    (tester) async {
      final waveform = FakeWaveform();
      final music = _Music(waveform);
      await tester.pumpWidget(MaterialApp(home: MusicLogo(music: music)));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.graphic_eq_rounded), findsOneWidget);
      expect(tester.binding.hasScheduledFrame, isFalse);
      music.playing(true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(music.visualization.value, hasLength(5));
      expect(find.byIcon(Icons.graphic_eq_rounded), findsNothing);
      expect(waveform.loads, 1);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: MusicLogo(music: music),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(find.byIcon(Icons.graphic_eq_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      var frames = 0;
      void count() {
        frames++;
      }

      music.visualization.addListener(count);
      await tester.pump(const Duration(milliseconds: 150));
      expect(frames, greaterThan(0));
      expect(waveform.loads, 1);
      music.playing(false);
      expect(music.visualization.value, isNull);
      final stopped = frames;
      await tester.pump(const Duration(milliseconds: 150));
      expect(frames, stopped);
      music.visualization.removeListener(count);
      await tester.runAsync(music.close);
      expect(waveform.cancelled, isTrue);
    },
  );
}
