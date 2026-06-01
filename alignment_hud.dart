// lib/ui/widgets/alignment_hud.dart
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/models/pose_model.dart';
import '../../core/models/scene_classification.dart';

class AlignmentHUD extends StatelessWidget {
  final PoseAlignmentResult alignment;
  final SceneClassificationResult scene;
  final String? poseLabel;
  final bool inFallbackMode;
  final bool subjectDetected;

  const AlignmentHUD({
    super.key,
    required this.alignment,
    required this.scene,
    this.poseLabel,
    this.inFallbackMode = false,
    this.subjectDetected = false,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: 140,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.30),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withOpacity(0.10),
              width: 0.7,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Scene chip
              _SceneChip(scene: scene),
              const SizedBox(height: 8),

              // Pose label
              if (poseLabel != null) ...[
                Text(
                  poseLabel!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.spaceMono(
                    fontSize: 9,
                    color: Colors.white.withOpacity(0.65),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
              ],

              // Alignment bar
              if (!inFallbackMode && subjectDetected) ...[
                _AlignmentBar(score: alignment.similarity),
                const SizedBox(height: 4),
                Text(
                  '${alignment.percentAligned}% ALIGNED',
                  style: GoogleFonts.spaceMono(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: _scoreColor(alignment.similarity),
                    letterSpacing: 1.0,
                  ),
                ),
              ] else ...[
                _FallbackIndicator(inFallback: inFallbackMode),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _scoreColor(double score) {
    if (score >= 0.85) return const Color(0xFF4DFFC0);
    if (score >= 0.55) return const Color(0xFFFFCC44);
    return Colors.white.withOpacity(0.6);
  }
}

class _SceneChip extends StatelessWidget {
  final SceneClassificationResult scene;
  const _SceneChip({required this.scene});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(scene.category.emoji,
            style: const TextStyle(fontSize: 11)),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            scene.category.displayName.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.spaceMono(
              fontSize: 8,
              color: Colors.white.withOpacity(0.8),
              letterSpacing: 0.8,
            ),
          ),
        ),
      ],
    );
  }
}

class _AlignmentBar extends StatelessWidget {
  final double score;
  const _AlignmentBar({required this.score});

  @override
  Widget build(BuildContext context) {
    final color = score >= 0.85
        ? const Color(0xFF4DFFC0)
        : score >= 0.55
            ? const Color(0xFFFFCC44)
            : Colors.white.withOpacity(0.4);

    return SizedBox(
      height: 3,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: Stack(
          children: [
            Container(color: Colors.white.withOpacity(0.12)),
            FractionallySizedBox(
              widthFactor: score.clamp(0.0, 1.0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.6),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FallbackIndicator extends StatelessWidget {
  final bool inFallback;
  const _FallbackIndicator({required this.inFallback});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: inFallback
                ? const Color(0xFFFFCC44)
                : Colors.white.withOpacity(0.3),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          inFallback ? 'COMPOSITION' : 'SEARCHING…',
          style: GoogleFonts.spaceMono(
            fontSize: 8,
            color: inFallback
                ? const Color(0xFFFFCC44)
                : Colors.white.withOpacity(0.5),
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}
