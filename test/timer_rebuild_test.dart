import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walone/features/timer/presentation/timer_cubit.dart';
import 'package:walone/features/timer/presentation/timer_page.dart';

void main() {
  testWidgets(
    'Промежуточные тики обновляют кольцо, сохраняя элементы управления',
    (tester) async {
      var now = DateTime(2026, 10, 19);
      final timer = TimerCubit(now: () => now);
      addTearDown(() async {
        debugOnRebuildDirtyWidget = null;
        await tester.pumpWidget(const SizedBox.shrink());
        if (!timer.isClosed) await timer.close();
      });
      await tester.pumpWidget(
        BlocProvider.value(
          value: timer,
          child: MaterialApp(home: const TimerPage()),
        ),
      );
      timer.toggle();
      await tester.pump();
      var controls = 0;
      var rings = 0;
      debugOnRebuildDirtyWidget = (element, builtOnce) {
        if (element.widget is SegmentedButton<TimerMode>) controls++;
        if (element.widget.runtimeType.toString() == '_TimerRing') rings++;
      };
      for (var i = 0; i < 5; i++) {
        now = now.add(const Duration(milliseconds: 200));
        timer.tick();
        await tester.pump(const Duration(milliseconds: 200));
      }
      debugPrint('Timer ticks: $controls control builds, $rings ring builds');
      expect(controls, lessThanOrEqualTo(1));
      expect(rings, 5);
      expect(tester.takeException(), isNull);
      debugOnRebuildDirtyWidget = null;
      await tester.pumpWidget(const SizedBox.shrink());
      await timer.close();
    },
  );
}
