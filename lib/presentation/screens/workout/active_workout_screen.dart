import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitness_exercise_application/presentation/providers/providers.dart';
import 'package:fitness_exercise_application/presentation/providers/workout_providers.dart';
import 'package:fitness_exercise_application/presentation/screens/home/home_screen.dart';

class ActiveWorkoutScreen extends ConsumerWidget {
  final String workoutId;
  final String activityType;

  const ActiveWorkoutScreen({
    super.key,
    required this.workoutId,
    required this.activityType,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timerState = ref.watch(timerProvider);

    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) async {
        if (didPop) return;
        final shouldPop = await _showExitConfirmation(context);
        if (shouldPop == true && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Workout in Progress'),
          backgroundColor: const Color(0xff18b0e8),
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Activity Type
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: const Color(0xff18b0e8).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getActivityIcon(activityType),
                    size: 50,
                    color: const Color(0xff18b0e8),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  activityType,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 48),

                // Timer Display
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _formatDuration(timerState.seconds),
                    style: const TextStyle(
                      fontSize: 56,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                const SizedBox(height: 48),

                // Control Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Pause/Resume Button
                    FloatingActionButton.large(
                      heroTag: 'pause',
                      onPressed: () {
                        if (timerState.isRunning) {
                          ref.read(timerProvider.notifier).pause();
                        } else {
                          ref.read(timerProvider.notifier).resume();
                        }
                      },
                      backgroundColor: Colors.orange,
                      child: Icon(
                        timerState.isRunning ? Icons.pause : Icons.play_arrow,
                        size: 36,
                      ),
                    ),
                    const SizedBox(width: 24),

                    // End Button
                    FloatingActionButton.large(
                      heroTag: 'end',
                      onPressed: () =>
                          _endWorkout(context, ref, timerState.seconds),
                      backgroundColor: Colors.red,
                      child: const Icon(Icons.stop, size: 36),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Labels
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Pause/Resume',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    const SizedBox(width: 80),
                    Text('End', style: TextStyle(color: Colors.grey[600])),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDuration(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
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

  Future<bool?> _showExitConfirmation(BuildContext context) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit Workout?'),
        content: const Text(
          'Are you sure you want to exit? Your workout progress will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Exit'),
          ),
        ],
      ),
    );
  }

  Future<void> _endWorkout(
    BuildContext context,
    WidgetRef ref,
    int durationSeconds,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Workout?'),
        content: const Text('Do you want to end this workout and save it?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('End Workout'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Use notifier to finish workout
      await ref
          .read(workoutListProvider.notifier)
          .finishWorkout(
            workoutId: workoutId,
            activityType: activityType,
            durationSeconds: durationSeconds,
          );

      // Fetch updated workout to get calculated calories
      final repository = ref.read(workoutRepositoryProvider);
      final workout = await repository.getWorkout(workoutId);

      // Dismiss loading
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      if (workout == null) throw Exception('Failed to fetch workout details');

      // Show success dialog
      if (context.mounted) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Workout Completed! 🎉'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Great job on your $activityType workout!',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                _ResultRow(
                  icon: Icons.timer,
                  label: 'Duration',
                  value: '${(durationSeconds / 60).toStringAsFixed(1)} min',
                ),
                _ResultRow(
                  icon: Icons.local_fire_department,
                  label: 'Calories Burned',
                  value: '${workout.calories ?? 0} kcal',
                  valueColor: Colors.orange,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  // Navigate back to home
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const HomeScreen()),
                    (route) => false,
                  );
                },
                child: const Text('Done'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      // Dismiss loading
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // Show error
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving workout: $e')));
      }
    }
  }
}

// Result Row Widget for Success Dialog
class _ResultRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _ResultRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: valueColor ?? Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}
