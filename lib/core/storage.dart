import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class JsonStore {
  JsonStore(this.file);
  final File file;
  bool _readable = true;

  static Future<Directory> applicationDirectory() async => Directory(
    p.join((await getApplicationSupportDirectory()).path, 'WaloneFlutter'),
  );

  Future<Map<String, dynamic>?> read() async {
    try {
      if (!await file.exists()) return null;
      if (await file.length() > 16 * 1024 * 1024) {
        throw const FormatException('Слишком большой манифест');
      }
      return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      _readable = false;
      rethrow;
    }
  }

  void protect() => _readable = false;

  Future<void> write(Map<String, dynamic> value) async {
    if (!_readable) {
      throw StateError(
        'Повреждённый манифест сохранён без перезаписи: ${file.path}',
      );
    }
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.${const Uuid().v4()}.tmp');
    try {
      await temporary.writeAsString(jsonEncode(value), flush: true);
      await temporary.rename(file.path);
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  }
}

String checkedName(String name) {
  final result = name.trim();
  if (result.isEmpty || result.runes.length > 80) {
    throw const FormatException(
      'Название должно содержать от 1 до 80 символов',
    );
  }
  return result;
}

Map<String, dynamic> jsonMap(Object? value) => value as Map<String, dynamic>;
double finiteNumber(
  Object? value, {
  double min = 0,
  double max = double.infinity,
}) {
  final number = (value as num).toDouble();
  if (!number.isFinite || number < min || number > max) {
    throw const FormatException('Некорректное число');
  }
  return number;
}
