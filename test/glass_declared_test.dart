import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';
import 'package:walone/core/widgets.dart';

void main() {
  testWidgets('Однотонный фон стекла не требует повторных кадров', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (_, child) => WaloneGlassHost(child: child!),
        home: const Scaffold(
          body: GlassBackdrop.color(
            Colors.white,
            child: FrostedPanel(child: SizedBox(width: 200, height: 120)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 5),
    );
    final declaration = GlassBackdrop.maybeOf(
      tester.element(find.byType(FrostedPanel)),
    )!;
    final renders = declaration.renders;
    await tester.pump(const Duration(milliseconds: 100));
    expect(declaration.renders, renders);
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
