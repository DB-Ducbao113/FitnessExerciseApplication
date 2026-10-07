import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/shared/formatters/workout_formatters.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_card.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_colors.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_typography.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class KineticDetailsSecondaryCard extends StatelessWidget {
  final WorkoutSession workout;
  final bool useMetricUnits;
  final AppLanguage currentLang;

  const KineticDetailsSecondaryCard({
    super.key,
    required this.workout,
    required this.useMetricUnits,
    required this.currentLang,
  });

  bool _hasSteps(String activityType) {
    final t = activityType.toLowerCase();
    return t == 'running' || t == 'walking';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    final displayDistanceKm = workout.distanceKm;
    final effectiveDistanceKm = workout.gpsAnalysis.validDistanceKm > 0
        ? workout.gpsAnalysis.validDistanceKm
        : displayDistanceKm;
    final showSteps = _hasSteps(workout.activityType) && workout.steps > 0;

    final movingPace = WorkoutFormatters.formatMovingPaceFromDistanceAndDuration(
      distanceKm: effectiveDistanceKm,
      durationSec: workout.movingTimeSec,
      restDurationSec: 0,
      useMetric: useMetricUnits,
    );

    final speedUnit = useMetricUnits ? 'km/h' : 'mph';
    final avgSpeed = useMetricUnits
        ? workout.avgSpeedKmh
        : WorkoutFormatters.kmToMi(workout.avgSpeedKmh);

    return KineticCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune_rounded, size: 14, color: colors.primary),
              const SizedBox(width: 6),
              Text(
                currentLang == AppLanguage.vi
                    ? 'THÔNG SỐ BỔ SUNG'
                    : 'SECONDARY TELEMETRY',
                style: KineticTypography.unitLabel.copyWith(
                  color: colors.textPrimary,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Moving pace (if steps were in primary grid)
          if (showSteps) ...[
            _Row(
              icon: Icons.directions_run_rounded,
              label: currentLang == AppLanguage.vi ? 'Pace di chuyển' : 'Moving Pace',
              value: movingPace,
              colors: colors,
            ),
            _divider(colors),
          ],

          // Moving Time
          _Row(
            icon: Icons.play_circle_outline_rounded,
            label: currentLang == AppLanguage.vi ? 'Thời gian di chuyển' : 'Moving Time',
            value: WorkoutFormatters.formatElapsedClock(workout.movingTimeSec),
            colors: colors,
          ),
          _divider(colors),

          // Rest Time
          _Row(
            icon: Icons.pause_circle_outline_rounded,
            label: currentLang == AppLanguage.vi ? 'Thời gian nghỉ' : 'Rest Time',
            value: WorkoutFormatters.formatElapsedClock(workout.gpsAnalysis.restDurationSec),
            colors: colors,
          ),
          _divider(colors),

          // Average Speed
          _Row(
            icon: Icons.speed_outlined,
            label: currentLang == AppLanguage.vi ? 'Tốc độ trung bình' : 'Avg Speed',
            value: '${avgSpeed.toStringAsFixed(1)} $speedUnit',
            colors: colors,
          ),
          _divider(colors),

          // Start Time
          _Row(
            icon: Icons.login_rounded,
            label: currentLang == AppLanguage.vi ? 'Bắt đầu' : 'Started',
            value: DateFormat('HH:mm:ss').format(workout.startedAt.toLocal()),
            colors: colors,
          ),
          _divider(colors),

          // Finished Time
          _Row(
            icon: Icons.logout_rounded,
            label: currentLang == AppLanguage.vi ? 'Kết thúc' : 'Finished',
            value: DateFormat('HH:mm:ss').format(workout.endedAt.toLocal()),
            colors: colors,
          ),
          _divider(colors),

          // Mode
          _Row(
            icon: workout.mode == 'outdoor' ? Icons.terrain_rounded : Icons.fitness_center_rounded,
            label: currentLang == AppLanguage.vi ? 'Môi trường' : 'Environment',
            value: workout.mode == 'outdoor'
                ? (currentLang == AppLanguage.vi ? 'Ngoài trời' : 'Outdoor')
                : (currentLang == AppLanguage.vi ? 'Trong nhà' : 'Indoor'),
            colors: colors,
          ),
          _divider(colors),

          // Saved Date
          _Row(
            icon: Icons.save_outlined,
            label: currentLang == AppLanguage.vi ? 'Đã lưu' : 'Saved',
            value: DateFormat('dd/MM/yyyy HH:mm').format(workout.createdAt.toLocal()),
            colors: colors,
          ),
        ],
      ),
    );
  }

  Widget _divider(KineticColors colors) => Divider(
        height: 16,
        thickness: 0.8,
        color: colors.borderSubtle,
      );
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final KineticColors colors;

  const _Row({
    required this.icon,
    required this.label,
    required this.value,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: colors.textMuted),
        const SizedBox(width: 8),
        Text(
          label,
          style: KineticTypography.bodySmall.copyWith(
            color: colors.textMuted,
            fontSize: 13,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: KineticTypography.label.copyWith(
            color: colors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
