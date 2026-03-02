import 'dart:async';
import 'package:fitness_exercise_application/data/datasources/remote/workout_remote_datasource.dart';
import 'package:fitness_exercise_application/data/local/local_db.dart';
import 'package:fitness_exercise_application/data/local/schema/local_gps_point.dart';
import 'package:fitness_exercise_application/data/local/schema/local_workout.dart';
import 'package:fitness_exercise_application/domain/repositories/workout_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:fitness_exercise_application/domain/entities/workout.dart';

class WorkoutRepositoryImpl implements WorkoutRepository {
  final WorkoutRemoteDataSource _remoteDataSource;
  final SupabaseClient _supabase;

  WorkoutRepositoryImpl(this._remoteDataSource, this._supabase);

  @override
  Future<List<Workout>> getWorkouts() async {
    final localWorkouts = await LocalDB.getAllWorkouts();
    return localWorkouts.map((w) {
      return Workout(
        id: w.id.toString(),
        userId: w.userId,
        activityType: w.activityType,
        startedAt: w.startTime,
        endedAt: w.endTime,
        distanceKm: w.distanceMeters / 1000.0,
        durationMin: w.durationSeconds / 60.0,
        calories: w.caloriesBurned.toInt(),
        avgSpeedKmh: w.durationSeconds > 0
            ? (w.distanceMeters * 3.6) / w.durationSeconds
            : 0.0,
      );
    }).toList();
  }

  @override
  Future<Workout?> getWorkout(String id) async {
    final intId = int.tryParse(id);
    if (intId == null) return null;

    final w = await LocalDB.getWorkout(intId);
    if (w == null) return null;

    return Workout(
      id: w.id.toString(),
      userId: w.userId,
      activityType: w.activityType,
      startedAt: w.startTime,
      endedAt: w.endTime,
      distanceKm: w.distanceMeters / 1000.0,
      durationMin: w.durationSeconds / 60.0,
      calories: w.caloriesBurned.toInt(),
      avgSpeedKmh: w.durationSeconds > 0
          ? (w.distanceMeters * 3.6) / w.durationSeconds
          : 0.0,
    );
  }

  @override
  Future<int> startWorkout(String activityType) async {
    final userId = _supabase.auth.currentUser!.id;

    final workout = LocalWorkout()
      ..userId = userId
      ..activityType = activityType
      ..status = WorkoutStatus.ongoing
      ..startTime = DateTime.now();

    final id = await LocalDB.createWorkout(workout);

    // Attempt to start on server immediately, but don't block
    _syncStartWorkout(id, activityType);

    return id;
  }

  @override
  Future<void> deleteWorkout(String id) async {
    final intId = int.tryParse(id);
    if (intId != null) {
      await LocalDB.deleteWorkout(intId);
    }
  }

  Future<void> _syncStartWorkout(int localId, String activityType) async {
    if (await InternetConnectionChecker().hasConnection) {
      try {
        final serverId = await _remoteDataSource.startWorkout(activityType);
        final workout = await LocalDB.getWorkout(localId);
        if (workout != null) {
          workout.syncId = serverId;
          await LocalDB.updateWorkout(workout);
        }
      } catch (e) {
        print('Failed to sync start workout: $e');
      }
    }
  }

  @override
  Future<void> pauseWorkout(int workoutId) async {
    // Implement pause logic if needed (e.g., status update)
  }

  @override
  Future<void> resumeWorkout(int workoutId) async {
    // Implement resume logic
  }

  @override
  Future<void> endWorkout(
    int workoutId, {
    double? distance,
    double? durationMinutes,
    double? speed,
    int? calories,
    String? mode,
    int? stepCount,
    double? elevationGainMeters,
  }) async {
    final workout = await LocalDB.getWorkout(workoutId);
    if (workout == null) return;

    workout.status = WorkoutStatus.completed;
    workout.endTime = DateTime.now();

    // Update metrics if provided
    if (distance != null) workout.distanceMeters = distance * 1000;
    if (durationMinutes != null) workout.durationSeconds = durationMinutes * 60;
    if (calories != null) workout.caloriesBurned = calories.toDouble();
    if (speed != null) workout.avgPace = speed;

    // Set dual-mode specifics if they exist
    if (mode != null) workout.mode = mode;
    if (stepCount != null) workout.stepCount = stepCount;

    await LocalDB.updateWorkout(workout);

    // Trigger sync
    await syncPendingData();
  }

  @override
  Future<void> trackPoint(int workoutId, LocalGPSPoint point) async {
    point.localWorkoutId = workoutId;
    await LocalDB.savePoints([point]);

    // Update workout stats (distance, etc.) here or in a separate manager
    // For simplicity, we just save points now.
  }

  @override
  Stream<LocalWorkout?> watchWorkout(int workoutId) async* {
    // Isar watchers would go here. For now, simple poll or just return current
    yield await LocalDB.getWorkout(workoutId);
  }

  @override
  Stream<List<LocalGPSPoint>> watchPoints(int workoutId) async* {
    yield await LocalDB.getPointsForWorkout(workoutId);
  }

  @override
  Future<void> syncPendingData() async {
    if (!await InternetConnectionChecker().hasConnection) return;

    // 1. Sync pending Workouts
    try {
      final unsyncedWorkouts = await LocalDB.getUnsyncedWorkouts();
      for (final workout in unsyncedWorkouts) {
        if (workout.syncId == null) {
          final serverId = await _remoteDataSource.startWorkout(
            workout.activityType,
          );
          workout.syncId = serverId;
          await LocalDB.updateWorkout(workout);
        }

        if (workout.status == WorkoutStatus.completed) {
          // Push completion if finished
          await _remoteDataSource.endWorkout(
            workout.syncId!,
            distance: workout.distanceMeters,
            durationMinutes: workout.durationSeconds / 60,
            speed: workout.avgPace,
            calories: workout.caloriesBurned.toInt(),
            mode: workout.mode,
            stepCount: workout.stepCount,
          );
          workout.isSynced = true;
          await LocalDB.updateWorkout(workout);
        }

        // Push pending points
        await syncWorkoutPoints(workout.id);
      }
    } catch (e) {
      print('Failed to sync workouts: $e');
    }
  }

  // Helper to sync specific workout's points
  Future<void> syncWorkoutPoints(int localWorkoutId) async {
    final workout = await LocalDB.getWorkout(localWorkoutId);
    if (workout?.syncId == null)
      return; // Can't sync points without server workout ID

    final points = await LocalDB.getUnsyncedPoints(localWorkoutId);
    if (points.isEmpty) return;

    // Batch in chunks of 50
    for (var i = 0; i < points.length; i += 50) {
      final end = (i + 50 < points.length) ? i + 50 : points.length;
      final batch = points.sublist(i, end);

      try {
        final payload = batch
            .map(
              (p) => {
                'workout_id': workout!.syncId,
                'latitude': p.latitude,
                'longitude': p.longitude,
                'altitude': p.altitude,
                'speed': p.speed,
                'accuracy': p.accuracy,
                'heading': p.heading,
                'timestamp': p.timestamp.toIso8601String(),
              },
            )
            .toList();

        await _remoteDataSource.trackGPSBatch(payload);

        // Mark as synced
        await LocalDB.markPointsAsSynced(batch.map((e) => e.id).toList());
      } catch (e) {
        print('Sync error: $e');
        break; // Stop on error
      }
    }
  }
}
