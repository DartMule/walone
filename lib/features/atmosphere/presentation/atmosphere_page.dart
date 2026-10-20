import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/widgets.dart';
import '../../keyboard/presentation/keyboard_page.dart';
import '../domain/atmosphere.dart';
import 'atmosphere_cubit.dart';

class AtmospherePage extends StatelessWidget {
  const AtmospherePage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    appBar: AppBar(
      title: const Text('Атмосфера'),
      actions: [
        TextButton(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => const KeyboardLicensesDialog(),
          ),
          child: const Text('Источники'),
        ),
        const SizedBox(width: 16),
      ],
    ),
    body: BlocBuilder<AtmosphereCubit, AtmosphereState>(
      builder: (context, state) {
        final cubit = context.read<AtmosphereCubit>();
        return ListView(
          padding: EdgeInsets.fromLTRB(
            WaloneDesign.pagePadding,
            WaloneDesign.cardPadding,
            WaloneDesign.pagePadding,
            WaloneDesign.pagePadding + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            SceneBanner(
              title: 'Ваш звуковой микс',
              subtitle: 'Выберите звуки и настройте их громкость.',
              icon: Icons.waves_rounded,
              action: FilledButton.icon(
                onPressed: state.mix.layers.values.any((l) => l.enabled)
                    ? cubit.toggleBackground
                    : null,
                icon: Icon(
                  state.running ? Icons.stop_rounded : Icons.play_arrow_rounded,
                ),
                label: Text(state.running ? 'Выключить фон' : 'Включить фон'),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.waves_rounded, size: 18),
                const SizedBox(width: 8),
                const Text('Громкость атмосферы'),
                const SizedBox(width: 12),
                Expanded(
                  child: GainSlider(
                    value: state.backgroundVolume,
                    label: 'Громкость атмосферы',
                    onChanged: cubit.setBackgroundVolume,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    state.paused
                        ? 'Мои наборы · все звуки на паузе'
                        : state.running
                        ? 'Мои наборы · фон включён'
                        : 'Мои наборы',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (state.presets.isEmpty)
                    Text(
                      'Настройте звуки ниже и сохраните свой первый набор.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  if (state.presets.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final preset in state.presets)
                          InputChip(
                            label: Text(
                              '${preset.name}${state.selectedID == preset.id && state.modified ? ' · изменён' : ''}',
                            ),
                            selected: state.selectedID == preset.id,
                            onPressed: () => cubit.selectPreset(preset.id),
                          ),
                      ],
                    ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      TextButton.icon(
                        onPressed: () async {
                          final name = await showDialog<String>(
                            context: context,
                            builder: (_) =>
                                const NameDialog(title: 'Сохранить атмосферу'),
                          );
                          if (name != null) await cubit.savePreset(name);
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Сохранить как новый'),
                      ),
                      if (state.selected != null) ...[
                        if (state.modified)
                          TextButton(
                            onPressed: () => cubit.savePreset(
                              state.selected!.name,
                              id: state.selectedID,
                              update: true,
                            ),
                            child: const Text('Обновить набор'),
                          ),
                        TextButton(
                          onPressed: () async {
                            final name = await showDialog<String>(
                              context: context,
                              builder: (_) => NameDialog(
                                title: 'Переименовать набор',
                                initial: state.selected!.name,
                              ),
                            );
                            if (name != null) {
                              await cubit.savePreset(
                                name,
                                id: state.selectedID,
                              );
                            }
                          },
                          child: const Text('Переименовать'),
                        ),
                        TextButton(
                          onPressed: () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (_) => const ConfirmDialog(
                                title: 'Удалить набор?',
                                message: 'Текущий микс останется доступен.',
                              ),
                            );
                            if (confirmed == true) {
                              await cubit.deletePreset(state.selectedID!);
                            }
                          },
                          child: const Text('Удалить'),
                        ),
                      ],
                      if (state.canUndo)
                        TextButton(
                          onPressed: cubit.undo,
                          child: const Text('Отменить переключение'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Звуки окружения',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 900
                    ? 3
                    : constraints.maxWidth >= 520
                    ? 2
                    : 1;
                final width =
                    (constraints.maxWidth - (columns - 1) * 12) / columns;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final entry in ambientTitles.entries)
                      SizedBox(
                        width: width,
                        child: AmbientLayerCard(
                          id: entry.key,
                          title: entry.value,
                          paused: state.paused,
                          running: state.running,
                          layer:
                              state.mix.layers[entry.key] ?? const SoundLayer(),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            if (state.error != null)
              SelectableText(
                state.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const SizedBox(height: 16),
            const Text(
              'Все звуки доступны без интернета. Наборы также сохраняют выбор и громкость клавиатуры.',
            ),
          ],
        );
      },
    ),
  );
}

class AmbientLayerCard extends StatelessWidget {
  const AmbientLayerCard({
    super.key,
    required this.id,
    required this.title,
    required this.layer,
    this.paused = false,
    this.running = false,
  });
  final String id;
  final String title;
  final SoundLayer layer;
  final bool paused;
  final bool running;
  @override
  Widget build(BuildContext context) => GlassPanel(
    radius: WaloneDesign.cardRadius,
    selected: layer.enabled,
    child: Padding(
      padding: const EdgeInsets.all(WaloneDesign.cardPadding),
      child: Column(
        children: [
          SwitchListTile.adaptive(
            activeTrackColor: Theme.of(context).colorScheme.primary,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(20)),
            ),
            secondary: Icon(
              switch (id) {
                'rain' => Icons.water_drop_outlined,
                'ocean' => Icons.waves_rounded,
                'train' => Icons.train_outlined,
                'cafe' => Icons.local_cafe_outlined,
                'wind' => Icons.air_rounded,
                'birds' || 'seagulls' => Icons.flutter_dash_rounded,
                _ => Icons.graphic_eq_rounded,
              },
              color: layer.enabled
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              layer.enabled
                  ? paused
                        ? 'Выбран · общая пауза'
                        : running
                        ? 'Звучит'
                        : 'Выбран · фон выключен'
                  : id == 'birds' || id == 'seagulls'
                  ? 'Редкие голоса'
                  : 'Непрерывный фон',
            ),
            value: layer.enabled,
            onChanged: (value) =>
                context.read<AtmosphereCubit>().setLayer(id, enabled: value),
          ),
          GainSlider(
            value: layer.volume,
            label: title,
            onChanged: (value) =>
                context.read<AtmosphereCubit>().setLayer(id, volume: value),
          ),
        ],
      ),
    ),
  );
}
