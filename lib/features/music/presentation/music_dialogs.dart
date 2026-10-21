import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/audio.dart';
import '../../../core/widgets.dart';
import '../../atmosphere/presentation/atmosphere_cubit.dart';
import '../domain/import.dart';
import '../data/import_tools.dart';
import '../domain/music.dart';
import 'import_cubit.dart';
import 'music_cubit.dart';

class MusicImportDialog extends StatefulWidget {
  const MusicImportDialog({super.key});
  @override
  State<MusicImportDialog> createState() => _MusicImportDialogState();
}

class _MusicImportDialogState extends State<MusicImportDialog> {
  final _link = TextEditingController();
  final _limit = TextEditingController(text: '500');
  String? _limitError;
  ImportProvider _provider = ImportProvider.youtube;
  String _youtubeBrowser = '';
  Map<String, bool> _tools = {};
  bool _checking = true;
  String? _linkError;
  String? _checkError;

  @override
  void initState() {
    super.initState();
    _limit.text =
        '${context.read<ImportCubit>().music.repository.library.importLimit}';
    unawaited(_checkTools());
  }

  Future<void> _checkTools() async {
    setState(() {
      _checking = true;
      _checkError = null;
    });
    try {
      final tools = await context.read<ImportCubit>().checkTools();
      if (mounted) setState(() => _tools = tools);
    } catch (_) {
      if (mounted) {
        setState(() => _checkError = 'Не удалось проверить компоненты');
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  void _changed(String text) {
    context.read<ImportCubit>().clearResult();
    setState(() {
      _linkError = null;
      if (text.trim().isEmpty) return;
      try {
        _provider = MusicLink.detect(text).provider;
      } on FormatException catch (error) {
        _linkError = error.message;
      }
    });
  }

  @override
  void dispose() {
    _link.dispose();
    _limit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<ImportCubit, ImportState>(
    builder: (context, state) {
      final cubit = context.read<ImportCubit>();
      final theme = Theme.of(context);
      final needed = requiredImportTools(_provider);
      final ready = !_checking && needed.every((name) => _tools[name] == true);
      return PopScope(
        canPop: !state.busy,
        child: WaloneDialog(
          title: const Text('Импорт музыки'),
          content: SizedBox(
            width: 540,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Вставьте ссылку на запись или плейлист',
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _link,
                    enabled: !state.busy,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    onChanged: _changed,
                    decoration: InputDecoration(
                      labelText: 'HTTPS-ссылка',
                      hintText: 'https://…',
                      prefixIcon: const Icon(Icons.link),
                      errorText: _linkError,
                      errorMaxLines: 3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final (provider, label, icon) in const [
                        (
                          ImportProvider.youtube,
                          'YouTube',
                          Icons.smart_display_outlined,
                        ),
                        (
                          ImportProvider.soundcloud,
                          'SoundCloud',
                          Icons.cloud_outlined,
                        ),
                        (ImportProvider.vk, 'VK', Icons.music_note_outlined),
                        (
                          ImportProvider.spotify,
                          'Spotify',
                          Icons.library_music_outlined,
                        ),
                      ])
                        ChoiceChip(
                          avatar: Icon(icon, size: 18),
                          label: Text(label),
                          selected: _provider == provider,
                          onSelected: state.busy
                              ? null
                              : (_) {
                                  if (_link.text.trim().isEmpty) {
                                    cubit.clearResult();
                                    setState(() => _provider = provider);
                                  } else {
                                    _changed(_link.text);
                                  }
                                },
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Источник определяется автоматически по ссылке',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  Text(switch (_provider) {
                    ImportProvider.youtube => 'Плейлист сохранится отдельным списком. В одиночном видео главы и таймкоды станут треками.',
                    ImportProvider.soundcloud => 'Трек добавится в открытый плейлист, а альбом или плейлист сохранится отдельным списком.',
                    ImportProvider.spotify => 'Названия и исполнители из Spotify будут найдены на YouTube. Совпадения проверяются по названию и длительности; некоторые записи могут быть пропущены.',
                    ImportProvider.vk => 'Для импорта войдите в VK. Можно вставить ссылку на трек, плейлист или раздел «Моя музыка»: https://vk.com/music.',
                  }),
                  if (_provider == ImportProvider.youtube ||
                      _provider == ImportProvider.spotify) ...[
                    const SizedBox(height: 12),
                    DesktopSelect<String>(
                      value: _youtubeBrowser,
                      hint: 'Браузер для входа в YouTube',
                      items: const {
                        '': 'Без cookies браузера',
                        ...youtubeBrowsers,
                      },
                      onChanged: state.busy
                          ? null
                          : (value) {
                              cubit.clearResult();
                              setState(() => _youtubeBrowser = value);
                            },
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Если YouTube просит проверку «не бот», откройте видео в браузере, войдите и пройдите проверку. Выберите этот браузер и повторите импорт. Его cookies будут использованы только для этого импорта. macOS может запросить доступ к Связке ключей или данным браузера.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  if (_provider == ImportProvider.vk)
                    Wrap(
                      spacing: 8,
                      children: [
                        TextButton.icon(
                          onPressed: state.busy ? null : cubit.login,
                          icon: const Icon(Icons.login),
                          label: const Text('Войти в VK'),
                        ),
                        TextButton(
                          onPressed: state.busy ? null : cubit.forget,
                          child: const Text('Удалить вход VK'),
                        ),
                      ],
                    ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _limit,
                    enabled: !state.busy,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() => _limitError = null),
                    decoration: InputDecoration(
                      labelText: 'Максимум треков',
                      helperText:
                          'Первые N треков из списка. 0 — импортировать всё.',
                      errorText: _limitError,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Компоненты для импорта',
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: 10),
                        if (_checking)
                          const Text('Проверяем компоненты…')
                        else ...[
                          for (final name in needed)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Icon(
                                    _tools[name] == true
                                        ? Icons.check_circle_outline
                                        : Icons.download_outlined,
                                    size: 18,
                                    color: _tools[name] == true
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      name == 'javascript'
                                          ? 'JavaScript runtime · Deno / Node.js'
                                          : name == 'ffmpeg'
                                          ? 'FFmpeg'
                                          : name,
                                    ),
                                  ),
                                  Text(
                                    _tools[name] == true ? 'Готов' : 'Нужен',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (!ready)
                                FilledButton.tonalIcon(
                                  onPressed: state.busy
                                      ? null
                                      : () async {
                                          await cubit.installTools(_provider);
                                          if (mounted) await _checkTools();
                                        },
                                  icon: const Icon(Icons.download),
                                  label: const Text('Скачать недостающее'),
                                ),
                              TextButton.icon(
                                onPressed: state.busy ? null : _checkTools,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Проверить снова'),
                              ),
                            ],
                          ),
                          Text(
                            'Компоненты сохраняются в папке Walone на этом компьютере.',
                            style: theme.textTheme.bodySmall,
                          ),
                          if (Platform.isMacOS && _tools['ffmpeg'] != true)
                            Text(
                              'FFmpeg: нативная сборка для вашего Mac от ffmpeg.martin-riedl.de.',
                              style: theme.textTheme.bodySmall,
                            ),
                        ],
                        if (_checkError != null)
                          Text(
                            _checkError!,
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                      ],
                    ),
                  ),
                  if (state.busy) ...[
                    const SizedBox(height: 16),
                    const LinearProgressIndicator(),
                  ],
                  if (state.error != null || state.status.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    SelectableText(
                      state.error ?? state.status,
                      style: TextStyle(
                        color: state.error == null
                            ? null
                            : theme.colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            if (state.busy)
              TextButton(
                onPressed: cubit.cancel,
                child: const Text('Отменить'),
              ),
            OutlinedButton(
              onPressed: state.busy ? null : () => Navigator.pop(context),
              child: const Text('Закрыть'),
            ),
            FilledButton.icon(
              onPressed:
                  state.busy ||
                      !ready ||
                      _link.text.trim().isEmpty ||
                      _linkError != null
                  ? null
                  : () {
                      final limit = int.tryParse(_limit.text.trim());
                      if (limit == null || limit < 0 || limit > 100000) {
                        setState(
                          () => _limitError = 'Введите число от 0 до 100000',
                        );
                        return;
                      }
                      cubit.remote(
                        _provider,
                        _link.text,
                        limit: limit,
                        youtubeBrowser: _youtubeBrowser.isEmpty
                            ? null
                            : _youtubeBrowser,
                        chooseArtist: (name, matches) => showDialog<String>(
                          context: context,
                          barrierDismissible: false,
                          builder: (_) =>
                              ArtistMatchDialog(name: name, matches: matches),
                        ),
                      );
                    },
              icon: const Icon(Icons.playlist_add),
              label: const Text('Импортировать'),
            ),
          ],
        ),
      );
    },
  );
}

class MusicSplitDialog extends StatefulWidget {
  const MusicSplitDialog({
    super.key,
    required this.track,
    required this.playlistID,
  });
  final MusicTrack track;
  final String playlistID;
  @override
  State<MusicSplitDialog> createState() => _MusicSplitDialogState();
}

class _MusicSplitDialogState extends State<MusicSplitDialog> {
  final _marks = TextEditingController();
  late final AudioHandle _audio;
  StreamSubscription<Duration>? _subscription;
  StreamSubscription<void>? _completion;
  StreamSubscription<String>? _errors;
  double _position = 0;
  bool _playing = false;
  bool _ready = false;
  String? _error;
  double? _previewEnd;

  @override
  void initState() {
    super.initState();
    final repository = context.read<MusicCubit>().repository;
    _audio = repository.audioFactory();
    _subscription = _audio.positions.listen((value) {
      if (!mounted) return;
      setState(() => _position = value.inMicroseconds / 1000000);
      if (_previewEnd != null && _position >= _previewEnd!) {
        _previewEnd = null;
        _pause();
      }
    });
    _completion = _audio.completions.listen((_) {
      if (mounted) setState(() => _playing = false);
    });
    _errors = _audio.errors.listen((message) {
      if (mounted) {
        setState(() {
          _error = message;
          _playing = false;
        });
      }
    });
    _load(repository.pathFor(widget.track));
  }

  Future<void> _load(String path) async {
    try {
      await _audio.load(path);
      if (!mounted) return;
      await _audio.setVolume(
        context.read<AtmosphereCubit>().state.master *
            context.read<MusicCubit>().state.library.volume,
      );
      if (mounted) setState(() => _ready = true);
    } catch (_) {
      if (mounted) setState(() => _error = 'Не удалось открыть исходный трек');
    }
  }

  Future<void> _pause() async {
    await _audio.pause();
    if (mounted) setState(() => _playing = false);
  }

  Future<void> _play({AudioSection? section}) async {
    try {
      final atmosphere = context.read<AtmosphereCubit>();
      if (atmosphere.state.paused) await atmosphere.resume();
      if (section != null) {
        await _audio.seek(
          Duration(microseconds: (section.start * 1000000).round()),
        );
        _previewEnd = section.end;
      } else {
        _previewEnd = null;
      }
      await _audio.play();
      if (mounted) setState(() => _playing = true);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Не удалось запустить прослушивание');
      }
    }
  }

  @override
  void dispose() {
    _marks.dispose();
    _subscription?.cancel();
    _completion?.cancel();
    _errors?.cancel();
    unawaited(_audio.dispose());
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocListener<AtmosphereCubit, AtmosphereState>(
    listener: (_, state) {
      if (state.paused) _pause();
      _audio.setVolume(
        state.master * context.read<MusicCubit>().state.library.volume,
      );
    },
    child: BlocBuilder<ImportCubit, ImportState>(
      builder: (context, importing) {
        List<AudioSection> sections = [];
        String? parseError;
        try {
          if (_marks.text.trim().isNotEmpty) {
            sections = AudioSection.parse(_marks.text, widget.track.duration);
          }
        } catch (error) {
          parseError = '$error';
        }
        final cubit = context.read<ImportCubit>();
        return PopScope(
          canPop: !importing.busy,
          child: WaloneDialog(
            title: const Text('Разделить на треки'),
            content: SizedBox(
              width: 640,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.track.title),
                    Text(
                      '${timeLabel(_position)} / ${timeLabel(widget.track.duration)}',
                    ),
                    GainSlider(
                      value: _position,
                      max: widget.track.duration,
                      label: 'Позиция записи',
                      onChanged: _ready && !importing.busy
                          ? (value) => _audio.seek(
                              Duration(microseconds: (value * 1000000).round()),
                            )
                          : null,
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: _ready && !importing.busy
                              ? () => _playing ? _pause() : _play()
                              : null,
                          child: Text(_playing ? 'Пауза' : 'Послушать запись'),
                        ),
                        TextButton(
                          onPressed: importing.busy || !_ready
                              ? null
                              : () => setState(() {
                                  _marks.text +=
                                      '${_marks.text.isEmpty ? '' : '\n'}${timeLabel(_position)} Трек ${sections.length + 1}';
                                }),
                          child: const Text('Поставить границу'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _marks,
                      enabled: !importing.busy,
                      minLines: 5,
                      maxLines: 10,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Таймкоды и названия',
                        hintText: '0:00 Первый трек\n3:20 Второй трек',
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Все фрагменты готовятся до сохранения. Исходник заменится только в выбранном плейлисте.',
                    ),
                    if (parseError != null) Text(parseError),
                    for (final section in sections.take(30))
                      TextButton(
                        onPressed: _ready && !importing.busy
                            ? () => _play(section: section)
                            : null,
                        child: Text(
                          '${timeLabel(section.start)} — ${section.title}',
                        ),
                      ),
                    if (_error != null) Text(_error!),
                    if (importing.busy) const LinearProgressIndicator(),
                    SelectableText(importing.error ?? importing.status),
                  ],
                ),
              ),
            ),
            actions: [
              if (importing.busy)
                TextButton(
                  onPressed: cubit.cancel,
                  child: const Text('Отменить нарезку'),
                ),
              OutlinedButton(
                onPressed: importing.busy ? null : () => Navigator.pop(context),
                child: const Text('Закрыть'),
              ),
              FilledButton(
                onPressed: importing.busy || sections.isEmpty
                    ? null
                    : () async {
                        await _pause();
                        await cubit.split(
                          widget.track,
                          widget.playlistID,
                          _marks.text,
                        );
                        if (context.mounted && cubit.state.error == null) {
                          Navigator.pop(context);
                        }
                      },
                child: const Text('Сохранить нарезку'),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class ArtistMatchDialog extends StatelessWidget {
  const ArtistMatchDialog({
    super.key,
    required this.name,
    required this.matches,
  });
  final String name;
  final List<String> matches;
  @override
  Widget build(BuildContext context) => WaloneDialog(
    title: const Text('Совпадение исполнителя'),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '«$name» отличается от сохранённого имени только регистром. Выбор применяется ко всем трекам с таким именем в этом импорте.',
            ),
            for (final match in matches)
              ListTile(
                title: Text(match),
                subtitle: const Text('Привязать к сохранённому исполнителю'),
                onTap: () => Navigator.pop(context, match),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Отменить импорт'),
      ),
      OutlinedButton(
        onPressed: () => Navigator.pop(context, name),
        child: Text('Создать «$name»'),
      ),
    ],
  );
}

class TrackEditDialog extends StatefulWidget {
  const TrackEditDialog({super.key, required this.artists, this.track});
  final List<String> artists;
  final MusicTrack? track;
  @override
  State<TrackEditDialog> createState() => _TrackEditDialogState();
}

class _TrackEditDialogState extends State<TrackEditDialog> {
  late final _title = TextEditingController(text: widget.track?.title ?? '');
  final _artist = TextEditingController();
  late final _artists = [...?widget.track?.artists];

  void _addArtist(String name) {
    final clean = name.trim();
    if (clean.isEmpty) return;
    setState(() {
      if (!_artists.contains(clean)) _artists.add(clean);
      _artist.clear();
    });
  }

  String? _error;
  @override
  void dispose() {
    _title.dispose();
    _artist.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => WaloneDialog(
    title: Text(
      widget.track == null ? 'Назначить исполнителей' : 'Изменить трек',
    ),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.track != null) ...[
              TextField(
                controller: _title,
                decoration: InputDecoration(
                  labelText: 'Название трека',
                  errorText: _error,
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (_artists.isNotEmpty) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final name in _artists)
                      InputChip(
                        label: Text(name),
                        deleteButtonTooltipMessage: 'Убрать исполнителя $name',
                        onDeleted: () => setState(() => _artists.remove(name)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _artist,
              onSubmitted: _addArtist,
              decoration: InputDecoration(
                labelText: 'Добавить исполнителя',
                helperText:
                    'Одно имя за раз. Enter или кнопка + добавляет в список.',
                helperMaxLines: 2,
                suffixIcon: IconButton(
                  tooltip: 'Добавить исполнителя',
                  onPressed: () => _addArtist(_artist.text),
                  icon: const Icon(Icons.add),
                ),
              ),
            ),
            if (widget.artists.isNotEmpty) ...[
              const SizedBox(height: 12),
              DesktopSelect<String>(
                value: null,
                hint: 'Сохранённые исполнители',
                items: {for (final a in widget.artists) a: a},
                onChanged: _addArtist,
              ),
            ],
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Отмена'),
      ),
      FilledButton(
        onPressed: () {
          if (widget.track != null &&
              (_title.text.trim().isEmpty || _title.text.trim().length > 80)) {
            setState(
              () => _error = 'Название должно содержать от 1 до 80 символов',
            );
            return;
          }
          Navigator.pop(context, (
            title: _title.text.trim(),
            artists: cleanArtistNames([..._artists, _artist.text]),
          ));
        },
        child: const Text('Сохранить'),
      ),
    ],
  );
}
