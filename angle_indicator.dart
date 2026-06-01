// lib/ui/widgets/angle_indicator.dart
// ─────────────────────────────────────────────────────────────────────────────
// Floating angle indicator widget shown in the bottom-centre of the viewfinder.
//
// Contains:
//   • [CrosshairPainter] canvas — the animated ring-dot-arc element
//   • "HOLD STEADY" text label — fades in after 5 consecutive aligned frames
//   • Pitch / roll readout in tiny monospaced numbers (visible in debug mode)
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/models/sensor_state.dart';
import '../painters/crosshair_painter.dart';

class AngleIndicator extends StatefulWidget {
  final OrientationValidationResult result;
  final bool holdSteady;

  const AngleIndicator({
    super.key,
    required this.result,
    required this.holdSteady,
  });

  @override
  State<AngleIndicator> createState() => _AngleIndicatorState();
}

class _AngleIndicatorState extends State<AngleIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Crosshair ─────────────────────────────────────────────────────
        AnimatedBuilder(
          animation: _glowController,
          builder: (_, __) {
            return SizedBox(
              width: 80,
              height: 80,
              child: CustomPaint(
                painter: CrosshairPainter(
                  pitchError: widget.result.pitchError,
                  rollError: widget.result.rollError,
                  isAligned: widget.result.isAligned,
                  animValue: _glowController.value,
                ),
              ),
            );
          },
        ),

        const SizedBox(height: 8),

        // ── "HOLD STEADY" label ────────────────────────────────────────────
        AnimatedOpacity(
          opacity: widget.holdSteady ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 400),
          child: Text(
            'HOLD STEADY',
            style: GoogleFonts.spaceMono(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF4DFFC0),
              letterSpacing: 3.0,
            ),
          )
          .animate(target: widget.holdSteady ? 1.0 : 0.0)
          .fadeIn(duration: 400.ms)
          .scale(begin: const Offset(0.9, 0.9), end: const Offset(1.0, 1.0)),
        ),
      ],
    );
  }
}
