import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walone/core/widgets.dart';

void main() {
  for (final native in [false, true]) {
    for (final selected in [false, true]) {
      testWidgets(
        'Передний план не попадает в размытие панели (native=$native, selected=$selected)',
        (tester) async {
          final boundary = GlobalKey();
          var showForeground = false;
          late StateSetter update;
          await tester.pumpWidget(
            MaterialApp(
              theme: WaloneDesign.theme(Brightness.dark),
              builder: (_, child) => WaloneGlassHost(child: child!),
              home: Scaffold(
                body: Center(
                  child: RepaintBoundary(
                    key: boundary,
                    child: StatefulBuilder(
                      builder: (context, setState) {
                        update = setState;
                        final panel = native
                            ? FrostedPanel(
                                radius: 0,
                                sidebar: !selected,
                                selected: selected,
                                child: const SizedBox.expand(),
                              )
                            : GlassPanel(
                                radius: 0,
                                selected: selected,
                                child: const SizedBox.expand(),
                              );
                        return SizedBox(
                          width: 200,
                          height: 120,
                          child: Stack(
                            children: [
                              Positioned.fill(child: panel),
                              if (showForeground)
                                const Positioned(
                                  left: 80,
                                  top: 50,
                                  width: 40,
                                  height: 20,
                                  child: ColoredBox(color: Colors.white),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          Future<ui.Image> capture() =>
              (boundary.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage();
          final before = (await tester.runAsync(capture))!;
          final baseline = (await tester.runAsync(before.toByteData))!;
          update(() => showForeground = true);
          await tester.pumpAndSettle();
          final after = (await tester.runAsync(capture))!;
          final foreground = (await tester.runAsync(after.toByteData))!;
          var changedOutside = 0;
          for (var y = 0; y < 120; y++) {
            for (var x = 0; x < 200; x++) {
              if (x >= 78 && x < 122 && y >= 48 && y < 72) continue;
              final offset = (y * 200 + x) * 4;
              for (var channel = 0; channel < 3; channel++) {
                if ((foreground.getUint8(offset + channel) -
                            baseline.getUint8(offset + channel))
                        .abs() >
                    2) {
                  changedOutside++;
                  break;
                }
              }
            }
          }
          before.dispose();
          after.dispose();
          expect(
            changedOutside,
            0,
            reason: 'Передний план оставляет размытый ореол в подложке',
          );
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}
