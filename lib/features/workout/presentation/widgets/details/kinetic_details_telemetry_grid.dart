import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/shared/formatters/workout_formatters.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_card.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_colors.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_metric_tile.dart';
import 'package:flutter/material.dart';

class KineticDetailsTelemetryGrid extends StatelessWidget {
  final WorkoutSession workout;
  final bool useMetricUnits;
  final AppLanguage currentLang;

  const KineticDetailsTelemetryGrid({
    super.key,
    required this.workout,
    required this.useMetricUnits,
    required this.currentLang,
  });

  bool _hasSteps(String activityType) {
    final t = activityType.toLowerCase();
    return t == 'running' || t == 'walking';
  }

  String _formatSteps(int steps) {
    if (steps >= 1000) {
      return '${(steps / 1000).toStringAsFixed(1)}k';
    }
    return '$steps';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    final displayDistanceKm = workout.distanceKm;
    final effectiveDistanceKm = workout.gpsAnalysis.validDistanceKm > 0
        ? workout.gpsAnalysis.validDistanceKm
        : displayDistanceKm;

    final avgPace = WorkoutFormatters.formatPaceFromDistanceAndDuration(
      distanceKm: displayDistanceKm,
      durationSec: workout.durationSec,
      useMetric: useMetricUnits,
    );
    final movingPace = WorkoutFormatters.formatMovingPaceFromDistanceAndDuration(
      distanceKm: effectiveDistanceKm,
      durationSec: workout.movingTimeSec,
      restDurationSec: 0,
      useMetric: useMetricUnits,
    );

    final showSteps = _hasSteps(workout.activityType) && workout.steps > 0;
    final paceUnit = useMetricUnits ? 'min/km' : 'min/mi';

    return Column(
      children: [
        // Row 1: Duration & Avg Pace
        Row(
          children: [
            Expanded(
              child: KineticCard(
                padding: const EdgeInsets.all(14),
                child: KineticMetricTile(
                  icon: Icons.timer_outlined,
                  label: AppTranslations.get('duration', currentLang),
                  value: WorkoutFormatters.formatDurationFromSeconds(
                    workout.durationSec,
                  ),
                  unit: '',
                  accentColor: colors.primary,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: KineticCard(
                padding: const EdgeInsets.all(14),
                child: KineticMetricTile(
                  icon: Icons.speed_rounded,
                  label: currentLang == AppLanguage.vi ? 'Pace TB' : 'Avg Pace',
                  value: avgPace,
                  unit: paceUnit,
                  accentColor: colors.secondary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Row 2: Calories & (Steps or Moving Pace)
        Row(
          children: [
            Expanded(
              child: KineticCard(
                padding: const EdgeInsets.all(14),
                child: KineticMetricTile(
                  icon: Icons.local_fire_department_outlined,
                  label: AppTranslations.get('calories', currentLang),
                  value: '${workout.caloriesKcal.round()}',
                  unit: 'kcal',
                  accentColor: colors.tertiary,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: KineticCard(
                padding: const EdgeInsets.all(14),
                child: showSteps
                    ? KineticMetricTile(
                        icon: Icons.directions_walk_rounded,
                        label: currentLang == AppLanguage.vi ? 'Số bước' : 'Steps',
                        value: _formatSteps(workout.steps),
                        unit: 'bước',
                        accentColor: colors.secondary,
                      )
                    : KineticMetricTile(
                        icon: Icons.directions_run_rounded,
                        label: currentLang == AppLanguage.vi ? 'Pace di chuyển' : 'Moving Pace',
                        value: movingPace,
                        unit: paceUnit,
                        accentColor: colors.secondary,
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
