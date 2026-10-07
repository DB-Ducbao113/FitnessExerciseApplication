import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/shared/formatters/workout_formatters.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ActivityOptionItem {
  final String type;
  final String nameVi;
  final String nameEn;
  final String? tagVi;
  final String? tagEn;
  final String imagePath;
  final IconData icon;
  final Color accentColor;
  final bool requireGps;

  const ActivityOptionItem({
    required this.type,
    required this.nameVi,
    required this.nameEn,
    this.tagVi,
    this.tagEn,
    required this.imagePath,
    required this.icon,
    required this.accentColor,
    required this.requireGps,
  });
}

class KineticActivityCard extends StatelessWidget {
  final ActivityOptionItem option;
  final bool isSelected;
  final List<WorkoutSession> workouts;
  final bool isVi;
  final VoidCallback onSelect;

  const KineticActivityCard({
    super.key,
    required this.option,
    required this.isSelected,
    required this.workouts,
    required this.isVi,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    final activityWorkouts = workouts
        .where((w) => w.activityType.toLowerCase() == option.type.toLowerCase())
        .toList();

    // Compute real athlete statistics for this activity (only for valid sessions >= 0.1km)
    String? statLeft;
    String? statRight;

    final validWorkouts = activityWorkouts.where((w) => w.distanceKm >= 0.1).toList();

    if (validWorkouts.isNotEmpty) {
      final totalDist = validWorkouts.fold<double>(
        0.0,
        (sum, w) => sum + w.distanceKm,
      );
      final avgDist = totalDist / validWorkouts.length;
      final totalSec = validWorkouts.fold<int>(
        0,
        (sum, w) => sum + w.durationSec,
      );
      final avgSec = (totalSec / validWorkouts.length).round();

      if (avgDist >= 0.1) {
        statLeft = '${avgDist.toStringAsFixed(1)} ${isVi ? 'km / buổi' : 'km / session'}';
        if (option.type == 'cycling') {
          final totalSpeed = validWorkouts.fold<double>(
            0.0,
            (sum, w) => sum + w.avgSpeedKmh,
          );
          final avgSpeed = totalSpeed / validWorkouts.length;
          if (avgSpeed > 0) {
            statRight = 'TB ${avgSpeed.toStringAsFixed(1)} km/h';
          }
        } else {
          if (avgSec > 0 && avgDist > 0) {
            statRight = 'Pace ${WorkoutFormatters.formatPaceFromDistanceAndDuration(distanceKm: avgDist, durationSec: avgSec)}';
          }
        }
      }
    }

    final name = isVi ? option.nameVi : option.nameEn;

    return Semantics(
      button: true,
      selected: isSelected,
      label: name,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onSelect();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: colors.surface1,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? colors.primary
                  : colors.borderSubtle.withValues(alpha: 0.6),
              width: isSelected ? 2.0 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: colors.primary.withValues(alpha: 0.22),
                      blurRadius: 18,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(19),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Highlight strip when active
                if (isSelected)
                  Container(
                    height: 3,
                    color: colors.primary,
                  ),

                // Main Scenic Image Body
                SizedBox(
                  height: 140,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Photo Asset
                      Image.asset(
                        option.imagePath,
                        fit: BoxFit.cover,
                        alignment: Alignment.centerRight,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: colors.surface2,
                          child: Icon(
                            option.icon,
                            size: 64,
                            color: colors.textSecondary.withValues(alpha: 0.3),
                          ),
                        ),
                      ),

                      // Subtle Bottom Gradient for title readability without darkening the photo
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.25),
                              Colors.black.withValues(alpha: 0.65),
                            ],
                            stops: const [0.0, 0.40, 0.70, 1.0],
                          ),
                        ),
                      ),

                      // Top Row: Active Check Circle
                      Positioned(
                        top: 10,
                        right: 12,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected
                                ? colors.primary
                                : Colors.black.withValues(alpha: 0.35),
                            border: Border.all(
                              color: isSelected
                                  ? colors.primary
                                  : Colors.white.withValues(alpha: 0.4),
                              width: 1.5,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(
                                  Icons.check_rounded,
                                  size: 16,
                                  color: Colors.black,
                                )
                              : null,
                        ),
                      ),

                      // Bottom Content: Title only with text shadow for crisp legibility
                      Positioned(
                        bottom: 12,
                        left: 14,
                        right: 14,
                        child: Text(
                          name,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.2,
                            shadows: [
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.8),
                                blurRadius: 8,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Telemetry Specification Strip at Bottom (rendered only when stats exist)
                if (statLeft != null && statRight != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? colors.surface2
                          : colors.surface1.withValues(alpha: 0.9),
                      border: Border(
                        top: BorderSide(
                          color: colors.borderSubtle.withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.insights_rounded,
                          size: 14,
                          color: isSelected
                              ? colors.primary
                              : colors.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          statLeft,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary,
                            fontFeatures: KineticTypography.tabularFigures,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            '·',
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Text(
                          statRight,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: colors.textSecondary,
                            fontFeatures: KineticTypography.tabularFigures,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
