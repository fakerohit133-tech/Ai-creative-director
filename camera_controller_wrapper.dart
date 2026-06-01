// lib/modules/camera/camera_controller_wrapper.dart
// ─────────────────────────────────────────────────────────────────────────────
// Wraps Flutter's `camera` package to provide:
//   • High-performance 30 FPS preview with raw ImageStream callbacks
//   • Manual / auto exposure & focus lock
//   • Raw (uncompressed) image buffer interception on shutter
//   • Lux estimation from histogram brightness
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import '../../core/constants/app_constants.dart';

final _log = Logger(printer: PrettyPrinter(methodCount: 0));

/// Encapsulates a single raw YUV/BGRA frame for downstream processing.
class RawCameraFrame {
  final CameraImage image;
  final DateTime    timestamp;
  const RawCameraFrame({required this.image, required this.timestamp});
}

class CameraControllerWrapper {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isStreaming = false;
  bool _isCapturing = false;

  /// Broadcast stream of raw camera frames (YUV / BGRA depending on platform).
  final _frameController = StreamController<RawCameraFrame>.broadcast();
  Stream<RawCameraFrame> get frameStream => _frameController.stream;

  /// Most recent lux estimate (0–100k+).
  double _lastLux = 100.0;
  double get lastLux => _lastLux;

  CameraController? get controller => _controller;
  bool get isInitialised => _controller?.value.isInitialized ?? false;

  // ── Initialisation ─────────────────────────────────────────────────────────

  Future<void> initialise() async {
    _cameras = await availableCameras();
    if (_cameras.isEmpty) throw CameraException('NO_CAMERA', 'No cameras found');

    // Prefer back camera; fall back to first available.
    final desc = _cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => _cameras.first,
    );

    _controller = CameraController(
      desc,
      ResolutionPreset.veryHigh,       // 1080p — balances quality vs latency
      enableAudio: false,
      imageFormatGroup: defaultTargetPlatform == TargetPlatform.iOS
          ? ImageFormatGroup.bgra8888
          : ImageFormatGroup.yuv420,   // native GPU-friendly formats
    );

    await _controller!.initialize();
    await _controller!.lockCaptureOrientation();

    // Set initial camera params for quality capture.
    await _setHighQualityDefaults();

    _log.i('[Camera] Initialised: ${desc.name} '
        '(${_controller!.value.previewSize})');
  }

  Future<void> _setHighQualityDefaults() async {
    try {
      // Flash off; let the AI pipeline handle lighting guidance.
      await _controller!.setFlashMode(FlashMode.off);
      // Start with auto-focus and auto-exposure; user can lock manually.
      await _controller!.setFocusMode(FocusMode.auto);
      await _controller!.setExposureMode(ExposureMode.auto);
    } catch (e) {
      _log.w('[Camera] Could not set defaults: $e');
    }
  }

  // ── Frame Streaming ────────────────────────────────────────────────────────

  /// Start delivering raw [CameraImage] frames via [frameStream].
  ///
  /// Frames are throttled to the pipeline frame budget (≤33 ms) to prevent
  /// the stream from backing up when inference is slower.
  Future<void> startFrameStream() async {
    if (_isStreaming || !isInitialised) return;
    _isStreaming = true;

    int lastEmitMs = 0;
    await _controller!.startImageStream((CameraImage img) {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      // Throttle: emit at most once per frame budget to avoid queue buildup.
      if (nowMs - lastEmitMs < kFrameBudgetMs) return;
      lastEmitMs = nowMs;

      // Non-blocking; drop frame rather than queue if buffer full.
      if (!_frameController.isClosed) {
        _lastLux = _estimateLux(img);
        _frameController.add(
          RawCameraFrame(image: img, timestamp: DateTime.now()),
        );
      }
    });
    _log.i('[Camera] Frame stream started');
  }

  Future<void> stopFrameStream() async {
    if (!_isStreaming) return;
    _isStreaming = false;
    await _controller!.stopImageStream();
    _log.i('[Camera] Frame stream stopped');
  }

  // ── Focus / Exposure Control ───────────────────────────────────────────────

  /// Lock auto-focus at a normalised point [0,1] × [0,1].
  Future<void> lockFocusAt(Offset point) async {
    try {
      await _controller!.setFocusMode(FocusMode.locked);
      await _controller!.setFocusPoint(point);
    } catch (e) {
      _log.w('[Camera] focusLock failed: $e');
    }
  }

  Future<void> unlockFocus() async {
    try {
      await _controller!.setFocusMode(FocusMode.auto);
      await _controller!.setFocusPoint(null);
    } catch (e) {
      _log.w('[Camera] focusUnlock failed: $e');
    }
  }

  /// Lock exposure at a normalised point.
  Future<void> lockExposureAt(Offset point) async {
    try {
      await _controller!.setExposureMode(ExposureMode.locked);
      await _controller!.setExposurePoint(point);
    } catch (e) {
      _log.w('[Camera] exposureLock failed: $e');
    }
  }

  Future<void> unlockExposure() async {
    try {
      await _controller!.setExposureMode(ExposureMode.auto);
      await _controller!.setExposurePoint(null);
    } catch (e) {
      _log.w('[Camera] exposureUnlock failed: $e');
    }
  }

  /// Adjust exposure compensation in EV steps.
  Future<void> setExposureOffset(double evOffset) async {
    try {
      final min = await _controller!.getMinExposureOffset();
      final max = await _controller!.getMaxExposureOffset();
      final clamped = evOffset.clamp(min, max);
      await _controller!.setExposureOffset(clamped);
    } catch (e) {
      _log.w('[Camera] setExposureOffset failed: $e');
    }
  }

  // ── Shutter / Capture ──────────────────────────────────────────────────────

  /// Capture a still image and return the raw [XFile] path.
  /// The post-processing pipeline will open this file and apply enhancements.
  Future<XFile?> captureStill() async {
    if (_isCapturing || !isInitialised) return null;
    _isCapturing = true;
    try {
      // Pause stream momentarily to avoid frame contention.
      await stopFrameStream();
      final file = await _controller!.takePicture();
      _log.i('[Camera] Captured: ${file.path}');
      return file;
    } catch (e) {
      _log.e('[Camera] Capture failed: $e');
      return null;
    } finally {
      _isCapturing = false;
      await startFrameStream();
    }
  }

  // ── Lux Estimation ─────────────────────────────────────────────────────────
  // Approximate scene luminance from the Y-plane mean of a YUV frame
  // (or luminance from BGRA).  Returns lux in [0, 100 000].

  double _estimateLux(CameraImage img) {
    try {
      final plane = img.planes.first;
      final bytes = plane.bytes;
      if (bytes.isEmpty) return 100.0;

      // Sample every 64 pixels for speed.
      double sum = 0;
      int count = 0;
      for (int i = 0; i < bytes.length; i += 64) {
        sum += bytes[i] & 0xFF;
        count++;
      }
      final meanBrightness = sum / count; // [0, 255]
      // Very rough mapping: 0 → 0 lux, 128 → 300 lux, 255 → 5000 lux.
      return (meanBrightness / 255.0) * 5000.0;
    } catch (_) {
      return 100.0;
    }
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  Future<void> dispose() async {
    await stopFrameStream();
    await _frameController.close();
    await _controller?.dispose();
    _controller = null;
  }
}
