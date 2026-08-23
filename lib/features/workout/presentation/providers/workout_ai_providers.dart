import 'package:fitness_exercise_application/features/workout/data/repositories/workout_ai_repository.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_ai_insight.dart';
import 'package:fitness_exercise_application/features/workout/presentation/providers/workout_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final workoutAiRepositoryProvider = Provider<WorkoutAiRepository>((ref) {
  return WorkoutAiRepository();
});

/// Riverpod FutureProvider family that fetches AI Post-Workout Insight for a given workoutId.
final workoutAiInsightProvider =
    FutureProvider.family<WorkoutAiInsight?, String>((ref, workoutId) async {
  final workoutAsync = await ref.watch(workoutProvider(workoutId).future);
  if (workoutAsync == null) return null;

  final repository = ref.watch(workoutAiRepositoryProvider);
  final historyAsync = await ref.watch(workoutListProvider.future);

  final history = historyAsync
      .where((w) => w.id != workoutId)
      .toList();

  return repository.getWorkoutInsight(
    workout: workoutAsync,
    last30DaysWorkouts: history,
  );
});
