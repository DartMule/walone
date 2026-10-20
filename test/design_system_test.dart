import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';
import 'package:walone/core/widgets.dart';
import 'package:walone/core/sidebar_icon.dart';
import 'package:walone/workspace.dart';

void main() {
  testWidgets('Обновление плеера не перерисовывает его стеклянную панель', (
    tester,
  ) async {
    final progress = ValueNotifier(Colors.red);
    await tester.pumpWidget(
      MaterialApp(
        builder: (_, child) => WaloneGlassHost(child: child!),
        home: Scaffold(
          body: GlassBackdrop.color(
            Colors.white,
            child: WorkspaceSidebar(
              selected: 0,
              onSelected: (_) {},
              player: ValueListenableBuilder<Color>(
                valueListenable: progress,
                builder: (_, color, _) => ColoredBox(
                  color: color,
                  child: const SizedBox(width: 100, height: 50),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final surface = tester.renderObject<RenderGlassSurface>(
      find.descendant(
        of: find.byKey(const ValueKey('sidebar-player-card')),
        matching: find.byType(GlassSurface),
      ),
    );
    int paints() =>
        surface.paintsWithProxy +
        surface.paintsWithoutProxy +
        surface.paintsCheap +
        surface.paintsOpaque;
    final before = paints();
    expect(before, greaterThan(0));
    progress.value = Colors.blue;
    await tester.pump();
    expect(paints(), before);
    await tester.pumpWidget(const SizedBox.shrink());
    progress.dispose();
  });

  for (final reducedMotion in [false, true]) {
    testWidgets('Иконки меню: клики и уменьшение движения=$reducedMotion', (
      tester,
    ) async {
      var selected = 4;
      await tester.pumpWidget(
        MaterialApp(
          builder: (_, child) => MediaQuery(
            data: MediaQueryData(disableAnimations: reducedMotion),
            child: child!,
          ),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (_, update) => WorkspaceSidebar(
                selected: selected,
                onSelected: (value) => update(() => selected = value),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final label in [
        'Атмосфера',
        'Моя музыка',
        'Клавиатура',
        'Настройки',
        'Таймеры',
        'Статистика',
      ]) {
        final tile = find.widgetWithText(ListTile, label);
        double pose() => tester
            .widgetList<CustomPaint>(
              find.descendant(of: tile, matching: find.byType(CustomPaint)),
            )
            .map((paint) => paint.painter)
            .whereType<SidebarIconPainter>()
            .single
            .progress;
        for (var click = 0; click < 2; click++) {
          await tester.tap(tile);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 140));
          expect(tester.widget<ListTile>(tile).selected, isTrue);
          expect(pose(), reducedMotion ? 0 : greaterThan(0));
          // Повторное нажатие во время движения перезапускает анимацию.
          await tester.tap(tile);
          await tester.pumpAndSettle();
          expect(pose(), reducedMotion ? 0 : 1);
        }
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('Меню группирует разделы и закрепляет настройки внизу', (
    tester,
  ) async {
    var selected = 4;
    for (final size in [const Size(1000, 760), const Size(800, 500)]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        MaterialApp(
          theme: WaloneDesign.theme(Brightness.light),
          builder: (_, child) => WaloneGlassHost(child: child!),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, update) => WorkspaceSidebar(
                selected: selected,
                onSelected: (value) => update(() => selected = value),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      const labels = [
        'Таймеры',
        'Статистика',
        'Атмосфера',
        'Моя музыка',
        'Клавиатура',
        'Настройки',
      ];
      const ids = [4, 5, 0, 1, 2, 3];
      Finder tile(String label) => find.widgetWithText(ListTile, label);
      for (var i = 1; i < labels.length; i++) {
        expect(
          tester.getTopLeft(tile(labels[i])).dy,
          greaterThan(tester.getBottomLeft(tile(labels[i - 1])).dy),
        );
      }
      expect(
        tester.getBottomLeft(tile('Настройки')).dy,
        closeTo(size.height - 10, 1),
      );
      for (var i = 0; i < labels.length; i++) {
        await tester.tap(tile(labels[i]));
        await tester.pumpAndSettle();
        expect(selected, ids[i]);
        expect(
          tester
              .getTopLeft(
                find.byKey(const ValueKey('sidebar-selection-bubble')),
              )
              .dy,
          closeTo(tester.getTopLeft(tile(labels[i])).dy, 0.1),
        );
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }
    await tester.binding.setSurfaceSize(null);
  });

  test('Основной и вторичный текст, акцент читаемы в обеих темах', () {
    for (final brightness in Brightness.values) {
      final theme = WaloneDesign.theme(brightness);
      final scheme = theme.colorScheme;
      for (final background in [
        scheme.surface,
        theme.scaffoldBackgroundColor,
        scheme.primaryContainer,
      ]) {
        for (final foreground in [
          scheme.onSurface,
          scheme.onSurfaceVariant,
          scheme.primary,
        ]) {
          expect(
            GlassFinish.contrastRatio(background, foreground),
            greaterThanOrEqualTo(4.5),
          );
        }
      }
      expect(
        GlassFinish.contrastRatio(scheme.primary, scheme.onPrimary),
        greaterThanOrEqualTo(4.5),
      );
    }
  });
}
