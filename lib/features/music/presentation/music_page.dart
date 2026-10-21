import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/widgets.dart';
import '../../atmosphere/presentation/atmosphere_cubit.dart';
import '../domain/music.dart';
import 'import_cubit.dart';
import 'music_cubit.dart';
import 'music_dialogs.dart';

class MusicPage extends StatefulWidget {
  const MusicPage({super.key});

  @override
  State<MusicPage> createState() => MusicPageState();
}

class MusicPageState extends State<MusicPage> {
  final _scroll = ScrollController();
  final _currentTrack = GlobalKey();
  int _revealRequest = 0;
  int _searchRevision = 0;
  final _selected = <String>{};
  String _query = '';
  bool _selecting = false;
  String? _selectionView;
  int? _anchor;

  void _toggle(List<MusicTrack> tracks, int index, bool value) => setState(() {
    if (HardwareKeyboard.instance.isShiftPressed &&
        _anchor != null &&
        _anchor! < tracks.length) {
      final start = index < _anchor! ? index : _anchor!;
      final end = index > _anchor! ? index : _anchor!;
      for (var i = start; i <= end; i++) {
        if (value) {
          _selected.add(tracks[i].id);
        } else {
          _selected.remove(tracks[i].id);
        }
      }
    } else if (value) {
      _selected.add(tracks[index].id);
    } else {
      _selected.remove(tracks[index].id);
    }
    _anchor = index;
  });

  Future<void> _batch(String action, MusicLibrary library) async {
    final cubit = context.read<MusicCubit>();
    final ids = Set<String>.of(_selected);
    if (ids.isEmpty) return;
    if (action == 'artist') {
      final result = await showDialog<({String title, List<String> artists})>(
        context: context,
        builder: (_) => TrackEditDialog(artists: library.artists),
      );
      if (result != null) await cubit.editTracks(ids, artists: result.artists);
    } else if (action == 'add') {
      final destination = await showDialog<String>(
        context: context,
        builder: (dialogContext) => WaloneDialog(
          title: const Text('Добавить в плейлист'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final p in library.playlists)
                    ListTile(
                      title: Text(p.name),
                      onTap: () => Navigator.pop(dialogContext, p.id),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Отмена'),
            ),
          ],
        ),
      );
      if (destination != null) await cubit.addToPlaylist(ids, destination);
    } else {
      final delete = action == 'delete';
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => ConfirmDialog(
          title: delete
              ? 'Удалить выбранные треки из медиатеки?'
              : 'Убрать выбранные треки из плейлиста?',
          message: delete
              ? 'Локальные копии будут удалены из всех плейлистов. Исходные файлы останутся.'
              : 'Треки останутся в разделе «Все треки».',
        ),
      );
      if (confirmed == true) {
        await cubit.removeTracks(
          ids,
          playlistID: delete ? null : library.selectedID,
        );
      }
    }
    if (mounted) setState(() => _selected.clear());
  }

  Future<void> revealCurrentTrack() async {
    final request = ++_revealRequest;
    final cubit = context.read<MusicCubit>();
    final library = cubit.state.library;
    if (library.trackID == null || library.playingID == null) return;
    if (library.selectedID != library.playingID) {
      await cubit.select(library.playingID!);
    }
    if (mounted) {
      setState(() {
        _query = '';
        _searchRevision++;
      });
    }
    var reset = _currentTrack.currentContext == null;
    void reveal(Duration _) {
      if (!mounted || request != _revealRequest || !_scroll.hasClients) return;
      if (cubit.state.library.trackID != library.trackID ||
          cubit.state.library.selectedID != library.playingID) {
        return;
      }
      if (reset) {
        _scroll.jumpTo(0);
        reset = false;
      } else {
        final target = _currentTrack.currentContext;
        if (target != null) {
          Scrollable.ensureVisible(
            target,
            alignment: 0.1,
            duration: const Duration(milliseconds: 250),
          );
          return;
        }
        // ponytail: проход по экранам поддерживает строки любой высоты.
        // Для огромных плейлистов заменить на список с прокруткой по индексу.
        final position = _scroll.position;
        final next = (position.pixels + position.viewportDimension).clamp(
          0.0,
          position.maxScrollExtent,
        );
        if (next <= position.pixels) return;
        _scroll.jumpTo(next);
      }
      WidgetsBinding.instance.addPostFrameCallback(reveal);
      WidgetsBinding.instance.scheduleFrame();
    }

    if (!mounted || request != _revealRequest) return;
    WidgetsBinding.instance.addPostFrameCallback(reveal);
    WidgetsBinding.instance.scheduleFrame();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<String?> _chooseArtist(String name, List<String> matches) =>
      showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (_) => ArtistMatchDialog(name: name, matches: matches),
      );

  Future<void> _name(BuildContext context, {MusicPlaylist? playlist}) async {
    final cubit = context.read<MusicCubit>();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => NameDialog(
        title: playlist == null ? 'Новый плейлист' : 'Переименовать плейлист',
        initial: playlist?.name ?? '',
      ),
    );
    if (name != null) await cubit.savePlaylist(name, id: playlist?.id);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    appBar: AppBar(title: const Text('Моя музыка')),
    body: BlocBuilder<MusicCubit, MusicState>(
      buildWhen: _musicContentChanged,
      builder: (context, state) {
        final cubit = context.read<MusicCubit>();
        final importer = context.read<ImportCubit>();
        final library = state.library;
        final playlist =
            library.playlist(library.selectedID) ??
            library.playlist(allMusicID)!;
        final savedPlaylist = library.isSavedPlaylist(playlist.id);
        if (_selectionView != playlist.id) {
          _query = '';
          _searchRevision++;
          _selected.clear();
          _anchor = null;
          _selectionView = playlist.id;
        }
        _selected.retainAll(library.tracks.map((t) => t.id));
        final query = _query.toLowerCase();
        final tracks = library
            .tracksIn(playlist.id)
            .where(
              (t) => '${t.title} ${t.artist}'.toLowerCase().contains(query),
            )
            .toList();
        final reorderable = savedPlaylist && _query.isEmpty && !_selecting;
        final artistView = library.artists
            .where((a) => artistMusicID(a) == playlist.id)
            .firstOrNull;
        return DropTarget(
          enable: !state.importing,
          onDragDone: (details) => importer.files(
            details.files.map((f) => f.path).toList(),
            chooseArtist: _chooseArtist,
          ),
          child: CustomScrollView(
            controller: _scroll,
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  WaloneDesign.pagePadding,
                  16,
                  WaloneDesign.pagePadding,
                  16,
                ),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SceneBanner(
                        title: 'Ваша медиатека',
                        subtitle: 'Добавляйте файлы или импортируйте записи по ссылке.',
                        icon: Icons.library_music_outlined,
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 300),
                            child: DesktopSelect<String>(
                              value: playlist.id,
                              hint: 'Выберите плейлист',
                              items: {
                                allMusicID: 'Все треки',
                                playlist.id: ?artistView,
                                for (final p in library.playlists) p.id: p.name,
                              },
                              onChanged: cubit.select,
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () async {
                              final artist = await showDialog<String>(
                                context: context,
                                builder: (dialogContext) => WaloneDialog(
                                  title: const Text('Исполнители'),
                                  content: SizedBox(
                                    width: 420,
                                    child: SingleChildScrollView(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (library.artists.isEmpty)
                                            const Text(
                                              'Исполнители появятся после импорта или редактирования треков.',
                                            ),
                                          for (final a
                                              in (library.artists.toList()
                                                ..sort(
                                                  (a, b) =>
                                                      a.toLowerCase().compareTo(
                                                        b.toLowerCase(),
                                                      ),
                                                )))
                                            ListTile(
                                              title: Text(a),
                                              subtitle: Text(
                                                '${library.tracks.where((t) => t.artists.contains(a)).length} треков',
                                              ),
                                              onTap: () => Navigator.pop(
                                                dialogContext,
                                                a,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(dialogContext),
                                      child: const Text('Закрыть'),
                                    ),
                                  ],
                                ),
                              );
                              if (artist != null) {
                                await cubit.select(artistMusicID(artist));
                              }
                            },
                            icon: const Icon(Icons.person_outline),
                            label: const Text('Исполнители'),
                          ),
                          if (artistView != null)
                            OutlinedButton.icon(
                              onPressed: state.importing
                                  ? null
                                  : () => cubit.artistPlaylist(artistView),
                              icon: const Icon(Icons.playlist_add),
                              label: const Text('Плейлист исполнителя'),
                            ),
                          OutlinedButton.icon(
                            onPressed: state.importing
                                ? null
                                : () => _name(context),
                            icon: const Icon(Icons.playlist_add),
                            label: const Text('Новый плейлист'),
                          ),
                          if (savedPlaylist)
                            PopupMenuButton<String>(
                              tooltip: 'Действия с плейлистом',
                              icon: const Icon(
                                Icons.more_horiz_rounded,
                                size: 20,
                              ),
                              enabled: !state.importing,
                              itemBuilder: (_) => [
                                DesktopMenuItem(
                                  value: 'rename',
                                  label: 'Переименовать',
                                  icon: Icons.edit_outlined,
                                ),
                                const PopupMenuDivider(height: 9),
                                DesktopMenuItem(
                                  value: 'delete',
                                  label: 'Удалить плейлист',
                                  icon: Icons.delete_outline_rounded,
                                  destructive: true,
                                ),
                              ],
                              onSelected: (action) async {
                                if (action == 'rename') {
                                  await _name(context, playlist: playlist);
                                } else {
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (_) => ConfirmDialog(
                                      title: 'Удалить «${playlist.name}»?',
                                      message: 'Треки останутся в разделе «Все треки».',
                                    ),
                                  );
                                  if (confirmed == true) {
                                    await cubit.deletePlaylist(playlist.id);
                                  }
                                }
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.tonalIcon(
                            onPressed: state.importing
                                ? null
                                : () async {
                                    final files = await openFiles(
                                      acceptedTypeGroups: const [
                                        XTypeGroup(
                                          label: 'Аудио',
                                          extensions: [
                                            'mp3',
                                            'wav',
                                            'flac',
                                            'm4a',
                                            'aac',
                                            'ogg',
                                            'opus',
                                            'wma',
                                            'aiff',
                                            'aif',
                                            'mp4',
                                            'webm',
                                          ],
                                        ),
                                      ],
                                    );
                                    if (files.isNotEmpty) {
                                      await importer.files(
                                        files.map((f) => f.path).toList(),
                                        chooseArtist: _chooseArtist,
                                      );
                                    }
                                  },
                            icon: const Icon(Icons.add),
                            label: const Text('Добавить файлы'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => showDialog<void>(
                              context: context,
                              builder: (_) => BlocProvider.value(
                                value: importer,
                                child: const MusicImportDialog(),
                              ),
                            ),
                            icon: const Icon(Icons.link),
                            label: const Text('Импорт по ссылке'),
                          ),
                          OutlinedButton.icon(
                            onPressed: state.importing
                                ? null
                                : () async {
                                    final file = await openFile(
                                      acceptedTypeGroups: const [
                                        XTypeGroup(
                                          label: 'Архив медиатеки Walone',
                                          extensions: ['zip'],
                                        ),
                                      ],
                                    );
                                    if (file != null) {
                                      await importer.importArchive(
                                        file.path,
                                        chooseArtist: _chooseArtist,
                                      );
                                    }
                                  },
                            icon: const Icon(Icons.unarchive_outlined),
                            label: const Text('Импорт архива'),
                          ),
                          OutlinedButton.icon(
                            onPressed:
                                state.importing ||
                                    library.playlists.isEmpty &&
                                        library.tracks.isEmpty
                                ? null
                                : () async {
                                    final location = await getSaveLocation(
                                      suggestedName: 'Walone-music.zip',
                                      acceptedTypeGroups: const [
                                        XTypeGroup(
                                          label: 'Архив медиатеки Walone',
                                          extensions: ['zip'],
                                        ),
                                      ],
                                    );
                                    if (location != null) {
                                      await importer.exportArchive(
                                        location.path,
                                      );
                                    }
                                  },
                            icon: const Icon(Icons.archive_outlined),
                            label: const Text('Экспорт медиатеки'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text('${playlist.name} · ${tracks.length} треков'),
                      const SizedBox(height: 12),
                      TextField(
                        key: ValueKey('music-search-$_searchRevision'),
                        decoration: const InputDecoration(
                          labelText: 'Поиск по названию и исполнителю',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: (value) => setState(() {
                          _query = value;
                          _anchor = null;
                        }),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          TextButton.icon(
                            onPressed: state.importing
                                ? null
                                : () => setState(() {
                                    _selecting = !_selecting;
                                    _selected.clear();
                                    _anchor = null;
                                  }),
                            icon: Icon(
                              _selecting ? Icons.close : Icons.checklist,
                            ),
                            label: Text(
                              _selecting
                                  ? 'Закончить выделение'
                                  : 'Выделить треки',
                            ),
                          ),
                          if (_selecting) ...[
                            TextButton(
                              onPressed: () => setState(() {
                                _selected.addAll(tracks.map((t) => t.id));
                              }),
                              child: const Text('Выделить все'),
                            ),
                            Text('Выбрано: ${_selected.length}'),
                            PopupMenuButton<String>(
                              tooltip: 'Действия с выбранными',
                              enabled: _selected.isNotEmpty && !state.importing,
                              onSelected: (action) => _batch(action, library),
                              itemBuilder: (_) => [
                                if (library.playlists.isNotEmpty)
                                  const PopupMenuItem(
                                    value: 'add',
                                    child: Text('Добавить в плейлист'),
                                  ),
                                const PopupMenuItem(
                                  value: 'artist',
                                  child: Text('Назначить исполнителей'),
                                ),
                                if (savedPlaylist)
                                  const PopupMenuItem(
                                    value: 'remove',
                                    child: Text('Убрать из плейлиста'),
                                  ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Удалить из медиатеки'),
                                ),
                              ],
                              child: const Padding(
                                padding: EdgeInsets.all(8),
                                child: Text('Действия с выбранными'),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (state.error != null)
                        SelectableText(
                          state.error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      BlocBuilder<ImportCubit, ImportState>(
                        builder: (context, state) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (state.busy) const LinearProgressIndicator(),
                            if (state.status.isNotEmpty || state.error != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: SelectableText(
                                  state.error ?? state.status,
                                ),
                              ),
                            if (state.busy)
                              TextButton(
                                onPressed: importer.cancel,
                                child: const Text('Отменить операцию'),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (tracks.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'Нет треков. Добавьте музыку или измените поисковый запрос.',
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverReorderableList(
                    itemCount: tracks.length,
                    onReorderItem: (from, to) {
                      if (reorderable) {
                        cubit.reorder(
                          playlist.id,
                          from,
                          to > from ? to + 1 : to,
                        );
                      }
                    },
                    itemBuilder: (context, index) => Padding(
                      key: ValueKey(tracks[index].id),
                      padding: const EdgeInsets.only(bottom: 8),
                      child: MusicTrackTile(
                        key:
                            tracks[index].id == library.trackID &&
                                library.selectedID == library.playingID
                            ? _currentTrack
                            : null,
                        track: tracks[index],
                        playlist: playlist,
                        reorderable: reorderable,
                        selecting: _selecting,
                        selected: _selected.contains(tracks[index].id),
                        onSelect: (value) => _toggle(tracks, index, value),
                        index: index,
                        state: state,
                      ),
                    ),
                  ),
                ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 24 + MediaQuery.paddingOf(context).bottom,
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class MusicTrackTile extends StatelessWidget {
  const MusicTrackTile({
    super.key,
    required this.track,
    required this.playlist,
    required this.index,
    required this.state,
    this.reorderable = true,
    this.selecting = false,
    this.selected = false,
    this.onSelect,
  });
  final bool reorderable, selecting, selected;
  final ValueChanged<bool>? onSelect;
  final MusicTrack track;
  final MusicPlaylist playlist;
  final int index;
  final MusicState state;
  @override
  Widget build(BuildContext context) {
    final cubit = context.read<MusicCubit>();
    final current =
        state.library.trackID == track.id &&
        state.library.playingID == playlist.id;
    return GlassPanel(
      radius: WaloneDesign.cardRadius,
      selected: current || selected,
      child: ListTile(
        onTap: selecting ? () => onSelect?.call(!selected) : null,
        leading: selecting
            ? Checkbox(
                value: selected,
                onChanged: state.importing
                    ? null
                    : (v) => onSelect?.call(v ?? false),
              )
            : IconButton(
                tooltip: 'Воспроизвести ${track.title}',
                icon: Icon(
                  current && state.playing ? Icons.pause : Icons.play_arrow,
                ),
                onPressed: () => current && state.playing
                    ? cubit.pause()
                    : cubit.play(trackID: track.id, playlistID: playlist.id),
              ),
        title: Text(track.title),
        subtitle: track.artists.isEmpty
            ? const Text('Исполнитель не указан')
            : Wrap(
                spacing: 4,
                children: [
                  for (var i = 0; i < track.artists.length; i++)
                    InkWell(
                      onTap: () =>
                          cubit.select(artistMusicID(track.artists[i])),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          '${track.artists[i]}${i + 1 < track.artists.length ? ',' : ''}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(timeLabel(track.duration)),
            if (reorderable)
              ReorderableDragStartListener(
                index: index,
                enabled: !state.importing,
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.drag_handle),
                ),
              ),
            PopupMenuButton<String>(
              tooltip: 'Действия с треком',
              icon: const Icon(Icons.more_horiz_rounded, size: 20),
              enabled: !state.importing,
              itemBuilder: (_) => [
                if (reorderable && index > 0)
                  DesktopMenuItem(
                    value: 'up',
                    label: 'Переместить выше',
                    icon: Icons.arrow_upward_rounded,
                  ),
                if (reorderable && index + 1 < playlist.trackIDs.length)
                  DesktopMenuItem(
                    value: 'down',
                    label: 'Переместить ниже',
                    icon: Icons.arrow_downward_rounded,
                  ),
                const PopupMenuItem(
                  value: 'edit',
                  child: Text('Изменить название и исполнителя…'),
                ),
                if (state.library.isSavedPlaylist(playlist.id))
                  DesktopMenuItem(
                    value: 'split',
                    label: 'Разделить на треки…',
                    icon: Icons.content_cut_rounded,
                  ),
                const PopupMenuDivider(height: 9),
                if (state.library.isSavedPlaylist(playlist.id))
                  DesktopMenuItem(
                    value: 'remove',
                    label: 'Убрать из плейлиста',
                    icon: Icons.delete_outline_rounded,
                    destructive: true,
                  ),
              ],
              onSelected: (action) async {
                switch (action) {
                  case 'edit':
                    final result =
                        await showDialog<
                          ({String title, List<String> artists})
                        >(
                          context: context,
                          builder: (_) => TrackEditDialog(
                            artists: state.library.artists,
                            track: track,
                          ),
                        );
                    if (result != null) {
                      await cubit.editTracks(
                        {track.id},
                        title: result.title,
                        artists: result.artists,
                      );
                    }
                  case 'up':
                    await cubit.reorder(playlist.id, index, index - 1);
                  case 'down':
                    await cubit.reorder(playlist.id, index, index + 2);
                  case 'remove':
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (_) => const ConfirmDialog(
                        title: 'Убрать трек?',
                        message: 'Трек останется в разделе «Все треки».',
                      ),
                    );
                    if (confirmed == true) {
                      await cubit.removeTrack(track.id, playlist.id);
                    }
                  case 'split':
                    await cubit.pause();
                    if (!context.mounted) return;
                    final importer = context.read<ImportCubit>();
                    final atmosphere = context.read<AtmosphereCubit>();
                    await showDialog<void>(
                      context: context,
                      builder: (_) => MultiBlocProvider(
                        providers: [
                          BlocProvider.value(value: cubit),
                          BlocProvider.value(value: importer),
                          BlocProvider.value(value: atmosphere),
                        ],
                        child: MusicSplitDialog(
                          track: track,
                          playlistID: playlist.id,
                        ),
                      ),
                    );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class MusicPlayerBar extends StatelessWidget {
  const MusicPlayerBar({super.key, this.compact = false, this.onOpenLibrary});
  final bool compact;
  final VoidCallback? onOpenLibrary;
  @override
  Widget build(BuildContext context) => BlocBuilder<MusicCubit, MusicState>(
    buildWhen: _musicContentChanged,
    builder: (context, state) {
      final cubit = context.read<MusicCubit>();
      final library = state.library;
      final track = library.track(library.trackID);
      if (library.tracks.isEmpty && !compact) return const SizedBox.shrink();
      final previous = IconButton(
        tooltip: 'Предыдущий трек',
        onPressed: track == null ? null : cubit.previous,
        icon: const Icon(Icons.skip_previous),
      );
      final play = IconButton(
        tooltip: state.playing ? 'Пауза музыки' : 'Воспроизвести музыку',
        onPressed: state.loading || library.tracks.isEmpty
            ? null
            : state.playing
            ? cubit.pause
            : cubit.play,
        style: compact
            ? IconButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.onSurface
                    .withValues(alpha: 0.10),
                foregroundColor: Theme.of(context).colorScheme.onSurface,
              )
            : null,
        icon: Icon(
          compact
              ? (state.playing ? Icons.pause_rounded : Icons.play_arrow_rounded)
              : (state.playing
                    ? Icons.pause_circle_outline
                    : Icons.play_circle_outline),
          size: compact ? 20 : 30,
        ),
      );
      final next = IconButton(
        tooltip: 'Следующий трек',
        onPressed: track == null ? null : cubit.next,
        icon: const Icon(Icons.skip_next),
      );
      final shuffle = IconButton(
        tooltip: 'Случайный порядок',
        isSelected: library.shuffle,
        onPressed: () => cubit.configure(shuffle: !library.shuffle),
        icon: const Icon(Icons.shuffle_rounded),
      );
      final repeat = IconButton(
        tooltip: switch (library.repeatMode) {
          MusicRepeat.off => 'Повтор выключен',
          MusicRepeat.playlist => 'Повтор плейлиста',
          MusicRepeat.track => 'Повтор трека',
        },
        isSelected: library.repeatMode != MusicRepeat.off,
        onPressed: () => cubit.configure(
          repeatMode: switch (library.repeatMode) {
            MusicRepeat.off => MusicRepeat.playlist,
            MusicRepeat.playlist => MusicRepeat.track,
            MusicRepeat.track => MusicRepeat.off,
          },
        ),
        icon: Icon(
          library.repeatMode == MusicRepeat.track
              ? Icons.repeat_one_rounded
              : Icons.repeat_rounded,
        ),
      );
      final controls = Row(
        mainAxisSize: MainAxisSize.min,
        children: compact
            ? [shuffle, previous, play, next, repeat]
            : [previous, play, next, shuffle, repeat],
      );
      final title = Row(
        children: [
          Icon(
            Icons.music_note_rounded,
            size: compact ? 14 : 20,
            color: compact
                ? Theme.of(context).colorScheme.onSurfaceVariant
                : null,
          ),
          SizedBox(width: compact ? 6 : 10),
          Expanded(
            child: Text(
              track?.title ?? 'Выберите трек в медиатеке',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: compact ? 12 : null,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      );
      final volume = SizedBox(
        height: compact ? 28 : 40,
        child: Row(
          children: [
            Icon(
              Icons.volume_down_rounded,
              size: compact ? 12 : 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            Expanded(
              child: GainSlider(
                value: library.volume,
                label: 'Громкость музыки',
                compact: compact,
                showValue: !compact,
                onChanged: (value) => cubit.configure(volume: value),
              ),
            ),
          ],
        ),
      );
      if (compact) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Tooltip(
                message: track?.title ?? 'Выберите трек в медиатеке',
                child: TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    minimumSize: const Size(0, 30),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    alignment: Alignment.centerLeft,
                  ),
                  onPressed:
                      onOpenLibrary ??
                      (track == null
                          ? null
                          : () => showDialog<void>(
                              context: context,
                              builder: (_) => WaloneDialog(
                                title: const Text('Текущий трек'),
                                content: SelectableText(track.title),
                                actions: [
                                  FilledButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Закрыть'),
                                  ),
                                ],
                              ),
                            )),
                  child: title,
                ),
              ),
              _MusicPosition(
                builder: (context, position) => GainSlider(
                  value: track == null ? 0 : position,
                  max: track?.duration ?? 1,
                  label: 'Позиция',
                  live: false,
                  compact: true,
                  showValue: false,
                  onChanged: track == null || track.duration <= 0
                      ? null
                      : cubit.seek,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _MusicPosition(
                    builder: (context, position) => Text(
                      timeLabel(track == null ? 0 : position),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                  Text(
                    timeLabel(track?.duration ?? 0),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              IconButtonTheme(
                data: IconButtonThemeData(
                  style:
                      IconButton.styleFrom(
                        iconSize: 16,
                        foregroundColor: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant,
                        minimumSize: const Size(30, 30),
                        maximumSize: const Size(30, 30),
                        padding: EdgeInsets.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ).copyWith(
                        foregroundColor: WidgetStateProperty.resolveWith((
                          states,
                        ) {
                          final scheme = Theme.of(context).colorScheme;
                          if (states.contains(WidgetState.disabled)) {
                            return scheme.onSurface.withValues(alpha: 0.3);
                          }
                          return states.contains(WidgetState.selected)
                              ? scheme.primary
                              : scheme.onSurfaceVariant;
                        }),
                      ),
                ),
                child: FittedBox(fit: BoxFit.scaleDown, child: controls),
              ),
              volume,
            ],
          ),
        );
      }
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 600;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: onOpenLibrary == null
                          ? title
                          : Tooltip(
                              message: track?.title ?? 'Открыть мою музыку',
                              child: TextButton(
                                onPressed: onOpenLibrary,
                                style: TextButton.styleFrom(
                                  foregroundColor: Theme.of(context)
                                      .colorScheme
                                      .onSurface,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  minimumSize: const Size(0, 36),
                                  alignment: Alignment.centerLeft,
                                ),
                                child: title,
                              ),
                            ),
                    ),
                    if (wide) controls,
                  ],
                ),
                if (!wide)
                  Row(
                    children: [
                      controls,
                      const Spacer(),
                      SizedBox(width: 140, child: volume),
                    ],
                  ),
                if (track != null)
                  Row(
                    children: [
                      _MusicPosition(
                        builder: (context, position) => Text(
                          timeLabel(position),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SizedBox(
                          height: 28,
                          child: _MusicPosition(
                            builder: (context, position) => GainSlider(
                              value: position,
                              max: track.duration,
                              label: 'Позиция',
                              live: false,
                              onChanged: cubit.seek,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        timeLabel(track.duration),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (wide) ...[
                        const SizedBox(width: 12),
                        SizedBox(width: 140, child: volume),
                      ],
                    ],
                  )
                else if (wide)
                  Align(
                    alignment: Alignment.centerRight,
                    child: SizedBox(width: 140, child: volume),
                  ),
                const Divider(height: 12),
              ],
            );
          },
        ),
      );
    },
  );
}

// Тики позиции не меняют медиатеку, кнопки и оформление плеера.
bool _musicContentChanged(MusicState previous, MusicState next) =>
    previous.library != next.library ||
    previous.playing != next.playing ||
    previous.loading != next.loading ||
    previous.importing != next.importing ||
    previous.error != next.error;

class _MusicPosition extends StatelessWidget {
  const _MusicPosition({required this.builder});
  final Widget Function(BuildContext, double) builder;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: BlocSelector<MusicCubit, MusicState, double>(
      selector: (state) => state.position,
      builder: builder,
    ),
  );
}
