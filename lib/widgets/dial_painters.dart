import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:theme/theme.dart';

void _paintLabel(Canvas canvas, String text, Offset center, TextStyle style) {
  final tp = TextPainter(text: TextSpan(text: text, style: style), textDirection: TextDirection.ltr)..layout();
  tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
}

/// A dial with ticks every 5 degrees and labels every 30.
///
/// 0 is at the top and angles grow clockwise. The needle sits at [angle].
class ProtractorPainter extends CustomPainter {
  ProtractorPainter({
    required this.colors,
    required this.labelStyle,
    required this.angle,
    required this.active,
  });

  final UiColors colors;
  final TextStyle labelStyle;

  /// Needle angle in degrees clockwise from the top, as shown on the dial.
  final double angle;

  /// False dims the needle (no valid reading).
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = math.min(size.width, size.height) / 2 - 8;
    canvas.drawCircle(c, r, Paint()..color = colors.surfaceMuted);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = colors.borderStrong,
    );

    Offset at(double deg, double radius) {
      final rad = (deg - 90) * math.pi / 180;
      return c + Offset(math.cos(rad), math.sin(rad)) * radius;
    }

    for (var d = 0; d < 360; d += 5) {
      final major = d % 30 == 0;
      final len = major ? 16.0 : (d % 10 == 0 ? 10.0 : 6.0);
      canvas.drawLine(
        at(d.toDouble(), r),
        at(d.toDouble(), r - len),
        Paint()
          ..strokeWidth = major ? 2.5 : 1.5
          ..color = major ? colors.textMuted : colors.textSubtle,
      );
      if (major) _paintLabel(canvas, '$d', at(d.toDouble(), r - 30), labelStyle);
    }

    // Arc from the top to the needle.
    final sweep = angle * math.pi / 180;
    final arcRect = Rect.fromCircle(center: c, radius: r * 0.45);
    canvas.drawArc(
      arcRect,
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round
        ..color = colors.accentSoft.withValues(alpha: active ? 1 : 0.4),
    );

    final needle = active ? colors.accent : colors.textDisabled;
    canvas.drawLine(c, at(angle, r - 4), Paint()
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..color = needle);
    canvas.drawCircle(c, 9, Paint()..color = needle);
    canvas.drawCircle(c, 3.5, Paint()..color = colors.surfaceMuted);
  }

  @override
  bool shouldRepaint(ProtractorPainter old) =>
      old.angle != angle || old.active != active || old.colors != colors;
}

/// A compass rose that rotates so the current heading is at the top.
class CompassPainter extends CustomPainter {
  CompassPainter({required this.colors, required this.labelStyle, required this.heading, required this.active});

  final UiColors colors;
  final TextStyle labelStyle;
  final double heading;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = math.min(size.width, size.height) / 2 - 8;
    canvas.drawCircle(c, r, Paint()..color = colors.surfaceMuted);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = colors.borderStrong,
    );

    Offset at(double deg, double radius) {
      final rad = (deg - heading - 90) * math.pi / 180;
      return c + Offset(math.cos(rad), math.sin(rad)) * radius;
    }

    for (var d = 0; d < 360; d += 5) {
      final major = d % 90 == 0;
      final len = major ? 18.0 : (d % 30 == 0 ? 12.0 : 6.0);
      canvas.drawLine(
        at(d.toDouble(), r),
        at(d.toDouble(), r - len),
        Paint()
          ..strokeWidth = major ? 3 : 1.5
          ..color = d == 0 ? colors.danger : colors.textSubtle,
      );
    }
    const points = {0: 'N', 90: 'E', 180: 'S', 270: 'W'};
    points.forEach((deg, name) {
      _paintLabel(
        canvas,
        name,
        at(deg.toDouble(), r - 40),
        labelStyle.copyWith(color: deg == 0 ? colors.danger : colors.text, fontWeight: FontWeight.w700),
      );
    });

    // Fixed pointer at the top: the direction the phone is facing.
    final tone = active ? colors.accent : colors.textDisabled;
    final tip = Offset(c.dx, c.dy - r + 4);
    canvas.drawPath(
      Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(tip.dx - 10, tip.dy + 22)
        ..lineTo(tip.dx + 10, tip.dy + 22)
        ..close(),
      Paint()..color = tone,
    );
    canvas.drawCircle(c, 6, Paint()..color = tone);
  }

  @override
  bool shouldRepaint(CompassPainter old) => old.heading != heading || old.active != active || old.colors != colors;
}
