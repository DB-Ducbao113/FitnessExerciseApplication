import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_card.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_colors.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_typography.dart';
import 'package:flutter/material.dart';

class KineticSummaryHeroDistance extends StatelessWidget {
  final double distanceKm;
  final String activityType;
  final bool useMetricUnits;
  final WorkoutValidityFlag validityFlag;
  final AppLanguage currentLang;

  const KineticSummaryHeroDistance({
    super.key,
    required this.distanceKm,
    required this.activityType,
    required this.useMetricUnits,
    this.validityFlag = WorkoutValidityFlag.verified,
    required this.currentLang,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    final displayDistance = useMetricUnits ? distanceKm : distanceKm * 0.621371;
    final distanceUnit = useMetricUnits ? 'KM' : 'MI';

    final Color validityColor;
    final String validityText;
    switch (validityFlag) {
      case WorkoutValidityFlag.verified:
        validityColor = colors.primary;
        validityText = currentLang == AppLanguage.vi
            ? 'GPS ĐÃ XÁC MINH'
            : 'GPS VERIFIED';
        break;
      case WorkoutValidityFlag.partial:
        validityColor = colors.secondary;
        validityText = currentLang == AppLanguage.vi
            ? 'GPS HIỆU CHỈNH'
            : 'GPS CALIBRATED';
        break;
      case WorkoutValidityFlag.unverified:
        validityColor = colors.tertiary;
        validityText = currentLang == AppLanguage.vi
            ? 'CẢM BIẾN NỘI SUY'
            : 'SENSOR INTERPOLATED';
        break;
    }

    return KineticCard(
      padding: const EdgeInsets.all(20),
      topAccentColor: colors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: colors.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: colors.primary.withValues(alpha: 0.6),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        currentLang == AppLanguage.vi
                            ? 'HOÀN THÀNH XUẤT SẮC'
                            : 'SESSION COMPLETE',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: KineticTypography.unitLabel.copyWith(
                          color: colors.primary,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: validityColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: validityColor.withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  validityText,
                  style: KineticTypography.unitLabel.copyWith(
                    color: validityColor,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Big Metric Value
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                displayDistance.toStringAsFixed(2),
                style: KineticTypography.metricHero.copyWith(
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                distanceUnit,
                style: KineticTypography.headlineMedium.copyWith(
                  color: colors.textMuted,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
