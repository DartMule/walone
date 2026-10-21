import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

typedef UpdateProcess = Future<ProcessResult> Function(String script);

// Только стабильные x64-установщики из нашего репозитория.
class WindowsRelease {
  const WindowsRelease(this.version, this.url, this.digest, this.size);
  final String version;
  final Uri url;
  final String digest;
  final int size;

  static List<int> versionParts(String value) {
    final match = RegExp(r'^v?(\d+)\.(\d+)\.(\d+)(?:[+.](\d+))?$')
        .firstMatch(value);
    if (match == null) throw const FormatException('Некорректная версия');
    return [for (var i = 1; i <= 4; i++) int.parse(match[i] ?? '0')];
  }

  static int compare(String a, String b) {
    final left = versionParts(a);
    final right = versionParts(b);
    for (var i = 0; i < left.length; i++) {
      final order = left[i].compareTo(right[i]);
      if (order != 0) return order;
    }
    return 0;
  }

  static WindowsRelease? fromGithub(
    Map<String, dynamic> release,
    String current,
  ) {
    if (release['draft'] != false || release['prerelease'] != false) {
      return null;
    }
    final tag = release['tag_name'] as String;
    versionParts(tag);
    final candidates = <WindowsRelease>[];
    for (final asset in release['assets'] as List) {
      final match = RegExp(
        r'^walone-(\d+\.\d+\.\d+\+\d+)-windows-x64-setup\.exe$',
      ).firstMatch(asset['name'] as String);
      if (match == null) continue;
      final version = match[1]!;
      if (compare(version.split('+').first, tag) != 0) {
        throw const FormatException(
          'Версия установщика не совпадает с релизом',
        );
      }
      final url = Uri.parse(asset['browser_download_url'] as String);
      final digest = asset['digest'];
      final size = asset['size'];
      if (url.scheme != 'https' ||
          url.host != 'github.com' ||
          url.hasPort ||
          url.userInfo.isNotEmpty ||
          url.pathSegments.length != 6 ||
          url.pathSegments.take(4).join('/') !=
              'DartMule/walone/releases/download' ||
          url.pathSegments[4] != tag ||
          url.pathSegments.last != asset['name'] ||
          digest is! String ||
          !RegExp(r'^sha256:[a-fA-F0-9]{64}$').hasMatch(digest) ||
          size is! int ||
          size <= 0 ||
          size > 256 * 1024 * 1024) {
        throw const FormatException('Некорректные данные Windows-обновления');
      }
      candidates.add(
        WindowsRelease(version, url, digest.substring(7).toLowerCase(), size),
      );
    }
    if (candidates.length > 1) {
      throw const FormatException('Несколько Windows-установщиков в релизе');
    }
    final candidate = candidates.firstOrNull;
    return candidate != null && compare(candidate.version, current) > 0
        ? candidate
        : null;
  }
}

String powershellLiteral(String value) => "'${value.replaceAll("'", "''")}'";

String encodePowershell(String script) => base64Encode([
  for (final unit in script.codeUnits) ...[unit & 255, unit >> 8],
]);

String get _powershell => p.join(
  Platform.environment['SystemRoot'] ?? r'C:\Windows',
  'System32',
  'WindowsPowerShell',
  'v1.0',
  'powershell.exe',
);

Future<ProcessResult> _runPowershell(String script) async {
  final process = await Process.start(_powershell, [
    '-NoProfile',
    '-NonInteractive',
    '-EncodedCommand',
    encodePowershell(script),
  ]);
  final output = process.stdout.transform(systemEncoding.decoder).join();
  final errors = process.stderr.transform(systemEncoding.decoder).join();
  try {
    final code = await process.exitCode.timeout(const Duration(minutes: 2));
    return ProcessResult(process.pid, code, await output, await errors);
  } on TimeoutException {
    process.kill();
    rethrow;
  }
}

class WindowsUpdates extends ChangeNotifier {
  WindowsUpdates(
    this.directory, {
    UpdateProcess? runProcess,
    HttpClient? client,
  }) : _run = runProcess ?? _runPowershell,
       _client = client ?? HttpClient();
  final Directory directory;
  final UpdateProcess _run;
  final HttpClient _client;
  bool busy = false;
  bool ready = false;
  bool restartAfterUpdate = false;
  bool _disposed = false;
  bool _launched = false;
  double? progress;
  String message = 'Проверка обновлений ещё не выполнялась.';
  WindowsRelease? release;
  File? _installer;
  String? _thumbprint;

  Future<void> check() async {
    if (busy || _disposed || ready) return;
    busy = true;
    message = 'Проверка обновлений…';
    notifyListeners();
    File? partial;
    try {
      _client.connectionTimeout = const Duration(seconds: 30);
      final installed = await _run('''
\$ErrorActionPreference = 'Stop'
\$exe = ${powershellLiteral(Platform.resolvedExecutable)}
\$sig = Get-AuthenticodeSignature -LiteralPath \$exe
if (\$sig.Status -ne 'Valid') { throw 'Walone is not signed by a trusted publisher' }
\$v = (Get-Item -LiteralPath \$exe).VersionInfo
@{version="\$(\$v.FileMajorPart).\$(\$v.FileMinorPart).\$(\$v.FileBuildPart).\$(\$v.FilePrivatePart)"; thumbprint=\$sig.SignerCertificate.Thumbprint} | ConvertTo-Json -Compress
''');
      if (installed.exitCode != 0) {
        throw const FormatException(
          'Автообновления доступны в сборках с доверенной Windows-подписью.',
        );
      }
      final identity = jsonDecode(installed.stdout as String) as Map;
      final thumbprint = identity['thumbprint'] as String;
      if (!RegExp(r'^[A-Fa-f0-9]{40}$').hasMatch(thumbprint)) {
        throw const FormatException('Не удалось проверить издателя Walone');
      }
      _thumbprint = thumbprint;
      final response = await _get(
        Uri.https('api.github.com', '/repos/DartMule/walone/releases/latest'),
      );
      if (response.statusCode == 404) {
        message = 'Windows-обновления ещё не опубликованы.';
        return;
      }
      if (response.statusCode != 200) {
        throw HttpException('GitHub: ${response.statusCode}');
      }
      final bytes = <int>[];
      await for (final chunk in response.timeout(const Duration(seconds: 30))) {
        bytes.addAll(chunk);
        if (bytes.length > 1024 * 1024) {
          throw const FormatException('Слишком большой ответ GitHub');
        }
      }
      release = WindowsRelease.fromGithub(
        jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>,
        identity['version'] as String,
      );
      if (release == null) {
        message = 'Новых Windows-обновлений нет.';
        return;
      }
      if (_disposed) return;
      message = 'Загрузка версии ${release!.version}…';
      notifyListeners();
      await directory.create(recursive: true);
      final download = await _get(release!.url);
      if (download.statusCode != 200) {
        throw HttpException('Загрузка: ${download.statusCode}');
      }
      partial = File(p.join(directory.path, 'installer.part'));
      final sink = partial.openWrite();
      var length = 0;
      try {
        await for (final chunk in download.timeout(
          const Duration(seconds: 30),
        )) {
          length += chunk.length;
          if (length > release!.size) {
            throw const FormatException('Неверный размер обновления');
          }
          sink.add(chunk);
          progress = length / release!.size;
          if (!_disposed) notifyListeners();
        }
        await sink.flush();
      } finally {
        await sink.close();
      }
      if (length != release!.size ||
          (await sha256.bind(partial.openRead()).first).toString() !=
              release!.digest) {
        throw const FormatException('Не совпадает SHA-256 обновления');
      }
      final installer = await partial.rename(
        p.join(directory.path, 'walone-${release!.version}-setup.exe'),
      );
      partial = installer;
      final signature = await _run(_verifyInstaller(installer));
      if (signature.exitCode != 0) {
        throw const FormatException(
          'Не подтверждена подпись издателя обновления',
        );
      }
      if (_disposed) return;
      _installer = installer;
      partial = null;
      ready = true;
      message =
          'Версия ${release!.version} готова. Установится при выходе из Walone.';
    } catch (error) {
      message = 'Не удалось подготовить обновление: $error';
    } finally {
      try {
        if (partial != null && await partial.exists()) await partial.delete();
      } on FileSystemException {
        // Заблокированный антивирусом файл не становится готовым обновлением.
      }
      busy = false;
      progress = null;
      if (!_disposed) notifyListeners();
    }
  }

  Future<HttpClientResponse> _get(Uri uri) async {
    for (var redirects = 0; redirects <= 8; redirects++) {
      if (uri.scheme != 'https' ||
          uri.userInfo.isNotEmpty ||
          uri.hasPort ||
          !{
            'api.github.com',
            'github.com',
            'release-assets.githubusercontent.com',
            'objects.githubusercontent.com',
          }.contains(uri.host)) {
        throw const FormatException('Недопустимый адрес обновления');
      }
      final request = await _client
          .getUrl(uri)
          .timeout(const Duration(seconds: 30));
      request.followRedirects = false;
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'Walone-Windows-Updater',
      );
      final response = await request.close().timeout(
        const Duration(seconds: 30),
      );
      if (!response.isRedirect) return response;
      final location = response.headers.value(HttpHeaders.locationHeader);
      await response.drain<void>().timeout(const Duration(seconds: 30));
      if (location == null) throw const FormatException('Нет адреса загрузки');
      uri = uri.resolve(location);
    }
    throw const FormatException('Слишком много перенаправлений');
  }

  String _verifyInstaller(File installer) =>
      '''
\$ErrorActionPreference = 'Stop'
\$file = ${powershellLiteral(installer.path)}
if ((Get-FileHash -LiteralPath \$file -Algorithm SHA256).Hash -ne ${powershellLiteral(release!.digest)}) { throw 'Invalid update hash' }
\$sig = Get-AuthenticodeSignature -LiteralPath \$file
if (\$sig.Status -ne 'Valid' -or \$sig.SignerCertificate.Thumbprint -ne ${powershellLiteral(_thumbprint!)}) { throw 'Invalid update publisher' }
\$v = (Get-Item -LiteralPath \$file).VersionInfo
\$version = "\$(\$v.FileMajorPart).\$(\$v.FileMinorPart).\$(\$v.FileBuildPart).\$(\$v.FilePrivatePart)"
if (\$version -ne ${powershellLiteral(WindowsRelease.versionParts(release!.version).join('.'))}) { throw 'Invalid installer version' }
''';

  // Вызывается после сохранения медиатеки и закрытия аудио, до выхода процесса.
  Future<void> installOnExit() async {
    if (!ready || _launched || _installer == null) return;
    final installer = _installer!;
    final script =
        '''
trap { \$_ | Out-File -LiteralPath ${powershellLiteral(p.join(directory.path, 'update-install.log'))} -Encoding utf8; exit 1 }
${_verifyInstaller(installer)}
\$app = Get-Process -Id $pid -ErrorAction SilentlyContinue
if (\$app -and -not \$app.WaitForExit(30000)) { throw 'Walone did not exit' }
${_verifyInstaller(installer)}
\$arguments = @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/NOCLOSEAPPLICATIONS', '/DIR="' + ${powershellLiteral(p.dirname(Platform.resolvedExecutable))} + '"')
\$setup = Start-Process -FilePath \$file -ArgumentList \$arguments -PassThru -Wait
if (\$setup.ExitCode -ne 0) { throw "Setup failed: \$(\$setup.ExitCode)" }
${restartAfterUpdate ? 'Start-Process -FilePath ${powershellLiteral(Platform.resolvedExecutable)}' : ''}
Remove-Item -LiteralPath \$file -ErrorAction SilentlyContinue
''';
    await Process.start(_powershell, [
      '-NoProfile',
      '-NonInteractive',
      '-WindowStyle',
      'Hidden',
      '-EncodedCommand',
      encodePowershell(script),
    ], mode: ProcessStartMode.detached);
    _launched = true;
  }

  @override
  void dispose() {
    _disposed = true;
    _client.close(force: true);
    super.dispose();
  }
}
