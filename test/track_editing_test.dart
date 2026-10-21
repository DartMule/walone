import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walone/core/widgets.dart';
import 'package:walone/features/music/domain/music.dart';
import 'package:walone/features/music/presentation/music_dialogs.dart';

void main() {
  testWidgets(
    'Название редактируется в середине и в начале на macOS',
    verifyTrackEditing,
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );
}

Future<void> verifyTrackEditing(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: WaloneDesign.theme(Brightness.dark),
      builder: (_, child) => WaloneGlassHost(child: child!),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => TrackEditDialog(
                artists: [],
                track: MusicTrack(
                  id: 'test',
                  title: 'Первая песня',
                  filename: 'test.wav',
                  duration: 10,
                ),
              ),
            ),
            child: const Text('Открыть'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Открыть'));
  await tester.pumpAndSettle();
  final field = find.byType(TextField).first;
  await tester.tap(field, kind: PointerDeviceKind.mouse);
  final controller = tester.widget<TextField>(field).controller!;
  final editable = tester
      .state<EditableTextState>(find.byType(EditableText).first)
      .renderEditable;
  await tester.pump(const Duration(milliseconds: 500));
  await tester.tapAt(
    editable.localToGlobal(
      editable.getLocalRectForCaret(const TextPosition(offset: 7)).center,
    ),
    kind: PointerDeviceKind.mouse,
  );
  await tester.pump();
  expect(controller.selection.baseOffset, 7);
  expect(controller.selection.extentOffset, 7);
  Actions.invoke(
    FocusManager.instance.primaryFocus!.context!,
    const DeleteCharacterIntent(forward: false),
  );
  await tester.pump();
  expect(controller.text, 'Перваяпесня');
  expect(controller.selection.baseOffset, 6);
  await tester.pump(const Duration(milliseconds: 500));
  await tester.tapAt(
    editable.localToGlobal(
      editable.getLocalRectForCaret(const TextPosition(offset: 0)).center,
    ),
    kind: PointerDeviceKind.mouse,
  );
  await tester.pump();
  expect(controller.selection.baseOffset, 0);
  expect(controller.selection.extentOffset, 0);
  for (var i = 0; i < 6; i++) {
    Actions.invoke(
      FocusManager.instance.primaryFocus!.context!,
      const ExtendSelectionByCharacterIntent(
        forward: true,
        collapseSelection: false,
      ),
    );
  }
  Actions.invoke(
    FocusManager.instance.primaryFocus!.context!,
    const DeleteCharacterIntent(forward: false),
  );
  await tester.pump();
  expect(controller.text, 'песня');
  expect(controller.selection.baseOffset, 0);
  await tester.pumpWidget(const SizedBox.shrink());
}
