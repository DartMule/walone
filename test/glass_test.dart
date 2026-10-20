import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';
import 'package:walone/core/widgets.dart';
import 'package:walone/core/storage.dart';
import 'package:walone/features/settings/presentation/settings_page.dart';
import 'package:walone/main.dart';
import 'package:walone/workspace.dart';

import 'keyboard_test.dart' show FakeKeyboardRepository;

class MemoryAppearanceStore extends JsonStore {
  MemoryAppearanceStore() : super(File('/unused/appearance.json'));
  Map<String, dynamic>? saved;
  @override
  Future<Map<String, dynamic>?> read() async => saved;
  @override
  Future<void> write(Map<String, dynamic> value) async => saved = value;
}

void main() {
  for (final saved in [
    null,
    <String, dynamic>{'followSystem': true},
    <String, dynamic>{'followSystem': true, 'compactPlayer': false},
    <String, dynamic>{'followSystem': true, 'compactPlayer': true},
  ]) {
    testWidgets('Начальный режим плеера: $saved', (tester) async {
      final store = MemoryAppearanceStore()..saved = saved;
      await tester.pumpWidget(
        MaterialApp(
          home: WaloneGlassHost(store: store, child: const SizedBox.shrink()),
        ),
      );
      await tester.pumpAndSettle();
      final appearance = tester.state<WaloneGlassHostState>(
        find.byType(WaloneGlassHost),
      );
      expect(appearance.compactPlayer, saved?['compactPlayer'] ?? true);
      expect(appearance.useSystemAccentColor, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets(
    'Выделение меню движется между пунктами и учитывает уменьшение движения',
    (tester) async {
      var selected = 0;
      var reduceMotion = false;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          builder: (_, child) => WaloneGlassHost(child: child!),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(disableAnimations: reduceMotion),
                  child: WorkspaceSidebar(
                    selected: selected,
                    onSelected: (value) => setState(() => selected = value),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final bubble = find.byKey(const ValueKey('sidebar-selection-bubble'));
      Finder tile(String label) => find.widgetWithText(ListTile, label);
      final first = tester.getTopLeft(bubble).dy;
      final second = tester.getTopLeft(tile('Моя музыка')).dy;
      await tester.tap(tile('Моя музыка'));
      await tester.pump();
      expect(tester.getTopLeft(bubble).dy, closeTo(first, 0.01));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.getTopLeft(bubble).dy, greaterThan(first));
      expect(tester.getTopLeft(bubble).dy, lessThan(second));
      // Новый выбор во время движения перенаправляет единственный пузырёк.
      await tester.tap(tile('Настройки'));
      await tester.pumpAndSettle();
      expect(bubble, findsOneWidget);
      expect(
        tester.getTopLeft(bubble).dy,
        closeTo(tester.getTopLeft(tile('Настройки')).dy, 0.01),
      );
      update(() => reduceMotion = true);
      await tester.pumpAndSettle();
      await tester.tap(tile('Атмосфера'));
      await tester.pump();
      expect(tester.getTopLeft(bubble).dy, closeTo(first, 0.01));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('Пузырёк темы плавно движется и учитывает уменьшение движения', (
    tester,
  ) async {
    const channel = MethodChannel('dev.soyjanks.walone/appearance');
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => <String, dynamic>{},
    );
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    var reduceMotion = false;
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        builder: (_, child) =>
            WaloneGlassHost(store: MemoryAppearanceStore(), child: child!),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(disableAnimations: reduceMotion),
                child: const AppearanceSettings(),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final appearance = WaloneGlassHost.maybeOf(
      tester.element(find.byType(AppearanceSettings)),
    )!;
    expect(appearance.ready, isTrue);
    final bubble = find.byKey(const ValueKey('theme-selection-bubble'));
    final first = tester.getTopLeft(bubble).dx;
    final width = tester.getSize(bubble).width;
    await tester.tap(find.text('Светлая'));
    expect(appearance.themeMode, ThemeMode.light);
    await tester.pump();
    expect(tester.getTopLeft(bubble).dx, closeTo(first, 0.01));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.getTopLeft(bubble).dx, greaterThan(first));
    expect(tester.getTopLeft(bubble).dx, lessThan(first + width));
    await tester.tap(find.text('Тёмная'));
    await tester.pumpAndSettle();
    expect(bubble, findsOneWidget);
    expect(tester.getTopLeft(bubble).dx, closeTo(first + width * 2, 0.01));
    update(() => reduceMotion = true);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Системная'));
    await tester.pump();
    expect(tester.getTopLeft(bubble).dx, closeTo(first, 0.01));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets(
    'Тема по умолчанию системная; ручной выбор меняет стекло и сохраняется',
    (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      const channel = MethodChannel('dev.soyjanks.walone/appearance');
      final messenger = tester.binding.defaultBinaryMessenger;
      var reduceTransparency = false;
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => {
          'glassTint': 0.15,
          'reduceTransparency': reduceTransparency,
          'increaseContrast': false,
        },
      );
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final store = MemoryAppearanceStore()
        ..saved = {'followSystem': false, 'transparency': 0.5};

      Future<void> openApp() async {
        await tester.pumpWidget(
          WaloneApp(
            keyboardOnly: true,
            repository: FakeKeyboardRepository(),
            appearanceStore: store,
          ),
        );
        await tester.pumpAndSettle();
        final context = tester.element(find.byType(Scaffold).first);
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(
              body: SingleChildScrollView(child: AppearanceSettings()),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      ThemeData theme() =>
          Theme.of(tester.element(find.byType(AppearanceSettings)));
      Future<void> choose(String label) async {
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 250));
        final checkboxInk = tester.widget<InkWell>(
          find
              .descendant(
                of: find.widgetWithText(
                  CheckboxListTile,
                  'Автоматически по материалу macOS',
                ),
                matching: find.byType(InkWell),
              )
              .first,
        );
        expect(
          checkboxInk.customBorder,
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(WaloneDesign.controlRadius),
          ),
        );
        final context = tester.element(find.byType(AppearanceSettings));
        final glass = GlassTheme.of(context);
        final base = GlassFinish.regular(
          appearance: theme().brightness,
          backdrop: theme().scaffoldBackgroundColor,
        );
        expect(glass.finish.tint.r, base.tint.r);
        expect(glass.finish.tint.a, closeTo(0.5, 0.001));
      }

      await openApp();
      for (final label in ['Системная', 'Светлая', 'Тёмная']) {
        expect(find.text(label).hitTestable(), findsOneWidget);
      }
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        ThemeMode.system,
      );
      expect(theme().brightness, Brightness.dark);
      final host = tester.state(find.byType(WaloneGlassHost));
      await choose('Светлая');
      expect(theme().brightness, Brightness.light);
      expect(store.saved!['themeMode'], 'light');
      expect(tester.state(find.byType(WaloneGlassHost)), same(host));
      await choose('Тёмная');
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      await tester.pumpAndSettle();
      expect(theme().brightness, Brightness.dark);
      await choose('Системная');
      expect(theme().brightness, Brightness.light);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await tester.pumpAndSettle();
      expect(theme().brightness, Brightness.dark);
      await choose('Светлая');
      final appearance = WaloneGlassHost.maybeOf(
        tester.element(find.byType(AppearanceSettings)),
      )!;
      final surfaces = find.descendant(
        of: find.byType(AppearanceSettings),
        matching: find.byType(FrostedPanel),
      );
      expect(
        surfaces,
        findsNWidgets(3),
        reason:
            'Карточка, вкладки и пузырёк используют общий стеклянный материал',
      );
      for (final value in [0.0, 0.5, 1.0]) {
        appearance.setTransparency(value);
        await tester.pumpAndSettle();
        for (final element in surfaces.evaluate()) {
          final material = tester.widget<Material>(
            find
                .descendant(
                  of: find.byWidget(element.widget),
                  matching: find.byType(Material),
                )
                .first,
          );
          expect(material.color!.a, value == 0 ? 1 : lessThan(1));
        }
      }
      reduceTransparency = true;
      await messenger.handlePlatformMessage(
        channel.name,
        channel.codec.encodeMethodCall(const MethodCall('changed')),
        (_) {},
      );
      await tester.pumpAndSettle();
      for (final element in surfaces.evaluate()) {
        final material = tester.widget<Material>(
          find
              .descendant(
                of: find.byWidget(element.widget),
                matching: find.byType(Material),
              )
              .first,
        );
        expect(material.color!.a, 1);
      }
      reduceTransparency = false;
      await messenger.handlePlatformMessage(
        channel.name,
        channel.codec.encodeMethodCall(const MethodCall('changed')),
        (_) {},
      );
      await tester.pumpAndSettle();
      appearance.setTransparency(0.5);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await openApp();
      expect(theme().brightness, Brightness.light);
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        ThemeMode.light,
      );
      expect(store.saved!['transparency'], 0.5);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('Системное стекло, ручное значение и приоритет доступности', (
    tester,
  ) async {
    const channel = MethodChannel('dev.soyjanks.walone/appearance');
    final messenger = tester.binding.defaultBinaryMessenger;
    Object? tint = 0.15;
    var reduce = false;
    var contrast = false;
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => {
        'glassTint': tint,
        'reduceTransparency': reduce,
        'increaseContrast': contrast,
      },
    );
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final store = MemoryAppearanceStore();
    Widget application() => MaterialApp(
      builder: (_, child) => WaloneGlassHost(store: store, child: child!),
      home: const Scaffold(
        body: SingleChildScrollView(child: AppearanceSettings()),
      ),
    );
    Future<void> refresh() async {
      await messenger.handlePlatformMessage(
        channel.name,
        channel.codec.encodeMethodCall(const MethodCall('changed')),
        (_) {},
      );
      await tester.pumpAndSettle();
    }

    CupertinoSlider slider() => tester.widget(find.byType(CupertinoSlider));
    await tester.pumpWidget(application());
    await tester.pumpAndSettle();
    expect(find.text('Управляется macOS'), findsOneWidget);
    expect(slider().value, closeTo(0.85, 0.001));
    expect(slider().onChanged, isNull);
    await tester.tap(
      find.widgetWithText(CheckboxListTile, 'Автоматически по материалу macOS'),
    );
    await tester.pumpAndSettle();
    final manualDefault = slider().value;
    final base = GlassFinish.regular(
      appearance: Brightness.light,
      backdrop: ThemeData().scaffoldBackgroundColor,
    );
    expect(manualDefault, closeTo(1 - base.tint.a, 0.001));

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(CupertinoSlider)),
    );
    await gesture.moveBy(const Offset(30, 0));
    await gesture.moveBy(const Offset(60, 0));
    await tester.pump();
    final manual = slider().value;
    expect(manual, isNot(closeTo(manualDefault, 0.01)));
    expect(
      GlassTheme.of(tester.element(find.byType(AppearanceSettings)))
          .finish
          .tint
          .a,
      closeTo(1 - manual, 0.001),
    );
    await gesture.up();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 250));
    expect(store.saved!['transparency'], manual);
    WaloneGlassHost.maybeOf(tester.element(find.byType(AppearanceSettings)))!
        .setCompactPlayer(true);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 250));
    expect(store.saved!['compactPlayer'], true);
    await tester.tap(
      find.widgetWithText(CheckboxListTile, 'Автоматически по материалу macOS'),
    );
    await tester.pumpAndSettle();
    tint = 0.6;
    await refresh();
    expect(slider().value, closeTo(0.4, 0.001));
    reduce = true;
    await refresh();
    expect(slider().value, 0);
    expect(
      tester.widget<GlassHost>(find.byType(GlassHost)).tier.tier,
      GlassTier.opaque,
    );
    await tester.tap(
      find.widgetWithText(CheckboxListTile, 'Автоматически по материалу macOS'),
    );
    await tester.pumpAndSettle();
    expect(slider().onChanged, isNull);
    reduce = false;
    await refresh();
    expect(slider().value, manual);
    contrast = true;
    await refresh();
    expect(slider().onChanged, isNull);
    expect(slider().value, 0);
    contrast = false;
    await refresh();
    expect(slider().value, manual);
    expect(slider().onChanged, isNotNull);
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(application());
    await tester.pumpAndSettle();
    expect(slider().value, manual);
    expect(slider().onChanged, isNotNull);
    expect(
      WaloneGlassHost.maybeOf(tester.element(find.byType(AppearanceSettings)))!
          .compactPlayer,
      true,
    );
    await tester.tap(
      find.widgetWithText(CheckboxListTile, 'Автоматически по материалу macOS'),
    );
    await tester.pumpAndSettle();
    for (final invalid in [null, true, double.nan, -0.1, 1.1, '0.5']) {
      tint = invalid;
      await refresh();
      expect(
        find.widgetWithText(
          CheckboxListTile,
          'Автоматически по материалу macOS',
        ),
        findsNothing,
      );
      expect(slider().value, manual);
      expect(slider().onChanged, isNotNull);
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('Стекло учитывает изменения системной доступности macOS', (
    tester,
  ) async {
    const channel = MethodChannel('dev.soyjanks.walone/appearance');
    var reduceTransparency = true;
    var increaseContrast = true;
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'accessibility');
      return {
        'reduceTransparency': reduceTransparency,
        'increaseContrast': increaseContrast,
      };
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => WaloneGlassHost(child: child!),
        home: const Scaffold(body: GlassPanel(child: Text('Плеер'))),
      ),
    );
    await tester.pumpAndSettle();
    var host = tester.widget<GlassHost>(find.byType(GlassHost));
    expect(host.tier.tier, GlassTier.opaque);
    expect(host.highContrast, isTrue);
    reduceTransparency = false;
    increaseContrast = false;
    await messenger.handlePlatformMessage(
      channel.name,
      channel.codec.encodeMethodCall(const MethodCall('changed')),
      (_) {},
    );
    await tester.pumpAndSettle();
    host = tester.widget<GlassHost>(find.byType(GlassHost));
    expect(host.tier.tier, GlassTier.full);
    expect(host.highContrast, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  for (final brightness in Brightness.values) {
    testWidgets(
      'Карточки и плеер используют читаемый матовый материал: $brightness',
      (tester) async {
        const channel = MethodChannel('dev.soyjanks.walone/appearance');
        final messenger = tester.binding.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(
          channel,
          (_) async => <String, dynamic>{},
        );
        addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
        final theme = WaloneDesign.theme(brightness);
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            builder: (_, child) => WaloneGlassHost(child: child!),
            home: const Scaffold(
              body: Column(
                children: [
                  SectionCard(child: Text('Карточка')),
                  FrostedPanel(child: Text('Плеер')),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final appearance = WaloneGlassHost.maybeOf(
          tester.element(find.byType(SectionCard)),
        )!;
        for (final value in [0.0, 0.25, 0.5, 0.85, 1.0]) {
          appearance.setTransparency(value);
          await tester.pumpAndSettle();
          final materials = find.descendant(
            of: find.byType(FrostedPanel),
            matching: find.byType(Material),
          );
          final card = tester.widget<Material>(materials.first).color!;
          final player = tester.widget<Material>(materials.last).color!;
          expect(card, player);
          expect(card.a, value == 0 ? 1 : lessThan(1));
          for (final backdrop in [Colors.black, Colors.white]) {
            final fill = Color.alphaBlend(card, backdrop);
            for (final foreground in [
              theme.colorScheme.onSurface,
              theme.colorScheme.onSurfaceVariant,
              theme.colorScheme.primary,
            ]) {
              expect(
                GlassFinish.contrastRatio(fill, foreground),
                greaterThanOrEqualTo(4.5),
              );
            }
          }
        }
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
