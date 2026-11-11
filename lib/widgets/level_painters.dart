import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:theme/theme.dart';

/// Degrees from the centre to the edge of the bubble area.
const double bubbleRangeDegrees = 6;

/// Bullseye vial for a phone lying flat. The bubble moves towards the higher side.
class BubblePainter extends CustomPainter {
  BubblePainter({required this.colors, required this.x, required this.y, required this.isLevel});

  final UiColors colors;

  /// Tilt in degrees: positive x = right edge higher, positive y = top higher.
  final double x;
  final double y;
  final bool isLevel;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = math.min(size.width, size.height) / 2 - 4;

    canvas.drawCircle(c, r, Paint()..color = colors.surfaceMuted);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = colors.borderStrong;
    canvas.drawCircle(c, r, ring);
    canvas.drawCircle(c, r * 0.5, ring..color = colors.border);
    final target = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = isLevel ? colors.success : colors.textSubtle;
    final bubbleR = r * 0.14;
    canvas.drawCircle(c, bubbleR + 4, target);

    final cross = Paint()
      ..strokeWidth = 1.5
      ..color = colors.border;
    canvas.drawLine(Offset(c.dx - r, c.dy), Offset(c.dx - bubbleR - 10, c.dy), cross);
    canvas.drawLine(Offset(c.dx + bubbleR + 10, c.dy), Offset(c.dx + r, c.dy), cross);
    canvas.drawLine(Offset(c.dx, c.dy - r), Offset(c.dx, c.dy - bubbleR - 10), cross);
    canvas.drawLine(Offset(c.dx, c.dy + bubbleR + 10), Offset(c.dx, c.dy + r), cross);

    // Screen y grows downwards, tilt y grows upwards.
    var offset = Offset(x / bubbleRangeDegrees, -y / bubbleRangeDegrees) * (r - bubbleR);
    final limit = r - bubbleR - 2;
    if (offset.distance > limit) offset = offset / offset.distance * limit;
    final color = isLevel ? colors.success : colors.accent;
    canvas.drawCircle(c + offset, bubbleR, Paint()..color = color.withValues(alpha: 0.85));
    canvas.drawCircle(
      c + offset - Offset(bubbleR * 0.3, bubbleR * 0.3),
      bubbleR * 0.28,
      Paint()..color = colors.onAccent.withValues(alpha: 0.55),
    );
  }

  @override
  bool shouldRepaint(BubblePainter old) =>
      old.x != x || old.y != y || old.isLevel != isLevel || old.colors != colors;
}

/// One-axis tube vial for a phone standing on an edge.
class TubePainter extends CustomPainter {
  TubePainter({required this.colors, required this.angle, required this.isLevel});

  final UiColors colors;

  /// Positive = right-hand end higher.
  final double angle;
  final bool isLevel;

  @override
  void paint(Canvas canvas, Size size) {
    final h = math.min(size.height, 96.0);
    final tube = RRect.fromRectAndRadius(
      Rect.fromCenter(center: size.center(Offset.zero), width: size.width - 8, height: h),
      Radius.circular(h / 2),
    );
    canvas.drawRRect(tube, Paint()..color = colors.surfaceMuted);
    canvas.drawRRect(
      tube,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = colors.borderStrong,
    );

    final c = tube.center;
    final bubbleR = h * 0.34;
    final travel = tube.width / 2 - h / 2 - bubbleR * 0.2;
    final mark = Paint()
      ..strokeWidth = 3
      ..color = isLevel ? colors.success : colors.textSubtle;
    for (final dx in [-(bubbleR + 6), bubbleR + 6]) {
      canvas.drawLine(Offset(c.dx + dx, c.dy - h / 2 + 8), Offset(c.dx + dx, c.dy + h / 2 - 8), mark);
    }

    final dx = (angle / bubbleRangeDegrees).clamp(-1.0, 1.0) * travel;
    final color = isLevel ? colors.success : colors.accent;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(c.dx + dx, c.dy), width: bubbleR * 2.6, height: bubbleR * 2),
      Paint()..color = color.withValues(alpha: 0.85),
    );
  }

  @override
  bool shouldRepaint(TubePainter old) => old.angle != angle || old.isLevel != isLevel || old.colors != colors;
}
