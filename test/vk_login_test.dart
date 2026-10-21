import 'dart:async';
import 'dart:io';

import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walone/features/music/data/vk_session.dart';
import 'package:walone/features/music/data/music_process.dart';
import 'package:walone/features/music/domain/import.dart';

class LoginView implements Webview {
  final closed = Completer<void>();
  final hidden = Completer<void>();
  final visibility = <bool>[];
  bool signedIn = false;
  @override
  Future<void> get onClose => closed.future;
  @override
  void setOnUrlRequestCallback(OnUrlRequestCallback? callback) {}
  @override
  void launch(String url, {bool triggerOnUrlRequestEvent = true}) {}
  @override
  Future<String?> evaluateJavaScript(String script) async =>
      signedIn ? '{"ok":true}' : '{"ok":false}';
  @override
  Future<void> setWebviewWindowVisibility(bool visible) async {
    visibility.add(visible);
    if (!visible && !hidden.isCompleted) hidden.complete();
  }

  @override
  Future<void> bringToForeground({bool maximized = false}) async {}
  @override
  void close() {
    if (!closed.isCompleted) closed.complete();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class CatalogView extends LoginView {
  @override
  final ValueNotifier<bool> isNavigating = ValueNotifier(false);
  Timer? ready;
  bool catalogStarted = false;

  @override
  void launch(String url, {bool triggerOnUrlRequestEvent = true}) {
    if (!url.contains('/audio')) return;
    // Документ загружен, но VK ещё восстанавливает сессию в новой странице.
    signedIn = false;
    ready = Timer(const Duration(milliseconds: 900), () => signedIn = true);
  }

  @override
  Future<String?> evaluateJavaScript(String script) async {
    if (script.contains('const targetOwnerID')) catalogStarted = true;
    if (script.startsWith('JSON.stringify(window[') && catalogStarted) {
      return '{"tracks":[{"id":"1"}]}';
    }
    return super.evaluateJavaScript(script);
  }

  @override
  void close() {
    ready?.cancel();
    isNavigating.dispose();
    super.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Импорт ждёт восстановления VK-сессии после перехода', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('webview_window'),
          (_) async => true,
        );
    final directory = await Directory.systemTemp.createTemp(
      'walone-vk-catalog-',
    );
    final view = CatalogView()..signedIn = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dev.soyjanks.walone/desktop'),
          (call) async {
            await view.setWebviewWindowVisibility(call.arguments as bool);
            return null;
          },
        );
    final session = VkSession(directory, createView: (_) async => view);
    try {
      await session.open();
      await view.hidden.future.timeout(const Duration(seconds: 2));
      final result = await session.catalog(
        MusicLink.detect('https://vk.ru/audio123_1'),
        MusicProcess(),
        limit: 1,
      );
      expect(result['tracks'], hasLength(1));
      expect(
        view.visibility,
        isNot(contains(true)),
        reason:
            'Подтверждённый вход не должен снова требоваться во время загрузки',
      );
    } finally {
      session.dispose();
      await directory.delete(recursive: true);
    }
  });

  test(
    'Вход без URL callback скрывает сайт и не открывает его повторно',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('webview_window'),
            (_) async => true,
          );
      final directory = await Directory.systemTemp.createTemp(
        'walone-vk-login-',
      );
      var view = LoginView();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('dev.soyjanks.walone/desktop'),
            (call) async {
              expect(call.method, 'setVkLoginVisible');
              await view.setWebviewWindowVisibility(call.arguments as bool);
              return null;
            },
          );
      final session = VkSession(directory, createView: (_) async => view);
      try {
        await session.open();
        session.release();
        expect(view.closed.isCompleted, isFalse);
        await Future<void>.delayed(const Duration(milliseconds: 550));
        expect(view.visibility, isEmpty);
        // Перенаправление VK завершает вход без уведомления обработчика URL.
        view.signedIn = true;
        await view.hidden.future.timeout(const Duration(seconds: 2));
        await session.open();
        expect(view.visibility, [false]);
        session.release();
        expect(view.closed.isCompleted, isTrue);
        // Новое окно использует тот же профиль, не очищая сохранённый вход.
        view = LoginView();
        await session.open();
        expect(view.closed.isCompleted, isFalse);
        view.signedIn = true;
        await view.hidden.future.timeout(const Duration(seconds: 2));
        session.release();
        expect(view.closed.isCompleted, isTrue);
      } finally {
        session.dispose();
        await directory.delete(recursive: true);
      }
    },
  );
}
