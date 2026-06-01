// lib/core/constants/pose_library.dart
// ─────────────────────────────────────────────────────────────────────────────
// 50 "magazine-style" reference poses stored as normalised 2-D landmark
// coordinate vectors (17 MediaPipe / BlazePose landmarks × [x, y]).
//
// Each PoseDefinition bundles:
//   • A human-readable label and scene category
//   • Target device orientation (pitch / roll in degrees)
//   • 17 × [x, y] landmark coordinates in the range [0, 1],
//     measured from the top-left of a 1:1 bounding square
//   • Optional direction cues
//
// The coordinates are intentionally minimal / archetypal approximations.
// During runtime the on-device pose estimator produces real landmarks that
// are compared against these via Procrustes / cosine similarity.
// ─────────────────────────────────────────────────────────────────────────────

import '../models/pose_model.dart';
import '../models/scene_classification.dart';

/// MediaPipe Pose landmark indices (subset used for matching)
class LM {
  static const int nose         = 0;
  static const int leftEye      = 1;
  static const int rightEye     = 2;
  static const int leftEar      = 3;
  static const int rightEar     = 4;
  static const int leftShoulder = 5;
  static const int rightShoulder= 6;
  static const int leftElbow    = 7;
  static const int rightElbow   = 8;
  static const int leftWrist    = 9;
  static const int rightWrist   = 10;
  static const int leftHip      = 11;
  static const int rightHip     = 12;
  static const int leftKnee     = 13;
  static const int rightKnee    = 14;
  static const int leftAnkle    = 15;
  static const int rightAnkle   = 16;
}

// ---------------------------------------------------------------------------
// Helper: build a 17-landmark array from named positions.
// Unspecified landmarks default to [0.5, 0.5] (body centre).
// ---------------------------------------------------------------------------
List<PoseLandmark> _lm(Map<int, List<double>> pts) {
  return List.generate(17, (i) {
    final p = pts[i] ?? [0.5, 0.5];
    return PoseLandmark(x: p[0], y: p[1]);
  });
}

// ═══════════════════════════════════════════════════════════════════════════
//  POSE LIBRARY — 50 entries, grouped by scene category
// ═══════════════════════════════════════════════════════════════════════════

final List<PoseDefinition> kPoseLibrary = [

  // ─────────────────────────────────────────────────────────
  //  URBAN / STREET  (10 poses)
  // ─────────────────────────────────────────────────────────
  PoseDefinition(
    id: 'urban_01',
    label: 'Street Power Stance',
    category: SceneCategory.urbanStreet,
    targetPitchDeg: 0,
    targetRollDeg: 0,
    directionCue: 'Stand tall, feet shoulder-width, slight chin lift',
    landmarks: _lm({
      LM.nose:          [0.50, 0.08],
      LM.leftShoulder:  [0.38, 0.25],
      LM.rightShoulder: [0.62, 0.25],
      LM.leftElbow:     [0.30, 0.42],
      LM.rightElbow:    [0.70, 0.42],
      LM.leftWrist:     [0.28, 0.58],
      LM.rightWrist:    [0.72, 0.58],
      LM.leftHip:       [0.42, 0.55],
      LM.rightHip:      [0.58, 0.55],
      LM.leftKnee:      [0.40, 0.75],
      LM.rightKnee:     [0.60, 0.75],
      LM.leftAnkle:     [0.38, 0.95],
      LM.rightAnkle:    [0.62, 0.95],
    }),
  ),

  PoseDefinition(
    id: 'urban_02',
    label: 'Lean on Wall',
    category: SceneCategory.urbanStreet,
    targetPitchDeg: 5,
    targetRollDeg: -3,
    directionCue: 'Lean left shoulder against wall, arms relaxed',
    landmarks: _lm({
      LM.nose:          [0.48, 0.08],
      LM.leftShoulder:  [0.34, 0.26],
      LM.rightShoulder: [0.60, 0.24],
      LM.leftElbow:     [0.26, 0.40],
      LM.rightElbow:    [0.65, 0.40],
      LM.leftWrist:     [0.24, 0.54],
      LM.rightWrist:    [0.68, 0.52],
      LM.leftHip:       [0.40, 0.56],
      LM.rightHip:      [0.56, 0.54],
      LM.leftKnee:      [0.38, 0.75],
      LM.rightKnee:     [0.58, 0.73],
      LM.leftAnkle:     [0.37, 0.94],
      LM.rightAnkle:    [0.60, 0.92],
    }),
  ),

  PoseDefinition(
    id: 'urban_03',
    label: 'Heroic Low Angle',
    category: SceneCategory.urbanStreet,
    targetPitchDeg: -15,
    targetRollDeg: 0,
    directionCue: 'Lower camera to hip height, shoot upward',
    landmarks: _lm({
      LM.nose:          [0.50, 0.10],
      LM.leftShoulder:  [0.36, 0.28],
      LM.rightShoulder: [0.64, 0.28],
      LM.leftHip:       [0.42, 0.60],
      LM.rightHip:      [0.58, 0.60],
      LM.leftKnee:      [0.40, 0.78],
      LM.rightKnee:     [0.60, 0.78],
      LM.leftAnkle:     [0.38, 0.95],
      LM.rightAnkle:    [0.62, 0.95],
    }),
  ),

  PoseDefinition(
    id: 'urban_04',
    label: 'Walking Away',
    category: SceneCategory.urbanStreet,
    targetPitchDeg: 0,
    targetRollDeg: 0,
    directionCue: 'Subject walks away, looking back over shoulder',
    landmarks: _lm({
      LM.nose:          [0.55, 0.09],
      LM.leftShoulder:  [0.40, 0.26],
      LM.rightShoulder: [0.63, 0.24],
      LM.leftElbow:     [0.34, 0.43],
      LM.rightElbow:    [0.68, 0.40],
      LM.leftHip:       [0.43, 0.58],
      LM.rightHip:      [0.60, 0.56],
      LM.leftKnee:      [0.42, 0.76],
      LM.rightKnee:     [0.61, 0.74],
      LM.leftAnkle:     [0.40, 0.95],
      LM.rightAnkle:    [0.63, 0.93],
    }),
  ),

  PoseDefinition(
    id: 'urban_05',
    label: 'Crossed Arms — Editorial',
    category: SceneCategory.urbanStreet,
    targetPitchDeg: 0,
    targetRollDeg: 2,
    directionCue: 'Arms crossed at chest, weight on one hip',
    landmarks: _lm({
      LM.nose:          [0.50, 0.08],
      LM.leftShoulder:  [0.37, 0.26],
      LM.rightShoulder: [0.63, 0.26],
      LM.leftElbow:     [0.55, 0.38],
      LM.rightElbow:    [0.45, 0.38],
      LM.leftWrist:     [0.58, 0.34],
      LM.rightWrist:    [0.42, 0.34],
      LM.leftHip:       [0.41, 0.58],
      LM.rightHip:      [0.59, 0.55],
    }),
  ),

  PoseDefinition(
    id: 'urban_06',
    label: 'Sitting on Steps',
    category: SceneCategory.urbanStreet,
    targetPitchDeg: 8,
    targetRollDeg: 0,
    directionCue: 'Seated on steps, elbows on knees, gaze forward',
    landmarks: _lm({
      LM.nose:          [0.50, 0.12],
      LM.leftShoulder:  [0.38, 0.28],
      LM.rightShoulder: [0.62, 0.28],
      LM.leftElbow:     [0.35, 0.48],
      LM.rightElbow:    [0.65, 0.48],
      LM.leftWrist:     [0.40, 0.62],
      LM.rightWrist:    [0.60, 0.62],
      LM.leftHip:       [0.42, 0.58],
      LM.rightHip:      [0.58, 0.58],
      LM.leftKnee:      [0.38, 0.70],
      LM.rightKnee:     [0.62, 0.70],
    }),
  ),

  PoseDefinition(
    id: 'urban_07',
    label: 'Profile Shadow Play',
    category: SceneCategory.urbanStreet,
    targetPitchDeg: 0,
    targetRollDeg: -5,
    directionCue: 'Subject in strict profile, strong side-light',
    landmarks: _lm({
      LM.nose:          [0.62, 0.09],
      LM.leftShoulder:  [0.43, 0.27],
      LM.rightShoulder: [0.58, 0.27],
      LM.leftHip:       [0.45, 0.58],
      LM.rightHip:      [0.56, 0.58],
      LM.leftKnee:      [0.44, 0.77],
      LM.rightKnee:     [0.55, 0.77],
    }),
  ),

  PoseDefinition(
    id: 'urban_08',
    label: 'Candid Stride',
    category: SceneCategory.urbanStreet,
    targetPitchDeg: 0,
    targetRollDeg: 0,
    directionCue: 'Natural walking gait, 45° to camera',
    landmarks: _lm({
      LM.nose:          [0.52, 0.09],
      LM.leftShoulder:  [0.40, 0.25],
      LM.rightShoulder: [0.62, 0.26],
      LM.leftElbow:     [0.32, 0.42],
      LM.rightElbow:    [0.68, 0.41],
      LM.leftHip:       [0.43, 0.57],
      LM.rightHip:      [0.59, 0.57],
      LM.leftKnee:      [0.38, 0.74],
      LM.rightKnee:     [0.63, 0.71],
      LM.leftAnkle:     [0.36, 0.93],
      LM.rightAnkle:    [0.65, 0.88],
    }),
  ),

  PoseDefinition(
    id: 'urban_09',
    label: 'Over-Shoulder Glance',
    category: SceneCategory.urbanStreet,
    targetPitchDeg: 2,
    targetRollDeg: 0,
    directionCue: 'Back to camera, head turned 180° — eye contact',
    landmarks: _lm({
      LM.nose:          [0.52, 0.10],
      LM.leftShoulder:  [0.60, 0.26],
      LM.rightShoulder: [0.40, 0.26],
      LM.leftHip:       [0.57, 0.56],
      LM.rightHip:      [0.43, 0.56],
      LM.leftKnee:      [0.56, 0.75],
      LM.rightKnee:     [0.44, 0.75],
      LM.leftAnkle:     [0.55, 0.94],
      LM.rightAnkle:    [0.45, 0.94],
    }),
  ),

  PoseDefinition(
    id: 'urban_10',
    label: 'Crouching — Low Energy',
    category: SceneCategory.urbanStreet,
    targetPitchDeg: -10,
    targetRollDeg: 0,
    directionCue: 'Deep squat, arms wrapped around knees, introspective gaze',
    landmarks: _lm({
      LM.nose:          [0.50, 0.20],
      LM.leftShoulder:  [0.38, 0.35],
      LM.rightShoulder: [0.62, 0.35],
      LM.leftElbow:     [0.35, 0.52],
      LM.rightElbow:    [0.65, 0.52],
      LM.leftHip:       [0.42, 0.55],
      LM.rightHip:      [0.58, 0.55],
      LM.leftKnee:      [0.36, 0.65],
      LM.rightKnee:     [0.64, 0.65],
      LM.leftAnkle:     [0.38, 0.75],
      LM.rightAnkle:    [0.62, 0.75],
    }),
  ),

  // ─────────────────────────────────────────────────────────
  //  INDOOR STUDIO  (10 poses)
  // ─────────────────────────────────────────────────────────
  PoseDefinition(
    id: 'studio_01',
    label: 'High-Fashion Standing',
    category: SceneCategory.indoorStudio,
    targetPitchDeg: 0,
    targetRollDeg: 0,
    directionCue: 'Full-length, shoulders relaxed, strong eye contact',
    landmarks: _lm({
      LM.nose:          [0.50, 0.07],
      LM.leftShoulder:  [0.38, 0.24],
      LM.rightShoulder: [0.62, 0.24],
      LM.leftElbow:     [0.32, 0.38],
      LM.rightElbow:    [0.68, 0.38],
      LM.leftWrist:     [0.30, 0.52],
      LM.rightWrist:    [0.70, 0.52],
      LM.leftHip:       [0.43, 0.56],
      LM.rightHip:      [0.57, 0.56],
      LM.leftKnee:      [0.42, 0.76],
      LM.rightKnee:     [0.58, 0.76],
      LM.leftAnkle:     [0.41, 0.95],
      LM.rightAnkle:    [0.59, 0.95],
    }),
  ),

  PoseDefinition(
    id: 'studio_02',
    label: 'Seated — Knees Up',
    category: SceneCategory.indoorStudio,
    targetPitchDeg: 5,
    targetRollDeg: 0,
    directionCue: 'Seated on floor, knees drawn to chest, arms over knees',
    landmarks: _lm({
      LM.nose:          [0.50, 0.14],
      LM.leftShoulder:  [0.38, 0.30],
      LM.rightShoulder: [0.62, 0.30],
      LM.leftElbow:     [0.36, 0.45],
      LM.rightElbow:    [0.64, 0.45],
      LM.leftHip:       [0.42, 0.54],
      LM.rightHip:      [0.58, 0.54],
      LM.leftKnee:      [0.38, 0.60],
      LM.rightKnee:     [0.62, 0.60],
      LM.leftAnkle:     [0.40, 0.72],
      LM.rightAnkle:    [0.60, 0.72],
    }),
  ),

  PoseDefinition(
    id: 'studio_03',
    label: 'Contraposto — Classic',
    category: SceneCategory.indoorStudio,
    targetPitchDeg: 0,
    targetRollDeg: 0,
    directionCue: 'Weight on one leg, hip shifted, slight upper-body twist',
    landmarks: _lm({
      LM.nose:          [0.50, 0.08],
      LM.leftShoulder:  [0.40, 0.25],
      LM.rightShoulder: [0.62, 0.24],
      LM.leftHip:       [0.45, 0.55],
      LM.rightHip:      [0.60, 0.52],
      LM.leftKnee:      [0.44, 0.74],
      LM.rightKnee:     [0.61, 0.73],
    }),
  ),

  PoseDefinition(
    id: 'studio_04',
    label: 'Lying — Overhead Shot',
    category: SceneCategory.indoorStudio,
    targetPitchDeg: 90,
    targetRollDeg: 0,
    directionCue: 'Camera directly overhead. Subject lies flat, arms at sides',
    landmarks: _lm({
      LM.nose:          [0.50, 0.08],
      LM.leftShoulder:  [0.38, 0.26],
      LM.rightShoulder: [0.62, 0.26],
      LM.leftElbow:     [0.28, 0.40],
      LM.rightElbow:    [0.72, 0.40],
      LM.leftWrist:     [0.24, 0.55],
      LM.rightWrist:    [0.76, 0.55],
      LM.leftHip:       [0.42, 0.60],
      LM.rightHip:      [0.58, 0.60],
      LM.leftKnee:      [0.41, 0.78],
      LM.rightKnee:     [0.59, 0.78],
      LM.leftAnkle:     [0.40, 0.95],
      LM.rightAnkle:    [0.60, 0.95],
    }),
  ),

  PoseDefinition(
    id: 'studio_05',
    label: 'Hands On Hips — Confident',
    category: SceneCategory.indoorStudio,
    targetPitchDeg: 0,
    targetRollDeg: 0,
    directionCue: 'Both hands on hips, feet slightly apart, tall posture',
    landmarks: _lm({
      LM.nose:          [0.50, 0.08],
      LM.leftShoulder:  [0.37, 0.25],
      LM.rightShoulder: [0.63, 0.25],
      LM.leftElbow:     [0.32, 0.42],
      LM.rightElbow:    [0.68, 0.42],
      LM.leftWrist:     [0.38, 0.52],
      LM.rightWrist:    [0.62, 0.52],
      LM.leftHip:       [0.42, 0.55],
      LM.rightHip:      [0.58, 0.55],
    }),
  ),

  PoseDefinition(
    id: 'studio_06',
    label: 'Three-Quarter Turn',
    category: SceneCategory.indoorStudio,
    targetPitchDeg: 0,
    targetRollDeg: 0,
    directionCue: '45° body turn, head faces camera, back shoulder pulled back',
    landmarks: _lm({
      LM.nose:          [0.50, 0.09],
      LM.leftShoulder:  [0.42, 0.26],
      LM.rightShoulder: [0.60, 0.24],
      LM.leftHip:       [0.44, 0.57],
      LM.rightHip:      [0.57, 0.55],
    }),
  ),

  PoseDefinition(
    id: 'studio_07',
    label: 'Side Drape — Floor',
    category: SceneCategory.indoorStudio,
    targetPitchDeg: 85,
    targetRollDeg: 0,
    directionCue: 'Subject on side, resting on elbow, legs extended',
    landmarks: _lm({
      LM.nose:          [0.50, 0.10],
      LM.leftShoulder:  [0.36, 0.30],
      LM.rightShoulder: [0.64, 0.24],
      LM.leftElbow:     [0.28, 0.44],
      LM.rightElbow:    [0.70, 0.36],
      LM.leftHip:       [0.42, 0.60],
      LM.rightHip:      [0.58, 0.55],
      LM.leftKnee:      [0.40, 0.80],
      LM.rightKnee:     [0.60, 0.75],
    }),
  ),

  PoseDefinition(
    id: 'studio_08',
    label: 'Arms Above Head',
    category: SceneCategory.indoorStudio,
    targetPitchDeg: 0,
    targetRollDeg: 0,
    directionCue: 'Both arms raised, wrists crossed overhead, eyes up',
    landmarks: _lm({
      LM.nose:          [0.50, 0.16],
      LM.leftShoulder:  [0.38, 0.32],
      LM.rightShoulder: [0.62, 0.32],
      LM.leftElbow:     [0.34, 0.18],
      LM.rightElbow:    [0.66, 0.18],
      LM.leftWrist:     [0.46, 0.06],
      LM.rightWrist:    [0.54, 0.06],
      LM.leftHip:       [0.43, 0.62],
      LM.rightHip:      [0.57, 0.62],
    }),
  ),

  PoseDefinition(
    id: 'studio_09',
    label: 'Close-Up — Head Tilt',
    category: SceneCategory.indoorStudio,
    targetPitchDeg: 0,
    targetRollDeg: 0,
    directionCue: 'Frame head and shoulders only, slight head tilt to one side',
    landmarks: _lm({
      LM.nose:          [0.52, 0.20],
      LM.leftShoulder:  [0.28, 0.55],
      LM.rightShoulder: [0.72, 0.55],
      LM.leftEye:       [0.42, 0.14],
      LM.rightEye:      [0.58, 0.14],
    }),
  ),

  PoseDefinition(
    id: 'studio_10',
    label: 'Sitting — Chair Straddle',
    category: SceneCategory.indoorStudio,
    targetPitchDeg: 5,
    targetRollDeg: 0,
    directionCue: 'Straddle chair backwards, arms folded on chair back',
    landmarks: _lm({
      LM.nose:          [0.50, 0.12],
      LM.leftShoulder:  [0.38, 0.28],
      LM.rightShoulder: [0.62, 0.28],
      LM.leftElbow:     [0.34, 0.42],
      LM.rightElbow:    [0.66, 0.42],
      LM.leftWrist:     [0.42, 0.50],
      LM.rightWrist:    [0.58, 0.50],
      LM.leftHip:       [0.40, 0.60],
      LM.rightHip:      [0.60, 0.60],
      LM.leftKnee:      [0.34, 0.75],
      LM.rightKnee:     [0.66, 0.75],
    }),
  ),

  // ─────────────────────────────────────────────────────────
  //  MINIMAL / INDOOR  (10 poses)
  // ─────────────────────────────────────────────────────────
  PoseDefinition(
    id: 'minimal_01',
    label: 'Facing Window — Silhouette',
    category: SceneCategory.minimalIndoor,
    targetPitchDeg: 0,
    targetRollDeg: 0,
    directionCue: 'Subject faces window backlit, minimal exposure',
    landmarks: _lm({
      LM.nose:          [0.50, 0.09],
      LM.leftShoulder:  [0.38, 0.26],
      LM.rightShoulder: [0.62, 0.26],
      LM.leftHip:       [0.43, 0.58],
      LM.rightHip:      [0.57, 0.58],
      LM.leftAnkle:     [0.41, 0.95],
      LM.rightAnkle:    [0.59, 0.95],
    }),
  ),

  PoseDefinition(
    id: 'minimal_02',
    label: 'Negative Space — Corner',
    category: SceneCategory.minimalIndoor,
    targetPitchDeg: 3,
    targetRollDeg: 0,
    directionCue: 'Subject small in frame; vast negative space; rule of thirds',
    landmarks: _lm({
      LM.nose:          [0.78, 0.25],
      LM.leftShoulder:  [0.70, 0.35],
      LM.rightShoulder: [0.86, 0.35],
      LM.leftHip:       [0.72, 0.58],
      LM.rightHip:      [0.84, 0.58],
    }),
  ),

  PoseDefinition(
    id: 'minimal_03',
    label: 'Reading — Natural Light',
    category: SceneCategory.minimalIndoor,
    targetPitchDeg: 10,
    targetRollDeg: 0,
    directionCue: 'Seated, holding book/device, soft side-light from window',
    landmarks: _lm({
      LM.nose:          [0.50, 0.14],
      LM.leftShoulder:  [0.38, 0.29],
      LM.rightShoulder: [0.62, 0.29],
      LM.leftElbow:     [0.33, 0.44],
      LM.rightElbow:    [0.67, 0.44],
      LM.leftWrist:     [0.39, 0.57],
      LM.rightWrist:    [0.61, 0.57],
      LM.leftHip:       [0.42, 0.60],
      LM.rightHip:      [0.58, 0.60],
    }),
  ),

  PoseDefinition(
    id: 'minimal_04',
    label: 'Reflection — Mirror',
    category: SceneCategory.minimalIndoor,
    targetPitchDeg: 0,
    targetRollDeg: 0,
    directionCue: 'Shoot through mirror; include camera visible in reflection',
    landmarks: _lm({
      LM.nose:          [0.50, 0.09],
      LM.leftShoulder:  [0.38, 0.26],
      LM.rightShoulder: [0.62, 0.26],
      LM.leftHip:       [0.43, 0.57],
      LM.rightHip:      [0.57, 0.57],
    }),
  ),

  PoseDefinition(
    id: 'minimal_05',
    label: 'Lying Down — Morning',
    category: SceneCategory.minimalIndoor,
    targetPitchDeg: 80,
    targetRollDeg: 0,
    directionCue: 'Overhead looking down; subject in bed, arms above head',
    landmarks: _lm({
      LM.nose:          [0.50, 0.12],
      LM.leftShoulder:  [0.36, 0.26],
      LM.rightShoulder: [0.64, 0.26],
      LM.leftElbow:     [0.26, 0.18],
      LM.rightElbow:    [0.74, 0.18],
      LM.leftWrist:     [0.22, 0.08],
      LM.rightWrist:    [0.78, 0.08],
      LM.leftHip:       [0.42, 0.60],
      LM.rightHip:      [0.58, 0.60],
    }),
  ),

  PoseDefinition(
    id: 'minimal_06',
    label: 'One-Wall Lean',
    category: SceneCategory.minimalIndoor,
    targetPitchDeg: 0,
    targetRollDeg: 2,
    directionCue: 'Back against plain wall, arms loose at sides, direct gaze',
    landmarks: _lm({
      LM.nose:          [0.50, 0.08],
      LM.leftShoulder:  [0.38, 0.25],
      LM.rightShoulder: [0.62, 0.25],
      LM.leftElbow:     [0.32, 0.40],
      LM.rightElbow:    [0.68, 0.40],
      LM.leftWrist:     [0.32, 0.56],
      LM.rightWrist:    [0.68, 0.56],
      LM.leftHip:       [0.43, 0.57],
      LM.rightHip:      [0.57, 0.57],
    }),
  ),

  PoseDefinition(
    id: 'minimal_07',
    label: 'Shadow Self-Portrait',
    category: SceneCategory.minimalIndoor,
    targetPitchDeg: -5,
    targetRollDeg: -8,
    directionCue: 'Capture shadow on floor; camera tilted down at 45°',
    landmarks: _lm({
      LM.nose:          [0.50, 0.09],
      LM.leftShoulder:  [0.39, 0.25],
      LM.rightShoulder: [0.61, 0.25],
      LM.leftHip:       [0.43, 0.58],
      LM.rightHip:      [0.57, 0.58],
    }),
  ),

  PoseDefinition(
    id: 'minimal_08',
    label: 'Contemplative — Staircase',
    category: SceneCategory.minimalIndoor,
    targetPitchDeg: -8,
    targetRollDeg: 0,
    directionCue: 'Subject on stairs; low-angle shot showing ascending lines',
    landmarks: _lm({
      LM.nose:          [0.50, 0.08],
      LM.leftShoulder:  [0.39, 0.24],
      LM.rightShoulder: [0.61, 0.24],
      LM.leftHip:       [0.43, 0.55],
      LM.rightHip:      [0.57, 0.53],
      LM.leftKnee:      [0.41, 0.73],
      LM.rightKnee:     [0.59, 0.70],
    }),
  ),

  PoseDefinition(
    id: 'minimal_09',
    label: 'Hands Frame Face',
    category: SceneCategory.minimalIndoor,
    targetPitchDeg: 0,
    targetRollDeg: 0,
    directionCue: 'Close-up; both hands loosely frame the face',
    landmarks: _lm({
      LM.nose:          [0.50, 0.35],
      LM.leftShoulder:  [0.22, 0.72],
      LM.rightShoulder: [0.78, 0.72],
      LM.leftElbow:     [0.24, 0.54],
      LM.rightElbow:    [0.76, 0.54],
      LM.leftWrist:     [0.32, 0.38],
      LM.rightWrist:    [0.68, 0.38],
    }),
  ),

  PoseDefinition(
    id: 'minimal_10',
    label: 'Doorway Frame',
    category: SceneCategory.minimalIndoor,
    targetPitchDeg: 0,
    targetRollDeg: 0,
    directionCue: 'Subject centred in doorway; leading lines from frame',
    landmarks: _lm({
      LM.nose:          [0.50, 0.09],
      LM.leftShoulder:  [0.38, 0.26],
      LM.rightShoulder: [0.62, 0.26],
      LM.leftHip:       [0.43, 0.58],
      LM.rightHip:      [0.57, 0.58],
      LM.leftAnkle:     [0.41, 0.94],
      LM.rightAnkle:    [0.59, 0.94],
    }),
  ),

  // ─────────────────────────────────────────────────────────
  //  NATURE / GREENERY  (10 poses)
  // ─────────────────────────────────────────────────────────
  PoseDefinition(
    id: 'nature_01',
    label: 'Among the Trees',
    category: SceneCategory.natureGreenery,
    targetPitchDeg: 0,
    targetRollDeg: 0,
    directionCue: 'Standing between trees, arms slightly open, soft gaze',
    landmarks: _lm({
      LM.nose:          [0.50, 0.09],
      LM.leftShoulder:  [0.37, 0.26],
      LM.rightShoulder: [0.63, 0.26],
      LM.leftElbow:     [0.28, 0.41],
      LM.rightElbow:    [0.72, 0.41],
      LM.leftWrist:     [0.22, 0.56],
      LM.rightWrist:    [0.78, 0.56],
      LM.leftHip:       [0.43, 0.58],
      LM.rightHip:      [0.57, 0.58],
    }),
  ),

  PoseDefinition(
    id: 'nature_02',
    label: 'Meadow Spin',
    category: SceneCategory.natureGreenery,
    targetPitchDeg: -5,
    targetRollDeg: 0,
    directionCue: 'Subject spinning with arms out; motion blur on edges',
    landmarks: _lm({
      LM.nose:          [0.50, 0.09],
      LM.leftShoulder:  [0.30, 0.26],
      LM.rightShoulder: [0.70, 0.26],
      LM.leftElbow:     [0.18, 0.30],
      LM.rightElbow:    [0.82, 0.30],
      LM.leftWrist:     [0.08, 0.34],
      LM.rightWrist:    [0.92, 0.34],
      LM.leftHip:       [0.43, 0.58],
      LM.rightHip:      [0.57, 0.58],
    }),
  ),

  PoseDefinition(
    id: 'nature_03',
    label: 'Golden Hour Walk',
    category: SceneCategory.natureGreenery,
    targetPitchDeg: 0,
    targetRollDeg: 0,
    directionCue: 'Subject walks away; backlit by low sun; long shadow',
    landmarks: _lm({
      LM.nose:          [0.52, 0.09],
      LM.leftShoulder:  [0.40, 0.26],
      LM.rightShoulder: [0.62, 0.26],
      LM.leftHip:       [0.43, 0.58],
      LM.rightHip:      [0.59, 0.58],
      LM.leftKnee:      [0.40, 0.76],
      LM.rightKnee:     [0.61, 0.74],
    }),
  ),

  PoseDefinition(
    id: 'nature_04',
    label: 'Sitting on Rock',
    category: SceneCategory.natureGreenery,
    targetPitchDeg: 8,
    targetRollDeg: 0,
    directionCue: 'Perched on rock, knees up, looking towards horizon',
    landmarks: _lm({
      LM.nose:          [0.50, 0.13],
      LM.leftShoulder:  [0.38, 0.28],
      LM.rightShoulder: [0.62, 0.28],
      LM.leftHip:       [0.42, 0.55],
      LM.rightHip:      [0.58, 0.55],
      LM.leftKnee:      [0.36, 0.67],
      LM.rightKnee:     [0.64, 0.67],
      LM.leftAnkle:     [0.38, 0.80],
      LM.rightAnkle:    [0.62, 0.80],
    }),
  ),

  PoseDefinition(
    id: 'nature_05',
    label: 'Lying in Grass',
    category: SceneCategory.natureGreenery,
    targetPitchDeg: 85,
    targetRollDeg: 0,
    directionCue: 'Overhead; subject in lush grass, arms spread wide',
    landmarks: _lm({
      LM.nose:          [0.50, 0.10],
      LM.leftShoulder:  [0.35, 0.26],
      LM.rightShoulder: [0.65, 0.26],
      LM.leftElbow:     [0.20, 0.22],
      LM.rightElbow:    [0.80, 0.22],
      LM.leftWrist:     [0.08, 0.18],
      LM.rightWrist:    [0.92, 0.18],
      LM.leftHip:       [0.42, 0.62],
      LM.rightHip:      [0.58, 0.62],
    }),
  ),

  PoseDefinition(
    id: 'nature_06',
    label: 'Leaning Tree',
    category: SceneCategory.natureGreenery,
    targetPitchDeg: 0,
    targetRollDeg: -4,
    directionCue: 'One arm against tree trunk; casual lean; dappled light',
    landmarks: _lm({
      LM.nose:          [0.48, 0.09],
      LM.leftShoulder:  [0.36, 0.25],
      LM.rightShoulder: [0.62, 0.25],
      LM.leftElbow:     [0.28, 0.38],
      LM.rightElbow:    [0.68, 0.38],
      LM.leftWrist:     [0.22, 0.24],
      LM.rightWrist:    [0.70, 0.52],
      LM.leftHip:       [0.42, 0.57],
      LM.rightHip:      [0.58, 0.55],
    }),
  ),

  PoseDefinition(
    id: 'nature_07',
    label: 'Wading Water',
    category: SceneCategory.natureGreenery,
    targetPitchDeg: 5,
    targetRollDeg: 0,
    directionCue: 'Ankles in stream; arms out for balance; looking down',
    landmarks: _lm({
      LM.nose:          [0.50, 0.10],
      LM.leftShoulder:  [0.34, 0.26],
      LM.rightShoulder: [0.66, 0.26],
      LM.leftElbow:     [0.24, 0.38],
      LM.rightElbow:    [0.76, 0.38],
      LM.leftWrist:     [0.18, 0.46],
      LM.rightWrist:    [0.82, 0.46],
      LM.leftHip:       [0.42, 0.60],
      LM.rightHip:      [0.58, 0.60],
      LM.leftKnee:      [0.40, 0.78],
      LM.rightKnee:     [0.60, 0.78],
    }),
  ),

  PoseDefinition(
    id: 'nature_08',
    label: 'Reaching Up — Canopy',
    category: SceneCategory.natureGreenery,
    targetPitchDeg: -20,
    targetRollDeg: 0,
    directionCue: 'Camera shoots up through canopy; subject arms stretched high',
    landmarks: _lm({
      LM.nose:          [0.50, 0.40],
      LM.leftShoulder:  [0.36, 0.54],
      LM.rightShoulder: [0.64, 0.54],
      LM.leftElbow:     [0.30, 0.36],
      LM.rightElbow:    [0.70, 0.36],
      LM.leftWrist:     [0.26, 0.18],
      LM.rightWrist:    [0.74, 0.18],
      LM.leftHip:       [0.42, 0.74],
      LM.rightHip:      [0.58, 0.74],
    }),
  ),

  PoseDefinition(
    id: 'nature_09',
    label: 'Running — Side Profile',
    category: SceneCategory.natureGreenery,
    targetPitchDeg: 0,
    targetRollDeg: -5,
    directionCue: 'Subject runs L→R; camera panned to freeze motion',
    landmarks: _lm({
      LM.nose:          [0.62, 0.10],
      LM.leftShoulder:  [0.44, 0.27],
      LM.rightShoulder: [0.58, 0.26],
      LM.leftElbow:     [0.36, 0.42],
      LM.rightElbow:    [0.66, 0.37],
      LM.leftHip:       [0.46, 0.58],
      LM.rightHip:      [0.56, 0.57],
      LM.leftKnee:      [0.40, 0.74],
      LM.rightKnee:     [0.62, 0.70],
    }),
  ),

  PoseDefinition(
    id: 'nature_10',
    label: 'Fog Silhouette',
    category: SceneCategory.natureGreenery,
    targetPitchDeg: 0,
    targetRollDeg: 0,
    directionCue: 'Subject far from camera in foggy treeline; minimal detail',
    landmarks: _lm({
      LM.nose:          [0.50, 0.28],
      LM.leftShoulder:  [0.44, 0.36],
      LM.rightShoulder: [0.56, 0.36],
      LM.leftHip:       [0.46, 0.52],
      LM.rightHip:      [0.54, 0.52],
    }),
  ),

  // ─────────────────────────────────────────────────────────
  //  OPEN LANDSCAPE  (10 poses)
  // ─────────────────────────────────────────────────────────
  PoseDefinition(
    id: 'landscape_01',
    label: 'Horizon Stand',
    category: SceneCategory.openLandscape,
    targetPitchDeg: 0,
    targetRollDeg: 0,
    directionCue: 'Subject on horizon line at rule-of-thirds; tiny vs. sky',
    landmarks: _lm({
      LM.nose:          [0.50, 0.60],
      LM.leftShoulder:  [0.46, 0.66],
      LM.rightShoulder: [0.54, 0.66],
      LM.leftHip:       [0.47, 0.72],
      LM.rightHip:      [0.53, 0.72],
      LM.leftAnkle:     [0.47, 0.80],
      LM.rightAnkle:    [0.53, 0.80],
    }),
  ),

  PoseDefinition(
    id: 'landscape_02',
    label: 'Arms Out — Vista',
    category: SceneCategory.openLandscape,
    targetPitchDeg: -5,
    targetRollDeg: 0,
    directionCue: 'Arms outstretched like wings; vast sky background',
    landmarks: _lm({
      LM.nose:          [0.50, 0.09],
      LM.leftShoulder:  [0.28, 0.26],
      LM.rightShoulder: [0.72, 0.26],
      LM.leftElbow:     [0.14, 0.26],
      LM.rightElbow:    [0.86, 0.26],
      LM.leftWrist:     [0.04, 0.26],
      LM.rightWrist:    [0.96, 0.26],
      LM.leftHip:       [0.43, 0.58],
      LM.rightHip:      [0.57, 0.58],
    }),
  ),

  PoseDefinition(
    id: 'landscape_03',
    label: 'Cliffside Gaze',
    category: SceneCategory.openLandscape,
    targetPitchDeg: -10,
    targetRollDeg: 0,
    directionCue: 'Subject on edge looking out; low camera angle shows drop',
    landmarks: _lm({
      LM.nose:          [0.50, 0.08],
      LM.leftShoulder:  [0.38, 0.24],
      LM.rightShoulder: [0.62, 0.24],
      LM.leftHip:       [0.43, 0.55],
      LM.rightHip:      [0.57, 0.55],
      LM.leftKnee:      [0.41, 0.73],
      LM.rightKnee:     [0.59, 0.73],
    }),
  ),

  PoseDefinition(
    id: 'landscape_04',
    label: 'Desert Road Walk',
    category: SceneCategory.openLandscape,
    targetPitchDeg: 0,
    targetRollDeg: 0,
    directionCue: 'Walking along centre line; vanishing point recedes behind',
    landmarks: _lm({
      LM.nose:          [0.50, 0.10],
      LM.leftShoulder:  [0.40, 0.26],
      LM.rightShoulder: [0.60, 0.26],
      LM.leftHip:       [0.43, 0.58],
      LM.rightHip:      [0.57, 0.58],
      LM.leftKnee:      [0.40, 0.76],
      LM.rightKnee:     [0.60, 0.74],
    }),
  ),

  PoseDefinition(
    id: 'landscape_05',
    label: 'Sunrise Meditation',
    category: SceneCategory.openLandscape,
    targetPitchDeg: 5,
    targetRollDeg: 0,
    directionCue: 'Seated cross-legged; sunrise behind; arms resting on knees',
    landmarks: _lm({
      LM.nose:          [0.50, 0.15],
      LM.leftShoulder:  [0.38, 0.30],
      LM.rightShoulder: [0.62, 0.30],
      LM.leftElbow:     [0.32, 0.44],
      LM.rightElbow:    [0.68, 0.44],
      LM.leftWrist:     [0.38, 0.58],
      LM.rightWrist:    [0.62, 0.58],
      LM.leftHip:       [0.41, 0.60],
      LM.rightHip:      [0.59, 0.60],
      LM.leftKnee:      [0.32, 0.70],
      LM.rightKnee:     [0.68, 0.70],
    }),
  ),

  PoseDefinition(
    id: 'landscape_06',
    label: 'Storm Light Profile',
    category: SceneCategory.openLandscape,
    targetPitchDeg: 0,
    targetRollDeg: -8,
    directionCue: 'Strict profile; dramatic storm cloud background',
    landmarks: _lm({
      LM.nose:          [0.64, 0.09],
      LM.leftShoulder:  [0.44, 0.26],
      LM.rightShoulder: [0.58, 0.26],
      LM.leftHip:       [0.46, 0.57],
      LM.rightHip:      [0.56, 0.57],
    }),
  ),

  PoseDefinition(
    id: 'landscape_07',
    label: 'Kneeling — Plains',
    category: SceneCategory.openLandscape,
    targetPitchDeg: 3,
    targetRollDeg: 0,
    directionCue: 'Single knee down; elbow on raised knee; strong horizon',
    landmarks: _lm({
      LM.nose:          [0.50, 0.12],
      LM.leftShoulder:  [0.38, 0.28],
      LM.rightShoulder: [0.62, 0.28],
      LM.leftElbow:     [0.35, 0.43],
      LM.rightElbow:    [0.65, 0.40],
      LM.leftHip:       [0.42, 0.58],
      LM.rightHip:      [0.58, 0.55],
      LM.leftKnee:      [0.40, 0.73],
      LM.rightKnee:     [0.60, 0.65],
      LM.leftAnkle:     [0.38, 0.88],
    }),
  ),

  PoseDefinition(
    id: 'landscape_08',
    label: 'Long Exposure — Light Trail',
    category: SceneCategory.openLandscape,
    targetPitchDeg: 0,
    targetRollDeg: 0,
    directionCue: 'Subject fully still; 3-second exposure; city/sky light trails',
    landmarks: _lm({
      LM.nose:          [0.50, 0.09],
      LM.leftShoulder:  [0.38, 0.26],
      LM.rightShoulder: [0.62, 0.26],
      LM.leftHip:       [0.43, 0.57],
      LM.rightHip:      [0.57, 0.57],
      LM.leftAnkle:     [0.41, 0.94],
      LM.rightAnkle:    [0.59, 0.94],
    }),
  ),

  PoseDefinition(
    id: 'landscape_09',
    label: 'Hilltop Victory',
    category: SceneCategory.openLandscape,
    targetPitchDeg: -12,
    targetRollDeg: 0,
    directionCue: 'Shoot from below hilltop; subject arms raised in triumph',
    landmarks: _lm({
      LM.nose:          [0.50, 0.10],
      LM.leftShoulder:  [0.34, 0.26],
      LM.rightShoulder: [0.66, 0.26],
      LM.leftElbow:     [0.24, 0.14],
      LM.rightElbow:    [0.76, 0.14],
      LM.leftWrist:     [0.18, 0.04],
      LM.rightWrist:    [0.82, 0.04],
      LM.leftHip:       [0.43, 0.58],
      LM.rightHip:      [0.57, 0.58],
    }),
  ),

  PoseDefinition(
    id: 'landscape_10',
    label: 'Snow Field — Isolation',
    category: SceneCategory.openLandscape,
    targetPitchDeg: 0,
    targetRollDeg: 0,
    directionCue: 'Tiny figure in enormous white expanse; centered',
    landmarks: _lm({
      LM.nose:          [0.50, 0.48],
      LM.leftShoulder:  [0.47, 0.52],
      LM.rightShoulder: [0.53, 0.52],
      LM.leftHip:       [0.48, 0.58],
      LM.rightHip:      [0.52, 0.58],
    }),
  ),
];

/// Convenience accessor: return all poses for a given [SceneCategory].
List<PoseDefinition> posesForScene(SceneCategory cat) =>
    kPoseLibrary.where((p) => p.category == cat).toList();
