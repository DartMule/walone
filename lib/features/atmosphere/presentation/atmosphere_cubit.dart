import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../core/storage.dart';
import '../../keyboard/presentation/keyboard_cubit.dart';
import '../../music/presentation/music_cubit.dart';
import '../data/atmosphere_audio.dart';
import '../domain/atmosphere.dart';

class AtmosphereState {
  AtmosphereState({
    AtmosphereMix? mix,
    this.presets = const [],
    this.selectedID,
    this.master = 0.7,
    this.backgroundVolume = 1,
    this.running = false,
    this.paused = false,
    this.pausedUntil,
    this.error,
    this.canUndo = false,
  }) : mix = mix ?? AtmosphereMix();
  final AtmosphereMix mix;
  final List<AtmospherePreset> presets;
  final String? selectedID;
  final double master;
  final double backgroundVolume;
  final bool running;
  final bool paused;
  final DateTime? pausedUntil;
  final String? error;
  final bool canUndo;
  AtmospherePreset? get selected =>
      presets.where((p) => p.id == selectedID).firstOrNull;
  bool get modified =>
      selected != null &&
      jsonEncode(selected!.mix.toJson()) != jsonEncode(mix.toJson());
}

class AtmosphereCubit extends Cubit<AtmosphereState> {
  AtmosphereCubit({
    required this.store,
    required this.audio,
    required this.music,
    required this.keyboard,
    Future<void> Function(double, bool)? keyboardEnvironment,
    Stream<dynamic>? lifecycle,
  }) : _keyboardEnvironment = keyboardEnvironment ?? _nativeEnvironment,
       super(AtmosphereState()) {
    audio.onError = (message) => _run(() async {
      _running = false;
      await audio.stop();
      throw StateError(message);
    }, skipWhenPaused: true);
    _keyboardSubscription = keyboard.stream.listen((state) {
      if (_applyingPreset || state.selected == null || state.busy) return;
      if (_mix.keyboardID == state.selected!.id &&
          _mix.keyboard.enabled == state.status.enabled &&
          _mix.keyboard.volume == state.volume) {
        return;
      }
      _mix = _mix.copyWith(
        keyboardID: state.selected!.id,
        keyboard: SoundLayer(
          enabled: state.status.enabled,
          volume: state.volume,
        ),
      );
      _publish();
      _run(_save);
    });
    _lifecycleSubscription =
        (lifecycle ??
                const EventChannel('dev.soyjanks.walone/lifecycle')
                    .receiveBroadcastStream())
            .listen(
              (_) => interrupt(),
              onError: (Object _) {
                /* Отсутствие событий не запускает воспроизведение. */
              },
            );
    music.onUserPlay = () {
      if (_paused) resume();
    };
  }
  final JsonStore store;
  final AtmosphereAudio audio;
  final MusicCubit music;
  final KeyboardCubit keyboard;
  final Future<void> Function(double, bool) _keyboardEnvironment;
  late final StreamSubscription<KeyboardState> _keyboardSubscription;
  late final StreamSubscription<dynamic> _lifecycleSubscription;
  Future<void> _tail = Future.value();
  AtmosphereMix _mix = AtmosphereMix();
  List<AtmospherePreset> _presets = [];
  String? _selected;
  double _master = 0.7;
  double _backgroundVolume = 1;
  bool _running = false;
  bool _paused = false;
  bool _applyingPreset = false;
  String? _error;
  AtmosphereState? _undo;
  DateTime? _until;
  Timer? _timer;

  static Future<void> _nativeEnvironment(double volume, bool allowed) =>
      const MethodChannel('dev.soyjanks.walone/keyboard').invokeMethod<void>(
        'environment',
        {'masterVolume': volume, 'allowed': allowed},
      );
  void _publish() {
    if (!isClosed) {
      emit(
        AtmosphereState(
          mix: _mix,
          presets: List.unmodifiable(_presets),
          selectedID: _selected,
          master: _master,
          backgroundVolume: _backgroundVolume,
          running: _running,
          paused: _paused,
          pausedUntil: _until,
          error: _error,
          canUndo: _undo != null,
        ),
      );
    }
  }

  Future<void> _run(
    Future<void> Function() action, {
    bool skipWhenPaused = false,
  }) {
    _tail = _tail.then((_) async {
      if (isClosed || (skipWhenPaused && _paused)) return;
      try {
        _error = null;
        await action();
      } catch (error) {
        _error = '$error';
      }
      _publish();
    });
    return _tail;
  }

  Future<void> initialize() => _run(() async {
    try {
      final saved = await store.read();
      if (saved != null) {
        if (saved['version'] != 1) {
          throw const FormatException('Неизвестная версия атмосферы');
        }
        _mix = AtmosphereMix.fromJson(jsonMap(saved['mix']));
        _master = finiteNumber(saved['masterVolume'], max: 1);
        _backgroundVolume = finiteNumber(
          saved['backgroundVolume'] ?? 1,
          max: 1,
        );
        _presets = (saved['presets'] as List<dynamic>)
            .map((r) => AtmospherePreset.fromJson(jsonMap(r)))
            .toList();
        if (_presets.map((p) => p.id).toSet().length != _presets.length) {
          throw const FormatException('Повторяющиеся наборы');
        }
        final known = keyboard.state.packs.map((p) => p.id).toSet();
        if (!known.contains(_mix.keyboardID) ||
            _presets.any((p) => !known.contains(p.mix.keyboardID))) {
          throw const FormatException('Неизвестная клавиатура');
        }
        _selected = saved['selectedPresetID'] as String?;
      }
    } catch (_) {
      store.protect();
      _mix = AtmosphereMix();
      _presets = [];
      _selected = null;
      _master = 0.7;
      _backgroundVolume = 1;
      _error =
          'Настройки атмосферы повреждены и сохранены без перезаписи: ${store.file.path}';
    }
    // После запуска ждём явной команды пользователя для любого фона и музыки.
    _mix = _mix.copyWith(keyboard: _mix.keyboard.copyWith(enabled: false));
    await _applyKeyboard();
    await _environment();
  });
  Future<void> _save() => store.write({
    'version': 1,
    'mix': _mix.toJson(),
    'masterVolume': _master,
    'backgroundVolume': _backgroundVolume,
    'presets': _presets.map((p) => p.toJson()).toList(),
    'selectedPresetID': _selected,
  });
  Future<void> _environment({bool clearIntent = false}) async {
    await keyboard.previewEnvironment(_master, !_paused);
    await _keyboardEnvironment(_master, !_paused);
    await music.environment(_master, !_paused, clearIntent: clearIntent);
    final layers = _mix.layers.entries.where((e) => e.value.enabled).toList();
    final headroom = max(1, sqrt(layers.length));
    if (_paused || !_running) {
      await audio.stop();
    } else {
      await audio.update({
        for (final layer in layers)
          layer.key:
              layer.value.volume * _master * _backgroundVolume / headroom,
      });
    }
  }

  Future<void> setLayer(String id, {bool? enabled, double? volume}) {
    if (isClosed ||
        !ambientTitles.containsKey(id) ||
        (volume != null && !volume.isFinite)) {
      return Future.value();
    }
    final layer = (_mix.layers[id] ?? const SoundLayer()).copyWith(
      enabled: enabled,
      volume: volume?.clamp(0, 1),
    );
    _mix = _mix.copyWith(layers: {..._mix.layers, id: layer});
    _publish();
    return _run(() async {
      await _environment();
      await _save();
    });
  }

  Future<void> setBackgroundVolume(double volume) {
    if (isClosed || !volume.isFinite) return Future.value();
    _backgroundVolume = volume.clamp(0, 1);
    _publish();
    return _run(() async {
      await _environment();
      await _save();
    });
  }

  Future<void> setMaster(double volume) {
    if (isClosed || !volume.isFinite) return Future.value();
    _master = volume.clamp(0, 1);
    _publish();
    return _run(() async {
      await _environment();
      await _save();
    });
  }

  Future<void> toggleBackground() => _run(() async {
    _running = !_running;
    if (_running) {
      _paused = false;
      _until = null;
      _timer?.cancel();
    }
    await _environment();
  });
  Future<void> pause({Duration? duration}) => _run(() async {
    _paused = true;
    _until = duration == null ? null : DateTime.now().add(duration);
    _timer?.cancel();
    if (duration != null) _timer = Timer(duration, resume);
    await _environment();
  });
  Future<void> resume() => _run(() async {
    _paused = false;
    _until = null;
    _timer?.cancel();
    await _environment();
  });
  Future<void> interrupt() => _run(() async {
    _paused = true;
    _until = null;
    _timer?.cancel();
    await _environment(clearIntent: true);
    _error = 'Сон, блокировка или изменение аудиовыхода — все звуки на паузе';
  });
  Future<void> _applyKeyboard() async {
    final pack = keyboard.state.packs
        .where((p) => p.id == _mix.keyboardID)
        .firstOrNull;
    if (pack == null) {
      throw const FormatException('Клавиатура отсутствует в каталоге');
    }
    _applyingPreset = true;
    try {
      await keyboard.configure(
        pack: pack,
        enabled: _mix.keyboard.enabled,
        volume: _mix.keyboard.volume,
      );
    } finally {
      _applyingPreset = false;
    }
    if (keyboard.state.error != null) throw StateError(keyboard.state.error!);
  }

  Future<void> savePreset(String name, {String? id, bool update = false}) =>
      _run(() async {
        final clean = checkedName(name);
        if (id != null) {
          _presets = _presets
              .map(
                (p) => p.id == id
                    ? AtmospherePreset(
                        id: id,
                        name: clean,
                        mix: update ? _mix : p.mix,
                      )
                    : p,
              )
              .toList();
        } else {
          final preset = AtmospherePreset(
            id: const Uuid().v4(),
            name: clean,
            mix: _mix,
          );
          _presets = [..._presets, preset];
          _selected = preset.id;
        }
        await _save();
      });
  Future<void> deletePreset(String id) => _run(() async {
    _presets = _presets.where((p) => p.id != id).toList();
    if (_selected == id) _selected = null;
    await _save();
  });
  Future<void> selectPreset(String id) => _run(() async {
    final preset = _presets.where((p) => p.id == id).firstOrNull;
    if (preset == null) return;
    _undo = state;
    _mix = preset.mix;
    _selected = id;
    _running = true;
    _paused = false;
    _until = null;
    _timer?.cancel();
    await _applyKeyboard();
    await _environment();
    await _save();
  });
  Future<void> undo() => _run(() async {
    final previous = _undo;
    if (previous == null) return;
    _mix = previous.mix;
    _selected = previous.selectedID;
    _running = previous.running;
    _paused = previous.paused;
    _until = previous.pausedUntil;
    _undo = null;
    await _applyKeyboard();
    await _environment();
    await _save();
    _timer?.cancel();
    if (_until != null) {
      final left = _until!.difference(DateTime.now());
      if (left > Duration.zero) {
        _timer = Timer(left, resume);
      } else {
        _paused = false;
        _until = null;
        await _environment();
      }
    }
  });

  @override
  Future<void> close() async {
    _timer?.cancel();
    music.onUserPlay = null;
    await _keyboardSubscription.cancel();
    await _lifecycleSubscription.cancel();
    await _tail;
    await audio.stop();
    return super.close();
  }
}
