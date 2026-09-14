import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/settings/presentation/providers/settings_preferences_providers.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/details/workout_details_screen.dart';
import 'package:fitness_exercise_application/features/workout/presentation/utils/activity_consistency_feedback.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_ui.dart';
import 'package:fitness_exercise_application/shared/formatters/workout_formatters.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class DailyWorkoutList extends ConsumerWidget {
  final List<WorkoutSession> workouts;
  final String range;

  const DailyWorkoutList({
    super.key,
    required this.workouts,
    required this.range,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(appLanguageProvider);
    final useMetricUnits =
        ref.watch(metricUnitsPreferenceProvider).value ?? true;

    if (workouts.isEmpty) {
      return _EmptyHistoryFilterState(currentLang: currentLang);
    }

    final grouped = _groupWorkoutsByDate(workouts, currentLang);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: grouped.entries.map((entry) {
        final dateHeader = entry.key;
        final dayWorkouts = entry.value;

        // Calculate total distance for this specific day
        final dayTotalDist = dayWorkouts.fold(0.0, (sum, w) {
          final d = w.gpsAnalysis.validDistanceKm > 0
              ? w.gpsAnalysis.validDistanceKm
              : w.distanceKm;
          return sum + d;
        });

        final dayDistStr = WorkoutFormatters.formatDistance(
          dayTotalDist,
          useMetric: useMetricUnits,
          decimals: 1,
        );

        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Day Header Row (Date + Day Total Distance)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AetronColors.cyan,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          dateHeader,
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: AetronColors.cyanSoft.withValues(alpha: 0.95),
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                    if (dayTotalDist > 0)
                      Text(
                        '$dayDistStr ${WorkoutFormatters.distanceUnitLabel(useMetric: useMetricUnits)}',
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AetronColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),

              // Workout Bento Cards under this date
              Column(
                children: dayWorkouts.map((workout) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _WorkoutHistoryBentoCard(
                      workout: workout,
                      useMetricUnits: useMetricUnits,
                      currentLang: currentLang,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Map<String, List<WorkoutSession>> _groupWorkoutsByDate(
    List<WorkoutSession> items,
    AppLanguage lang,
  ) {
    final map = <String, List<WorkoutSession>>{};
    for (final workout in items) {
      final localStart = workout.startedAt.toLocal();
      final dateHeader = lang == AppLanguage.vi
          ? '${localStart.day.toString().padLeft(2, '0')} THÁNG ${localStart.month.toString().padLeft(2, '0')}, ${localStart.year}'
          : DateFormat('MMM dd, yyyy').format(localStart).toUpperCase();
      map.putIfAbsent(dateHeader, () => []).add(workout);
    }
    return map;
  }
}

// ─── 3D Workout History Bento Card ───────────────────────────────────────────
class _WorkoutHistoryBentoCard extends StatelessWidget {
  final WorkoutSession workout;
  final bool useMetricUnits;
  final AppLanguage currentLang;

  const _WorkoutHistoryBentoCard({
    required this.workout,
    required this.useMetricUnits,
    required this.currentLang,
  });

  @override
  Widget build(BuildContext context) {
    final isVi = currentLang == AppLanguage.vi;
    final consistency = assessWorkoutSession(workout);
    final isVerified = consistency.validityFlag == WorkoutValidityFlag.verified;
    final activityType =
        WorkoutFormatters.formatActivityType(workout.activityType, currentLang);
    final timeStr = DateFormat('HH:mm').format(workout.startedAt.toLocal());

    final distanceKm = workout.gpsAnalysis.validDistanceKm > 0
        ? workout.gpsAnalysis.validDistanceKm
        : workout.distanceKm;

    final distanceStr = distanceKm > 0
        ? WorkoutFormatters.formatDistance(
            distanceKm,
            useMetric: useMetricUnits,
            decimals: 2,
          )
        : '—';

    final durationStr = workout.durationSec > 0
        ? WorkoutFormatters.formatDurationFromSeconds(workout.durationSec)
        : '—';

    final paceStr = workout.avgSpeedKmh > 0
        ? WorkoutFormatters.formatPaceFromSpeedKmh(
            workout.avgSpeedKmh,
            useMetric: useMetricUnits,
          )
        : '—';

    final caloriesStr = workout.caloriesKcal > 0
        ? '${workout.caloriesKcal.round()} kcal'
        : null;

    final accentColor = switch (workout.activityType.toLowerCase()) {
      'running' => AetronColors.cyan,
      'walking' => AetronColors.mint,
      'cycling' => AetronColors.gold,
      _ => const Color(0xFFA55EEA),
    };

    final iconData = switch (workout.activityType.toLowerCase()) {
      'running' => Icons.directions_run_rounded,
      'walking' => Icons.directions_walk_rounded,
      'cycling' => Icons.directions_bike_rounded,
      _ => Icons.fitness_center_rounded,
    };

    final hasSteps = (workout.activityType.toLowerCase() == 'running' ||
            workout.activityType.toLowerCase() == 'walking') &&
        workout.steps > 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => WorkoutDetailsScreen(workoutId: workout.id),
            ),
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AetronColors.panelHigh,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: accentColor.withValues(alpha: 0.3),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: accentColor.withValues(alpha: 0.08),
                blurRadius: 12,
                spreadRadius: -2,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Activity Pill + Time + Verified Tag + Chevron
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: accentColor.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(iconData, size: 14, color: accentColor),
                        const SizedBox(width: 5),
                        Text(
                          activityType.toUpperCase(),
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: accentColor,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  Text(
                    timeStr,
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AetronColors.textSecondary,
                    ),
                  ),
                  const Spacer(),

                  if (isVerified)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AetronColors.mint.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: AetronColors.mint.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        isVi ? 'HỢP LỆ ✓' : 'VERIFIED ✓',
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: AetronColors.mint,
                        ),
                      ),
                    ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AetronColors.textSecondary,
                    size: 18,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Hero Distance & Telemetry Bento Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Big Distance
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isVi ? 'QUÃNG ĐƯỜNG' : 'DISTANCE',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            color: AetronColors.textSecondary
                                .withValues(alpha: 0.7),
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              distanceStr,
                              style: const TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: AetronColors.textPrimary,
                                height: 1.0,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              WorkoutFormatters.distanceUnitLabel(
                                  useMetric: useMetricUnits),
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: accentColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Mini Telemetry Chips (Pace, Duration, Calo)
                  Expanded(
                    flex: 6,
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      alignment: WrapAlignment.end,
                      children: [
                        // Duration
                        _MiniTelemetryChip(
                          icon: Icons.timer_rounded,
                          value: durationStr,
                          color: AetronColors.blue,
                        ),
                        // Pace
                        _MiniTelemetryChip(
                          icon: Icons.speed_rounded,
                          value: paceStr,
                          color: AetronColors.mint,
                        ),
                        // Calories
                        if (caloriesStr != null)
                          _MiniTelemetryChip(
                            icon: Icons.local_fire_department_rounded,
                            value: caloriesStr,
                            color: AetronColors.gold,
                          ),
                        // Steps
                        if (hasSteps)
                          _MiniTelemetryChip(
                            icon: Icons.directions_walk_rounded,
                            value: '${workout.steps}',
                            color: const Color(0xFFA55EEA),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniTelemetryChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color color;

  const _MiniTelemetryChip({
    required this.icon,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0C1222),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHistoryFilterState extends StatelessWidget {
  final AppLanguage currentLang;

  const _EmptyHistoryFilterState({required this.currentLang});

  @override
  Widget build(BuildContext context) {
    final isVi = currentLang == AppLanguage.vi;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AetronColors.panelHigh,
                border: Border.all(
                  color: AetronColors.cyan.withValues(alpha: 0.3),
                ),
              ),
              child: const Icon(
                Icons.filter_alt_off_rounded,
                size: 28,
                color: AetronColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isVi
                  ? 'Không tìm thấy buổi tập phù hợp'
                  : 'No matching workouts found',
              style: const TextStyle(
                fontFamily: 'Outfit',
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AetronColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isVi
                  ? 'Hãy thử chuyển bộ lọc hoặc thời gian khác'
                  : 'Try selecting a different filter or time range',
              style: const TextStyle(
                fontFamily: 'Outfit',
                fontSize: 12,
                color: AetronColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
