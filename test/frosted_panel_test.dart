import 'package:g1455/g1455.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walone/core/widgets.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('Матовое стекло размывает реальный фон: $brightness', (
      tester,
    ) async {
      const channel = MethodChannel('dev.soyjanks.walone/appearance');
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => <String, dynamic>{},
      );
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final boundary = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: WaloneDesign.theme(brightness),
          builder: (_, child) => WaloneGlassHost(child: child!),
          home: Scaffold(
            body: Center(
              child: RepaintBoundary(
                key: boundary,
                child: SizedBox(
                  width: 200,
                  height: 120,
                  child: Stack(
                    children: [
                      const Positioned.fill(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: ColoredBox(color: Colors.black)),
                            Expanded(child: ColoredBox(color: Colors.white)),
                          ],
                        ),
                      ),
                      const Positioned.fill(
                        child: FrostedPanel(
                          radius: 0,
                          child: SizedBox.expand(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      WaloneGlassHost.maybeOf(tester.element(find.byType(FrostedPanel)))!
          .setTransparency(1);
      await tester.pumpAndSettle();
      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.byType(GlassSurface), findsOneWidget);
      final image = (await tester.runAsync(
        () =>
            (boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage(),
      ))!;
      final bytes = (await tester.runAsync(image.toByteData))!;
      int red(int x) => bytes.getUint8((60 * 200 + x) * 4);
      final left = red(50);
      final right = red(150);
      expect(
        right - left,
        greaterThan(5),
        reason: 'Реальный фон должен просвечивать через материал',
      );
      expect(red(95), greaterThan(left + 1));
      expect(
        red(105),
        lessThan(right - 1),
        reason: 'Граница фона должна размываться',
      );
      image.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets(
    'Прозрачность и контраст отключают размытие и декоративную тень',
    (tester) async {
      const channel = MethodChannel('dev.soyjanks.walone/appearance');
      final messenger = tester.binding.defaultBinaryMessenger;
      var reduce = false;
      var contrast = false;
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => {
          'reduceTransparency': reduce,
          'increaseContrast': contrast,
        },
      );
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      await tester.pumpWidget(
        MaterialApp(
          builder: (_, child) => WaloneGlassHost(child: child!),
          home: const Scaffold(body: FrostedPanel(child: Text('Чёткий текст'))),
        ),
      );
      await tester.pumpAndSettle();
      final appearance = WaloneGlassHost.maybeOf(
        tester.element(find.byType(FrostedPanel)),
      )!;
      final materials = find.descendant(
        of: find.byType(FrostedPanel),
        matching: find.byType(Material),
      );
      void expectOpaque() {
        expect(find.byType(GlassSurface), findsNothing);
        expect(tester.widget<Material>(materials.first).color!.a, 1);
        final decoration =
            tester
                    .widget<DecoratedBox>(
                      find
                          .descendant(
                            of: find.byType(FrostedPanel),
                            matching: find.byType(DecoratedBox),
                          )
                          .first,
                    )
                    .decoration
                as BoxDecoration;
        expect(decoration.boxShadow, isEmpty);
      }

      expect(find.byType(GlassSurface), findsOneWidget);
      appearance.setTransparency(0);
      await tester.pumpAndSettle();
      expectOpaque();
      appearance.setTransparency(0.85);
      await tester.pumpAndSettle();
      expect(find.byType(GlassSurface), findsOneWidget);
      Future<void> refresh() async {
        await messenger.handlePlatformMessage(
          channel.name,
          channel.codec.encodeMethodCall(const MethodCall('changed')),
          (_) {},
        );
        await tester.pumpAndSettle();
      }

      reduce = true;
      await refresh();
      expectOpaque();
      reduce = false;
      contrast = true;
      await refresh();
      expectOpaque();
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
