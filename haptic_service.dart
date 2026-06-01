// lib/services/haptic_service.dart
// ─────────────────────────────────────────────────────────────────────────────
// Thin wrapper around the `vibration` package that provides named haptic
// patterns semantically aligned with the camera UX events.
//
// Pattern design rationale:
//   • Alignment feedback: short double-tap (tactile "snap") — signals the
//     user to hold steady without startling them.
//   • Shutter feedback: single firm pulse — classic camera "click" proxy.
//   • Warning feedback: long rumble — used when low-light fallback activates.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:vibration/vibration.dart';
import 'package:logger/logger.dart';
import '../core/constants/app_constants.dart';

final _log = Logger(printer: PrettyPrinter(methodCount: 0));

class HapticService {
  bool _available = false;

  Future<void> init() async {
    try {
      _available = (await Vibration.hasVibrator()) ?? false;
      _log.i('[Haptic] Vibrator available: $_available');
    } catch (e) {
      _log.w('[Haptic] Init failed: $e');
    }
  }

  /// Double light tap — triggered when device enters ±1.5° alignment window.
  Future<void> alignmentFeedback() async {
    if (!_available) return;
    await Vibration.vibrate(
      pattern: [0, kHapticAlignDurationMs, 80, kHapticAlignDurationMs],
      intensities: [0, 64, 0, 64],
    );
  }

  /// Single firm pulse — triggered on shutter release.
  Future<void> shutterFeedback() async {
    if (!_available) return;
    await Vibration.vibrate(
      duration: kHapticShutterDurationMs,
      amplitude: 180,
    );
  }

  /// Gentle rumble — triggered when transitioning to fallback / low-light mode.
  Future<void> warningFeedback() async {
    if (!_available) return;
    await Vibration.vibrate(
      pattern: [0, 80, 60, 80, 60, 80],
      intensities: [0, 48, 0, 48, 0, 48],
    );
  }

  Future<void> dispose() async {
    Vibration.cancel();
  }
}
