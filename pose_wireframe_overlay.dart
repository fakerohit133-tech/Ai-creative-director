// lib/ui/widgets/pose_wireframe_overlay.dart
// ─────────────────────────────────────────────────────────────────────────────
// Full-viewport overlay widget that renders the skeleton wireframe on top of
// the live camera preview. Uses an IgnorePointer so touch events pass through
// to underlying camera controls.
//
// Animates the overall opacity and the reference skeleton scale with
// flutter_animate so the guide "breathes" gently when the subject is aligned.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/constants/app_constants.dart';
import '../../core/models/pose_model.dart';
import '../painters/skeleton_painter.dart';

class PoseWireframeOverlay extends StatelessWidget {
  final List<PoseLandmark>  referenceLandmarks;
  final List<PoseLandmark>? liveLandmarks;
  final List<double>        perLandmarkError;
  final double              alignmentScore; // [0, 1]
  final bool                visible;

  const PoseWireframeOverlay({
    super.key,
    required this.referenceLandmarks,
    required this.alignmentScore,
    this.liveLandmarks,
    this.perLandmarkError = const [],
    this.visible = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible || referenceLandmarks.isEmpty) {
      return const SizedBox.shrink();
    }

    return IgnorePointer(
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: visible ? 1.0 : 0.0,
        child: CustomPaint(
          painter: SkeletonPainter(
            referenceLandmarks: referenceLandmarks,
            liveLandmarks: liveLandmarks,
            perLandmarkError: perLandmarkError,
            alignmentScore: alignmentScore,
            showReference: true,
          ),
          child: const SizedBox.expand(),
        ),
      )
      .animate(
        onPlay: (c) => c.repeat(reverse: true),
      )
      .custom(
        duration: const Duration(milliseconds: 1800),
        curve: Curves.easeInOut,
        builder: (context, value, child) {
          // Subtle opacity breathe when aligned
          final extraOpacity = alignmentScore > kPoseAlignmentThreshold
              ? 0.92 + 0.08 * value
              : 1.0;
          return Opacity(opacity: extraOpacity, child: child);
        },
      ),
    );
  }
}
