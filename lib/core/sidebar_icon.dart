import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Контуры остаются неподвижными, а детали оживают при выборе раздела.
class SidebarIconPainter extends CustomPainter {
  const SidebarIconPainter({
    required this.destination,
    required this.progress,
    required this.color,
  });

  final int destination;
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()..color = color;
    final t = progress == 1 ? 0.0 : progress;
    final envelope = math.sin(math.pi * t);

    switch (destination) {
      case 0:
        // Три струи с разной фазой: одна удлиняется, другая укорачивается.
        for (var i = 0; i < 3; i++) {
          final (y, length, radius, direction) = switch (i) {
            0 => (8.0, 10.0, 2.3, -1.0),
            1 => (12.0, 18.0, 2.5, -1.0),
            _ => (16.0, 12.0, 2.3, 1.0),
          };
          final gust = math.sin(t * math.pi * 4 + i * 2.1) * envelope;
          final end = length + gust * 1.5;
          canvas.drawPath(
            Path()
              ..moveTo(3, y)
              ..lineTo(end, y)
              ..cubicTo(
                end + radius * 1.33,
                y,
                end + radius * 1.33,
                y + direction * radius * 2,
                end,
                y + direction * radius * 2,
              )
              ..cubicTo(
                end - radius * 0.55,
                y + direction * radius * 2,
                end - radius,
                y + direction * radius * 1.55,
                end - radius,
                y + direction * radius,
              ),
            stroke,
          );
        }
      case 1:
        // Нотные головки пружинят по очереди, перекладина изгибается с ними.
        final left = math.sin(t * math.pi * 4) * envelope * 2;
        final right = math.sin(t * math.pi * 4 + 1.8) * envelope * 2;
        canvas.drawPath(
          Path()
            ..moveTo(8, 17 + left)
            ..lineTo(8, 6 + left)
            ..lineTo(19, 3 + right)
            ..lineTo(19, 14 + right)
            ..moveTo(8, 9 + left)
            ..lineTo(19, 6 + right),
          stroke,
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(5.5, 18 + left),
            width: 5,
            height: 3.6,
          ),
          fill,
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(16.5, 15 + right),
            width: 5,
            height: 3.6,
          ),
          fill,
        );
      case 2:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(2, 5, 20, 14),
            const Radius.circular(2.5),
          ),
          stroke,
        );
        for (var row = 0; row < 2; row++) {
          for (var column = 0; column < 5; column++) {
            final phase = t * math.pi * 4 - (column + row * 2) * 0.8;
            final press = math.max(0.0, math.sin(phase)) * envelope;
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromLTWH(
                  4.5 + column * 3.1,
                  8 + row * 3.5 + press,
                  1.7,
                  1.7 - press * 0.6,
                ),
                const Radius.circular(0.4),
              ),
              fill
                ..color = color.withValues(alpha: color.a * (1 - press * 0.6)),
            );
          }
        }
        canvas.drawLine(const Offset(8, 16), const Offset(16, 16), stroke);
      case 3:
        canvas.save();
        canvas.translate(12, 12);
        canvas.rotate(Curves.easeInOutCubic.transform(t) * math.pi / 2);
        final gear = Path();
        for (var i = 0; i < 48; i++) {
          final radius = switch (i % 6) {
            1 || 2 || 3 || 4 => 10.0,
            _ => 7.6,
          };
          final angle = i * math.pi / 24;
          final point = Offset(math.cos(angle), math.sin(angle)) * radius;
          if (i == 0) {
            gear.moveTo(point.dx, point.dy);
          } else {
            gear.lineTo(point.dx, point.dy);
          }
        }
        canvas.drawPath(gear..close(), stroke);
        canvas.drawCircle(Offset.zero, 3.3, stroke);
        canvas.restore();
      case 4:
        canvas.drawCircle(const Offset(12, 13), 8.5, stroke);
        canvas.drawLine(const Offset(10, 2), const Offset(14, 2), stroke);
        canvas.drawLine(const Offset(12, 2), const Offset(12, 4.5), stroke);
        canvas.drawLine(const Offset(19, 5), const Offset(20.5, 3.5), stroke);
        for (var i = 0; i < 4; i++) {
          final angle = i * math.pi / 2;
          final direction = Offset(math.sin(angle), -math.cos(angle));
          canvas.drawLine(
            const Offset(12, 13) + direction * 6.3,
            const Offset(12, 13) + direction * 7,
            stroke,
          );
        }
        final angle = Curves.easeInOutCubic.transform(t) * math.pi * 2;
        canvas.drawLine(
          const Offset(12, 13),
          Offset(12 + math.sin(angle) * 5.5, 13 - math.cos(angle) * 5.5),
          stroke,
        );
        canvas.drawCircle(const Offset(12, 13), 1.1, fill);
      case 5:
        for (var i = 0; i < 3; i++) {
          final base = [8.0, 15.0, 11.0][i];
          final height =
              base + math.sin(t * math.pi * 4 + i * 2.2) * envelope * 5;
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(3 + i * 7, 21 - height, 4, height),
              const Radius.circular(1),
            ),
            fill,
          );
        }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(SidebarIconPainter oldDelegate) =>
      destination != oldDelegate.destination ||
      progress != oldDelegate.progress ||
      color != oldDelegate.color;
}
