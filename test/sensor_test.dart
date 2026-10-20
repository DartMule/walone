import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walone/features/sensor/presentation/sensor_cubit.dart';
import 'package:walone/features/sensor/presentation/sensor_panel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('walone/test/sensor');
  late SensorCubit cubit;
  late List<MethodCall> calls;
  late Map<String, dynamic> values;
  var reject = false;

  setUp(() {
    calls = [];
    reject = false;
    values = {
      'enabled': false,
      'sensitivity': 0.08,
      'stage': 0,
      'collecting': false,
      'intensity': 0.5,
      'processingMS': 6.2,
      'hasCalibration': false,
      'status': 'Нет свежего сигнала — обычный режим',
      'summary': 'Измерений пока нет',
    };
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (reject) {
            throw PlatformException(
              code: 'sensor',
              message: 'Некорректная сводка',
            );
          }
          if (call.method == 'sensorConfigure') {
            values.addAll(Map<String, dynamic>.from(call.arguments as Map));
          }
          return values;
        });
    cubit = SensorCubit(channel: channel);
  });
  tearDown(() async {
    await cubit.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'Датчик включается явно; настройка и отказ сохраняют нативное состояние',
    () async {
      await cubit.initialize();
      expect(calls.single.method, 'sensorStatus');
      expect(cubit.state.enabled, isFalse);
      await cubit.configure(
        enabled: true,
        sensitivity: 0.12,
        stage: 2,
        collecting: true,
      );
      expect(cubit.state.collecting, isTrue);
      expect(cubit.state.stage, 2);
      expect(cubit.state.sensitivity, 0.12);
      reject = true;
      await cubit.command('sensorLoadCalibration');
      expect(cubit.state.error, contains('Некорректная сводка'));
      expect(cubit.state.enabled, isTrue);
      expect(cubit.state.busy, isFalse);
      reject = false;
      await cubit.command('sensorReset');
      expect(cubit.state.error, isNull);
      await cubit.command('sensorExport');
      expect(calls.last.method, 'sensorExport');
    },
  );

  testWidgets('Настройки эксперимента доступны на узком окне', (tester) async {
    tester.view.physicalSize = const Size(560, 680);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await cubit.refresh();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: BlocProvider.value(
              value: cubit,
              child: const SensorControls(),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    expect(cubit.state.enabled, isTrue);
    await tester.ensureVisible(find.text('Собирать амплитуды'));
    await tester.tap(find.byType(Switch).last);
    await tester.pumpAndSettle();
    expect(cubit.state.collecting, isTrue);
    await tester.ensureVisible(find.text('Сохранить сводку…'));
    await tester.tap(find.text('Сохранить сводку…'));
    await tester.pumpAndSettle();
    expect(calls.last.method, 'sensorExport');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
