// lib/services/pose_database_service.dart
// ─────────────────────────────────────────────────────────────────────────────
// Lightweight in-memory vector database over the 50 reference poses.
//
// At startup, we pre-compute a normalised flat vector for every pose
// so that similarity queries during a session are O(n) dot-products
// with no per-query memory allocation.
//
// API:
//   • query(liveLandmarks, scene)  → ranked List<PoseMatch>
//   • posesForScene(category)      → List<PoseDefinition>
//   • findById(id)                 → PoseDefinition?
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:math' as math;
import '../core/constants/pose_library.dart';
import '../core/models/pose_model.dart';
import '../core/models/scene_classification.dart';
import '../core/utils/math_utils.dart';
import '../core/utils/procrustes_analysis.dart';

class PoseMatch {
  final PoseDefinition pose;
  final double         similarity; // [0, 1]
  const PoseMatch({required this.pose, required this.similarity});
}

class PoseDatabaseService {
  // Pre-computed normalised vectors keyed by pose id.
  final Map<String, List<double>> _vectorIndex = {};

  void initialise() {
    for (final pose in kPoseLibrary) {
      final normalised = normaliseScale(centreAtOrigin(pose.landmarks));
      _vectorIndex[pose.id] = flattenLandmarks(normalised);
    }
  }

  // ── Queries ────────────────────────────────────────────────────────────────

  /// Return poses ranked by cosine similarity to [live], optionally filtered
  /// to [sceneFilter].  Returns top [limit] results.
  List<PoseMatch> query({
    required List<PoseLandmark> live,
    SceneCategory? sceneFilter,
    int limit = 5,
  }) {
    final queryVec = flattenLandmarks(normaliseScale(centreAtOrigin(live)));
    final candidates = sceneFilter != null
        ? kPoseLibrary.where((p) => p.category == sceneFilter).toList()
        : kPoseLibrary;

    final matches = <PoseMatch>[];
    for (final pose in candidates) {
      final refVec = _vectorIndex[pose.id];
      if (refVec == null) continue;
      final sim = ((cosineSimilarity(queryVec, refVec) + 1.0) / 2.0)
          .clamp(0.0, 1.0);
      matches.add(PoseMatch(pose: pose, similarity: sim));
    }

    matches.sort((a, b) => b.similarity.compareTo(a.similarity));
    return matches.take(limit).toList();
  }

  /// All poses for a given scene category.
  List<PoseDefinition> posesForScene(SceneCategory cat) =>
      kPoseLibrary.where((p) => p.category == cat).toList();

  /// Look up a pose by its unique id.
  PoseDefinition? findById(String id) {
    try {
      return kPoseLibrary.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  /// All available poses.
  List<PoseDefinition> get all => kPoseLibrary;
}
