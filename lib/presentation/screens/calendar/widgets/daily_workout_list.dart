import 'package:flutter/material.dart';
import 'package:fitness_exercise_application/domain/entities/workout.dart';
import 'package:fitness_exercise_application/presentation/screens/workout/workout_details_screen.dart';
import 'package:fitness_exercise_application/core/utils/workout_formatters.dart';

class DailyWorkoutList extends StatelessWidget {
  final DateTime selectedDate;
  final List<Workout> workouts;

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

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color),
                  ),
                  title: Text(
                    workout.activityType,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${workout.calories != null ? WorkoutFormatters.formatCalories(workout.calories!) : '0 kcal'} • ${workout.durationMin != null ? WorkoutFormatters.formatDuration(workout.durationMin!.round()) : '0 min'}',
                  ),
                  trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            WorkoutDetailsScreen(workoutId: workout.id),
                      ),
                    );
                  },
                ),
              );
            },
          ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final months = [
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
