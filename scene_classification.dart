// lib/core/models/scene_classification.dart

/// The five environment buckets output by the on-device scene classifier.
enum SceneCategory {
  urbanStreet,
  indoorStudio,
  minimalIndoor,
  natureGreenery,
  openLandscape,
}

extension SceneCategoryX on SceneCategory {
  String get displayName {
    switch (this) {
      case SceneCategory.urbanStreet:    return 'Urban / Street';
      case SceneCategory.indoorStudio:   return 'Indoor Studio';
      case SceneCategory.minimalIndoor:  return 'Minimal / Indoor';
      case SceneCategory.natureGreenery: return 'Nature / Greenery';
      case SceneCategory.openLandscape:  return 'Open Landscape';
    }
  }

  String get emoji {
    switch (this) {
      case SceneCategory.urbanStreet:    return '🏙️';
      case SceneCategory.indoorStudio:   return '🎞️';
      case SceneCategory.minimalIndoor:  return '🪟';
      case SceneCategory.natureGreenery: return '🌿';
      case SceneCategory.openLandscape:  return '🌄';
    }
  }
}

/// Snapshot output from the scene classifier.
class SceneClassificationResult {
  final SceneCategory category;
  final double confidence;        // [0, 1]
  final Map<SceneCategory, double> allScores;
  final DateTime timestamp;

  const SceneClassificationResult({
    required this.category,
    required this.confidence,
    required this.allScores,
    required this.timestamp,
  });

  static SceneClassificationResult defaultResult() =>
      SceneClassificationResult(
        category: SceneCategory.minimalIndoor,
        confidence: 0.5,
        allScores: {for (var c in SceneCategory.values) c: 0.2},
        timestamp: DateTime.now(),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// lib/core/models/sensor_state.dart
// ─────────────────────────────────────────────────────────────────────────────
