// lib/core/utils/math_utils.dart
import 'dart:math' as math;
import '../models/pose_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// General vector / matrix helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Clamp [value] into [min, max].
double clamp(double value, double min, double max) =>
    value < min ? min : (value > max ? max : value);

/// Degrees → radians.
double toRad(double deg) => deg * math.pi / 180.0;

/// Radians → degrees.
double toDeg(double rad) => rad * 180.0 / math.pi;

/// Dot-product of two flat double lists (must be same length).
double dotProduct(List<double> a, List<double> b) {
  assert(a.length == b.length, 'Vector length mismatch');
  double sum = 0;
  for (int i = 0; i < a.length; i++) {
    sum += a[i] * b[i];
  }
  return sum;
}

/// L2 norm of a flat double list.
double l2Norm(List<double> v) {
  double sum = 0;
  for (final x in v) sum += x * x;
  return math.sqrt(sum);
}

/// Cosine similarity of two flat vectors.
double cosineSimilarity(List<double> a, List<double> b) {
  final na = l2Norm(a);
  final nb = l2Norm(b);
  if (na == 0 || nb == 0) return 0.0;
  return (dotProduct(a, b) / (na * nb)).clamp(-1.0, 1.0);
}

// ─────────────────────────────────────────────────────────────────────────────
// Pose landmark utilities
// ─────────────────────────────────────────────────────────────────────────────

/// Flatten a list of [PoseLandmark]s into [x0, y0, x1, y1, ...].
List<double> flattenLandmarks(List<PoseLandmark> pts) {
  final out = <double>[];
  for (final p in pts) {
    out.add(p.x);
    out.add(p.y);
  }
  return out;
}

/// Centre of mass of a landmark list.
PoseLandmark centroid(List<PoseLandmark> pts) {
  if (pts.isEmpty) return const PoseLandmark(x: 0.5, y: 0.5);
  double sx = 0, sy = 0;
  for (final p in pts) {
    sx += p.x;
    sy += p.y;
  }
  return PoseLandmark(x: sx / pts.length, y: sy / pts.length);
}

/// Translate landmarks so their centroid is at the origin.
List<PoseLandmark> centreAtOrigin(List<PoseLandmark> pts) {
  final c = centroid(pts);
  return pts.map((p) => p - c).toList();
}

/// Scale landmarks so the max distance from origin = 1.
List<PoseLandmark> normaliseScale(List<PoseLandmark> pts) {
  double maxD = 0;
  for (final p in pts) {
    final d = math.sqrt(p.x * p.x + p.y * p.y);
    if (d > maxD) maxD = d;
  }
  if (maxD == 0) return pts;
  return pts.map((p) => p * (1.0 / maxD)).toList();
}

/// Per-landmark Euclidean distance between two equal-length landmark lists.
List<double> perLandmarkDistance(
    List<PoseLandmark> a, List<PoseLandmark> b) {
  assert(a.length == b.length);
  return List.generate(a.length, (i) {
    final dx = a[i].x - b[i].x;
    final dy = a[i].y - b[i].y;
    return math.sqrt(dx * dx + dy * dy);
  });
}
