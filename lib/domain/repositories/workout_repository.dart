import 'package:fitness_exercise_application/data/local/schema/local_workout.dart';
import 'package:fitness_exercise_application/data/local/schema/local_gps_point.dart';

import 'package:fitness_exercise_application/domain/entities/workout.dart';

abstract class WorkoutRepository {
  Future<List<Workout>> getWorkouts();
  Future<Workout?> getWorkout(String id);
  Future<int> startWorkout(String activityType);
  Future<void> deleteWorkout(String id);
  Future<void> pauseWorkout(int workoutId);
  Future<void> resumeWorkout(int workoutId);
  Future<void> endWorkout(
    int workoutId, {
    double? distance,
    double? durationMinutes,
    double? speed,
    int? calories,
    String? mode,
    int? stepCount,
    double? elevationGainMeters,
  });

  Future<void> trackPoint(int workoutId, LocalGPSPoint point);

  Stream<LocalWorkout?> watchWorkout(int workoutId);
  Stream<List<LocalGPSPoint>> watchPoints(int workoutId);

  Future<void> syncPendingData();
}
