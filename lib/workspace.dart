import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:g1455/g1455.dart';
import 'package:path/path.dart' as p;

import 'core/sidebar_icon.dart';
import 'core/storage.dart';
import 'core/widgets.dart';
import 'features/atmosphere/data/atmosphere_audio.dart';
import 'features/atmosphere/presentation/atmosphere_cubit.dart';
import 'features/atmosphere/presentation/atmosphere_page.dart';
import 'features/keyboard/presentation/keyboard_cubit.dart';
import 'features/keyboard/presentation/keyboard_page.dart';
import 'features/music/data/music_repository.dart';
import 'features/music/data/vk_session.dart';
import 'features/music/presentation/import_cubit.dart';
import 'features/music/presentation/music_cubit.dart';
import 'features/music/presentation/music_logo.dart';
import 'features/music/presentation/music_page.dart';
import 'features/settings/presentation/settings_cubit.dart';
import 'features/settings/presentation/settings_page.dart';
import 'features/timer/presentation/timer_cubit.dart';
import 'features/timer/data/timer_sound.dart';
import 'features/timer/presentation/timer_colors.dart';
import 'features/timer/presentation/timer_readout.dart';
import 'features/timer/presentation/timer_page.dart';
import 'features/statistics/data/statistics_database.dart';
import 'features/statistics/presentation/statistics_cubit.dart';
import 'features/statistics/presentation/statistics_page.dart';

class WorkspaceHost extends StatefulWidget {
  const WorkspaceHost({super.key});
  @override
  State<WorkspaceHost> createState() => _WorkspaceHostState();
}

class _WorkspaceHostState extends State<WorkspaceHost> {
  MusicCubit? _music;
  AtmosphereCubit? _atmosphere;
  ImportCubit? _import;
  SettingsCubit? _settings;
  TimerCubit? _timer;
  final _timerSound = TimerSound();
  StatisticsCubit? _statistics;
  String? _error;
  bool _ready = false;
  Future<void>? _closing;
  bool _windowVisible = true;
  static const _lifecycle = MethodChannel('dev.soyjanks.walone/workspace');
  @override
  void initState() {
    super.initState();
    _lifecycle.setMethodCallHandler((call) async {
      if (call.method == 'shutdown') {
        await _close();
        return true;
      }
      throw MissingPluginException();
    });
    _initialize();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _windowVisible = WaloneGlassHost.maybeOf(context)?.windowVisible ?? true;
    _music?.setVisualizationVisible(_windowVisible);
  }

  Future<void> _initialize() async {
    try {
      final keyboard = context.read<KeyboardCubit>();
      if (keyboard.state.loading) {
        await keyboard.stream.firstWhere((s) => !s.loading);
      }
      if (!mounted || _closing != null) return;
      final directory = await JsonStore.applicationDirectory();
      if (!mounted || _closing != null) return;
      final music = MusicCubit(
        MusicRepository(Directory(p.join(directory.path, 'Music'))),
      );
      _music = music;
      music.setVisualizationVisible(_windowVisible);
      await music.initialize();
      if (!mounted || _closing != null) return;
      final atmosphere = AtmosphereCubit(
        store: JsonStore(File(p.join(directory.path, 'atmosphere.json'))),
        audio: AtmosphereAudio(),
        music: music,
        keyboard: keyboard,
      );
      _atmosphere = atmosphere;
      await atmosphere.initialize();
      if (!mounted || _closing != null) return;
      _import = ImportCubit(music, VkSession(directory));
      final timer = TimerCubit(
        onPhaseComplete: (phase) => unawaited(_playTimerSound(phase)),
      );
      _timer = timer;
      final settings = SettingsCubit(atmosphere, timer: timer);
      _settings = settings;
      await settings.initialize();
      if (!mounted || _closing != null) return;
      final statistics = StatisticsCubit(
        StatisticsDatabase.open(
          File(p.join(directory.path, 'statistics.sqlite')),
        ),
      );
      _statistics = statistics;
      await statistics.initialize();
      if (!mounted || _closing != null) return;
      statistics.attach(music, atmosphere, timer: timer);
      setState(() => _ready = true);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  Future<void> _playTimerSound(PomodoroPhase phase) async {
    if (_closing != null) return;
    try {
      await _timerSound.play(phase);
    } catch (error) {
      debugPrint('Не удалось воспроизвести сигнал таймера: $error');
    }
  }

  Future<void> _close() => _closing ??= () async {
    await _settings?.close();
    await _timer?.close();
    await _timerSound.dispose();
    await _statistics?.close();
    await _atmosphere?.pause();
    await _import?.close();
    await _atmosphere?.close();
    await _music?.close();
  }();
  @override
  void dispose() {
    _lifecycle.setMethodCallHandler(null);
    unawaited(_close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SelectableText(_error!),
          ),
        ),
      );
    }
    if (!_ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _music!),
        BlocProvider.value(value: _atmosphere!),
        BlocProvider.value(value: _import!),
        BlocProvider.value(value: _settings!),
        BlocProvider.value(value: _timer!),
        BlocProvider.value(value: _statistics!),
      ],
      child: const WorkspacePage(),
    );
  }
}

class WorkspacePage extends StatefulWidget {
  const WorkspacePage({super.key});
  @override
  State<WorkspacePage> createState() => _WorkspacePageState();
}

class _WorkspacePageState extends State<WorkspacePage>
    with WidgetsBindingObserver {
  int _section = 0;
  final _playerKey = GlobalKey();
  final _musicPageKey = GlobalKey<MusicPageState>();
  double _playerHeight = 0;
  bool _measurementScheduled = false;
  WaloneGlassHostState? _appearance;

  void _measurePlayer() {
    if (_measurementScheduled) return;
    _measurementScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measurementScheduled = false;
      if (!mounted) return;
      final height = _playerKey.currentContext?.size?.height ?? 0;
      if ((height - _playerHeight).abs() > 0.5) {
        setState(() => _playerHeight = height);
      }
    });
  }

  late final SettingsCubit _settings;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _settings = context.read<SettingsCubit>();
    _settings.onNavigate = _selectSection;
  }

  void _selectSection(int section) {
    if (!mounted) return;
    if (_section == 2 && section != 2) {
      unawaited(context.read<KeyboardCubit>().stopPreview());
    }
    setState(() => _section = section);
  }

  Future<void> _openMusicLibrary() async {
    _selectSection(1);
    final music = context.read<MusicCubit>();
    final library = music.state.library;
    if (library.playingID != null && library.selectedID != library.playingID) {
      await music.select(library.playingID!);
    }
    if (!mounted || _section != 1) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _section == 1) {
        unawaited(_musicPageKey.currentState?.revealCurrentTrack());
      }
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _settings.onNavigate = null;
    _appearance?.setLiveBackdropNeeded(true);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _settings.refresh();
    }
    // Потеря фокуса не останавливает глобальную работу; фоновые события приходят из ОС.
    if (state == AppLifecycleState.detached) {
      context.read<AtmosphereCubit>().interrupt();
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      _measurePlayer();
      final wide = constraints.maxWidth >= 760;
      final appearance = _appearance = WaloneGlassHost.maybeOf(context);
      final compact = wide && (appearance?.compactPlayer ?? false);
      // В компактном режиме все панели читают GlassBackdrop.color, а не снимок окна.
      appearance?.setLiveBackdropNeeded(!compact);
      void togglePlayer() => appearance?.setCompactPlayer(!compact);
      final page = KeyedSubtree(
        key: PageStorageKey(_section),
        child: switch (_section) {
          0 => const AtmospherePage(),
          1 => MusicPage(key: _musicPageKey),
          2 => const KeyboardPage(),
          3 => const SettingsPage(),
          4 => const TimerPage(),
          5 => const StatisticsPage(),
          _ => const SizedBox.shrink(),
        },
      );
      final sidebar = WorkspaceSidebar(
        selected: _section,
        onSelected: _selectSection,
        timer: context.read<TimerCubit>(),
        music: context.read<MusicCubit>(),
        player: compact
            ? CompactPlayer(
                onExpand: togglePlayer,
                onOpenLibrary: _openMusicLibrary,
                onSectionSelected: _selectSection,
              )
            : null,
      );
      return Scaffold(
        body: DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
          ),
          child: Row(
            children: [
              if (wide)
                if (compact)
                  GlassBackdrop.color(
                    Theme.of(context).scaffoldBackgroundColor,
                    child: sidebar,
                  )
                else
                  sidebar,
              Expanded(
                child: Stack(
                  key: const ValueKey('workspace-content'),
                  children: [
                    Positioned.fill(
                      child: RepaintBoundary(
                        child: MediaQuery(
                          data: MediaQuery.of(context).copyWith(
                            padding: MediaQuery.paddingOf(context).copyWith(
                              bottom: compact ? 0 : _playerHeight + 32,
                            ),
                          ),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 1320),
                              // Под плавающим плеером фон должен оставаться живым.
                              child: compact
                                  ? GlassBackdrop.color(
                                      Theme.of(context).scaffoldBackgroundColor,
                                      child: page,
                                    )
                                  : page,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (!compact)
                      Positioned(
                        left: wide ? 24 : 12,
                        right: wide ? 24 : 12,
                        bottom: 16,
                        child:
                            NotificationListener<SizeChangedLayoutNotification>(
                              onNotification: (_) {
                                _measurePlayer();
                                return true;
                              },
                              child: GlassAbove(
                                child: SizeChangedLayoutNotifier(
                                  child: RepaintBoundary(
                                    child: FrostedPanel(
                                      key: _playerKey,
                                      radius: WaloneDesign.playerRadius,
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          MusicPlayerBar(
                                            onOpenLibrary: _openMusicLibrary,
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.fromLTRB(
                                              16,
                                              0,
                                              16,
                                              8,
                                            ),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: _PlayerChannel(
                                                    section: 0,
                                                    onSectionSelected:
                                                        _selectSection,
                                                  ),
                                                ),
                                                const SizedBox(width: 16),
                                                Expanded(
                                                  child: _PlayerChannel(
                                                    section: 2,
                                                    onSectionSelected:
                                                        _selectSection,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          GlobalMixerBar(
                                            onCompact:
                                                wide &&
                                                    appearance?.ready == true
                                                ? togglePlayer
                                                : null,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: wide
            ? null
            : FrostedPanel(
                radius: 0,
                sidebar: true,
                child: NavigationBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  selectedIndex: _destinations.indexWhere(
                    (item) => item.id == _section,
                  ),
                  onDestinationSelected: (index) =>
                      _selectSection(_destinations[index].id),
                  destinations: [
                    for (final item in _destinations)
                      NavigationDestination(
                        icon: Icon(item.icon),
                        label: item.title,
                      ),
                  ],
                ),
              ),
      );
    },
  );
}

// Идентификаторы разделов сохраняют маршруты нативного меню и плеера.
const _destinations = [
  (id: 4, title: 'Таймеры', icon: Icons.timer_outlined),
  (id: 5, title: 'Статистика', icon: Icons.bar_chart_rounded),
  (id: 0, title: 'Атмосфера', icon: Icons.air_rounded),
  (id: 1, title: 'Моя музыка', icon: Icons.music_note_outlined),
  (id: 2, title: 'Клавиатура', icon: Icons.keyboard_outlined),
  (id: 3, title: 'Настройки', icon: Icons.settings_outlined),
];

class WorkspaceSidebar extends StatelessWidget {
  const WorkspaceSidebar({
    super.key,
    required this.selected,
    required this.onSelected,
    this.player,
    this.timer,
    this.music,
  });
  final MusicCubit? music;
  final TimerCubit? timer;
  final int selected;
  final ValueChanged<int> onSelected;
  final Widget? player;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tileHeight = (MediaQuery.textScalerOf(context).scale(14) * 1.5 + 16)
        .clamp(48.0, double.infinity);
    Widget destination(int index) {
      final item = _destinations[index];
      final active = selected == item.id;
      final tile = _SidebarDestination(
        id: item.id,
        title: item.title,
        active: active,
        onSelected: onSelected,
      );
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        child: SizedBox(height: tileHeight, child: tile),
      );
    }

    return SizedBox(
      width: 224,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(
              color: theme.colorScheme.outlineVariant,
              width: 0.5,
            ),
          ),
        ),
        child: FrostedPanel(
          radius: 0,
          sidebar: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 24, 16, 24),
                child: Row(
                  children: [
                    if (music != null)
                      MusicLogo(music: music!)
                    else
                      Icon(
                        Icons.graphic_eq_rounded,
                        color: theme.colorScheme.primary,
                        size: 27,
                      ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: timer == null
                          ? const _SidebarBrand()
                          : _SidebarTimerTitle(
                              timer: timer!,
                              showTimers: selected != 4,
                              onOpen: () => onSelected(4),
                            ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final row = tileHeight + 4;
                    const headingHeight = 28.0;
                    final minimumHeight = row * 6 + headingHeight * 2 + 16;
                    final height = constraints.maxHeight.clamp(
                      minimumHeight,
                      double.infinity,
                    );
                    final index = _destinations.indexWhere(
                      (item) => item.id == selected,
                    );
                    final top = index == 5
                        ? height - row - 8
                        : headingHeight +
                              index * row +
                              (index >= 2 ? headingHeight : 0);
                    Widget heading(String label) => SizedBox(
                      height: headingHeight,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 22, top: 6),
                        child: Text(label, style: theme.textTheme.labelMedium),
                      ),
                    );
                    return SingleChildScrollView(
                      child: SizedBox(
                        height: height,
                        child: Stack(
                          children: [
                            AnimatedPositioned(
                              duration: MediaQuery.disableAnimationsOf(context)
                                  ? Duration.zero
                                  : WaloneDesign.motion,
                              curve: Curves.easeOutCubic,
                              left: 10,
                              right: 10,
                              top: top + 2,
                              height: tileHeight,
                              child: IgnorePointer(
                                child: DecoratedBox(
                                  key: const ValueKey(
                                    'sidebar-selection-bubble',
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(
                                      WaloneDesign.controlRadius,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                heading('Фокус'),
                                destination(0),
                                destination(1),
                                heading('Звук'),
                                for (var index = 2; index < 5; index++)
                                  destination(index),
                                Expanded(
                                  child: Align(
                                    alignment: Alignment.bottomCenter,
                                    child: SingleChildScrollView(
                                      child: player == null
                                          ? const SizedBox.shrink()
                                          : Padding(
                                              padding: const EdgeInsets.all(10),
                                              child: FrostedPanel(
                                                key: const ValueKey(
                                                  'sidebar-player-card',
                                                ),
                                                child: RepaintBoundary(
                                                  child: player!,
                                                ),
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16),
                                  child: Divider(height: 8),
                                ),
                                destination(5),
                                const SizedBox(height: 8),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarDestination extends StatefulWidget {
  const _SidebarDestination({
    required this.id,
    required this.active,
    required this.onSelected,
    required this.title,
  });

  final int id;
  final bool active;
  final String title;
  final ValueChanged<int> onSelected;

  @override
  State<_SidebarDestination> createState() => _SidebarDestinationState();
}

class _SidebarDestinationState extends State<_SidebarDestination>
    with SingleTickerProviderStateMixin {
  late final _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  );

  void _animate() {
    if (!MediaQuery.disableAnimationsOf(context)) _motion.forward(from: 0);
  }

  @override
  void didUpdateWidget(_SidebarDestination oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) _animate();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) _motion.reset();
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      selected: widget.active,
      selectedTileColor: Colors.transparent,
      selectedColor: colors.primary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(WaloneDesign.controlRadius),
      ),
      minLeadingWidth: 24,
      horizontalTitleGap: 10,
      title: Text(
        widget.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 14,
          fontWeight: widget.active ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      onTap: () {
        _animate();
        widget.onSelected(widget.id);
      },
      leading: AnimatedBuilder(
        animation: _motion,
        builder: (context, child) => CustomPaint(
          size: const Size.square(22),
          painter: SidebarIconPainter(
            destination: widget.id,
            progress: _motion.value,
            color: widget.active ? colors.primary : colors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _SidebarBrand extends StatelessWidget {
  const _SidebarBrand({super.key});
  @override
  Widget build(BuildContext context) => const Text(
    'Walone',
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(
      fontSize: 23,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.7,
    ),
  );
}

class _SidebarTimerTitle extends StatelessWidget {
  const _SidebarTimerTitle({
    required this.timer,
    required this.showTimers,
    required this.onOpen,
  });
  final TimerCubit timer;
  final bool showTimers;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) =>
      BlocSelector<
        TimerCubit,
        TimerState,
        ({String? focus, String? watch, bool resting})
      >(
        bloc: timer,
        selector: (state) => (
          focus: state.pomodoro.running
              ? state.copyWith(mode: TimerMode.pomodoro).time
              : null,
          watch: state.stopwatch.running
              ? timerTime(state.stopwatch.elapsed)
              : null,
          resting: state.resting,
        ),
        builder: (context, value) {
          final focus = showTimers ? value.focus : null;
          final watch = showTimers ? value.watch : null;
          final both = focus != null && watch != null;
          final active = focus != null || watch != null;
          final reduced = MediaQuery.disableAnimationsOf(context);
          final scheme = Theme.of(context).colorScheme;
          Widget clock(
            TimerMode mode,
            String time,
            IconData icon,
            String label, {
            Color? color,
          }) => TimerColorTransition(
            key: ValueKey(mode),
            color: color ?? scheme.onSurface,
            builder: (context, animatedColor) => Tooltip(
              message: 'Открыть: $label',
              child: Semantics(
                label: '$label · $time',
                button: true,
                child: InkWell(
                  key: ValueKey(('sidebar-timer', mode)),
                  onTap: () {
                    timer.selectMode(mode);
                    onOpen();
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: ExcludeSemantics(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            icon,
                            size: both ? 13 : 16,
                            color: mode == TimerMode.pomodoro
                                ? animatedColor
                                : scheme.primary,
                          ),
                          const SizedBox(width: 5),
                          TimerReadout(
                            value: time,
                            style: TextStyle(
                              color: animatedColor,
                              fontSize: both ? 15 : 22,
                              height: 1.1,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          return SizedBox(
            height: MediaQuery.textScalerOf(context).scale(36),
            child: ClipRect(
              child: AnimatedSwitcher(
                duration: reduced
                    ? Duration.zero
                    : const Duration(milliseconds: 320),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                layoutBuilder: (child, previous) => Stack(
                  alignment: Alignment.centerLeft,
                  children: [...previous, ?child],
                ),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.3),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: !active
                    ? const _SidebarBrand(key: ValueKey('sidebar-brand'))
                    : KeyedSubtree(
                        key: ValueKey((focus != null, watch != null)),
                        child: Column(
                          key: const ValueKey('sidebar-timer-preview'),
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (focus != null)
                              clock(
                                TimerMode.pomodoro,
                                focus,
                                value.resting
                                    ? Icons.local_cafe_outlined
                                    : Icons.work_outline_rounded,
                                value.resting
                                    ? 'Помодоро · Отдых'
                                    : 'Помодоро · Работа',
                                color: pomodoroColor(
                                  scheme,
                                  resting: value.resting,
                                ),
                              ),
                            if (watch != null)
                              clock(
                                TimerMode.stopwatch,
                                watch,
                                Icons.timer_outlined,
                                'Секундомер',
                              ),
                          ],
                        ),
                      ),
              ),
            ),
          );
        },
      );
}

class GlobalPauseNotice extends StatelessWidget {
  const GlobalPauseNotice({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<AtmosphereCubit, AtmosphereState>(
    builder: (context, state) {
      if (!state.paused) return const SizedBox.shrink();
      final theme = Theme.of(context);
      final until = state.pausedUntil;
      final message = until == null
          ? 'Все звуки на паузе'
          : 'Все звуки на паузе\nДо ${until.hour.toString().padLeft(2, '0')}:${until.minute.toString().padLeft(2, '0')}';
      final status = Semantics(
        liveRegion: true,
        child: Row(
          children: [
            Icon(
              Icons.pause_circle_filled_rounded,
              size: compact ? 18 : 24,
              color: theme.colorScheme.onPrimaryContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
      final resume = TextButton(
        onPressed: context.read<AtmosphereCubit>().resume,
        style: TextButton.styleFrom(
          foregroundColor: theme.colorScheme.onPrimaryContainer,
        ),
        child: Text(compact ? 'Возобновить' : 'Возобновить все звуки'),
      );
      return Container(
        margin: compact
            ? const EdgeInsets.symmetric(vertical: 6)
            : const EdgeInsets.fromLTRB(12, 12, 12, 0),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(10),
        ),
        child: compact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [status, resume],
              )
            : Row(
                children: [
                  Expanded(child: status),
                  const SizedBox(width: 8),
                  resume,
                ],
              ),
      );
    },
  );
}

class GlobalMixerBar extends StatelessWidget {
  const GlobalMixerBar({super.key, this.onCompact});
  final VoidCallback? onCompact;
  @override
  Widget build(BuildContext context) =>
      BlocBuilder<AtmosphereCubit, AtmosphereState>(
        builder: (context, state) {
          final cubit = context.read<AtmosphereCubit>();
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const GlobalPauseNotice(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: state.paused
                            ? const SizedBox.shrink()
                            : TextButton.icon(
                                onPressed: cubit.pause,
                                icon: const Icon(Icons.pause_rounded, size: 18),
                                label: const Text('Пауза всех звуков'),
                              ),
                      ),
                    ),
                    if (onCompact != null)
                      IconButton(
                        tooltip: 'Убрать плеер в левое меню',
                        onPressed: onCompact,
                        icon: const Icon(
                          Icons.vertical_split_outlined,
                          size: 20,
                        ),
                      ),
                    PopupMenuButton<int>(
                      tooltip: 'Приостановить все звуки на время',
                      icon: const Icon(Icons.timer_outlined, size: 20),
                      itemBuilder: (_) => [
                        DesktopMenuItem(
                          value: 15,
                          label: 'Пауза на 15 минут',
                          icon: Icons.pause_rounded,
                        ),
                        DesktopMenuItem(
                          value: 30,
                          label: 'Пауза на 30 минут',
                          icon: Icons.pause_rounded,
                        ),
                        DesktopMenuItem(
                          value: 60,
                          label: 'Пауза на час',
                          icon: Icons.pause_rounded,
                        ),
                      ],
                      onSelected: (minutes) =>
                          cubit.pause(duration: Duration(minutes: minutes)),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 150,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Общая громкость',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          GainSlider(
                            value: state.master,
                            label: 'Общая громкость',
                            onChanged: cubit.setMaster,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      );
}

class _PlayerChannel extends StatelessWidget {
  const _PlayerChannel({
    required this.section,
    required this.onSectionSelected,
    this.compact = false,
  });
  final int section;
  final ValueChanged<int> onSectionSelected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    Widget channel({
      required String title,
      required IconData icon,
      required String action,
      required IconData actionIcon,
      required double value,
      required ValueChanged<double>? onChanged,
      required VoidCallback? onPressed,
      required String label,
      required VoidCallback onOpen,
    }) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: onOpen,
                style: TextButton.styleFrom(
                  foregroundColor: muted,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  minimumSize: Size(0, compact ? 30 : 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  alignment: Alignment.centerLeft,
                ),
                child: Row(
                  children: [
                    Icon(icon, size: compact ? 14 : 18),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: compact ? 11 : 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: action,
              onPressed: onPressed,
              icon: Icon(actionIcon, size: compact ? 14 : 18),
            ),
          ],
        ),
        GainSlider(
          value: value,
          label: label,
          compact: compact,
          showValue: !compact,
          onChanged: onChanged,
        ),
      ],
    );
    return section == 0
        ? BlocBuilder<AtmosphereCubit, AtmosphereState>(
            builder: (context, state) {
              final cubit = context.read<AtmosphereCubit>();
              return channel(
                title: 'Атмосфера',
                onOpen: () => onSectionSelected(0),
                icon: Icons.waves_rounded,
                action: state.running ? 'Выключить фон' : 'Включить фон',
                actionIcon: state.running
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                onPressed:
                    state.running ||
                        state.mix.layers.values.any((layer) => layer.enabled)
                    ? cubit.toggleBackground
                    : null,
                value: state.backgroundVolume,
                label: 'Громкость атмосферы',
                onChanged: cubit.setBackgroundVolume,
              );
            },
          )
        : BlocBuilder<KeyboardCubit, KeyboardState>(
            builder: (context, state) {
              final cubit = context.read<KeyboardCubit>();
              return channel(
                title: 'Клавиатура',
                onOpen: () => onSectionSelected(2),
                icon: Icons.keyboard_outlined,
                action: state.status.enabled
                    ? 'Выключить клавиатуру'
                    : 'Включить клавиатуру',
                actionIcon: state.status.enabled
                    ? Icons.volume_up_rounded
                    : Icons.volume_off_rounded,
                onPressed: state.busy
                    ? null
                    : () => cubit.configure(enabled: !state.status.enabled),
                value: state.volume,
                label: 'Громкость клавиатуры',
                onChanged: state.busy
                    ? null
                    : (value) => cubit.configure(volume: value),
              );
            },
          );
  }
}

class CompactPlayer extends StatelessWidget {
  const CompactPlayer({
    super.key,
    required this.onExpand,
    this.onOpenLibrary,
    required this.onSectionSelected,
  });
  final VoidCallback onExpand;
  final VoidCallback? onOpenLibrary;
  final ValueChanged<int> onSectionSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    Widget divider() => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Divider(
        height: 1,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.10),
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
      child: IconButtonTheme(
        data: IconButtonThemeData(
          style: IconButton.styleFrom(
            foregroundColor: muted,
            minimumSize: const Size(26, 26),
            maximumSize: const Size(26, 26),
            padding: EdgeInsets.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'ЗВУК',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                      color: muted.withValues(alpha: 0.7),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Развернуть плеер',
                  onPressed: onExpand,
                  icon: const Icon(Icons.open_in_full_rounded, size: 13),
                ),
              ],
            ),
            const GlobalPauseNotice(compact: true),
            MusicPlayerBar(
              compact: true,
              onOpenLibrary: onOpenLibrary ?? () => onSectionSelected(1),
            ),
            divider(),
            _PlayerChannel(
              section: 0,
              compact: true,
              onSectionSelected: onSectionSelected,
            ),
            divider(),
            _PlayerChannel(
              section: 2,
              compact: true,
              onSectionSelected: onSectionSelected,
            ),
            divider(),
            BlocBuilder<AtmosphereCubit, AtmosphereState>(
              builder: (context, state) {
                final cubit = context.read<AtmosphereCubit>();
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Общая громкость',
                      style: TextStyle(fontSize: 10, color: muted),
                    ),
                    Row(
                      children: [
                        Icon(Icons.volume_up_rounded, size: 12, color: muted),
                        const SizedBox(width: 4),
                        Expanded(
                          child: GainSlider(
                            value: state.master,
                            label: 'Общая громкость',
                            compact: true,
                            onChanged: cubit.setMaster,
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          tooltip: state.paused
                              ? 'Возобновить все звуки'
                              : 'Пауза всех звуков',
                          onPressed: state.paused ? cubit.resume : cubit.pause,
                          icon: Icon(
                            state.paused
                                ? Icons.play_arrow_rounded
                                : Icons.pause_rounded,
                            size: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
