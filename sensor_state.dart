// lib/core/models/sensor_state.dart
import 'package:equatable/equatable.dart';
import '../constants/app_constants.dart';

/// Camera / shooting mode
enum ShootingMode { humanPortrait, environmentWildlife }

/// Fused orientation derived from accelerometer + gyroscope
class DeviceOrientation extends Equatable {
  /// Pitch: negative = tilted up (low-angle shot), positive = tilted down.
  final double pitchDeg;

  /// Roll: negative = rolled left, positive = rolled right.
  final double rollDeg;

  /// Yaw: compass bearing (0–360°).
  final double yawDeg;

  const DeviceOrientation({
    required this.pitchDeg,
    required this.rollDeg,
    required this.yawDeg,
  });

  static const DeviceOrientation level =
      DeviceOrientation(pitchDeg: 0, rollDeg: 0, yawDeg: 0);

  @override
  List<Object?> get props => [pitchDeg, rollDeg, yawDeg];

  @override
  String toString() =>
      'Orientation(P:${pitchDeg.toStringAsFixed(1)}° R:${rollDeg.toStringAsFixed(1)}° Y:${yawDeg.toStringAsFixed(1)}°)';
}

/// Direction the user should tilt the device.
enum TiltDirection { up, down, left, right, aligned }

/// Result of comparing current orientation against a target pose orientation.
class OrientationValidationResult extends Equatable {
  final double pitchError;   // currentPitch − targetPitch
  final double rollError;    // currentRoll  − targetRoll
  final bool   isAligned;
  final TiltDirection verticalDirection;
  final TiltDirection horizontalDirection;

  const OrientationValidationResult({
    required this.pitchError,
    required this.rollError,
    required this.isAligned,
    required this.verticalDirection,
    required this.horizontalDirection,
  });

  static OrientationValidationResult compute({
    required DeviceOrientation current,
    required double targetPitch,
    required double targetRoll,
    double tolerance = kAngleToleranceDeg,
  }) {
    final pe = current.pitchDeg - targetPitch;
    final re = current.rollDeg - targetRoll;

    final aligned = pe.abs() <= tolerance && re.abs() <= tolerance;

    TiltDirection v;
    if (pe.abs() <= tolerance) {
      v = TiltDirection.aligned;
    } else if (pe > 0) {
      v = TiltDirection.down; // pitched too far down → move camera up
    } else {
      v = TiltDirection.up;
    }

    TiltDirection h;
    if (re.abs() <= tolerance) {
      h = TiltDirection.aligned;
    } else if (re > 0) {
      h = TiltDirection.right;
    } else {
      h = TiltDirection.left;
    }

    return OrientationValidationResult(
      pitchError: pe,
      rollError: re,
      isAligned: aligned,
      verticalDirection: v,
      horizontalDirection: h,
    );
  }

  @override
  List<Object?> get props => [pitchError, rollError, isAligned];
}

/// Aggregated state snapshot passed to the UI layer once per frame.
class CameraSessionState {
  final ShootingMode            shootingMode;
  final DeviceOrientation       orientation;
  final OrientationValidationResult orientationResult;
  final bool                    subjectDetected;
  final bool                    isLowLight;
  final bool                    inCompositionGuideMode;
  final double                  estimatedLux;

  const CameraSessionState({
    required this.shootingMode,
    required this.orientation,
    required this.orientationResult,
    required this.subjectDetected,
    required this.isLowLight,
    required this.inCompositionGuideMode,
    required this.estimatedLux,
  });

  static CameraSessionState initial() => CameraSessionState(
        shootingMode: ShootingMode.humanPortrait,
        orientation: DeviceOrientation.level,
        orientationResult: OrientationValidationResult(
          pitchError: 0,
          rollError: 0,
          isAligned: false,
          verticalDirection: TiltDirection.aligned,
          horizontalDirection: TiltDirection.aligned,
        ),
        subjectDetected: false,
        isLowLight: false,
        inCompositionGuideMode: false,
        estimatedLux: 100,
      );

  CameraSessionState copyWith({
    ShootingMode? shootingMode,
    DeviceOrientation? orientation,
    OrientationValidationResult? orientationResult,
    bool? subjectDetected,
    bool? isLowLight,
    bool? inCompositionGuideMode,
    double? estimatedLux,
  }) {
    return CameraSessionState(
      shootingMode: shootingMode ?? this.shootingMode,
      orientation: orientation ?? this.orientation,
      orientationResult: orientationResult ?? this.orientationResult,
      subjectDetected: subjectDetected ?? this.subjectDetected,
      isLowLight: isLowLight ?? this.isLowLight,
      inCompositionGuideMode: inCompositionGuideMode ?? this.inCompositionGuideMode,
      estimatedLux: estimatedLux ?? this.estimatedLux,
    );
  }
}
