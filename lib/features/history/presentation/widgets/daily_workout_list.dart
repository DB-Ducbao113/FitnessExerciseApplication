import 'package:fitness_exercise_application/features/workout/presentation/screens/workout_details_screen.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/core/utils/date_time_helper.dart';
import 'package:fitness_exercise_application/shared/formatters/workout_formatters.dart';
import 'package:flutter/material.dart';

const _kCardBg = Color(0xcc121b2c);
const _kCardBorder = Color(0x2200e5ff);
const _kMutedText = Color(0xff7d8da6);
const _kNeonCyan = Color(0xff00e5ff);

class DailyWorkoutList extends StatelessWidget {
  final DateTime selectedDate;
  final List<WorkoutSession> workouts;

  const DailyWorkoutList({
    super.key,
    required this.selectedDate,
    required this.workouts,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _kCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sessions on ${_formatDate(selectedDate)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          if (workouts.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
              decoration: BoxDecoration(
                color: const Color(0xff101a29),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Column(
                children: [
                  Icon(Icons.event_busy_rounded, color: _kMutedText, size: 42),
                  SizedBox(height: 10),
                  Text(
                    'Nothing recorded on this date yet.',
                    style: TextStyle(
                      color: _kMutedText,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )
          else
            ...workouts.map(
              (workout) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _WorkoutTile(workout: workout),
              ),
            ),
        ],
      ),
    );
  }
}

class _WorkoutTile extends StatelessWidget {
  final WorkoutSession workout;

  const _WorkoutTile({required this.workout});

  @override
  Widget build(BuildContext context) {
    final color = _activityColor(workout.activityType);

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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xff101a29),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _kCardBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                _activityIcon(workout.activityType),
                color: color,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
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
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Text(
                        _timeLabel(workout.startedAt),
                        style: const TextStyle(
                          color: _kMutedText,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _InfoPill(
                        icon: Icons.straighten_rounded,
                        text: WorkoutFormatters.formatDistance(
                          workout.distanceKm,
                        ),
                        color: color,
                      ),
                      _InfoPill(
                        icon: Icons.timer_outlined,
                        text: WorkoutFormatters.formatDurationFromSeconds(
                          workout.durationSec,
                        ),
                        color: color,
                      ),
                      _InfoPill(
                        icon: Icons.local_fire_department_rounded,
                        text: '${workout.caloriesKcal.round()} kcal',
                        color: color,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded, color: _kMutedText),
          ],
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _InfoPill({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: color.withValues(alpha: 0.95),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDate(DateTime date) {
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
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

String _timeLabel(DateTime dateTime) {
  final local = dateTime.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  final today = DateTimeHelper.localDateOnly(DateTime.now());
  final date = DateTimeHelper.localDateOnly(local);
  if (date == today) return '$hour:$minute';
  return '${local.day}/${local.month} $hour:$minute';
}

Color _activityColor(String activity) {
  switch (activity.toLowerCase()) {
    case 'running':
      return const Color(0xffFF6B6B);
    case 'cycling':
      return const Color(0xff4ECDC4);
    case 'walking':
      return const Color(0xff95E1D3);
    case 'swimming':
      return const Color(0xff3498DB);
    case 'weights':
      return const Color(0xff9B59B6);
    case 'yoga':
      return const Color(0xffF39C12);
    default:
      return _kNeonCyan;
  }
}

IconData _activityIcon(String activity) {
  switch (activity.toLowerCase()) {
    case 'running':
      return Icons.directions_run;
    case 'cycling':
      return Icons.directions_bike;
    case 'walking':
      return Icons.directions_walk;
    case 'swimming':
      return Icons.pool;
    case 'weights':
      return Icons.fitness_center;
    case 'yoga':
      return Icons.self_improvement;
    default:
      return Icons.fitness_center;
  }
}
