import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walone/core/widgets.dart';

void main() {
  testWidgets('Глубина заметно меняет поверхность в тёмной теме', (
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
        theme: WaloneDesign.theme(Brightness.dark),
        builder: (_, child) => WaloneGlassHost(child: child!),
        home: RepaintBoundary(
          key: boundary,
          child: const Scaffold(
            body: Center(
              child: FrostedPanel(child: SizedBox(width: 200, height: 120)),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final appearance = WaloneGlassHost.maybeOf(
      tester.element(find.byType(FrostedPanel)),
    )!;
    expect(appearance.ready, isTrue);
    Future<int> sample(double depth) async {
      appearance.setTransparency(depth);
      await tester.pumpAndSettle();
      final image = (await tester.runAsync(
        () =>
            (boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage(),
      ))!;
      final data = (await tester.runAsync(
        () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
      ))!;
      final value = data.getUint8(
        ((image.height ~/ 2) * image.width + image.width ~/ 2) * 4,
      );
      image.dispose();
      return value;
    }

    final flat = await sample(0);
    final raised = await sample(1);
    expect(
      raised - flat,
      greaterThanOrEqualTo(12),
      reason: 'На ровном тёмном фоне глубина должна менять сам материал, а не только невидимую тень',
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
