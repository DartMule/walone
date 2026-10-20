import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walone/core/sidebar_icon.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Детали каждой иконки движутся и возвращаются в исходную позу',
    () async {
      Future<List<int>> pixels(int destination, double progress) async {
        final recorder = ui.PictureRecorder();
        SidebarIconPainter(
          destination: destination,
          progress: progress,
          color: Colors.black,
        ).paint(Canvas(recorder), const Size.square(96));
        final picture = recorder.endRecording();
        final image = await picture.toImage(96, 96);
        final bytes = await image.toByteData();
        final result = bytes!.buffer.asUint8List().toList();
        image.dispose();
        picture.dispose();
        return result;
      }

      for (var destination = 0; destination < 6; destination++) {
        final idle = await pixels(destination, 0);
        expect(await pixels(destination, 0.2), isNot(orderedEquals(idle)));
        expect(await pixels(destination, 0.6), isNot(orderedEquals(idle)));
        expect(await pixels(destination, 1), orderedEquals(idle));
      }
    },
  );
}
