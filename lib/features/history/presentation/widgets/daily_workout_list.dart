import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/workout_details_screen.dart';
import 'package:fitness_exercise_application/shared/formatters/workout_formatters.dart';
import 'package:flutter/material.dart';

const _kCardBg = Color(0xFF102033);
const _kCardBorder = Color(0x2200E5FF);
const _kMutedText = Color(0xFF8A96A9);
const _kMutedSoft = Color(0xFF627286);
const _kNeonCyan = Color(0xFF19E2FF);
const _kAmber = Color(0xFFFFB85C);

class DailyWorkoutList extends StatelessWidget {
  final List<WorkoutSession> workouts;
  final String range;

  const DailyWorkoutList({
    super.key,
    required this.workouts,
    required this.range,
  });

  @override
  Widget build(BuildContext context) {
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
          child: _WorkoutHistoryCard(workout: workout),
        );
      }).toList(),
    );
  }
}

class _WorkoutHistoryCard extends StatelessWidget {
  final WorkoutSession workout;

  const _WorkoutHistoryCard({required this.workout});

  @override
  Widget build(BuildContext context) {
    final color = _activityColor(workout.activityType);
    final start = workout.startedAt.toLocal();
    final day = start.day.toString().padLeft(2, '0');
    final month = _monthShort(start.month).toUpperCase();
    final pace = _paceLabel(workout);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => WorkoutDetailsScreen(workoutId: workout.id),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _kCardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _kCardBorder),
          boxShadow: [
            BoxShadow(
              color: _kNeonCyan.withValues(alpha: 0.06),
              blurRadius: 20,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 58,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(12),
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
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
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
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _MetricMini(
                        color: _kNeonCyan,
                        icon: Icons.place_outlined,
                        value: workout.distanceKm.toStringAsFixed(1),
                        label: 'km',
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

String _paceLabel(WorkoutSession workout) {
  if (workout.distanceKm <= 0 || workout.durationSec <= 0) return '--';
  final paceMinPerKm = workout.durationSec / 60 / workout.distanceKm;
  final minutes = paceMinPerKm.floor();
  var paceSeconds = ((paceMinPerKm - minutes) * 60).round();
  var safeMinutes = minutes;
  if (paceSeconds == 60) {
    safeMinutes += 1;
    paceSeconds = 0;
  }
  return '$safeMinutes\'${paceSeconds.toString().padLeft(2, '0')}';
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
