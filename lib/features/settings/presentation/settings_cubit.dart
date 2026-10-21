import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../atmosphere/presentation/atmosphere_cubit.dart';
import '../../music/presentation/music_cubit.dart';
import '../../keyboard/presentation/keyboard_cubit.dart';
import '../../timer/presentation/timer_cubit.dart';

enum LoginStatus { disabled, enabled, requiresApproval, notFound }

class SettingsState {
  const SettingsState({
    this.login = LoginStatus.disabled,
    this.trayAvailable = false,
    this.busy = false,
    this.updateVersion,
    this.updateReady = false,
    this.error,
  });
  final LoginStatus login;
  final bool trayAvailable;
  final bool busy;
  final String? updateVersion;
  final bool updateReady;
  final String? error;
  bool get launchAtLogin =>
      login == LoginStatus.enabled || login == LoginStatus.requiresApproval;
}

class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit(
    this.atmosphere, {
    this.timer,
    this.channel = const MethodChannel('dev.soyjanks.walone/desktop'),
  }) : super(const SettingsState(busy: true));

  final AtmosphereCubit atmosphere;
  final TimerCubit? timer;
  StreamSubscription<TimerState>? _timerSubscription;
  String? _lastTimerTray;
  StreamSubscription<MusicState>? _playerSubscription;
  (String?, bool, bool, bool)? _lastPlayerTray;
  final MethodChannel channel;
  StreamSubscription<AtmosphereState>? _subscription;
  StreamSubscription<KeyboardState>? _keyboardSubscription;
  (double, double, double, double, bool)? _lastVolumes;
  Future<void> _trayTail = Future.value();
  Future<void>? _musicTrayUpdate;
  bool _musicTrayPending = false;
  void Function(int)? onNavigate;

  Future<void> initialize() async {
    channel.setMethodCallHandler((call) async {
      if (call.method != 'action') throw MissingPluginException();
      final args = Map<Object?, Object?>.from(call.arguments as Map);
      switch (args['action']) {
        case 'updateStatus':
          emit(
            SettingsState(
              login: state.login,
              trayAvailable: state.trayAvailable,
              busy: state.busy,
              error: state.error,
              updateVersion: args['version'] as String?,
              updateReady: args['ready'] == true,
            ),
          );
        case 'volume':
          final value = args['value'];
          if (value is! num || !value.isFinite) return false;
          final volume = value.toDouble().clamp(0.0, 1.0);
          switch (args['channel']) {
            case 'master':
              await atmosphere.setMaster(volume);
            case 'music':
              await atmosphere.music.configure(volume: volume);
            case 'atmosphere':
              await atmosphere.setBackgroundVolume(volume);
            case 'keyboard':
              await atmosphere.keyboard.configure(volume: volume);
            default:
              return false;
          }
        case 'togglePause':
          if (atmosphere.state.paused) {
            await atmosphere.resume();
          } else {
            await atmosphere.pause();
          }
        case 'pause15':
          await atmosphere.pause(duration: const Duration(minutes: 15));
        case 'stopBackground':
          if (atmosphere.state.running) await atmosphere.toggleBackground();
        case 'preset':
          if (args['id'] case final String id) {
            await atmosphere.selectPreset(id);
          }
        case 'atmosphere':
          onNavigate?.call(0);
        case 'music':
          onNavigate?.call(1);
        case 'toggleMusic':
          if (atmosphere.music.state.playing) {
            await atmosphere.music.pause();
          } else {
            await atmosphere.music.play();
          }
        case 'previousTrack':
          await atmosphere.music.previous();
        case 'nextTrack':
          await atmosphere.music.next();
        case 'timers':
          onNavigate?.call(4);
        case 'toggleTimer':
          timer?.toggle();
        case 'resetTimer':
          timer?.reset();
        case 'settings':
          onNavigate?.call(3);
        default:
          throw MissingPluginException();
      }
      return true;
    });
    await _read('initialize');
    if (isClosed) return;
    _subscription = atmosphere.stream.listen((value) {
      _updateTray(value);
      _updateVolumes();
    });
    await _updateTray(atmosphere.state);
    _playerSubscription = atmosphere.music.stream.listen((value) {
      _updatePlayerTray(value);
      _updateVolumes();
    });
    _keyboardSubscription = atmosphere.keyboard.stream.listen((_) {
      _updateVolumes();
    });
    await _updateVolumes();
    await _updatePlayerTray(atmosphere.music.state);
    atmosphere.music.visualization.addListener(_updateMusicTray);
    atmosphere.music.setTrayVisualizationEnabled(true);
    _updateMusicTray();
    if (timer case final timer?) {
      _timerSubscription = timer.stream.listen(_updateTimerTray);
      await _updateTimerTray(timer.state);
    }
  }

  Future<void> _updateVolumes() {
    final snapshot = (
      atmosphere.state.master,
      atmosphere.music.state.library.volume,
      atmosphere.state.backgroundVolume,
      atmosphere.keyboard.state.volume,
      !atmosphere.keyboard.state.busy &&
          atmosphere.keyboard.state.selected != null,
    );
    if (_lastVolumes == snapshot) return _trayTail;
    _lastVolumes = snapshot;
    _trayTail = _trayTail.then((_) async {
      if (isClosed) return;
      try {
        await channel.invokeMethod<void>('updateVolumes', {
          'master': snapshot.$1,
          'music': snapshot.$2,
          'atmosphere': snapshot.$3,
          'keyboard': snapshot.$4,
          'keyboardEnabled': snapshot.$5,
        });
      } on MissingPluginException {
        // На платформах без управления громкостью в трее остаётся окно приложения.
      } catch (error) {
        if (!isClosed) _publish(error: '$error');
      }
    });
    return _trayTail;
  }

  Future<void> _updatePlayerTray(MusicState value) {
    final library = value.library;
    final track = library.track(library.trackID);
    final available =
        track != null ||
        (library.playlist(library.selectedID)?.trackIDs.isNotEmpty ?? false);
    final snapshot = (track?.title, value.playing, available, value.loading);
    if (_lastPlayerTray == snapshot) return _trayTail;
    _lastPlayerTray = snapshot;
    _trayTail = _trayTail.then((_) async {
      if (isClosed) return;
      try {
        await channel.invokeMethod<void>('updatePlayerTray', {
          'title': track?.title ?? '',
          'playing': value.playing,
          'available': available,
          'loading': value.loading,
        });
      } on MissingPluginException {
        // На платформах без плеера в трее остаётся окно приложения.
      } catch (error) {
        if (!isClosed) _publish(error: '$error');
      }
    });
    return _trayTail;
  }

  void _updateMusicTray() {
    if (isClosed) return;
    _musicTrayPending = true;
    if (_musicTrayUpdate != null) return;
    _musicTrayUpdate = () async {
      while (_musicTrayPending && !isClosed) {
        _musicTrayPending = false;
        try {
          await channel.invokeMethod<void>(
            'updateMusicTray',
            atmosphere.music.visualization.value,
          );
        } catch (_) {
          // Отказ визуализации не должен блокировать управление из трея.
        }
      }
    }().whenComplete(() => _musicTrayUpdate = null);
  }

  Future<void> _updateTray(AtmosphereState value) {
    _trayTail = _trayTail.then((_) async {
      if (isClosed) return;
      try {
        await channel.invokeMethod<void>('updateTray', {
          'paused': value.paused,
          'running': value.running,
          'selectedID': value.selectedID,
          'presets': [
            for (final preset in value.presets)
              {'id': preset.id, 'name': preset.name},
          ],
        });
      } catch (error) {
        if (!isClosed) _publish(error: '$error');
      }
    });
    return _trayTail;
  }

  Future<void> _updateTimerTray(TimerState value) {
    final menuTitle = value.copyWith(showInTray: true).trayTitle;
    final key = '$menuTitle|${value.showInTray}|${value.current.running}';
    if (_lastTimerTray == key) return _trayTail;
    _lastTimerTray = key;
    _trayTail = _trayTail.then((_) async {
      if (isClosed) return;
      try {
        await channel.invokeMethod<void>('updateTimerTray', {
          'title': menuTitle,
          'time': value.trayTitle.isEmpty ? '' : value.time,
          'running': value.current.running,
        });
      } catch (error) {
        if (!isClosed) _publish(error: '$error');
      }
    });
    return _trayTail;
  }

  void _publish({bool busy = false, String? error}) => emit(
    SettingsState(
      login: state.login,
      trayAvailable: state.trayAvailable,
      busy: busy,
      updateVersion: state.updateVersion,
      updateReady: state.updateReady,
      error: error,
    ),
  );

  Future<void> _read(String method, [Object? arguments]) async {
    try {
      final result = await channel.invokeMapMethod<String, dynamic>(
        method,
        arguments,
      );
      if (isClosed) return;
      if (result == null) throw const FormatException('Нет ответа системы');
      final login = LoginStatus.values.byName(result['login'] as String);
      emit(
        SettingsState(
          login: login,
          trayAvailable: result['trayAvailable'] == true,
          updateVersion: result['updateVersion'] as String?,
          updateReady: result['updateReady'] == true,
        ),
      );
    } catch (error) {
      if (!isClosed) _publish(error: '$error');
    }
  }

  Future<void> refresh() => _read('status');

  Future<void> setLaunchAtLogin(bool value) async {
    if (state.busy) return;
    _publish(busy: true);
    try {
      await channel.invokeMethod<void>('setLaunchAtLogin', value);
      await refresh();
    } catch (error) {
      // После отказа показываем фактическое состояние ОС, а не положение переключателя.
      await refresh();
      if (!isClosed) _publish(error: 'Не удалось изменить автозапуск: $error');
    }
  }

  Future<void> command(String method) async {
    try {
      await channel.invokeMethod<void>(method);
      if (method == 'restoreTray') await refresh();
    } catch (error) {
      if (!isClosed) _publish(error: '$error');
    }
  }

  @override
  Future<void> close() async {
    atmosphere.music.visualization.removeListener(_updateMusicTray);
    atmosphere.music.setTrayVisualizationEnabled(false);
    _musicTrayPending = false;
    await _musicTrayUpdate;
    onNavigate = null;
    channel.setMethodCallHandler(null);
    await _subscription?.cancel();
    await _timerSubscription?.cancel();
    await _playerSubscription?.cancel();
    await _keyboardSubscription?.cancel();
    await _trayTail;
    return super.close();
  }
}
