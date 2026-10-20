import 'package:flutter/material.dart';

Color pomodoroColor(ColorScheme scheme, {required bool resting}) => resting
    ? scheme.brightness == Brightness.dark
          ? const Color(0xFF66BB6A)
          : const Color(0xFF2E7D32)
    : scheme.primary;

class TimerColorTransition extends StatelessWidget {
  const TimerColorTransition({
    super.key,
    required this.color,
    required this.builder,
  });
  final Color color;
  final Widget Function(BuildContext context, Color color) builder;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return builder(context, color);
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(begin: color, end: color),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOutCubic,
      builder: (context, value, _) => builder(context, value!),
    );
  }
}
