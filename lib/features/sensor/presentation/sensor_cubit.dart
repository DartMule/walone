import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SensorState {
  const SensorState({this.values = const {}, this.busy = false, this.error});
  final Map<String, dynamic> values;
  final bool busy;
  final String? error;
  bool get enabled => values['enabled'] == true;
  bool get collecting => values['collecting'] == true;
  bool get hasCalibration => values['hasCalibration'] == true;
  double get sensitivity => (values['sensitivity'] as num?)?.toDouble() ?? 0.08;
  double get intensity => (values['intensity'] as num?)?.toDouble() ?? 0;
  int get stage => values['stage'] as int? ?? 0;
  String text(String key) => values[key] as String? ?? '';
}

class SensorCubit extends Cubit<SensorState> {
  SensorCubit({
    this.channel = const MethodChannel('dev.soyjanks.walone/keyboard'),
  }) : super(const SensorState());

  final MethodChannel channel;
  Timer? _timer;
  bool _polling = false;

  Future<void> initialize() async {
    await refresh();
    if (!isClosed) {
      _timer ??= Timer.periodic(const Duration(seconds: 1), (_) => refresh());
    }
  }

  Future<void> refresh() async {
    if (isClosed || state.busy || _polling) return;
    _polling = true;
    try {
      final values = await channel.invokeMapMethod<String, dynamic>(
        'sensorStatus',
      );
      if (!isClosed && !state.busy && values != null) {
        emit(SensorState(values: values, error: state.error));
      }
    } catch (error) {
      if (!isClosed) emit(SensorState(values: state.values, error: '$error'));
    } finally {
      _polling = false;
    }
  }

  Future<void> configure({
    bool? enabled,
    double? sensitivity,
    int? stage,
    bool? collecting,
  }) => command('sensorConfigure', {
    'enabled': enabled ?? state.enabled,
    'sensitivity': sensitivity ?? state.sensitivity,
    'stage': stage ?? state.stage,
    'collecting': collecting ?? state.collecting,
  });

  Future<void> command(String method, [Map<String, dynamic>? arguments]) async {
    if (isClosed || state.busy) return;
    emit(SensorState(values: state.values, busy: true));
    try {
      final values = await channel.invokeMapMethod<String, dynamic>(
        method,
        arguments,
      );
      if (!isClosed) emit(SensorState(values: values ?? state.values));
    } catch (error) {
      if (!isClosed) emit(SensorState(values: state.values, error: '$error'));
    }
  }

  @override
  Future<void> close() async {
    _timer?.cancel();
    return super.close();
  }
}
