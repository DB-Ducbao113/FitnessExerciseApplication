import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/features/workout/presentation/providers/workout_providers.dart';
import 'package:fitness_exercise_application/shared/formatters/workout_formatters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RecentActivities extends ConsumerWidget {
  const RecentActivities({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workouts =
        ref.watch(workoutListProvider).valueOrNull ?? const <WorkoutSession>[];
    final recent = workouts.take(10).toList();

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Activities',
              style: Theme.of(context).textTheme.displayLarge,
            ),
            const SizedBox(height: 20),
            Expanded(
              child: recent.isEmpty
                  ? const Center(
                      child: Text(
                        'No activities yet',
                        style: TextStyle(color: Colors.white70),
                      ),
                    )
                  : ListView.builder(
                      itemCount: recent.length,
                      itemBuilder: (context, index) =>
                          ActivityItem(workout: recent[index]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class ActivityItem extends StatelessWidget {
  final WorkoutSession workout;

  const ActivityItem({super.key, required this.workout});

  String _getActivityImage(String activityType) {
    switch (activityType.toLowerCase()) {
      case 'running':
        return 'assets/running.jpg';
      case 'cycling':
        return 'assets/cycling.jpg';
      case 'walking':
        return 'assets/walking.jpg';
      case 'swimming':
        return 'assets/swimming.jpg';
      case 'weights':
        return 'assets/weights.jpg';
      case 'yoga':
        return 'assets/yoga.jpg';
      default:
        return 'assets/running.jpg';
    }
  }

  @override
  Widget build(BuildContext context) {
    final activity = WorkoutFormatters.formatActivityType(workout.activityType);

    return GestureDetector(
      onTap: () {
        // Legacy widget: keep passive until it is wired back into navigation.
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        height: 50,
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xffe1e1e1)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xffcff2ff),
              ),
              height: 35,
              width: 35,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  image: DecorationImage(
                    image: AssetImage(_getActivityImage(activity)),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 20),
            Text(
              activity,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
            ),
            const Expanded(child: SizedBox()),
            const SizedBox(width: 5),
            const Icon(Icons.timer, size: 12),
            Text(
              WorkoutFormatters.formatDurationFromSeconds(workout.durationSec),
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w300),
            ),
            const SizedBox(width: 10),
            const Icon(Icons.wb_sunny_outlined, size: 12),
            const SizedBox(width: 5),
            Text(
              WorkoutFormatters.formatCalories(workout.caloriesKcal.round()),
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w300),
            ),
            const SizedBox(width: 20),
          ],
        ),
      ),
    );
  }
}
