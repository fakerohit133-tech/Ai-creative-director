// lib/modules/ai_engine/scene_classifier.dart
// ─────────────────────────────────────────────────────────────────────────────
// On-device scene classification using Google ML Kit Image Labeling.
//
// ML Kit returns general object/scene labels; we map these to our 5 buckets
// using a weighted keyword scoring system — no additional TFLite model needed.
//
// Inference is throttled to [kSceneClassifierIntervalMs] (500 ms) since
// scene context changes slowly compared to the 30 FPS camera feed.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:logger/logger.dart';
import '../../core/constants/app_constants.dart';
import '../../core/models/scene_classification.dart';

final _log = Logger(printer: PrettyPrinter(methodCount: 0));

// ── Keyword → Category mapping tables ─────────────────────────────────────

const _urbanKeywords = {
  'road': 2.0, 'street': 3.0, 'building': 2.5, 'car': 2.0, 'sidewalk': 3.0,
  'pavement': 2.5, 'urban': 3.0, 'city': 3.0, 'traffic': 2.0, 'skyscraper': 2.5,
  'bus': 1.5, 'taxi': 1.5, 'graffiti': 2.0, 'architecture': 1.5, 'facade': 2.0,
};

const _studioKeywords = {
  'room': 1.5, 'interior': 2.0, 'furniture': 2.5, 'wall': 1.0, 'studio': 3.0,
  'light': 1.5, 'backdrop': 3.0, 'floor': 1.0, 'ceiling': 1.0, 'lamp': 2.0,
  'couch': 2.0, 'chair': 1.5, 'table': 1.5, 'shelf': 2.0, 'curtain': 2.0,
};

const _minimalKeywords = {
  'window': 2.5, 'white': 2.0, 'minimalist': 3.0, 'concrete': 2.0,
  'brick': 1.5, 'hallway': 2.5, 'corridor': 2.5, 'staircase': 2.5,
  'shadow': 2.0, 'reflection': 2.0, 'mirror': 2.5, 'door': 2.0,
};

const _natureKeywords = {
  'tree': 3.0, 'forest': 3.0, 'grass': 2.5, 'plant': 2.0, 'flower': 2.0,
  'garden': 2.5, 'park': 2.5, 'leaf': 2.0, 'foliage': 3.0, 'nature': 3.0,
  'woodland': 2.5, 'meadow': 3.0, 'water': 1.5, 'stream': 2.0, 'bush': 2.0,
};

const _landscapeKeywords = {
  'sky': 3.0, 'mountain': 3.0, 'horizon': 3.0, 'ocean': 3.0, 'sea': 2.5,
  'desert': 3.0, 'plain': 2.5, 'hill': 2.0, 'landscape': 3.0, 'cloud': 2.0,
  'sunset': 2.5, 'sunrise': 2.5, 'field': 2.0, 'valley': 2.5, 'cliff': 2.5,
};

final _allTables = {
  SceneCategory.urbanStreet:    _urbanKeywords,
  SceneCategory.indoorStudio:   _studioKeywords,
  SceneCategory.minimalIndoor:  _minimalKeywords,
  SceneCategory.natureGreenery: _natureKeywords,
  SceneCategory.openLandscape:  _landscapeKeywords,
};

// ─────────────────────────────────────────────────────────────────────────────

class SceneClassifier {
  late final ImageLabeler _labeler;
  int _lastInferenceMs = 0;
  SceneClassificationResult _lastResult = SceneClassificationResult.defaultResult();

  final _resultController =
      StreamController<SceneClassificationResult>.broadcast();
  Stream<SceneClassificationResult> get resultStream => _resultController.stream;

  SceneClassificationResult get lastResult => _lastResult;

  void initialise() {
    _labeler = ImageLabeler(
      options: ImageLabelerOptions(confidenceThreshold: 0.4),
    );
    _log.i('[SceneClassifier] ML Kit ImageLabeler initialised');
  }

  // ── Frame Processing ───────────────────────────────────────────────────────

  void processFrame(CameraImage frame, int sensorOrientation) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (nowMs - _lastInferenceMs < kSceneClassifierIntervalMs) return;
    _lastInferenceMs = nowMs;

    _runInference(frame, sensorOrientation);
  }

  Future<void> _runInference(
      CameraImage frame, int sensorOrientation) async {
    try {
      final inputImage = _buildInputImage(frame, sensorOrientation);
      if (inputImage == null) return;

      final labels = await _labeler.processImage(inputImage);
      final result = _classifyLabels(labels);
      _lastResult = result;
      _resultController.add(result);
    } catch (e) {
      _log.w('[SceneClassifier] Inference error: $e');
    }
  }

  SceneClassificationResult _classifyLabels(List<ImageLabel> labels) {
    final scores = <SceneCategory, double>{
      for (final c in SceneCategory.values) c: 0.0,
    };

    for (final label in labels) {
      final text = label.label.toLowerCase();
      final confidence = label.confidence;

      for (final entry in _allTables.entries) {
        final table = entry.value;
        for (final kv in table.entries) {
          if (text.contains(kv.key)) {
            scores[entry.key] = (scores[entry.key]! + kv.value * confidence);
          }
        }
      }
    }

    // Normalise scores to [0,1]
    final totalScore = scores.values.fold(0.0, (s, v) => s + v);
    final normalised = totalScore == 0
        ? <SceneCategory, double>{
            for (final c in SceneCategory.values) c: 0.2
          }
        : scores.map((k, v) => MapEntry(k, v / totalScore));

    // Winning category
    final winner = normalised.entries
        .reduce((a, b) => a.value >= b.value ? a : b);

    return SceneClassificationResult(
      category: winner.key,
      confidence: winner.value,
      allScores: normalised,
      timestamp: DateTime.now(),
    );
  }

  InputImage? _buildInputImage(CameraImage frame, int sensorOrientation) {
    try {
      final format = InputImageFormatValue.fromRawValue(frame.format.raw);
      if (format == null) return null;

      final WriteBuffer buffer = WriteBuffer();
      for (final plane in frame.planes) {
        buffer.putUint8List(plane.bytes);
      }

      final rotation = _mapSensorOrientation(sensorOrientation);

      return InputImage.fromBytes(
        bytes: buffer.done().buffer.asUint8List(),
        metadata: InputImageMetadata(
          size: Size(frame.width.toDouble(), frame.height.toDouble()),
          rotation: rotation,
          format: format,
          bytesPerRow: frame.planes.first.bytesPerRow,
        ),
      );
    } catch (e) {
      _log.w('[SceneClassifier] buildInputImage: $e');
      return null;
    }
  }

  InputImageRotation _mapSensorOrientation(int deg) {
    switch (deg) {
      case 90:  return InputImageRotation.rotation90deg;
      case 180: return InputImageRotation.rotation180deg;
      case 270: return InputImageRotation.rotation270deg;
      default:  return InputImageRotation.rotation0deg;
    }
  }

  Future<void> dispose() async {
    await _labeler.close();
    await _resultController.close();
  }
}
