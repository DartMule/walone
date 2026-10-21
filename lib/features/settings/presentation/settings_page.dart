import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/widgets.dart';
import '../../sensor/presentation/sensor_panel.dart';
import '../../keyboard/presentation/keyboard_cubit.dart';
import '../../keyboard/presentation/keyboard_page.dart';
import 'settings_cubit.dart';
import 'theme_colors.dart';
import 'windows_update_panel.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    appBar: AppBar(title: const Text('Настройки')),
    body: BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) {
        final settings = context.read<SettingsCubit>();
        return ListView(
          padding: EdgeInsets.fromLTRB(
            WaloneDesign.pagePadding,
            WaloneDesign.cardPadding,
            WaloneDesign.pagePadding,
            WaloneDesign.pagePadding + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            const AppearanceSettings(),
            if (Platform.isWindows) const WindowsUpdatePanel(),
            if (Platform.isMacOS) ...[
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Обновления Walone',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      state.updateReady
                          ? 'Версия ${state.updateVersion} загружена и готова к установке.'
                          : 'Walone загружает обновления в фоне и устанавливает их при выходе. Готовую версию можно установить и перезапустить одной кнопкой.',
                    ),
                    TextButton(
                      onPressed: () => settings.command('checkForUpdates'),
                      child: Text(
                        state.updateReady
                            ? 'Обновить и перезапустить'
                            : 'Проверить обновления…',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Запуск приложения',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  SwitchListTile.adaptive(
                    activeTrackColor: Theme.of(context).colorScheme.primary,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(20)),
                    ),
                    title: const Text('Запускать при входе в систему'),
                    value: state.launchAtLogin,
                    onChanged: state.busy ? null : settings.setLaunchAtLogin,
                  ),
                  const Text(
                    'При входе Walone появится только в трее, без окна. Звук запускается вручную.',
                  ),
                  if (Platform.isWindows)
                    const Text(
                      'Переключатель показывает регистрацию автозапуска. Windows может отдельно отключить её в настройках приложений.',
                    ),
                  if (state.login == LoginStatus.requiresApproval)
                    const Text(
                      'Автозапуск ожидает разрешения в настройках системы.',
                    ),
                  if (state.login == LoginStatus.notFound)
                    const Text(
                      'Система не нашла установленное приложение для автозапуска.',
                    ),
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton(
                        onPressed: () => settings.command('openLoginSettings'),
                        child: const Text('Настройки автозапуска ОС…'),
                      ),
                      TextButton(
                        onPressed: state.busy ? null : settings.refresh,
                        child: const Text('Обновить статус'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    Platform.isMacOS ? 'Строка меню' : 'Системный трей',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Закрытие окна оставляет Walone работать в фоне. Значок позволяет вернуть окно, поставить все звуки на паузу, выбрать набор или завершить приложение.',
                  ),
                  if (!state.trayAvailable)
                    const Text(
                      'Значок недоступен. Окно останется доступным; попробуйте восстановить значок.',
                    ),
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton(
                        onPressed: () => settings.command('restoreTray'),
                        child: const Text('Восстановить значок'),
                      ),
                      TextButton(
                        onPressed: state.trayAvailable
                            ? () => settings.command('hide')
                            : null,
                        child: const Text('Скрыть в трей'),
                      ),
                      TextButton(
                        onPressed: () => settings.command('quit'),
                        child: const Text('Завершить Walone'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const KeyboardDiagnostics(),
            const SizedBox(height: 16),
            const SensorPanel(),
            if (state.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: SelectableText(
                  state.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        );
      },
    ),
  );
}

class AppearanceSettings extends StatelessWidget {
  const AppearanceSettings({super.key});

  @override
  Widget build(BuildContext context) {
    final appearance = WaloneGlassHost.maybeOf(context);
    if (appearance == null) return const SizedBox.shrink();
    final highContrast =
        appearance.increaseContrast || MediaQuery.highContrastOf(context);
    final enabled =
        !highContrast &&
        appearance.ready &&
        !appearance.followsSystem &&
        !appearance.reduceTransparency;
    final value = highContrast ? 0.0 : appearance.transparency(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Тема приложения',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: GlassPanel(
                radius: WaloneDesign.controlRadius,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: SizedBox(
                    width: double.infinity,
                    height:
                        (MediaQuery.textScalerOf(context).scale(14) * 1.5 + 16)
                            .clamp(40.0, double.infinity),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        const modes = [
                          ThemeMode.system,
                          ThemeMode.light,
                          ThemeMode.dark,
                        ];
                        const labels = ['Системная', 'Светлая', 'Тёмная'];
                        final width = constraints.maxWidth / modes.length;
                        return Stack(
                          children: [
                            AnimatedPositioned(
                              duration: MediaQuery.disableAnimationsOf(context)
                                  ? Duration.zero
                                  : WaloneDesign.motion,
                              curve: Curves.easeOutCubic,
                              left: modes.indexOf(appearance.themeMode) * width,
                              top: 0,
                              bottom: 0,
                              width: width,
                              child: const IgnorePointer(
                                child: GlassPanel(
                                  key: ValueKey('theme-selection-bubble'),
                                  radius: WaloneDesign.controlRadius,
                                  child: SizedBox.expand(),
                                ),
                              ),
                            ),
                            Row(
                              children: [
                                for (
                                  var index = 0;
                                  index < modes.length;
                                  index++
                                )
                                  Expanded(
                                    child: Semantics(
                                      selected:
                                          appearance.themeMode == modes[index],
                                      child: TextButton(
                                        style: TextButton.styleFrom(
                                          minimumSize: const Size(
                                            0,
                                            double.infinity,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                          ),
                                          foregroundColor:
                                              appearance.themeMode ==
                                                  modes[index]
                                              ? Theme.of(context)
                                                    .colorScheme
                                                    .primary
                                              : Theme.of(context)
                                                    .colorScheme
                                                    .onSurface,
                                        ),
                                        onPressed: appearance.ready
                                            ? () => appearance.setThemeMode(
                                                modes[index],
                                              )
                                            : null,
                                        child: Text(
                                          labels[index],
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const ThemeColors(),
            const SizedBox(height: 20),
            Text(
              'Материал интерфейса',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Глубина меняет материал, кромку и тени панелей. В тёмной теме объёмные поверхности светлее.',
            ),
            if (appearance.systemAvailable)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('Автоматически по материалу macOS'),
                value: appearance.followsSystem,
                onChanged: appearance.ready
                    ? (value) => appearance.followSystem(value!)
                    : null,
              ),
            const SizedBox(height: 12),
            const Text('Глубина интерфейса'),
            GainSlider(
              label: 'Глубина интерфейса',
              value: value,
              live: true,
              onChanged: enabled ? appearance.setTransparency : null,
            ),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [Text('Плоско'), Text('Объёмно')],
            ),
            const SizedBox(height: 8),
            Text(
              appearance.reduceTransparency
                  ? 'В системе отключена прозрачность. Эффекты объёма отключены; ваше значение сохранено.'
                  : highContrast
                  ? 'В системе включён повышенный контраст. Эффекты объёма отключены; ваше значение сохранено.'
                  : appearance.followsSystem
                  ? 'Управляется macOS'
                  : 'Изменения применяются сразу и сохраняются автоматически.',
            ),
            if (appearance.error != null)
              Text(
                appearance.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
    );
  }
}

class KeyboardDiagnostics extends StatelessWidget {
  const KeyboardDiagnostics({super.key});
  @override
  Widget build(BuildContext context) =>
      BlocBuilder<KeyboardCubit, KeyboardState>(
        builder: (context, state) {
          final status = state.status;
          return SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Подключение и диагностика',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  status.hasPermission
                      ? 'Разрешение на глобальный ввод выдано'
                      : 'Нет разрешения на глобальный ввод',
                ),
                Text(
                  status.listening
                      ? 'Глобальная клавиатура подключена'
                      : 'Глобальная клавиатура не подключена',
                ),
                if (status.secureInput)
                  const Text(
                    'Защищённый ввод: обработка клавиш временно приостановлена',
                  ),
                Text('Получено нажатий: ${status.receivedKeys}'),
                if (status.error != null) SelectableText(status.error!),
                if (state.error != null) SelectableText(state.error!),
                Wrap(
                  spacing: 8,
                  children: [
                    if (Platform.isMacOS)
                      TextButton(
                        onPressed: state.busy
                            ? null
                            : context.read<KeyboardCubit>().requestPermission,
                        child: const Text('Мониторинг ввода…'),
                      ),
                    TextButton(
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (_) => const KeyboardLicensesDialog(),
                      ),
                      child: const Text('Источники и лицензии звуков'),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );
}
