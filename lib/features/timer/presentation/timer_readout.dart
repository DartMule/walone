import 'package:flutter/material.dart';

/// Прокручиваются только изменившиеся цифры; разряды и двоеточия неподвижны.
class TimerReadout extends StatefulWidget {
  const TimerReadout({super.key, required this.value, required this.style});
  final String value;
  final TextStyle style;

  @override
  State<TimerReadout> createState() => _TimerReadoutState();
}

class _TimerReadoutState extends State<TimerReadout>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 360),
    value: 1,
  );
  late String _previous = widget.value;
  double _direction = 1;

  int _seconds(String value) =>
      value.split(':').fold(0, (total, part) => total * 60 + int.parse(part));

  @override
  void didUpdateWidget(covariant TimerReadout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value == widget.value) return;
    _previous = oldWidget.value;
    final difference = _seconds(widget.value) - _seconds(_previous);
    _direction = difference < 0 ? 1 : -1;
    // Сброс, смена этапа и возвращение после сна не прокручивают пропущенные секунды.
    if (!MediaQuery.disableAnimationsOf(context) &&
        difference.abs() == 1 &&
        _previous.length == widget.value.length) {
      _controller.forward(from: 0);
    } else {
      _controller.value = 1;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) _controller.value = 1;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(context).style
        .merge(widget.style)
        .copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
    final scaler = MediaQuery.textScalerOf(context);
    final metrics = TextPainter(
      text: TextSpan(text: '0', style: style),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    )..layout();
    final digitSize = metrics.size;
    metrics.dispose();
    Widget digit(String value) => Center(
      child: Text(value, style: style, textScaler: scaler),
    );
    return Semantics(
      label: widget.value,
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final progress = Curves.easeInOutCubic.transform(_controller.value);
            return Row(
              mainAxisSize: MainAxisSize.min,
              textDirection: TextDirection.ltr,
              children: [
                for (var i = 0; i < widget.value.length; i++)
                  if (widget.value[i] == ':')
                    Text(
                      ':',
                      key: ValueKey(('separator', i)),
                      style: style,
                      textScaler: scaler,
                    )
                  else
                    SizedBox(
                      key: ValueKey(('digit', i)),
                      width: digitSize.width,
                      height: digitSize.height,
                      child: ClipRect(
                        child:
                            progress == 1 ||
                                _previous.length != widget.value.length ||
                                _previous[i] == widget.value[i]
                            ? digit(widget.value[i])
                            : Stack(
                                fit: StackFit.expand,
                                children: [
                                  FractionalTranslation(
                                    translation: Offset(
                                      0,
                                      _direction * progress,
                                    ),
                                    child: digit(_previous[i]),
                                  ),
                                  FractionalTranslation(
                                    translation: Offset(
                                      0,
                                      _direction * (progress - 1),
                                    ),
                                    child: digit(widget.value[i]),
                                  ),
                                ],
                              ),
                      ),
                    ),
              ],
            );
          },
        ),
      ),
    );
  }
}
