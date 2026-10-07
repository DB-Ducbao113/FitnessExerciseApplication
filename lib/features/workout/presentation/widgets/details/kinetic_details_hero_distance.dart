import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/shared/formatters/workout_formatters.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_card.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_colors.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_typography.dart';
import 'package:flutter/material.dart';

class KineticDetailsHeroDistance extends StatelessWidget {
  final WorkoutSession workout;
  final bool useMetricUnits;
  final AppLanguage currentLang;

  const KineticDetailsHeroDistance({
    super.key,
    required this.workout,
    required this.useMetricUnits,
    required this.currentLang,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    final displayDistanceKm = workout.distanceKm;
    final formattedDistance = (useMetricUnits
            ? displayDistanceKm
            : WorkoutFormatters.kmToMi(displayDistanceKm))
        .toStringAsFixed(2);
    final unitLabel = WorkoutFormatters.distanceUnitLabel(
      useMetric: useMetricUnits,
    ).toUpperCase();

    return KineticCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      topAccentColor: colors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            currentLang == AppLanguage.vi
                ? 'QUÃNG ĐƯỜNG ĐÃ LƯU'
                : 'RECORDED DISTANCE',
            style: KineticTypography.unitLabel.copyWith(
              color: colors.primary,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                formattedDistance,
                style: KineticTypography.metricHero.copyWith(
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: colors.primary.withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  unitLabel,
                  style: KineticTypography.unitLabel.copyWith(
                    color: colors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          if (workout.gpsAnalysis.validDistanceKm > 0 &&
              (workout.gpsAnalysis.validDistanceKm - displayDistanceKm).abs() > 0.05) ...[
            const SizedBox(height: 6),
            Text(
              '${currentLang == AppLanguage.vi ? 'Khoảng cách hợp lệ theo GPS' : 'GPS valid distance'}: ${(useMetricUnits ? workout.gpsAnalysis.validDistanceKm : WorkoutFormatters.kmToMi(workout.gpsAnalysis.validDistanceKm)).toStringAsFixed(2)} $unitLabel',
              style: KineticTypography.bodySmall.copyWith(
                color: colors.textMuted,
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
