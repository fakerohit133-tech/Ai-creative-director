// lib/ui/screens/splash_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'camera_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 2200), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const CameraScreen(),
            transitionDuration: const Duration(milliseconds: 700),
            transitionsBuilder: (_, anim, __, child) =>
                FadeTransition(opacity: anim, child: child),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Aperture icon
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF4DFFC0).withOpacity(0.8),
                  width: 1.5,
                ),
              ),
              child: const Center(
                child: Icon(Icons.camera_alt_outlined,
                    color: Color(0xFF4DFFC0), size: 28),
              ),
            )
            .animate()
            .scale(begin: const Offset(0.6, 0.6), end: const Offset(1, 1),
                duration: 600.ms, curve: Curves.easeOut)
            .fadeIn(duration: 500.ms),

            const SizedBox(height: 24),

            Text(
              'AI CREATIVE\nDIRECTOR',
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceMono(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 4.0,
                height: 1.4,
              ),
            )
            .animate(delay: 300.ms)
            .fadeIn(duration: 600.ms)
            .slideY(begin: 0.15, end: 0, duration: 500.ms, curve: Curves.easeOut),

            const SizedBox(height: 10),

            Text(
              'ON-DEVICE POSE · SCENE · SENSOR FUSION',
              style: GoogleFonts.spaceMono(
                fontSize: 8.5,
                color: Colors.white.withOpacity(0.35),
                letterSpacing: 2.0,
              ),
            )
            .animate(delay: 600.ms)
            .fadeIn(duration: 500.ms),

            const SizedBox(height: 48),

            SizedBox(
              width: 120,
              child: LinearProgressIndicator(
                backgroundColor: Colors.white.withOpacity(0.08),
                color: const Color(0xFF4DFFC0).withOpacity(0.7),
                minHeight: 1.0,
              ),
            )
            .animate(delay: 700.ms)
            .fadeIn(duration: 400.ms),
          ],
        ),
      ),
    );
  }
}
