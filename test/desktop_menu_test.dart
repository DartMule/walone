import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walone/core/widgets.dart';

void main() {
  testWidgets('Селектор выбирает пункт, закрывается по Escape и блокируется', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var value = 'first';
    var enabled = true;
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        theme: WaloneDesign.theme(Brightness.light),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return SizedBox(
                width: 240,
                child: DesktopSelect<String>(
                  value: value,
                  hint: 'Выберите плейлист',
                  items: const {
                    'first': 'Первый плейлист',
                    'second': 'Очень длинное название второго плейлиста',
                  },
                  onChanged: enabled
                      ? (next) => setState(() => value = next)
                      : null,
                ),
              );
            },
          ),
        ),
      ),
    );
    final node = tester.getSemantics(find.byType(DesktopSelect<String>));
    expect(node.getSemanticsData().flagsCollection.isButton, isTrue);
    expect(node.getSemanticsData().hasAction(ui.SemanticsAction.tap), isTrue);
    await tester.tap(find.byType(DesktopSelect<String>));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    await tester.tap(find.text('Очень длинное название второго плейлиста'));
    await tester.pumpAndSettle();
    expect(value, 'second');
    expect(find.byType(DesktopMenuItem<String>), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byType(DesktopSelect<String>));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(DesktopMenuItem<String>), findsNothing);
    expect(value, 'second');

    update(() => enabled = false);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DesktopSelect<String>));
    await tester.pumpAndSettle();
    expect(find.byType(DesktopMenuItem<String>), findsNothing);
    expect(value, 'second');
    expect(
      tester
          .getSemantics(find.byType(DesktopSelect<String>))
          .getSemanticsData()
          .hasAction(ui.SemanticsAction.tap),
      isFalse,
    );
    semantics.dispose();
  });

  testWidgets('Меню передаёт действие удаления и закрывается', (tester) async {
    String? action;
    await tester.pumpWidget(
      MaterialApp(
        theme: WaloneDesign.theme(Brightness.light),
        home: Scaffold(
          body: PopupMenuButton<String>(
            tooltip: 'Действия с треком',
            itemBuilder: (_) => [
              DesktopMenuItem(
                value: 'split',
                label: 'Разделить на треки…',
                icon: Icons.content_cut_rounded,
              ),
              const PopupMenuDivider(height: 9),
              DesktopMenuItem(
                value: 'remove',
                label: 'Убрать из плейлиста',
                icon: Icons.delete_outline_rounded,
                destructive: true,
              ),
            ],
            onSelected: (value) => action = value,
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Действия с треком'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Убрать из плейлиста'));
    await tester.pumpAndSettle();
    expect(action, 'remove');
    expect(find.text('Убрать из плейлиста'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Селектор доступен с клавиатуры после поля ввода', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: WaloneDesign.theme(Brightness.light),
        home: Scaffold(
          body: Column(
            children: [
              const TextField(
                decoration: InputDecoration(labelText: 'Название'),
              ),
              DesktopSelect<String>(
                value: 'first',
                hint: 'Выберите плейлист',
                items: const {
                  'first': 'Первый плейлист',
                  'second': 'Второй плейлист',
                },
                onChanged: (_) {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'Мой набор');
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byType(DesktopMenuItem<String>), findsNWidgets(2));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(DesktopMenuItem<String>), findsNothing);
    expect(find.text('Мой набор'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
