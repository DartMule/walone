import 'package:g1455/g1455.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walone/core/widgets.dart';
import 'package:walone/features/settings/presentation/settings_page.dart';

void main() {
  testWidgets(
    'Вложенные матовые панели сохраняют размытие при перетаскивании ползунков',
    (tester) async {
      const channel = MethodChannel('dev.soyjanks.walone/appearance');
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => {'reduceTransparency': false, 'increaseContrast': false},
      );
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      var volume = 0.5;
      await tester.pumpWidget(
        MaterialApp(
          builder: (_, child) => WaloneGlassHost(child: child!),
          home: Scaffold(
            body: Stack(
              children: [
                const Positioned.fill(
                  child: RepaintBoundary(
                    child: Column(
                      children: [
                        AppearanceSettings(),
                        Expanded(
                          child: GlassPanel(
                            key: ValueKey('underlying-card'),
                            child: Row(
                              children: [
                                Expanded(child: ColoredBox(color: Colors.red)),
                                Expanded(child: ColoredBox(color: Colors.blue)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 20,
                  child: GlassAbove(
                    child: RepaintBoundary(
                      child: FrostedPanel(
                        key: const ValueKey('live-player'),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: StatefulBuilder(
                            builder: (context, setState) => GainSlider(
                              label: 'Проверка громкости',
                              value: volume,
                              onChanged: (value) =>
                                  setState(() => volume = value),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        WaloneGlassHost.maybeOf(
          tester.element(find.byType(AppearanceSettings)),
        )!.ready,
        true,
      );
      expect(find.byType(BackdropFilter), findsNothing);
      final playerSurface = find.descendant(
        of: find.byKey(const ValueKey('live-player')),
        matching: find.byType(GlassSurface),
      );
      expect(playerSurface, findsOneWidget);
      final background = find.descendant(
        of: find.byKey(const ValueKey('underlying-card')),
        matching: find.byType(GlassSurface),
      );
      expect(background, findsOneWidget);
      final sliders = find.byType(GainSlider);
      for (final index in [0, 1]) {
        final initialValue = tester.widget<GainSlider>(sliders.at(index)).value;
        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(CupertinoSlider).at(index)),
        );
        for (var step = 0; step < 15; step++) {
          await gesture.moveBy(Offset(step < 9 ? 30 : -30, 0));
          await tester.pump(const Duration(milliseconds: 16));
          await tester.pump();
          expect(playerSurface, findsOneWidget);
          expect(background, findsOneWidget);
          expect(tester.takeException(), isNull);
        }
        await gesture.up();
        await tester.pumpAndSettle();
        expect(
          tester.widget<GainSlider>(sliders.at(index)).value,
          isNot(initialValue),
        );
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
}
