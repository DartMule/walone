import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../domain/import.dart';
import 'music_process.dart';

class VkSession {
  VkSession(
    this.directory, {
    Future<Webview> Function(CreateConfiguration)? createView,
  }) : _createView =
           createView ??
           ((configuration) =>
               WebviewWindow.create(configuration: configuration));
  final Directory directory;
  final Future<Webview> Function(CreateConfiguration) _createView;
  Webview? _view;
  bool _closed = false;
  bool _loginCompleted = false;
  Timer? _loginTimer;
  bool _checkingLogin = false;
  static const _signedInScript = '''
    if (!['vk.ru','vk.com','m.vk.ru','m.vk.com','www.vk.ru','www.vk.com'].includes(location.hostname)) return {ok:false};
    const id = Number(window.vk?.id || (document.cookie.match(/(?:^|;\\s*)remixmid=(\\d+)/) || [])[1]);
    return {ok: Number.isSafeInteger(id) && id > 0};
  ''';

  void _watchLogin(Webview view) {
    _loginTimer?.cancel();
    _loginTimer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => _checkLogin(view),
    );
  }

  Future<void> _checkLogin(Webview view) async {
    if (_checkingLogin || _loginCompleted || !identical(_view, view)) return;
    _checkingLogin = true;
    try {
      if (await _isSignedIn(view)) {
        await _finishLogin(view);
      }
    } catch (_) {
      // Документ может ещё загружаться или окно могло быть закрыто.
    } finally {
      _checkingLogin = false;
    }
  }

  Future<bool> _isSignedIn(Webview view) async {
    final raw = await view.evaluateJavaScript(
      'JSON.stringify((() => {$_signedInScript})())',
    );
    Object? result = jsonDecode(raw ?? 'null');
    if (result is String) result = jsonDecode(result);
    return result is Map<String, dynamic> && result['ok'] == true;
  }

  Future<void> _setLoginVisible(Webview view, bool visible) async {
    // Плагин реализует управление видимостью только на Windows.
    if (Platform.isMacOS) {
      await const MethodChannel('dev.soyjanks.walone/desktop')
          .invokeMethod<void>('setVkLoginVisible', visible);
    } else {
      await view.setWebviewWindowVisibility(visible);
    }
  }

  Future<void> _finishLogin(Webview view) async {
    if (!identical(_view, view)) return;
    _loginCompleted = true;
    try {
      await _setLoginVisible(view, false);
    } catch (_) {
      _loginCompleted = false;
      rethrow;
    }
    _loginTimer?.cancel();
    _loginTimer = null;
  }

  static bool isLoginComplete(String text) {
    final uri = Uri.tryParse(text);
    return allows(text) &&
        [
          'vk.ru',
          'vk.com',
          'www.vk.ru',
          'www.vk.com',
          'm.vk.ru',
          'm.vk.com',
        ].contains(uri?.host) &&
        uri?.path == '/feed';
  }

  static bool allows(String text) {
    final uri = Uri.tryParse(text);
    return uri != null &&
        uri.scheme == 'https' &&
        uri.userInfo.isEmpty &&
        !uri.hasPort &&
        [
          'vk.ru',
          'vk.com',
        ].any((host) => uri.host == host || uri.host.endsWith('.$host'));
  }

  Future<void> open() async {
    if (_view != null) {
      if (_loginCompleted) return;
      _watchLogin(_view!);
      await _setLoginVisible(_view!, true);
      await _view!.bringToForeground();
      return;
    }
    await directory.create(recursive: true);
    if (!await WebviewWindow.isWebviewAvailable()) {
      throw StateError(
        'Установите Microsoft Edge WebView2 Runtime для входа VK',
      );
    }
    final view = await _createView(
      CreateConfiguration(
        title: 'Вход VK — Walone',
        windowWidth: 1000,
        windowHeight: 760,
        titleBarHeight: 0,
        userDataFolderWindows: p.join(directory.path, 'VK-WebView2'),
        denyCameraAndMicrophone: true,
      ),
    );
    _view = view;
    _closed = false;
    _loginCompleted = false;
    view.setOnUrlRequestCallback((url) {
      if (!allows(url)) return false;
      // Скрываем окно до загрузки ленты, сохраняя WebView для импорта.
      if (isLoginComplete(url)) {
        unawaited(_finishLogin(view));
      }
      return true;
    });
    // Перенаправления и SPA-переходы VK могут не вызвать URL callback.
    _watchLogin(view);
    view.launch('https://vk.ru/');
    unawaited(
      view.onClose.then((_) {
        if (identical(_view, view)) {
          _loginTimer?.cancel();
          _view = null;
          _closed = true;
        }
      }),
    );
  }

  Future<void> forget() async {
    _loginTimer?.cancel();
    _view?.close();
    _view = null;
    _loginCompleted = false;
    await WebviewWindow.clearAll(
      userDataFolderWindows: p.join(directory.path, 'VK-WebView2'),
    );
  }

  Future<Map<String, dynamic>> evaluate(
    String body,
    Map<String, dynamic> arguments,
    MusicProcess worker, {
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final view = _view;
    if (view == null || _closed) {
      throw StateError('Откройте «Войти в VK» и завершите вход');
    }
    final token = '__walone_${const Uuid().v4().replaceAll('-', '')}';
    final key = jsonEncode(token);
    final declarations = arguments.entries
        .map((e) => 'const ${e.key} = ${jsonEncode(e.value)};')
        .join('\n');
    await view.evaluateJavaScript(
      'window[$key] = null; (async () => { $declarations\n$body\n })().then(value => window[$key] = value).catch(() => window[$key] = {reason:"script"}); null;',
    );
    final deadline = DateTime.now().add(timeout);
    try {
      while (DateTime.now().isBefore(deadline)) {
        worker.check();
        if (_closed) throw StateError('Окно VK закрыто');
        final raw = await view.evaluateJavaScript(
          'JSON.stringify(window[$key] || null)',
        );
        if (raw != null && raw != 'null') {
          Object? data = jsonDecode(raw);
          if (data is String) data = jsonDecode(data);
          if (data is Map<String, dynamic>) return data;
        }
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      throw StateError('VK не ответил. Проверьте вход и доступ к записи.');
    } finally {
      try {
        await view.evaluateJavaScript('delete window[$key]; null;');
      } catch (_) {
        /* Окно могло быть закрыто пользователем. */
      }
    }
  }

  Future<Map<String, dynamic>> catalog(
    MusicLink link,
    MusicProcess worker, {
    int limit = 500,
  }) async {
    await open();
    final view = _view!;
    view.launch(link.url);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final deadline = DateTime.now().add(const Duration(seconds: 30));
    var signedIn = false;
    // VK восстанавливает данные сессии и после завершения навигации WebView.
    while (DateTime.now().isBefore(deadline)) {
      worker.check();
      if (_closed) throw StateError('Окно VK закрыто');
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (view.isNavigating.value) continue;
      try {
        signedIn = await _isSignedIn(view);
        if (signedIn) break;
      } catch (_) {
        // Перенаправление может заменить документ во время проверки.
      }
    }
    worker.check();
    if (!signedIn) {
      _loginCompleted = false;
      _watchLogin(view);
      await _setLoginVisible(view, true);
      await view.bringToForeground();
      throw StateError('Завершите вход в окне VK, затем повторите импорт');
    }
    await _finishLogin(view);
    final result = await evaluate(
      await rootBundle.loadString('assets/import/catalogScript.js'),
      {
        'targetOwnerID': link.owner,
        'targetID': link.id,
        'accessKey': link.accessKey,
        'isPlaylist': link.playlist,
        'trackLimit': limit,
      },
      worker,
      timeout: const Duration(minutes: 30),
    );
    if (result['tracks'] is! List<dynamic> ||
        (result['tracks'] as List<dynamic>).isEmpty) {
      throw StateError(
        'VK не вернул полный список. Проверьте вход и доступ к плейлисту.',
      );
    }
    await _setLoginVisible(view, false);
    return result;
  }

  Future<Map<String, dynamic>> resolve(
    Map<String, dynamic> track,
    MusicProcess worker,
  ) async =>
      evaluate(await rootBundle.loadString('assets/import/resolveScript.js'), {
        'targetOwnerID': track['ownerID'],
        'targetTrackID': track['id'],
        'rawTrack': track['raw'],
      }, worker);

  Future<void> cancel() async {
    try {
      await _view?.evaluateJavaScript(
        'window.__waloneVKCancelled = true; window.__waloneVKRequest?.abort(); null;',
      );
    } catch (_) {
      /* Отмена при закрытом окне уже завершена. */
    }
  }

  // Незавершённый вход оставляем открытым; cookies при закрытии сохраняются.
  void release() {
    if (_loginCompleted) dispose();
  }

  void dispose() {
    _loginTimer?.cancel();
    _loginTimer = null;
    final view = _view;
    _view = null;
    _closed = true;
    _loginCompleted = false;
    view?.close();
  }
}
