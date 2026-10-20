import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:walone/core/audio.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('Аудиопозиция обновляется без непрерывного рендеринга окна', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('Аудио'))),
    );
    final audio = DesktopAudio();
    final positions = <Duration>[];
    final subscription = audio.positions.listen(positions.add);
    var counting = false;
    var frameRequests = 0;
    binding.addPersistentFrameCallback((_) {
      // fullyLive сам выдаёт vsync; считаем запросы следующего кадра от приложения.
      if (counting) frameRequests += binding.transientCallbackCount;
    });
    try {
      await audio.setVolume(0);
      await audio.load('atmosphere/rain.wav', asset: true, loop: true);
      await audio.play();
      await Future<void>.delayed(const Duration(seconds: 1));
      positions.clear();
      counting = true;
      await Future<void>.delayed(const Duration(seconds: 2));
      counting = false;
      debugPrint(
        'Audio frame requests in 2 seconds: $frameRequests; positions: ${positions.length}',
      );
      expect(positions.length, greaterThanOrEqualTo(3));
      expect(positions.last, greaterThan(positions.first));
      expect(
        frameRequests,
        lessThan(30),
        reason: 'Опрос аудио не должен запрашивать кадр на каждом vsync',
      );
      await audio.pause();
      final seekPosition = audio.positions
          .firstWhere((value) => value.inMilliseconds >= 4900)
          .timeout(const Duration(seconds: 2));
      await audio.seek(const Duration(seconds: 5));
      expect((await seekPosition).inMilliseconds, inInclusiveRange(4900, 5100));
      await audio.play();
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(positions.last.inMilliseconds, greaterThan(5100));
    } finally {
      counting = false;
      await subscription.cancel();
      await audio.dispose();
    }
  });
}
