import 'package:flutter/material.dart';
import 'package:theme/theme.dart';

import '../core/ruler_math.dart';

/// Vertical ruler: centimetres down the left edge, inches down the right.
/// Positions are in millimetres from the top, so the drawing is at true scale
/// when [pxPerMm] is right.
class RulerPainter extends CustomPainter {
  RulerPainter({
    required this.colors,
    required this.labelStyle,
    required this.pxPerMm,
    required this.markerA,
    required this.markerB,
    this.showA = true,
  });

  final UiColors colors;
  final TextStyle labelStyle;
  final double pxPerMm;

  /// Marker positions in millimetres from the top.
  final double markerA;
  final double markerB;

  /// The first marker is hidden-but-fixed at zero while calibrating.
  final bool showA;

  static const double handleRadius = 16;

  @override
  void paint(Canvas canvas, Size size) {
    final tick = Paint()..color = colors.textMuted;
    final totalMm = size.height / pxPerMm;

    // Band between the markers.
    final top = mmToPx(markerA < markerB ? markerA : markerB, pxPerMm);
    final bottom = mmToPx(markerA < markerB ? markerB : markerA, pxPerMm);
    canvas.drawRect(Rect.fromLTRB(0, top, size.width, bottom), Paint()..color = colors.accentSoft.withValues(alpha: 0.5));

    // Centimetres: a tick per millimetre.
    for (var mm = 0; mm <= totalMm; mm++) {
      final y = mmToPx(mm.toDouble(), pxPerMm);
      final len = mm % 10 == 0 ? 30.0 : (mm % 5 == 0 ? 21.0 : 13.0);
      canvas.drawLine(Offset(0, y), Offset(len, y), tick..strokeWidth = mm % 10 == 0 ? 2 : 1);
      if (mm % 10 == 0 && mm > 0) _label(canvas, '${mm ~/ 10}', Offset(36, y), left: true);
    }

    // Inches: a tick per sixteenth.
    final totalSixteenths = (mmToInches(totalMm) * 16).floor();
    for (var i = 0; i <= totalSixteenths; i++) {
      final y = mmToPx(inchesToMm(i / 16), pxPerMm);
      final len = i % 16 == 0 ? 30.0 : (i % 8 == 0 ? 24.0 : (i % 4 == 0 ? 18.0 : (i % 2 == 0 ? 13.0 : 8.0)));
      canvas.drawLine(Offset(size.width, y), Offset(size.width - len, y), tick..strokeWidth = i % 16 == 0 ? 2 : 1);
      if (i % 16 == 0 && i > 0) _label(canvas, '${i ~/ 16}', Offset(size.width - 36, y), left: false);
    }

    _marker(canvas, size, markerB);
    if (showA) _marker(canvas, size, markerA);
  }

  void _marker(Canvas canvas, Size size, double mm) {
    final y = mmToPx(mm, pxPerMm);
    canvas.drawLine(
      Offset(0, y),
      Offset(size.width, y),
      Paint()
        ..strokeWidth = 2
        ..color = colors.accent,
    );
    final center = Offset(size.width / 2, y);
    canvas.drawCircle(center, handleRadius, Paint()..color = colors.accent);
    canvas.drawCircle(center, handleRadius - 6, Paint()..color = colors.onAccent.withValues(alpha: 0.9));
  }

  void _label(Canvas canvas, String text, Offset at, {required bool left}) {
    final tp = TextPainter(text: TextSpan(text: text, style: labelStyle), textDirection: TextDirection.ltr)..layout();
    final dx = left ? at.dx : at.dx - tp.width;
    tp.paint(canvas, Offset(dx, at.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(RulerPainter old) =>
      old.pxPerMm != pxPerMm || old.markerA != markerA || old.markerB != markerB || old.showA != showA || old.colors != colors;
}
