// lib/ui/widgets/composition_guide_overlay.dart
// ─────────────────────────────────────────────────────────────────────────────
// Rule-of-thirds grid + golden-spiral indicator displayed when:
//   • No human subject detected for > 3 seconds (kNoSubjectTimeoutMs)
//   • Scene lighting drops below kLowLightLuxThreshold
//
// Rendered as a thin, barely-visible overlay that guides framing without
// obscuring the scene.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

class CompositionGuideOverlay extends StatelessWidget {
  final bool visible;
  final bool isLowLight;

  const CompositionGuideOverlay({
    super.key,
    required this.visible,
    this.isLowLight = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 600),
      opacity: visible ? 1.0 : 0.0,
      child: IgnorePointer(
        child: Stack(
          children: [
            // Rule-of-thirds grid
            CustomPaint(
              painter: _RuleOfThirdsPainter(),
              size: Size.infinite,
            ),

            // Corner markers
            ..._cornerMarkers(),

            // Mode label
            if (visible)
              Positioned(
                top: 24,
                left: 0,
                right: 0,
                child: Center(
                  child: _ModeChip(isLowLight: isLowLight),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _cornerMarkers() {
    const size = 18.0;
    const thickness = 1.5;
    final color = Colors.white.withOpacity(0.35);

    Widget marker(Alignment align, bool flipX, bool flipY) {
      return Align(
        alignment: align,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SizedBox(
            width: size,
            height: size,
            child: CustomPaint(
              painter: _CornerPainter(
                color: color,
                flipX: flipX,
                flipY: flipY,
                thickness: thickness,
              ),
            ),
          ),
        ),
      );
    }

    return [
      marker(Alignment.topLeft,     false, false),
      marker(Alignment.topRight,    true,  false),
      marker(Alignment.bottomLeft,  false, true),
      marker(Alignment.bottomRight, true,  true),
    ];
  }
}

// ── Rule-of-thirds grid painter ───────────────────────────────────────────────

class _RuleOfThirdsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.12)
      ..strokeWidth = 0.5;

    // Two vertical lines
    for (int i = 1; i <= 2; i++) {
      final x = size.width * i / 3;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Two horizontal lines
    for (int i = 1; i <= 2; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // Power points (intersections) — small circles
    final dotPaint = Paint()
      ..color = Colors.white.withOpacity(0.22)
      ..style = PaintingStyle.fill;

    for (int ix = 1; ix <= 2; ix++) {
      for (int iy = 1; iy <= 2; iy++) {
        canvas.drawCircle(
          Offset(size.width * ix / 3, size.height * iy / 3),
          3.0,
          dotPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── Corner bracket painter ────────────────────────────────────────────────────

class _CornerPainter extends CustomPainter {
  final Color  color;
  final bool   flipX;
  final bool   flipY;
  final double thickness;

  const _CornerPainter({
    required this.color,
    required this.flipX,
    required this.flipY,
    required this.thickness,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.square
      ..style = PaintingStyle.stroke;

    final w = size.width;
    final h = size.height;

    canvas.save();
    canvas.translate(flipX ? w : 0, flipY ? h : 0);
    canvas.scale(flipX ? -1 : 1, flipY ? -1 : 1);

    final path = Path()
      ..moveTo(0, h * 0.5)
      ..lineTo(0, 0)
      ..lineTo(w * 0.5, 0);

    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── Mode chip ─────────────────────────────────────────────────────────────────

class _ModeChip extends StatelessWidget {
  final bool isLowLight;
  const _ModeChip({required this.isLowLight});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.40),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isLowLight
              ? const Color(0xFFFFCC44).withOpacity(0.5)
              : Colors.white.withOpacity(0.18),
          width: 0.8,
        ),
      ),
      child: Text(
        isLowLight ? '⚡ LOW LIGHT — COMPOSITION MODE' : '◈ COMPOSITION GUIDE',
        style: GoogleFonts.spaceMono(
          fontSize: 9,
          color: isLowLight
              ? const Color(0xFFFFCC44)
              : Colors.white.withOpacity(0.7),
          letterSpacing: 1.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    )
    .animate(onPlay: (c) => c.repeat(reverse: true))
    .fadeIn(duration: 800.ms)
    .then()
    .fadeOut(duration: 800.ms);
  }
}
