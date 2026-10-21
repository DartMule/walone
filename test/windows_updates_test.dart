import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walone/features/settings/data/windows_updates.dart';

Map<String, dynamic> manifest(List<int> bytes) => {
  'tag_name': 'v0.1.4',
  'draft': false,
  'prerelease': false,
  'assets': [
    <String, dynamic>{
      'name': 'walone-0.1.4+5-windows-x64-setup.exe',
      'size': bytes.length,
      'digest': 'sha256:${sha256.convert(bytes)}',
      'browser_download_url': 'https://github.com/DartMule/walone/releases/download/v0.1.4/walone-0.1.4+5-windows-x64-setup.exe',
    },
  ],
};

class _Response extends Stream<List<int>> implements HttpClientResponse {
  _Response(this.bytes);
  final List<int> bytes;
  @override
  final int statusCode = 200;
  @override
  bool get isRedirect => false;
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream.value(bytes).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Headers implements HttpHeaders {
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Request implements HttpClientRequest {
  _Request(this.response);
  final _Response response;
  @override
  bool followRedirects = true;
  @override
  final HttpHeaders headers = _Headers();
  @override
  Future<HttpClientResponse> close() async => response;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Client implements HttpClient {
  _Client(this.responses);
  final List<_Response> responses;
  int requests = 0;
  @override
  Duration? connectionTimeout;
  @override
  Future<HttpClientRequest> getUrl(Uri url) async =>
      _Request(responses[requests++]);
  @override
  void close({bool force = false}) {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final payload = utf8.encode('signed installer fixture');
  test('Сравнение числовых версий и номера сборки исключает откат', () {
    expect(WindowsRelease.compare('0.1.10+1', '0.1.9.99'), greaterThan(0));
    expect(WindowsRelease.compare('0.1.3+5', '0.1.3.4'), greaterThan(0));
    expect(WindowsRelease.compare('0.1.3+4', 'v0.1.3'), greaterThan(0));
    expect(WindowsRelease.compare('v1.0.0', '1.0.0.0'), 0);
    expect(
      () => WindowsRelease.compare('1.0.0-beta', '1.0.0'),
      throwsFormatException,
    );
    expect(WindowsRelease.fromGithub(manifest(payload), '0.1.4.5'), isNull);
  });

  test('Релиз принимает только наш стабильный установщик с SHA-256', () {
    expect(
      WindowsRelease.fromGithub(manifest(payload), '0.1.3.4')!.version,
      '0.1.4+5',
    );
    expect(
      WindowsRelease.fromGithub({
        ...manifest(payload),
        'prerelease': true,
      }, '0.1.3'),
      isNull,
    );
    expect(
      WindowsRelease.fromGithub({...manifest(payload), 'draft': true}, '0.1.3'),
      isNull,
    );
    for (final change in [
      {'digest': null},
      {'size': -1},
      {'size': 300 * 1024 * 1024},
      {
        'browser_download_url': 'https://github.com/other/repo/releases/download/v0.1.4/walone-0.1.4+5-windows-x64-setup.exe',
      },
      {
        'browser_download_url': 'http://github.com/DartMule/walone/releases/download/v0.1.4/walone-0.1.4+5-windows-x64-setup.exe',
      },
      {'name': 'walone-0.1.5+5-windows-x64-setup.exe'},
    ]) {
      final data = manifest(payload);
      (data['assets'] as List)[0].addAll(change);
      expect(
        () => WindowsRelease.fromGithub(data, '0.1.3'),
        throwsFormatException,
      );
    }
    final duplicate = manifest(payload);
    (duplicate['assets'] as List).add((duplicate['assets'] as List).first);
    expect(
      () => WindowsRelease.fromGithub(duplicate, '0.1.3'),
      throwsFormatException,
    );
  });

  test('PowerShell: пути с кавычками и Unicode не исполняются как команды', () {
    const path = "C:\\Музыка O'Brien\\\$data`track.exe";
    expect(powershellLiteral(path), "'C:\\Музыка O''Brien\\\$data`track.exe'");
    final bytes = base64Decode(encodePowershell(path));
    expect(
      String.fromCharCodes([
        for (var i = 0; i < bytes.length; i += 2) bytes[i] | bytes[i + 1] << 8,
      ]),
      path,
    );
  });

  for (final scenario in ['ready', 'hash', 'size', 'signature', 'unsigned']) {
    test('Подготовка обновления: $scenario', () async {
      final root = await Directory.systemTemp.createTemp('walone-update-');
      addTearDown(() => root.delete(recursive: true));
      final client = _Client([
        _Response(utf8.encode(jsonEncode(manifest(payload)))),
        _Response(
          scenario == 'hash'
              ? List.filled(payload.length, 0)
              : scenario == 'size'
              ? [0]
              : payload,
        ),
      ]);
      final scripts = <String>[];
      final updates = WindowsUpdates(
        root,
        client: client,
        runProcess: (script) async {
          scripts.add(script);
          if (scripts.length == 1) {
            return ProcessResult(
              1,
              scenario == 'unsigned' ? 1 : 0,
              jsonEncode({'version': '0.1.3.4', 'thumbprint': 'A' * 40}),
              '',
            );
          }
          expect(script, contains('Get-AuthenticodeSignature'));
          expect(script, contains('Get-FileHash'));
          expect(script, contains('A' * 40));
          return ProcessResult(1, scenario == 'signature' ? 1 : 0, '', '');
        },
      );
      addTearDown(updates.dispose);
      await updates.check();
      expect(updates.busy, isFalse);
      expect(updates.ready, scenario == 'ready');
      if (scenario == 'ready') {
        expect(await root.list().length, 1);
        await updates.check();
        expect(client.requests, 2);
      } else {
        expect(await root.list().length, 0);
        expect(updates.message, contains('Не удалось'));
      }
      if (scenario == 'unsigned') expect(client.requests, 0);
    });
  }
}
