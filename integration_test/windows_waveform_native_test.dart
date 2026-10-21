import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:walone/features/music/data/music_waveform.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Windows декодирует амплитуду без FFmpeg', (tester) async {
    final directory = await Directory.systemTemp.createTemp('walone-waveform-');
    final waveform = MusicWaveform();
    try {
      // 20 мс тишины, 20 мс стерео в противофазе и неполный блок тишины.
      const frames = 321;
      final bytes = ByteData(44 + frames * 4);
      void text(int offset, String value) {
        for (var i = 0; i < value.length; i++) {
          bytes.setUint8(offset + i, value.codeUnitAt(i));
        }
      }

      text(0, 'RIFF');
      bytes.setUint32(4, bytes.lengthInBytes - 8, Endian.little);
      text(8, 'WAVEfmt ');
      bytes.setUint32(16, 16, Endian.little);
      bytes.setUint16(20, 1, Endian.little);
      bytes.setUint16(22, 2, Endian.little);
      bytes.setUint32(24, 8000, Endian.little);
      bytes.setUint32(28, 32000, Endian.little);
      bytes.setUint16(32, 4, Endian.little);
      bytes.setUint16(34, 16, Endian.little);
      text(36, 'data');
      bytes.setUint32(40, frames * 4, Endian.little);
      for (var frame = 160; frame < 320; frame++) {
        bytes.setInt16(44 + frame * 4, 16384, Endian.little);
        bytes.setInt16(46 + frame * 4, -16384, Endian.little);
      }
      final file = File('${directory.path}/Музыка.wav');
      await file.writeAsBytes(bytes.buffer.asUint8List());
      await waveform.load(file.path).timeout(const Duration(seconds: 15));
      expect(waveform.levels, hasLength(3));
      expect(waveform.levels[0], closeTo(0, 0.001));
      expect(waveform.levels[1], closeTo(0.5, 0.001));
      expect(waveform.levels[2], closeTo(0, 0.001));
      expect(waveform.bars(0.02, 0), everyElement(0));
      waveform.cancel();
      expect(waveform.levels, isEmpty);
    } finally {
      waveform.cancel();
      await directory.delete(recursive: true);
    }
  }, skip: !Platform.isWindows);
}
