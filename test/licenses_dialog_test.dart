import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_md/flutter_md.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walone/features/keyboard/presentation/keyboard_page.dart';

void main() {
  testWidgets('Licenses render Markdown tables and remain scrollable', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => const KeyboardLicensesDialog(),
              ),
              child: const Text('Источники'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Источники'));
    await tester.pumpAndSettle();
    // Asset loading uses real I/O outside the test's fake clock.
    await tester.runAsync(
      () => rootBundle.loadString('assets/licenses/SOURCES.md'),
    );
    await tester.pumpAndSettle();

    final widget = tester.widget<MarkdownWidget>(find.byType(MarkdownWidget));
    expect(widget.markdown.blocks.whereType<MD$Heading>(), isNotEmpty);
    expect(widget.markdown.blocks.whereType<MD$Table>(), isNotEmpty);
    expect(widget.markdown.text, contains('CC BY 4.0'));
    final scope = tester.widget<MarkdownSelectionScope>(
      find.byType(MarkdownSelectionScope),
    );
    scope.controller.selectAll();
    expect(scope.controller.getText(), contains('CC BY 4.0'));

    final scrollable = find.descendant(
      of: find.byType(SingleChildScrollView).last,
      matching: find.byType(Scrollable),
    );
    await tester.drag(
      find.byType(SingleChildScrollView).last,
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    expect(
      tester.state<ScrollableState>(scrollable).position.pixels,
      greaterThan(0),
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Закрыть'));
    await tester.pumpAndSettle();
    expect(find.byType(KeyboardLicensesDialog), findsNothing);
  });
}
