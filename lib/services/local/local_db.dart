import 'package:fitness_exercise_application/services/local/schema/local_gps_point.dart';
import 'package:fitness_exercise_application/services/local/schema/local_workout.dart';
import 'package:fitness_exercise_application/models/workout_session.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

class LocalDB {
  static late Isar _isar;

  static Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    _isar = await Isar.open([
      LocalWorkoutSchema,
      LocalGPSPointSchema,
    ], directory: dir.path);
  }

  static Isar get instance => _isar;

  // New Workout Methods

  /// Insert locally. Used when finishing a session.
  static Future<void> saveSession(LocalWorkout workout) async {
    await _isar.writeTxn(() async {
      await _isar.localWorkouts.put(workout);
    });
  }

  /// Get all sessions for a user, sorted descending. UI uses this.
  static Future<List<LocalWorkout>> getSessionsByUser(String userId) async {
    return await _isar.localWorkouts
        .filter()
        .userIdEqualTo(userId)
        .sortByStartedAtDesc()
        .findAll();
  }

  /// Filtered by activity type.
  static Future<List<LocalWorkout>> getSessionsByUserByType(
    String userId,
    String activityType,
  ) async {
    return await _isar.localWorkouts
        .filter()
        .userIdEqualTo(userId)
        .activityTypeEqualTo(activityType, caseSensitive: false)
        .sortByStartedAtDesc()
        .findAll();
  }

  static Future<LocalWorkout?> getSessionById(String sessionId) async {
    return await _isar.localWorkouts
        .filter()
        .sessionIdEqualTo(sessionId)
        .findFirst();
  }

  static Future<void> deleteWorkout(int id) async {
    await _isar.writeTxn(() async {
      await _isar.localWorkouts.delete(id);
    });
  }

  static Future<List<LocalWorkout>> getUnsyncedWorkouts() async {
    return await _isar.localWorkouts.filter().isSyncedEqualTo(false).findAll();
  }

  /// Wipe all local cache for a specific user (used on logout).
  static Future<void> clearAllForUser(String userId) async {
    await _isar.writeTxn(() async {
      final workouts = await _isar.localWorkouts
          .filter()
          .userIdEqualTo(userId)
          .findAll();

      // Delete GPS points associated with these workouts
      for (final w in workouts) {
        await _isar.localGPSPoints
            .filter()
            .localWorkoutIdEqualTo(w.id)
            .deleteAll();
      }

      // Delete the workouts themselves
      await _isar.localWorkouts.filter().userIdEqualTo(userId).deleteAll();
    });
  }

  /// Hydrate local DB from cloud models to implement sync across devices.
  static Future<void> syncRemoteSessions(List<WorkoutSession> remotes) async {
    await _isar.writeTxn(() async {
      for (final remote in remotes) {
        var existing = await _isar.localWorkouts
            .filter()
            .sessionIdEqualTo(remote.id)
            .findFirst();

        if (existing == null) {
          // If it doesn't exist locally, add it to the cache
          final newWorkout = LocalWorkout.fromEntity(remote);
          await _isar.localWorkouts.put(newWorkout);
        } else {
          // If it exists locally, ensure it matches the cloud source of truth
          existing.userId = remote.userId;
          existing.activityType = remote.activityType;
          existing.startedAt = remote.startedAt;
          existing.endedAt = remote.endedAt;
          existing.durationSec = remote.durationSec;
          existing.distanceKm = remote.distanceKm;
          existing.steps = remote.steps;
          existing.avgSpeedKmh = remote.avgSpeedKmh;
          existing.caloriesKcal = remote.caloriesKcal;
          existing.mode = remote.mode;
          existing.createdAt = remote.createdAt;
          existing.isSynced = true;

          await _isar.localWorkouts.put(existing);
        }
      }
    });
  }

  // GPS Point Methods
  static Future<void> savePoints(List<LocalGPSPoint> points) async {
    await _isar.writeTxn(() async {
      await _isar.localGPSPoints.putAll(points);
    });
  }

  static Future<List<LocalGPSPoint>> getPointsForWorkout(int workoutId) async {
    return await _isar.localGPSPoints
        .filter()
        .localWorkoutIdEqualTo(workoutId)
        .sortByTimestamp()
        .findAll();
  }

  static Future<List<LocalGPSPoint>> getUnsyncedPoints(int workoutId) async {
    return await _isar.localGPSPoints
        .filter()
        .localWorkoutIdEqualTo(workoutId)
        .isSyncedEqualTo(false)
        .sortByTimestamp()
        .findAll();
  }

  static Future<void> markPointsAsSynced(List<int> pointIds) async {
    await _isar.writeTxn(() async {
      for (final id in pointIds) {
        final point = await _isar.localGPSPoints.get(id);
        if (point != null) {
          point.isSynced = true;
          await _isar.localGPSPoints.put(point);
        }
      }
    });
  }
}
