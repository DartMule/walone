import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';
import 'package:walone/core/widgets.dart';
import 'package:walone/features/settings/presentation/settings_page.dart';
import 'package:walone/main.dart';

import 'glass_test.dart' show MemoryAppearanceStore;
import 'keyboard_test.dart' show FakeKeyboardRepository;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dev.soyjanks.walone/appearance');
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => <String, dynamic>{});
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
  test('Акцент сохраняет контраст в светлой и тёмной теме', () {
    for (final color in [
      ...WaloneDesign.accentColors.values,
      Colors.black,
      Colors.white,
      const Color(0xFF123456),
    ]) {
      for (final brightness in Brightness.values) {
        final theme = WaloneDesign.theme(brightness, accentColor: color);
        final scheme = theme.colorScheme;
        for (final pair in [
          (scheme.primary, scheme.onPrimary),
          (scheme.primaryContainer, scheme.onPrimaryContainer),
          (scheme.surface, scheme.primary),
          (theme.scaffoldBackgroundColor, scheme.primary),
        ]) {
          expect(
            GlassFinish.contrastRatio(pair.$1, pair.$2),
            greaterThanOrEqualTo(4.5),
            reason: '$color, $brightness',
          );
        }
      }
    }
  });

  testWidgets(
    'Выбор цвета обновляет обе темы и сохраняется после перезапуска',
    (tester) async {
      final store = MemoryAppearanceStore();
      Future<void> open() async {
        await tester.pumpWidget(
          WaloneApp(
            keyboardOnly: true,
            repository: FakeKeyboardRepository(),
            appearanceStore: store,
          ),
        );
        await tester.pumpAndSettle();
        Navigator.of(tester.element(find.byType(Scaffold).first)).push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(
              body: SingleChildScrollView(child: AppearanceSettings()),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      Color primary() =>
          Theme.of(tester.element(find.byType(AppearanceSettings)))
              .colorScheme
              .primary;
      WaloneGlassHostState appearance() =>
          tester.state(find.byType(WaloneGlassHost));
      await open();
      expect(appearance().ready, isTrue);
      expect(appearance().useSystemAccentColor, isTrue);
      expect(find.text('Свой цвет'), findsNothing);
      await tester.tap(find.text('Использовать системный цвет'));
      await tester.pumpAndSettle();
      expect(appearance().accentColor, WaloneDesign.defaultAccent);
      await tester.tap(find.text('Светлая'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Зелёный'));
      await tester.pumpAndSettle();
      final green = WaloneDesign.accentColors['Зелёный']!;
      expect(
        primary(),
        WaloneDesign.theme(
          Brightness.light,
          accentColor: green,
        ).colorScheme.primary,
      );
      expect(store.saved!['accentColor'], green.toARGB32());
      await tester.tap(find.text('Тёмная'));
      await tester.pumpAndSettle();
      expect(
        primary(),
        WaloneDesign.theme(
          Brightness.dark,
          accentColor: green,
        ).colorScheme.primary,
      );

      await tester.tap(find.text('Свой цвет'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'bad');
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Применить'),
            )
            .onPressed,
        isNull,
      );
      await tester.enterText(find.byType(TextField), '#123456');
      await tester.pump(const Duration(milliseconds: 300));
      // Предпросмотр не меняет сохранённую тему до подтверждения.
      expect(appearance().accentColor, green);
      await tester.tap(find.text('Применить'));
      await tester.pumpAndSettle();
      const custom = Color(0xFF123456);
      expect(appearance().accentColor, custom);
      expect(store.saved!['accentColor'], custom.toARGB32());
      await tester.tap(find.text('Свой цвет'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'FF0000');
      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();
      expect(appearance().accentColor, custom);
      await tester.pumpWidget(const SizedBox.shrink());
      await open();
      expect(appearance().accentColor, custom);
      expect(
        primary(),
        WaloneDesign.theme(
          Brightness.dark,
          accentColor: custom,
        ).colorScheme.primary,
      );
      await tester.tap(find.byTooltip('Синий'));
      await tester.pumpAndSettle();
      expect(appearance().accentColor, WaloneDesign.defaultAccent);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('Системный цвет скрывает палитру и сохраняет ручной цвет', (
    tester,
  ) async {
    var systemColor = const Color(0xFFE88B35);
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => {'accentColor': systemColor.toARGB32()},
    );
    final store = MemoryAppearanceStore();
    Future<void> open() async {
      await tester.pumpWidget(
        WaloneApp(
          keyboardOnly: true,
          repository: FakeKeyboardRepository(),
          appearanceStore: store,
        ),
      );
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.byType(Scaffold).first)).push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(
            body: SingleChildScrollView(child: AppearanceSettings()),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    WaloneGlassHostState appearance() =>
        tester.state(find.byType(WaloneGlassHost));
    void expectTheme(Color color) {
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(
        app.theme!.colorScheme.primary,
        WaloneDesign.theme(
          Brightness.light,
          accentColor: color,
        ).colorScheme.primary,
      );
      expect(
        app.darkTheme!.colorScheme.primary,
        WaloneDesign.theme(
          Brightness.dark,
          accentColor: color,
        ).colorScheme.primary,
      );
    }

    await open();
    expect(appearance().useSystemAccentColor, isTrue);
    expectTheme(systemColor);
    expect(find.text('Свой цвет'), findsNothing);
    await tester.tap(find.text('Использовать системный цвет'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Зелёный'));
    await tester.pumpAndSettle();
    final manual = appearance().accentColor;
    await tester.tap(find.text('Использовать системный цвет'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byTooltip('Зелёный'), findsNothing);
    expect(find.text('Свой цвет'), findsNothing);
    expect(appearance().accentColor, systemColor);
    expectTheme(systemColor);
    expect(store.saved!['useSystemAccentColor'], isTrue);
    expect(store.saved!['accentColor'], manual.toARGB32());

    systemColor = const Color(0xFFD85D9D);
    await messenger.handlePlatformMessage(
      channel.name,
      channel.codec.encodeMethodCall(const MethodCall('changed')),
      (_) {},
    );
    await tester.pumpAndSettle();
    expectTheme(systemColor);
    await tester.pumpWidget(const SizedBox.shrink());
    await open();
    expect(appearance().useSystemAccentColor, isTrue);
    expect(find.text('Свой цвет'), findsNothing);
    expectTheme(systemColor);
    await tester.tap(find.text('Использовать системный цвет'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byTooltip('Зелёный'), findsOneWidget);
    expect(appearance().accentColor, manual);
    expectTheme(manual);
    expect(store.saved!['useSystemAccentColor'], isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Палитра и диалог помещаются в узком окне с крупным текстом', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 650));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: WaloneDesign.theme(Brightness.light),
        builder: (_, child) => MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
          child: WaloneGlassHost(child: child!),
        ),
        home: const Scaffold(
          body: SingleChildScrollView(child: AppearanceSettings()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Использовать системный цвет'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Свой цвет'));
    await tester.pumpAndSettle();
    expect(find.text('Предпросмотр'), findsOneWidget);
    await tester.drag(find.byType(Slider).first, const Offset(35, 0));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
