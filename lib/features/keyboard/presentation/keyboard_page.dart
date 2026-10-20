import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_md/flutter_md.dart';

import '../../../core/widgets.dart';
import '../domain/keyboard.dart';
import 'keyboard_cubit.dart';

class KeyboardPage extends StatefulWidget {
  const KeyboardPage({super.key});

  @override
  State<KeyboardPage> createState() => _KeyboardPageState();
}

class _KeyboardPageState extends State<KeyboardPage>
    with WidgetsBindingObserver {
  String _query = '';
  bool _history = false;
  late final TextEditingController _search;
  PageStorageBucket? _storage;
  late final KeyboardCubit _cubit;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController();
    _cubit = context.read<KeyboardCubit>();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_storage != null) return;
    _storage = PageStorage.maybeOf(context);
    final saved = _storage?.readState(context, identifier: 'keyboard-filter');
    if (saved is (String, bool)) {
      _query = saved.$1;
      _history = saved.$2;
      _search.text = _query;
    }
  }

  void _saveFilter() => _storage?.writeState(context, (
    _query,
    _history,
  ), identifier: 'keyboard-filter');

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _search.dispose();
    unawaited(_cubit.stopPreview());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _cubit.refresh();
    } else if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      unawaited(_cubit.stopPreview());
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    appBar: AppBar(
      title: const Text('Клавиатура'),
      actions: [
        TextButton.icon(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => const KeyboardLicensesDialog(),
          ),
          icon: const Icon(Icons.info_outline),
          label: const Text('Источники'),
        ),
        const SizedBox(width: 16),
      ],
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            WaloneDesign.pagePadding,
            16,
            WaloneDesign.pagePadding,
            WaloneDesign.pagePadding,
          ),
          child: BlocBuilder<KeyboardCubit, KeyboardState>(
            builder: (context, state) {
              if (state.loading) {
                return const Center(child: CircularProgressIndicator());
              }
              final query = _query.toLowerCase().trim();
              final byID = {for (final pack in state.packs) pack.id: pack};
              final history = {
                for (final entry in state.history) entry.packID: entry.lastUsed,
              };
              final packs =
                  (_history
                          ? state.history
                                .map((entry) => byID[entry.packID])
                                .whereType<KeyboardPack>()
                          : (state.packs.toList()
                              ..sort((a, b) => a.title.compareTo(b.title))))
                      .where(
                        (pack) => '${pack.title} ${pack.detail}'
                            .toLowerCase()
                            .contains(query),
                      )
                      .toList();
              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SceneBanner(
                          title: 'Звук вашей клавиатуры',
                          subtitle: 'Выберите клавиатуру и печатайте в любом приложении.',
                          icon: Icons.keyboard_outlined,
                        ),
                        const SizedBox(height: 16),
                        KeyboardControls(state: state),
                        const SizedBox(height: 16),
                        SegmentedButton<bool>(
                          showSelectedIcon: false,
                          segments: const [
                            ButtonSegment(
                              value: false,
                              label: Text('Каталог'),
                              icon: Icon(Icons.keyboard_outlined),
                            ),
                            ButtonSegment(
                              value: true,
                              label: Text('История'),
                              icon: Icon(Icons.history),
                            ),
                          ],
                          selected: {_history},
                          onSelectionChanged: (values) {
                            setState(() => _history = values.single);
                            _saveFilter();
                          },
                        ),
                        if (_history) ...[
                          const SizedBox(height: 8),
                          const Text(
                            'Последний выбор каждой клавиатуры · Новые сверху. Прослушивание не меняет историю.',
                          ),
                        ],
                        if (state.historyError != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: SelectableText(
                              state.historyError!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _search,
                          onChanged: (value) {
                            setState(() => _query = value);
                            _saveFilter();
                          },
                          decoration: const InputDecoration(
                            labelText: 'Поиск клавиатуры',
                            prefixIcon: Icon(Icons.search),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _history
                              ? 'В истории: ${packs.length}'
                              : 'Наборов: ${packs.length} · Все записи встроены',
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                  if (packs.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: Text(
                            _history && state.history.isEmpty
                                ? 'История пока пуста. Выберите клавиатуру в каталоге.'
                                : 'Клавиатуры не найдены',
                          ),
                        ),
                      ),
                    )
                  else
                    SliverList.builder(
                      itemCount: packs.length,
                      itemBuilder: (_, index) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: KeyboardPackTile(
                          pack: packs[index],
                          selected: state.selected?.id == packs[index].id,
                          busy: state.busy,
                          previewing: state.previewID == packs[index].id,
                          lastUsed: _history ? history[packs[index].id] : null,
                        ),
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: MediaQuery.paddingOf(context).bottom,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );
}

class KeyboardControls extends StatelessWidget {
  const KeyboardControls({super.key, required this.state});
  final KeyboardState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<KeyboardCubit>();
    final status = state.status;
    final error = state.error ?? status.error;
    final message = status.secureInput
        ? 'Защищённый ввод: озвучивание временно приостановлено'
        : !status.hasPermission
        ? 'Разрешите «Мониторинг ввода» для Walone и перезапустите приложение.'
        : status.listening
        ? 'Глобальные нажатия подключены'
        : 'Глобальные нажатия не подключены';
    return GlassPanel(
      radius: WaloneDesign.cardRadius,
      child: Padding(
        padding: const EdgeInsets.all(WaloneDesign.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (state.selected == null)
              OutlinedButton(
                onPressed: state.busy ? null : cubit.initialize,
                child: const Text('Повторить загрузку'),
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
              title: const Text('Озвучивать нажатия'),
              subtitle: Text(state.selected?.title ?? 'Набор не выбран'),
              value: status.enabled,
              onChanged: state.busy || state.selected == null
                  ? null
                  : (value) => cubit.configure(enabled: value),
            ),
            Text(message),
            if (!status.hasPermission)
              TextButton(
                onPressed: state.busy ? null : cubit.requestPermission,
                child: const Text('Разрешить…'),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  key: const ValueKey('preview-selected'),
                  onPressed: state.busy || state.selected == null
                      ? null
                      : cubit.preview,
                  icon: Icon(
                    state.previewID == state.selected?.id
                        ? Icons.stop
                        : Icons.play_arrow,
                  ),
                  label: Text(
                    state.previewID == state.selected?.id
                        ? 'Остановить'
                        : 'Послушать',
                  ),
                ),
              ],
            ),
            KeyboardVolume(value: state.volume, busy: state.busy),
            ExpansionTile(
              key: const PageStorageKey('keyboard-tryout'),
              maintainState: true,
              tilePadding: const EdgeInsets.symmetric(horizontal: 16),
              childrenPadding: const EdgeInsets.only(bottom: 12),
              shape: const Border(),
              collapsedShape: const Border(),
              title: const Text('Проверить звучание'),
              leading: const Icon(Icons.keyboard_outlined, size: 20),
              children: [
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final entry in [
                      'Буква',
                      'Пробел',
                      'Enter',
                      '⌫',
                    ].asMap().entries)
                      OutlinedButton(
                        onPressed: state.busy || state.selected == null
                            ? null
                            : () => cubit.preview(group: entry.key),
                        child: Text(entry.value),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                const TextField(
                  key: ValueKey('keyboard-typing'),
                  decoration: InputDecoration(
                    labelText: 'Попробуйте печатать',
                    hintText: 'Напишите здесь пару слов…',
                  ),
                ),
                const Text(
                  'Символы и текст не сохраняются. Удержание клавиши не повторяет звук.',
                ),
              ],
            ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(
                error,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class KeyboardVolume extends StatelessWidget {
  const KeyboardVolume({super.key, required this.value, required this.busy});
  final double value;
  final bool busy;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Icon(Icons.volume_up_outlined),
      Expanded(
        child: GainSlider(
          label: 'Громкость клавиатуры',
          value: value,
          onChanged: busy
              ? null
              : (value) =>
                    context.read<KeyboardCubit>().configure(volume: value),
        ),
      ),
    ],
  );
}

class KeyboardPackTile extends StatelessWidget {
  const KeyboardPackTile({
    super.key,
    required this.pack,
    required this.selected,
    required this.busy,
    required this.previewing,
    this.lastUsed,
  });
  final KeyboardPack pack;
  final bool selected;
  final bool busy;
  final bool previewing;
  final DateTime? lastUsed;

  @override
  Widget build(BuildContext context) => GlassPanel(
    radius: WaloneDesign.cardRadius,
    selected: selected,
    child: Padding(
      padding: const EdgeInsets.all(WaloneDesign.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (lastUsed != null)
            Text(
              '${MaterialLocalizations.of(context).formatMediumDate(lastUsed!.toLocal())} · ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(lastUsed!.toLocal()), alwaysUse24HourFormat: true)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          Row(
            children: [
              const Icon(Icons.keyboard_outlined),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  pack.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (selected) const Icon(Icons.check_circle_outline),
            ],
          ),
          const SizedBox(height: 8),
          Text(pack.detail),
          Text('Запись: ${pack.author}'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            children: [
              OutlinedButton.icon(
                key: ValueKey('preview-${pack.id}'),
                onPressed: busy
                    ? null
                    : () => context.read<KeyboardCubit>().preview(pack: pack),
                icon: Icon(previewing ? Icons.stop : Icons.play_arrow),
                label: Text(
                  previewing ? 'Остановить' : 'Послушать',
                  semanticsLabel:
                      '${previewing ? 'Остановить' : 'Послушать'} ${pack.title}',
                ),
              ),
              TextButton(
                key: ValueKey('choose-${pack.id}'),
                onPressed: busy || selected
                    ? null
                    : () => context.read<KeyboardCubit>().choose(pack),
                child: Text(
                  selected ? 'Выбрано' : 'Выбрать',
                  semanticsLabel:
                      '${selected ? 'Выбрано' : 'Выбрать'} ${pack.title}',
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class KeyboardLicensesDialog extends StatefulWidget {
  const KeyboardLicensesDialog({super.key});

  @override
  State<KeyboardLicensesDialog> createState() => _KeyboardLicensesDialogState();
}

class _KeyboardLicensesDialogState extends State<KeyboardLicensesDialog> {
  final _selection = MarkdownSelectionController();
  late final Future<Markdown> _markdown = _loadMarkdown();

  Future<Markdown> _loadMarkdown() async {
    final source = await rootBundle.loadString('assets/licenses/SOURCES.md');
    final markdown = Markdown.fromString(source);
    if (mounted) {
      _selection.setDocuments([
        MarkdownDocumentRef(id: 'licenses', model: markdown, order: 0),
      ]);
    }
    return markdown;
  }

  @override
  void dispose() {
    _selection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => WaloneDialog(
    title: const Text('Источники и лицензии'),
    content: SizedBox(
      width: 680,
      height: 440,
      child: FutureBuilder<Markdown>(
        future: _markdown,
        builder: (_, snapshot) => snapshot.hasError
            ? Text('Не удалось загрузить источники: ${snapshot.error}')
            : !snapshot.hasData
            ? const Text('Загрузка…')
            : MarkdownSelectionScope(
                controller: _selection,
                child: SingleChildScrollView(
                  child: MarkdownWidget(
                    documentId: 'licenses',
                    markdown: snapshot.data!,
                    theme: MarkdownThemeData.mergeTheme(Theme.of(context)),
                  ),
                ),
              ),
      ),
    ),
    actions: [
      FilledButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Закрыть'),
      ),
    ],
  );
}
