import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walone/features/timer/presentation/timer_readout.dart';

void main() {
  testWidgets(
    'Прокручиваются только изменившиеся разряды без движения двоеточий',
    (tester) async {
      var value = '00:01:10';
      var reduced = false;
      var color = Colors.orange;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: StatefulBuilder(
                builder: (context, setState) {
                  update = setState;
                  return MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(disableAnimations: reduced),
                    child: TimerReadout(
                      value: value,
                      style: TextStyle(fontSize: 54, color: color),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final colon = find.byKey(const ValueKey(('separator', 5)));
      final unchanged = find.byKey(const ValueKey(('digit', 4)));
      final colonPosition = tester.getTopLeft(colon);
      final digitPosition = tester.getTopLeft(unchanged);
      final width = tester.getSize(find.byType(TimerReadout)).width;
      update(() => value = '00:01:09');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 180));
      expect(tester.getTopLeft(colon), colonPosition);
      expect(tester.getTopLeft(unchanged), digitPosition);
      expect(tester.getSize(find.byType(TimerReadout)).width, width);
      // Меняются только десятки и единицы секунд: две пары цифр.
      final rolling = find.descendant(
        of: find.byType(TimerReadout),
        matching: find.byType(FractionalTranslation),
      );
      expect(rolling, findsNWidgets(4));
      final offsets = tester
          .widgetList<FractionalTranslation>(rolling)
          .map((widget) => widget.translation.dy)
          .toList();
      expect(offsets.first, greaterThan(0));
      expect(offsets[1], lessThan(0));
      update(() => color = Colors.green);
      await tester.pump();
      expect(
        tester.widgetList<FractionalTranslation>(rolling).first.translation.dy,
        offsets.first,
      );
      expect(
        tester
            .widgetList<Text>(find.byType(Text))
            .every((text) => text.style?.color == Colors.green),
        isTrue,
      );
      await tester.pumpAndSettle();
      expect(rolling, findsNothing);
      expect(find.text('9'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);

      // При увеличении времени направление прокрутки обратное.
      update(() => value = '00:01:10');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 180));
      expect(
        tester.widgetList<FractionalTranslation>(rolling).first.translation.dy,
        lessThan(0),
      );
      update(() => reduced = true);
      await tester.pumpAndSettle();
      expect(rolling, findsNothing);
      update(() => value = '00:01:11');
      await tester.pumpAndSettle();
      expect(rolling, findsNothing);
      expect(tester.binding.hasScheduledFrame, isFalse);

      // Сброс/смена этапа и длинные значения не прокручивают пропущенные секунды.
      update(() {
        reduced = false;
        value = '123:00:00';
      });
      await tester.pumpAndSettle();
      expect(rolling, findsNothing);
      expect(find.text('3'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
