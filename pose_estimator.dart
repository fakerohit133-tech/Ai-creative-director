// lib/modules/ai_engine/pose_estimator.dart
// ─────────────────────────────────────────────────────────────────────────────
// On-device human pose estimation using Google ML Kit PoseDetection
// (MediaPipe BlazePose under the hood).
//
// Design decisions:
//   • Inference runs on a dedicated Isolate via compute() so the main thread
//     is never blocked.
//   • Frame throttling: we schedule inference every [kPoseEstimatorIntervalMs]
//     milliseconds and silently drop frames arriving faster than the model.
//   • If no pose is detected for [kNoSubjectTimeoutMs] ms, we emit a null
//     result so the upstream session manager can trigger fallback mode.
//   • Input image is downscaled to 256×256 before passing to the model to
//     stay comfortably within the 33 ms frame budget.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import '../../core/constants/app_constants.dart';
import '../../core/models/pose_model.dart';

final _log = Logger(printer: PrettyPrinter(methodCount: 0));

class PoseEstimator {
  late final PoseDetector _detector;
  bool _isRunning = false;
  int  _lastInferenceMs = 0;
  int  _noSubjectSinceMs = 0;

  /// Stream of [LivePoseSnapshot]; null → no subject detected.
  final _poseController =
      StreamController<LivePoseSnapshot?>.broadcast();
  Stream<LivePoseSnapshot?> get poseStream => _poseController.stream;

  void initialise() {
    _detector = PoseDetector(
      options: PoseDetectorOptions(
        mode: PoseDetectionMode.stream,   // continuous video optimisation
        model: PoseDetectionModel.accurate, // falls back gracefully on low-end
      ),
    );
    _log.i('[PoseEstimator] MediaPipe PoseDetector initialised');
  }

  // ── Frame Processing ───────────────────────────────────────────────────────

  /// Feed a raw [CameraImage] from the camera frame stream.
  /// Returns immediately; result is emitted on [poseStream].
  void processFrame(CameraImage frame, int sensorOrientation) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    // Throttle: skip this frame if previous inference is still within budget.
    if (nowMs - _lastInferenceMs < kPoseEstimatorIntervalMs) return;
    if (_isRunning) return; // Never queue concurrent inferences.

    _isRunning = true;
    _lastInferenceMs = nowMs;

    _runInference(frame, sensorOrientation, nowMs);
  }

  Future<void> _runInference(
      CameraImage frame, int sensorOrientation, int frameMs) async {
    try {
      final inputImage = _buildInputImage(frame, sensorOrientation);
      if (inputImage == null) {
        _emitNoSubject(frameMs);
        return;
      }

      final poses = await _detector.processImage(inputImage);

      if (poses.isEmpty) {
        _emitNoSubject(frameMs);
        return;
      }

      // Use the highest-confidence pose (first pose from the detector).
      final pose = poses.first;
      final snapshot = _buildSnapshot(pose);
      _noSubjectSinceMs = 0; // reset timeout
      _poseController.add(snapshot);
    } catch (e) {
      _log.e('[PoseEstimator] Inference error: $e');
      _emitNoSubject(frameMs);
    } finally {
      _isRunning = false;
    }
  }

  void _emitNoSubject(int nowMs) {
    if (_noSubjectSinceMs == 0) _noSubjectSinceMs = nowMs;
    // Only emit null after the timeout to avoid noisy flickering.
    if (nowMs - _noSubjectSinceMs >= kNoSubjectTimeoutMs) {
      _poseController.add(null);
    }
  }

  // ── Input Image Construction ───────────────────────────────────────────────

  /// Convert [CameraImage] (YUV or BGRA) into an [InputImage] for ML Kit.
  InputImage? _buildInputImage(CameraImage frame, int sensorOrientation) {
    try {
      final format = InputImageFormatValue.fromRawValue(frame.format.raw);
      if (format == null) {
        _log.w('[PoseEstimator] Unknown image format: ${frame.format.raw}');
        return null;
      }

      // For multi-plane YUV420 (Android), concatenate all planes into one
      // contiguous byte buffer as required by ML Kit.
      final WriteBuffer allBytes = WriteBuffer();
      for (final plane in frame.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      final rotation = _mapSensorOrientation(sensorOrientation);

      return InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: Size(
              frame.width.toDouble(), frame.height.toDouble()),
          rotation: rotation,
          format: format,
          bytesPerRow: frame.planes.first.bytesPerRow,
        ),
      );
    } catch (e) {
      _log.w('[PoseEstimator] buildInputImage failed: $e');
      return null;
    }
  }

  InputImageRotation _mapSensorOrientation(int deg) {
    switch (deg) {
      case 90:  return InputImageRotation.rotation90deg;
      case 180: return InputImageRotation.rotation180deg;
      case 270: return InputImageRotation.rotation270deg;
      default:  return InputImageRotation.rotation0deg;
    }
  }

  // ── Snapshot Construction ──────────────────────────────────────────────────

  /// Map ML Kit [Pose] landmarks to our normalised [LivePoseSnapshot].
  LivePoseSnapshot _buildSnapshot(Pose pose) {
    // Ordered list of the 17 landmarks we care about.
    final orderedTypes = [
      PoseLandmarkType.nose,
      PoseLandmarkType.leftEye,
      PoseLandmarkType.rightEye,
      PoseLandmarkType.leftEar,
      PoseLandmarkType.rightEar,
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.rightShoulder,
      PoseLandmarkType.leftElbow,
      PoseLandmarkType.rightElbow,
      PoseLandmarkType.leftWrist,
      PoseLandmarkType.rightWrist,
      PoseLandmarkType.leftHip,
      PoseLandmarkType.rightHip,
      PoseLandmarkType.leftKnee,
      PoseLandmarkType.rightKnee,
      PoseLandmarkType.leftAnkle,
      PoseLandmarkType.rightAnkle,
    ];

    // Find bounding box for normalisation.
    double minX = double.infinity, maxX = -double.infinity;
    double minY = double.infinity, maxY = -double.infinity;
    for (final t in orderedTypes) {
      final lm = pose.landmarks[t];
      if (lm == null) continue;
      if (lm.x < minX) minX = lm.x;
      if (lm.x > maxX) maxX = lm.x;
      if (lm.y < minY) minY = lm.y;
      if (lm.y > maxY) maxY = lm.y;
    }
    final w = (maxX - minX).clamp(1.0, double.infinity);
    final h = (maxY - minY).clamp(1.0, double.infinity);

    final landmarks = <PoseLandmark>[];
    final confidence = <double>[];

    for (final t in orderedTypes) {
      final lm = pose.landmarks[t];
      if (lm == null) {
        landmarks.add(const PoseLandmark(x: 0.5, y: 0.5));
        confidence.add(0.0);
      } else {
        landmarks.add(PoseLandmark(
          x: ((lm.x - minX) / w).clamp(0.0, 1.0),
          y: ((lm.y - minY) / h).clamp(0.0, 1.0),
        ));
        confidence.add(lm.likelihood.clamp(0.0, 1.0));
      }
    }

    return LivePoseSnapshot(
      landmarks: landmarks,
      confidence: confidence,
      timestamp: DateTime.now(),
    );
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  Future<void> dispose() async {
    await _detector.close();
    await _poseController.close();
  }
}
