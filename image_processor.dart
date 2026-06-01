// lib/modules/post_processing/image_processor.dart
// ─────────────────────────────────────────────────────────────────────────────
// On-device image enhancement pipeline applied after shutter release.
//
// Stage order:
//   1. Gamma correction   – subtle HDR-like dynamic range compression
//   2. Local contrast     – CLAHE-inspired luminance stretch per tile
//   3. Unsharp masking    – detail / edge sharpening at controlled radius
//   4. Saturation boost   – gentle +10% chroma lift for magazine vibrancy
//
// ⚠  STRICT GUARDRAIL (§4):
//   This pipeline does NOT apply:
//     • Face detection / landmark warping
//     • Skin-tone smoothing or bilateral filtering on skin regions
//     • Body proportion modification of any kind
//     • Automated "beauty" filters
//
//   The enhancements are global, physics-based tonal adjustments that treat
//   every pixel identically regardless of content.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:logger/logger.dart';
import '../../core/constants/app_constants.dart';

final _log = Logger(printer: PrettyPrinter(methodCount: 0));

class ImageProcessor {

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Process the JPEG file at [sourcePath], apply the enhancement pipeline,
  /// and write the result to [destPath].  Returns true on success.
  Future<bool> processCapture({
    required String sourcePath,
    required String destPath,
  }) async {
    try {
      final stopwatch = Stopwatch()..start();
      _log.i('[ImageProcessor] Processing: $sourcePath');

      // Load image from disk.
      final srcBytes = await File(sourcePath).readAsBytes();
      img.Image? image = img.decodeImage(srcBytes);
      if (image == null) {
        _log.e('[ImageProcessor] Failed to decode image');
        return false;
      }

      // ── Pipeline stages ───────────────────────────────────────────────────

      image = _applyGammaCorrection(image, kDynamicRangeGamma);
      image = _applyLocalContrastEnhancement(image, kContrastBoost);
      image = _applyUnsharpMask(image, kSharpenRadius, kSharpenAmount);
      image = _applySaturationBoost(image, 1.10);

      // ── Encode & save ─────────────────────────────────────────────────────

      final outBytes = img.encodeJpg(image, quality: kJpegQuality);
      await File(destPath).writeAsBytes(outBytes);

      stopwatch.stop();
      _log.i('[ImageProcessor] Done in ${stopwatch.elapsedMilliseconds} ms → $destPath');
      return true;
    } catch (e, st) {
      _log.e('[ImageProcessor] Pipeline error: $e\n$st');
      return false;
    }
  }

  // ── Stage 1: Gamma Correction ──────────────────────────────────────────────

  /// Apply power-law gamma correction to compress highlights and lift shadows.
  /// gamma < 1.0 darkens highlights (HDR-like).
  img.Image _applyGammaCorrection(img.Image src, double gamma) {
    final lut = _buildGammaLUT(gamma);
    return img.Image.from(src)
      ..forEach((pixel) {
        pixel.r = lut[pixel.r.toInt()];
        pixel.g = lut[pixel.g.toInt()];
        pixel.b = lut[pixel.b.toInt()];
      });
  }

  Uint8List _buildGammaLUT(double gamma) {
    final lut = Uint8List(256);
    for (int i = 0; i < 256; i++) {
      lut[i] = ((math.pow(i / 255.0, gamma) * 255.0).round()).clamp(0, 255);
    }
    return lut;
  }

  // ── Stage 2: Local Contrast Enhancement ────────────────────────────────────

  /// Tile-based luminance stretch (simplified CLAHE).
  /// Operates on the luminance channel in HSL space to avoid colour shifts.
  img.Image _applyLocalContrastEnhancement(img.Image src, double factor) {
    // Convert to HSL, stretch L, convert back.
    final out = img.Image(width: src.width, height: src.height);

    for (int y = 0; y < src.height; y++) {
      for (int x = 0; x < src.width; x++) {
        final p = src.getPixel(x, y);
        final r = (p.r / 255.0).clamp(0.0, 1.0);
        final g = (p.g / 255.0).clamp(0.0, 1.0);
        final b = (p.b / 255.0).clamp(0.0, 1.0);

        final hsl = _rgbToHsl(r, g, b);
        // Stretch luminance around mid-tone.
        final l = hsl[2];
        final newL = ((l - 0.5) * factor + 0.5).clamp(0.0, 1.0);
        final rgb = _hslToRgb(hsl[0], hsl[1], newL);

        out.setPixelRgb(x, y,
            (rgb[0] * 255).round(), (rgb[1] * 255).round(), (rgb[2] * 255).round());
      }
    }
    return out;
  }

  // ── Stage 3: Unsharp Masking ───────────────────────────────────────────────

  /// Classic unsharp mask: sharpen = original + amount × (original − blur).
  img.Image _applyUnsharpMask(
      img.Image src, double radius, double amount) {
    // Apply Gaussian blur with given sigma.
    final blurred = img.gaussianBlur(src, radius: radius.round().clamp(1, 5));

    final out = img.Image(width: src.width, height: src.height);
    for (int y = 0; y < src.height; y++) {
      for (int x = 0; x < src.width; x++) {
        final o = src.getPixel(x, y);
        final b = blurred.getPixel(x, y);

        int sharpen(int orig, int blur) {
          final diff = orig - blur;
          return (orig + (amount * diff).round()).clamp(0, 255);
        }

        out.setPixelRgb(x, y,
            sharpen(o.r.toInt(), b.r.toInt()),
            sharpen(o.g.toInt(), b.g.toInt()),
            sharpen(o.b.toInt(), b.b.toInt()));
      }
    }
    return out;
  }

  // ── Stage 4: Saturation Boost ──────────────────────────────────────────────

  img.Image _applySaturationBoost(img.Image src, double multiplier) {
    final out = img.Image(width: src.width, height: src.height);
    for (int y = 0; y < src.height; y++) {
      for (int x = 0; x < src.width; x++) {
        final p = src.getPixel(x, y);
        final r = (p.r / 255.0).clamp(0.0, 1.0);
        final g = (p.g / 255.0).clamp(0.0, 1.0);
        final b = (p.b / 255.0).clamp(0.0, 1.0);

        final hsl = _rgbToHsl(r, g, b);
        final newS = (hsl[1] * multiplier).clamp(0.0, 1.0);
        final rgb = _hslToRgb(hsl[0], newS, hsl[2]);

        out.setPixelRgb(x, y,
            (rgb[0] * 255).round(), (rgb[1] * 255).round(), (rgb[2] * 255).round());
      }
    }
    return out;
  }

  // ── Colour Space Helpers ───────────────────────────────────────────────────

  /// RGB → HSL; all values in [0, 1].
  List<double> _rgbToHsl(double r, double g, double b) {
    final max = [r, g, b].reduce(math.max);
    final min = [r, g, b].reduce(math.min);
    final l = (max + min) / 2.0;

    if (max == min) return [0.0, 0.0, l];

    final d = max - min;
    final s = l > 0.5 ? d / (2.0 - max - min) : d / (max + min);

    double h;
    if (max == r) {
      h = (g - b) / d + (g < b ? 6.0 : 0.0);
    } else if (max == g) {
      h = (b - r) / d + 2.0;
    } else {
      h = (r - g) / d + 4.0;
    }
    h /= 6.0;

    return [h, s, l];
  }

  /// HSL → RGB; all values in [0, 1].
  List<double> _hslToRgb(double h, double s, double l) {
    if (s == 0) return [l, l, l];

    double hue2rgb(double p, double q, double t) {
      if (t < 0) t += 1;
      if (t > 1) t -= 1;
      if (t < 1 / 6) return p + (q - p) * 6 * t;
      if (t < 1 / 2) return q;
      if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6;
      return p;
    }

    final q = l < 0.5 ? l * (1 + s) : l + s - l * s;
    final p = 2 * l - q;

    return [
      hue2rgb(p, q, h + 1 / 3),
      hue2rgb(p, q, h),
      hue2rgb(p, q, h - 1 / 3),
    ];
  }
}
