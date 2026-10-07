import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/shared/formatters/workout_formatters.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:flutter/material.dart';

class KineticKeyTelemetryBento extends StatelessWidget {
  final List<WorkoutSession> workouts;
  final bool useMetricUnits;
  final bool isVi;

  const KineticKeyTelemetryBento({
    super.key,
    required this.workouts,
    required this.useMetricUnits,
    required this.isVi,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;

    // Aggregate statistics
    double totalDistKm = 0.0;
    int totalDurationSec = 0;
    int totalCalories = 0;

    for (final w in workouts) {
      totalDistKm += w.distanceKm;
      totalDurationSec += w.durationSec;
      totalCalories += w.caloriesKcal.round();
    }

    final displayDistance =
        useMetricUnits ? totalDistKm : WorkoutFormatters.kmToMi(totalDistKm);
    final distanceUnit =
        WorkoutFormatters.distanceUnitLabel(useMetric: useMetricUnits);
    final durationStr = totalDurationSec > 0
        ? WorkoutFormatters.formatDurationFromSeconds(totalDurationSec)
        : '00:00';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isVi ? 'CHỈ SỐ TỔNG HỢP' : 'KEY TELEMETRY',
          style: KineticTypography.unitLabel.copyWith(
            color: colors.primary,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _TelemetryCard(
                label: isVi ? 'QUÃNG ĐƯỜNG' : 'DISTANCE',
                value: displayDistance > 0
                    ? displayDistance.toStringAsFixed(1)
                    : '—',
                unit: displayDistance > 0 ? distanceUnit.toUpperCase() : '',
                icon: Icons.route_rounded,
                accentColor: colors.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _TelemetryCard(
                label: isVi ? 'THỜI GIAN' : 'ACTIVE TIME',
                value: durationStr,
                unit: '',
                icon: Icons.timer_rounded,
                accentColor: colors.secondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _TelemetryCard(
                label: isVi ? 'NĂNG LƯỢNG' : 'CALORIES',
                value: totalCalories > 0 ? '$totalCalories' : '—',
                unit: totalCalories > 0 ? 'KCAL' : '',
                icon: Icons.local_fire_department_rounded,
                accentColor: colors.tertiary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _TelemetryCard(
                label: isVi ? 'BUỔI TẬP' : 'SESSIONS',
                value: '${workouts.length}',
                unit: isVi ? 'BUỔI' : 'WORKOUTS',
                icon: Icons.sports_score_rounded,
                accentColor: colors.primary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TelemetryCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final Color accentColor;

  const _TelemetryCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface1,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colors.borderSubtle.withValues(alpha: 0.8),
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: colors.textSecondary,
                  letterSpacing: 0.6,
                ),
              ),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accentColor.withValues(alpha: 0.12),
                ),
                child: Icon(icon, size: 15, color: accentColor),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: colors.textPrimary,
                  letterSpacing: -0.5,
                  fontFeatures: KineticTypography.tabularFigures,
                ),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 4),
                Text(
                  unit,
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: accentColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
