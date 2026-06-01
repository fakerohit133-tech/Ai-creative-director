// lib/modules/sensor/sensor_fusion_controller.dart
// ─────────────────────────────────────────────────────────────────────────────
// Hardware sensor fusion using a complementary filter.
//
// Theory:
//   Accelerometer provides absolute orientation (low noise, high-frequency
//   drift) and gyroscope provides smooth short-term rotation (low noise,
//   integrates drift over time).  We blend them:
//
//     fused = α × (fused + gyro_delta × dt) + (1 − α) × accel_angle
//
//   where α = kSensorFusionAlpha = 0.98 (strongly biases gyro for smooth
//   per-frame motion while the accelerometer corrects long-term drift).
//
// Performance notes:
//   • Both sensor streams run at the platform's max rate (SENSOR_DELAY_GAME).
//   • We use sensors_plus which delivers events on background threads; we
//     collect them into a local buffer and publish on a broadcast stream at
//     a rate gated by [kFrameBudgetMs] so the UI never sees stale data.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:math' as math;
import 'package:sensors_plus/sensors_plus.dart';
import 'package:logger/logger.dart';
import '../../core/constants/app_constants.dart';
import '../../core/models/sensor_state.dart';

final _log = Logger(printer: PrettyPrinter(methodCount: 0));

class SensorFusionController {
  // Complementary filter state
  double _fusedPitch = 0.0;
  double _fusedRoll  = 0.0;
  double _fusedYaw   = 0.0;

  // Previous gyro measurement timestamp
  DateTime? _lastGyroTs;

  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<GyroscopeEvent>?     _gyroSub;

  // Accelerometer readings (gravity vector in m/s²)
  double _ax = 0, _ay = 0, _az = 9.8;

  // Gyroscope readings (rad/s)
  double _gx = 0, _gy = 0, _gz = 0;

  final _orientationController = StreamController<DeviceOrientation>.broadcast();
  Stream<DeviceOrientation> get orientationStream =>
      _orientationController.stream;

  DeviceOrientation _lastOrientation = DeviceOrientation.level;
  DeviceOrientation get lastOrientation => _lastOrientation;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  void start() {
    _accelSub = accelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 10),
    ).listen(_onAccelerometer);

    _gyroSub = gyroscopeEventStream(
      samplingPeriod: const Duration(milliseconds: 10),
    ).listen(_onGyroscope);

    _log.i('[SensorFusion] Accelerometer + Gyroscope streams started');
  }

  void stop() {
    _accelSub?.cancel();
    _gyroSub?.cancel();
    _orientationController.close();
    _log.i('[SensorFusion] Streams stopped');
  }

  // ── Event Handlers ─────────────────────────────────────────────────────────

  void _onAccelerometer(AccelerometerEvent e) {
    _ax = e.x;
    _ay = e.y;
    _az = e.z;
    _fuseAndEmit();
  }

  void _onGyroscope(GyroscopeEvent e) {
    final now = DateTime.now();
    final dt = _lastGyroTs != null
        ? now.difference(_lastGyroTs!).inMicroseconds / 1e6
        : 0.01;
    _lastGyroTs = now;

    // Limit dt to avoid large jumps after app resumes from background.
    final safeDt = dt.clamp(0.0, 0.1);

    // Integrate gyroscope (angular velocity → angle change).
    // Note: axis mapping depends on device/platform conventions.
    // We follow the right-hand rule with the device held in portrait:
    //   gy → pitch change,  gx → roll change,  gz → yaw change
    _gx = e.x;
    _gy = e.y;
    _gz = e.z;

    _fusedPitch += _gy * safeDt * (180.0 / math.pi);
    _fusedRoll  += _gx * safeDt * (180.0 / math.pi);
    _fusedYaw   += _gz * safeDt * (180.0 / math.pi);

    _fuseAndEmit();
  }

  void _fuseAndEmit() {
    // Accelerometer-derived pitch and roll from gravity vector.
    // Pitch: rotation around X-axis (forward tilt).
    // Roll:  rotation around Y-axis (side tilt).
    final accelPitch = _accelPitch(_ax, _ay, _az);
    final accelRoll  = _accelRoll(_ax, _ay, _az);

    // Complementary filter blend.
    _fusedPitch = kSensorFusionAlpha * _fusedPitch +
        (1.0 - kSensorFusionAlpha) * accelPitch;
    _fusedRoll  = kSensorFusionAlpha * _fusedRoll +
        (1.0 - kSensorFusionAlpha) * accelRoll;

    final orientation = DeviceOrientation(
      pitchDeg: _fusedPitch,
      rollDeg:  _fusedRoll,
      yawDeg:   _fusedYaw % 360.0,
    );

    _lastOrientation = orientation;
    if (!_orientationController.isClosed) {
      _orientationController.add(orientation);
    }
  }

  // ── Angle derivations from gravity vector ──────────────────────────────────

  /// Pitch from accelerometer: angle of tilt forward/back.
  double _accelPitch(double ax, double ay, double az) {
    // atan2(ay, sqrt(ax² + az²)) → pitch in degrees
    return math.atan2(ay, math.sqrt(ax * ax + az * az)) * 180.0 / math.pi;
  }

  /// Roll from accelerometer: angle of tilt left/right.
  double _accelRoll(double ax, double ay, double az) {
    // atan2(-ax, az) → roll in degrees
    return math.atan2(-ax, az) * 180.0 / math.pi;
  }

  // ── Reset ──────────────────────────────────────────────────────────────────

  /// Zero the gyroscope integration (call when resuming from background).
  void resetIntegration() {
    _fusedPitch = 0.0;
    _fusedRoll  = 0.0;
    _fusedYaw   = 0.0;
    _lastGyroTs = null;
  }

  Future<void> dispose() async {
    stop();
  }
}
