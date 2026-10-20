import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walone/core/widgets.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('Диалоги сохраняют ввод и действия: $brightness', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(420, 360));
      String? result;
      await tester.pumpWidget(
        MaterialApp(
          theme: WaloneDesign.theme(brightness),
          builder: (_, child) => WaloneGlassHost(child: child!),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async => result = await showDialog<String>(
                  context: context,
                  builder: (_) => const NameDialog(title: 'Название набора'),
                ),
                child: const Text('Открыть'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Открыть'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(WaloneDialog),
          matching: find.byType(FrostedPanel),
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Сохранить'),
            )
            .onPressed,
        isNull,
      );
      await tester.enterText(find.byType(TextField), 'Мой набор');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();
      expect(result, 'Мой набор');
      expect(find.byType(WaloneDialog), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.binding.setSurfaceSize(null);
    });
  }
}
