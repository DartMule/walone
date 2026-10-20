import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/widgets.dart';
import 'sensor_cubit.dart';

class SensorPanel extends StatelessWidget {
  const SensorPanel({super.key});

  @override
  Widget build(BuildContext context) => SectionCard(
    child: ExpansionTile(
      key: const PageStorageKey('sensor-experiment'),
      title: const Text('Эксперимент с вибрацией'),
      subtitle: const Text('Чувствительность, калибровка и измерения'),
      children: [
        if (!Platform.isMacOS)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Датчик вибрации встроенной клавиатуры доступен только на совместимых Mac. На Windows работает обычное озвучивание.',
            ),
          )
        else
          BlocProvider(
            create: (_) => SensorCubit()..initialize(),
            child: const SensorControls(),
          ),
      ],
    ),
  );
}

class SensorControls extends StatelessWidget {
  const SensorControls({super.key});

  @override
  Widget build(BuildContext context) => BlocBuilder<SensorCubit, SensorState>(
    builder: (context, state) {
      final cubit = context.read<SensorCubit>();
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Эксперимент измеряет вибрацию корпуса, а не силу отдельной клавиши. Нужен отдельный поток датчика и запуск с --sensor-stdin.',
            ),
            SwitchListTile.adaptive(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(20)),
              ),
              title: const Text('Оценивать вибрацию встроенной клавиатуры'),
              value: state.enabled,
              onChanged: state.busy
                  ? null
                  : (value) => cubit.configure(enabled: value),
            ),
            Text(state.text('status')),
            Text(
              'Полная интенсивность: ${state.sensitivity.toStringAsFixed(3)} g',
            ),
            GainSlider(
              label: 'Чувствительность датчика',
              max: 0.24,
              value: state.sensitivity - 0.01,
              onChanged: state.busy || state.hasCalibration
                  ? null
                  : (value) => cubit.configure(sensitivity: value + 0.01),
            ),
            LinearProgressIndicator(value: state.intensity),
            Text(state.text('calibrationStatus')),
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: state.busy
                      ? null
                      : () => cubit.command('sensorLoadCalibration'),
                  child: const Text('Калибровка из сводки…'),
                ),
                TextButton(
                  onPressed: state.busy || !state.hasCalibration
                      ? null
                      : () => cubit.command('sensorRemoveCalibration'),
                  child: const Text('Убрать калибровку'),
                ),
              ],
            ),
            const Text(
              'Соберите 20–30 отдельных нажатий одной клавиши для каждого режима с выключенным звуком.',
            ),
            SizedBox(
              width: 240,
              child: DesktopSelect<int>(
                value: state.stage,
                hint: 'Режим печати',
                items: const {
                  0: 'Мягкая печать',
                  1: 'Обычная печать',
                  2: 'Сильная печать',
                },
                onChanged: state.busy
                    ? null
                    : (value) => cubit.configure(stage: value),
              ),
            ),
            SwitchListTile.adaptive(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(20)),
              ),
              title: const Text('Собирать амплитуды'),
              value: state.collecting,
              onChanged: state.busy || !state.enabled
                  ? null
                  : (value) => cubit.configure(collecting: value),
            ),
            SelectableText(state.text('summary')),
            Text(state.text('comparison')),
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: state.busy
                      ? null
                      : () => cubit.command('sensorReset'),
                  child: const Text('Сбросить измерения'),
                ),
                TextButton(
                  onPressed: state.busy
                      ? null
                      : () => cubit.command('sensorExport'),
                  child: const Text('Сохранить сводку…'),
                ),
              ],
            ),
            Text(state.text('transport')),
            Text(
              'Последняя обработка: ${((state.values['processingMS'] as num?) ?? 0).toStringAsFixed(1)} мс · слышимая задержка не измерена',
            ),
            if (state.error != null)
              SelectableText(
                state.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      );
    },
  );
}
