import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/keyboard.dart';
import '../data/keyboard_history_repository.dart';
import '../data/keyboard_preview.dart';

class KeyboardState {
  const KeyboardState({
    this.packs = const [],
    this.selected,
    this.volume = 0.35,
    this.status = const KeyboardStatus(),
    this.loading = true,
    this.busy = false,
    this.error,
    this.history = const [],
    this.historyError,
    this.previewID,
  });

  final List<KeyboardPack> packs;
  final KeyboardPack? selected;
  final double volume;
  final KeyboardStatus status;
  final bool loading;
  final bool busy;
  final String? error;
  final List<KeyboardUsage> history;
  final String? historyError;
  final String? previewID;

  KeyboardState copyWith({
    List<KeyboardPack>? packs,
    KeyboardPack? selected,
    double? volume,
    KeyboardStatus? status,
    bool? loading,
    bool? busy,
    String? error,
    List<KeyboardUsage>? history,
    String? historyError,
    bool clearHistoryError = false,
    String? previewID,
    bool clearPreview = false,
  }) => KeyboardState(
    packs: packs ?? this.packs,
    selected: selected ?? this.selected,
    volume: volume ?? this.volume,
    status: status ?? this.status,
    loading: loading ?? this.loading,
    busy: busy ?? this.busy,
    error: error,
    history: history ?? this.history,
    historyError: clearHistoryError ? null : historyError ?? this.historyError,
    previewID: clearPreview ? null : previewID ?? this.previewID,
  );
}

class KeyboardCubit extends Cubit<KeyboardState> {
  KeyboardCubit(
    this._repository, {
    this.historyRepository,
    KeyboardPreview? preview,
  }) : _preview = preview ?? KeyboardPreview(),
       super(const KeyboardState()) {
    _preview.onChanged = (id) {
      if (!isClosed) {
        emit(
          state.copyWith(
            previewID: id,
            clearPreview: id == null,
            error: state.error,
          ),
        );
      }
    };
    _preview.onError = (message) {
      if (!isClosed) emit(state.copyWith(error: message));
    };
  }

  final KeyboardRepository _repository;
  final KeyboardHistoryRepository? historyRepository;
  final KeyboardPreview _preview;
  double _master = 0.7;
  bool _allowed = true;
  Timer? _timer;
  bool _polling = false;

  Future<void> initialize() async {
    if (state.selected != null || state.busy) return;
    emit(state.copyWith(busy: true, loading: true));
    try {
      final packs = await _repository.loadCatalog();
      if (isClosed) return;
      if (packs.isEmpty) {
        throw StateError('Каталог клавиатур пуст');
      }
      final status = await _repository.initialize();
      var history = <KeyboardUsage>[];
      String? historyError;
      try {
        history =
            await historyRepository?.read(packs.map((p) => p.id).toSet()) ?? [];
      } catch (error) {
        historyError =
            'Не удалось прочитать историю. Исходный файл сохранён без перезаписи: $error';
      }
      if (isClosed) return;
      final selected = history.isEmpty
          ? packs.first
          : packs.firstWhere((pack) => pack.id == history.first.packID);
      await _repository.configure(selected, false, state.volume);
      if (isClosed) return;
      emit(
        state.copyWith(
          packs: packs,
          selected: selected,
          status: status,
          loading: false,
          busy: false,
          history: List.unmodifiable(history),
          historyError: historyError,
        ),
      );
      // Счётчик обновляется отдельно от нативного тракта воспроизведения.
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => refresh());
    } catch (error) {
      if (!isClosed) {
        emit(state.copyWith(loading: false, busy: false, error: '$error'));
      }
    }
  }

  Future<void> refresh() async {
    if (isClosed || state.busy || _polling) return;
    _polling = true;
    try {
      final status = await _repository.status();
      if (!isClosed && !state.busy && status != state.status) {
        emit(state.copyWith(status: status, error: state.error));
      }
    } catch (error) {
      if (!isClosed) emit(state.copyWith(error: '$error'));
    } finally {
      _polling = false;
    }
  }

  Future<void>? _volumeTail;
  double? _appliedVolume;
  int _volumeRevision = 0;

  Future<void> _setVolume(double volume) {
    if (isClosed || state.busy || state.selected == null || !volume.isFinite) {
      return Future.value();
    }
    final next = volume.clamp(0.0, 1.0);
    final revision = ++_volumeRevision;
    _appliedVolume ??= state.volume;
    emit(state.copyWith(volume: next));
    _volumeTail = (_volumeTail ?? Future<void>.value()).then((_) async {
      if (isClosed) return;
      final requested = state.volume;
      try {
        await _repository.configure(
          state.selected!,
          state.status.enabled,
          requested,
        );
        _appliedVolume = requested;
        await _preview.environment(_master, _allowed, state.volume);
      } catch (error) {
        if (!isClosed) {
          emit(
            state.copyWith(
              volume: revision == _volumeRevision ? _appliedVolume : null,
              error: '$error',
            ),
          );
        }
      }
    });
    return _volumeTail!;
  }

  Future<void> configure({
    KeyboardPack? pack,
    bool? enabled,
    double? volume,
    bool recordUsage = false,
  }) async {
    if (volume != null && pack == null && enabled == null && !recordUsage) {
      return _setVolume(volume);
    }
    if (_volumeTail != null) await _volumeTail;
    final selected = pack ?? state.selected;
    if (state.busy || selected == null) return;
    emit(state.copyWith(busy: true));
    final nextVolume = (volume ?? state.volume).clamp(0.0, 1.0);
    try {
      if (enabled == true && !state.status.enabled) {
        final status = await _repository.status();
        if (!status.hasPermission) await _repository.requestPermission();
      }
      if (pack != null) await stopPreview();
      await _repository.configure(
        selected,
        enabled ?? state.status.enabled,
        nextVolume,
      );
      _appliedVolume = nextVolume;
      final status = await _repository.status();
      var history = state.history;
      String? historyError;
      if (recordUsage) {
        history = List.unmodifiable([
          KeyboardUsage(packID: selected.id, lastUsed: DateTime.now().toUtc()),
          ...history.where((entry) => entry.packID != selected.id),
        ]);
        try {
          await historyRepository?.save(history);
        } catch (error) {
          historyError = 'Не удалось сохранить историю: $error';
        }
      }
      await _preview.environment(_master, _allowed, nextVolume);
      if (!isClosed) {
        emit(
          state.copyWith(
            selected: selected,
            volume: nextVolume,
            status: status,
            busy: false,
            history: history,
            historyError: historyError,
            clearHistoryError: recordUsage && historyError == null,
          ),
        );
      }
    } catch (error) {
      if (!isClosed) emit(state.copyWith(busy: false, error: '$error'));
    }
  }

  Future<void> choose(KeyboardPack pack) =>
      configure(pack: pack, recordUsage: true);

  Future<void> preview({KeyboardPack? pack, int? group}) async {
    final candidate = pack ?? state.selected;
    if (state.busy || candidate == null || !_allowed) return;
    if (group == null && state.previewID == candidate.id) {
      await stopPreview();
      return;
    }
    if (state.error != null) emit(state.copyWith());
    await _preview.play(candidate, group: group, volume: state.volume);
  }

  Future<void> stopPreview() async {
    try {
      await _preview.stop();
    } catch (error) {
      if (!isClosed) emit(state.copyWith(error: '$error'));
    }
  }

  Future<void> previewEnvironment(double master, bool allowed) async {
    _master = master;
    _allowed = allowed;
    await _preview.environment(master, allowed, state.volume);
  }

  Future<void> requestPermission() => _action(_repository.requestPermission);

  Future<void> _action(Future<void> Function() action) async {
    if (state.busy) return;
    emit(state.copyWith(busy: true));
    try {
      await action();
      final status = await _repository.status();
      if (!isClosed) emit(state.copyWith(status: status, busy: false));
    } catch (error) {
      if (!isClosed) emit(state.copyWith(busy: false, error: '$error'));
    }
  }

  @override
  Future<void> close() async {
    _timer?.cancel();
    _preview.onChanged = null;
    _preview.onError = null;
    if (_volumeTail != null) await _volumeTail;
    await _preview.dispose();
    await historyRepository?.flush();
    await super.close();
    await _repository.dispose();
  }
}
