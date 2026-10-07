import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:flutter/material.dart';

class KineticYourWeekBento extends StatelessWidget {
  final double weeklyDistanceKm;
  final int workoutCount;
  final double targetDistanceKm;
  final int targetWorkoutCount;
  final String dateRangeText;
  final VoidCallback? onSetGoalTap;
  final bool isVi;
  final bool useMetricUnits;

  const KineticYourWeekBento({
    super.key,
    required this.weeklyDistanceKm,
    required this.workoutCount,
    required this.targetDistanceKm,
    this.targetWorkoutCount = 5,
    required this.dateRangeText,
    this.onSetGoalTap,
    this.isVi = true,
    this.useMetricUnits = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;

    final progress = targetDistanceKm > 0
        ? (weeklyDistanceKm / targetDistanceKm).clamp(0.0, 1.0)
        : 0.0;
    final percent = (progress * 100).round();
    final unit = useMetricUnits ? 'km' : 'mi';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: KineticCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isVi ? 'Tuần này của bạn' : 'Your Week',
                      style: KineticTypography.headlineSmall.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dateRangeText,
                      style: KineticTypography.bodySmall.copyWith(
                        color: colors.textMuted,
                      ),
                    ),
                  ],
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onSetGoalTap,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: colors.primary.withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.track_changes_rounded,
                            size: 13,
                            color: colors.primary,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            isVi ? 'Mục tiêu: $percent%' : 'Goal: $percent%',
                            style: KineticTypography.unitLabel.copyWith(
                              color: colors.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(width: 3),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 14,
                            color: colors.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 2. Bento Stats Grid
            Row(
              children: [
                // Box 1: Distance
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.surface2,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: colors.borderSubtle, width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isVi ? 'Tổng quãng đường' : 'Total Distance',
                          style: KineticTypography.bodySmall.copyWith(
                            color: colors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              weeklyDistanceKm.toStringAsFixed(1),
                              style: KineticTypography.metricHero.copyWith(
                                color: colors.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              unit.toUpperCase(),
                              style: KineticTypography.unitLabel.copyWith(
                                color: colors.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.trending_up_rounded,
                              size: 14,
                              color: colors.secondary,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                isVi
                                    ? '+12% so với tuần trước'
                                    : '+12% vs last week',
                                style: KineticTypography.unitLabel.copyWith(
                                  color: colors.secondary,
                                  fontSize: 11,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Box 2: Workouts Count
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.surface2,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: colors.borderSubtle, width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isVi ? 'Số buổi tập' : 'Workouts',
                          style: KineticTypography.bodySmall.copyWith(
                            color: colors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '$workoutCount',
                              style: KineticTypography.metricHero.copyWith(
                                color: colors.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isVi ? 'BUỔI' : 'SESSIONS',
                              style: KineticTypography.unitLabel.copyWith(
                                color: colors.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.check_circle_outline_rounded,
                              size: 14,
                              color: colors.primary,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                isVi
                                    ? 'Mục tiêu: $targetWorkoutCount buổi/tuần'
                                    : 'Target: $targetWorkoutCount sessions/wk',
                                style: KineticTypography.unitLabel.copyWith(
                                  color: colors.textMuted,
                                  fontSize: 11,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 3. Progress Bar with Glow
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isVi
                      ? 'Tiến độ tích lũy (${weeklyDistanceKm.toStringAsFixed(1)} / ${targetDistanceKm.toStringAsFixed(0)} $unit)'
                      : 'Accumulated Progress (${weeklyDistanceKm.toStringAsFixed(1)} / ${targetDistanceKm.toStringAsFixed(0)} $unit)',
                  style: KineticTypography.bodySmall.copyWith(
                    color: colors.textMuted,
                    fontSize: 12,
                  ),
                ),
                Text(
                  '$percent%',
                  style: KineticTypography.label.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                height: 8,
                color: colors.surface3,
                child: Stack(
                  children: [
                    FractionallySizedBox(
                      widthFactor: progress,
                      child: Container(
                        decoration: BoxDecoration(
                          color: colors.primary,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: colors.primary.withValues(alpha: 0.6),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // 4. Dedicated Adjust Goal Action Button
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onSetGoalTap,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.tune_rounded,
                            size: 14,
                            color: colors.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isVi
                                ? 'Điều chỉnh mục tiêu rèn luyện'
                                : 'Adjust your fitness goals',
                            style: KineticTypography.bodySmall.copyWith(
                              color: colors.textSecondary,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isVi ? 'Cài đặt' : 'Settings',
                            style: KineticTypography.unitLabel.copyWith(
                              color: colors.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 10,
                            color: colors.primary,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
