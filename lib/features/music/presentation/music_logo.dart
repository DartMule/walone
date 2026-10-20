import 'package:flutter/material.dart';

import 'music_cubit.dart';

class MusicLogo extends StatelessWidget {
  const MusicLogo({super.key, required this.music});
  final MusicCubit music;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    if (MediaQuery.disableAnimationsOf(context)) {
      return Icon(Icons.graphic_eq_rounded, color: color, size: 27);
    }
    return RepaintBoundary(
      child: ValueListenableBuilder<List<double>?>(
        valueListenable: music.visualization,
        builder: (context, bars, _) {
          if (bars == null) {
            return Icon(Icons.graphic_eq_rounded, color: color, size: 27);
          }
          return ExcludeSemantics(
            child: SizedBox(
              width: 27,
              height: 27,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (final level in bars)
                    Container(
                      width: 3,
                      height: 4 + 23 * level,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
