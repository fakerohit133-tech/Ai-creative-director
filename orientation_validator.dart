// lib/modules/sensor/orientation_validator.dart
// ─────────────────────────────────────────────────────────────────────────────
// Implements the Angle Evaluation Logic specified in §3:
//
//   IF |currentPitch − targetPitch| ≤ 1.5° AND |currentRoll − targetRoll| ≤ 1.5°
//     → ALIGNED  (trigger haptic + green crosshair + "HOLD STEADY" prompt)
//
//   IF currentPitch > targetPitch + 1.5°  → show downward arrow
//   IF currentPitch < targetPitch − 1.5°  → show upward arrow
//
// The validator also drives haptic feedback via [HapticService] and manages
// the "hold steady" countdown before auto-capture is offered.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import '../../core/constants/app_constants.dart';
import '../../core/models/pose_model.dart';
import '../../core/models/sensor_state.dart';
import '../../services/haptic_service.dart';

class OrientationValidator {
  final HapticService _haptic;

  // Prevent haptic spam: enforce a minimum gap between alignment haptics.
  int _lastHapticMs = 0;
  static const int _hapticCooldownMs = 800;

  // Consecutive aligned frames before "HOLD STEADY" is displayed.
  int _alignedFrameCount = 0;
  static const int _holdSteadyThreshold = 5;

  bool _holdSteadyActive = false;
  bool get holdSteadyActive => _holdSteadyActive;

  OrientationValidator({required HapticService hapticService})
      : _haptic = hapticService;

  // ── Validation ─────────────────────────────────────────────────────────────

  /// Evaluate [current] against [targetPitch] / [targetRoll] and
  /// return an [OrientationValidationResult].  Side-effects:
  ///   • Triggers haptic if newly aligned.
  ///   • Sets [holdSteadyActive] after [_holdSteadyThreshold] aligned frames.
  OrientationValidationResult validate({
    required DeviceOrientation current,
    required double targetPitch,
    required double targetRoll,
  }) {
    final result = OrientationValidationResult.compute(
      current: current,
      targetPitch: targetPitch,
      targetRoll: targetRoll,
      tolerance: kAngleToleranceDeg,
    );

    if (result.isAligned) {
      _alignedFrameCount++;
      if (_alignedFrameCount >= _holdSteadyThreshold) {
        _holdSteadyActive = true;
        _triggerAlignmentHaptic();
      }
    } else {
      _alignedFrameCount = 0;
      _holdSteadyActive = false;
    }

    return result;
  }

  void _triggerAlignmentHaptic() {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (nowMs - _lastHapticMs < _hapticCooldownMs) return;
    _lastHapticMs = nowMs;
    _haptic.alignmentFeedback();
  }

  void reset() {
    _alignedFrameCount = 0;
    _holdSteadyActive = false;
  }
}
