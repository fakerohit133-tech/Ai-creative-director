// lib/ui/screens/camera_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// Root camera screen.  Wires together:
//   • CameraControllerWrapper   → live preview + raw frame stream
//   • AIEngineManager           → pose estimation + scene classification
//   • SensorFusionController    → device orientation
//   • OrientationValidator      → angle evaluation + haptic triggers
//   • ImageProcessor            → post-capture enhancement pipeline
//   • All UI overlay widgets
//
// State model: single [_ScreenState] class updated via setState; kept simple
// intentionally so every field has a clear source of truth.  A production
// app would migrate this to a Riverpod/Bloc layer, but separation of concerns
// is maintained via the module boundaries above.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/constants/app_constants.dart';
import '../../core/models/pose_model.dart';
import '../../core/models/scene_classification.dart';
import '../../core/models/sensor_state.dart';
import '../../modules/ai_engine/ai_engine_manager.dart';
import '../../modules/camera/camera_controller_wrapper.dart';
import '../../modules/post_processing/image_processor.dart';
import '../../modules/sensor/orientation_validator.dart';
import '../../modules/sensor/sensor_fusion_controller.dart';
import '../../services/haptic_service.dart';
import '../../services/pose_database_service.dart';
import '../widgets/alignment_hud.dart';
import '../widgets/angle_indicator.dart';
import '../widgets/composition_guide_overlay.dart';
import '../widgets/pose_selector_sheet.dart';
import '../widgets/pose_wireframe_overlay.dart';
import '../widgets/scene_mode_toggle.dart';
import '../widgets/shutter_button.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {

  // ── Services & Modules ─────────────────────────────────────────────────────
  final _camera          = CameraControllerWrapper();
  final _aiEngine        = AIEngineManager();
  final _sensor          = SensorFusionController();
  final _haptic          = HapticService();
  final _poseDB          = PoseDatabaseService();
  final _imageProcessor  = ImageProcessor();
  late final OrientationValidator _orientationValidator;

  // ── Subscriptions ──────────────────────────────────────────────────────────
  StreamSubscription<AIStateSnapshot>?   _aiSub;
  StreamSubscription<DeviceOrientation>? _sensorSub;

  // ── Mutable UI State ───────────────────────────────────────────────────────
  bool              _initialised       = false;
  String?           _initError;
  bool              _isCapturing       = false;
  String?           _lastCapturePath;
  ShootingMode      _shootingMode      = ShootingMode.humanPortrait;
  bool              _focusLocked       = false;
  bool              _exposureLocked    = false;

  // AI state
  AIStateSnapshot?  _aiSnapshot;

  // Sensor state
  DeviceOrientation _orientation       = DeviceOrientation.level;
  OrientationValidationResult _orientResult = OrientationValidationResult(
    pitchError: 0, rollError: 0, isAligned: false,
    verticalDirection: TiltDirection.aligned,
    horizontalDirection: TiltDirection.aligned,
  );
  bool _holdSteady = false;

  // Focus/exposure tap indicator
  Offset? _focusTapPosition;
  Timer?  _focusTapTimer;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _boot();
  }

  Future<void> _boot() async {
    try {
      // Initialise services serially so we can report first meaningful error.
      await _haptic.init();
      _poseDB.initialise();

      _orientationValidator = OrientationValidator(hapticService: _haptic);

      await _camera.initialise();
      await _camera.startFrameStream();

      _aiEngine.initialise(_shootingMode);
      final sensorOrientation =
          _camera.controller?.description.sensorOrientation ?? 90;
      _aiEngine.attachFrameStream(_camera.frameStream, sensorOrientation);

      _sensor.start();

      // Wire subscriptions
      _aiSub = _aiEngine.aiStateStream.listen(_onAISnapshot);
      _sensorSub = _sensor.orientationStream.listen(_onOrientation);

      if (mounted) setState(() => _initialised = true);
    } catch (e) {
      if (mounted) setState(() => _initError = e.toString());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (!_initialised) return;
    if (state == AppLifecycleState.inactive) {
      _camera.stopFrameStream();
      _sensor.stop();
    } else if (state == AppLifecycleState.resumed) {
      _sensor.resetIntegration();
      _sensor.start();
      _camera.startFrameStream();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _aiSub?.cancel();
    _sensorSub?.cancel();
    _aiEngine.dispose();
    _camera.dispose();
    _sensor.dispose();
    _haptic.dispose();
    _focusTapTimer?.cancel();
    super.dispose();
  }

  // ── Stream Handlers ────────────────────────────────────────────────────────

  void _onAISnapshot(AIStateSnapshot snap) {
    if (!mounted) return;
    setState(() => _aiSnapshot = snap);
  }

  void _onOrientation(DeviceOrientation orientation) {
    if (!mounted) return;
    final activePose = _aiSnapshot?.activePose;
    if (activePose == null) {
      setState(() => _orientation = orientation);
      return;
    }

    final result = _orientationValidator.validate(
      current: orientation,
      targetPitch: activePose.targetPitchDeg,
      targetRoll: activePose.targetRollDeg,
    );

    setState(() {
      _orientation  = orientation;
      _orientResult = result;
      _holdSteady   = _orientationValidator.holdSteadyActive;
    });
  }

  // ── Shutter ────────────────────────────────────────────────────────────────

  Future<void> _onShutter() async {
    if (_isCapturing) return;
    setState(() => _isCapturing = true);
    await _haptic.shutterFeedback();

    try {
      final file = await _camera.captureStill();
      if (file == null) return;

      // Build output path
      final dir   = await getApplicationDocumentsDirectory();
      final ts    = DateTime.now().millisecondsSinceEpoch;
      final dest  = '${dir.path}/acd_$ts.jpg';

      final success = await _imageProcessor.processCapture(
        sourcePath: file.path,
        destPath:   dest,
      );

      if (mounted) {
        setState(() => _lastCapturePath = success ? dest : file.path);
        _showCapturePreview(success ? dest : file.path);
      }
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  void _showCapturePreview(String path) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.85),
      builder: (_) => _CapturePreviewDialog(imagePath: path),
    );
  }

  // ── Focus / Exposure Tap ───────────────────────────────────────────────────

  void _onViewfinderTap(TapDownDetails details, BoxConstraints constraints) {
    final dx = details.localPosition.dx / constraints.maxWidth;
    final dy = details.localPosition.dy / constraints.maxHeight;
    final point = Offset(dx.clamp(0.05, 0.95), dy.clamp(0.05, 0.95));

    _camera.lockFocusAt(point);
    _camera.lockExposureAt(point);

    setState(() {
      _focusLocked     = true;
      _exposureLocked  = true;
      _focusTapPosition = details.localPosition;
    });

    _focusTapTimer?.cancel();
    _focusTapTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _focusTapPosition = null);
    });
  }

  void _onFocusDoubleTap() {
    _camera.unlockFocus();
    _camera.unlockExposure();
    setState(() {
      _focusLocked    = false;
      _exposureLocked = false;
      _focusTapPosition = null;
    });
  }

  // ── Pose / Mode ────────────────────────────────────────────────────────────

  void _onModeChanged(ShootingMode mode) {
    setState(() => _shootingMode = mode);
    _aiEngine.initialise(mode);
  }

  void _onPoseSelected(PoseDefinition pose) {
    _aiEngine.setActivePose(pose);
    _orientationValidator.reset();
  }

  void _openPoseSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => PoseSelectorSheet(
        activePose:   _aiSnapshot?.activePose,
        currentScene: _aiSnapshot?.scene.category ?? SceneCategory.minimalIndoor,
        onSelect:     _onPoseSelected,
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_initError != null) return _ErrorScreen(error: _initError!);
    if (!_initialised)      return _LoadingScreen();

    final ai        = _aiSnapshot;
    final alignment = ai?.alignment ?? PoseAlignmentResult.empty;
    final scene     = ai?.scene ?? SceneClassificationResult.defaultResult();
    final inFallback = ai?.inFallbackMode ?? false;
    final isLowLight = (_camera.lastLux) < kLowLightLuxThreshold;
    final showComposition = inFallback || isLowLight;
    final showWireframe   = !showComposition &&
        _shootingMode == ShootingMode.humanPortrait;

    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (_, constraints) {
          return GestureDetector(
            onTapDown:       (d) => _onViewfinderTap(d, constraints),
            onDoubleTap:     _onFocusDoubleTap,
            child: Stack(
              fit: StackFit.expand,
              children: [

                // ① Live camera preview
                _CameraPreview(controller: _camera.controller!),

                // ② Rule-of-thirds / Composition guide (fallback mode)
                CompositionGuideOverlay(
                  visible: showComposition,
                  isLowLight: isLowLight,
                ),

                // ③ Skeleton wireframe overlay
                if (showWireframe && ai?.activePose != null)
                  PoseWireframeOverlay(
                    referenceLandmarks: ai!.activePose!.landmarks,
                    liveLandmarks:      ai.livePose?.landmarks,
                    perLandmarkError:   alignment.perLandmarkError,
                    alignmentScore:     alignment.similarity,
                    visible:            ai.subjectDetected || true,
                  ),

                // ④ Focus tap indicator
                if (_focusTapPosition != null)
                  Positioned(
                    left: _focusTapPosition!.dx - 28,
                    top:  _focusTapPosition!.dy - 28,
                    child: const _FocusIndicator(),
                  ),

                // ── Top bar ──────────────────────────────────────────────────
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Scene mode toggle
                        SceneModeToggle(
                          current: _shootingMode,
                          onChanged: _onModeChanged,
                        ),
                        const Spacer(),
                        // Alignment HUD
                        AlignmentHUD(
                          alignment:      alignment,
                          scene:          scene,
                          poseLabel:      ai?.activePose?.label,
                          inFallbackMode: inFallback,
                          subjectDetected: ai?.subjectDetected ?? false,
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Direction cue (pose label) ───────────────────────────────
                if (ai?.activePose != null && !inFallback)
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 100,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: _DirectionCueChip(
                        cue: ai!.activePose!.directionCue,
                      ),
                    ),
                  ),

                // ── Bottom controls ──────────────────────────────────────────
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: _BottomControlBar(
                    onShutter:      _onShutter,
                    onPoseSelector: _openPoseSelector,
                    isCapturing:    _isCapturing,
                    isAligned:      _orientResult.isAligned,
                    lastCapturePath: _lastCapturePath,
                    orientResult:   _orientResult,
                    holdSteady:     _holdSteady,
                  ),
                ),

                // ── Lock indicators ──────────────────────────────────────────
                if (_focusLocked || _exposureLocked)
                  Positioned(
                    bottom: 170,
                    right: 20,
                    child: _LockChip(
                      focus: _focusLocked,
                      exposure: _exposureLocked,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _CameraPreview extends StatelessWidget {
  final CameraController controller;
  const _CameraPreview({required this.controller});

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width:  controller.value.previewSize?.height ?? 1920,
          height: controller.value.previewSize?.width  ?? 1080,
          child: CameraPreview(controller),
        ),
      ),
    );
  }
}

class _DirectionCueChip extends StatelessWidget {
  final String cue;
  const _DirectionCueChip({required this.cue});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 40),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.35),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.12), width: 0.7),
      ),
      child: Text(
        cue,
        textAlign: TextAlign.center,
        style: GoogleFonts.spaceMono(
          fontSize: 9.5,
          color: Colors.white.withOpacity(0.7),
          letterSpacing: 0.3,
        ),
      ),
    )
    .animate()
    .fadeIn(duration: 500.ms);
  }
}

class _BottomControlBar extends StatelessWidget {
  final VoidCallback    onShutter;
  final VoidCallback    onPoseSelector;
  final bool            isCapturing;
  final bool            isAligned;
  final String?         lastCapturePath;
  final OrientationValidationResult orientResult;
  final bool            holdSteady;

  const _BottomControlBar({
    required this.onShutter,
    required this.onPoseSelector,
    required this.isCapturing,
    required this.isAligned,
    required this.orientResult,
    required this.holdSteady,
    this.lastCapturePath,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160 + MediaQuery.of(context).padding.bottom,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end:   Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withOpacity(0.65),
          ],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Angle indicator
            const SizedBox(height: 4),
            AngleIndicator(result: orientResult, holdSteady: holdSteady),
            const SizedBox(height: 6),

            // Main control row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Last capture thumbnail
                  _ThumbnailButton(path: lastCapturePath),

                  // Shutter
                  ShutterButton(
                    onPressed:   onShutter,
                    isCapturing: isCapturing,
                    isAligned:   isAligned,
                  ),

                  // Pose selector
                  _PoseSelectorButton(onTap: onPoseSelector),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThumbnailButton extends StatelessWidget {
  final String? path;
  const _ThumbnailButton({this.path});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: path != null
          ? () => showDialog(
                context: context,
                barrierColor: Colors.black.withOpacity(0.9),
                builder: (_) => _CapturePreviewDialog(imagePath: path!),
              )
          : null,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.white.withOpacity(0.25),
            width: 0.8,
          ),
          color: Colors.white.withOpacity(0.05),
          image: path != null
              ? DecorationImage(
                  image: FileImage(File(path!)),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: path == null
            ? Icon(Icons.photo_library_outlined,
                size: 20, color: Colors.white.withOpacity(0.35))
            : null,
      ),
    );
  }
}

class _PoseSelectorButton extends StatelessWidget {
  final VoidCallback onTap;
  const _PoseSelectorButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.10),
          border: Border.all(
            color: Colors.white.withOpacity(0.25),
            width: 0.8,
          ),
        ),
        child: const Icon(Icons.accessibility_new_rounded,
            size: 22, color: Colors.white),
      ),
    );
  }
}

class _FocusIndicator extends StatelessWidget {
  const _FocusIndicator();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 56,
      child: CustomPaint(
        painter: _FocusBoxPainter(),
      ),
    )
    .animate()
    .scale(
      begin: const Offset(1.4, 1.4),
      end:   const Offset(1.0, 1.0),
      duration: 250.ms,
      curve: Curves.easeOut,
    )
    .fadeIn(duration: 150.ms);
  }
}

class _FocusBoxPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const len = 10.0;
    const thick = 1.4;
    final paint = Paint()
      ..color = const Color(0xFFFFCC44).withOpacity(0.9)
      ..strokeWidth = thick
      ..strokeCap = StrokeCap.square
      ..style = PaintingStyle.stroke;

    final corners = [
      [Offset(0, len), Offset.zero, Offset(len, 0)],
      [Offset(size.width - len, 0), Offset(size.width, 0), Offset(size.width, len)],
      [Offset(size.width, size.height - len), Offset(size.width, size.height),
          Offset(size.width - len, size.height)],
      [Offset(len, size.height), Offset(0, size.height), Offset(0, size.height - len)],
    ];

    for (final c in corners) {
      final path = Path()
        ..moveTo(c[0].dx, c[0].dy)
        ..lineTo(c[1].dx, c[1].dy)
        ..lineTo(c[2].dx, c[2].dy);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

class _LockChip extends StatelessWidget {
  final bool focus;
  final bool exposure;
  const _LockChip({required this.focus, required this.exposure});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFFFCC44).withOpacity(0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: const Color(0xFFFFCC44).withOpacity(0.5), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lock_outline_rounded,
              size: 11, color: Color(0xFFFFCC44)),
          const SizedBox(width: 4),
          Text(
            [if (focus) 'AF', if (exposure) 'AE'].join('/'),
            style: GoogleFonts.spaceMono(
              fontSize: 8.5,
              color: const Color(0xFFFFCC44),
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Capture preview dialog ──────────────────────────────────────────────────

class _CapturePreviewDialog extends StatelessWidget {
  final String imagePath;
  const _CapturePreviewDialog({required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(File(imagePath), fit: BoxFit.contain),
          ),
          Positioned(
            top: 8, right: 8,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 18),
              ),
            ),
          ),
        ],
      ),
    )
    .animate()
    .scale(begin: const Offset(0.92, 0.92), end: const Offset(1, 1),
        duration: 220.ms, curve: Curves.easeOut)
    .fadeIn(duration: 180.ms);
  }
}

// ── Loading / Error screens ─────────────────────────────────────────────────

class _LoadingScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 28, height: 28,
              child: CircularProgressIndicator(
                color: Color(0xFF4DFFC0), strokeWidth: 1.5,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'INITIALISING PIPELINE',
              style: GoogleFonts.spaceMono(
                fontSize: 10, color: Colors.white.withOpacity(0.5),
                letterSpacing: 2.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  final String error;
  const _ErrorScreen({required this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.camera_alt_outlined,
                  color: Color(0xFFFF4D6A), size: 36),
              const SizedBox(height: 16),
              Text(
                'CAMERA UNAVAILABLE',
                style: GoogleFonts.spaceMono(
                  fontSize: 11, color: Colors.white,
                  letterSpacing: 2.5, fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                error,
                textAlign: TextAlign.center,
                style: GoogleFonts.spaceMono(
                  fontSize: 9, color: Colors.white.withOpacity(0.4),
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
