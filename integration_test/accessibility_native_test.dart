import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:g1455/g1455.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:walone/core/storage.dart';
import 'package:walone/core/widgets.dart';
import 'package:walone/features/atmosphere/data/atmosphere_audio.dart';
import 'package:walone/features/atmosphere/presentation/atmosphere_cubit.dart';
import 'package:walone/features/keyboard/presentation/keyboard_cubit.dart';
import 'package:walone/features/music/data/music_repository.dart';
import 'package:walone/features/music/presentation/import_cubit.dart';
import 'package:walone/features/music/presentation/music_cubit.dart';
import 'package:walone/features/settings/presentation/settings_cubit.dart';
import 'package:walone/features/settings/presentation/settings_page.dart';
import 'package:walone/features/timer/presentation/timer_cubit.dart';
import 'package:walone/workspace.dart';

import '../test/media_fakes.dart';
import '../test/semantics_graph.dart';

class AccessibilityIntegrationBinding
    extends IntegrationTestWidgetsFlutterBinding {
  final graph = SemanticsGraph();
  @override
  ui.SemanticsUpdateBuilder createSemanticsUpdateBuilder() =>
      RecordingSemanticsBuilder(graph, super.createSemanticsUpdateBuilder());
}

void main() {
  final binding = AccessibilityIntegrationBinding();
  testWidgets('30 циклов разделов и обновлений с нативным деревом доступности', (
    tester,
  ) async {
    // Данные и звук изолированы; дерево доступности передаётся настоящему движку.
    final root = await Directory.systemTemp.createTemp('walone-a11y-');
    final keyboard = KeyboardCubit(FakeKeyboard());
    final repository = MusicRepository(
      Directory('${root.path}/Music'),
      audioFactory: FakeAudio.new,
    );
    final music = MusicCubit(repository);
    await keyboard.initialize();
    await music.initialize();
    final atmosphere = AtmosphereCubit(
      store: JsonStore(File('${root.path}/atmosphere.json')),
      audio: AtmosphereAudio(factory: FakeAudio.new),
      music: music,
      keyboard: keyboard,
      keyboardEnvironment: (_, _) async {},
      lifecycle: const Stream.empty(),
    );
    await atmosphere.initialize();
    final importer = ImportCubit(music, FakeVkSession(root));
    final timer = TimerCubit();
    final settings = SettingsCubit(atmosphere, timer: timer);
    await settings.initialize();
    final source = await File('${root.path}/player.wav').writeAsString('10');
    final track = await repository.prepareFile(source.path);
    await music.accept([track], newPlaylistName: 'Проверка плеера');
    await music.play(
      trackID: track.id,
      playlistID: music.state.library.selectedID,
    );

    final appearanceStore = JsonStore(File('${root.path}/appearance.json'));
    await appearanceStore.write({'followSystem': true, 'compactPlayer': false});
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider.value(value: keyboard),
            BlocProvider.value(value: music),
            BlocProvider.value(value: atmosphere),
            BlocProvider.value(value: importer),
            BlocProvider.value(value: settings),
            BlocProvider.value(value: timer),
          ],
          child: MaterialApp(
            theme: ThemeData(useMaterial3: true),
            builder: (context, child) =>
                WaloneGlassHost(store: appearanceStore, child: child!),
            home: const WorkspacePage(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();
      const appearanceChannel = MethodChannel('dev.soyjanks.walone/appearance');
      final native = await appearanceChannel.invokeMapMethod<String, dynamic>(
        'accessibility',
      );
      final nativeTint = native!['glassTint'] as num?;
      if (Platform.isMacOS) {
        final tint = nativeTint!;
        expect(tint.isFinite && tint >= 0 && tint <= 1, isTrue);
      } else {
        expect(nativeTint, isNull);
      }
      await tester.tap(
        find.descendant(
          of: find.byType(WorkspaceSidebar),
          matching: find.widgetWithText(ListTile, 'Настройки'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AppearanceSettings), findsOneWidget);
      final automaticGlass = find.widgetWithText(
        CheckboxListTile,
        'Автоматически по материалу macOS',
      );
      if (Platform.isMacOS) {
        expect(find.text('Управляется macOS'), findsOneWidget);
        await tester.tap(automaticGlass);
        await tester.pumpAndSettle();
      } else {
        expect(find.text('Управляется macOS'), findsNothing);
        expect(automaticGlass, findsNothing);
      }
      final glassSlider = find.byWidgetPredicate(
        (widget) =>
            widget is GainSlider && widget.label == 'Глубина интерфейса',
      );
      Future<void> dragWithGlass(Finder slider) async {
        final surface = tester.renderObject<RenderGlassSurface>(
          find.byType(GlassSurface).first,
        );
        expect(surface.paintsWithOptics, greaterThan(0));
        final missing = surface.paintsWithoutProxy;
        final sliderThumb = find.descendant(
          of: slider,
          matching: find.byType(CupertinoSlider),
        );
        final gesture = await tester.startGesture(
          tester.getCenter(sliderThumb),
        );
        for (var step = 0; step < 20; step++) {
          await gesture.moveBy(Offset(step < 10 ? 8 : -8, 0));
          await tester.pump(const Duration(milliseconds: 16));
          expect(
            surface.paintsWithoutProxy,
            missing,
            reason: 'Стекло потеряло фон во время drag, кадр $step',
          );
        }
        await gesture.up();
        await tester.pumpAndSettle();
        expect(surface.paintsWithoutProxy, missing);
      }

      await dragWithGlass(glassSlider);
      await dragWithGlass(
        find.byWidgetPredicate(
          (widget) => widget is GainSlider && widget.label == 'Общая громкость',
        ),
      );
      await tester.tapAt(tester.getTopLeft(glassSlider) + const Offset(80, 16));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 300));
      final appearanceState = WaloneGlassHost.maybeOf(
        tester.element(find.byType(AppearanceSettings)),
      )!;
      final manual = appearanceState.transparency(tester.element(glassSlider));
      expect(manual, lessThan(0.3));
      final savedAppearance = await appearanceStore.read();
      expect(savedAppearance!['transparency'], manual);
      if (Platform.isMacOS) {
        expect(savedAppearance['followSystem'], false);
        await tester.tap(automaticGlass);
        await tester.pumpAndSettle();
        expect(appearanceState.followsSystem, isTrue);
        expect(
          appearanceState.transparency(tester.element(glassSlider)),
          native['reduceTransparency'] == true
              ? 0
              : closeTo(1 - nativeTint!, 0.001),
        );
      } else {
        expect(appearanceState.systemAvailable, isFalse);
        expect(appearanceState.followsSystem, isFalse);
        expect(
          appearanceState.transparency(tester.element(glassSlider)),
          manual,
        );
      }
      await tester.tap(
        find.descendant(
          of: find.byType(WorkspaceSidebar),
          matching: find.widgetWithText(ListTile, 'Атмосфера'),
        ),
      );
      await tester.pumpAndSettle();
      debugPrint(
        Platform.isMacOS
            ? 'Native glass: системное значение прочитано; ручное значение сохранено; синхронизация восстановлена'
            : 'Native glass: ручной режим Windows и сохранение значения проверены',
      );
      final volumeBefore = music.state.library.volume;
      final volume = find.byWidgetPredicate(
        (widget) => widget is GainSlider && widget.label == 'Громкость музыки',
      );
      await tester.tapAt(tester.getTopLeft(volume) + const Offset(40, 16));
      await tester.pumpAndSettle();
      expect(music.state.library.volume, isNot(volumeBefore));
      expect(music.state.playing, isTrue);
      await tester.tap(find.byTooltip('Случайный порядок'));
      await tester.pumpAndSettle();
      expect(music.state.library.shuffle, isTrue);
      await tester.tap(find.byTooltip('Повтор выключен'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Повтор плейлиста'), findsOneWidget);
      await tester.tap(find.byTooltip('Повтор плейлиста'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Повтор трека'), findsOneWidget);
      await tester.tap(find.byTooltip('Повтор трека'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Повтор выключен'), findsOneWidget);

      expect(music.state.playing, isTrue);
      await tester.tap(find.text('Пауза всех звуков'));
      await tester.pumpAndSettle();
      expect(atmosphere.state.paused, isTrue);
      expect(music.state.playing, isFalse);
      await tester.tap(find.text('Возобновить все звуки'));
      await tester.pumpAndSettle();
      expect(atmosphere.state.paused, isFalse);
      expect(music.state.playing, isTrue);
      expect(binding.graph.orphans, isEmpty);
      await tester.tap(find.byTooltip('Убрать плеер в левое меню'));
      await tester.pumpAndSettle();
      expect(find.byType(CompactPlayer), findsOneWidget);
      expect(music.state.playing, isTrue);
      final compactMusicVolume = find.descendant(
        of: find.byType(CompactPlayer),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is GainSlider && widget.label == 'Громкость музыки',
        ),
      );
      final compactVolumeBefore = music.state.library.volume;
      await tester.tapAt(
        tester.getTopLeft(compactMusicVolume) +
            Offset(tester.getSize(compactMusicVolume).width * 0.7, 13),
      );
      await tester.pumpAndSettle();
      expect(music.state.library.volume, isNot(compactVolumeBefore));
      expect(music.state.playing, true);
      expect(binding.graph.orphans, isEmpty);

      await tester.tap(find.byTooltip('Пауза музыки'));
      await tester.pumpAndSettle();
      expect(music.state.playing, isFalse);
      await tester.tap(find.byTooltip('Воспроизвести музыку'));
      await tester.pumpAndSettle();
      expect(music.state.playing, isTrue);
      await tester.pump(const Duration(milliseconds: 300));
      expect((await appearanceStore.read())!['compactPlayer'], true);
      await tester.tap(find.byTooltip('Развернуть плеер'));
      await tester.pumpAndSettle();
      expect(find.byType(CompactPlayer), findsNothing);
      expect(music.state.playing, isTrue);
      expect(binding.graph.orphans, isEmpty);
      debugPrint(
        'Compact player: перенос, пауза, воспроизведение, сохранение и разворачивание проверены',
      );
      const desktop = MethodChannel('dev.soyjanks.walone/desktop');
      for (var cycle = 0; cycle < 30; cycle++) {
        if (cycle % 5 == 0) debugPrint('AX stress: цикл $cycle/30');
        for (final title in [
          'Моя музыка',
          'Клавиатура',
          'Настройки',
          'Атмосфера',
        ]) {
          final navigation = find.byType(WorkspaceSidebar).evaluate().isNotEmpty
              ? find.byType(WorkspaceSidebar)
              : find.byType(NavigationBar);
          await tester.tap(
            find.descendant(
              of: navigation,
              matching: find.byType(WorkspaceSidebar).evaluate().isNotEmpty
                  ? find.widgetWithText(ListTile, title)
                  : find.text(title),
            ),
          );
          await tester.pump(const Duration(milliseconds: 350));
          await tester.pump();
          expect(tester.takeException(), isNull);
          expect(binding.graph.orphans, isEmpty, reason: 'Цикл $cycle, $title');
        }
        await atmosphere.setLayer('rain', enabled: cycle.isEven, volume: 0.35);
        await atmosphere.setMaster(cycle.isEven ? 0.5 : 0.6);
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pump();
        if (cycle % 5 == 0) {
          await desktop.invokeMethod<void>('hide');
          await desktop.invokeMethod<void>('show');
          await tester.pump(const Duration(milliseconds: 350));
          await tester.pump();
        }
        expect(
          binding.graph.orphans,
          isEmpty,
          reason: 'Обновление атмосферы $cycle',
        );
      }
      expect(binding.graph.updates, greaterThan(100));
      debugPrint(
        'AX stress: 120 переходов, 30 обновлений микса, ${binding.graph.updates} пакетов, 0 orphan',
      );
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      semantics.dispose();
      await settings.close();
      await timer.close();
      await importer.close();
      await atmosphere.close();
      await music.close();
      await keyboard.close();
      await root.delete(recursive: true);
    }
  }, timeout: const Timeout(Duration(minutes: 3)));
}
