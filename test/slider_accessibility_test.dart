import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walone/core/widgets.dart';

import 'semantics_graph.dart';

class AccessibilityBinding extends AutomatedTestWidgetsFlutterBinding {
  final graph = SemanticsGraph();
  @override
  ui.SemanticsUpdateBuilder createSemanticsUpdateBuilder() =>
      RecordingSemanticsBuilder(graph, super.createSemanticsUpdateBuilder());
}

void main() {
  final binding = AccessibilityBinding();
  setUp(() {
    binding.graph.nodes.clear();
    binding.graph.orphans.clear();
  });
  for (final compact in [false, true]) {
    testWidgets(
      'Ползунок (compact=$compact) не откатывается до подтверждения громкости моделью',
      (tester) async {
        var value = 0.4;
        double? requested;
        late StateSetter update;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  update = setState;
                  return GainSlider(
                    value: value,
                    compact: compact,
                    onChanged: (next) => requested = next,
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final slider = find.byType(CupertinoSlider);
        final origin = tester.getTopLeft(slider);
        final size = tester.getSize(slider);
        final drag = await tester.startGesture(
          origin + Offset(size.width * 0.4, size.height / 2),
        );
        await drag.moveBy(const Offset(20, 0));
        await tester.pump();
        await drag.moveBy(const Offset(100, 0));
        await tester.pump();
        final dragged = tester.widget<CupertinoSlider>(slider).value;
        expect(dragged, greaterThan(value));
        expect(
          requested,
          closeTo(dragged, 0.001),
          reason: 'Громкость применяется до отпускания указателя',
        );
        await drag.up();
        await tester.pump(const Duration(milliseconds: 100));
        expect(requested, closeTo(dragged, 0.001));
        expect(
          tester.widget<CupertinoSlider>(slider).value,
          closeTo(dragged, 0.001),
        );
        // Пока звук и сохранение заняты, посторонняя перерисовка не сбрасывает выбор.
        update(() {});
        await tester.pump();
        expect(
          tester.widget<CupertinoSlider>(slider).value,
          closeTo(dragged, 0.001),
        );
        update(() => value = requested!);
        await tester.pumpAndSettle();
        expect(
          tester.widget<CupertinoSlider>(slider).value,
          closeTo(dragged, 0.001),
        );
        // После подтверждения внешнее изменение снова управляет ползунком.
        update(() => value = 0.2);
        await tester.pumpAndSettle();
        expect(tester.widget<CupertinoSlider>(slider).value, 0.2);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('Компактный ползунок сохраняет клики, стрелки и доступность', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var value = 0.4;
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 184,
                child: StatefulBuilder(
                  builder: (context, setState) => GainSlider(
                    value: value,
                    compact: true,
                    showValue: false,
                    label: 'Тихий уровень',
                    onChanged: (next) => setState(() => value = next),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final slider = find.byType(GainSlider);
      await tester.tapAt(
        tester.getTopLeft(slider) +
            Offset(tester.getSize(slider).width * 0.75, 13),
      );
      await tester.pumpAndSettle();
      expect(value, closeTo(0.75, 0.02));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(value, closeTo(0.70, 0.02));
      final node = tester.getSemantics(find.bySemanticsLabel('Тихий уровень'));
      expect(node.getSemanticsData().flagsCollection.isSlider, true);
      node.owner!.performAction(node.id, ui.SemanticsAction.increase);
      await tester.pump();
      expect(value, greaterThan(0.70));
      Color focusBorder() =>
          (tester
                      .widget<DecoratedBox>(
                        find
                            .descendant(
                              of: slider,
                              matching: find.byType(DecoratedBox),
                            )
                            .first,
                      )
                      .decoration
                  as BoxDecoration)
              .border!
              .top
              .color;
      expect(focusBorder().a, greaterThan(0));
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(
        focusBorder(),
        Colors.transparent,
        reason: 'Клик по пустому месту должен убрать рамку ползунка',
      );
      expect(binding.graph.orphans, isEmpty);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      semantics.dispose();
    }
  });

  testWidgets(
    'Слайдер сохраняет доступность, стрелки и запись по окончании drag',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final changed = <double>[];
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: GainSlider(
                value: 0.4,
                live: false,
                label: 'Уровень',
                onChanged: changed.add,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        var node = tester.getSemantics(find.bySemanticsLabel('Уровень'));
        expect(node.getSemanticsData().flagsCollection.isSlider, isTrue);
        expect(
          node.getSemanticsData().hasAction(ui.SemanticsAction.increase),
          isTrue,
        );
        node.owner!.performAction(node.id, ui.SemanticsAction.increase);
        await tester.pump();
        expect(changed.single, greaterThan(0.4));
        node = tester.getSemantics(find.bySemanticsLabel('Уровень'));
        node.owner!.performAction(node.id, ui.SemanticsAction.decrease);
        await tester.pump();
        expect(changed.last, closeTo(0.4, 0.0001));
        final focus = tester
            .widget<Focus>(
              find
                  .ancestor(
                    of: find.byType(CupertinoSlider),
                    matching: find.byType(Focus),
                  )
                  .first,
            )
            .focusNode!;
        focus.requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();
        expect(changed.last, closeTo(0.45, 0.0001));
        changed.clear();
        final slider = find.byType(CupertinoSlider);
        final size = tester.getSize(slider);
        final drag = await tester.startGesture(
          tester.getTopLeft(slider) +
              Offset(size.width * 0.45, size.height / 2),
        );
        await drag.moveBy(const Offset(50, 0));
        await tester.pump();
        expect(changed, isEmpty);
        await drag.up();
        await tester.pumpAndSettle();
        expect(changed, hasLength(1));
        await tester.tapAt(
          tester.getTopLeft(slider) + Offset(size.width * 0.8, size.height / 2),
        );
        await tester.pumpAndSettle();
        expect(changed.last, closeTo(0.8, 0.0001));
        changed.clear();
        final trackDrag = await tester.startGesture(
          tester.getTopLeft(slider) + Offset(size.width * 0.2, size.height / 2),
        );
        await trackDrag.moveBy(const Offset(30, 0));
        await tester.pump();
        await trackDrag.moveTo(
          tester.getTopLeft(slider) + Offset(size.width * 0.5, size.height / 2),
        );
        await tester.pump();
        expect(changed, isEmpty);
        await trackDrag.up();
        await tester.pumpAndSettle();
        expect(changed, hasLength(1));
        expect(changed.single, closeTo(0.5, 0.0001));
        expect(binding.graph.orphans, isEmpty);
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: GainSlider(value: 0.4, label: 'Выключен', onChanged: null),
            ),
          ),
        );
        await tester.pumpAndSettle();
        node = tester.getSemantics(find.bySemanticsLabel('Выключен'));
        expect(
          node.getSemanticsData().hasAction(ui.SemanticsAction.increase),
          isFalse,
        );
      } finally {
        semantics.dispose();
      }
    },
  );
  testWidgets('Слайдер в новом маршруте не отправляет осиротевшие AX-узлы', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => Scaffold(
                      body: GainSlider(value: 0.4, onChanged: (_) {}),
                    ),
                  ),
                ),
                child: const Text('Открыть'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Открыть'));
      await tester.pumpAndSettle();
      expect(
        binding.graph.orphans,
        isEmpty,
        reason: 'Каждый отправленный AX-узел должен быть связан с корнем',
      );
    } finally {
      semantics.dispose();
    }
  });
}
