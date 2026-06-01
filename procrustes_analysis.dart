// lib/core/utils/procrustes_analysis.dart
// ─────────────────────────────────────────────────────────────────────────────
// Generalised Procrustes Analysis (GPA) for 2-D landmark pose matching.
//
// Pipeline:
//   1. Translate both shapes so their centroids coincide at the origin.
//   2. Scale both shapes to unit size (Procrustes normalisation).
//   3. Find the optimal rotation angle θ that minimises the sum of squared
//      distances between corresponding landmarks using the analytical formula:
//
//        θ = atan2( Σ(aᵢ × bᵢ),  Σ(aᵢ · bᵢ) )
//
//      where × is the 2-D cross-product and · the dot-product.
//   4. Apply the rotation to shape A and compute residual distance.
//   5. Convert residual → similarity score in [0, 1] using an exponential
//      decay kernel:   similarity = exp(−k · d²)
//
// We also expose a fast cosine-similarity path (no rotation) for the live
// feedback loop when full GPA is too expensive.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:math' as math;
import '../models/pose_model.dart';
import '../models/pose_model.dart' show PoseAlignmentResult;
import '../constants/app_constants.dart';
import 'math_utils.dart';

class ProcrustesAnalysis {
  /// Full GPA-based alignment result.
  ///
  /// [live]   – current pose landmarks from the AI engine (17 keypoints)
  /// [target] – reference pose from the pose library     (17 keypoints)
  static PoseAlignmentResult align({
    required List<PoseLandmark> live,
    required List<PoseLandmark> target,
  }) {
    if (live.length != target.length || live.isEmpty) {
      return PoseAlignmentResult.empty;
    }

    // Step 1 & 2: Centre + normalise both sets
    final lNorm = normaliseScale(centreAtOrigin(live));
    final tNorm = normaliseScale(centreAtOrigin(target));

    // Step 3: Optimal rotation angle
    double sumCross = 0, sumDot = 0;
    for (int i = 0; i < lNorm.length; i++) {
      // cross product (scalar z of 3D cross): ax*by − ay*bx
      sumCross += lNorm[i].x * tNorm[i].y - lNorm[i].y * tNorm[i].x;
      // dot product: ax*bx + ay*by
      sumDot   += lNorm[i].x * tNorm[i].x + lNorm[i].y * tNorm[i].y;
    }
    final theta = math.atan2(sumCross, sumDot);
    final cosT = math.cos(theta);
    final sinT = math.sin(theta);

    // Step 4: Rotate lNorm by theta
    final rotated = lNorm.map((p) => PoseLandmark(
          x: p.x * cosT - p.y * sinT,
          y: p.x * sinT + p.y * cosT,
        )).toList();

    // Per-landmark distances after optimal alignment
    final errors = perLandmarkDistance(rotated, tNorm);
    final meanSqDist = errors.fold(0.0, (s, e) => s + e * e) / errors.length;

    // Step 5: Exponential decay → similarity in [0,1]
    // k tuned so that meanSqDist = 0.02 → ~87% similarity (≈ "aligned").
    const double k = 30.0;
    final similarity = math.exp(-k * meanSqDist).clamp(0.0, 1.0);

    return PoseAlignmentResult(
      similarity: similarity,
      isAligned: similarity >= kPoseAlignmentThreshold,
      perLandmarkError: errors,
    );
  }

  /// Fast cosine-similarity path — no rotation, O(n).
  /// Used for real-time HUD percentage when GPA is throttled.
  static double fastCosineSimilarity({
    required List<PoseLandmark> live,
    required List<PoseLandmark> target,
  }) {
    if (live.length != target.length || live.isEmpty) return 0.0;
    final lVec = flattenLandmarks(centreAtOrigin(live));
    final tVec = flattenLandmarks(centreAtOrigin(target));
    // Map cosine similarity from [-1,1] to [0,1]
    return ((cosineSimilarity(lVec, tVec) + 1.0) / 2.0).clamp(0.0, 1.0);
  }
}
