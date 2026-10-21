import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walone/core/widgets.dart';
import 'package:walone/features/music/data/music_repository.dart';
import 'package:walone/features/music/domain/music.dart';
import 'package:walone/features/music/presentation/music_cubit.dart';
import 'package:walone/features/music/presentation/music_page.dart';

import 'media_fakes.dart';

class _Audio extends FakeAudio {
  @override
  Future<Duration> load(
    String path, {
    bool asset = false,
    bool loop = false,
  }) async => const Duration(seconds: 100);
}

class _Repository extends MusicRepository {
  _Repository(_Audio audio)
    : super(Directory.systemTemp, audioFactory: () => audio) {
    library = MusicLibrary(
      tracks: [
        MusicTrack(
          id: 'test',
          title: 'Test',
          filename: 'test.wav',
          duration: 100,
        ),
      ],
      playlists: [
        MusicPlaylist(id: 'list', name: 'List', trackIDs: ['test']),
      ],
      selectedID: 'list',
    );
  }

  @override
  Future<void> commit(MusicLibrary next) async => library = next;
}

void main() {
  for (final compact in [true, false]) {
    testWidgets(
      'Позиция обновляется без пересборки кнопок (compact=$compact)',
      (tester) async {
        final audio = _Audio();
        final music = MusicCubit(
          _Repository(audio),
          waveformFactory: FakeWaveform.new,
        );
        try {
          await tester.pumpWidget(
            BlocProvider.value(
              value: music,
              child: MaterialApp(
                home: Scaffold(body: MusicPlayerBar(compact: compact)),
              ),
            ),
          );
          await music.play(trackID: 'test', playlistID: 'list');
          await tester.pumpAndSettle();
          var buttons = 0;
          debugOnRebuildDirtyWidget = (element, _) {
            if (element.widget is IconButton) buttons++;
          };
          for (var i = 1; i <= 5; i++) {
            audio.position.add(Duration(seconds: i));
            await tester.pump(const Duration(milliseconds: 100));
            final slider = tester
                .widgetList<GainSlider>(find.byType(GainSlider))
                .singleWhere((widget) => widget.label == 'Позиция');
            expect(slider.value, i.toDouble());
          }
          expect(find.text('0:05'), findsOneWidget);
          expect(buttons, 0);
          debugOnRebuildDirtyWidget = null;
          await music.pause();
          await tester.pumpAndSettle();
          expect(find.byTooltip('Воспроизвести музыку'), findsOneWidget);
          expect(tester.takeException(), isNull);
        } finally {
          debugOnRebuildDirtyWidget = null;
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.runAsync(music.close);
        }
      },
    );
  }
}
