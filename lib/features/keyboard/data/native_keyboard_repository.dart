import 'dart:convert';

import 'package:flutter/services.dart';

import '../domain/keyboard.dart';

class NativeKeyboardRepository implements KeyboardRepository {
  const NativeKeyboardRepository({
    this.channel = const MethodChannel('dev.soyjanks.walone/keyboard'),
  });

  final MethodChannel channel;

  @override
  Future<List<KeyboardPack>> loadCatalog() async {
    final data =
        jsonDecode(await rootBundle.loadString('assets/catalog.json'))
            as List<dynamic>;
    return List.unmodifiable(
      data.map((item) {
        final row = item as Map<String, dynamic>;
        return KeyboardPack(
          id: row['id'] as String,
          title: row['title'] as String,
          detail: row['detail'] as String,
          author: row['author'] as String,
          keyCount: row['keyCount'] as int,
        );
      }),
    );
  }

  Future<KeyboardStatus> _read(String method) async {
    final row = await channel.invokeMapMethod<String, dynamic>(method);
    if (row == null) throw StateError('Нативный модуль не вернул состояние');
    return KeyboardStatus(
      hasPermission: row['hasPermission'] as bool,
      listening: row['listening'] as bool,
      secureInput: row['secureInput'] as bool,
      enabled: row['enabled'] as bool,
      receivedKeys: row['receivedKeys'] as int,
      error: row['error'] as String?,
    );
  }

  @override
  Future<KeyboardStatus> initialize() => _read('initialize');

  @override
  Future<KeyboardStatus> status() => _read('status');

  @override
  Future<void> configure(KeyboardPack pack, bool enabled, double volume) =>
      channel.invokeMethod<void>('configure', {
        'pack': pack.id,
        'keyCount': pack.keyCount,
        'enabled': enabled,
        'volume': volume,
      });

  @override
  Future<void> preview() => channel.invokeMethod<void>('preview');

  @override
  Future<void> requestPermission() =>
      channel.invokeMethod<void>('requestPermission');

  @override
  Future<void> dispose() => channel.invokeMethod<void>('dispose');
}
