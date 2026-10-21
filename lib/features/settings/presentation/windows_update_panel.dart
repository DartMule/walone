import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/widgets.dart';
import '../data/windows_updates.dart';
import 'settings_cubit.dart';

Future<void> _install(BuildContext context, WindowsUpdates updates) async {
  updates.restartAfterUpdate = true;
  await context.read<SettingsCubit>().command('quit');
}

class WindowsUpdateButton extends StatelessWidget {
  const WindowsUpdateButton({super.key});

  @override
  Widget build(BuildContext context) {
    final updates = WindowsUpdateScope.maybeOf(context);
    if (updates == null || !updates.ready) return const SizedBox.shrink();
    return IconButton(
      tooltip: 'Обновить до ${updates.release!.version} и перезапустить',
      onPressed: () => _install(context, updates),
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      style: IconButton.styleFrom(
        shape: const CircleBorder(),
        minimumSize: const Size.square(36),
        padding: const EdgeInsets.all(8),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      iconSize: 18,
      icon: const Icon(Icons.arrow_circle_up_rounded),
    );
  }
}

class WindowsUpdatePanel extends StatelessWidget {
  const WindowsUpdatePanel({super.key});

  @override
  Widget build(BuildContext context) {
    final updates = WindowsUpdateScope.maybeOf(context);
    if (updates == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Обновления Walone',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(updates.message),
            if (updates.busy) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(value: updates.progress),
            ],
            TextButton(
              onPressed: updates.busy
                  ? null
                  : () async {
                      if (updates.ready) {
                        await _install(context, updates);
                      } else {
                        await updates.check();
                      }
                    },
              child: Text(
                updates.ready
                    ? 'Обновить и перезапустить'
                    : 'Проверить обновления…',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WindowsUpdateScope extends InheritedNotifier<WindowsUpdates> {
  const WindowsUpdateScope({
    super.key,
    required WindowsUpdates updates,
    required super.child,
  }) : super(notifier: updates);

  static WindowsUpdates? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<WindowsUpdateScope>()
      ?.notifier;
}
