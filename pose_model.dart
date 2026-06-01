// lib/core/models/pose_model.dart
import 'package:equatable/equatable.dart';
import 'scene_classification.dart';

/// A single 2-D normalised landmark coordinate [0,1].
class PoseLandmark extends Equatable {
  final double x;
  final double y;

  const PoseLandmark({required this.x, required this.y});

  PoseLandmark operator +(PoseLandmark other) =>
      PoseLandmark(x: x + other.x, y: y + other.y);
  PoseLandmark operator -(PoseLandmark other) =>
      PoseLandmark(x: x - other.x, y: y - other.y);
  PoseLandmark operator *(double s) => PoseLandmark(x: x * s, y: y * s);

  double distanceTo(PoseLandmark other) {
    final dx = x - other.x;
    final dy = y - other.y;
    return (dx * dx + dy * dy) == 0 ? 0 : (dx * dx + dy * dy) * 0.5;
  }

  @override
  List<Object?> get props => [x, y];

  @override
  String toString() => 'LM(${x.toStringAsFixed(3)}, ${y.toStringAsFixed(3)})';
}

/// A reference pose definition stored in the on-device pose library.
class PoseDefinition extends Equatable {
  final String id;
  final String label;
  final SceneCategory category;
  final double targetPitchDeg;
  final double targetRollDeg;
  final String directionCue;
  final List<PoseLandmark> landmarks; // 17 MediaPipe keypoints

  const PoseDefinition({
    required this.id,
    required this.label,
    required this.category,
    required this.targetPitchDeg,
    required this.targetRollDeg,
    required this.directionCue,
    required this.landmarks,
  });

  @override
  List<Object?> get props => [id];
}

/// Snapshot of a live pose detected by the on-device AI engine.
class LivePoseSnapshot {
  final List<PoseLandmark> landmarks;     // 17 keypoints, normalised [0,1]
  final List<double>       confidence;   // Per-landmark confidence scores
  final DateTime           timestamp;

  const LivePoseSnapshot({
    required this.landmarks,
    required this.confidence,
    required this.timestamp,
  });

  bool get isValid => landmarks.isNotEmpty && confidence.any((c) => c > 0.5);
}

/// Result of comparing a [LivePoseSnapshot] against a [PoseDefinition].
class PoseAlignmentResult {
  /// Cosine similarity in [0, 1]; 1.0 = perfect match.
  final double similarity;

  /// Percentage aligned to display on HUD.
  int get percentAligned => (similarity * 100).round().clamp(0, 100);

  /// True when similarity ≥ threshold defined in app_constants.
  final bool isAligned;

  /// Per-landmark distances (useful for segment-level guidance).
  final List<double> perLandmarkError;

  const PoseAlignmentResult({
    required this.similarity,
    required this.isAligned,
    required this.perLandmarkError,
  });

  static const PoseAlignmentResult empty = PoseAlignmentResult(
    similarity: 0,
    isAligned: false,
    perLandmarkError: [],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// lib/core/models/scene_classification.dart
// ─────────────────────────────────────────────────────────────────────────────
