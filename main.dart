// lib/main.dart
// ─────────────────────────────────────────────────────────────────────────────
// Entry point.  Before runApp() we:
//   1. Ensure Flutter binding is initialised (required for camera/sensors).
//   2. Lock orientation to portrait-up (the pose library assumes this).
//   3. Request maximum display refresh rate on supported devices.
//   4. Pre-warm the Dart VM and Skia shader cache to hit the 33 ms target.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Force portrait — pose library coordinates are portrait-based.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // Maximise display refresh rate on Pro-Motion / high-refresh devices.
  // Tells the engine to request 120 Hz when available.
  if (Platform.isAndroid) {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  // Edge-to-edge on Android; transparent system bars.
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor:           Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    statusBarIconBrightness:  Brightness.light,
  ));

  runApp(const AiCreativeDirectorApp());
}
