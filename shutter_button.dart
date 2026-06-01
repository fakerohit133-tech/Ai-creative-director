// lib/ui/widgets/shutter_button.dart
// ─────────────────────────────────────────────────────────────────────────────
// The shutter button:
//   • Always tappable (compliance not required for capture per §3)
//   • Animates with a "ring expand + fade" effect on press
//   • Outer ring turns validation green when pose is aligned
//   • Shows a processing spinner while post-processing runs
//   • Haptic feedback on press via HapticService
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ShutterButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final bool isCapturing;
  final bool isAligned;

  const ShutterButton({
    super.key,
    required this.onPressed,
    this.isCapturing = false,
    this.isAligned = false,
  });

  @override
  State<ShutterButton> createState() => _ShutterButtonState();
}

class _ShutterButtonState extends State<ShutterButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressController;
  late final Animation<double>   _scaleAnim;
  late final Animation<double>   _ringAnim;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeIn),
    );
    _ringAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  void _handleTapDown(_) {
    _pressController.forward();
  }

  void _handleTapUp(_) {
    _pressController.reverse();
    widget.onPressed?.call();
  }

  void _handleTapCancel() {
    _pressController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final ringColor = widget.isAligned
        ? const Color(0xFF4DFFC0)
        : Colors.white;

    return GestureDetector(
      onTapDown: widget.isCapturing ? null : _handleTapDown,
      onTapUp: widget.isCapturing ? null : _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: AnimatedBuilder(
        animation: _pressController,
        builder: (_, __) {
          return Transform.scale(
            scale: _scaleAnim.value,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Expanding ring on press
                if (_ringAnim.value > 0)
                  Opacity(
                    opacity: 1.0 - _ringAnim.value,
                    child: Container(
                      width: 80 + _ringAnim.value * 20,
                      height: 80 + _ringAnim.value * 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: ringColor,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),

                // Outer decorative ring
                Container(
                  width: 78,
                  height: 78,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: ringColor.withOpacity(
                          widget.isAligned ? 0.85 : 0.55),
                      width: 2.0,
                    ),
                    boxShadow: widget.isAligned
                        ? [
                            BoxShadow(
                              color: ringColor.withOpacity(0.3),
                              blurRadius: 14,
                              spreadRadius: 2,
                            )
                          ]
                        : null,
                  ),
                ),

                // Inner button disc
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.isCapturing
                        ? Colors.white.withOpacity(0.4)
                        : Colors.white,
                  ),
                  child: widget.isCapturing
                      ? const _CapturingSpinner()
                      : null,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CapturingSpinner extends StatefulWidget {
  const _CapturingSpinner();

  @override
  State<_CapturingSpinner> createState() => _CapturingSpinnerState();
}

class _CapturingSpinnerState extends State<_CapturingSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _spin,
      child: const Padding(
        padding: EdgeInsets.all(18),
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Colors.black45,
        ),
      ),
    );
  }
}
