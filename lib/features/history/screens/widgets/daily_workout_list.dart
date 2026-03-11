import 'package:flutter/material.dart';
import 'package:fitness_exercise_application/models/workout_session.dart';
import 'package:fitness_exercise_application/features/workout/screens/workout_details_screen.dart';
import 'package:fitness_exercise_application/utils/workout_formatters.dart';

class DailyWorkoutList extends StatelessWidget {
  final DateTime selectedDate;
  final List<WorkoutSession> workouts;

  const DailyWorkoutList({
    super.key,
    required this.selectedDate,
    required this.workouts,
  });

  Color _getActivityColor(String activity) {
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
        return const Color(0xff18b0e8);
    }
  }

  IconData _getActivityIcon(String activity) {
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Workouts on ${_formatDate(selectedDate)}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        if (workouts.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.event_busy, size: 60, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  Text(
                    'No workouts on this day',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: workouts.length,
            itemBuilder: (context, index) {
              final workout = workouts[index];
              final color = _getActivityColor(workout.activityType);
              final icon = _getActivityIcon(workout.activityType);

              final distanceStr = '${workout.distanceKm.toStringAsFixed(2)} km';
              final durationStr = WorkoutFormatters.formatDurationFromSeconds(
                workout.durationSec,
              );
              final speedStr = '${workout.avgSpeedKmh.toStringAsFixed(1)} km/h';
              final calStr = WorkoutFormatters.formatCalories(
                workout.caloriesKcal.round(),
              );

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            WorkoutDetailsScreen(workoutId: workout.id),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Activity icon
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(icon, color: color, size: 26),
                        ),
                        const SizedBox(width: 14),

                        // Metrics
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Title row
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    workout.activityType,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right,
                                    color: Colors.grey[400],
                                    size: 20,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),

                              // 2×2 metric grid
                              Row(
                                children: [
                                  _MetricChip(
                                    icon: Icons.straighten,
                                    value: distanceStr,
                                    color: color,
                                  ),
                                  const SizedBox(width: 8),
                                  _MetricChip(
                                    icon: Icons.timer_outlined,
                                    value: durationStr,
                                    color: color,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  _MetricChip(
                                    icon: Icons.speed,
                                    value: speedStr,
                                    color: color,
                                  ),
                                  const SizedBox(width: 8),
                                  _MetricChip(
                                    icon: Icons.local_fire_department,
                                    value: calStr,
                                    color: color,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
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
}

// ─── Metric chip ─────────────────────────────────────────────────────────────

class _MetricChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color color;

  const _MetricChip({
    required this.icon,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color.withOpacity(0.9),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
