import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/features/settings/presentation/providers/settings_preferences_providers.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/workout_details_screen.dart';
import 'package:fitness_exercise_application/features/workout/presentation/utils/activity_consistency_feedback.dart';
import 'package:fitness_exercise_application/shared/formatters/workout_formatters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _kCardBg = Color(0xFF102033);
const _kCardBorder = Color(0x2200E5FF);
const _kMutedText = Color(0xFF8A96A9);
const _kMutedSoft = Color(0xFF627286);
const _kNeonCyan = Color(0xFF19E2FF);
const _kAmber = Color(0xFFFFB85C);
const _kValidGreen = Color(0xFF6BE39B);
const _kDangerRed = Color(0xFFFF7A8A);

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
    final useMetricUnits =
        ref.watch(metricUnitsPreferenceProvider).value ?? true;
    if (workouts.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
        decoration: BoxDecoration(
          color: _kCardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _kCardBorder),
        ),
        child: Column(
          children: [
            const Icon(Icons.event_busy_rounded, color: _kMutedText, size: 40),
            const SizedBox(height: 10),
            Text(
              'No workouts found for $range.',
              style: const TextStyle(
                color: _kMutedText,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: workouts.map((workout) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _WorkoutHistoryCard(
            workout: workout,
            useMetricUnits: useMetricUnits,
          ),
        );
      }).toList(),
    );
  }
}

class _WorkoutHistoryCard extends StatelessWidget {
  final WorkoutSession workout;
  final bool useMetricUnits;

  const _WorkoutHistoryCard({
    required this.workout,
    required this.useMetricUnits,
  });

  @override
  Widget build(BuildContext context) {
    final color = _activityColor(workout.activityType);
    final start = workout.startedAt.toLocal();
    final day = start.day.toString().padLeft(2, '0');
    final month = _monthShort(start.month).toUpperCase();
    final pace = _paceLabel(workout, useMetricUnits: useMetricUnits);
    final consistency = assessWorkoutSession(workout);
    final shouldWarn = consistency.validityFlag != WorkoutValidityFlag.verified;
    final primaryDistanceKm = workout.gpsAnalysis.validDistanceKm > 0
        ? workout.gpsAnalysis.validDistanceKm
        : workout.distanceKm;
    final excludedKm =
        workout.gpsAnalysis.suspiciousDistanceKm +
        workout.gpsAnalysis.invalidDistanceKm;

    return InkWell(
      borderRadius: BorderRadius.circular(22),
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
          color: _kCardBg,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _kCardBorder),
          boxShadow: [
            BoxShadow(
              color: _kNeonCyan.withValues(alpha: 0.06),
              blurRadius: 24,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 62,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    day,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      height: 0.95,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    month,
                    style: const TextStyle(
                      color: _kMutedText,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          WorkoutFormatters.formatActivityType(
                            workout.activityType,
                          ),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      _HistoryValidityBadge(flag: consistency.validityFlag),
                      const SizedBox(width: 8),
                      Text(
                        _timeLabel(workout.startedAt),
                        style: const TextStyle(
                          color: _kMutedText,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  if (shouldWarn) ...[
                    const SizedBox(height: 8),
                    Text(
                      activityConsistencyWarningText(consistency),
                      style: const TextStyle(
                        color: _kAmber,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Raw ${WorkoutFormatters.formatDistance(workout.gpsAnalysis.totalDistanceKm, useMetric: useMetricUnits, decimals: 2)} • Excluded ${WorkoutFormatters.formatDistance(excludedKm, useMetric: useMetricUnits, decimals: 2)}',
                      style: const TextStyle(
                        color: _kMutedText,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _MetricMini(
                        color: _kNeonCyan,
                        icon: Icons.place_outlined,
                        value:
                            (useMetricUnits
                                    ? primaryDistanceKm
                                    : WorkoutFormatters.kmToMi(
                                        primaryDistanceKm,
                                      ))
                                .toStringAsFixed(1),
                        label: WorkoutFormatters.distanceUnitLabel(
                          useMetric: useMetricUnits,
                        ),
                      ),
                      _MetricMini(
                        color: color,
                        icon: Icons.timer_outlined,
                        value: _durationShort(workout.durationSec),
                        label: 'time',
                      ),
                      _MetricMini(
                        color: Colors.white,
                        icon: Icons.speed_rounded,
                        value: pace,
                        label: 'pace',
                      ),
                      _MetricMini(
                        color: _kAmber,
                        icon: Icons.local_fire_department_rounded,
                        value: '${workout.caloriesKcal.round()}',
                        label: 'kcal',
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: _kMutedSoft),
          ],
        ),
      ),
    );
  }
}

class _MetricMini extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String value;
  final String label;

  const _MetricMini({
    required this.color,
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.96),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  color: _kMutedText,
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HistoryValidityBadge extends StatelessWidget {
  const _HistoryValidityBadge({required this.flag});

  final WorkoutValidityFlag flag;

  @override
  Widget build(BuildContext context) {
    final color = switch (flag) {
      WorkoutValidityFlag.verified => _kValidGreen,
      WorkoutValidityFlag.partial => _kAmber,
      WorkoutValidityFlag.unverified => _kDangerRed,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Text(
        workoutValidityLabel(flag),
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

String _timeLabel(DateTime dateTime) {
  final local = dateTime.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _monthShort(int month) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return months[month - 1];
}

String _durationShort(int seconds) {
  final minutes = seconds ~/ 60;
  final remaining = seconds % 60;
  return '$minutes:${remaining.toString().padLeft(2, '0')}';
}

String _paceLabel(WorkoutSession workout, {required bool useMetricUnits}) {
  final distanceKm = workout.gpsAnalysis.validDistanceKm > 0
      ? workout.gpsAnalysis.validDistanceKm
      : workout.distanceKm;
  if (distanceKm <= 0 || workout.durationSec <= 0) return '--';
  final paceMinPerKm = workout.durationSec / 60 / distanceKm;
  return WorkoutFormatters.formatSplitPace(
    paceMinPerKm,
    useMetric: useMetricUnits,
  );
}

Color _activityColor(String activity) {
  switch (activity.toLowerCase()) {
    case 'running':
      return const Color(0xFF19E2FF);
    case 'cycling':
      return const Color(0xFFFFB85C);
    case 'walking':
      return const Color(0xFF39F2B8);
    default:
      return _kNeonCyan;
  }
}
