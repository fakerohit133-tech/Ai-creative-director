// lib/ui/painters/crosshair_painter.dart
// ─────────────────────────────────────────────────────────────────────────────
// Paints the minimal crosshair / angle indicator:
//
//   • Outer ring     : thin static circle (always visible)
//   • Inner dot      : moves inside the ring proportional to pitch/roll error
//   • Direction arcs : short arcs at N/S/E/W indicating which way to tilt
//   • Colour state   :
//       – Misaligned  → glacier white  (#E8EAED, 60% opacity)
//       – Approaching → amber          (#FFCC44, 80% opacity)
//       – Aligned     → validation green (#4DFFC0, 100% opacity) + glow
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/models/sensor_state.dart';

class CrosshairPainter extends CustomPainter {
  final double pitchError;   // degrees, signed
  final double rollError;    // degrees, signed
  final bool   isAligned;
  final double animValue;    // [0,1] from AnimationController for glow pulse

  static const double _maxError = 15.0; // degrees at which dot hits ring edge

  const CrosshairPainter({
    required this.pitchError,
    required this.rollError,
    required this.isAligned,
    required this.animValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final ringR  = kCrosshairRingRadius;
    final dotR   = kCrosshairDotRadius;

    final color  = _stateColor();
    final opacity = isAligned ? 1.0 : (pitchError.abs() + rollError.abs() < 10 ? 0.8 : 0.6);

    // ── Outer ring ──────────────────────────────────────────────────────────
    final ringPaint = Paint()
      ..color = color.withOpacity(opacity * 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawCircle(centre, ringR, ringPaint);

    // ── Alignment glow when locked ──────────────────────────────────────────
    if (isAligned) {
      final glowOpacity = 0.15 + 0.15 * math.sin(animValue * math.pi * 2);
      canvas.drawCircle(
        centre, ringR + 6,
        Paint()
          ..color = color.withOpacity(glowOpacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4,
      );
      canvas.drawCircle(
        centre, ringR + 12,
        Paint()
          ..color = color.withOpacity(glowOpacity * 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    // ── Inner dot (moves with error) ────────────────────────────────────────
    final dx = (rollError  / _maxError).clamp(-1.0, 1.0) * (ringR - dotR - 2);
    final dy = (pitchError / _maxError).clamp(-1.0, 1.0) * (ringR - dotR - 2);
    final dotCenter = Offset(centre.dx + dx, centre.dy + dy);

    canvas.drawCircle(
        dotCenter, dotR,
        Paint()..color = color.withOpacity(opacity));

    // ── Tick marks at cardinal points ───────────────────────────────────────
    _drawTicks(canvas, centre, ringR, color, opacity);

    // ── Directional arcs ────────────────────────────────────────────────────
    _drawDirectionalArcs(canvas, centre, ringR, color, opacity);
  }

  void _drawTicks(Canvas canvas, Offset centre, double r, Color color, double opacity) {
    const tickLen = 5.0;
    final paint = Paint()
      ..color = color.withOpacity(opacity * 0.5)
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 4; i++) {
      final angle = i * math.pi / 2;
      final cos = math.cos(angle);
      final sin = math.sin(angle);
      final inner = Offset(centre.dx + cos * (r - tickLen), centre.dy + sin * (r - tickLen));
      final outer = Offset(centre.dx + cos * (r + tickLen), centre.dy + sin * (r + tickLen));
      canvas.drawLine(inner, outer, paint);
    }
  }

  void _drawDirectionalArcs(
      Canvas canvas, Offset centre, double r, Color color, double opacity) {
    // Only draw arc in the direction the user needs to tilt.
    const arcSpan = math.pi / 5; // 36° arc

    if (pitchError.abs() > kAngleToleranceDeg) {
      // Pitch error → vertical arc
      final angle = pitchError > 0
          ? math.pi / 2  // too low → up arrow at top
          : -math.pi / 2; // too high → down arrow at bottom

      final rect = Rect.fromCircle(center: centre, radius: r + 10);
      canvas.drawArc(
        rect,
        angle - arcSpan / 2,
        arcSpan,
        false,
        Paint()
          ..color = color.withOpacity(opacity * 0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round,
      );

      // Arrowhead
      _drawArrowhead(canvas, centre, r + 10, angle, color, opacity);
    }

    if (rollError.abs() > kAngleToleranceDeg) {
      // Roll error → horizontal arc
      final angle = rollError > 0
          ? 0.0        // rolled right → arc on right side
          : math.pi;   // rolled left → arc on left

      final rect = Rect.fromCircle(center: centre, radius: r + 10);
      canvas.drawArc(
        rect,
        angle - arcSpan / 2,
        arcSpan,
        false,
        Paint()
          ..color = color.withOpacity(opacity * 0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round,
      );

      _drawArrowhead(canvas, centre, r + 10, angle, color, opacity);
    }
  }

  void _drawArrowhead(Canvas canvas, Offset centre, double r,
      double angle, Color color, double opacity) {
    const size = 5.0;
    final tip = Offset(
        centre.dx + math.cos(angle) * r,
        centre.dy + math.sin(angle) * r);
    final left = Offset(
        tip.dx + math.cos(angle + math.pi * 0.8) * size,
        tip.dy + math.sin(angle + math.pi * 0.8) * size);
    final right = Offset(
        tip.dx + math.cos(angle - math.pi * 0.8) * size,
        tip.dy + math.sin(angle - math.pi * 0.8) * size);

    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(left.dx, left.dy)
      ..lineTo(right.dx, right.dy)
      ..close();

    canvas.drawPath(
        path,
        Paint()
          ..color = color.withOpacity(opacity)
          ..style = PaintingStyle.fill);
  }

  Color _stateColor() {
    if (isAligned) return const Color(0xFF4DFFC0);  // validation green
    final totalError = pitchError.abs() + rollError.abs();
    if (totalError < 8.0) return const Color(0xFFFFCC44); // approaching amber
    return const Color(0xFFE8EAED);                       // glacier white
  }

  @override
  bool shouldRepaint(CrosshairPainter old) =>
      old.pitchError != pitchError ||
      old.rollError  != rollError  ||
      old.isAligned  != isAligned  ||
      old.animValue  != animValue;
}
