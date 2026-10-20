import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:walone/features/keyboard/data/native_keyboard_repository.dart';
import 'package:walone/features/keyboard/presentation/keyboard_cubit.dart';
import 'package:walone/features/keyboard/presentation/keyboard_page.dart';
import 'package:walone/main.dart';

// Запускается через tool/check_keyboard_permission.py в отдельной копии приложения.
class DeniedKeyboardRepository extends NativeKeyboardRepository {
  const DeniedKeyboardRepository();

  // Имитируем отказ в диалоге, не открывая настройки и не меняя разрешения ОС.
  @override
  Future<void> requestPermission() async {}
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Поле печати работает без разрешения мониторинга ввода', (
    tester,
  ) async {
    const repository = DeniedKeyboardRepository();
    await tester.pumpWidget(
      const WaloneApp(repository: repository, keyboardOnly: true),
    );
    await tester.pumpAndSettle();
    final cubit = tester
        .element(find.byType(KeyboardPage))
        .read<KeyboardCubit>();
    await cubit.configure(volume: 0);

    final typing = find.byKey(const ValueKey('keyboard-typing'));
    for (final enabled in [false, true, false]) {
      if (enabled != cubit.state.status.enabled) {
        await cubit.configure(enabled: enabled);
        await tester.pumpAndSettle();
      }
      expect(cubit.state.status.hasPermission, isFalse);
      expect(cubit.state.status.listening, isFalse);
      expect(cubit.state.status.enabled, enabled);
      expect(cubit.state.busy, isFalse);
      expect(cubit.state.error, isNull);
      expect(cubit.state.status.error, isNull);
      expect(find.text('Разрешить…'), findsOneWidget);
      debugPrint(
        'Мониторинг ввода: доступ=false, прослушивание=false, звук=$enabled',
      );

      await Scrollable.ensureVisible(
        tester.element(find.text('Проверить звучание')),
        alignment: 0.5,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Проверить звучание'));
      await tester.pumpAndSettle();
      await Scrollable.ensureVisible(tester.element(typing), alignment: 0.5);
      await tester.pumpAndSettle();
      expect(find.byType(ErrorWidget), findsNothing);
      expect(tester.takeException(), isNull);
      expect(tester.getSize(typing).height, lessThan(100));
      // Тот же callback, которым движок доставляет текст; работает и в AOT,
      // где debug-подстановка клиента в tester.enterText отключена.
      tester
          .state<EditableTextState>(
            find.descendant(of: typing, matching: find.byType(EditableText)),
          )
          .updateEditingValue(TextEditingValue(text: 'Без разрешения: $enabled'));
      await tester.pump();
      expect(find.text('Без разрешения: $enabled'), findsOneWidget);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await cubit.refresh();
      expect(cubit.state.status.hasPermission, isFalse);
      expect(cubit.state.status.listening, isFalse);
      expect(cubit.state.status.error, isNull);
      expect(cubit.state.error, isNull);
      expect(find.byType(ErrorWidget), findsNothing);
      expect(tester.takeException(), isNull);
      await Scrollable.ensureVisible(
        tester.element(find.text('Проверить звучание')),
        alignment: 0.5,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Проверить звучание'));
      await tester.pumpAndSettle();
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
