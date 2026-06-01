# AI Creative Director — Complete Technical Reference

> **Real-time on-device AI camera that guides the photographer to capture
> minimal, magazine-quality, ultra-HD portrait and environment-aware photography.**

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                          UI LAYER                                    │
│  CameraScreen  ←  SceneModeToggle  ←  AlignmentHUD                 │
│      ↑               ↑                    ↑                         │
│  PoseWireframeOverlay  AngleIndicator  CompositionGuideOverlay       │
│      ↑               ↑                    ↑                         │
│  SkeletonPainter  CrosshairPainter     PoseSelectorSheet            │
└──────────────────────────┬──────────────────────────────────────────┘
                           │  AIStateSnapshot stream
┌──────────────────────────▼──────────────────────────────────────────┐
│                     ORCHESTRATION LAYER                              │
│  AIEngineManager    SensorFusionController    OrientationValidator   │
│       ↑                    ↑                        ↑               │
│  (combines AI outputs)  (complementary filter)  (±1.5° logic)       │
└──────┬─────────────────────┬───────────────────────┬────────────────┘
       │                     │                       │
┌──────▼──────┐   ┌──────────▼──────┐   ┌───────────▼────────────┐
│  MODULE A   │   │   MODULE B      │   │      MODULE C          │
│   Camera    │   │   Edge AI       │   │  Sensor Fusion         │
│  Pipeline   │   │   Engine        │   │  Kinematics            │
│             │   │                 │   │                        │
│ • 30 FPS    │   │ • MediaPipe     │   │ • Accelerometer        │
│   preview   │   │   BlazePose     │   │ • Gyroscope            │
│ • Raw YUV   │   │ • Scene         │   │ • Complementary        │
│   frames    │   │   Classifier    │   │   filter (α=0.98)      │
│ • Focus /   │   │ • Procrustes    │   │ • Pitch / Roll / Yaw   │
│   Exposure  │   │   Analysis      │   │   streaming            │
│   lock      │   │ • 50-pose DB    │   │                        │
└──────┬──────┘   └────────┬────────┘   └────────────────────────┘
       │                   │
┌──────▼───────────────────▼─────────────────────────────────────────┐
│                    POST-PROCESSING (§4)                              │
│  1. Gamma correction    γ=0.95  (HDR dynamic range compression)     │
│  2. Local contrast      ×1.15   (CLAHE-inspired luminance stretch)  │
│  3. Unsharp mask        r=1.2 a=0.35 (detail / edge sharpening)    │
│  4. Saturation boost    ×1.10   (magazine chroma lift)              │
│                                                                      │
│  ⚠  STRICT GUARDRAIL: No face-warping, slimming, or beauty filters  │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Module Breakdown

### Module A — Live Camera Pipeline (`modules/camera/`)

| Feature | Implementation |
|---|---|
| Preview FPS | 30+ at `ResolutionPreset.veryHigh` (1080p) |
| Frame format | `YUV420` (Android) / `BGRA8888` (iOS) for GPU-native access |
| Focus lock | Tap-to-lock via `setFocusMode(FocusMode.locked)` + `setFocusPoint` |
| Exposure lock | Tap-to-lock via `setExposureMode(ExposureMode.locked)` |
| EV compensation | `setExposureOffset` clamped to device min/max range |
| Lux estimation | Y-plane mean brightness → mapped to approximate lux [0–5000] |
| Raw capture | `takePicture()` → JPEG path; frame stream paused during capture |

### Module B — Edge AI Engine (`modules/ai_engine/`)

#### Pose Estimation
- **Model**: Google ML Kit `PoseDetector` (MediaPipe BlazePose Accurate)
- **Mode**: `PoseDetectionMode.stream` — continuous video-optimised pipeline
- **Rate**: Every frame (33 ms); drops frames if inference exceeds budget
- **Fallback**: After 3 s without a detected subject → `inFallbackMode = true`
- **Output**: 17-landmark `LivePoseSnapshot` with per-joint confidence scores

#### Scene Classification
- **Model**: Google ML Kit `ImageLabeler` (MobileNet-based, confidence ≥ 0.4)
- **Rate**: Every 500 ms (`kSceneClassifierIntervalMs`)
- **Mapping**: 75 weighted keywords → 5 scene buckets via dot-product scoring
- **Auto-suggest**: When scene confidence > 0.65, automatically selects a matching pose

#### Pose Matching — Procrustes Analysis
```
Input:  live 17×[x,y]  +  reference 17×[x,y]
Steps:
  1. Translate centroids to origin
  2. Normalise to unit scale
  3. θ = atan2( Σ(aᵢ × bᵢ),  Σ(aᵢ · bᵢ) )   ← optimal rotation
  4. Rotate live landmarks by θ
  5. similarity = exp(-30 × mean_sq_dist)      ← [0,1]
```

#### Pose Library
- 50 reference poses across 5 scene categories
- Each pose: label, scene category, target pitch/roll, direction cue, 17 landmarks
- Vector index pre-computed at startup for O(n) similarity queries

### Module C — Sensor Fusion (`modules/sensor/`)

**Complementary filter** blending accelerometer (long-term stable) and gyroscope (short-term smooth):

```
pitch_fused = α × (pitch_fused + gy × dt × 180/π) + (1 − α) × accel_pitch
roll_fused  = α × (roll_fused  + gx × dt × 180/π) + (1 − α) × accel_roll

α = 0.98  (kSensorFusionAlpha)
```

**Angle Evaluation Logic** (§3):
```
|currentPitch - targetPitch| ≤ 1.5° AND |currentRoll - targetRoll| ≤ 1.5°
  → ALIGNED: haptic double-tap + green crosshair + "HOLD STEADY"
currentPitch > targetPitch + 1.5°
  → downward arrow indicator
currentPitch < targetPitch - 1.5°
  → upward arrow indicator
```

---

## Project Structure

```
ai_creative_director/
├── lib/
│   ├── main.dart                          # Entry point + hardware init
│   ├── app.dart                           # MaterialApp root
│   ├── core/
│   │   ├── constants/
│   │   │   ├── app_constants.dart         # All numeric constants
│   │   │   └── pose_library.dart          # 50 reference poses
│   │   ├── models/
│   │   │   ├── pose_model.dart            # PoseLandmark, PoseDefinition, etc.
│   │   │   ├── scene_classification.dart  # SceneCategory enum + result
│   │   │   └── sensor_state.dart          # DeviceOrientation, session state
│   │   └── utils/
│   │       ├── math_utils.dart            # Vector helpers, centroid, normalise
│   │       └── procrustes_analysis.dart   # GPA + fast cosine path
│   ├── modules/
│   │   ├── camera/
│   │   │   └── camera_controller_wrapper.dart  # Preview, focus, capture, lux
│   │   ├── ai_engine/
│   │   │   ├── pose_estimator.dart        # ML Kit BlazePose wrapper
│   │   │   ├── scene_classifier.dart      # ML Kit image labeler + keyword map
│   │   │   └── ai_engine_manager.dart     # Fan-out coordinator + thermal guard
│   │   ├── sensor/
│   │   │   ├── sensor_fusion_controller.dart  # Complementary filter
│   │   │   └── orientation_validator.dart     # ±1.5° logic + haptic trigger
│   │   └── post_processing/
│   │       └── image_processor.dart       # Gamma, CLAHE, USM, saturation
│   ├── ui/
│   │   ├── screens/
│   │   │   ├── camera_screen.dart         # Main orchestrating screen
│   │   │   └── splash_screen.dart         # Animated boot screen
│   │   ├── widgets/
│   │   │   ├── pose_wireframe_overlay.dart  # Skeleton overlay widget
│   │   │   ├── angle_indicator.dart         # Crosshair + HOLD STEADY
│   │   │   ├── scene_mode_toggle.dart       # Portrait / Environment pill
│   │   │   ├── alignment_hud.dart           # Score bar + scene chip
│   │   │   ├── shutter_button.dart          # Animated shutter
│   │   │   ├── pose_selector_sheet.dart     # Bottom sheet pose browser
│   │   │   └── composition_guide_overlay.dart # Rule-of-thirds fallback
│   │   └── painters/
│   │       ├── skeleton_painter.dart      # Reference + live wireframe
│   │       └── crosshair_painter.dart     # Ring-dot-arc angle indicator
│   └── services/
│       ├── haptic_service.dart            # Named haptic patterns
│       └── pose_database_service.dart     # In-memory vector index
├── android/app/src/main/
│   └── AndroidManifest.xml               # Camera, vibration, sensor permissions
├── ios/Runner/
│   └── Info.plist                        # Usage descriptions + portrait lock
└── pubspec.yaml                          # Dependencies
```

---

## Performance Targets & Mitigations

| Target | Strategy |
|---|---|
| ≤ 33 ms frame-to-UI | Frame throttle gate in `CameraControllerWrapper` |
| No CPU thermal throttling | AI inference via ML Kit GPU/NNAPI delegate; thermal detection reduces inference rate after 10 slow frames |
| Sensor at camera FPS | Complementary filter runs async; sensor updates published at max platform rate |
| No queue build-up | `isRunning` guard prevents concurrent inference; frames dropped rather than buffered |

---

## Setup & Build

### Prerequisites
```bash
flutter --version   # ≥ 3.22.0 required
```

### Install dependencies
```bash
cd ai_creative_director
flutter pub get
```

### Run on device (physical device required — camera unavailable on simulators)
```bash
# Android
flutter run --release -d <android-device-id>

# iOS
flutter run --release -d <ios-device-id>
```

### Android — enable GPU delegate
In `android/app/build.gradle`, ensure `minSdkVersion 21` and `targetSdkVersion 34`.

### iOS — enable Core ML delegate
ML Kit automatically selects Core ML when available on A12+ chips.

---

## Customisation

### Adding poses
Append a `PoseDefinition` to `kPoseLibrary` in `pose_library.dart`:
```dart
PoseDefinition(
  id: 'custom_01',
  label: 'My Custom Pose',
  category: SceneCategory.urbanStreet,
  targetPitchDeg: 0,
  targetRollDeg: 0,
  directionCue: 'Stand with arms slightly away from body',
  landmarks: _lm({ LM.nose: [0.50, 0.08], ... }),
),
```

### Tuning alignment thresholds
Edit `app_constants.dart`:
```dart
const double kPoseAlignmentThreshold = 0.85; // raise for stricter "aligned" state
const double kAngleToleranceDeg      = 1.5;  // degrees — lower = tighter haptic window
```

### Post-processing intensity
```dart
const double kContrastBoost   = 1.15;  // 1.0 = off, 1.3 = strong
const double kSharpenAmount   = 0.35;  // 0.0 = off, 0.6 = aggressive
const double kSharpenRadius   = 1.2;   // pixels, affects edge width
```

---

## Guardrails — What This Pipeline Does NOT Do

Per §4 of the specification, the post-processing pipeline strictly avoids:

- ❌ Face landmark detection for warping
- ❌ Skin-region segmentation or smoothing
- ❌ Body proportion modification (slimming, elongation)
- ❌ Synthetic "beauty" or "skin-softening" filters
- ❌ Any per-pixel discrimination based on detected content type

All tonal adjustments (gamma, contrast, sharpening, saturation) are applied
**globally and identically** to every pixel, treating the image as a pure
luminance/chroma signal with no semantic content awareness.

---

## Licence

MIT — see `LICENSE` for details.
