import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitness_exercise_application/providers/workout_providers.dart';
import 'package:fitness_exercise_application/utils/workout_formatters.dart';
import 'package:intl/intl.dart';

class WorkoutDetailsScreen extends ConsumerWidget {
  final String workoutId;

  const WorkoutDetailsScreen({super.key, required this.workoutId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workoutAsync = ref.watch(workoutProvider(workoutId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Workout Details'),
        backgroundColor: const Color(0xff18b0e8),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _showDeleteConfirmation(context, ref, workoutId),
          ),
        ],
      ),
      body: workoutAsync.when(
        data: (workout) {
          if (workout == null) {
            return const Center(child: Text('Workout not found'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Activity Type Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: const Color(
                              0xff18b0e8,
                            ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            _getActivityIcon(workout.activityType),
                            color: const Color(0xff18b0e8),
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              workout.activityType.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              DateFormat(
                                'EEEE, MMM dd, yyyy',
                              ).format(workout.startedAt.toLocal()),
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Stats Grid
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: Icons.straighten,
                        label: 'Distance',
                        value: '${workout.distanceKm.toStringAsFixed(2)} km',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.timer,
                        label: 'Duration',
                        value:
                            '${(workout.durationSec / 60.0).toStringAsFixed(0)} min',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: Icons.speed,
                        label: 'Avg Speed',
                        value: '${workout.avgSpeedKmh.toStringAsFixed(1)} km/h',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.local_fire_department,
                        label: 'Calories',
                        value: WorkoutFormatters.formatCalories(
                          workout.caloriesKcal.round(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Timeline Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Timeline',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _TimelineItem(
                          icon: Icons.play_circle,
                          label: 'Started',
                          time: DateFormat(
                            'HH:mm:ss',
                          ).format(workout.startedAt.toLocal()),
                        ),
                        if (workout.endedAt != null) ...[
                          const SizedBox(height: 12),
                          _TimelineItem(
                            icon: Icons.stop_circle,
                            label: 'Ended',
                            time: DateFormat(
                              'HH:mm:ss',
                            ).format(workout.endedAt!.toLocal()),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }

  IconData _getActivityIcon(String activityType) {
    switch (activityType.toLowerCase()) {
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
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xff18b0e8), size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String time;

  const _TimelineItem({
    required this.icon,
    required this.label,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xff18b0e8)),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(fontSize: 16)),
        const Spacer(),
        Text(
          time,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

void _showDeleteConfirmation(
  BuildContext context,
  WidgetRef ref,
  String workoutId,
) {
  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Delete Workout'),
      content: const Text(
        'Are you sure you want to delete this workout? This action cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () async {
            Navigator.of(dialogContext).pop(); // Close dialog

            try {
              await ref
                  .read(workoutListProvider.notifier)
                  .deleteWorkout(workoutId);

              if (context.mounted) {
                Navigator.of(context).pop(); // Go back to previous screen
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Workout deleted'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          },
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
}
