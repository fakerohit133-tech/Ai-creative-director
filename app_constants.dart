// lib/core/constants/app_constants.dart
// ─────────────────────────────────────────────────────────────────────────────
// Centralised numeric constants that drive timing, tolerance, and capability
// limits across the entire pipeline.  Changing a value here propagates to
// every module that imports this file — no magic numbers in business logic.
// ─────────────────────────────────────────────────────────────────────────────

// ignore_for_file: constant_identifier_names

/// Camera pipeline
const int    kCameraTargetFPS         = 30;
const int    kCameraResolutionWidth   = 1920;
const int    kCameraResolutionHeight  = 1080;

/// Frame budget: 1 000 ms / 30 fps ≈ 33 ms per frame.
/// Any stage of the pipeline that exceeds this budget is flagged in debug mode.
const int    kFrameBudgetMs           = 33;

/// On-device AI inference scheduling
const int    kSceneClassifierIntervalMs = 500;
const int    kPoseEstimatorIntervalMs   = 33;   // every frame
const int    kNoSubjectTimeoutMs        = 3000; // fallback → Composition Guide

/// Sensor fusion
const double kSensorFusionAlpha        = 0.98; // complementary filter weight
const double kAngleToleranceDeg        = 1.5;  // ±1.5° haptic window

/// Pose matching
const double kPoseAlignmentThreshold   = 0.85; // cosine similarity "aligned"
const double kPosePartialThreshold     = 0.55; // below → "adjusting"

/// Post-processing
const double kContrastBoost            = 1.15;
const double kSharpenRadius            = 1.2;
const double kSharpenAmount            = 0.35;
const double kDynamicRangeGamma        = 0.95;
const int    kJpegQuality              = 96;

/// Thermal mitigation: if on-device temp > threshold, reduce inference rate
const int    kThermalReducedIntervalMs = 100;

/// Wireframe overlay aesthetics
const double kWireframeBaseOpacity     = 0.55;
const double kWireframeAlignedOpacity  = 0.85;
const double kWireframeStrokeWidth     = 2.0;

/// Crosshair indicator
const double kCrosshairRingRadius      = 28.0;
const double kCrosshairDotRadius       = 4.5;

/// Haptic
const int    kHapticAlignDurationMs    = 60;
const int    kHapticShutterDurationMs  = 120;

/// Lighting threshold below which we switch to Composition Guide mode
const double kLowLightLuxThreshold     = 20.0;
