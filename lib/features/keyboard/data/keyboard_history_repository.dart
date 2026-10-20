import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../core/storage.dart';
import '../domain/keyboard.dart';

class KeyboardHistoryRepository {
  KeyboardHistoryRepository({JsonStore? store}) : _providedStore = store;
  final JsonStore? _providedStore;
  late final Future<JsonStore> _store = _open();
  Future<void> _tail = Future.value();

  Future<JsonStore> _open() async =>
      _providedStore ??
      JsonStore(
        File(
          p.join(
            (await JsonStore.applicationDirectory()).path,
            'keyboard-history.json',
          ),
        ),
      );

  static List<KeyboardUsage> merge(
    Iterable<KeyboardUsage> entries,
    Set<String> known,
  ) {
    final latest = <String, KeyboardUsage>{};
    for (final entry in entries) {
      if (!known.contains(entry.packID)) continue;
      final previous = latest[entry.packID];
      if (previous == null || entry.lastUsed.isAfter(previous.lastUsed)) {
        latest[entry.packID] = entry;
      }
    }
    return latest.values.toList()..sort((a, b) {
      final order = b.lastUsed.compareTo(a.lastUsed);
      return order == 0 ? a.packID.compareTo(b.packID) : order;
    });
  }

  Future<List<KeyboardUsage>> read(Set<String> known) async {
    final store = await _store;
    try {
      final data = await store.read();
      if (data == null) return [];
      if (data['version'] != 1) {
        throw const FormatException('Неизвестная версия истории');
      }
      return merge(
        (data['history'] as List<dynamic>).map(
          (row) => KeyboardUsage.fromJson(jsonMap(row)),
        ),
        known,
      );
    } catch (_) {
      store.protect();
      rethrow;
    }
  }

  Future<void> save(List<KeyboardUsage> entries) {
    final write = _tail.then(
      (_) async => (await _store).write({
        'version': 1,
        'history': entries.map((entry) => entry.toJson()).toList(),
      }),
    );
    _tail = write.catchError((Object _) {});
    return write;
  }

  Future<void> flush() => _tail;
}
