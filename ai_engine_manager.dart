// lib/modules/ai_engine/ai_engine_manager.dart
// ─────────────────────────────────────────────────────────────────────────────
// Central coordinator for all on-device AI inference.
//
// Responsibilities:
//   • Fan out each incoming [RawCameraFrame] to the PoseEstimator and
//     SceneClassifier on the same background isolate chain.
//   • Apply thermal mitigation: when back pressure is detected (inference
//     is slower than kFrameBudgetMs × 2), reduce inference rate automatically.
//   • Maintain the current "active" pose from the library and compute
//     Procrustes alignment every frame.
//   • Expose a single [aiStateStream] that combines all AI outputs so the
//     UI layer needs only one listener.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'package:camera/camera.dart';
import 'package:logger/logger.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/pose_library.dart';
import '../../core/models/pose_model.dart';
import '../../core/models/scene_classification.dart';
import '../../core/models/sensor_state.dart';
import '../../core/utils/procrustes_analysis.dart';
import '../camera/camera_controller_wrapper.dart';
import 'pose_estimator.dart';
import 'scene_classifier.dart';

final _log = Logger(printer: PrettyPrinter(methodCount: 0));

/// Aggregated AI state snapshot published once per frame.
class AIStateSnapshot {
  final LivePoseSnapshot?            livePose;
  final SceneClassificationResult    scene;
  final PoseDefinition?              activePose;
  final PoseAlignmentResult          alignment;
  final bool                         subjectDetected;
  final bool                         inFallbackMode;

  const AIStateSnapshot({
    required this.livePose,
    required this.scene,
    required this.activePose,
    required this.alignment,
    required this.subjectDetected,
    required this.inFallbackMode,
  });
}

class AIEngineManager {
  final PoseEstimator      _poseEstimator  = PoseEstimator();
  final SceneClassifier    _sceneClassifier = SceneClassifier();

  StreamSubscription<RawCameraFrame>? _frameSub;
  StreamSubscription<LivePoseSnapshot?>? _poseSub;
  StreamSubscription<SceneClassificationResult>? _sceneSub;

  final _stateController = StreamController<AIStateSnapshot>.broadcast();
  Stream<AIStateSnapshot> get aiStateStream => _stateController.stream;

  // Mutable state accumulator
  LivePoseSnapshot?         _latestPose;
  SceneClassificationResult _latestScene = SceneClassificationResult.defaultResult();
  PoseDefinition?           _activePose;
  int                       _lastNoSubjectMs = 0;
  bool                      _inFallback = false;

  // Thermal mitigation
  int _consecutiveSlowFrames = 0;
  bool _thermalThrottling = false;

  // ── Initialisation ─────────────────────────────────────────────────────────

  void initialise(ShootingMode mode) {
    _poseEstimator.initialise();
    _sceneClassifier.initialise();

    // Listen to sub-module outputs and merge.
    _poseSub = _poseEstimator.poseStream.listen(_onPose);
    _sceneSub = _sceneClassifier.resultStream.listen(_onScene);

    // Auto-select first pose for detected scene
    _activePose = kPoseLibrary.first;

    _log.i('[AIEngineManager] Initialised (mode=$mode)');
  }

  /// Attach to the camera frame stream.
  void attachFrameStream(Stream<RawCameraFrame> frameStream, int sensorOrientation) {
    _frameSub?.cancel();
    _frameSub = frameStream.listen((frame) {
      _onFrame(frame, sensorOrientation);
    });
  }

  // ── Active Pose Management ─────────────────────────────────────────────────

  /// Externally set the active reference pose (e.g., user selects from list).
  void setActivePose(PoseDefinition pose) {
    _activePose = pose;
    _log.i('[AIEngineManager] Active pose: ${pose.label}');
  }

  /// Auto-suggest the best pose for the current scene.
  PoseDefinition? suggestPoseForScene(SceneCategory cat) {
    final available = posesForScene(cat);
    return available.isNotEmpty ? available.first : null;
  }

  // ── Frame Dispatch ─────────────────────────────────────────────────────────

  int _lastFrameMs = 0;

  void _onFrame(RawCameraFrame frame, int sensorOrientation) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final elapsed = nowMs - _lastFrameMs;

    // Thermal mitigation: if inference is consistently slow, reduce rate.
    if (elapsed > kFrameBudgetMs * 2) {
      _consecutiveSlowFrames++;
      if (_consecutiveSlowFrames > 10 && !_thermalThrottling) {
        _thermalThrottling = true;
        _log.w('[AIEngineManager] Thermal throttling active');
      }
    } else {
      _consecutiveSlowFrames = 0;
      if (_thermalThrottling) {
        _thermalThrottling = false;
        _log.i('[AIEngineManager] Thermal throttling lifted');
      }
    }

    // Under throttling: skip every other frame for pose, keep scene cadence.
    if (_thermalThrottling && nowMs % 2 == 0) return;

    _lastFrameMs = nowMs;
    _poseEstimator.processFrame(frame.image, sensorOrientation);
    _sceneClassifier.processFrame(frame.image, sensorOrientation);
  }

  // ── Sub-Module Output Handlers ─────────────────────────────────────────────

  void _onPose(LivePoseSnapshot? snapshot) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    _latestPose = snapshot;

    if (snapshot == null || !snapshot.isValid) {
      if (_lastNoSubjectMs == 0) _lastNoSubjectMs = nowMs;
      if (nowMs - _lastNoSubjectMs >= kNoSubjectTimeoutMs) {
        _inFallback = true;
      }
    } else {
      _lastNoSubjectMs = 0;
      _inFallback = false;
    }

    _emit();
  }

  void _onScene(SceneClassificationResult result) {
    _latestScene = result;
    // Auto-suggest a matching pose when scene changes significantly.
    if (_activePose?.category != result.category && result.confidence > 0.65) {
      final suggested = suggestPoseForScene(result.category);
      if (suggested != null) {
        _activePose = suggested;
        _log.i('[AIEngineManager] Auto-suggested pose: ${suggested.label} '
            'for scene: ${result.category.displayName}');
      }
    }
    _emit();
  }

  void _emit() {
    if (_stateController.isClosed) return;

    final alignment = _activePose != null && _latestPose != null
        ? ProcrustesAnalysis.align(
            live: _latestPose!.landmarks,
            target: _activePose!.landmarks,
          )
        : PoseAlignmentResult.empty;

    _stateController.add(AIStateSnapshot(
      livePose: _latestPose,
      scene: _latestScene,
      activePose: _activePose,
      alignment: alignment,
      subjectDetected: _latestPose != null && _latestPose!.isValid,
      inFallbackMode: _inFallback,
    ));
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  Future<void> dispose() async {
    await _frameSub?.cancel();
    await _poseSub?.cancel();
    await _sceneSub?.cancel();
    await _poseEstimator.dispose();
    await _sceneClassifier.dispose();
    await _stateController.close();
  }
}
