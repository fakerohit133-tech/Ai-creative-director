// lib/ui/widgets/scene_mode_toggle.dart
// ─────────────────────────────────────────────────────────────────────────────
// Pill-shaped toggle between "Human Portrait" and "Environment / Wildlife" mode.
// Minimal, translucent, non-intrusive per the design spec.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/models/sensor_state.dart';

class SceneModeToggle extends StatelessWidget {
  final ShootingMode current;
  final ValueChanged<ShootingMode> onChanged;

  const SceneModeToggle({
    super.key,
    required this.current,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: _blur,
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.28),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withOpacity(0.12),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Pill(
                label: '◎ PORTRAIT',
                selected: current == ShootingMode.humanPortrait,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onChanged(ShootingMode.humanPortrait);
                },
              ),
              _Pill(
                label: '⬡ ENVIRON',
                selected: current == ShootingMode.environmentWildlife,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onChanged(ShootingMode.environmentWildlife);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  static final _blur = ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10);
}

// ignore: avoid_classes_with_only_static_members
import 'dart:ui' as ui;

class _Pill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Pill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? Colors.white.withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Text(
          label,
          style: GoogleFonts.spaceMono(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: selected
                ? Colors.white
                : Colors.white.withOpacity(0.45),
            letterSpacing: 1.4,
          ),
        ),
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// lib/ui/widgets/alignment_hud.dart
// ─────────────────────────────────────────────────────────────────────────────
// Displays the real-time pose alignment percentage bar and scene category chip.
// Lives in the top-right corner of the viewfinder.
// ─────────────────────────────────────────────────────────────────────────────
