// lib/ui/widgets/pose_selector_sheet.dart
// ─────────────────────────────────────────────────────────────────────────────
// Draggable bottom sheet that lets the user browse and select a reference pose.
// Groups poses by scene category using a horizontal category tab strip.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/pose_library.dart';
import '../../core/models/pose_model.dart';
import '../../core/models/scene_classification.dart';
import '../painters/skeleton_painter.dart';

class PoseSelectorSheet extends StatefulWidget {
  final PoseDefinition? activePose;
  final SceneCategory   currentScene;
  final ValueChanged<PoseDefinition> onSelect;

  const PoseSelectorSheet({
    super.key,
    required this.activePose,
    required this.currentScene,
    required this.onSelect,
  });

  @override
  State<PoseSelectorSheet> createState() => _PoseSelectorSheetState();
}

class _PoseSelectorSheetState extends State<PoseSelectorSheet> {
  late SceneCategory _selectedCat;

  @override
  void initState() {
    super.initState();
    _selectedCat = widget.currentScene;
  }

  List<PoseDefinition> get _poses => posesForScene(_selectedCat);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.52,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.72),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(
              color: Colors.white.withOpacity(0.08),
              width: 0.8,
            ),
          ),
          child: Column(
            children: [
              // Handle
              const SizedBox(height: 8),
              Container(
                width: 36, height: 3,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),

              // Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Text(
                      'SELECT POSE',
                      style: GoogleFonts.spaceMono(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 2.5,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${kPoseLibrary.length} POSES',
                      style: GoogleFonts.spaceMono(
                        fontSize: 9,
                        color: Colors.white.withOpacity(0.4),
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Category tabs
              SizedBox(
                height: 32,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: SceneCategory.values.map((cat) {
                    final selected = cat == _selectedCat;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedCat = cat),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: selected
                              ? Colors.white.withOpacity(0.14)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: selected
                                ? Colors.white.withOpacity(0.35)
                                : Colors.white.withOpacity(0.12),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          '${cat.emoji} ${cat.displayName}',
                          style: GoogleFonts.spaceMono(
                            fontSize: 9,
                            color: selected
                                ? Colors.white
                                : Colors.white.withOpacity(0.45),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 14),

              // Pose grid
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.78,
                  ),
                  itemCount: _poses.length,
                  itemBuilder: (_, i) {
                    final pose = _poses[i];
                    final isActive = pose.id == widget.activePose?.id;
                    return _PoseCard(
                      pose: pose,
                      isActive: isActive,
                      onTap: () {
                        widget.onSelect(pose);
                        Navigator.of(context).pop();
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PoseCard extends StatelessWidget {
  final PoseDefinition pose;
  final bool isActive;
  final VoidCallback onTap;

  const _PoseCard({
    required this.pose,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: isActive
              ? const Color(0xFF4DFFC0).withOpacity(0.12)
              : Colors.white.withOpacity(0.05),
          border: Border.all(
            color: isActive
                ? const Color(0xFF4DFFC0).withOpacity(0.6)
                : Colors.white.withOpacity(0.10),
            width: isActive ? 1.2 : 0.7,
          ),
        ),
        child: Column(
          children: [
            // Mini skeleton preview
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: CustomPaint(
                  painter: SkeletonPainter(
                    referenceLandmarks: pose.landmarks,
                    alignmentScore: 0.0,
                    showReference: true,
                  ),
                ),
              ),
            ),
            // Label
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
              child: Text(
                pose.label,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.spaceMono(
                  fontSize: 7.5,
                  color: isActive
                      ? const Color(0xFF4DFFC0)
                      : Colors.white.withOpacity(0.65),
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
