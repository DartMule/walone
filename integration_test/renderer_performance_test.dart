import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:walone/core/storage.dart';
import 'package:walone/core/widgets.dart';
import 'package:walone/features/keyboard/data/native_keyboard_repository.dart';
import 'package:walone/features/keyboard/domain/keyboard.dart';
import 'package:walone/features/keyboard/presentation/keyboard_cubit.dart';
import 'package:walone/features/keyboard/presentation/keyboard_page.dart';
import 'package:walone/features/statistics/data/statistics_database.dart';
import 'package:walone/features/statistics/domain/activity.dart';
import 'package:walone/features/statistics/presentation/statistics_cubit.dart';
import 'package:walone/features/statistics/presentation/statistics_page.dart';
import 'package:walone/features/timer/presentation/timer_cubit.dart';
import 'package:walone/features/timer/presentation/timer_page.dart';

// Настоящий каталог и UI; глобальный ввод и аудио не нужны для замера рендера.
class _Keyboard extends NativeKeyboardRepository {
  @override
  Future<KeyboardStatus> initialize() async => const KeyboardStatus();
  @override
  Future<KeyboardStatus> status() async => const KeyboardStatus();
  @override
  Future<void> configure(
    KeyboardPack pack,
    bool enabled,
    double volume,
  ) async {}
  @override
  Future<void> dispose() async {}
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('Сравнение рендереров при бюджете 120 Гц', (tester) async {
    final directory = await Directory.systemTemp.createTemp('walone-renderer-');
    final appearance = JsonStore(File('${directory.path}/appearance.json'));
    await appearance.write({
      'followSystem': false,
      'transparency': 0.75,
      'themeMode': 'light',
      'compactPlayer': true,
    });
    final keyboard = KeyboardCubit(_Keyboard());
    await keyboard.initialize();
    final timer = TimerCubit();
    final now = DateTime(2026, 10, 19, 12);
    final db = StatisticsDatabase.open(File('${directory.path}/stats.sqlite'));
    final preferences = await db.preferences();
    final days = <String, ActivityIncrement>{};
    for (var i = 0; i < 365; i++) {
      days[dayKey(now.subtract(Duration(days: i)))] = ActivityIncrement()
        ..listeningMs = (i % 5 + 1) * 600000
        ..keys = i * 13;
    }
    await db.record(days, preferences, {});
    final statistics = StatisticsCubit(
      db,
      clock: () => now,
      syncKeys: (_) async => 0,
    );
    await statistics.initialize();
    final results = <String, dynamic>{};

    Future<void> show(Widget page) async {
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider.value(value: keyboard),
            BlocProvider.value(value: timer),
            BlocProvider.value(value: statistics),
          ],
          child: MaterialApp(
            theme: WaloneDesign.theme(Brightness.light),
            builder: (_, child) =>
                WaloneGlassHost(store: appearance, child: child!),
            home: page,
          ),
        ),
      );
      await Future<void>.delayed(const Duration(seconds: 2));
      final glass = tester.state<WaloneGlassHostState>(
        find.byType(WaloneGlassHost),
      );
      glass.setLiveBackdropNeeded(false);
      expect(glass.reduceTransparency, isFalse);
      expect(glass.increaseContrast, isFalse);
      await Future<void>.delayed(const Duration(seconds: 1));
    }

    Future<void> measure(String name, Future<void> Function() action) async {
      final frames = <ui.FrameTiming>[];
      void collect(List<ui.FrameTiming> batch) => frames.addAll(batch);
      binding.addTimingsCallback(collect);
      final watch = Stopwatch()..start();
      await action();
      final elapsed = watch.elapsedMicroseconds;
      await Future<void>.delayed(const Duration(seconds: 1));
      binding.removeTimingsCallback(collect);
      expect(frames.length, greaterThan(100));
      results[name] = {
        'action_us': elapsed,
        'frames': frames
            .map(
              (f) => {
                'build_us': f.buildDuration.inMicroseconds,
                'raster_us': f.rasterDuration.inMicroseconds,
                'total_us': f.totalSpan.inMicroseconds,
                'vsync_us': f.timestampInMicroseconds(ui.FramePhase.vsyncStart),
              },
            )
            .toList(),
      };
      expect(tester.takeException(), isNull);
    }

    Future<void> scroll() async {
      final position = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      expect(position.maxScrollExtent, greaterThan(0));
      for (var i = 0; i < 6; i++) {
        await position.animateTo(
          i.isEven ? position.maxScrollExtent : 0,
          duration: const Duration(seconds: 2),
          curve: Curves.linear,
        );
      }
    }

    try {
      final view = binding.platformDispatcher.views.first;
      results['environment'] = {
        'physical_width': view.physicalSize.width,
        'physical_height': view.physicalSize.height,
        'dpr': view.devicePixelRatio,
        'reported_refresh_hz': view.display.refreshRate,
        'budget_us': 1000000 / 120,
        'glass_depth': 0.75,
        'live_backdrop': false,
      };
      await show(const KeyboardPage());
      await measure('keyboard_scroll', scroll);
      await show(const StatisticsPage());
      await measure('statistics_scroll', scroll);
      await show(const TimerPage());
      timer.toggle();
      await Future<void>.delayed(const Duration(seconds: 2));
      await measure(
        'timer_animation',
        () => Future<void>.delayed(const Duration(seconds: 12)),
      );
      timer.toggle();
      binding.reportData = results;
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await keyboard.close();
      await timer.close();
      await statistics.close();
      await directory.delete(recursive: true);
    }
  }, timeout: const Timeout(Duration(minutes: 3)));
}
