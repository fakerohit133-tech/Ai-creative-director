// lib/ui/painters/skeleton_painter.dart
// ─────────────────────────────────────────────────────────────────────────────
// CustomPainter that renders:
//   1. The REFERENCE pose wireframe (thin, static, guide silhouette)
//   2. The LIVE pose wireframe (thicker, coloured by per-joint alignment)
//
// Both are drawn over the live camera preview using normalised [0,1]
// coordinates scaled to the widget bounds at paint time.
//
// Visual language:
//   • Reference pose  → grey-white, low opacity, dotted segments
//   • Live pose       → solid; green when aligned, amber when close, red when off
//   • Joint circles   → 5 dp radius, same colour coding as segments
//   • Overall opacity → lerps from kWireframeBaseOpacity to kWireframeAlignedOpacity
//     as the Procrustes similarity score rises toward 1.0
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/models/pose_model.dart';

/// Pairs of landmark indices that form skeleton segments.
const List<List<int>> kSkeletonConnections = [
  // Head
  [0, 1], [0, 2], [1, 3], [2, 4],
  // Torso
  [5, 6], [5, 11], [6, 12], [11, 12],
  // Left arm
  [5, 7], [7, 9],
  // Right arm
  [6, 8], [8, 10],
  // Left leg
  [11, 13], [13, 15],
  // Right leg
  [12, 14], [14, 16],
];

class SkeletonPainter extends CustomPainter {
  final List<PoseLandmark>? liveLandmarks;
  final List<PoseLandmark>  referenceLandmarks;
  final List<double>        perLandmarkError; // Procrustes per-joint errors
  final double              alignmentScore;   // [0, 1]
  final bool                showReference;

  const SkeletonPainter({
    required this.referenceLandmarks,
    required this.alignmentScore,
    this.liveLandmarks,
    this.perLandmarkError = const [],
    this.showReference = true,
  });

  // ── Paint ──────────────────────────────────────────────────────────────────

  @override
  void paint(Canvas canvas, Size size) {
    if (showReference) {
      _drawReferenceSkeleton(canvas, size);
    }
    if (liveLandmarks != null && liveLandmarks!.isNotEmpty) {
      _drawLiveSkeleton(canvas, size);
    }
  }

  void _drawReferenceSkeleton(Canvas canvas, Size size) {
    final opacity = ui.lerpDouble(
        kWireframeBaseOpacity, kWireframeAlignedOpacity, alignmentScore)!;

    final segPaint = Paint()
      ..color = Colors.white.withOpacity(opacity * 0.55)
      ..strokeWidth = kWireframeStrokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final jointPaint = Paint()
      ..color = Colors.white.withOpacity(opacity * 0.70)
      ..style = PaintingStyle.fill;

    _drawSkeleton(canvas, size, referenceLandmarks, segPaint, jointPaint,
        jointRadius: 4.0, dashLength: 6.0, gapLength: 4.0);
  }

  void _drawLiveSkeleton(Canvas canvas, Size size) {
    final lm = liveLandmarks!;

    for (final conn in kSkeletonConnections) {
      final i = conn[0], j = conn[1];
      if (i >= lm.length || j >= lm.length) continue;

      final color = _segmentColor(i, j);
      final paint = Paint()
        ..color = color.withOpacity(0.85)
        ..strokeWidth = kWireframeStrokeWidth * 1.8
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final p1 = _toOffset(lm[i], size);
      final p2 = _toOffset(lm[j], size);
      canvas.drawLine(p1, p2, paint);
    }

    // Draw joints
    for (int i = 0; i < lm.length; i++) {
      final color = _jointColor(i);
      final paint = Paint()
        ..color = color.withOpacity(0.9)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(_toOffset(lm[i], size), 5.5, paint);

      // Outer ring
      canvas.drawCircle(
        _toOffset(lm[i], size),
        7.5,
        Paint()
          ..color = color.withOpacity(0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  void _drawSkeleton(
    Canvas canvas,
    Size size,
    List<PoseLandmark> landmarks,
    Paint segPaint,
    Paint jointPaint, {
    required double jointRadius,
    double? dashLength,
    double? gapLength,
  }) {
    for (final conn in kSkeletonConnections) {
      final i = conn[0], j = conn[1];
      if (i >= landmarks.length || j >= landmarks.length) continue;
      final p1 = _toOffset(landmarks[i], size);
      final p2 = _toOffset(landmarks[j], size);

      if (dashLength != null && gapLength != null) {
        _drawDashedLine(canvas, p1, p2, segPaint, dashLength, gapLength);
      } else {
        canvas.drawLine(p1, p2, segPaint);
      }
    }

    for (int i = 0; i < landmarks.length; i++) {
      canvas.drawCircle(_toOffset(landmarks[i], size), jointRadius, jointPaint);
    }
  }

  void _drawDashedLine(
      Canvas canvas, Offset p1, Offset p2, Paint paint,
      double dashLen, double gapLen) {
    final dx = p2.dx - p1.dx;
    final dy = p2.dy - p1.dy;
    final dist = (dx * dx + dy * dy) == 0
        ? 1.0
        : (dx * dx + dy * dy) * 0.5; // approximation; replace with sqrt if needed
    final norm = Offset(dx / dist, dy / dist);
    double travelled = 0.0;
    bool drawing = true;

    while (travelled < dist) {
      final remaining = dist - travelled;
      final step = drawing
          ? (remaining < dashLen ? remaining : dashLen)
          : (remaining < gapLen ? remaining : gapLen);

      if (drawing) {
        final s = p1 + norm * travelled;
        final e = p1 + norm * (travelled + step);
        canvas.drawLine(s, e, paint);
      }

      travelled += step;
      drawing = !drawing;
    }
  }

  // ── Colour coding by per-landmark alignment error ──────────────────────────

  Color _jointColor(int index) {
    if (index >= perLandmarkError.length) return Colors.cyanAccent;
    final err = perLandmarkError[index].clamp(0.0, 0.25);
    // 0.0 → green, 0.125 → amber, 0.25+ → red
    if (err < 0.05) return const Color(0xFF4DFFC0); // aligned green
    if (err < 0.15) return const Color(0xFFFFCC44); // amber
    return const Color(0xFFFF4D6A);                 // misaligned red
  }

  Color _segmentColor(int i, int j) {
    if (perLandmarkError.isEmpty) return const Color(0xFF4DFFC0);
    final avgErr = ((i < perLandmarkError.length ? perLandmarkError[i] : 0.1) +
            (j < perLandmarkError.length ? perLandmarkError[j] : 0.1)) /
        2.0;
    return _jointColor(i).withOpacity(0.8); // inherit joint colour
  }

  Offset _toOffset(PoseLandmark lm, Size size) =>
      Offset(lm.x * size.width, lm.y * size.height);

  @override
  bool shouldRepaint(SkeletonPainter old) =>
      old.liveLandmarks != liveLandmarks ||
      old.alignmentScore != alignmentScore;
}
