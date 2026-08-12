import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/settings/presentation/providers/settings_preferences_providers.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/details/workout_details_screen.dart';
import 'package:fitness_exercise_application/features/workout/presentation/utils/activity_consistency_feedback.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_ui.dart';
import 'package:fitness_exercise_application/shared/formatters/workout_formatters.dart';
import 'package:flutter/material.dart';
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
    final useMetricUnits = ref.watch(metricUnitsPreferenceProvider).value ?? true;

    if (workouts.isEmpty) {
      return _EmptyHistoryState(range: range);
    }

    final grouped = _groupWorkoutsByDate(workouts, currentLang);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: grouped.entries.map((entry) {
        final dateHeader = entry.key;
        final dayWorkouts = entry.value;

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date Header Badge
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AetronColors.cyan,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      dateHeader,
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AetronColors.cyanSoft.withValues(alpha: 0.9),
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),

              // Workout 3D Cards under this date
              Column(
                children: dayWorkouts.map((workout) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _WorkoutHistory3DCard(
                      workout: workout,
                      useMetricUnits: useMetricUnits,
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
          ? '${localStart.day.toString().padLeft(2, '0')} Thg ${localStart.month.toString().padLeft(2, '0')}, ${localStart.year}'
          : DateFormat('MMM dd, yyyy').format(localStart).toUpperCase();
      map.putIfAbsent(dateHeader, () => []).add(workout);
    }
    return map;
  }
}

// ─── 3D Workout History Card ───────────────────────────────────────────────────
class _WorkoutHistory3DCard extends ConsumerWidget {
  final WorkoutSession workout;
  final bool useMetricUnits;

  const _WorkoutHistory3DCard({
    required this.workout,
    required this.useMetricUnits,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(appLanguageProvider);
    final consistency = assessWorkoutSession(workout);
    final isVerified = consistency.validityFlag == WorkoutValidityFlag.verified;
    final activityType = WorkoutFormatters.formatActivityType(workout.activityType, currentLang);
    final timeStr = DateFormat('HH:mm').format(workout.startedAt.toLocal());

    final distanceKm = workout.gpsAnalysis.validDistanceKm > 0
        ? workout.gpsAnalysis.validDistanceKm
        : workout.distanceKm;

    final distanceStr = distanceKm > 0
        ? WorkoutFormatters.formatDistance(
            distanceKm,
            useMetric: useMetricUnits,
            decimals: 1,
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

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => WorkoutDetailsScreen(workoutId: workout.id),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AetronColors.panelHigh,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AetronColors.cyan.withValues(alpha: 0.25),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: 3D Icon, Activity Name, Verified Badge & Time
            Row(
              children: [
                // 3D Icon Badge
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AetronColors.space,
                    border: Border.all(color: AetronColors.cyan.withValues(alpha: 0.4)),
                    boxShadow: [
                      BoxShadow(
                        color: AetronColors.cyan.withValues(alpha: 0.2),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Icon(
                    _activityIcon(workout.activityType),
                    color: AetronColors.cyan,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),

                // Workout Type Name
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activityType.toUpperCase(),
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AetronColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        timeStr,
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 11,
                          color: AetronColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

                // Verified Badge
                if (isVerified) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AetronColors.mint.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AetronColors.mint.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      currentLang == AppLanguage.vi ? 'XÁC NHẬN ✓' : 'VERIFIED ✓',
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: AetronColors.mint,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],

                const Icon(
                  Icons.chevron_right_rounded,
                  color: AetronColors.textSecondary,
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Metrics Line Row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0F1524),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AetronColors.borderSubtle),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _MetricColumn(
                    label: AppTranslations.get('distance', currentLang).toUpperCase(),
                    val: distanceStr,
                  ),
                  Container(width: 1, height: 20, color: AetronColors.borderSubtle),
                  _MetricColumn(
                    label: AppTranslations.get('duration', currentLang).toUpperCase(),
                    val: durationStr,
                  ),
                  Container(width: 1, height: 20, color: AetronColors.borderSubtle),
                  _MetricColumn(
                    label: 'PACE',
                    val: paceStr,
                  ),
                  if (caloriesStr != null) ...[
                    Container(width: 1, height: 20, color: AetronColors.borderSubtle),
                    _MetricColumn(
                      label: AppTranslations.get('calories', currentLang).toUpperCase(),
                      val: caloriesStr,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _activityIcon(String type) {
    switch (type.toLowerCase()) {
      case 'running':
        return Icons.directions_run_rounded;
      case 'cycling':
        return Icons.directions_bike_rounded;
      case 'walking':
        return Icons.directions_walk_rounded;
      default:
        return Icons.fitness_center_rounded;
    }
  }
}

class _MetricColumn extends StatelessWidget {
  const _MetricColumn({required this.label, required this.val});

  final String label;
  final String val;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Outfit',
            fontSize: 8,
            fontWeight: FontWeight.w800,
            color: AetronColors.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          val,
          style: const TextStyle(
            fontFamily: 'Outfit',
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: AetronColors.cyan,
          ),
        ),
      ],
    );
  }
}

// ─── 3D Empty History State ─────────────────────────────────────────────────────
class _EmptyHistoryState extends ConsumerWidget {
  const _EmptyHistoryState({required this.range});

  final String range;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(appLanguageProvider);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AetronColors.panelHigh,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AetronColors.borderSubtle),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.history_toggle_off_rounded,
            size: 48,
            color: AetronColors.textSecondary,
          ),
          const SizedBox(height: 12),
          Text(
            AppTranslations.get('no_workouts_yet', currentLang),
            style: const TextStyle(
              fontFamily: 'Outfit',
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: AetronColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            AppTranslations.get('empty_history_desc', currentLang),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Outfit',
              fontSize: 12,
              color: AetronColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
